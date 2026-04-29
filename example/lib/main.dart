import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

enum DisplayMode { light, dark }

class TataEvDetailsScreen extends StatefulWidget {
  const TataEvDetailsScreen({super.key});

  @override
  State<TataEvDetailsScreen> createState() => _TataEvDetailsScreenState();
}

class _TataEvDetailsScreenState extends State<TataEvDetailsScreen> {
  VehicleView _selectedView = VehicleView.exterior;
  DisplayMode _selectedMode = DisplayMode.light;
  bool _doorsOpen = true;
  bool _lightsOn = true;

  @override
  Widget build(BuildContext context) {
    const panelColor = Color(0xFFF5F5F5);
    const borderColor = Color(0xFFB1B8C2);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = constraints.maxWidth / 411.0;
            final designHeight = 818.0 * scale;
            final contentHeight = math.max(constraints.maxHeight, designHeight);
            final panelHeight = 192.0 * scale;
            final panelTop = contentHeight - panelHeight;

            return SingleChildScrollView(
              child: SizedBox(
                width: constraints.maxWidth,
                height: contentHeight,
                child: Stack(
                  children: [
                    Positioned(
                      top: 196.0 * scale,
                      left: 0,
                      right: 0,
                      child: SizedBox(
                        height: 323.0 * scale,
                        child: ColoredBox(
                          color: panelColor,
                          child: Image.asset(
                            'assets/images/car.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20.0 * scale,
                      top: 32.0 * scale,
                      child: SizedBox(
                        width: 148.0 * scale,
                        height: 61.0 * scale,
                        child: Image.asset(
                          'assets/images/tata_logo.png',
                          fit: BoxFit.contain,
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: panelTop,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: panelColor,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.10),
                              blurRadius: 10,
                              spreadRadius: 5,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            20.0 * scale,
                            21.0 * scale,
                            20.0 * scale,
                            14.0 * scale,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _TextSegmentedControl(
                                      options: const [
                                        'Exterior View',
                                        'Interior View',
                                      ],
                                      selectedIndex: _selectedView.index,
                                      onSelected: (index) {
                                        setState(() {
                                          _selectedView =
                                              VehicleView.values[index];
                                        });
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 16.0 * scale),
                                  _IconSegmentedControl(
                                    selectedIndex: _selectedMode.index,
                                    onSelected: (index) {
                                      setState(() {
                                        _selectedMode =
                                            DisplayMode.values[index];
                                      });
                                    },
                                  ),
                                ],
                              ),
                              SizedBox(height: 20.0 * scale),
                              const Divider(
                                height: 1,
                                thickness: 1,
                                color: borderColor,
                              ),
                              SizedBox(height: 19.0 * scale),
                              _ActionRow(
                                title: 'Toggle Doors',
                                iconPath: 'assets/images/door_open.png',
                                positiveLabel: 'OPEN',
                                negativeLabel: 'CLOSE',
                                isPositive: _doorsOpen,
                                onChanged: (value) {
                                  setState(() {
                                    _doorsOpen = value;
                                  });
                                },
                              ),
                              SizedBox(height: 12.0 * scale),
                              _ActionRow(
                                title: 'Toggle Lights',
                                iconPath: 'assets/images/backlight_low.png',
                                positiveLabel: 'ON',
                                negativeLabel: 'OFF',
                                isPositive: _lightsOn,
                                onChanged: (value) {
                                  setState(() {
                                    _lightsOn = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TextSegmentedControl extends StatelessWidget {
  const _TextSegmentedControl({
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFB1B8C2);

    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        children: List.generate(options.length, (index) {
          final isSelected = index == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(50),
                ),
                alignment: Alignment.center,
                child: Text(
                  options[index],
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF5B5B5B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _IconSegmentedControl extends StatelessWidget {
  const _IconSegmentedControl({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFB1B8C2);
    const selectedColor = Color(0xFFB1B8C2);
    const icons = [
      'assets/images/light_mode.png',
      'assets/images/dark_mode.png',
    ];

    return Container(
      width: 88,
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        children: List.generate(icons.length, (index) {
          final isSelected = index == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: isSelected ? selectedColor : Colors.white,
                  borderRadius: BorderRadius.circular(50),
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(icons[index], width: 16, height: 16),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    required this.iconPath,
    required this.positiveLabel,
    required this.negativeLabel,
    required this.isPositive,
    required this.onChanged,
  });

  final String title;
  final String iconPath;
  final String positiveLabel;
  final String negativeLabel;
  final bool isPositive;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: SvgPicture.asset(iconPath, width: 20, height: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w700,
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
      height: 32,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1EAF53) : Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF5B5B5B),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
