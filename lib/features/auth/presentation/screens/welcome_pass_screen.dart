import 'package:flutter/material.dart';
import 'package:tripmate_app/features/auth/presentation/screens/complete_profile_screen.dart';

class WelcomePassScreen extends StatelessWidget {
  const WelcomePassScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              Image.asset(
                'assets/logo_tripmate.png', 
                height: 120,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.directions_car_filled,
                  size: 100,
                  color: Color(0xFF1A4371),
                ),
              ),
              
              const SizedBox(height: 40),
              
              const Text(
                "¡Ahora completemos tu información para generar confianza en conductores y pasajeros!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color.fromARGB(255, 1, 47, 212),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 40),
              
              const Text(
                "El 74% de los usuarios declara confiar más en servicios ofrecidos por perfiles verificados",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF2BB8D1),
                  fontSize: 16,
                ),
              ),
              
              const Spacer(),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CompleteProfileScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF05A28), // Naranja
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    "Comenzar",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}