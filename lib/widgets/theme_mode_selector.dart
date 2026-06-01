// Controle visual compartilhado para alternar a aparência do aplicativo.
import 'package:flutter/material.dart';

import '../services/app_theme_controller.dart';

/// Observa o controlador global e exibe as opções claro, escuro e sistema.
class ThemeModeSelector extends StatelessWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return SegmentedButton<AppThemeMode>(
          showSelectedIcon: false,
          selected: {controller.mode},
          segments: const [
            ButtonSegment(
              value: AppThemeMode.light,
              icon: Icon(Icons.light_mode_outlined, size: 16),
              label: Text('Claro'),
            ),
            ButtonSegment(
              value: AppThemeMode.dark,
              icon: Icon(Icons.dark_mode_outlined, size: 16),
              label: Text('Escuro'),
            ),
            ButtonSegment(
              value: AppThemeMode.system,
              icon: Icon(Icons.settings_suggest_outlined, size: 16),
              label: Text('Sistema'),
            ),
          ],
          onSelectionChanged: (selection) {
            controller.setMode(selection.first);
          },
        );
      },
    );
  }
}
