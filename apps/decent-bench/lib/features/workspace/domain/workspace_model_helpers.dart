int? asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

Map<String, Object?>? asStringMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map<Object?, Object?>) {
    return value.map((key, value) => MapEntry(key as String, value));
  }
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries) '${entry.key}': entry.value,
    };
  }
  return null;
}

List<Map<String, Object?>> asMapList(Object? value) {
  if (value is! List) {
    return const <Map<String, Object?>>[];
  }
  final maps = <Map<String, Object?>>[];
  for (final item in value) {
    final map = asStringMap(item);
    if (map != null) {
      maps.add(map);
    }
  }
  return maps;
}

List<String> asStringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return <String>[
    for (final item in value)
      if (item != null) '$item',
  ];
}
