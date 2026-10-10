# Issiqlik Ta'minoti

Корпоративное Flutter-приложение для сотрудников предприятия «Хоразм Иссиқлик Манбаи», обслуживающего котельные и систему централизованного отопления Хорезмской области, Узбекистан.

## Возможности

- Список котельных и сведения об оборудовании.
- Журнал событий и смен, инструкции и схемы котельных.
- Рабочие уведомления и управление пользователями по ролям.
- Интерфейс на узбекском языке: кириллица и латиница.
- Офлайн-кэш Firestore и автоматическая синхронизация текстовых изменений после восстановления соединения.

## Технологии

- Flutter и Dart.
- Firebase Authentication, Cloud Firestore, Cloud Storage и Firebase Cloud Messaging.
- Riverpod для состояния и GoRouter для навигации.
- Firebase Cloud Functions для push-уведомлений и административного сброса пароля.

## Требования

- Flutter SDK, установленный в соответствии с ограничением Dart SDK в `pubspec.yaml`.
- Android SDK для сборки Android-приложения.
- Доступ к настроенному проекту Firebase.

## Запуск и проверки

```bash
flutter pub get
flutter run
flutter analyze
flutter test
flutter test test/firestore_sync_tracker_test.dart
flutter build apk --release
```

Для Android укажи локальные пути к Flutter и Android SDK в `android/local.properties`. Этот локальный файл намеренно исключён из Git.

## Firebase

Приложение использует клиентскую конфигурацию Firebase из `lib/firebase_options.dart` и `android/app/google-services.json`. Конфигурация относится к проекту Firebase владельца приложения; форки должны подставить конфигурацию собственного Firebase-проекта и развернуть для него правила Firestore из `firestore.rules`.

Клиентские API-ключи Firebase не заменяют правила безопасности. Не добавляй в репозиторий service-account JSON, закрытые ключи, пароли или ключи подписи Android. Развёртывание Cloud Functions требует подходящего плана Firebase и авторизации Firebase CLI.

> При первой регистрации в пустой базе Firebase пользователь получает роль администратора. Следующие новые пользователи создаются со статусом ожидания подтверждения администратором.

## Архитектура

- `lib/src/services/firebase_service.dart` — единая точка доступа приложения к Firebase и преобразования документов Firestore в модели.
- `lib/src/core/app_state.dart` — общие Riverpod-провайдеры и состояние приложения.
- `lib/src/domain/models/` — доменные модели.
- `lib/src/features/` — экраны и локальные провайдеры функций.
- `lib/app.dart` — маршруты и переходы между экранами.
- `functions/` — Cloud Functions.
- `firestore.rules` — правила доступа Firestore с запрещающим правилом по умолчанию.
