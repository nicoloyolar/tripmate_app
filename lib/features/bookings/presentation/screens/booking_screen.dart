// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:tripmate_app/core/utils/formatters.dart';
import 'package:tripmate_app/features/chat/presentation/screens/chat_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  String _filtroActual = 'todos';

  // FUNCIÓN AUXILIAR: Extrae la dirección de forma segura
  String _getText(dynamic data) {
    if (data == null) return "No disponible";
    if (data is Map) return data['address'] ?? "Sin dirección";
    return data.toString();
  }

  String _formatearFecha(Timestamp? ts) {
    if (ts == null) return "Sin fecha";
    return DateFormat('EEE, d MMM - HH:mm', 'es').format(ts.toDate());
  }

  void _mostrarSnackBar(
    BuildContext context,
    String msj, {
    required bool isError,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msj),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF1A4371),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _cancelarReserva(
    BuildContext context,
    Map<String, dynamic> booking,
    String bookingId,
  ) async {
    final String? tripId = booking['tripId'];
    final int cantidadADevolver = booking['cantidadAsientos'] ?? 1;
    final statusActual = (booking['status'] ?? 'confirmado')
        .toString()
        .toLowerCase();

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference bookingRef = FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId);
        DocumentReference? tripRef;
        DocumentSnapshot? tripSnap;

        if (statusActual == 'confirmado' && tripId != null) {
          tripRef = FirebaseFirestore.instance.collection('trips').doc(tripId);
          tripSnap = await transaction.get(tripRef);
        }

        transaction.update(bookingRef, {
          'status': 'cancelado',
          'paymentStatus': 'liberado',
          'fechaCancelacion': FieldValue.serverTimestamp(),
        });

        final paymentIntentId = booking['paymentIntentId'];
        if (paymentIntentId != null) {
          final paymentRef = FirebaseFirestore.instance
              .collection('payment_intents')
              .doc(paymentIntentId);
          transaction.update(paymentRef, {
            'status': 'released',
            'releasedAt': FieldValue.serverTimestamp(),
          });
        }

        if (tripRef != null && tripSnap != null && tripSnap.exists) {
          int asientosEnViaje = tripSnap['asientosDisponibles'] ?? 0;
          transaction.update(tripRef, {
            'asientosDisponibles': asientosEnViaje + cantidadADevolver,
          });
        }
      });

      _mostrarSnackBar(
        context,
        "Reserva cancelada exitosamente",
        isError: false,
      );
    } catch (e) {
      _mostrarSnackBar(context, "Error al cancelar: $e", isError: true);
    }
  }

  void _confirmarCancelacion(
    BuildContext context,
    Map<String, dynamic> booking,
    String id,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text(
              "Cancelar Reserva",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          "¿Estás seguro de que deseas cancelar esta reserva? Esta acción no se puede deshacer.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("VOLVER"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _cancelarReserva(context, booking, id);
            },
            child: const Text("SÍ, CANCELAR"),
          ),
        ],
      ),
    );
  }

  void _abrirChat(
    BuildContext context,
    Map<String, dynamic> booking,
    String bookingId,
  ) {
    final tripId = booking['tripId']?.toString() ?? '';
    final driverId = booking['driverId']?.toString() ?? '';
    final passengerId = booking['passengerId']?.toString() ?? '';
    if (tripId.isEmpty || driverId.isEmpty || passengerId.isEmpty) {
      _mostrarSnackBar(
        context,
        "No se pudo abrir el chat de esta reserva.",
        isError: true,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          bookingId: bookingId,
          tripId: tripId,
          driverId: driverId,
          passengerId: passengerId,
          title: "Chat del viaje",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Mis Reservas",
          style: TextStyle(
            color: Color(0xFF1A4371),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFiltros(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('passengerId', isEqualTo: user?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text("Error al cargar datos"));
                }

                var docs = snapshot.data?.docs ?? [];
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['fechaSalida'] == null) return false;

                  final salida = (data['fechaSalida'] as Timestamp).toDate();
                  final status = (data['status'] ?? 'confirmado')
                      .toString()
                      .toLowerCase();
                  final ahora = DateTime.now();

                  if (_filtroActual == 'todos') return true;
                  if (_filtroActual == 'pasado') {
                    return salida.isBefore(ahora) && status == 'confirmado';
                  }
                  if (_filtroActual == 'pendiente') {
                    return status == 'pendiente';
                  }
                  if (_filtroActual == 'confirmado') {
                    return status == 'confirmado' && salida.isAfter(ahora);
                  }
                  if (_filtroActual == 'cancelado') {
                    return status == 'cancelado';
                  }
                  return true;
                }).toList();

                if (filteredDocs.isEmpty) return _buildEmptyState();

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final booking =
                        filteredDocs[index].data() as Map<String, dynamic>;
                    return _buildBookingCard(
                      context,
                      booking,
                      filteredDocs[index].id,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        children: [
          _filterChip("todos", "Todas"),
          _filterChip("pendiente", "Pendientes"),
          _filterChip("confirmado", "Próximas"),
          _filterChip("cancelado", "Canceladas"),
          _filterChip("pasado", "Historial"),
        ],
      ),
    );
  }

  Widget _filterChip(String id, String label) {
    bool selected = _filtroActual == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black54,
            fontSize: 12,
          ),
        ),
        selected: selected,
        onSelected: (val) => setState(() => _filtroActual = id),
        selectedColor: const Color(0xFF2BB8D1),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildBookingCard(
    BuildContext context,
    Map<String, dynamic> booking,
    String bookingId,
  ) {
    final Timestamp? fechaSalidaTs = booking['fechaSalida'];
    final salida = fechaSalidaTs?.toDate() ?? DateTime.now();
    final ahora = DateTime.now();
    final diferencia = salida.difference(ahora);

    final String status = (booking['status'] ?? 'confirmado')
        .toString()
        .toLowerCase();

    bool estaCerca =
        status == 'confirmado' &&
        diferencia.inMinutes <= 60 &&
        diferencia.inMinutes > 0;
    bool esMuyCritico = estaCerca && diferencia.inMinutes <= 30;

    bool esPasado = salida.isBefore(ahora);
    bool esCancelado = status == 'cancelado';

    String origen = _getText(booking['origen']);
    String destino = _getText(booking['destino']);

    return GestureDetector(
      onTap: () => _mostrarDetalles(context, booking, bookingId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              if (estaCerca)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  color: esMuyCritico
                      ? const Color(0xFFFFEBEE)
                      : const Color(0xFFFFF3E0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.access_alarm_rounded,
                        size: 14,
                        color: esMuyCritico ? Colors.red : Colors.orange[800],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        esMuyCritico
                            ? "¡APÚRATE! Faltan solo ${diferencia.inMinutes} min"
                            : "Tu viaje inicia en ${diferencia.inMinutes} min",
                        style: TextStyle(
                          color: esMuyCritico ? Colors.red : Colors.orange[900],
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              Stack(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(15, 20, 15, 15),
                    leading: _buildConductorInfo(booking['driverId']),
                    title: Text(
                      "$origen → $destino",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: const Color(0xFF1A4371),
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 5),
                        Text(
                          _formatearFecha(fechaSalidaTs),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          TripMateFormat.currencyCLP(booking['precio'] ?? 0),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: esCancelado
                                ? Colors.grey
                                : const Color(0xFF2BB8D1),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _buildStatusBadge(status, esPasado),
                  ),
                ],
              ),

              if (!esPasado && !esCancelado)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, right: 15),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () =>
                              _abrirChat(context, booking, bookingId),
                          icon: const Icon(Icons.chat_bubble_outline, size: 16),
                          label: const Text(
                            "CHAT",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _confirmarCancelacion(
                            context,
                            booking,
                            bookingId,
                          ),
                          child: const Text(
                            "CANCELAR RESERVA",
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool esPasado) {
    Color bgColor;
    String text;

    if (status == 'cancelado') {
      bgColor = Colors.red[50]!;
      text = "CANCELADO";
    } else if (status == 'rechazado') {
      bgColor = Colors.red[50]!;
      text = "RECHAZADO";
    } else if (status == 'pendiente') {
      bgColor = const Color(0xFFFFF3E0);
      text = "PENDIENTE";
    } else if (esPasado) {
      bgColor = Colors.grey[100]!;
      text = "FINALIZADO";
    } else {
      bgColor = const Color(0xFFE3F2FD);
      text = "CONFIRMADO";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(15)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: text == "CANCELADO" || text == "RECHAZADO"
              ? Colors.red
              : (text == "FINALIZADO" ? Colors.grey : const Color(0xFF1A4371)),
          fontWeight: FontWeight.bold,
          fontSize: 8,
        ),
      ),
    );
  }

  Widget _buildConductorInfo(String? driverId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(driverId)
          .get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const CircleAvatar(
            radius: 18,
            child: Icon(Icons.person, size: 18),
          );
        }
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: data['photoUrl'] != null
                  ? NetworkImage(data['photoUrl'])
                  : null,
              child: data['photoUrl'] == null
                  ? const Icon(Icons.person, size: 18)
                  : null,
            ),
            const SizedBox(height: 2),
            Text(
              data['nombre']?.toString().split(' ')[0] ?? "Driver",
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ],
        );
      },
    );
  }

  void _mostrarDetalles(
    BuildContext context,
    Map<String, dynamic> booking,
    String bookingId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Detalle del Viaje",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A4371),
              ),
            ),
            const Divider(height: 30),
            _detailItem(
              Icons.my_location,
              "Origen",
              _getText(booking['origen']),
            ),
            _detailItem(
              Icons.location_on,
              "Destino",
              _getText(booking['destino']),
            ),
            _detailItem(
              Icons.access_time,
              "Salida",
              _formatearFecha(booking['fechaSalida']),
            ),
            _detailItem(
              Icons.paid_outlined,
              "Precio",
              TripMateFormat.currencyCLP(booking['precio'] ?? 0),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _abrirChat(context, booking, bookingId),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text("Abrir chat con el conductor"),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Recuerda estar en el punto de encuentro 5 minutos antes.",
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _detailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2BB8D1)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car_filled_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 20),
          Text(
            "No hay viajes en esta categoría",
            style: TextStyle(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}
