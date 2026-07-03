import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:finanzas_app/models/savings_distribution.dart';
import 'package:finanzas_app/validators/distribution_validator.dart';

const _uuid = Uuid();

SavingsDistribution _makeDist({
  double income = 3000,
  List<DistributionCategory>? cats,
}) {
  return SavingsDistribution(
    id: _uuid.v4(),
    month: 7,
    year: 2026,
    monthlyIncome: income,
    categories: cats ?? [
      DistributionCategory(name: 'Alquiler', isFixed: true, fixedAmount: 800, spentAmount: 800),
      DistributionCategory(name: 'Comida', isFixed: false, percentage: 25, spentAmount: 400),
      DistributionCategory(name: 'Ocio', isFixed: false, percentage: 15, spentAmount: 100),
    ],
  );
}

void main() {
  group('DistributionCategory.computeBudget', () {
    test('fixed category returns fixedAmount', () {
      final cat = DistributionCategory(name: 'Alquiler', isFixed: true, fixedAmount: 800);
      expect(cat.computeBudget(3000), 800);
    });

    test('variable category uses remaining after fixed', () {
      final cat = DistributionCategory(name: 'Comida', isFixed: false, percentage: 25);
      expect(cat.computeBudget(3000, totalFixed: 800), (3000 - 800) * 25 / 100);
    });

    test('variable category returns 0 when remaining <= 0', () {
      final cat = DistributionCategory(name: 'Comida', isFixed: false, percentage: 25);
      expect(cat.computeBudget(500, totalFixed: 800), 0);
    });

    test('disabled category returns 0', () {
      final cat = DistributionCategory(name: 'Alquiler', isFixed: true, fixedAmount: 800, isEnabled: false);
      expect(cat.computeBudget(3000), 0);
    });

    test('automatic category returns 0', () {
      final cat = DistributionCategory(name: 'Ahorro', isAutomatic: true);
      expect(cat.computeBudget(3000), 0);
    });
  });

  group('DistributionCategory.computeUnspent', () {
    test('returns budget - spent when positive', () {
      final cat = DistributionCategory(name: 'Comida', isFixed: false, percentage: 25, spentAmount: 200);
      final unspent = cat.computeUnspent(3000, totalFixed: 800);
      final budget = (3000 - 800) * 25 / 100;
      expect(unspent, budget - 200);
    });

    test('returns 0 when spent exceeds budget', () {
      final cat = DistributionCategory(name: 'Comida', isFixed: false, percentage: 25, spentAmount: 9999);
      expect(cat.computeUnspent(3000, totalFixed: 800), 0);
    });
  });

  group('SavingsDistribution.totalBudget', () {
    test('sums fixed + percentage of remaining', () {
      final dist = _makeDist();
      final fixed = 800.0;
      final remaining = 3000 - fixed;
      final expected = fixed + remaining * 40 / 100;
      expect(dist.totalBudget, expected);
    });

    test('equals income when percentages sum to 100%', () {
      final dist = SavingsDistribution(
        id: _uuid.v4(),
        month: 7,
        year: 2026,
        monthlyIncome: 3000,
        categories: [
          DistributionCategory(name: 'Alquiler', isFixed: true, fixedAmount: 2000),
          DistributionCategory(name: 'Comida', isFixed: false, percentage: 100),
        ],
      );
      expect(dist.totalBudget, 3000);
    });

    test('disabled categories excluded', () {
      final dist = SavingsDistribution(
        id: _uuid.v4(),
        month: 7,
        year: 2026,
        monthlyIncome: 3000,
        categories: [
          DistributionCategory(name: 'Alquiler', isFixed: true, fixedAmount: 800),
          DistributionCategory(name: 'Comida', isFixed: false, percentage: 25, isEnabled: false),
        ],
      );
      expect(dist.totalBudget, 800);
    });
  });

  group('SavingsDistribution.savingsBudget', () {
    test('allocates remaining after fixed + variable', () {
      final dist = _makeDist();
      final remaining = 3000 - 800;
      final allocated = remaining * 40 / 100;
      expect(dist.savingsBudget, remaining - allocated);
    });

    test('returns 0 when no remaining', () {
      final dist = SavingsDistribution(
        id: _uuid.v4(),
        month: 7,
        year: 2026,
        monthlyIncome: 1000,
        categories: [
          DistributionCategory(name: 'Alquiler', isFixed: true, fixedAmount: 1000),
        ],
      );
      expect(dist.savingsBudget, 0);
    });
  });

  group('SavingsDistribution.getCategoryBudget', () {
    test('returns savingsBudget for automatic category', () {
      final dist = _makeDist();
      final auto = dist.savingsCategory;
      expect(dist.getCategoryBudget(auto), dist.savingsBudget);
    });

    test('includes totalRedistributionReceived', () {
      final cat = DistributionCategory(
        name: 'Comida', isFixed: false, percentage: 25, totalRedistributionReceived: 50,
      );
      final dist = _makeDist(cats: [
        DistributionCategory(name: 'Alquiler', isFixed: true, fixedAmount: 800),
        cat,
      ]);
      final base = (3000 - 800) * 25 / 100;
      expect(dist.getCategoryBudget(cat), base + 50);
    });
  });

  group('SavingsDistribution.getCategoryUnspent', () {
    test('returns budget - spent for enabled category', () {
      final cat = DistributionCategory(name: 'Comida', isFixed: false, percentage: 25, spentAmount: 300);
      final dist = _makeDist(cats: [
        DistributionCategory(name: 'Alquiler', isFixed: true, fixedAmount: 800, spentAmount: 800),
        cat,
      ]);
      final budget = dist.getCategoryBudget(cat);
      expect(dist.getCategoryUnspent(cat), (budget - 300).clamp(0, double.infinity));
    });

    test('returns 0 for disabled category', () {
      final cat = DistributionCategory(name: 'Comida', isFixed: false, percentage: 25, isEnabled: false);
      final dist = _makeDist(cats: [
        DistributionCategory(name: 'Alquiler', isFixed: true, fixedAmount: 800),
        cat,
      ]);
      expect(dist.getCategoryUnspent(cat), 0);
    });
  });

  group('DistributionValidator', () {
    test('accepts valid percentages', () {
      final dist = SavingsDistribution(
        id: _uuid.v4(), month: 7, year: 2026, monthlyIncome: 3000,
        categories: [
          DistributionCategory(name: 'Alquiler', isFixed: true, fixedAmount: 800),
          DistributionCategory(name: 'Comida', isFixed: false, percentage: 60),
          DistributionCategory(name: 'Ocio', isFixed: false, percentage: 40),
        ],
      );
      expect(() => DistributionValidator.validatePercentages(dist), returnsNormally);
    });

    test('rejects invalid percentages', () {
      final dist = SavingsDistribution(
        id: _uuid.v4(), month: 7, year: 2026, monthlyIncome: 3000,
        categories: [
          DistributionCategory(name: 'Alquiler', isFixed: true, fixedAmount: 800),
          DistributionCategory(name: 'Comida', isFixed: false, percentage: 60),
          DistributionCategory(name: 'Ocio', isFixed: false, percentage: 50),
        ],
      );
      expect(() => DistributionValidator.validatePercentages(dist), throwsA(isA<ValidationException>()));
    });

    test('rejects duplicate names', () {
      final dist = SavingsDistribution(
        id: _uuid.v4(), month: 7, year: 2026, monthlyIncome: 3000,
        categories: [
          DistributionCategory(name: 'Comida', isFixed: true, fixedAmount: 200),
          DistributionCategory(name: 'Comida', isFixed: true, fixedAmount: 300),
        ],
      );
      expect(() => DistributionValidator.validateNoDuplicateNames(dist), throwsA(isA<ValidationException>()));
    });

    test('rejects budget exceeding income', () {
      final dist = SavingsDistribution(
        id: _uuid.v4(), month: 7, year: 2026, monthlyIncome: 1000,
        categories: [
          DistributionCategory(name: 'Alquiler', isFixed: true, fixedAmount: 1100),
        ],
      );
      expect(() => DistributionValidator.validateBudgetFitsIncome(dist), throwsA(isA<ValidationException>()));
    });
  });
}
