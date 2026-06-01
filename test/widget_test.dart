// Teste básico de navegação pública antes da autenticação.
import 'package:flutter_test/flutter_test.dart';

import 'package:es_pi3_2026_t2_g12/main.dart';

void main() {
  // Garante que o botão inicial continua levando ao formulário de login.
  testWidgets('navega da tela inicial para o login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MeuApp());

    expect(find.text('Começar agora'), findsOneWidget);

    await tester.tap(find.text('Começar agora'));
    await tester.pumpAndSettle();

    expect(find.text('Boas-vindas ao MesclaInvest!'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Esqueceu a senha?'), findsOneWidget);
  });
}
