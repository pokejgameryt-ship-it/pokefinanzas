class CurrencyConfig {
  final String code;
  final String symbol;
  final String name;
  final int decimalDigits;

  const CurrencyConfig({
    required this.code,
    required this.symbol,
    required this.name,
    required this.decimalDigits,
  });

  static const List<CurrencyConfig> available = [
    CurrencyConfig(code: 'EUR', symbol: '\u20ac', name: 'Euro', decimalDigits: 2),
    CurrencyConfig(code: 'USD', symbol: '\$', name: 'D\u00f3lar', decimalDigits: 2),
    CurrencyConfig(code: 'GBP', symbol: '\u00a3', name: 'Libra', decimalDigits: 2),
  ];

  static CurrencyConfig fromCode(String code) {
    return available.firstWhere(
      (c) => c.code == code,
      orElse: () => available.first,
    );
  }
}
