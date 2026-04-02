// ignore_for_file: deprecated_member_use

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:tripmate_app/core/utils/formatters.dart';
import 'package:tripmate_app/features/trips/presentation/screens/trip_detail_screen.dart';

class TripResultsScreen extends StatefulWidget {
  final String destinoBusqueda;
  
  const TripResultsScreen({super.key, required this.destinoBusqueda});

  @override
  State<TripResultsScreen> createState() => _TripResultsScreenState();
}

class _TripResultsScreenState extends State<TripResultsScreen> {
  
  String _cap(String? s) => (s == null || s.isEmpty) ? '' : s[0].toUpperCase() + s.substring(1).toLowerCase();

  String _formatearFecha(Timestamp? timestamp) {
    if (timestamp == null) return "Fecha no disponible";
    return DateFormat('E, dd MMM - HH:mm', 'es').format(timestamp.toDate());
  }

  Future<Map<String, dynamic>?> _getDriverData(String uid) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return userDoc.data() as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool esBusquedaGeneral = widget.destinoBusqueda.isEmpty;
    
    final DateTime limiteVigencia = DateTime.now().subtract(const Duration(minutes: 10));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F4F8),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(esBusquedaGeneral ? Icons.explore : Icons.location_on, 
                   color: const Color(0xFF1A4371), size: 18),
              const SizedBox(width: 8),
              Text(
                esBusquedaGeneral ? "Todos los destinos" : _cap(widget.destinoBusqueda),
                style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Text(
              esBusquedaGeneral 
                ? "Viajes disponibles ahora" 
                : "Viajes a ${_cap(widget.destinoBusqueda)} disponibles", 
              style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)
            ),
          ),
          const Divider(thickness: 1, height: 1),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: esBusquedaGeneral
                ? FirebaseFirestore.instance
                    .collection('trips')
                    .where('fechaSalida', isGreaterThanOrEqualTo: limiteVigencia)
                    .orderBy('fechaSalida', descending: false)
                    .snapshots()
                : FirebaseFirestore.instance
                    .collection('trips')
                    .where('destino', isEqualTo: widget.destinoBusqueda.toLowerCase().trim())
                    .where('fechaSalida', isGreaterThanOrEqualTo: limiteVigencia)
                    .orderBy('fechaSalida', descending: false)
                    .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint("ERROR FIRESTORE: ${snapshot.error}");
                  return Center(child: Text("Error al cargar datos. Verifica los índices."));
                }
                
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final String? miUid = FirebaseAuth.instance.currentUser?.uid;

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  
                  final int asientos = data['asientosDisponibles'] ?? 0;
                  final String driverId = data['driverId'] ?? '';
                  final String estado = data['estado'] ?? 'disponible'; 
                  
                  return driverId != miUid && 
                        asientos > 0 && 
                        estado == 'disponible'; 
                }).toList();

                if (docs.isEmpty) {
                  return _buildEmptyState(esBusquedaGeneral);
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 10),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final tripData = doc.data() as Map<String, dynamic>;
                    tripData['tripId'] = doc.id; 

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => TripDetailScreen(tripData: tripData)),
                        );
                      },
                      child: _buildTripCard(tripData),
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

  Widget _buildEmptyState(bool general) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer_off_outlined, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            general 
              ? "No hay viajes programados para hoy." 
              : "No hay viajes próximos hacia este destino.",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    String origen = _cap(trip['origen']);
    String destino = _cap(trip['destino']);
    int precio = trip['precio'] ?? 0;
    int asientos = trip['asientosDisponibles'] ?? 0;
    String driverId = trip['driverId'] ?? '';
    Timestamp? fechaSalida = trip['fechaSalida'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 15, right: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A4371), 
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A4371).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<Map<String, dynamic>?>(
                future: _getDriverData(driverId),
                builder: (context, snapshot) {
                  final userData = snapshot.data;
                  String nombreReal = userData?['nombre'] ?? "Conductor";
                  String? fotoUrl = userData?['photoUrl']; 

                  return Column(
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.white,
                        backgroundImage: (fotoUrl != null && fotoUrl.isNotEmpty) 
                            ? NetworkImage(fotoUrl) : null,
                        child: (fotoUrl == null || fotoUrl.isEmpty)
                          ? const Icon(Icons.person, color: Color(0xFF1A4371), size: 40) : null,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 80,
                        child: Text(nombreReal.split(' ')[0], 
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(TripMateFormat.currencyCLP(precio), 
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFF05A28))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              const Icon(Icons.event_seat, color: Color(0xFF2BB8D1), size: 14),
                              const SizedBox(width: 4),
                              Text("$asientos", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(_formatearFecha(fechaSalida), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Column(
                          children: [
                            const Icon(Icons.circle, color: Color(0xFF2BB8D1), size: 10),
                            Container(width: 1, height: 15, color: Colors.white24),
                            const Icon(Icons.location_on, color: Color(0xFFF05A28), size: 12),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(origen, style: const TextStyle(color: Colors.white, fontSize: 13)),
                              const SizedBox(height: 8),
                              Text(destino, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Divider(color: Colors.white.withOpacity(0.1), thickness: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("🚗 Ver detalles del vehículo", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
              const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 12),
            ],
          ),
        ],
      ),
    );
  }
}