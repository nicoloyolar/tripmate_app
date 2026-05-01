// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:tripmate_app/core/utils/formatters.dart';
import 'package:tripmate_app/features/trips/presentation/screens/trip_detail_screen.dart';

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  String _capitalizar(String texto) {
    if (texto.isEmpty) return texto;
    return texto[0].toUpperCase() + texto.substring(1);
  }

  String _safeLocation(dynamic location) {
    if (location == null) return "Sin dirección";
    if (location is Map) {
      return location['address']?.toString() ?? "Dirección no disponible";
    }
    return location.toString();
  }

  Future<void> _confirmarEliminar(BuildContext context, String tripId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar viaje"),
        content: const Text(
          "Este viaje dejará de aparecer en tus viajes publicados.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCELAR"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text(
              "ELIMINAR",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    await FirebaseFirestore.instance.collection('trips').doc(tripId).update({
      'deleted': true,
      'estado': 'eliminado',
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text(
          "Mis Viajes Publicados",
          style: TextStyle(
            color: Color(0xFF1A4371),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('trips')
            .where('driverId', isEqualTo: uid)
            .orderBy('fechaSalida', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.directions_car_filled_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Aún no has publicado viajes",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          final trips = snapshot.data!.docs.where((doc) {
            final trip = doc.data() as Map<String, dynamic>;
            return trip['deleted'] != true;
          }).toList();

          if (trips.isEmpty) {
            return const Center(
              child: Text("No tienes viajes activos o visibles."),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              // try-catch para que un solo viaje corrupto no mate toda la pantalla
              try {
                var trip = trips[index].data() as Map<String, dynamic>;
                final tripId = trips[index].id;
                trip['tripId'] = tripId;
                final fechaSalida = trip['fechaSalida'] is Timestamp
                    ? (trip['fechaSalida'] as Timestamp).toDate()
                    : null;
                final viajePasado =
                    fechaSalida != null && fechaSalida.isBefore(DateTime.now());

                String fechaStr = "Sin fecha";
                if (fechaSalida != null) {
                  fechaStr = DateFormat(
                    'dd MMM, HH:mm',
                    'es',
                  ).format(fechaSalida);
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2BB8D1).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.directions_car,
                        color: Color(0xFF2BB8D1),
                      ),
                    ),
                    title: Text(
                      "${_capitalizar(_safeLocation(trip['origen']))} → ${_capitalizar(_safeLocation(trip['destino']))}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A4371),
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 5),
                        Text(
                          fechaStr,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Text(
                              TripMateFormat.currencyCLP(trip['precio']),
                              style: const TextStyle(
                                color: Color(0xFFF05A28),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.person,
                              size: 14,
                              color: Colors.grey,
                            ),
                            Text(
                              " ${trip['asientosDisponibles']} cupos",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: viajePasado
                        ? IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                            onPressed: () =>
                                _confirmarEliminar(context, tripId),
                          )
                        : const Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Colors.grey,
                          ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              TripDetailScreen(tripData: trip),
                        ),
                      );
                    },
                  ),
                );
              } catch (e) {
                return const ListTile(
                  title: Text("Error al cargar datos de este viaje"),
                );
              }
            },
          );
        },
      ),
    );
  }
}
