import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lokaluxe/core/services/localization_provider.dart';
import 'package:lokaluxe/screens/game/loka_catch_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LokaCatch uses the open-mouth Komodo instead of a basket', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LocalizationProvider(),
        child: const MaterialApp(home: LokaCatchScreen()),
      ),
    );
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('LokaCatch'),
      ),
      findsOneWidget,
    );
    expect(find.text('🧺'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/Background.jpg',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/lokacatch_komodo_open.png',
      ),
      findsNWidgets(2),
    );
    expect(
      (await rootBundle.load('assets/images/Background.jpg')).lengthInBytes,
      greaterThan(0),
    );
    expect(
      (await rootBundle.load('assets/audio/audio.mp3')).lengthInBytes,
      greaterThan(0),
    );
    expect(
      (await rootBundle.load('assets/images/lokacatch_komodo_closed.png'))
          .lengthInBytes,
      greaterThan(0),
    );
    for (final asset in [
      'assets/images/lokacatch_bomb.png',
      'assets/images/lokacatch_food_tofu.png',
      'assets/images/lokacatch_food_dumplings.png',
      'assets/images/lokacatch_food_sushi.png',
      'assets/images/lokacatch_food_satay.png',
      'assets/images/lokacatch_food_chicken_rice.png',
      'assets/images/lokacatch_food_steamed_cake.png',
      'assets/images/lokacatch_food_rice_cakes.png',
      'assets/images/lokacatch_food_tumpeng.png',
      'assets/images/lokacatch_food_rice_bowl.png',
    ]) {
      expect((await rootBundle.load(asset)).lengthInBytes, greaterThan(0));
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
