import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<String?> showSmsCodeDialog(
  BuildContext context, {
  required String phoneNumber,
  required String title,
  required String message,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SmsCodeDialog(
      phoneNumber: phoneNumber,
      title: title,
      message: message,
    ),
  );
}

class _SmsCodeDialog extends StatefulWidget {
  const _SmsCodeDialog({
    required this.phoneNumber,
    required this.title,
    required this.message,
  });

  final String phoneNumber;
  final String title;
  final String message;

  @override
  State<_SmsCodeDialog> createState() => _SmsCodeDialogState();
}

class _SmsCodeDialogState extends State<_SmsCodeDialog> {
  static const _roxo = Color(0xFF4C3BCF);

  final _codigoController = TextEditingController();
  String? _erro;

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  void _confirmar() {
    final codigo = _codigoController.text.trim();

    if (codigo.length < 6) {
      setState(() => _erro = 'Digite o código de 6 dígitos.');
      return;
    }

    Navigator.pop(context, codigo);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 8),
          Text(
            widget.phoneNumber,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _codigoController,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              labelText: 'Código SMS',
              errorText: _erro,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _confirmar(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _confirmar,
          style: FilledButton.styleFrom(backgroundColor: _roxo),
          child: const Text('Verificar'),
        ),
      ],
    );
  }
}
