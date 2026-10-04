#!/bin/bash
set -euo pipefail

# Codex Yury Kurilov setup for macOS
# Version 2026-10-04.1

ENDPOINT="https://cliproxy.kurilov.cloud/v1"
PROVIDER_ID="yury-kurilov-codex"
PROVIDER_LABEL="Кодекс Юрия Курилова"
PASEO_VERSION="0.10.3"
CODEX_VERSION="0.160.0"
ROOT="$HOME/Library/Application Support/Codex Yury Kurilov"
PASEO_PARENT="$HOME/Applications/Codex Yury Kurilov"
PASEO_APP="$PASEO_PARENT/Paseo.app"
PASEO_HOME="$HOME/.paseo"
PASEO_CONFIG="$PASEO_HOME/config.json"
PROJECT_DIR="$HOME/Documents/Codex-Yury-Kurilov"
CODEX_HOME_DIR="$ROOT/codex-home"
CODEX_DIR="$ROOT/codex-$CODEX_VERSION"
TMP="$ROOT/tmp"
DRY_RUN=0
CI_MODE="${KURILOV_CI:-0}"

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

log() { printf '%s %s\n' "$(date '+%H:%M:%S')" "$*"; }
fail() { printf 'ОШИБКА: %s\n' "$*" >&2; exit 1; }

cleanup() {
  if [[ -f "$TMP/key.txt" ]]; then
    rm -f "$TMP/key.txt"
  fi
}
trap cleanup EXIT

mkdir -p "$ROOT" "$TMP" "$PASEO_PARENT" "$PROJECT_DIR" "$CODEX_HOME_DIR" "$PASEO_HOME"
chmod 700 "$ROOT" "$TMP" "$CODEX_HOME_DIR" "$PASEO_HOME" 2>/dev/null || true

ARCH="$(uname -m)"
if [[ "$ARCH" == "x86_64" ]] && [[ "$(sysctl -in sysctl.proc_translated 2>/dev/null || true)" == "1" ]]; then
  ARCH="arm64"
fi

case "$ARCH" in
  arm64)
    PASEO_ASSET="Paseo-0.10.3-arm64.zip"
    PASEO_SHA="b145e842fc2a220f21897a369ff085f938a510e178fbfca4ee9f4e89342e3010"
    CODEX_ASSET="codex-aarch64-apple-darwin.tar.gz"
    CODEX_SHA="07c3c7ca376a8f791115342f53138dda37e97cfa29b8125d0652d93784894b5d"
    CODEX_EXTRACTED="codex-aarch64-apple-darwin"
    ;;
  x86_64)
    PASEO_ASSET="Paseo-0.10.3-x64.zip"
    PASEO_SHA="c16d1e0ceaa1e5cd030af84102611aac83ccaf847dd45e135474ff097c7ac9b4"
    CODEX_ASSET="codex-x86_64-apple-darwin.tar.gz"
    CODEX_SHA="a50c10606e4e81b8dd2f7b6bab635595aabc773c84cf2071773fbaf067825fbf"
    CODEX_EXTRACTED="codex-x86_64-apple-darwin"
    ;;
  *) fail "Неподдерживаемая архитектура Mac: $ARCH" ;;
esac

PASEO_URL="https://github.com/getpaseo/paseo/releases/download/v$PASEO_VERSION/$PASEO_ASSET"
CODEX_URL="https://github.com/openai/codex/releases/download/rust-v$CODEX_VERSION/$CODEX_ASSET"
PASEO_ZIP="$TMP/$PASEO_ASSET"
CODEX_TGZ="$TMP/$CODEX_ASSET"

verify_sha() {
  local file="$1" expected="$2" label="$3"
  local actual
  actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]] || fail "$label: контрольная сумма SHA-256 не совпала."
  log "$label: контрольная сумма SHA-256 проверена."
}

download_file() {
  local url="$1" target="$2" label="$3"
  log "Загрузка $label..."
  curl -L --fail --silent --show-error --retry 3 --retry-delay 2 "$url" -o "$target"
}

download_file "$CODEX_URL" "$CODEX_TGZ" "Codex"
verify_sha "$CODEX_TGZ" "$CODEX_SHA" "Codex"
rm -rf "$CODEX_DIR"
mkdir -p "$CODEX_DIR"
tar -xzf "$CODEX_TGZ" -C "$CODEX_DIR"
CODEX_BIN="$CODEX_DIR/$CODEX_EXTRACTED"
[[ -f "$CODEX_BIN" ]] || CODEX_BIN="$(find "$CODEX_DIR" -maxdepth 2 -type f -name 'codex*apple-darwin' | head -n 1 || true)"
[[ -n "$CODEX_BIN" && -f "$CODEX_BIN" ]] || fail "После распаковки Codex не найден исполняемый файл."
chmod 700 "$CODEX_BIN"
log "Codex подготовлен: $CODEX_BIN"
"$CODEX_BIN" --version

download_file "$PASEO_URL" "$PASEO_ZIP" "Paseo"
verify_sha "$PASEO_ZIP" "$PASEO_SHA" "Paseo"
PASEO_STAGE="$TMP/paseo-stage"
rm -rf "$PASEO_STAGE"
mkdir -p "$PASEO_STAGE"
ditto -x -k "$PASEO_ZIP" "$PASEO_STAGE"
FOUND_APP="$(find "$PASEO_STAGE" -maxdepth 3 -type d -name 'Paseo.app' | head -n 1 || true)"
[[ -n "$FOUND_APP" ]] || fail "В архиве Paseo не найден Paseo.app."
rm -rf "$PASEO_APP"
mkdir -p "$PASEO_PARENT"
mv "$FOUND_APP" "$PASEO_APP"
log "Paseo подготовлен: $PASEO_APP"

PASEO_EXE="$PASEO_APP/Contents/MacOS/Paseo"
NODE_HELPER="$PASEO_APP/Contents/Frameworks/Paseo Helper.app/Contents/MacOS/Paseo Helper"
NODE_RUNNER="$PASEO_APP/Contents/Resources/app.asar.unpacked/dist/daemon/node-entrypoint-runner.js"
CLI_ENTRY="$PASEO_APP/Contents/Resources/app.asar/node_modules/@getpaseo/cli/dist/index.js"
[[ -x "$PASEO_EXE" ]] || fail "В Paseo.app не найден основной исполняемый файл."
[[ -x "$NODE_HELPER" ]] || fail "В Paseo.app не найден встроенный Node helper."
[[ -f "$NODE_RUNNER" ]] || fail "В Paseo.app не найден встроенный Node runner."

if [[ "$DRY_RUN" == "1" ]]; then
  log "DRY-RUN OK: macOS=$ARCH, Codex и Paseo скачаны, проверены и распакованы."
  exit 0
fi

API_KEY="${KURILOV_API_KEY:-}"
if [[ -z "$API_KEY" ]]; then
  if [[ "$CI_MODE" == "1" ]]; then
    fail "Для полного CI-теста не задан KURILOV_API_KEY."
  fi
  set +e
  API_KEY="$(osascript -e 'text returned of (display dialog "Вставьте ключ доступа для Кодекса Юрия Курилова" default answer "" with hidden answer buttons {"Отмена", "Подключить"} default button "Подключить")' 2>/dev/null)"
  rc=$?
  set -e
  [[ $rc -eq 0 ]] || fail "Подключение отменено."
fi
[[ ${#API_KEY} -ge 10 && "$API_KEY" != *[[:space:]]* ]] || fail "Ключ доступа выглядит некорректно."
printf '%s' "$API_KEY" > "$TMP/key.txt"
chmod 600 "$TMP/key.txt"

log "Проверка ключа и списка моделей..."
MODELS_JSON="$TMP/models.json"
HTTP_CODE="$(curl -L --silent --show-error --output "$MODELS_JSON" --write-out '%{http_code}' -H "Authorization: Bearer $API_KEY" "$ENDPOINT/models" || true)"
[[ "$HTTP_CODE" == "200" ]] || fail "Роутер не вернул список моделей, HTTP $HTTP_CODE."

MODEL_PARSER="$TMP/select-model.js"
cat > "$MODEL_PARSER" <<'JS'
const fs = require('fs');
const p = process.argv[2];
const raw = JSON.parse(fs.readFileSync(p, 'utf8'));
const ids = [...new Set((raw.data || []).map(x => String(x && x.id || '')).filter(Boolean))]
  .filter(x => /^[A-Za-z0-9][A-Za-z0-9._:/()+-]{0,160}$/.test(x))
  .filter(x => /(^|\/)(gpt-|codex|o[1-9])/i.test(x))
  .filter(x => !/(embedding|audio|realtime|image|transcri|tts|search|spark)/i.test(x));
if (!ids.length) process.exit(2);
const preferred = ['gpt-5.3-codex','gpt-5.2-codex','gpt-5.1-codex','gpt-5-codex'];
let selected = preferred.find(x => ids.includes(x));
if (!selected) selected = ids.filter(x => /codex/i.test(x)).sort().reverse()[0];
if (!selected) selected = ids[0];
process.stdout.write(selected);
JS
MODEL="$(ELECTRON_RUN_AS_NODE=1 "$NODE_HELPER" "$MODEL_PARSER" "$MODELS_JSON")"
[[ -n "$MODEL" ]] || fail "Не удалось выбрать модель для Codex."
log "Доступная модель для проверки: $MODEL"

cat > "$CODEX_HOME_DIR/config.toml" <<EOF_CONFIG
model = "$MODEL"
model_provider = "$PROVIDER_ID"
approval_policy = "on-request"
sandbox_mode = "read-only"
web_search = "disabled"

[model_providers.$PROVIDER_ID]
name = "Codex Yury Kurilov"
base_url = "$ENDPOINT"
wire_api = "responses"
env_key = "OPENAI_API_KEY"
requires_openai_auth = false
request_max_retries = 1
stream_max_retries = 1
EOF_CONFIG
chmod 600 "$CODEX_HOME_DIR/config.toml"

CHECK_DIR="$TMP/codex-check"
rm -rf "$CHECK_DIR"
mkdir -p "$CHECK_DIR"
ANSWER="$CHECK_DIR/answer.txt"
log "Проверка ответа через Codex и роутер..."
CODEX_HOME="$CODEX_HOME_DIR" OPENAI_API_KEY="$API_KEY" OPENAI_BASE_URL="$ENDPOINT" \
  "$CODEX_BIN" -a never exec --skip-git-repo-check --sandbox read-only --ephemeral --color never \
  -C "$CHECK_DIR" -m "$MODEL" -o "$ANSWER" \
  'Connectivity test only. Do not use any tools, read any files, or run any commands. Reply with exactly this single token: CONNECTED_OK'
grep -q 'CONNECTED_OK' "$ANSWER" || fail "Codex не подтвердил подключение через роутер."
log "Codex получил тестовый ответ через выданный доступ."

CONFIG_WRITER="$TMP/write-paseo-config.js"
cat > "$CONFIG_WRITER" <<'JS'
const fs = require('fs');
const [configPath, codexBin, codexHome, endpoint, model, keyPath, providerId, label] = process.argv.slice(2);
let cfg = {};
if (fs.existsSync(configPath)) {
  const txt = fs.readFileSync(configPath, 'utf8').trim();
  if (txt) cfg = JSON.parse(txt);
}
if (!cfg || typeof cfg !== 'object' || Array.isArray(cfg)) cfg = {};
if (!Object.prototype.hasOwnProperty.call(cfg, 'version')) cfg.version = 1;
if (!cfg.agents || typeof cfg.agents !== 'object' || Array.isArray(cfg.agents)) cfg.agents = {};
if (!cfg.agents.providers || typeof cfg.agents.providers !== 'object' || Array.isArray(cfg.agents.providers)) cfg.agents.providers = {};
const key = fs.readFileSync(keyPath, 'utf8').trim();
cfg.agents.providers[providerId] = {
  extends: 'codex',
  label,
  description: 'Доступ через роутер Юрия Курилова',
  command: [codexBin],
  env: {
    OPENAI_API_KEY: key,
    OPENAI_BASE_URL: endpoint,
    CODEX_HOME: codexHome
  },
  models: [{ id: model, label: model, isDefault: true }]
};
const tmp = configPath + '.tmp-' + process.pid;
fs.writeFileSync(tmp, JSON.stringify(cfg, null, 2) + '\n', { mode: 0o600 });
fs.renameSync(tmp, configPath);
JS

if [[ -f "$PASEO_CONFIG" ]]; then
  cp -p "$PASEO_CONFIG" "$PASEO_CONFIG.before-codex-yury-$(date '+%Y%m%d-%H%M%S').bak"
fi
ELECTRON_RUN_AS_NODE=1 "$NODE_HELPER" "$CONFIG_WRITER" "$PASEO_CONFIG" "$CODEX_BIN" "$CODEX_HOME_DIR" "$ENDPOINT" "$MODEL" "$TMP/key.txt" "$PROVIDER_ID" "$PROVIDER_LABEL"
chmod 600 "$PASEO_CONFIG"
log "Провайдер сохранен в Paseo."

paseo_cli() {
  env ELECTRON_RUN_AS_NODE=1 PASEO_NODE_ENV=production PASEO_HOME="$PASEO_HOME" \
    "$NODE_HELPER" --disable-warning=DEP0040 "$NODE_RUNNER" node-script "$CLI_ENTRY" "$@"
}

log "Запуск локального сервиса Paseo..."
paseo_cli daemon start --timeout 60 >/dev/null
STATUS_FILE="$TMP/daemon-status.json"
paseo_cli daemon status --json > "$STATUS_FILE"

JSON_FIELD="$TMP/json-field.js"
cat > "$JSON_FIELD" <<'JS'
const fs=require('fs');
const [p,k]=process.argv.slice(2);
const txt=fs.readFileSync(p,'utf8');
const pos=txt.search(/[\[{]/);
if(pos<0) process.exit(2);
const obj=JSON.parse(txt.slice(pos));
const v=obj[k];
if(v===undefined || v===null) process.exit(3);
process.stdout.write(String(v));
JS
SERVER_ID="$(ELECTRON_RUN_AS_NODE=1 "$NODE_HELPER" "$JSON_FIELD" "$STATUS_FILE" serverId)"
[[ -n "$SERVER_ID" ]] || fail "Paseo daemon не вернул serverId."
log "Локальный сервис Paseo готов: $SERVER_ID"

PROMPT='Автоматическая проверка подключения. Не используй инструменты и не изменяй файлы. Ответь одной строкой: Подключение готово.'
RUN_FILE="$TMP/agent-run.json"
if [[ "$CI_MODE" == "1" ]]; then
  log "CI: создаем workspace и выполняем полный тест через Paseo..."
  paseo_cli agent run "$PROMPT" --new-workspace local --cwd "$PROJECT_DIR" --title "Старт" --provider "$PROVIDER_ID" --model "$MODEL" --json > "$RUN_FILE"
  STATUS="$(ELECTRON_RUN_AS_NODE=1 "$NODE_HELPER" "$JSON_FIELD" "$RUN_FILE" status)"
  AGENT_ID="$(ELECTRON_RUN_AS_NODE=1 "$NODE_HELPER" "$JSON_FIELD" "$RUN_FILE" agentId)"
  [[ "$STATUS" == "completed" || "$STATUS" == "running" || "$STATUS" == "created" ]] || fail "Paseo вернул неожиданный статус агента: $STATUS"
  [[ -n "$AGENT_ID" ]] || fail "Paseo не вернул agentId."
  log "FULL TEST OK: macOS=$ARCH, router=OK, Codex=OK, Paseo=OK, agent=$AGENT_ID, status=$STATUS"
  exit 0
fi

log "Создаем готовый стартовый чат..."
paseo_cli agent run "$PROMPT" --background --new-workspace local --cwd "$PROJECT_DIR" --title "Старт" --provider "$PROVIDER_ID" --model "$MODEL" --json > "$RUN_FILE"
AGENT_ID="$(ELECTRON_RUN_AS_NODE=1 "$NODE_HELPER" "$JSON_FIELD" "$RUN_FILE" agentId)"
[[ -n "$AGENT_ID" ]] || fail "Paseo не вернул agentId стартового чата."

ENC_SERVER="$(printf '%s' "$SERVER_ID" | /usr/bin/python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip(), safe=""))' 2>/dev/null || printf '%s' "$SERVER_ID")"
ENC_AGENT="$(printf '%s' "$AGENT_ID" | /usr/bin/python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read().strip(), safe=""))' 2>/dev/null || printf '%s' "$AGENT_ID")"
LINK="paseo://h/$ENC_SERVER/agent/$ENC_AGENT"

log "Открываем Paseo сразу в стартовом чате проекта..."
open -n -g -a "$PASEO_APP" --args "$LINK"
log "Готово. Paseo должен открыться в проекте Codex-Yury-Kurilov и чате Старт."
