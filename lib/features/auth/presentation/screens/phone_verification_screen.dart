// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:tripmate_app/features/home/presentation/screens/home_screen.dart';

class PhoneVerificationScreen extends StatefulWidget {
  const PhoneVerificationScreen({super.key});

  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  bool noRecibirOfertas = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2BB8D1), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Completa tu perfil",
          style: TextStyle(color: Color(0xFF2BB8D1), fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              "Verifiquemos tu número\nde teléfono",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2BB8D1),
              ),
            ),
            const SizedBox(height: 30),
            
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
                    ],
                  ),
                  child: Row(
                    children: [
                      const Text("🇨🇱", style: TextStyle(fontSize: 20)), 
                      const SizedBox(width: 8),
                      const Text("(+56)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                const Expanded(
                  child: TextField(
                    keyboardType: TextInputType.phone,
                    style: TextStyle(fontSize: 20, letterSpacing: 1.5),
                    decoration: InputDecoration(
                      hintText: "9 1234 56789",
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 40),
            const Center(
              child: Text(
                "Te llegará un SMS con el código\nde confirmación",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 14),
              ),
            ),
            
            const SizedBox(height: 30),
            
            Row(
              children: [
                Checkbox(
                  value: noRecibirOfertas,
                  activeColor: const Color(0xFF1A4371),
                  onChanged: (val) {
                    setState(() {
                      noRecibirOfertas = val!;
                    });
                  },
                ),
                const Expanded(
                  child: Text(
                    "No quiero recibir ofertas ni recomendaciones de TripMate por mensajes ni por teléfono.",
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              ],
            ),

            SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF05A28),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    "Guardar y Continuar",
                    style: TextStyle(
                      color: Colors.white, 
                      fontSize: 18, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}