// Helper de navegação para trocas de área que não devem animar a transição.
import 'package:flutter/material.dart';

/// Cria uma rota instantânea compatível com a API padrão do Navigator.
PageRoute<T> noAnimationRoute<T>({required WidgetBuilder builder}) {
  return PageRouteBuilder<T>(
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
  );
}
