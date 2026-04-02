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

              const SizedBox(height: 40), 

              _buildTextField(
                controller: _emailController,
                hint: "Correo electrónico",
                icon: Icons.email_outlined,
              ),
              
              const SizedBox(height: 20),

              _buildTextField(
                controller: _passwordController,
                hint: "Contraseña",
                icon: Icons.lock_outline,
                isPassword: true,
              ),

              const SizedBox(height: 30),

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

              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CompleteProfileScreen()),
                  );
                },
                child: const Text(
                  "¿No tienes cuenta? Regístrate",
                  style: TextStyle(color: Color(0xFF2BB8D1), fontWeight: FontWeight.w600),
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
    bool isPassword = false
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}