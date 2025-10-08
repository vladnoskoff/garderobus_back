# Подключение `permission_handler` в Flutter-приложении

Чтобы избавиться от ошибки вида `Target of URI doesn't exist: 'package:permission_handler/permission_handler.dart'`, добавьте пакет [`permission_handler`](https://pub.dev/packages/permission_handler) в зависимости проекта и выполните минимальную платформенную настройку.

## 1. Добавьте зависимость в `pubspec.yaml`

В секции `dependencies` пропишите:

```yaml
dependencies:
  permission_handler: ^11.1.0  # или любая актуальная версия с pub.dev
```

> Если хотите сделать это командой, выполните `flutter pub add permission_handler` в каталоге клиента.

После обновления `pubspec.yaml` обязательно запустите:

```bash
flutter pub get
```

## 2. Настройка Android

Откройте файл `android/app/src/main/AndroidManifest.xml` и убедитесь, что в блоке `<manifest>` присутствуют разрешения камеры и файловой системы:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

Для Android 13+ добавьте также `android.permission.READ_MEDIA_IMAGES`. При использовании `permission_handler` версии 11+ разрешение записи может не понадобиться, если вы работаете только с изображениями.

## 3. Настройка iOS

В файле `ios/Runner/Info.plist` добавьте ключи с описанием причин использования камеры и фотогалереи:

```xml
<key>NSCameraUsageDescription</key>
<string>Для добавления фотографий одежды требуется доступ к камере.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Для загрузки изображений одежды требуется доступ к фотогалерее.</string>
```

После этого выполните `cd ios && pod install` (или `flutter pub get`, который запустит `pod install` автоматически).

## 4. Очистка кеша (при необходимости)

Если после добавления пакета IDE продолжает подсвечивать ошибку, попробуйте:

```bash
flutter clean
flutter pub get
```

Затем перезапустите сборку/IDE. После этих шагов импорт `package:permission_handler/permission_handler.dart` станет доступен.
