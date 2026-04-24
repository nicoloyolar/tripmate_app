// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:tripmate_app/core/constants/legal_constants.dart';
import 'package:tripmate_app/core/utils/validators.dart'; 
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
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  DateTime? _fechaNacimiento; 
  bool aceptaCondiciones = false;
  bool obscurePassword = true; 
  String? generoSeleccionado;
  bool isLoading = false;

  File? _imagenSeleccionada; 
  File? _imagenCarnet; 
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nombreController.dispose();
    _rutController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isPasswordValid(String password) {
    final passwordRegExp = RegExp(r'^(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#\$&*~]).{8,}$');
    return passwordRegExp.hasMatch(password);
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
      setState(() => _fechaNacimiento = picked);
    }
  }

  Future<void> _seleccionarImagen(bool esPerfil) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512, 
        maxHeight: 512,
        imageQuality: 80, 
      );
      
      if (image != null) {
        setState(() {
          if (esPerfil) {
            _imagenSeleccionada = File(image.path);
          } else {
            _imagenCarnet = File(image.path);
          }
        });
      }
    } catch (e) {
      _mostrarError("Error al seleccionar imagen");
    }
  }

  Future<String?> _subirArchivo(File file, String folder, String uid) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child(folder).child('$uid.jpg');
      TaskSnapshot snapshot = await storageRef.putFile(file);
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<void> _registrarUsuario() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String telefono = _phoneController.text.trim();

    if (_imagenSeleccionada == null) return _mostrarError("Por favor, sube tu foto de perfil");
    if (_imagenCarnet == null) return _mostrarError("Por favor, sube la foto de tu carnet");
    if (_nombreController.text.trim().isEmpty) return _mostrarError("Ingresa tu nombre");
    if (!TripMateValidators.validarRutChileno(_rutController.text)) return _mostrarError("RUT no válido");
    if (telefono.length < 9) return _mostrarError("Ingresa un teléfono válido (9 dígitos)");
    if (generoSeleccionado == null) return _mostrarError("Selecciona tu género");
    if (_fechaNacimiento == null) return _mostrarError("Selecciona tu fecha de nacimiento");
    if (!_isPasswordValid(password)) return _mostrarError("Contraseña debe tener 8+ caracteres, Mayúscula, Número y Símbolo");
    if (!aceptaCondiciones) return _mostrarError("Debes aceptar los términos");

    setState(() => isLoading = true);

    try {
      final phoneCheck = await FirebaseFirestore.instance
          .collection('users')
          .where('telefono', isEqualTo: telefono)
          .get();

      if (phoneCheck.docs.isNotEmpty) {
        _mostrarError("Este número ya está registrado");
        setState(() => isLoading = false);
        return;
      }

      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String uid = userCredential.user!.uid;

      String? fotoUrl = await _subirArchivo(_imagenSeleccionada!, 'user_photos', uid);
      String? carnetUrl = await _subirArchivo(_imagenCarnet!, 'user_id_documents', uid);

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'nombre': _nombreController.text.trim(),
        'rut': _rutController.text.trim(),
        'email': email,
        'telefono': telefono,
        'genero': generoSeleccionado,
        'fechaNacimiento': _fechaNacimiento,
        'photoUrl': fotoUrl,
        'idDocumentUrl': carnetUrl,
        'isVerified': false, 
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

  void _mostrarTerminos(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            "Términos y Condiciones",
            style: TextStyle(color: Color(0xFF1A4371), fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Bienvenido a TripMate.\n\n"
                    "1. Uso del Servicio: Nuestra plataforma facilita el contacto entre conductores y pasajeros...\n\n"
                    "2. Seguridad: Los usuarios deben proporcionar datos reales y verificables...\n\n"
                    "3. Privacidad: Sus datos serán tratados según nuestra política de protección de datos...\n\n"
                    "4. Responsabilidad: TripMate no se hace responsable por acuerdos privados entre usuarios...",
                    style: TextStyle(fontSize: 14, color: Colors.black),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("ENTENDIDO", style: TextStyle(color: Color(0xFFF05A28), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _mostrarLegales(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return DefaultTabController(
          length: 2,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: EdgeInsets.zero,
            title: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 20, bottom: 10),
                  child: Text("Información Legal", 
                    style: TextStyle(color: Color(0xFF1A4371), fontWeight: FontWeight.bold)),
                ),
                const TabBar(
                  labelColor: Color(0xFF2BB8D1),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Color(0xFF2BB8D1),
                  tabs: [
                    Tab(text: "Términos"),
                    Tab(text: "Privacidad"),
                  ],
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.5, 
              child: TabBarView(
                children: [
                  _seccionLegal(
                    titulo: "TÉRMINOS Y CONDICIONES", 
                    contenido: TripMateLegales.terminosYCondiciones 
                  ),
                  _seccionLegal(
                    titulo: "POLÍTICA DE PRIVACIDAD", 
                    contenido: TripMateLegales.politicaPrivacidad 
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CERRAR", style: TextStyle(color: Color(0xFFF05A28), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _seccionLegal({required String titulo, required String contenido}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          Text(contenido, style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
        title: const Text("Completa tu perfil", style: TextStyle(color: Color(0xFF1A4371), fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              Center(
                child: GestureDetector(
                  onTap: () => _seleccionarImagen(true), 
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

              _buildFieldLabel("Teléfono Móvil"),
              _buildTextField(controller: _phoneController, hint: "912345678", icon: Icons.phone_iphone, keyboardType: TextInputType.phone),

              const SizedBox(height: 15),

              _buildFieldLabel("Documento de Identidad (Carnet)"),
              InkWell(
                onTap: () => _seleccionarImagen(false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _imagenCarnet != null ? Colors.green : Colors.transparent),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.camera_front, color: _imagenCarnet != null ? Colors.green : const Color(0xFF2BB8D1)),
                      const SizedBox(width: 12),
                      Text(
                        _imagenCarnet != null ? "¡Carnet cargado!" : "Subir foto frontal carnet",
                        style: TextStyle(color: _imagenCarnet != null ? Colors.green : Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 15),

              _buildFieldLabel("Correo electrónico"),
              _buildTextField(controller: _emailController, hint: "correo@ejemplo.com", icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),

              const SizedBox(height: 15),

              _buildFieldLabel("Género"),
              DropdownButtonFormField<String>(
                value: generoSeleccionado,
                // Asegura que el fondo del menú desplegable sea blanco
                dropdownColor: Colors.white, 
                decoration: _inputDecoration(Icons.wc_outlined).copyWith(
                  hintText: "Selecciona tu género",
                  hintStyle: const TextStyle(color: Colors.grey),
                ),
                // Esto controla cómo se ve el texto DESPUÉS de seleccionar una opción
                selectedItemBuilder: (BuildContext context) {
                  return ["Masculino", "Femenino", "Otros"].map<Widget>((String item) {
                    return Text(
                      item,
                      style: const TextStyle(
                        color: Color(0xFF1A4371), // Tu azul oscuro de TripMate
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  }).toList();
                },
                items: ["Masculino", "Femenino", "Otros"].map((e) {
                  return DropdownMenuItem(
                    value: e,
                    child: Text(
                      e,
                      style: const TextStyle(color: Colors.black87, fontSize: 16),
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  setState(() {
                    generoSeleccionado = v;
                  });
                },
              ),

              const SizedBox(height: 15),

              _buildFieldLabel("Fecha de nacimiento"),
              GestureDetector(
                onTap: () => _seleccionarFecha(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  decoration: BoxDecoration(color: const Color(0xFFF8F9FB), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, color: Color(0xFF2BB8D1)),
                      const SizedBox(width: 12),
                      Text(
                        _fechaNacimiento == null 
                            ? "Selecciona tu fecha" 
                            : DateFormat('dd / MM / yyyy').format(_fechaNacimiento!),
                        style: TextStyle(color: _fechaNacimiento == null ? Colors.grey : Colors.black87, fontSize: 16),
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
                  hintText: "8+ carac, Mayús y Símbolo",
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
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _mostrarLegales(context), // <--- Llamamos a la nueva función
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                          children: [
                            const TextSpan(text: "Acepto los "),
                            TextSpan(
                              text: "términos y condiciones",
                              style: TextStyle(
                                color: const Color(0xFF2BB8D1),
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const TextSpan(text: " y la "),
                            TextSpan(
                              text: "política de privacidad",
                              style: TextStyle(
                                color: const Color(0xFF2BB8D1),
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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

}