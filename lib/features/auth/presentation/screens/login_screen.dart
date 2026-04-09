// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tripmate_app/features/auth/presentation/screens/complete_profile_screen.dart';
import 'package:tripmate_app/features/trips/presentation/screens/main_navegation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _mostrarError("Por favor, llena todos los campos");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String mensaje = "Error al ingresar";
      if (e.code == 'user-not-found') mensaje = "Usuario no registrado";
      if (e.code == 'wrong-password') mensaje = "Contraseña incorrecta";
      if (e.code == 'invalid-email') mensaje = "Correo inválido";
      _mostrarError(mensaje);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            children: [
              const SizedBox(height: 60), 
              Image.asset(
                'assets/background-image-trip-mate.jpeg', 
                height: 350,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.directions_car_filled, size: 100, color: Color(0xFF1A4371),
                ),
              ), 

              const SizedBox(height: 20), 

              _buildTextField(
                controller: _emailController,
                hint: "Correo electrónico",
                icon: Icons.email_outlined,
              ),
              
              const SizedBox(height: 10),

              _buildTextField(
                controller: _passwordController,
                hint: "Contraseña",
                icon: Icons.lock_outline,
                isPassword: true,
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _iniciarSesion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF05A28),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Iniciar Sesión", 
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                      ),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      "O inicia sesión con",
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                ],
              ),

              const SizedBox(height: 25),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSocialCircle(
                    icon: Icons.g_mobiledata_rounded, 
                    color: Colors.red.shade700,
                    onTap: () => {},
                  ),
                  const SizedBox(width: 25),
                  _buildSocialCircle(
                    icon: Icons.facebook,
                    color: const Color(0xFF1877F2),
                    onTap: () => {},
                  ),
                  const SizedBox(width: 25),
                  _buildSocialCircle(
                    icon: Icons.apple,
                    color: Colors.black,
                    onTap: () => {},
                  ),
                ],
              ),

              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CompleteProfileScreen()),
                  );
                },
                child: const Text(
                  "¿No tienes cuenta? Regístrate",
                  style: TextStyle(color: Color(0xFF2BB8D1), fontWeight: FontWeight.w600, fontSize: 16,),
                ),
              ),

              TextButton(
                onPressed: _resetearPassword,
                child: const Text(
                  "¿Olvidaste tu contraseña?",
                  style: TextStyle(
                    color: Color(0xFF2BB8D1), 
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false, 
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey),
        suffixIcon: isPassword 
          ? IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            )
          : null,
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Future<void> _resetearPassword() async {
    final TextEditingController resetController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Recuperar contraseña"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Ingresa tu correo y te enviaremos un enlace para restablecer tu clave."),
            const SizedBox(height: 15),
            TextField(
              controller: resetController,
              decoration: InputDecoration(
                hintText: "tu@correo.com",
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2BB8D1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (resetController.text.trim().isEmpty) return;
              
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: resetController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  _mostrarError("Enlace enviado. Revisa tu correo.");
                }
              } catch (e) {
                _mostrarError("Error: Asegúrate de que el correo sea correcto.");
              }
            },
            child: const Text("Enviar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialCircle({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Icon(
          icon,
          size: 32,
          color: color,
        ),
      ),
    );
  }
}