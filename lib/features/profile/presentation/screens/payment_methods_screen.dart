import 'package:flutter/material.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Métodos de Pago"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A4371),
        elevation: 0,
      ),
      body: const Center(
        child: Text("Aquí el usuario podrá añadir sus tarjetas"),
      ),
    );
  }
}