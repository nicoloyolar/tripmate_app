// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart'; // Para formatear la fecha
import 'dart:io';

import 'package:tripmate_app/features/trips/presentation/screens/main_navegation_screen.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _rutController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  DateTime? _fechaNacimiento; 
  bool aceptaCondiciones = false;
  bool obscurePassword = true; 
  String? generoSeleccionado;
  bool isLoading = false;

  File? _imagenSeleccionada; 
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nombreController.dispose();
    _rutController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1A4371), 
              onPrimary: Colors.white,
              onSurface: Color(0xFF1A4371),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final edad = DateTime.now().year - picked.year;
      if (edad < 18) {
        _mostrarError("Debes ser mayor de 18 años para registrarte");
        return;
      }
      setState(() {
        _fechaNacimiento = picked;
      });
    }
  }

  Future<void> _seleccionarImagen() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512, 
        maxHeight: 512,
        imageQuality: 80, 
      );
      
      if (image != null) {
        setState(() {
          _imagenSeleccionada = File(image.path);
        });
      }
    } catch (e) {
      _mostrarError("Error al seleccionar imagen: $e");
    }
  }

  Future<String?> _subirImagenAFirebase(String uid) async {
    if (_imagenSeleccionada == null) return null; 

    try {
      final storageRef = FirebaseStorage.instance.ref().child('user_photos').child('$uid.jpg');
      UploadTask uploadTask = storageRef.putFile(_imagenSeleccionada!);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<void> _registrarUsuario() async {
    
    String rutLimpio = _rutController.text.trim();
    if (!validarRutChileno(rutLimpio)) {
      _mostrarError("El RUT ingresado no es válido. Revisa los puntos y guion.");
      return;
    }
    if (_imagenSeleccionada == null) return _mostrarError("Por favor, sube una foto de perfil");
    if (_nombreController.text.trim().isEmpty) return _mostrarError("Ingresa tu nombre");
    if (_rutController.text.trim().isEmpty) return _mostrarError("Ingresa tu RUT");
    if (_fechaNacimiento == null) return _mostrarError("Selecciona tu fecha de nacimiento");
    if (generoSeleccionado == null) return _mostrarError("Selecciona tu género");
    if (!aceptaCondiciones) return _mostrarError("Debes aceptar los términos");

    setState(() => isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String uid = userCredential.user!.uid;

      String? fotoUrl = await _subirImagenAFirebase(uid);

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'nombre': _nombreController.text.trim(),
        'rut': _rutController.text.trim(),
        'email': _emailController.text.trim(),
        'genero': generoSeleccionado,
        'fechaNacimiento': _fechaNacimiento,
        'photoUrl': fotoUrl, 
        'createdAt': FieldValue.serverTimestamp(),
        'rol': 'user',
      });

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
        (route) => false,
      );

    } on FirebaseAuthException catch (e) {
      _mostrarError(e.message ?? "Error al registrar");
    } catch (e) {
      _mostrarError("Error inesperado: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text("Completa tu perfil",
          style: TextStyle(color: Color(0xFF1A4371), fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // SECTOR FOTO DE PERFIL
              Center(
                child: GestureDetector(
                  onTap: _seleccionarImagen, 
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: const Color(0xFFF1F4F8),
                        backgroundImage: _imagenSeleccionada != null ? FileImage(_imagenSeleccionada!) : null,
                        child: _imagenSeleccionada == null 
                            ? const Icon(Icons.add_a_photo_outlined, size: 40, color: Color(0xFF1A4371))
                            : null,
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: Color(0xFFF05A28), shape: BoxShape.circle),
                          child: const Icon(Icons.edit, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 30),

              _buildFieldLabel("Nombre completo"),
              _buildTextField(controller: _nombreController, hint: "Ej: Juan Pérez", icon: Icons.person_outline),

              const SizedBox(height: 15),

              _buildFieldLabel("R.U.T"),
              _buildTextField(controller: _rutController, hint: "12.345.678-9", icon: Icons.badge_outlined),

              const SizedBox(height: 15),

              _buildFieldLabel("Correo electrónico"),
              _buildTextField(controller: _emailController, hint: "correo@ejemplo.com", icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),

              const SizedBox(height: 15),

              _buildFieldLabel("Género"),
              DropdownButtonFormField<String>(
                initialValue: generoSeleccionado,
                decoration: _inputDecoration(Icons.wc_outlined),
                items: ["Masculino", "Femenino", "Otros"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => generoSeleccionado = v),
              ),

              const SizedBox(height: 15),

              _buildFieldLabel("Fecha de nacimiento"),
              GestureDetector(
                onTap: () => _seleccionarFecha(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, color: Color(0xFF2BB8D1)),
                      const SizedBox(width: 12),
                      Text(
                        _fechaNacimiento == null 
                            ? "Selecciona tu fecha" 
                            : DateFormat('dd / MM / yyyy').format(_fechaNacimiento!),
                        style: TextStyle(
                          color: _fechaNacimiento == null ? Colors.grey : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 15),

              _buildFieldLabel("Contraseña"),
              TextField(
                controller: _passwordController,
                obscureText: obscurePassword, 
                decoration: _inputDecoration(Icons.lock_outline).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                    onPressed: () => setState(() => obscurePassword = !obscurePassword),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Checkbox(
                    value: aceptaCondiciones,
                    activeColor: const Color(0xFF1A4371), 
                    onChanged: (v) => setState(() => aceptaCondiciones = v ?? false),
                  ),
                  const Expanded(child: Text("Acepto los términos y condiciones de TripMate", style: TextStyle(fontSize: 12))),
                ],
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _registrarUsuario,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF05A28),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("CREAR MI CUENTA", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(label, style: const TextStyle(color: Color(0xFF1A4371), fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  InputDecoration _inputDecoration(IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: const Color(0xFF2BB8D1)),
      filled: true,
      fillColor: const Color(0xFFF8F9FB),
      contentPadding: const EdgeInsets.symmetric(vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String hint, required IconData icon, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _inputDecoration(icon).copyWith(hintText: hint),
    );
  }

  bool validarRutChileno(String rut) {
    rut = rut.replaceAll('.', '').replaceAll('-', '').trim().toUpperCase();
    
    if (rut.length < 8) return false;

    String cuerpo = rut.substring(0, rut.length - 1);
    String dv = rut.substring(rut.length - 1);

    int suma = 0;
    int multiplo = 2;

    for (int i = cuerpo.length - 1; i >= 0; i--) {
      suma += int.parse(cuerpo[i]) * multiplo;
      multiplo = (multiplo == 7) ? 2 : multiplo + 1;
    }

    int dvEsperadoInt = 11 - (suma % 11);
    String dvEsperado = (dvEsperadoInt == 11) 
        ? "0" 
        : (dvEsperadoInt == 10) 
            ? "K" 
            : dvEsperadoInt.toString();

    return dv == dvEsperado;
  }
}