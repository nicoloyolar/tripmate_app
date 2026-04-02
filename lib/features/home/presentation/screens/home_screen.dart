// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:tripmate_app/features/trips/presentation/screens/trip_results_screen.dart';
import 'package:tripmate_app/core/constants/locations.dart'; // Ajusta la ruta según tu carpeta

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _origenController = TextEditingController();
  final TextEditingController _destinoController = TextEditingController();
  DateTime _fechaSeleccionada = DateTime.now();

  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  void _mostrarSelectorCiudad(TextEditingController controller, String titulo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A4371))),
              const SizedBox(height: 15),
              Expanded(
                child: ListView.separated(
                  itemCount: ciudadesChile.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.location_city_outlined, color: Color(0xFF2BB8D1)),
                      title: Text(ciudadesChile[index], style: const TextStyle(fontSize: 16)),
                      onTap: () {
                        setState(() {
                          controller.text = ciudadesChile[index];
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime.now(), 
      lastDate: DateTime.now().add(const Duration(days: 365)), 
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1A4371), 
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _fechaSeleccionada) {
      setState(() {
        _fechaSeleccionada = picked;
      });
    }
  }

  @override
  void dispose() {
    _origenController.dispose();
    _destinoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String fechaFormateada = DateFormat('dd MMM', 'es').format(_fechaSeleccionada);

    return Material(
      color: Colors.white,
      child: Stack(
        children: [
          // Fondo azul superior
          Container(
            height: MediaQuery.of(context).size.height * 0.3,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF1A4371),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').doc(_uid).snapshots(),
                      builder: (context, snapshot) {
                        String saludo = "¿Cuál es tu próximo viaje?";
                        if (snapshot.hasData && snapshot.data!.exists) {
                          var data = snapshot.data!.data() as Map<String, dynamic>;
                          String nombreCompleto = data['nombre'] ?? "";
                          String primerNombre = nombreCompleto.split(' ').first;
                          saludo = "Hola, $primerNombre!\n¿A dónde vamos?";
                        }
                        return Text(
                          saludo,
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tarjeta de búsqueda
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).size.height * 0.18,
              left: 20,
              right: 20,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Campo Origen con Selector
                  _buildSearchInput(
                    icon: Icons.location_on_outlined, 
                    hintText: "Origen", 
                    controller: _origenController,
                    onTap: () => _mostrarSelectorCiudad(_origenController, "Selecciona Punto de Partida")
                  ),
                  const Divider(height: 30),
                  
                  // Campo Destino con Selector
                  _buildSearchInput(
                    icon: Icons.location_on, 
                    hintText: "Destino", 
                    controller: _destinoController,
                    onTap: () => _mostrarSelectorCiudad(_destinoController, "Selecciona tu Destino")
                  ),
                  const Divider(height: 30),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildSearchInput(
                          icon: Icons.calendar_today, 
                          hintText: fechaFormateada,
                          onTap: () => _seleccionarFecha(context)
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _buildSearchInput(icon: Icons.person_outline, hintText: "1")),
                    ],
                  ),
                  const SizedBox(height: 25),
                  
                  // Botón Buscar
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF05A28),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context, 
                          MaterialPageRoute(
                            builder: (context) => TripResultsScreen(
                              destinoBusqueda: _destinoController.text.toLowerCase().trim()
                            )
                          )
                        );
                      },
                      child: const Text("Buscar", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Widget mejorado para detectar toques ---
  Widget _buildSearchInput({
    required IconData icon, 
    required String hintText, 
    TextEditingController? controller,
    VoidCallback? onTap
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2BB8D1), size: 22),
          const SizedBox(width: 15),
          Expanded(
            child: AbsorbPointer(
              absorbing: onTap != null, // Bloquea el teclado si hay una función onTap
              child: TextField(
                controller: controller,
                readOnly: onTap != null, // Lo hace solo lectura para evitar teclado
                decoration: InputDecoration(
                  hintText: hintText, 
                  border: InputBorder.none, 
                  contentPadding: EdgeInsets.zero,
                  hintStyle: const TextStyle(color: Colors.black87)
                ),
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }
}