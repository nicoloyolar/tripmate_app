// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:tripmate_app/core/utils/formatters.dart';

class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  Future<void> _cancelarReserva(BuildContext context, Map<String, dynamic> booking, String bookingId) async {
    final String? tripId = booking['tripId'];
    
    final int cantidadADevolver = booking['cantidadAsientos'] ?? 1;

    if (tripId == null) {
      _mostrarSnackBar(context, "Error: No se encontró el ID del viaje", isError: true);
      return;
    }

    final DocumentReference tripRef = FirebaseFirestore.instance.collection('trips').doc(tripId);
    final DocumentReference bookingRef = FirebaseFirestore.instance.collection('bookings').doc(bookingId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot tripSnap = await transaction.get(tripRef);
        
        transaction.update(bookingRef, {
          'status': 'cancelado',
          'fechaCancelacion': FieldValue.serverTimestamp(),
        });

        if (tripSnap.exists) {
          int asientosEnViaje = tripSnap['asientosDisponibles'] ?? 0;
          
          transaction.update(tripRef, {
            'asientosDisponibles': asientosEnViaje + cantidadADevolver
          });
        }
      });

      _mostrarSnackBar(
        context, 
        "Reserva cancelada: se liberaron $cantidadADevolver cupos", 
        isError: false
      );

    } catch (e) {
      _mostrarSnackBar(context, "Error al cancelar: $e", isError: true);
    }
  }

  void _confirmarCancelacion(BuildContext context, Map<String, dynamic> booking, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("¿Cancelar reserva?", 
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A4371))),
        content: const Text("Se liberará tu asiento para que otro pasajero pueda tomarlo. Esta acción no se puede deshacer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("VOLVER", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context); 
              _cancelarReserva(context, booking, id);
            },
            child: const Text("SÍ, CANCELAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _cap(String? s) => 
      (s == null || s.isEmpty) ? '' : s[0].toUpperCase() + s.substring(1).toLowerCase();

  String _formatearFecha(Timestamp? ts) {
    if (ts == null) return "Sin fecha";
    return DateFormat('EEE, d MMM - HH:mm', 'es').format(ts.toDate());
  }

  String _obtenerTiempoRestante(Timestamp? fechaSalida) {
    if (fechaSalida == null) return "";
    final ahora = DateTime.now();
    final salida = fechaSalida.toDate();
    final diferencia = salida.difference(ahora);
    
    if (diferencia.isNegative) return "Viaje finalizado";
    if (diferencia.inDays > 0) return "En ${diferencia.inDays} días";
    if (diferencia.inHours > 0) return "En ${diferencia.inHours} h";
    return "En ${diferencia.inMinutes} min";
  }

  void _mostrarSnackBar(BuildContext context, String msj, {required bool isError}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msj),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF1A4371),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color colorCuerpo;
    Color colorTexto;
    String texto;

    switch (status.toLowerCase()) {
      case 'confirmado':
        colorCuerpo = const Color(0xFFE8F5E9); 
        colorTexto = const Color(0xFF2E7D32);  
        texto = "Confirmado";
        break;
      case 'cancelado':
        colorCuerpo = const Color(0xFFFFEBEE); 
        colorTexto = const Color(0xFFD32F2F);
        texto = "Cancelado";
        break;
      default:
        colorCuerpo = Colors.orange[50]!;
        colorTexto = Colors.orange[800]!;
        texto = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: colorCuerpo, borderRadius: BorderRadius.circular(10)),
      child: Text(texto.toUpperCase(),
        style: TextStyle(color: colorTexto, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Mis Reservas", 
          style: TextStyle(color: Color(0xFF1A4371), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, 
        elevation: 0, 
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('passengerId', isEqualTo: user?.uid)
            .orderBy('fechaReserva', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return _buildEmptyState(context);

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final booking = doc.data() as Map<String, dynamic>;
              return _buildBookingCard(context, booking, doc.id);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text("No tienes reservas activas", style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildBookingCard(BuildContext context, Map<String, dynamic> booking, String bookingId) {
    final String status = booking['status'] ?? 'Pendiente';
    final Timestamp? fechaSalidaTs = booking['fechaSalida'];
    final String tiempoFalta = _obtenerTiempoRestante(fechaSalidaTs);
    
    final bool esPasado = fechaSalidaTs != null && fechaSalidaTs.toDate().isBefore(DateTime.now());
    final bool esCancelado = status.toLowerCase() == 'cancelado';
    final bool puedeCancelar = !esPasado && !esCancelado;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusChip(status),
                if (!esPasado && !esCancelado)
                  Text(tiempoFalta, style: const TextStyle(color: Color(0xFFF05A28), fontWeight: FontWeight.bold, fontSize: 11)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Column(children: [
                  const Icon(Icons.circle, color: Color(0xFF2BB8D1), size: 12),
                  Container(height: 20, width: 1.5, color: Colors.grey[100]),
                  const Icon(Icons.location_on, color: Color(0xFFF05A28), size: 14),
                ]),
                const SizedBox(width: 15),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_cap(booking['origen']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A4371))),
                    const SizedBox(height: 10),
                    Text(_cap(booking['destino']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A4371))),
                  ],
                )),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(TripMateFormat.currencyCLP(booking['precio']), 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A4371))),
                  Text(_formatearFecha(fechaSalidaTs), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ]),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA), 
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24))
            ),
            child: Row(
              children: [
                Icon(
                  esCancelado ? Icons.cancel_outlined : (esPasado ? Icons.check_circle_outline : Icons.info_outline), 
                  size: 14, 
                  color: Colors.grey
                ),
                const SizedBox(width: 6),
                Text(
                  esCancelado ? "Reserva anulada" : (esPasado ? "Viaje completado" : "Presentarse 5 min antes"), 
                  style: TextStyle(color: Colors.grey[600], fontSize: 11)
                ),
                const Spacer(),
                if (puedeCancelar)
                  TextButton(
                    onPressed: () => _confirmarCancelacion(context, booking, bookingId),
                    child: const Text("CANCELAR", style: TextStyle(color: Color(0xFFD32F2F), fontSize: 11, fontWeight: FontWeight.bold)),
                  )
                else
                  const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ],
      ),
    );
  }
}