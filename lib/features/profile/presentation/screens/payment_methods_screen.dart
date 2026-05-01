import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final TextEditingController _cardController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _cardController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String _brandFor(String digits) {
    if (digits.startsWith('4')) return 'Visa';
    if (digits.startsWith('5')) return 'Mastercard';
    if (digits.startsWith('3')) return 'Amex';
    return 'Tarjeta';
  }

  Future<void> _saveCard() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final digits = _cardController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (uid == null) return;
    if (digits.length < 12) {
      _notify("Ingresa una tarjeta válida", isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final methodsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('payment_methods');
      final existing = await methodsRef.get();
      final brand = _brandFor(digits);
      final last4 = digits.substring(digits.length - 4);

      await methodsRef.add({
        'brand': brand,
        'last4': last4,
        'label': '$brand terminada en $last4',
        'holderName': _nameController.text.trim(),
        'isDefault': existing.docs.isEmpty,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _cardController.clear();
      _nameController.clear();
      _notify("Método de pago guardado", isError: false);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _notify("No pudimos guardar la tarjeta", isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _setDefault(String id) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final methodsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('payment_methods');
    final methods = await methodsRef.get();
    final batch = FirebaseFirestore.instance.batch();

    for (final doc in methods.docs) {
      batch.update(doc.reference, {'isDefault': doc.id == id});
    }

    await batch.commit();
  }

  void _notify(String text, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF1A4371),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text(
          "Métodos de Pago",
          style: TextStyle(
            color: Color(0xFF1A4371),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A4371)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (uid != null)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('payment_methods')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                final methods = snapshot.data?.docs ?? [];
                if (methods.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Text(
                      "Agrega una tarjeta para solicitar reservas.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return Column(
                  children: methods.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final isDefault = data['isDefault'] == true;
                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.credit_card,
                          color: Color(0xFF2BB8D1),
                        ),
                        title: Text(
                          data['label'] ?? 'Tarjeta',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          isDefault ? "Predeterminada" : "Disponible",
                        ),
                        trailing: isDefault
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : TextButton(
                                onPressed: () => _setDefault(doc.id),
                                child: const Text("USAR"),
                              ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Agregar tarjeta",
                  style: TextStyle(
                    color: Color(0xFF1A4371),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Nombre en la tarjeta",
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _cardController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Número de tarjeta",
                    prefixIcon: Icon(Icons.credit_card),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Ambiente de desarrollo: TripMate solo guarda marca y últimos 4 dígitos.",
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveCard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF05A28),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "GUARDAR TARJETA",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
