class Setting {
  final String key;
  final String value;

  const Setting({required this.key, required this.value});

  factory Setting.fromMap(Map<String, dynamic> map) {
    return Setting(
      key: map['key'] as String,
      value: map['value'] as String? ?? '',
    );
  }

  Map<String, Object?> toMap() {
    return {'key': key, 'value': value};
  }
}
