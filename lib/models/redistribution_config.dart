class RedistributionConfig {
  final int? redistributionDay; // null = use global day
  final Map<String, double> redistributionPercentages; // destination category -> percentage

  const RedistributionConfig({
    this.redistributionDay,
    this.redistributionPercentages = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'redistributionDay': redistributionDay,
      'redistributionPercentages': redistributionPercentages,
    };
  }

  factory RedistributionConfig.fromMap(Map<String, dynamic> map) {
    return RedistributionConfig(
      redistributionDay: map['redistributionDay'],
      redistributionPercentages: (map['redistributionPercentages'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          const {},
    );
  }

  RedistributionConfig copyWith({
    int? redistributionDay,
    Map<String, double>? redistributionPercentages,
  }) {
    return RedistributionConfig(
      redistributionDay: redistributionDay ?? this.redistributionDay,
      redistributionPercentages: redistributionPercentages ?? this.redistributionPercentages,
    );
  }
}
