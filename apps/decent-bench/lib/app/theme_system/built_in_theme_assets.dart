import 'package:flutter/material.dart';

class BuiltInThemeAsset {
  const BuiltInThemeAsset({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.brightness,
  });

  final String id;
  final String name;
  final String assetPath;
  final Brightness brightness;
}

const List<BuiltInThemeAsset> kBuiltInThemeAssets = <BuiltInThemeAsset>[
  BuiltInThemeAsset(
    id: 'classic-dark',
    name: 'Classic Dark',
    assetPath: 'assets/themes/classic-dark.toml',
    brightness: Brightness.dark,
  ),
  BuiltInThemeAsset(
    id: 'classic-light',
    name: 'Classic Light',
    assetPath: 'assets/themes/classic-light.toml',
    brightness: Brightness.light,
  ),
];
