import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // ¡Añade este import para los formatters!

class TripMateFormat {
  static String currencyCLP(dynamic valor) {
    if (valor == null) return "\$0";
    
    final int numero = (valor is String) 
        ? int.tryParse(valor.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0 
        : valor.toInt();

    final formatPuntos = NumberFormat.decimalPattern('es_CL');
    String conPuntos = formatPuntos.format(numero);

    return "\$$conPuntos"; 
  }

  static TextInputFormatter inputCLP() {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      if (newValue.text.isEmpty) return newValue;

      String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
      
      final f = NumberFormat.decimalPattern('es_CL');
      String newText = f.format(int.parse(digits));

      return newValue.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    });
  }
}