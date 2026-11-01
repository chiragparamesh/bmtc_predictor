import 'package:flutter_test/flutter_test.dart';
import 'package:bmtc_predictor/app.dart';
import 'package:bmtc_predictor/core/utils/app_constants.dart';

void main() {
  testWidgets('App boots to the skeleton home', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();
    expect(find.text(AppConstants.appName), findsWidgets);
  });
}
