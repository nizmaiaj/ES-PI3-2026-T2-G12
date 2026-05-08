import 'package:flutter_test/flutter_test.dart';

import 'package:es_pi3_2026_t2_g12/main.dart';

void main() {
  testWidgets('exibe a tela de login inicial', (WidgetTester tester) async {
    await tester.pumpWidget(const MeuApp());

    expect(find.text('Boas-vindas ao MesclaInvest!'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Esqueceu a senha?'), findsOneWidget);
  });
}
