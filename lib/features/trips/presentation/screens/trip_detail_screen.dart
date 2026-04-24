// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:tripmate_app/core/utils/formatters.dart';

class TripDetailScreen extends StatefulWidget {
  final Map<String, dynamic> tripData;

  const TripDetailScreen({super.key, required this.tripData});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  int _cantidadSeleccionada = 1;
  final TextEditingController _comentarioController = TextEditingController();

  String _cap(String? s) => (s == null || s.isEmpty) ? '' : s[0].toUpperCase() + s.substring(1).toLowerCase();

  Future<Map<String, dynamic>?> _getDriverData(String uid) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return userDoc.data() as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  String _formatearFechaLarga(Timestamp? timestamp) {
    if (timestamp == null) return "Fecha no definida";
    DateTime fecha = timestamp.toDate();
    return DateFormat("EEEE, d 'de' MMMM - HH:mm", 'es').format(fecha);
  }

  Future<void> _processBooking(BuildContext context, int cantidad, String comentario) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _mostrarMensaje(context, "Debes iniciar sesión para reservar", isError: true);
      return;
    }

    if (user.uid == widget.tripData['driverId']) {
      _mostrarMensaje(context, "No puedes reservar tu propio viaje", isError: true);
      return;
    }

    final String? tripId = widget.tripData['id'] ?? widget.tripData['tripId']; 
    if (tripId == null) {
      _mostrarMensaje(context, "Error: ID del viaje no encontrado", isError: true);
      return;
    }

    final DocumentReference tripRef = FirebaseFirestore.instance.collection('trips').doc(tripId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot tripSnapshot = await transaction.get(tripRef);

        if (!tripSnapshot.exists) throw "El viaje ya no está disponible.";

        int asientosDisponibles = tripSnapshot['asientosDisponibles'] ?? 0;

        if (asientosDisponibles >= cantidad) {
          transaction.update(tripRef, {
            'asientosDisponibles': asientosDisponibles - cantidad
          });

          DocumentReference bookingRef = FirebaseFirestore.instance.collection('bookings').doc();
          
          transaction.set(bookingRef, {
            'bookingId': bookingRef.id,
            'tripId': tripId,
            'passengerId': user.uid,
            'driverId': widget.tripData['driverId'],
            'origen': widget.tripData['origen'],
            'destino': widget.tripData['destino'],
            'fechaSalida': widget.tripData['fechaSalida'],
            'precio': widget.tripData['precio'],
            'vehiculo': widget.tripData['vehiculo'], 
            'fechaReserva': FieldValue.serverTimestamp(),
            'cantidadAsientos': cantidad,
            'comentario': comentario.trim(),
            'status': 'confirmado',
            'deleted': false,       
          });
        } else {
          throw "Solo quedan $asientosDisponibles asientos disponibles.";
        }
      });

      if (mounted) {
        _mostrarMensaje(context, "¡Reserva realizada con éxito!", isError: false);
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) _mostrarMensaje(context, e.toString(), isError: true);
    }
  }

  void _mostrarMensaje(BuildContext context, String msj, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msj),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF1A4371),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String origenTexto = widget.tripData['origen'] is Map 
        ? widget.tripData['origen']['address'] 
        : widget.tripData['origen'].toString();

    final String destinoTexto = widget.tripData['destino'] is Map 
        ? widget.tripData['destino']['address'] 
        : widget.tripData['destino'].toString();
    final String driverId = widget.tripData['driverId'] ?? '';
    final Timestamp? fechaSalida = widget.tripData['fechaSalida'];
    final int cuposMaximos = widget.tripData['asientosDisponibles'] ?? 0;
    final String? miUid = FirebaseAuth.instance.currentUser?.uid;
    final bool soyElConductor = miUid == driverId;
    final int precioUnitario = widget.tripData['precio'] ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Resumen del Viaje", 
          style: TextStyle(color: Color(0xFF1A4371), fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF1A4371)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            FutureBuilder<Map<String, dynamic>?>(
              future: _getDriverData(driverId),
              builder: (context, snapshot) {
                final userData = snapshot.data;
                final String nombre = userData?['nombre'] ?? "Cargando...";
                final String? fotoUrl = userData?['photoUrl'];

                return Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A4371),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50, backgroundColor: Colors.white,
                        backgroundImage: (fotoUrl != null && fotoUrl.isNotEmpty) ? NetworkImage(fotoUrl) : null,
                        child: (fotoUrl == null || fotoUrl.isEmpty) ? const Icon(Icons.person, size: 60, color: Color(0xFF1A4371)) : null,
                      ),
                      const SizedBox(height: 15),
                      Text(nombre, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star, color: Color(0xFFFFD700), size: 16),
                          Icon(Icons.star, color: Color(0xFFFFD700), size: 16),
                          Icon(Icons.star, color: Color(0xFFFFD700), size: 16),
                          SizedBox(width: 5),
                          Text("4.8", style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            Padding(
              padding: const EdgeInsets.all(25.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("INFORMACIÓN DEL VIAJE", style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 20),
                  
                  _buildRouteStep(
                    icon: Icons.radio_button_checked, 
                    color: const Color(0xFF2BB8D1), 
                    city: _cap(origenTexto), // <--- CAMBIADO
                    label: "Punto de partida", 
                    isLast: false
                  ),
                  _buildRouteStep(
                    icon: Icons.location_on, 
                    color: const Color(0xFFF05A28), 
                    city: _cap(destinoTexto), // <--- CAMBIADO
                    label: "Destino final", 
                    isLast: true
                  ),
                  
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: const Color(0xFFF1F4F8), borderRadius: BorderRadius.circular(15)),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month, color: Color(0xFF1A4371)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_formatearFechaLarga(fechaSalida), style: const TextStyle(fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),
                  
                  const Text("VEHÍCULO", style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 10),
                  _buildVehicleSection(widget.tripData['vehiculo']),

                  const SizedBox(height: 25),
                  
                  Row(
                    children: [
                      _infoCard(Icons.event_seat, "$cuposMaximos Cupos", "Disponibles"),
                      const SizedBox(width: 15),
                      _infoCard(Icons.payments_outlined, TripMateFormat.currencyCLP(precioUnitario), "Precio p/p"),
                    ],
                  ),
                  
                  const SizedBox(height: 30),
                  
                  if (!soyElConductor && cuposMaximos > 0) ...[
                    const Divider(),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Asientos a reservar", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A4371))),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _cantidadSeleccionada > 1 ? () => setState(() => _cantidadSeleccionada--) : null,
                              icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFF05A28)),
                            ),
                            Text("$_cantidadSeleccionada", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            IconButton(
                              onPressed: _cantidadSeleccionada < cuposMaximos ? () => setState(() => _cantidadSeleccionada++) : null,
                              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2BB8D1)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _comentarioController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: "Ej: Llevo equipaje, ¿hay espacio?",
                        labelText: "Comentarios al conductor",
                        labelStyle: const TextStyle(color: Color(0xFF1A4371), fontSize: 13),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF1A4371))),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text("Total a pagar: ${TripMateFormat.currencyCLP(precioUnitario * _cantidadSeleccionada)}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A4371))),
                    ),
                  ],

                  const SizedBox(height: 30),
                  
                  SizedBox(
                    width: double.infinity, height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (cuposMaximos > 0 && !soyElConductor) ? const Color(0xFFF05A28) : Colors.grey[400],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: (cuposMaximos > 0 && !soyElConductor) ? 4 : 0,
                      ),
                      onPressed: (cuposMaximos > 0 && !soyElConductor) 
                          ? () => _processBooking(context, _cantidadSeleccionada, _comentarioController.text) 
                          : null,
                      child: Text(
                        soyElConductor 
                            ? "ESTE ES TU VIAJE" 
                            : (cuposMaximos > 0 ? "CONFIRMAR RESERVA" : "VIAJE AGOTADO"), 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleSection(dynamic vehiculo) {
    if (vehiculo == null) return const Text("Información no disponible");
    final String marca = vehiculo['marca']?.toString() ?? 'Auto';
    final String modelo = vehiculo['modelo']?.toString() ?? '';
    final String color = vehiculo['color']?.toString() ?? '';
    final String patente = vehiculo['patente']?.toString() ?? 'S/P';

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[100]!)),
      child: Row(
        children: [
          const Icon(Icons.directions_car_filled, color: Color(0xFF2BB8D1), size: 30),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("${_cap(marca)} ${_cap(modelo)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text("Color: ${_cap(color)}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFF1F4F8), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black12)),
            child: Text(patente.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
          )
        ],
      ),
    );
  }

  Widget _infoCard(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[200]!),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
        child: Column(children: [
          Icon(icon, color: const Color(0xFF2BB8D1)), 
          const SizedBox(height: 8), 
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A4371))), 
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10))
        ]),
      ),
    );
  }

  Widget _buildRouteStep({required IconData icon, required Color color, required String city, required String label, required bool isLast}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(children: [Icon(icon, color: color, size: 28), if (!isLast) Container(width: 2, height: 40, color: Colors.grey[200])]),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(city, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1A4371))), 
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)), 
          const SizedBox(height: 15)
        ])),
      ],
    );
  }
}