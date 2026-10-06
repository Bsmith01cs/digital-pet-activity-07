import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:digital_pet/main.dart';

Future<void> pumpPet(
  WidgetTester tester, {
  int happiness = 50,
  int hunger = 50,
}) => tester.pumpWidget(
  MaterialApp(
    home: PetScreen(initialHappiness: happiness, initialHunger: hunger),
  ),
);

Future<void> tapButton(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pump();
}

VoidCallback? onPressed(WidgetTester tester, String label) => tester
    .widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    )
    .onPressed;

ColorFilter petFilter(WidgetTester tester) =>
    tester.widget<ColorFiltered>(find.byType(ColorFiltered)).colorFilter;

void main() {
  test('mood boundaries at 29, 30, 70, and 71', () {
    expect(moodFor(29), Mood.unhappy);
    expect(moodFor(30), Mood.neutral);
    expect(moodFor(70), Mood.neutral);
    expect(moodFor(71), Mood.happy);
    expect(tintFor(29), Colors.redAccent);
    expect(tintFor(30), Colors.amber);
    expect(tintFor(70), Colors.amber);
    expect(tintFor(71), Colors.lightGreen);
  });

  for (final (happiness, mood, color) in [
    (29, 'UNHAPPY', Colors.redAccent),
    (30, 'NEUTRAL', Colors.amber),
    (70, 'NEUTRAL', Colors.amber),
    (71, 'HAPPY', Colors.lightGreen),
  ]) {
    testWidgets('happiness $happiness shows $mood tint', (tester) async {
      await pumpPet(tester, happiness: happiness);
      expect(find.text(mood), findsOneWidget);
      expect(petFilter(tester), ColorFilter.mode(color, BlendMode.modulate));
    });
  }

  testWidgets('pet name is trimmed and blank names are ignored', (
    tester,
  ) async {
    await pumpPet(tester);
    expect(find.text("Hi, I'm Pip!"), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  Luna  ');
    await tapButton(tester, 'Set Name');
    expect(find.text("Hi, I'm Luna!"), findsOneWidget);

    await tester.enterText(find.byType(TextField), '   ');
    await tapButton(tester, 'Set Name');
    expect(find.text("Hi, I'm Luna!"), findsOneWidget);
  });

  testWidgets('hunger never goes below 0', (tester) async {
    await pumpPet(tester, hunger: 5);
    await tapButton(tester, 'Feed');
    await tapButton(tester, 'Feed');
    expect(find.text('Hunger: 0'), findsOneWidget);
  });

  testWidgets('hunger never goes above 100', (tester) async {
    await pumpPet(tester, happiness: 50, hunger: 98);
    await tapButton(tester, 'Play');
    expect(find.text('Hunger: 100'), findsOneWidget);
    await tester.pump(hungerInterval);
    expect(find.text('Hunger: 100'), findsOneWidget);
  });

  testWidgets('happiness never goes above 100', (tester) async {
    await pumpPet(tester, happiness: 95);
    await tapButton(tester, 'Play');
    expect(find.text('Happiness: 100'), findsOneWidget);
  });

  testWidgets('happiness never goes below 0', (tester) async {
    await pumpPet(tester, happiness: 15, hunger: 100);
    await tester.pump(hungerInterval);
    expect(find.text('Happiness: 0'), findsOneWidget);
  });

  testWidgets('hunger 95 to 100 does not reduce happiness', (tester) async {
    await pumpPet(tester, happiness: 50, hunger: 95);
    await tester.pump(hungerInterval);
    expect(find.text('Hunger: 100'), findsOneWidget);
    expect(find.text('Happiness: 50'), findsOneWidget);
  });

  testWidgets('tick at hunger 100 keeps hunger and reduces happiness by 20', (
    tester,
  ) async {
    await pumpPet(tester, happiness: 50, hunger: 100);
    await tester.pump(hungerInterval);
    expect(find.text('Hunger: 100'), findsOneWidget);
    expect(find.text('Happiness: 30'), findsOneWidget);
  });

  testWidgets('hunger increases by 5 every 30 seconds', (tester) async {
    await pumpPet(tester);
    await tester.pump(const Duration(seconds: 29));
    expect(find.text('Hunger: 50'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Hunger: 55'), findsOneWidget);
  });

  testWidgets('dropping back to exactly 80 cancels the win timer', (
    tester,
  ) async {
    await pumpPet(tester, happiness: 100, hunger: 100);
    await tester.pump(hungerInterval);
    expect(find.text('Happiness: 80'), findsOneWidget);
    await tester.pump(winDuration);
    expect(find.textContaining('You win'), findsNothing);
  });

  testWidgets('happiness above 80 for 3 minutes wins', (tester) async {
    await pumpPet(tester, happiness: 90, hunger: 0);
    await tester.pump(winDuration - const Duration(seconds: 1));
    expect(find.textContaining('You win'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('You win'), findsOneWidget);
    expect(onPressed(tester, 'Feed'), isNull);
    expect(onPressed(tester, 'Play'), isNull);
    expect(onPressed(tester, 'Pause'), isNull);
  });

  testWidgets('hunger 100 and happiness 10 or lower loses', (tester) async {
    await pumpPet(tester, happiness: 30, hunger: 100);
    await tester.pump(hungerInterval);
    expect(find.text('Hunger: 100'), findsOneWidget);
    expect(find.text('Happiness: 10'), findsOneWidget);
    expect(find.textContaining('Game over'), findsOneWidget);
    expect(onPressed(tester, 'Feed'), isNull);
    expect(onPressed(tester, 'Play'), isNull);
  });

  testWidgets('reset restores the original state', (tester) async {
    await pumpPet(tester);
    await tester.enterText(find.byType(TextField), 'Luna');
    await tapButton(tester, 'Set Name');
    await tapButton(tester, 'Play');
    await tapButton(tester, 'Pause');
    await tapButton(tester, 'Reset');
    expect(find.text("Hi, I'm Pip!"), findsOneWidget);
    expect(find.text('Happiness: 50'), findsOneWidget);
    expect(find.text('Hunger: 50'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    expect(onPressed(tester, 'Feed'), isNotNull);
  });

  testWidgets('pause stops hunger and resume continues it', (tester) async {
    await pumpPet(tester);
    await tapButton(tester, 'Pause');
    expect(onPressed(tester, 'Feed'), isNull);
    await tester.pump(const Duration(minutes: 2));
    expect(find.text('Hunger: 50'), findsOneWidget);

    await tapButton(tester, 'Resume');
    await tester.pump(hungerInterval);
    expect(find.text('Hunger: 55'), findsOneWidget);
  });

  testWidgets('leaving the screen cancels timers safely', (tester) async {
    await pumpPet(tester, happiness: 90);
    await tapButton(tester, 'Feed');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('animations are disabled when the system requests it', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: PetScreen()),
      ),
    );
    await tapButton(tester, 'Feed');
    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.duration, Duration.zero);
    expect(scale.scale, 1.0);
  });
}
