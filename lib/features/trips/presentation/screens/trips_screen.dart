// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:tripmate_app/core/utils/formatters.dart'; 

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  String _capitalizar(String texto) {
    if (texto.isEmpty) return texto;
    return texto[0].toUpperCase() + texto.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB), 
      appBar: AppBar(
        title: const Text("Mis Viajes Publicados", 
          style: TextStyle(color: Color(0xFF1A4371), fontWeight: FontWeight.bold)),
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
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car_filled_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text("Aún no has publicado viajes", 
                    style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }

          final trips = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              var trip = trips[index].data() as Map<String, dynamic>;
              
              String fechaStr = "Sin fecha";
              if (trip['fechaSalida'] != null) {
                fechaStr = DateFormat('dd MMM, HH:mm', 'es').format((trip['fechaSalida'] as Timestamp).toDate());
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
                    )
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2BB8D1).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.directions_car, color: Color(0xFF2BB8D1)),
                  ),
                  title: Text(
                    "${_capitalizar(trip['origen'])} → ${_capitalizar(trip['destino'])}", 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A4371), fontSize: 16)
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Text(fechaStr, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Text(TripMateFormat.currencyCLP(trip['precio']), 
                            style: const TextStyle(color: Color(0xFFF05A28), fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(width: 10),
                          const Icon(Icons.person, size: 14, color: Colors.grey),
                          Text(" ${trip['asientosDisponibles']} cupos", 
                            style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () {
                    
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}