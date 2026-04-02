// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:tripmate_app/core/utils/formatters.dart'; 
import 'package:tripmate_app/core/constants/locations.dart'; 

class PublishTripScreen extends StatefulWidget {
  const PublishTripScreen({super.key});

  @override
  State<PublishTripScreen> createState() => _PublishTripScreenState();
}

class _PublishTripScreenState extends State<PublishTripScreen> {
  final TextEditingController _origenController = TextEditingController();
  final TextEditingController _destinoController = TextEditingController();
  final TextEditingController _precioController = TextEditingController();
  final TextEditingController _asientosController = TextEditingController();
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    _verificarVehiculo();
  }

  Future<void> _verificarVehiculo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    
    if (doc.exists && doc.data()?['vehiculo'] == null) {
      _mostrarMensaje("Nota: Necesitas registrar un vehículo en tu perfil para poder publicar.");
    }
  }

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
          padding: const EdgeInsets.all(25),
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A4371))),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: ciudadesChile.length, 
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.location_on_outlined, color: Color(0xFF2BB8D1)),
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _publicarViaje() async {
    if (_origenController.text.isEmpty || _destinoController.text.isEmpty || 
        _precioController.text.isEmpty || _asientosController.text.isEmpty ||
        _selectedDate == null || _selectedTime == null) {
      _mostrarMensaje("Por favor, completa todos los campos");
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc.data();

      if (userData == null || userData['vehiculo'] == null) {
        _mostrarMensaje("Debes registrar un vehículo en tu perfil antes de publicar.");
        setState(() => _isPublishing = false);
        return;
      }

      final Map<String, dynamic> vehiculo = Map<String, dynamic>.from(userData['vehiculo']);

      final DateTime fullDateTime = DateTime(
        _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
        _selectedTime!.hour, _selectedTime!.minute,
      );

      final precioLimpio = _precioController.text.replaceAll(RegExp(r'[^0-9]'), '');

      final newTripRef = FirebaseFirestore.instance.collection('trips').doc();
      await newTripRef.set({
        'tripId': newTripRef.id,
        'driverId': uid,
        'origen': _origenController.text.trim().toLowerCase(),
        'destino': _destinoController.text.trim().toLowerCase(), 
        'precio': int.tryParse(precioLimpio) ?? 0, 
        'asientosDisponibles': int.tryParse(_asientosController.text) ?? 1,
        'fechaSalida': Timestamp.fromDate(fullDateTime), 
        'vehiculo': vehiculo,        
        'fechaPublicacion': FieldValue.serverTimestamp(),
        'estado': 'disponible',
      });
      
      if (!mounted) return;

      _mostrarMensaje("¡Viaje publicado con éxito!");

      _origenController.clear();
      _destinoController.clear();
      _precioController.clear();
      _asientosController.clear();
      
      setState(() {
        _selectedDate = null;
        _selectedTime = null;
        _isPublishing = false; 
      });

    } catch (e) {
      _mostrarMensaje("Error al publicar: $e");
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  void _mostrarMensaje(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: const Color(0xFF1A4371), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Publicar un Viaje", 
          style: TextStyle(color: Color(0xFF1A4371), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle("RUTA"),
            _buildInputCard(
              icon: Icons.location_on, 
              hint: "Punto de partida", 
              controller: _origenController,
              onTap: () => _mostrarSelectorCiudad(_origenController, "Partida desde..."),
            ),
            const SizedBox(height: 15),
            _buildInputCard(
              icon: Icons.flag, 
              hint: "Punto de destino", 
              controller: _destinoController,
              onTap: () => _mostrarSelectorCiudad(_destinoController, "¿A dónde vas?"),
            ),
            
            const SizedBox(height: 30),
            _sectionTitle("CUÁNDO"),
            Row(
              children: [
                Expanded(child: _buildPickerCard(
                  Icons.calendar_today, 
                  _selectedDate == null ? "Fecha" : DateFormat('dd/MM/yyyy').format(_selectedDate!), 
                  _selectDate
                )),
                const SizedBox(width: 15),
                Expanded(child: _buildPickerCard(
                  Icons.access_time, 
                  _selectedTime == null ? "Hora" : _selectedTime!.format(context), 
                  _selectTime
                )),
              ],
            ),

            const SizedBox(height: 30),
            _sectionTitle("DETALLES"),
            _buildInputCard(
              icon: Icons.attach_money, 
              hint: "Precio por persona", 
              controller: _precioController, 
              isNumber: true,
              formatters: [
                FilteringTextInputFormatter.digitsOnly, 
                TripMateFormat.inputCLP(), 
              ],
            ),
            const SizedBox(height: 15),
            _buildInputCard(
              icon: Icons.event_seat, 
              hint: "Asientos disponibles", 
              controller: _asientosController, 
              isNumber: true
            ),
            
            const SizedBox(height: 40),
            _buildPublishButton(),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 5),
      child: Text(title, style: const TextStyle(letterSpacing: 1.5, fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  Widget _buildInputCard({
    required IconData icon, 
    required String hint, 
    required TextEditingController controller, 
    bool isNumber = false, 
    List<TextInputFormatter>? formatters,
    VoidCallback? onTap, // Nuevo parámetro
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: controller,
        readOnly: onTap != null, 
        onTap: onTap,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: formatters, 
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: const Color(0xFF2BB8D1)),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildPickerCard(IconData icon, String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFF05A28), size: 20),
            const SizedBox(width: 10),
            Text(text, style: TextStyle(color: (text != "Fecha" && text != "Hora") ? Colors.black : Colors.grey, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildPublishButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF05A28),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 4,
          shadowColor: const Color(0xFFF05A28).withOpacity(0.4),
        ),
        onPressed: _isPublishing ? null : _publicarViaje,
        child: _isPublishing 
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text("PUBLICAR VIAJE", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      ),
    );
  }
}