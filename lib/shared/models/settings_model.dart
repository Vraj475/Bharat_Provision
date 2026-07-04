class SettingEntry {
  final String key;
  final String value;

  const SettingEntry({required this.key, required this.value});

  factory SettingEntry.fromMap(Map<String, dynamic> map) {
    return SettingEntry(
      key: map['key'] as String,
      value: map['value'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {'key': key, 'value': value};
  }
}
