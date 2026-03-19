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

### 3.1 Info.plist

В файле `ios/Runner/Info.plist` необходимо указать все причины обращения к фото и камере. Для корректной работы с новой политикой iOS 14+ добавьте **оба** ключа для фотогалереи:

```xml
<key>NSCameraUsageDescription</key>
<string>Для добавления фотографий одежды требуется доступ к камере.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Для выбора изображений одежды требуется доступ к вашей фотогалерее.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Для сохранения обработанных изображений гардероба требуется разрешение на добавление фото.</string>
<key>NSFaceIDUsageDescription</key>
<string>Face ID используется для быстрого входа в приложение вместо PIN-кода.</string>
```

Без `NSPhotoLibraryAddUsageDescription` iOS не добавит пункт «Фото» в настройках приложения и не покажет системный диалог при запросе `Permission.photos`, из-за чего кнопки «Камера»/«Галерея» останутся нерабочими.

### 3.2 Подключение нужных фич в Podfile

Плагин `permission_handler` на iOS собирает только те разрешения, которые явно включены в `ios/Podfile`. Откройте файл и в блоке `post_install` добавьте флаги для камеры и фотогалереи. **Не удаляйте** строку `flutter_additional_ios_build_settings(target)`, которая подключает генерацию плагинов Flutter — без неё Xcode не найдёт зависимости:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)

    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_CAMERA=1',
        'PERMISSION_PHOTOS=1'
      ]
    end
  end
end
```

После обновления `Info.plist` и `Podfile` выполните `cd ios && pod install` (или `flutter pub get`, который автоматически вызовет `pod install`).

## 4. Очистка кеша (при необходимости)

Если после добавления пакета IDE продолжает подсвечивать ошибку, попробуйте:

```bash
flutter clean
flutter pub get
```

Затем перезапустите сборку/IDE. После этих шагов импорт `package:permission_handler/permission_handler.dart` станет доступен.
