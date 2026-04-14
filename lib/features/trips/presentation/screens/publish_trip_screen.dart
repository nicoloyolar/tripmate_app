// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:tripmate_app/core/utils/formatters.dart'; 
import 'package:tripmate_app/core/models/location_model.dart';
import 'package:tripmate_app/core/services/google_maps_service.dart';

class PublishTripScreen extends StatefulWidget {
  const PublishTripScreen({super.key});

  @override
  State<PublishTripScreen> createState() => _PublishTripScreenState();
}

class _PublishTripScreenState extends State<PublishTripScreen> {
  // Controladores
  final TextEditingController _origenController = TextEditingController();
  final TextEditingController _destinoController = TextEditingController();
  final TextEditingController _precioController = TextEditingController();
  final TextEditingController _asientosController = TextEditingController();

  LocationData? _origenData;
  LocationData? _destinoData;
  Map<String, dynamic>? _vehiculoData;
  int _capacidadMax = 4;
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isPublishing = false;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _cargarDatosVehiculo();
  }

  Future<void> _cargarDatosVehiculo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    
    if (doc.exists && doc.data()?['vehiculo'] != null) {
      setState(() {
        _vehiculoData = Map<String, dynamic>.from(doc.data()!['vehiculo']);
        _capacidadMax = _vehiculoData!['capacidad'] ?? 4;
      });
    }
  }

  double _calcularDistancia(LocationData start, LocationData end) {
    const double radioTierra = 6371; 
    double lat1 = start.lat * math.pi / 180;
    double lat2 = end.lat * math.pi / 180;
    double lon1 = start.lng * math.pi / 180;
    double lon2 = end.lng * math.pi / 180;
    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return radioTierra * c; 
  }

  void _actualizarPrecioSugerido() {
    if (_origenData == null || _destinoData == null) return;
    double kms = _calcularDistancia(_origenData!, _destinoData!);
    int tarifa = 160; 
    int precioSugerido = (kms * tarifa).round();
    
    precioSugerido = (precioSugerido / 500).round() * 500;

    setState(() {
      _precioController.text = precioSugerido.toString();
    });
    _mostrarMensaje("Precio sugerido para ${kms.toStringAsFixed(1)} km");
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

  void _mostrarSelectorCiudad(TextEditingController controller, String titulo) {
    List<dynamic> predicciones = []; 
    Timer? debounce;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder( 
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(25),
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A4371))),
              const SizedBox(height: 20),
              TextField(
                onChanged: (value) {
                  if (debounce?.isActive ?? false) debounce!.cancel();
                  debounce = Timer(const Duration(milliseconds: 500), () async {
                    if (value.length > 2) {
                      final lista = await GoogleMapsService.buscarEnPlaces(value);
                      setModalState(() => predicciones = lista);
                    }
                  });
                },
                decoration: InputDecoration(
                  hintText: "Escribe una dirección o ciudad...",
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF2BB8D1)),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: predicciones.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final place = predicciones[index];
                    return ListTile(
                      leading: const Icon(Icons.location_on_outlined, color: Color(0xFF2BB8D1)),
                      title: Text(place['description']),
                      onTap: () async {
                        final coords = await GoogleMapsService.obtenerCoordenadas(place['place_id']);
                        setState(() {
                          controller.text = place['description'];
                          if (titulo.contains("Partida")) {
                            _origenData = LocationData(address: place['description'], lat: coords['lat'], lng: coords['lng']);
                          } else {
                            _destinoData = LocationData(address: place['description'], lat: coords['lat'], lng: coords['lng']);
                          }
                        });
                        if (_origenData != null && _destinoData != null) _actualizarPrecioSugerido();
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _publicarViaje() async {
    setState(() => _isPublishing = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      if (_origenData == null || _destinoData == null || _selectedDate == null || _selectedTime == null) {
        _mostrarMensaje("Faltan datos críticos para publicar");
        setState(() => _isPublishing = false);
        return;
      }

      final DateTime fullDateTime = DateTime(
        _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
        _selectedTime!.hour, _selectedTime!.minute,
      );

      final precioLimpio = _precioController.text.replaceAll(RegExp(r'[^0-9]'), '');
      
      final newTripRef = FirebaseFirestore.instance.collection('trips').doc();
      
      await newTripRef.set({
        'tripId': newTripRef.id,
        'driverId': uid,
        
        'origen': _origenData?.address ?? _origenController.text, 
        'destino': _destinoData?.address ?? _destinoController.text,

        'origenFull': _origenData?.toMap(),
        'destinoFull': _destinoData?.toMap(),

        'precio': int.tryParse(precioLimpio) ?? 0, 
        'asientosDisponibles': int.tryParse(_asientosController.text) ?? 1,
        'fechaSalida': Timestamp.fromDate(fullDateTime), 
        'vehiculo': _vehiculoData,        
        'fechaPublicacion': FieldValue.serverTimestamp(),
        'estado': 'disponible',
      });
      
      if (!mounted) return;

      _mostrarMensaje("¡Viaje publicado con éxito!");

      setState(() {
        _isPublishing = false;
        _currentStep = 0;
        _origenController.clear();
        _destinoController.clear();
        _precioController.clear();
        _asientosController.clear();
        _origenData = null;
        _destinoData = null;
        _selectedDate = null;
        _selectedTime = null;
      });

      Navigator.of(context).pop();

    } catch (e) {
      debugPrint("Error al publicar: $e");
      _mostrarMensaje("Error al publicar: No se pudo conectar con el servidor.");
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
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFFF05A28)),
        ),
        child: Stepper(
          type: StepperType.horizontal,
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep == 0 && (_origenData == null || _destinoData == null)) {
              _mostrarMensaje("Por favor, selecciona origen y destino");
              return;
            }
            if (_currentStep == 1 && (_selectedDate == null || _selectedTime == null)) {
              _mostrarMensaje("Por favor, selecciona fecha y hora");
              return;
            }
            if (_currentStep < 2) {
              setState(() => _currentStep += 1);
            } else {
              _publicarViaje();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) setState(() => _currentStep -= 1);
          },
          controlsBuilder: (context, details) => Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isPublishing ? null : details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF05A28),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: _isPublishing 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_currentStep == 2 ? "PUBLICAR" : "CONTINUAR", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 15),
                  TextButton(onPressed: details.onStepCancel, child: const Text("ATRÁS", style: TextStyle(color: Colors.grey))),
                ]
              ],
            ),
          ),
          steps: [
            Step(
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              title: const Text("Ruta"),
              content: Column(
                children: [
                  _buildInputCard(icon: Icons.location_on, hint: "Punto de partida", controller: _origenController, onTap: () => _mostrarSelectorCiudad(_origenController, "Partida desde...")),
                  const SizedBox(height: 15),
                  _buildInputCard(icon: Icons.flag, hint: "Punto de destino", controller: _destinoController, onTap: () => _mostrarSelectorCiudad(_destinoController, "¿A dónde vas?")),
                ],
              ),
            ),
            Step(
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              title: const Text("Agenda"),
              content: Row(
                children: [
                  Expanded(child: _buildPickerCard(Icons.calendar_today, _selectedDate == null ? "Fecha" : DateFormat('dd/MM/yyyy').format(_selectedDate!), _selectDate)),
                  const SizedBox(width: 15),
                  Expanded(child: _buildPickerCard(Icons.access_time, _selectedTime == null ? "Hora" : _selectedTime!.format(context), _selectTime)),
                ],
              ),
            ),
            Step(
              isActive: _currentStep >= 2,
              title: const Text("Detalles"),
              content: Column(
                children: [
                  _buildInputCard(icon: Icons.attach_money, hint: "Precio por persona", controller: _precioController, isNumber: true, formatters: [FilteringTextInputFormatter.digitsOnly, TripMateFormat.inputCLP()]),
                  const SizedBox(height: 15),
                  _buildInputCard(
                    icon: Icons.event_seat, 
                    hint: "Asientos (Máx: $_capacidadMax)", 
                    controller: _asientosController, 
                    isNumber: true,
                    formatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      TextInputFormatter.withFunction((old, newValue) {
                        if (newValue.text.isEmpty) return newValue;
                        final val = int.tryParse(newValue.text);
                        return (val != null && val <= _capacidadMax) ? newValue : old;
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard({required IconData icon, required String hint, required TextEditingController controller, bool isNumber = false, List<TextInputFormatter>? formatters, VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[200]!)),
      child: TextField(
        controller: controller, readOnly: onTap != null, onTap: onTap,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: formatters,
        decoration: InputDecoration(border: InputBorder.none, prefixIcon: Icon(icon, color: const Color(0xFF2BB8D1)), hintText: hint, hintStyle: const TextStyle(color: Colors.grey, fontSize: 14)),
      ),
    );
  }

  Widget _buildPickerCard(IconData icon, String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[200]!)),
        child: Row(children: [Icon(icon, color: const Color(0xFFF05A28), size: 20), const SizedBox(width: 10), Text(text, style: TextStyle(color: (text != "Fecha" && text != "Hora") ? Colors.black : Colors.grey, fontSize: 14))]),
      ),
    );
  }
}