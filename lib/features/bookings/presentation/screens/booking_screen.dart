// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:tripmate_app/core/utils/formatters.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  String _filtroActual = 'todos'; 

  Future<void> _cancelarReserva(BuildContext context, Map<String, dynamic> booking, String bookingId) async {
    final String? tripId = booking['tripId'];
    final int cantidadADevolver = booking['cantidadAsientos'] ?? 1;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference tripRef = FirebaseFirestore.instance.collection('trips').doc(tripId);
        DocumentReference bookingRef = FirebaseFirestore.instance.collection('bookings').doc(bookingId);
        
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

      _mostrarSnackBar(context, "Reserva cancelada exitosamente", isError: false);
    } catch (e) {
      _mostrarSnackBar(context, "Error al cancelar: $e", isError: true);
    }
  }

  void _confirmarCancelacion(BuildContext context, Map<String, dynamic> booking, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text("Aviso de Sanción", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Al cancelar como PASAJERO:"),
            SizedBox(height: 10),
            Text("• Si faltan menos de 2h, se descontarán 5 puntos de tu nivel de confianza.", 
              style: TextStyle(fontSize: 13, color: Colors.grey)),
            SizedBox(height: 5),
            Text("• El conductor será notificado de inmediato.", 
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("VOLVER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () { Navigator.pop(context); _cancelarReserva(context, booking, id); },
            child: const Text("ACEPTAR Y CANCELAR"),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(Timestamp? ts) {
    if (ts == null) return "Sin fecha";
    return DateFormat('EEE, d MMM - HH:mm', 'es').format(ts.toDate());
  }

  void _mostrarSnackBar(BuildContext context, String msj, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msj), backgroundColor: isError ? Colors.redAccent : const Color(0xFF1A4371))
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Mis Reservas", style: TextStyle(color: Color(0xFF1A4371), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
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
                  return Center(child: Text("Error al cargar datos"));
                }

                var docs = snapshot.data?.docs ?? [];

                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['fechaSalida'] == null) return false;
                  
                  final salida = (data['fechaSalida'] as Timestamp).toDate();
                  final status = (data['status'] ?? 'confirmado').toString().toLowerCase();
                  final ahora = DateTime.now();

                  if (_filtroActual == 'todos') return true;
                  if (_filtroActual == 'pasado') return salida.isBefore(ahora) && status == 'confirmado';
                  if (_filtroActual == 'confirmado') return status == 'confirmado' && salida.isAfter(ahora);
                  if (_filtroActual == 'cancelado') return status == 'cancelado';
                  
                  return true;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final booking = filteredDocs[index].data() as Map<String, dynamic>;
                    return _buildBookingCard(context, booking, filteredDocs[index].id);
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
        label: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.black54, fontSize: 12)),
        selected: selected,
        onSelected: (val) => setState(() => _filtroActual = id),
        selectedColor: const Color(0xFF2BB8D1),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildBookingCard(BuildContext context, Map<String, dynamic> booking, String bookingId) {
    final Timestamp? fechaSalidaTs = booking['fechaSalida'];
    final salida = fechaSalidaTs?.toDate() ?? DateTime.now();
    final diferencia = salida.difference(DateTime.now());
    
    bool esCritico = diferencia.inMinutes <= 60 && diferencia.inMinutes > 0 && booking['status'] == 'confirmado';
    bool esPasado = salida.isBefore(DateTime.now());
    bool esCancelado = booking['status'] == 'cancelado';

    return GestureDetector(
      onTap: () => _mostrarDetalles(context, booking),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: esCritico ? Border.all(color: const Color(0xFFF05A28), width: 1.5) : null,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        ),
        child: Column(
          children: [
            if (esCritico)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: const BoxDecoration(color: Color(0xFFF05A28), borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
                child: const Text("SALIDA EN MENOS DE 1 HORA", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ListTile(
              contentPadding: const EdgeInsets.all(15),
              leading: _buildConductorInfo(booking['driverId']),
              title: Text("${booking['origen']} → ${booking['destino']}", 
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A4371))),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  Text(_formatearFecha(fechaSalidaTs), style: const TextStyle(fontSize: 12)),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(TripMateFormat.currencyCLP(booking['precio']), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2BB8D1))),
                  const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                ],
              ),
            ),
            if (!esPasado && !esCancelado)
              Padding(
                padding: const EdgeInsets.only(bottom: 10, right: 15),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _confirmarCancelacion(context, booking, bookingId),
                    child: const Text("CANCELAR RESERVA", style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConductorInfo(String? driverId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(driverId).get(),
      builder: (context, snap) {
        if (!snap.hasData) return const CircleAvatar(radius: 20, child: Icon(Icons.person));
        final data = snap.data!.data() as Map<String, dynamic>;
        return Column(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: data['photoUrl'] != null ? NetworkImage(data['photoUrl']) : null,
              child: data['photoUrl'] == null ? const Icon(Icons.person, size: 18) : null,
            ),
            const SizedBox(height: 2),
            Text(data['nombre'].toString().split(' ')[0], style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        );
      },
    );
  }

  void _mostrarDetalles(BuildContext context, Map<String, dynamic> booking) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Detalle del Viaje", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A4371))),
            const Divider(height: 30),
            _detailItem(Icons.my_location, "Origen", booking['origen']),
            _detailItem(Icons.location_on, "Destino", booking['destino']),
            _detailItem(Icons.access_time, "Salida", _formatearFecha(booking['fechaSalida'])),
            _detailItem(Icons.paid_outlined, "Total Pagado", TripMateFormat.currencyCLP(booking['precio'])),
            const SizedBox(height: 20),
            const Text("Recuerda estar en el punto de encuentro 5 minutos antes.", 
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
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
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_filled_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text("No hay viajes en esta categoría", style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }
}