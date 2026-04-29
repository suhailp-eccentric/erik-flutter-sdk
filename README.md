# erik_flutter_sdk

A Flutter SDK package scaffold with reusable Dart API surface and Android/iOS platform implementations.

## Project Shape

- `lib/`: public Dart API for Flutter apps
- `android/`: Android implementation under `com.eccentric.erik_flutter`
- `ios/`: iOS implementation and CocoaPods spec
- `example/`: sample Flutter app that consumes the SDK locally

## Use From Flutter

Add the package as a dependency:

```yaml
dependencies:
  erik_flutter_sdk:
    path: ../erik_flutter_sdk
```

Then import it:

```dart
import 'package:erik_flutter_sdk/erik_flutter_sdk.dart';
```

## Use From Native Apps

This repository is set up as a Flutter plugin package, which gives you:

- Android platform code in `android/` that can be evolved into a published Maven/AAR artifact
- iOS platform code in `ios/` plus `ios/erik_flutter_sdk.podspec` for CocoaPods-based distribution

If your goal is to embed Flutter UI inside an existing native app, the next step would be a Flutter `module` project. If your goal is a reusable SDK API for Flutter apps with native Android/iOS implementations behind it, this plugin layout is the right starting point.
