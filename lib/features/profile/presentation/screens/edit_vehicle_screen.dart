// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
  final _capacidadController = TextEditingController();

  File? _fotoPatente;
  File? _fotoPadron;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _seleccionarImagen(String tipo) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image != null) {
      setState(() {
        if (tipo == 'patente') _fotoPatente = File(image.path);
        if (tipo == 'padron') _fotoPadron = File(image.path);
      });
    }
  }

  Future<String?> _subirArchivo(File file, String folder, String uid) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child(folder)
          .child('$uid-${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<void> _guardarVehiculo() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fotoPatente == null || _fotoPadron == null) {
      _notificar("Sube las fotos de la patente y padrón", esError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      String? urlPatente = await _subirArchivo(
        _fotoPatente!,
        'vehiculos/patentes',
        uid,
      );
      String? urlPadron = await _subirArchivo(
        _fotoPadron!,
        'vehiculos/padrones',
        uid,
      );
      final vehicleRef = FirebaseFirestore.instance
          .collection('vehicles')
          .doc();

      final nuevoVehiculo = {
        'vehicleId': vehicleRef.id,
        'ownerId': uid,
        'marca': _marcaController.text.trim(),
        'modelo': _modeloController.text.trim(),
        'color': _colorController.text.trim(),
        'patente': _patenteController.text.trim().toUpperCase(),
        'capacidad': int.tryParse(_capacidadController.text) ?? 4,
        'fotoPatenteUrl': urlPatente,
        'fotoPadronUrl': urlPadron,
        'verificado': false,
        'status': 'pendiente',
        'createdAt': Timestamp.now(),
      };

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'vehiculos': FieldValue.arrayUnion([nuevoVehiculo]),
      });

      await vehicleRef.set({
        ...nuevoVehiculo,
        'createdAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context);
      _notificar("Vehículo enviado a revisión", esError: false);
    } catch (e) {
      _notificar("Error: $e", esError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _notificar(String msj, {required bool esError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msj),
        backgroundColor: esError ? Colors.redAccent : const Color(0xFF1A4371),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Registrar Vehículo",
          style: TextStyle(
            color: Color(0xFF1A4371),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(_marcaController, "MARCA", Icons.directions_car),
              _buildTextField(
                _modeloController,
                "MODELO",
                Icons.settings_suggest,
              ),
              _buildTextField(
                _colorController,
                "COLOR",
                Icons.palette_outlined,
              ),
              _buildTextField(_patenteController, "PATENTE", Icons.badge),
              _buildTextField(
                _capacidadController,
                "CAPACIDAD DE PASAJEROS",
                Icons.event_seat,
              ),
              const SizedBox(height: 20),
              _buildPhotoBtn(
                "Foto Patente",
                _fotoPatente,
                () => _seleccionarImagen('patente'),
              ),
              _buildPhotoBtn(
                "Foto Padrón/SOAP",
                _fotoPadron,
                () => _seleccionarImagen('padron'),
              ),
              const SizedBox(height: 30),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF2BB8D1)),
          filled: true,
          fillColor: const Color(0xFFF8F9FB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoBtn(String label, File? file, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        file != null ? Icons.check_circle : Icons.camera_alt,
        color: file != null ? Colors.green : Colors.grey,
      ),
      title: Text(label),
      trailing: const Icon(Icons.upload),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF05A28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: _isLoading ? null : _guardarVehiculo,
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                "GUARDAR VEHÍCULO",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
