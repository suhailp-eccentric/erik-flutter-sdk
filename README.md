# erik_flutter_sdk

Flutter SDK for embedding the Erik vehicle experience inside a Flutter app on Android and iOS.

The package includes the Erik runtime, packaged assets, and a small Dart controller API for common actions such as switching views, opening doors, toggling lights, and changing vehicle color.

## What the SDK includes

- `ErikView`: widget that hosts the bundled Erik experience
- `ErikViewController`: controller for driving the experience from Flutter
- Bundled Erik runtime assets
- Native plugin hooks for Android and iOS

## Platform support

- Android
- iOS

`ErikView` is currently supported on Android and iOS. On Android emulators, the SDK shows a fallback message because the experience requires a WebGL-capable environment.

## Installation

Add the package to your Flutter app:

```yaml
dependencies:
  erik_flutter_sdk:
    git:
      url: https://suhailp-eccentric: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@github.com/suhailp-eccentric/erik-flutter-sdk.git
```

Then fetch packages:

```bash
flutter pub get
```

Import the SDK:

```dart
import 'package:erik_flutter_sdk/erik_flutter_sdk.dart';
```

## Android setup

The SDK uses local loopback transport internally on Android, so your host app should allow local cleartext traffic.

Add internet permission in your Android manifest if your app does not already have it:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

Enable cleartext traffic on your `<application>`:

```xml
<application
    android:usesCleartextTraffic="true" />
```

The included example enables cleartext traffic in its main manifest and includes `INTERNET` in its Android app manifests.

## Basic usage

Create a controller, pass it into `ErikView`, and use the controller from your Flutter UI.

```dart
import 'package:erik_flutter_sdk/erik_flutter_sdk.dart';
import 'package:flutter/material.dart';

class ErikDemoPage extends StatefulWidget {
  const ErikDemoPage({super.key});

  @override
  State<ErikDemoPage> createState() => _ErikDemoPageState();
}

class _ErikDemoPageState extends State<ErikDemoPage> {
  final ErikViewController _erikController = ErikViewController();
  bool _lightsOn = false;

  @override
  void dispose() {
    _erikController.dispose();
    super.dispose();
  }

  Future<void> _toggleLights() async {
    try {
      await _erikController.toggleLights();
      setState(() {
        _lightsOn = !_lightsOn;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Action failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ErikView(controller: _erikController),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton(
                  onPressed: () => _erikController.goExterior(),
                  child: const Text('Exterior'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () => _erikController.goInterior(),
                  child: const Text('Interior'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _toggleLights,
                  child: Text(_lightsOn ? 'Lights Off' : 'Lights On'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
```

## Waiting until the experience is ready

Controller methods internally wait until the Erik experience is ready, so you can call actions directly in response to button taps.

If you want to apply an initial state as soon as Erik finishes loading, listen to `ErikViewController` and react when `isReady` becomes `true`:

```dart
late final ErikViewController _erikController;
bool _didApplyInitialState = false;

@override
void initState() {
  super.initState();
  _erikController = ErikViewController()..addListener(_handleErikChanged);
}

void _handleErikChanged() {
  if (!_erikController.isReady || _didApplyInitialState) {
    return;
  }

  _didApplyInitialState = true;
  _erikController.toggleLights();
}

@override
void dispose() {
  _erikController.removeListener(_handleErikChanged);
  _erikController.dispose();
  super.dispose();
}
```

## Widget API

### `ErikView`

```dart
ErikView(
  controller: controller,
)
```

- `controller`: required `ErikViewController`

## Controller API

### Readiness

- `isReady`: `true` once the Erik experience is ready to receive commands

### View switching

- `goInterior()`
- `goExterior()`

### Doors and animations

- `openDoor(ErikDoor door)`
- `closeDoor(ErikDoor door)`
- `playDoor(ErikDoor door, ErikAnimationDirection direction)`
- `openAllDoors()`
- `closeAllDoors()`
- `setAllDoorsOpen(bool open)`

Available doors:

- `ErikDoor.frontLeft`
- `ErikDoor.frontRight`
- `ErikDoor.rearLeft`
- `ErikDoor.rearRight`
- `ErikDoor.boot`
- `ErikDoor.sunroof`

### Vehicle state

- `toggleLights()`
- `setColor(String colorName)`

## Available colors

The SDK exports `erikAvailableColors`:

```dart
const List<String> erikAvailableColors = [
  'Rishikesh_Rapids',
  'Oxide',
  'Pure_Grey',
  'Coorg_Clouds',
  'Pristine_White',
  'Andaman_Adventure',
  'Nainital_Nocturne',
  'Bengal_Rouge_Tinted',
];
```

Example:

```dart
await _erikController.setColor('Oxide');
```

## Note
A sample flutter application is included with the SDK.