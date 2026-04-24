// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores para los campos de texto
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _bioController = TextEditingController();

  File? _imageFile;
  String? _currentPhotoUrl;
  bool _isLoading = false;
  bool _isFetching = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // Carga inicial de datos desde Firebase
  Future<void> _cargarDatosUsuario() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _nombreController.text = data['nombre'] ?? '';
          _telefonoController.text = data['telefono'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _currentPhotoUrl = data['photoUrl'];
          _isFetching = false;
        });
      }
    } catch (e) {
      _notificar("Error al cargar datos", esError: true);
    }
  }

  // Selección de imagen desde la galería
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    
    if (image != null) {
      setState(() => _imageFile = File(image.path));
    }
  }

  // Cálculo de cuánto ha completado el usuario su perfil
  double _calcularProgreso() {
    int camposCompletos = 0;
    if (_nombreController.text.isNotEmpty) camposCompletos++;
    if (_telefonoController.text.isNotEmpty) camposCompletos++;
    if (_bioController.text.isNotEmpty) camposCompletos++;
    if (_currentPhotoUrl != null || _imageFile != null) camposCompletos++;
    
    return camposCompletos / 4; 
  }

  // Guardar cambios en Firebase
  Future<void> _actualizarPerfil() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      String? finalPhotoUrl = _currentPhotoUrl;

      // Si el usuario seleccionó una foto nueva, subirla a Storage
      if (_imageFile != null) {
        final ref = FirebaseStorage.instance.ref().child('perfiles').child('$uid.jpg');
        await ref.putFile(_imageFile!);
        finalPhotoUrl = await ref.getDownloadURL();
      }

      // Actualizar el documento del usuario en Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'nombre': _nombreController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'bio': _bioController.text.trim(),
        'photoUrl': finalPhotoUrl,
        'perfilCompleto': _calcularProgreso() >= 1.0,
      });

      _notificar("Perfil actualizado correctamente", esError: false);
      Navigator.pop(context);
    } catch (e) {
      _notificar("Error al actualizar: $e", esError: true);
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
    if (_isFetching) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Editar Perfil", style: TextStyle(color: Color(0xFF1A4371), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF1A4371)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // FOTO DE PERFIL CON BOTÓN DE CÁMARA
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: const Color(0xFF1A4371).withOpacity(0.1),
                      backgroundImage: _imageFile != null 
                        ? FileImage(_imageFile!) 
                        : (_currentPhotoUrl != null ? NetworkImage(_currentPhotoUrl!) : null) as ImageProvider?,
                      child: (_imageFile == null && _currentPhotoUrl == null)
                        ? const Icon(Icons.person, size: 60, color: Color(0xFF1A4371))
                        : null,
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: Color(0xFF2BB8D1), shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // INDICADOR DE PROGRESO
              _buildProgressIndicator(_calcularProgreso()),
              const SizedBox(height: 30),

              // FORMULARIO
              _buildFieldLabel("NOMBRE COMPLETO"),
              _buildTextField(
                controller: _nombreController,
                icon: Icons.person_outline,
                hint: "Ej: Juan Pérez",
              ),

              _buildFieldLabel("TELÉFONO"),
              _buildTextField(
                controller: _telefonoController,
                icon: Icons.phone_android,
                hint: "+56 9 ...",
                keyboardType: TextInputType.phone,
              ),

              _buildFieldLabel("MINI BIOGRAFÍA"),
              _buildTextField(
                controller: _bioController,
                icon: Icons.article_outlined,
                hint: "Cuéntanos sobre ti para generar confianza...",
                maxLines: 4,
              ),

              const SizedBox(height: 40),
              _buildSaveButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS DE APOYO (ESTILO) ---

  Widget _buildProgressIndicator(double porcentaje) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Completitud del perfil", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A4371))),
            Text("${(porcentaje * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2BB8D1))),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: porcentaje,
            minHeight: 8,
            backgroundColor: const Color(0xFFF0F0F0),
            color: const Color(0xFF2BB8D1),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 15),
      child: Align(alignment: Alignment.centerLeft, child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1))),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required IconData icon, required String hint, int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        filled: true, fillColor: const Color(0xFFF8F9FB),
        prefixIcon: Icon(icon, color: const Color(0xFF2BB8D1)),
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity, height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF05A28),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        onPressed: _isLoading ? null : _actualizarPerfil,
        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("GUARDAR PERFIL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}