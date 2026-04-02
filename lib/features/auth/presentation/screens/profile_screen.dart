// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; 
import 'package:tripmate_app/features/auth/presentation/screens/login_screen.dart';
import 'package:tripmate_app/features/profile/presentation/screens/edit_vehicle_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  String _formatBirthDate(dynamic fecha) {
    if (fecha == null) return "No definida";
    if (fecha is Timestamp) {
      DateTime date = fecha.toDate();
      return DateFormat('dd / MM / yyyy').format(date);
    }
    return fecha.toString();
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB), 
      appBar: AppBar(
        title: const Text("Mi Perfil", 
          style: TextStyle(color: Color(0xFF1A4371), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("No se encontraron datos del usuario"));
          }
          
          var userData = snapshot.data!.data() as Map<String, dynamic>;
          
          String nombre = userData['nombre'] ?? 'Usuario';
          String email = userData['email'] ?? 'Sin correo';
          String rut = userData['rut'] ?? 'Sin RUT';
          String genero = userData['genero'] ?? 'No especificado';
          String? photoUrl = userData['photoUrl']; 
          dynamic fechaNac = userData['fechaNacimiento'];
          
          Map<String, dynamic>? vehiculo = userData['vehiculo'] != null 
              ? Map<String, dynamic>.from(userData['vehiculo']) 
              : null;

          return SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 55,
                        backgroundColor: const Color(0xFF1A4371).withOpacity(0.1),
                        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) 
                            ? NetworkImage(photoUrl) 
                            : null,
                        child: (photoUrl == null || photoUrl.isEmpty) 
                            ? const Icon(Icons.person, size: 60, color: Color(0xFF1A4371))
                            : null,
                      ),
                      const SizedBox(height: 15),
                      Text(nombre, 
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A4371))),
                      Text(email, 
                        style: const TextStyle(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("INFORMACIÓN PERSONAL", 
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                      const SizedBox(height: 15),
                      _buildInfoTile(Icons.assignment_ind_outlined, "R.U.T", rut),
                      _buildInfoTile(Icons.wc_outlined, "Género", genero),
                      _buildInfoTile(Icons.cake_outlined, "Fecha de nacimiento", _formatBirthDate(fechaNac)),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("MI VEHÍCULO", 
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                      const SizedBox(height: 15),
                      _buildVehicleSection(context, vehiculo),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _logout(context),
                      icon: const Icon(Icons.logout, color: Color(0xFFF05A28)),
                      label: const Text("Cerrar Sesión", 
                        style: TextStyle(color: Color(0xFFF05A28), fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFF05A28)),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVehicleSection(BuildContext context, Map<String, dynamic>? vehiculo) {
    bool tieneVehiculo = vehiculo != null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EditVehicleScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: tieneVehiculo ? Colors.white : const Color(0xFF2BB8D1).withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: tieneVehiculo ? Colors.transparent : const Color(0xFF2BB8D1).withOpacity(0.3),
            style: tieneVehiculo ? BorderStyle.none : BorderStyle.solid,
          ),
          boxShadow: tieneVehiculo ? [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
          ] : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.directions_car_filled_outlined, 
              color: tieneVehiculo ? const Color(0xFF2BB8D1) : Colors.grey, 
              size: 30
            ),
            const SizedBox(width: 20),
            Expanded(
              child: tieneVehiculo 
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${vehiculo['marca']} ${vehiculo['modelo']}", 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A4371))),
                      Text("Patente: ${vehiculo['patente']}", 
                        style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  )
                : const Text("Registra tu vehículo para publicar viajes", 
                    style: TextStyle(fontSize: 14, color: Color(0xFF1A4371), fontWeight: FontWeight.w500)),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03), 
            blurRadius: 10, 
            offset: const Offset(0, 4)
          )
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2BB8D1), size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A4371))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}