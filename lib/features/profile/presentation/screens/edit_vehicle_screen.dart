// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tripmate_app/core/constants/vehicle_data.dart'; 

class EditVehicleScreen extends StatefulWidget {
  const EditVehicleScreen({super.key});

  @override
  State<EditVehicleScreen> createState() => _EditVehicleScreenState();
}

class _EditVehicleScreenState extends State<EditVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _colorController = TextEditingController();
  final _patenteController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosVehiculo();
  }

  Future<void> _cargarDatosVehiculo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    
    if (doc.exists && doc.data()?['vehiculo'] != null) {
      final v = doc.data()!['vehiculo'];
      setState(() {
        _marcaController.text = v['marca'] ?? '';
        _modeloController.text = v['modelo'] ?? '';
        _colorController.text = v['color'] ?? '';
        _patenteController.text = v['patente'] ?? '';
      });
    }
  }

  void _mostrarSelector(TextEditingController controller, String titulo, List<String> opciones) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A4371))),
            const SizedBox(height: 15),
            Expanded(
              child: ListView.separated(
                itemCount: opciones.length,
                separatorBuilder: (_, _) => Divider(color: Colors.grey[100]),
                itemBuilder: (context, i) => ListTile(
                  title: Text(opciones[i], style: const TextStyle(fontSize: 16)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () {
                    setState(() => controller.text = opciones[i]);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _guardarVehiculo() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'vehiculo': {
          'marca': _marcaController.text.trim(),
          'modelo': _modeloController.text.trim(),
          'color': _colorController.text.trim(),
          'patente': _patenteController.text.trim().toUpperCase(),
        }
      });
      Navigator.pop(context);
      _notificar("Vehículo guardado correctamente", esError: false);
    } catch (e) {
      _notificar("Error al guardar: $e", esError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _notificar(String msj, {required bool esError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msj), backgroundColor: esError ? Colors.redAccent : const Color(0xFF1A4371))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Configurar Vehículo", style: TextStyle(color: Color(0xFF1A4371), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF1A4371)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildInputGroup(
                label: "MARCA",
                controller: _marcaController,
                icon: Icons.directions_car_filled,
                onTap: () => _mostrarSelector(_marcaController, "Selecciona una Marca", VehicleConstants.marcas),
              ),
              _buildInputGroup(
                label: "MODELO",
                controller: _modeloController,
                icon: Icons.settings_suggest,
                hint: "Ej: Yaris, Swift, CX-5...",
                isReadOnly: false,
              ),
              _buildInputGroup(
                label: "COLOR",
                controller: _colorController,
                icon: Icons.palette_rounded,
                onTap: () => _mostrarSelector(_colorController, "Selecciona un Color", VehicleConstants.colores),
              ),
              _buildInputGroup(
                label: "PATENTE",
                controller: _patenteController,
                icon: Icons.badge_rounded,
                hint: "Ej: ABCD-12",
                isReadOnly: false,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 40),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputGroup({
    required String label, 
    required TextEditingController controller, 
    required IconData icon, 
    String? hint,
    VoidCallback? onTap,
    bool isReadOnly = true,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            readOnly: isReadOnly,
            onTap: onTap,
            textCapitalization: textCapitalization,
            validator: (v) => v!.isEmpty ? "Este campo es obligatorio" : null,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A4371)),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8F9FB),
              prefixIcon: Icon(icon, color: const Color(0xFF2BB8D1), size: 22),
              hintText: hint ?? "Seleccionar...",
              hintStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.normal, fontSize: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF05A28),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 4,
          shadowColor: const Color(0xFFF05A28).withOpacity(0.4),
        ),
        onPressed: _isLoading ? null : _guardarVehiculo,
        child: _isLoading 
          ? const CircularProgressIndicator(color: Colors.white) 
          : const Text("GUARDAR CAMBIOS", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}