class TransliterationEntry {
  final int? id;
  final String phoneticKey;
  final String gujaratiText;
  final bool isCustom; // 0=built-in, 1=custom

  const TransliterationEntry({
    this.id,
    required this.phoneticKey,
    required this.gujaratiText,
    required this.isCustom,
  });

  factory TransliterationEntry.fromMap(Map<String, dynamic> map) {
    return TransliterationEntry(
      id: map['id'] as int?,
      phoneticKey: map['phonetic_key'] as String,
      gujaratiText: map['gujarati_text'] as String,
      isCustom: (map['is_custom'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'phonetic_key': phoneticKey,
      'gujarati_text': gujaratiText,
      'is_custom': isCustom ? 1 : 0,
    };
  }
}
