import '../models/savings_distribution.dart';

class ValidationException implements Exception {
  final String message;
  const ValidationException(this.message);
  @override
  String toString() => message;
}

class DistributionValidator {
  static void validatePercentages(SavingsDistribution dist) {
    double total = 0;
    for (final cat in dist.enabledUserCategories) {
      if (!cat.isFixed) total += cat.percentage ?? 0;
    }
    if (total > 100.5) {
      throw ValidationException(
        'La suma de porcentajes es ${total.toStringAsFixed(1)}%. '
        'No puede exceder 100%. Reduce los porcentajes en las categorías variables.',
      );
    }
  }

  static void validateNoDuplicateNames(SavingsDistribution dist) {
    final seen = <String>{};
    for (final cat in dist.categories) {
      if (cat.isAutomatic) continue;
      final key = cat.name.toLowerCase().trim();
      if (!seen.add(key)) {
        throw ValidationException('Categoría duplicada: "${cat.name}". '
            'Elimina o renombra una de ellas.');
      }
    }
  }

  static void validateBudgetFitsIncome(SavingsDistribution dist) {
    if (dist.monthlyIncome <= 0) return;
    if (dist.totalBudget > dist.monthlyIncome * 1.01) {
      throw ValidationException(
        'El presupuesto total (${dist.totalBudget.toStringAsFixed(2)}) '
        'excede los ingresos (${dist.monthlyIncome.toStringAsFixed(2)}). '
        'Reduce los montos fijos o porcentajes.',
      );
    }
  }

  static void validateAll(SavingsDistribution dist) {
    validateNoDuplicateNames(dist);
    validatePercentages(dist);
    validateBudgetFitsIncome(dist);
  }
}
