import 'dart:math' as math;

import 'package:erik_flutter_sdk/erik_flutter_sdk.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const TataEvDetailsScreen(),
    );
  }
}

enum VehicleView { exterior, interior }

class _ColorOption {
  const _ColorOption({required this.jsName, required this.label});

  final String jsName;
  final String label;
}

class TataEvDetailsScreen extends StatefulWidget {
  const TataEvDetailsScreen({super.key});

  @override
  State<TataEvDetailsScreen> createState() => _TataEvDetailsScreenState();
}

class _TataEvDetailsScreenState extends State<TataEvDetailsScreen> {
  static const _colorOptions = [
    _ColorOption(jsName: 'Rishikesh_Rapids', label: 'Rishikesh Rapids'),
    _ColorOption(jsName: 'Oxide', label: 'Oxide'),
    _ColorOption(jsName: 'Pure_Grey', label: 'Pure Grey'),
    _ColorOption(jsName: 'Coorg_Clouds', label: 'Coorg Clouds'),
    _ColorOption(jsName: 'Pristine_White', label: 'Pristine White'),
    _ColorOption(jsName: 'Andaman_Adventure', label: 'Andaman Adventure'),
    _ColorOption(jsName: 'Nainital_Nocturne', label: 'Nainital Nocturne'),
    _ColorOption(jsName: 'Bengal_Rouge_Tinted', label: 'Bengal Rouge Tinted'),
  ];

  final ErikViewController _erikController = ErikViewController();

  VehicleView _selectedView = VehicleView.exterior;
  bool _lightsOn = false;
  bool _didApplyInitialLights = false;
  String _selectedColorName = _colorOptions.first.jsName;
  final Map<ErikDoor, bool> _doorStates = {
    ErikDoor.frontLeft: false,
    ErikDoor.frontRight: false,
    ErikDoor.rearLeft: false,
    ErikDoor.rearRight: false,
    ErikDoor.boot: false,
    ErikDoor.sunroof: false,
  };

  bool get _allDoorsOpen => [
    ErikDoor.frontLeft,
    ErikDoor.frontRight,
    ErikDoor.rearLeft,
    ErikDoor.rearRight,
    ErikDoor.boot,
  ].every((door) => _doorStates[door] ?? false);

  _ColorOption get _selectedColor =>
      _colorOptions.firstWhere((option) => option.jsName == _selectedColorName);

  @override
  void initState() {
    super.initState();
    _erikController.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    _erikController.removeListener(_handleControllerChanged);
    _erikController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!_erikController.isReady || _didApplyInitialLights) {
      return;
    }

    _didApplyInitialLights = true;
    _turnLightsOnByDefault();
  }

  Future<void> _runSdkAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Action failed: $error')));
    }
  }

  Future<void> _setVehicleView(VehicleView view) async {
    if (_selectedView == view) {
      return;
    }

    setState(() {
      _selectedView = view;
    });

    await _runSdkAction(() {
      return view == VehicleView.interior
          ? _erikController.goInterior()
          : _erikController.goExterior();
    });
  }

  Future<void> _setDoorOpen(ErikDoor door, bool open) async {
    if (_doorStates[door] == open) {
      return;
    }

    setState(() {
      _doorStates[door] = open;
    });

    await _runSdkAction(() {
      return open
          ? _erikController.openDoor(door)
          : _erikController.closeDoor(door);
    });
  }

  Future<void> _setAllDoorsOpen(bool open) async {
    if (_allDoorsOpen == open) {
      return;
    }

    setState(() {
      for (final door in [
        ErikDoor.frontLeft,
        ErikDoor.frontRight,
        ErikDoor.rearLeft,
        ErikDoor.rearRight,
        ErikDoor.boot,
      ]) {
        _doorStates[door] = open;
      }
    });

    await _runSdkAction(() => _erikController.setAllDoorsOpen(open));
  }

  Future<void> _toggleLights() async {
    var toggled = false;

    await _runSdkAction(() async {
      await _erikController.toggleLights();
      toggled = true;
    });

    if (!mounted || !toggled) {
      return;
    }

    setState(() {
      _lightsOn = !_lightsOn;
    });
  }

  Future<void> _turnLightsOnByDefault() async {
    var toggled = false;

    await _runSdkAction(() async {
      await _erikController.toggleLights();
      toggled = true;
    });

    if (!mounted || !toggled) {
      _didApplyInitialLights = false;
      return;
    }

    setState(() {
      _lightsOn = true;
    });
  }

  Future<void> _showColorPicker() async {
    final selected = await showModalBottomSheet<_ColorOption>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Color',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _colorOptions.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final option = _colorOptions[index];
                      final isSelected = option.jsName == _selectedColor.jsName;
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.of(context).pop(option),
                        child: Ink(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.black
                                  : const Color(0xFFD8DDE3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F7FA),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFCFD4DA),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.palette_outlined,
                                  size: 18,
                                  color: Color(0xFF5B6572),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      option.label,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Tap to apply this finish',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle,
                                  size: 20,
                                  color: Colors.black,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || selected.jsName == _selectedColorName) {
      return;
    }

    setState(() {
      _selectedColorName = selected.jsName;
    });

    await _runSdkAction(() => _erikController.setColor(selected.jsName));
  }

  Future<void> _skipIntro() async {
    await _runSdkAction(_erikController.skipIntro);
  }

  @override
  Widget build(BuildContext context) {
    const minSheetFraction = 0.18;
    const maxSheetFraction = 0.53;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = constraints.maxWidth / 411.0;
            final maxSheetFractionForViewport = math
                .min(maxSheetFraction, 560.0 / constraints.maxHeight)
                .toDouble();
            final collapsedSheetHeight =
                constraints.maxHeight * minSheetFraction;
            final contentBottomPadding = math.max(
              0.0,
              collapsedSheetHeight - 18.0,
            );

            return AnimatedBuilder(
              animation: _erikController,
              builder: (context, _) {
                return Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: contentBottomPadding),
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: 18.0 * scale),
                            child: Center(
                              child: SizedBox(
                                width: 148.0 * scale,
                                height: 61.0 * scale,
                                child: Image.asset(
                                  'assets/images/tata_logo.png',
                                  fit: BoxFit.contain,
                                  alignment: Alignment.center,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 18.0 * scale),
                          Expanded(
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: AspectRatio(
                                      aspectRatio: 72 / 50,
                                      child: ErikView(
                                        controller: _erikController,
                                      ),
                                    ),
                                  ),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    child:
                                        _erikController.isIntroAnimationPlaying
                                        ? Padding(
                                            key: const ValueKey(
                                              'skip-intro-button',
                                            ),
                                            padding: EdgeInsets.only(
                                              top: 14.0 * scale,
                                            ),
                                            child: FilledButton.tonal(
                                              onPressed: _skipIntro,
                                              style: FilledButton.styleFrom(
                                                foregroundColor: Colors.black,
                                                backgroundColor: const Color(
                                                  0xFFF1F3F5,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 12,
                                                    ),
                                              ),
                                              child: const Text('Skip'),
                                            ),
                                          )
                                        : const SizedBox.shrink(
                                            key: ValueKey('skip-intro-hidden'),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SizedBox(
                        height: constraints.maxHeight,
                        child: DraggableScrollableSheet(
                          initialChildSize: minSheetFraction,
                          minChildSize: minSheetFraction,
                          maxChildSize: maxSheetFractionForViewport,
                          snap: true,
                          snapSizes: [
                            minSheetFraction,
                            maxSheetFractionForViewport,
                          ],
                          builder: (context, scrollController) {
                            return _ActionBottomSheet(
                              scrollController: scrollController,
                              isReady: _erikController.isReady,
                              selectedView: _selectedView,
                              allDoorsOpen: _allDoorsOpen,
                              doorStates: _doorStates,
                              lightsOn: _lightsOn,
                              selectedColor: _selectedColor,
                              onVehicleViewChanged: _setVehicleView,
                              onAllDoorsChanged: _setAllDoorsOpen,
                              onDoorChanged: _setDoorOpen,
                              onLightsPressed: _toggleLights,
                              onColorPressed: _showColorPicker,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ActionBottomSheet extends StatelessWidget {
  const _ActionBottomSheet({
    required this.scrollController,
    required this.isReady,
    required this.selectedView,
    required this.allDoorsOpen,
    required this.doorStates,
    required this.lightsOn,
    required this.selectedColor,
    required this.onVehicleViewChanged,
    required this.onAllDoorsChanged,
    required this.onDoorChanged,
    required this.onLightsPressed,
    required this.onColorPressed,
  });

  final ScrollController scrollController;
  final bool isReady;
  final VehicleView selectedView;
  final bool allDoorsOpen;
  final Map<ErikDoor, bool> doorStates;
  final bool lightsOn;
  final _ColorOption selectedColor;
  final ValueChanged<VehicleView> onVehicleViewChanged;
  final ValueChanged<bool> onAllDoorsChanged;
  final Future<void> Function(ErikDoor door, bool open) onDoorChanged;
  final Future<void> Function() onLightsPressed;
  final Future<void> Function() onColorPressed;

  @override
  Widget build(BuildContext context) {
    const panelColor = Color(0xFFF5F5F5);
    const borderColor = Color(0xFFB1B8C2);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Opacity(
            opacity: isReady ? 1 : 0.7,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              children: [
                Center(
                  child: Container(
                    width: 52,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0D5DD),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Vehicle Controls',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black.withValues(alpha: 0.88),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isReady
                      ? 'Interact with the controls below'
                      : 'Waiting for the 3D scene to finish loading.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withValues(alpha: 0.54),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 1, color: borderColor),
                const SizedBox(height: 12),
                const _GroupHeader(title: 'View'),
                _ActionToggleRow(
                  title: 'Vehicle View',
                  positiveLabel: 'EXTERIOR',
                  negativeLabel: 'INTERIOR',
                  isPositive: selectedView == VehicleView.exterior,
                  onChanged: (value) => onVehicleViewChanged(
                    value ? VehicleView.exterior : VehicleView.interior,
                  ),
                ),
                const SizedBox(height: 18),
                const _GroupHeader(title: 'Doors'),
                _ActionToggleRow(
                  title: 'All Doors',
                  positiveLabel: 'OPEN',
                  negativeLabel: 'CLOSE',
                  isPositive: allDoorsOpen,
                  onChanged: onAllDoorsChanged,
                ),
                const SizedBox(height: 10),
                for (final door in [
                  ErikDoor.frontLeft,
                  ErikDoor.frontRight,
                  ErikDoor.rearLeft,
                  ErikDoor.rearRight,
                  ErikDoor.boot,
                  ErikDoor.sunroof,
                ]) ...[
                  _ActionToggleRow(
                    title: door._label,
                    positiveLabel: 'OPEN',
                    negativeLabel: 'CLOSE',
                    isPositive: doorStates[door] ?? false,
                    onChanged: (value) => onDoorChanged(door, value),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 8),
                const _GroupHeader(title: 'Lights'),
                _ActionStatusRow(
                  title: 'Scene Lights',
                  value: lightsOn ? 'ON' : 'OFF',
                  buttonLabel: 'TOGGLE',
                  onPressed: onLightsPressed,
                ),
                const SizedBox(height: 18),
                const _GroupHeader(title: 'Colors'),
                _ActionValueRow(
                  title: 'Paint Finish',
                  value: selectedColor.label,
                  buttonLabel: 'SELECT',
                  onPressed: onColorPressed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: Colors.black.withValues(alpha: 0.48),
        ),
      ),
    );
  }
}

class _ActionToggleRow extends StatelessWidget {
  const _ActionToggleRow({
    required this.title,
    required this.positiveLabel,
    required this.negativeLabel,
    required this.isPositive,
    required this.onChanged,
  });

  final String title;
  final String positiveLabel;
  final String negativeLabel;
  final bool isPositive;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _BooleanPillControl(
          positiveLabel: positiveLabel,
          negativeLabel: negativeLabel,
          isPositive: isPositive,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ActionStatusRow extends StatelessWidget {
  const _ActionStatusRow({
    required this.title,
    required this.value,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String value;
  final String buttonLabel;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.64),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            buttonLabel,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _ActionValueRow extends StatelessWidget {
  const _ActionValueRow({
    required this.title,
    required this.value,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String value;
  final String buttonLabel;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                    ),
                    child: const Icon(
                      Icons.palette_outlined,
                      size: 16,
                      color: Color(0xFF5B6572),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    value,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.64),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            buttonLabel,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _BooleanPillControl extends StatelessWidget {
  const _BooleanPillControl({
    required this.positiveLabel,
    required this.negativeLabel,
    required this.isPositive,
    required this.onChanged,
  });

  final String positiveLabel;
  final String negativeLabel;
  final bool isPositive;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 188,
      height: 36,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD6DBE1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BooleanPill(
            label: positiveLabel,
            selected: isPositive,
            onTap: () => onChanged(true),
          ),
          _BooleanPill(
            label: negativeLabel,
            selected: !isPositive,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _BooleanPill extends StatelessWidget {
  const _BooleanPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 88,
        height: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF5B5B5B),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

extension on ErikDoor {
  String get _label {
    switch (this) {
      case ErikDoor.frontLeft:
        return 'Front Left Door';
      case ErikDoor.frontRight:
        return 'Front Right Door';
      case ErikDoor.rearLeft:
        return 'Rear Left Door';
      case ErikDoor.rearRight:
        return 'Rear Right Door';
      case ErikDoor.boot:
        return 'Boot Door';
      case ErikDoor.sunroof:
        return 'Sunroof';
    }
  }
}
