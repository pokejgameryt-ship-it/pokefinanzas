import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/currency_config.dart';

class Formatters {
  static String _currencySymbol = '\u20ac';
  static String _currencyCode = 'EUR';
  static int _decimalDigits = 2;

  static String get currencySymbol => _currencySymbol;
  static String get currencyCode => _currencyCode;

  static final dateFormat = DateFormat('dd/MM/yyyy');
  static final timeFormat = DateFormat('HH:mm');
  static final dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final monthYearFormat = DateFormat('MMMM yyyy', 'es_ES');
  static final dayFormat = DateFormat('EEEE dd', 'es_ES');
  static final shortDateFormat = DateFormat('dd MMM', 'es_ES');
  static final shortDateTimeFormat = DateFormat('dd MMM HH:mm', 'es_ES');

  static Future<void> loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    _currencyCode = prefs.getString('currencyCode') ?? 'EUR';
    final config = CurrencyConfig.fromCode(_currencyCode);
    _currencySymbol = config.symbol;
    _decimalDigits = config.decimalDigits;
  }

  static Future<void> setCurrency(String code) async {
    _currencyCode = code;
    final config = CurrencyConfig.fromCode(code);
    _currencySymbol = config.symbol;
    _decimalDigits = config.decimalDigits;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currencyCode', code);
  }

  static NumberFormat get _currencyFormat => NumberFormat.currency(
    locale: 'es_ES',
    symbol: _currencySymbol,
    decimalDigits: _decimalDigits,
  );

  static String formatCurrency(double amount) {
    return _currencyFormat.format(amount);
  }

  static String formatDate(DateTime date) {
    return dateFormat.format(date);
  }

  static String formatTime(DateTime date) {
    return timeFormat.format(date);
  }

  static String formatDateTime(DateTime date) {
    return dateTimeFormat.format(date);
  }

  static String formatMonthYear(DateTime date) {
    return monthYearFormat.format(date);
  }

  static String formatDay(DateTime date) {
    return dayFormat.format(date);
  }

  static String formatShortDate(DateTime date) {
    return shortDateFormat.format(date);
  }

  static String formatShortDateTime(DateTime date) {
    return shortDateTimeFormat.format(date);
  }
}
