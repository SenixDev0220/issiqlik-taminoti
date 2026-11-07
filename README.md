# Issiqlik Ta'minoti

[Русский](README.md) · [O'zbekcha](README_UZ.md) · [English](README_EN.md)

Flutter-приложение для сотрудников отопительного предприятия: котельные, оборудование, журнал событий, инструкции, смены и уведомления. Интерфейс — узбекская кириллица и латиница, светлая/тёмная тема, адаптивный экран и Liquid Glass навигация.

## Текущая архитектура (1.2.1)

- Firebase Authentication + Cloud Firestore на Spark; для основных текстовых операций Cloud Functions и Blaze не требуются.
- Регистрация всегда создаёт **member/pending**. Первого администратора назначает доверенный оператор по явно выбранному Auth UID, не первый зарегистрировавшийся пользователь.
- Права берутся из `access/{uid}` и проверяются Firebase Rules. `users` — приватный профиль; `employeeDirectory` — управленческая проекция; `userProfiles` — ограниченный справочник.
- Журнал имеет неизменяемую историю. Справочники и смены **архивируются только администратором**, физическое удаление клиентами запрещено. Предыдущая запись сохраняется в `history/archive`.
- Сообщения доступны внутри приложения и только адресату. Фоновая FCM-доставка, загрузка конфиденциальных файлов и административный сброс пароля из приложения не поддерживаются в текущем Spark-варианте.
- Язык и тема сохраняются локально через SharedPreferences; пароли и полномочия туда не записываются. Постоянный Firestore-кэш приватных данных отключён.
- Некорректные записи не обрушивают весь список: пропускаются с предупреждением. Повреждённые полномочия всегда означают отказ, а не значение по умолчанию.

## Запуск и проверки

Требуются Flutter 3.47.6 / Dart 3.13+, Android SDK, Java 21 для Firebase Emulator Suite и Node 24.12+ для security-инструментов.

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test
npm ci --ignore-scripts
npm run test:security
npm run test:operator
```

На Windows без desktop symlink privileges перед Flutter-командами в Git Bash можно задать `FLUTTER_WINDOWS=false FLUTTER_LINUX=false`. Не продолжайте сборку через `--no-pub` после неудачной генерации плагинов: Android-регистратор обязателен и проверяется Gradle.

CI выполняет анализ, Flutter-тесты, сборку **test/debug APK**, эмуляторные проверки правил, тесты операторского инструмента, npm audit и **обязательный Gitleaks-скан истории/исходников**. Actions и бинарный сканер закреплены версиями/контрольными суммами.

## Release

```sh
flutter build apk --release --obfuscate --split-debug-info=build/symbols/1.2.1
```

Для release нужен локальный `android/key.properties`: `storeFile`, `storePassword`, `keyAlias`, `keyPassword`. Файл и keystore должны храниться приватно и не попадать в Git. Debug signing fallback отсутствует. Настройка текущей Android-иконки: `flutter_launcher_icons_android.yaml`.

## Production и оператор

Владелец ранее явно выбрал и активировал административный аккаунт; UID/личные данные не вшиты в код. Для воспроизводимого bootstrap и нового окружения используйте [tools/operator.cjs](tools/operator.cjs) с ADC, явным project/UID, проверенным профилем и dry-run. Подробно: [security/OPERATOR.md](security/OPERATOR.md).

Новые правила должны публиковаться согласованно с версией клиента. Не открывайте `allow read, write: if true`, не сбрасывайте session cutoff при разбане и не копируйте непроверенные legacy-роли в доверенную коллекцию. После разблокировки нужен повторный вход.

[Результаты и границы аудита](security/README.md) · [Контракт данных](security/contract.md)

Старые seed-данные и схемы удалены из текущего дерева/сборки после приватного резервного копирования. Это не удаляет ранее опубликованные копии из Git history. Исторические документы не мигрируются с выдуманными датами или получателями.

## Ограничения

Android — настроенная основная платформа; адаптивность не означает проверку всех устройств. Для iOS/web/desktop нужны собственные Firebase-конфигурации и platform release-тесты. App Check enforcement и API-key restrictions требуют отдельной проверки Console. Rules-only подход не заменяет Auth token revocation, anti-abuse квоты, резервное копирование и антивирусную проверку документов. Все ограничения и ручные действия указаны в security-документации.

Лицензия: [MIT](LICENSE).
