// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:tripmate_app/features/auth/presentation/screens/login_screen.dart';
import 'package:tripmate_app/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:tripmate_app/features/profile/presentation/screens/edit_vehicle_screen.dart';
import 'package:tripmate_app/features/profile/presentation/screens/payment_methods_screen.dart';
import 'package:tripmate_app/features/profile/presentation/screens/vehicle_detail_screen.dart';

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

  Future<void> _sendPasswordReset(BuildContext context) async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null || email.isEmpty) return;

    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Te enviamos un correo para cambiar tu contraseña."),
        ),
      );
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Borrar cuenta"),
        content: const Text(
          "Tu cuenta quedará marcada para eliminación. Esta acción debe ser revisada por soporte si tienes viajes o reservas activas.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCELAR"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("BORRAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'accountDeletionRequested': true,
      'accountDeletionRequestedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Solicitud de eliminación registrada.")),
      );
    }
  }

  String _formatBirthDate(dynamic fecha) {
    if (fecha == null) return "No definida";
    if (fecha is Timestamp) {
      return DateFormat('dd / MM / yyyy').format(fecha.toDate());
    }
    return fecha.toString();
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text(
          "Mi Perfil",
          style: TextStyle(
            color: Color(0xFF1A4371),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note, color: Color(0xFF1A4371)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EditProfileScreen(),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Error al cargar datos"));
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>;

          String nombre = userData['nombre'] ?? 'Usuario';
          String bio = userData['bio'] ?? 'Sin biografía añadida...';
          String? photoUrl = userData['photoUrl'];
          bool isVerified = userData['isVerified'] ?? false;
          bool isLicenseVerified = userData['isLicenseVerified'] ?? false;

          List<dynamic> vehiculos = userData['vehiculos'] ?? [];
          if (vehiculos.isEmpty && userData['vehiculo'] != null) {
            vehiculos = [userData['vehiculo']];
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // CABECERA PERFIL
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.only(bottom: 30, top: 10),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 55,
                            backgroundColor: const Color(
                              0xFF1A4371,
                            ).withOpacity(0.1),
                            backgroundImage:
                                (photoUrl != null && photoUrl.isNotEmpty)
                                ? NetworkImage(photoUrl)
                                : null,
                            child: (photoUrl == null || photoUrl.isEmpty)
                                ? const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Color(0xFF1A4371),
                                  )
                                : null,
                          ),
                          if (isVerified)
                            const Positioned(
                              bottom: 0,
                              right: 0,
                              child: Icon(
                                Icons.verified,
                                color: Color(0xFF2BB8D1),
                                size: 28,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(
                        nombre,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A4371),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 8,
                        ),
                        child: Text(
                          bio,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ESTADO DE VALIDACIÓN (Para que el usuario sepa por qué no puede publicar)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _buildVerificationSummary(
                    isVerified: isVerified,
                    isLicenseVerified: isLicenseVerified,
                    vehiculos: vehiculos,
                  ),
                ),

                // SECCIONES
                _buildSectionTitle("INFORMACIÓN PERSONAL"),
                _buildInfoGroup([
                  _buildInfoTile(
                    Icons.assignment_ind_outlined,
                    "R.U.T",
                    userData['rut'] ?? 'S/R',
                  ),
                  _buildInfoTile(
                    Icons.phone_iphone,
                    "Teléfono",
                    userData['telefono'] ?? 'No registrado',
                  ),
                  _buildInfoTile(
                    Icons.cake_outlined,
                    "Nacimiento",
                    _formatBirthDate(userData['fechaNacimiento']),
                  ),
                ]),

                _buildSectionTitle("PAGOS Y TARJETAS"),
                _buildInfoGroup([
                  _buildActionTile(
                    Icons.credit_card,
                    "Métodos de Pago",
                    "Gestionar mis tarjetas",
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PaymentMethodsScreen(),
                        ),
                      );
                    },
                  ),
                ]),

                _buildSectionTitle("DOCUMENTOS"),
                _buildInfoGroup([
                  _buildStatusTile(
                    Icons.badge_outlined,
                    "Documento de identidad",
                    isVerified ? "Aprobado" : "En revisión",
                    isVerified,
                  ),
                  _buildStatusTile(
                    Icons.contact_mail_outlined,
                    "Licencia / documentos conductor",
                    isLicenseVerified
                        ? "Aprobados"
                        : "Pendientes de aprobación",
                    isLicenseVerified,
                  ),
                  _buildInfoTile(
                    Icons.image_outlined,
                    "Foto documento",
                    userData['idDocumentUrl'] != null ? "Subida" : "Pendiente",
                  ),
                ]),

                _buildSectionTitle("MIS VEHÍCULOS"),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      ...vehiculos.map(
                        (v) => _buildVehicleCard(
                          context,
                          Map<String, dynamic>.from(v),
                          isLicenseVerified,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EditVehicleScreen(),
                          ),
                        ),
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Color(0xFF2BB8D1),
                        ),
                        label: const Text(
                          "Agregar otro vehículo",
                          style: TextStyle(
                            color: Color(0xFF2BB8D1),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                _buildSectionTitle("CUENTA"),
                _buildInfoGroup([
                  _buildActionTile(
                    Icons.lock_reset,
                    "Cambiar contraseña",
                    "Enviar correo de recuperación",
                    () => _sendPasswordReset(context),
                  ),
                  _buildActionTile(
                    Icons.delete_outline,
                    "Borrar cuenta",
                    "Solicitar eliminación de mi cuenta",
                    () => _deleteAccount(context),
                  ),
                ]),

                const SizedBox(height: 30),
                _buildLogoutButton(context),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoGroup(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildVerificationSummary({
    required bool isVerified,
    required bool isLicenseVerified,
    required List<dynamic> vehiculos,
  }) {
    final tieneVehiculoAprobado = vehiculos.any(
      (v) => v is Map && v['verificado'] == true,
    );
    final puedePublicar = isLicenseVerified && tieneVehiculoAprobado;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: puedePublicar
            ? Colors.green.withOpacity(0.08)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: puedePublicar
              ? Colors.green.withOpacity(0.25)
              : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                puedePublicar
                    ? Icons.verified_user
                    : Icons.warning_amber_rounded,
                color: puedePublicar ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  puedePublicar
                      ? "Tu cuenta está lista para publicar viajes."
                      : "Aún falta aprobación para publicar viajes.",
                  style: TextStyle(
                    fontSize: 13,
                    color: puedePublicar ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _miniStatus("Perfil", isVerified),
          _miniStatus("Licencia/documentos", isLicenseVerified),
          _miniStatus("Vehículo aprobado", tieneVehiculoAprobado),
        ],
      ),
    );
  }

  Widget _miniStatus(String label, bool ok) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.access_time_filled_rounded,
            size: 16,
            color: ok ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(
    BuildContext context,
    Map<String, dynamic> v,
    bool userLicenseVerified,
  ) {
    bool carVerified = v['verificado'] ?? false;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VehicleDetailScreen(vehicle: v),
        ),
      ),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: carVerified
                ? Colors.transparent
                : Colors.orange.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.directions_car_rounded,
              color: Color(0xFF2BB8D1),
              size: 35,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${v['marca']} ${v['modelo']}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A4371),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Patente: ${v['patente']}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    carVerified
                        ? "Vehículo verificado"
                        : "Documentos en revisión",
                    style: TextStyle(
                      fontSize: 11,
                      color: carVerified ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Icon(
                  carVerified
                      ? Icons.verified_user
                      : Icons.access_time_filled_rounded,
                  color: carVerified ? Colors.green : Colors.orange,
                  size: 24,
                ),
                if (!userLicenseVerified)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.contact_mail_outlined,
                      color: Colors.redAccent,
                      size: 16,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2BB8D1), size: 22),
      title: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A4371),
        ),
      ),
    );
  }

  Widget _buildStatusTile(
    IconData icon,
    String label,
    String value,
    bool approved,
  ) {
    return ListTile(
      leading: Icon(
        icon,
        color: approved ? Colors.green : Colors.orange,
        size: 22,
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: approved ? Colors.green : Colors.orange,
        ),
      ),
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: const Color(0xFFF05A28), size: 22),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A4371),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 12),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _logout(context),
          icon: const Icon(Icons.logout),
          label: const Text("Cerrar Sesión"),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFF05A28),
            side: const BorderSide(color: Color(0xFFF05A28)),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
