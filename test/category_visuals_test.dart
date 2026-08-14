import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds/core/constants/app_constants.dart';
import 'package:rounds/core/theme/category_visuals.dart';

void main() {
  group('CategoryVisual.resolve', () {
    test('category wins over name when present', () {
      final byCategory = CategoryVisual.resolve('Random name', 'Housing');
      expect(byCategory.icon, Icons.home_outlined);
    });

    test('falls back to name matching without a category', () {
      expect(CategoryVisual.resolve('Netflix', null).icon, Icons.tv_outlined);
      expect(CategoryVisual.resolve('Spotify', null).icon, Icons.headphones);
      expect(CategoryVisual.resolve('Rent', null).icon, Icons.home_outlined);
    });

    test('whole-word traps: credit card is not a car', () {
      final visual = CategoryVisual.resolve('Credit card', null);
      expect(visual.icon, Icons.credit_card_outlined);
    });

    test('whole-word traps: transportation is not a sport', () {
      final visual = CategoryVisual.resolve('x', 'Transportation');
      expect(visual.icon, Icons.directions_car_outlined);
    });

    test('whole-word traps: gasoline vs gas needs the leading space', () {
      expect(
        CategoryVisual.resolve('Natural gas', null).icon,
        Icons.local_fire_department_outlined,
      );
    });

    test('unknown bills get the fallback receipt', () {
      final visual = CategoryVisual.resolve('Something unusual', null);
      expect(visual.icon, Icons.receipt_outlined);
    });

    test('every built-in category resolves away from the fallback', () {
      final fallback = CategoryVisual.resolve('zzz', null);
      for (final category in AppConstants.categories) {
        if (category == 'Other') continue;
        final visual = CategoryVisual.resolve('x', category);
        expect(
          visual.icon,
          isNot(fallback.icon),
          reason: '$category should have its own icon',
        );
      }
    });

    test('built-in categories carry distinct hues per family', () {
      Color hueOf(String category) =>
          CategoryVisual.resolve('x', category).darkColor;

      // Families that share a hue on purpose (connectivity, entertainment,
      // finance) collapse; the remaining families must not collide.
      final distinct = {
        hueOf('Housing'),
        hueOf('Utilities'),
        hueOf('Internet & Phone'),
        hueOf('Insurance'),
        hueOf('Subscriptions'),
        hueOf('Credit Card'),
        hueOf('Transportation'),
      };
      expect(distinct.length, 7);

      // Finance family shares one hue.
      expect(hueOf('Credit Card'), hueOf('Loan'));
    });

    test('container tint is derived from the hue', () {
      final visual = CategoryVisual.resolve('x', 'Housing');
      for (final brightness in Brightness.values) {
        final container = visual.containerFor(brightness);
        final hue = visual.colorFor(brightness);
        expect(container.r, hue.r);
        expect(container.g, hue.g);
        expect(container.b, hue.b);
        expect(container.a, lessThan(0.2));
      }
    });
  });
}
