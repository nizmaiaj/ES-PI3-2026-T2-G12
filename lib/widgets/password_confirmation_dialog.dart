// Modal reutilizável para confirmar operações sensíveis com a senha atual.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/password_reauthentication_service.dart';
import '../theme/app_theme.dart';

/// Abre a confirmação e devolve `true` somente após reautenticar no Firebase.
Future<bool> showPasswordConfirmationDialog({
  required BuildContext context,
  String title = 'Confirme sua identidade para concluir a compra',
  String description =
      'Por segurança, informe sua senha para finalizar a transação e confirmar a aquisição dos tokens.',
  String confirmButtonLabel = 'Finalizar transação',
  String emptyPasswordMessage = 'Informe sua senha para confirmar a compra.',
  String invalidPasswordMessage =
      'Senha inválida.\nNão foi possível confirmar sua identidade e, por segurança, a compra dos tokens não foi realizada. Verifique sua senha e tente novamente.',
  Widget? details,
  Widget Function(bool processing)? detailsBuilder,
  String? Function()? additionalValidation,
}) async {
  var password = '';
  var processing = false;
  var hasError = false;
  var passwordVisible = false;
  String? errorMessage;

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final colorScheme = Theme.of(context).colorScheme;
          final themeColors = Theme.of(context).extension<AppThemeColors>()!;

          // A validação adicional permite que cada tela confira seus próprios
          // campos antes de iniciar a reautenticação.
          Future<void> confirm() async {
            if (processing) return;

            final validationMessage = additionalValidation?.call();
            if (validationMessage != null) {
              setDialogState(() {
                hasError = true;
                errorMessage = validationMessage;
              });
              return;
            }

            if (password.isEmpty) {
              setDialogState(() {
                hasError = true;
                errorMessage = emptyPasswordMessage;
              });
              return;
            }

            setDialogState(() {
              processing = true;
              hasError = false;
              errorMessage = null;
            });

            try {
              await reauthenticateCurrentUserWithPassword(password);

              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop(true);
            } on FirebaseAuthException {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                processing = false;
                hasError = true;
                errorMessage = null;
              });
            } catch (error) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                processing = false;
                hasError = true;
                errorMessage = error.toString().replaceFirst('Exception: ', '');
              });
            }
          }

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            backgroundColor: Colors.transparent,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: themeColors.elevatedSurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Fechar confirmação',
                        onPressed: processing
                            ? null
                            : () => Navigator.of(dialogContext).pop(false),
                        icon: Icon(Icons.close, color: colorScheme.onSurface),
                        style: IconButton.styleFrom(
                          backgroundColor: themeColors.subtleSurface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (detailsBuilder != null || details != null) ...[
                      const SizedBox(height: 16),
                      detailsBuilder?.call(processing) ?? details!,
                    ],
                    const SizedBox(height: 12),
                    Text(
                      description,
                      style: TextStyle(
                        color: themeColors.mutedText,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Digite a sua senha',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      obscureText: !passwordVisible,
                      enabled: !processing,
                      textInputAction: TextInputAction.done,
                      onChanged: (value) => password = value,
                      onSubmitted: (_) => confirm(),
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        fillColor: colorScheme.surface,
                        filled: true,
                        hintText: '••••••',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            passwordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: themeColors.mutedText,
                          ),
                          onPressed: () => setDialogState(
                            () => passwordVisible = !passwordVisible,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (hasError) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage ?? invalidPasswordMessage,
                              style: TextStyle(
                                color: Colors.red.shade800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: processing ? null : confirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3F51B5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: processing
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                confirmButtonLabel,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  return confirmed == true;
}
