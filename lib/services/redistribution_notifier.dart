import 'package:flutter/foundation.dart';

class RedistributionNotifier {
  static final RedistributionNotifier instance = RedistributionNotifier._();
  RedistributionNotifier._();

  final ValueNotifier<int> redistributionChanged = ValueNotifier<int>(0);

  void notify() {
    redistributionChanged.value++;
  }
}
