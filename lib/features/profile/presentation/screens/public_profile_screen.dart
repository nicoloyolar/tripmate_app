import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PublicProfileScreen extends StatelessWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  String _formatBirthDate(dynamic fecha) {
    if (fecha == null) return "No informada";
    if (fecha is Timestamp) return DateFormat('yyyy').format(fecha.toDate());
    return fecha.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text(
          "Perfil",
          style: TextStyle(
            color: Color(0xFF1A4371),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A4371)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("No se pudo cargar este perfil"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final nombre = data['nombre'] ?? 'Usuario';
          final bio = data['bio'] ?? 'Sin biografía añadida';
          final photoUrl = data['photoUrl'];
          final isVerified = data['isVerified'] == true;
          final isLicenseVerified = data['isLicenseVerified'] == true;
          final vehiculos = List<dynamic>.from(data['vehiculos'] ?? []);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Column(
                children: [
                  CircleAvatar(
                    radius: 58,
                    backgroundColor: const Color(
                      0xFF1A4371,
                    ).withValues(alpha: 0.1),
                    backgroundImage:
                        (photoUrl != null && photoUrl.toString().isNotEmpty)
                        ? NetworkImage(photoUrl)
                        : null,
                    child: (photoUrl == null || photoUrl.toString().isEmpty)
                        ? const Icon(
                            Icons.person,
                            color: Color(0xFF1A4371),
                            size: 58,
                          )
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          nombre,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A4371),
                          ),
                        ),
                      ),
                      if (isVerified) const SizedBox(width: 6),
                      if (isVerified)
                        const Icon(Icons.verified, color: Color(0xFF2BB8D1)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bio,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _section("CONFIANZA"),
              _tile(
                Icons.badge_outlined,
                "Perfil",
                isVerified ? "Verificado" : "En revisión",
                isVerified,
              ),
              _tile(
                Icons.contact_mail_outlined,
                "Documentos conductor",
                isLicenseVerified ? "Aprobados" : "Pendientes",
                isLicenseVerified,
              ),
              _tile(
                Icons.cake_outlined,
                "Año de nacimiento",
                _formatBirthDate(data['fechaNacimiento']),
                true,
              ),
              const SizedBox(height: 20),
              _section("VEHÍCULOS"),
              if (vehiculos.isEmpty)
                const Text(
                  "Este usuario aún no tiene vehículos visibles.",
                  style: TextStyle(color: Colors.grey),
                )
              else
                ...vehiculos.map(
                  (v) => _vehicleCard(Map<String, dynamic>.from(v)),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _tile(IconData icon, String title, String subtitle, bool ok) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: ok ? Colors.green : Colors.orange),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A4371),
          ),
        ),
        subtitle: Text(subtitle),
      ),
    );
  }

  Widget _vehicleCard(Map<String, dynamic> vehicle) {
    final verified = vehicle['verificado'] == true;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          Icons.directions_car,
          color: verified ? Colors.green : const Color(0xFF2BB8D1),
        ),
        title: Text(
          "${vehicle['marca'] ?? ''} ${vehicle['modelo'] ?? ''}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          verified ? "Vehículo verificado" : "Vehículo en revisión",
        ),
        trailing: Text((vehicle['patente'] ?? '').toString().toUpperCase()),
      ),
    );
  }
}
