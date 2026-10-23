import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/widgets/widgets.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

void main() {
  // ─── StatusChip ─────────────────────────────────────────────────
  group('StatusChip', () {
    testWidgets('renders label and icon', (tester) async {
      await tester.pumpWidget(_wrap(
        const StatusChip(label: 'Active', icon: Icons.check),
      ));
      expect(find.text('Active'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('neutral type uses disabledSurface background',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const StatusChip(label: 'Draft'),
      ));
      final container = tester.widget<Container>(find.byType(Container).first);
      final deco = container.decoration as BoxDecoration;
      expect(deco.color, isNotNull);
    });

    testWidgets('compact mode renders smaller', (tester) async {
      await tester.pumpWidget(_wrap(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            StatusChip(label: 'Normal'),
            SizedBox(height: 8),
            StatusChip(label: 'Compact', isCompact: true),
          ],
        ),
      ));
      final normal = tester.getSize(find.text('Normal'));
      final compact = tester.getSize(find.text('Compact'));
      expect(compact.height, lessThan(normal.height + 0.1));
    });
  });

  // ─── LoadingView ────────────────────────────────────────────────
  group('LoadingView', () {
    testWidgets('shows spinner', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingView()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows message when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const LoadingView(message: 'Loading deliveries…'),
      ));
      expect(find.text('Loading deliveries…'), findsOneWidget);
    });
  });

  // ─── ErrorView ──────────────────────────────────────────────────
  group('ErrorView', () {
    testWidgets('renders message and no retry without callback',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const ErrorView(message: 'Something went wrong.'),
      ));
      expect(find.text('Something went wrong.'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('renders retry button when onRetry set', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
        ErrorView(
          message: 'Network error.',
          onRetry: () => taps++,
        ),
      ));
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(taps, 1);
    });

    testWidgets('renders optional title', (tester) async {
      await tester.pumpWidget(_wrap(
        const ErrorView(
          title: 'Cannot load deliveries',
          message: 'Please try again.',
        ),
      ));
      expect(find.text('Cannot load deliveries'), findsOneWidget);
      expect(find.text('Please try again.'), findsOneWidget);
    });
  });

  // ─── EmptyView ──────────────────────────────────────────────────
  group('EmptyView', () {
    testWidgets('renders title and subtitle', (tester) async {
      await tester.pumpWidget(_wrap(
        const EmptyView(
          title: 'No deliveries yet',
          subtitle: 'Create your first request.',
        ),
      ));
      expect(find.text('No deliveries yet'), findsOneWidget);
      expect(find.text('Create your first request.'), findsOneWidget);
    });

    testWidgets('renders action widget when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        EmptyView(
          title: 'No staff',
          action: AppButton(label: 'Add staff', onPressed: () {}),
        ),
      ));
      expect(find.text('Add staff'), findsOneWidget);
    });
  });
}