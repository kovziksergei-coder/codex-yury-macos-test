# Codex Yury Kurilov - macOS test

Тестовая macOS-сборка подключения Codex/Paseo к роутеру Юрия Курилова.

## Что уже проверяется автоматически

- macOS 15 Apple Silicon (M1)
- macOS 15 Intel
- загрузка официального Codex 0.160.0
- проверка SHA-256
- запуск Codex
- загрузка официального Paseo 0.10.3
- проверка SHA-256
- распаковка Paseo.app
- синтаксис установщика
- сборка ZIP-артефакта для macOS

## Полный тест

Для полного теста роутера, Codex и Paseo нужен GitHub Actions secret:

`KURILOV_API_KEY`

Добавлять ключ в код или README нельзя. После добавления секрета следующий запуск workflow выполнит полный тест на чистом macOS runner.

## Файл для Mac

`Connect-Codex-Yury-Kurilov.command`

При обычном запуске он запрашивает ключ в скрытом системном окне, готовит Codex и Paseo, создает проект `Codex-Yury-Kurilov` и открывает стартовый чат.
