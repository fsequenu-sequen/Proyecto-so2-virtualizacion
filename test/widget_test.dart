import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_robot/main.dart';

void main() {
  testWidgets('Carga pantalla inicial del robot', (WidgetTester tester) async {
    await tester.pumpWidget(const RobotAssistantApp());

    expect(find.text('Robot Asistente'), findsOneWidget);
  });
}