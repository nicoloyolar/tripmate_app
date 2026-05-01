// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:tripmate_app/core/utils/formatters.dart';
import 'package:tripmate_app/core/models/location_model.dart';
import 'package:tripmate_app/core/services/google_maps_service.dart';
import 'package:tripmate_app/core/utils/geo_utils.dart';
import 'package:tripmate_app/core/utils/pricing.dart';
import 'package:tripmate_app/features/locations/presentation/screens/location_picker_screen.dart';
import 'package:tripmate_app/features/trips/presentation/widgets/modern_time_picker_screen.dart';
import 'package:tripmate_app/features/trips/presentation/widgets/seat_wheel_picker.dart';

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
  bool _isLicenseVerified = false;
  int? _precioRecomendado;
  int? _precioPasajeroRecomendado;
  int? _peajesEstimados;
  double? _distanciaEstimadaKm;
  bool _peajesDesdeApi = false;

  List<Map<String, dynamic>> _misVehiculos = [];

  @override
  void initState() {
    super.initState();
    _cargarDatosVehiculo();
  }

  Future<void> _cargarDatosVehiculo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (doc.exists) {
      final userData = doc.data()!;

      setState(() {
        _isLicenseVerified =
            userData['isLicenseVerified'] == true ||
            userData['isVerified'] == true;
        if (userData['vehiculos'] != null) {
          _misVehiculos = List<Map<String, dynamic>>.from(
            userData['vehiculos'],
          );
          if (_misVehiculos.isNotEmpty) {
            _vehiculoData = _misVehiculos.firstWhere(
              (v) => v['verificado'] == true,
              orElse: () => _misVehiculos[0],
            );
            _capacidadMax = _vehiculoData!['capacidad'] ?? 4;
          }
        }
      });
    }
  }

  bool get _vehiculoVerificado => _vehiculoData?['verificado'] == true;

  bool get _documentacionPendiente =>
      !_isLicenseVerified || !_vehiculoVerificado;

  int get _precioConductorActual {
    final precioLimpio = _precioController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    return int.tryParse(precioLimpio) ?? 0;
  }

  int? get _precioMinimoPermitido => _precioRecomendado == null
      ? null
      : TripMatePricing.minDriverPrice(_precioRecomendado!);

  int? get _precioMaximoPermitido => _precioRecomendado == null
      ? null
      : TripMatePricing.maxDriverPrice(_precioRecomendado!);

  bool get _precioFueraDeRango {
    final precioActual = _precioConductorActual;
    final minimo = _precioMinimoPermitido;
    final maximo = _precioMaximoPermitido;
    if (precioActual <= 0 || minimo == null || maximo == null) return false;
    return precioActual < minimo || precioActual > maximo;
  }

  Future<void> _actualizarPrecioSugerido() async {
    if (_origenData == null || _destinoData == null) return;

    final routeData = await GoogleMapsService.obtenerRutaConPeajes(
      originLat: _origenData!.lat,
      originLng: _origenData!.lng,
      destinationLat: _destinoData!.lat,
      destinationLng: _destinoData!.lng,
    );
    final routeDistanceFallback = routeData?.distanceKm == null
        ? await GoogleMapsService.obtenerDistanciaRutaKm(
            originLat: _origenData!.lat,
            originLng: _origenData!.lng,
            destinationLat: _destinoData!.lat,
            destinationLng: _destinoData!.lng,
          )
        : null;

    final kms =
        routeData?.distanceKm ??
        routeDistanceFallback ??
        GeoUtils.calcularDistancia(_origenData!, _destinoData!);
    final peajesEstimados =
        routeData?.tollsClp ?? TripMatePricing.estimateTolls(kms);
    final peajesDesdeApi = routeData?.tollsClp != null;
    final precioSugerido = TripMatePricing.recommendedDriverPrice(
      kms,
      tolls: peajesEstimados,
    );
    final precioPasajeroSugerido = TripMatePricing.passengerPrice(
      precioSugerido,
    );

    if (!mounted) return;
    setState(() {
      _distanciaEstimadaKm = kms;
      _peajesEstimados = peajesEstimados;
      _peajesDesdeApi = peajesDesdeApi;
      _precioRecomendado = precioSugerido;
      _precioPasajeroRecomendado = precioPasajeroSugerido;
      _precioController.text = precioSugerido.toString();
    });
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
    final TimeOfDay? picked = await Navigator.push<TimeOfDay>(
      context,
      MaterialPageRoute(
        builder: (context) => ModernTimePickerScreen(
          initialTime: _selectedTime ?? TimeOfDay.now(),
        ),
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _selectSeats() async {
    final current = int.tryParse(_asientosController.text) ?? 1;
    final selected = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (context) => SeatWheelPicker(
          maxSeats: _capacidadMax,
          initialSeats: current,
          title: "Asientos disponibles",
        ),
      ),
    );

    if (selected != null) {
      setState(() => _asientosController.text = selected.toString());
    }
  }

  Future<void> _abrirSelectorMapa(
    TextEditingController controller,
    bool esOrigen,
  ) async {
    final seleccion = await Navigator.push<LocationData>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          title: esOrigen
              ? "Punto exacto de partida"
              : "Punto exacto de destino",
          initialLocation: esOrigen ? _origenData : _destinoData,
        ),
      ),
    );

    if (seleccion == null) return;

    setState(() {
      controller.text = seleccion.address;
      if (esOrigen) {
        _origenData = seleccion;
      } else {
        _destinoData = seleccion;
      }
    });

    if (_origenData != null && _destinoData != null) {
      await _actualizarPrecioSugerido();
    }
  }

  Future<void> _publicarViaje() async {
    setState(() => _isPublishing = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _mostrarMensaje("Debes iniciar sesión para publicar");
        setState(() => _isPublishing = false);
        return;
      }

      if (_origenData == null ||
          _destinoData == null ||
          _selectedDate == null ||
          _selectedTime == null) {
        _mostrarMensaje("Faltan datos críticos para publicar");
        setState(() => _isPublishing = false);
        return;
      }

      final DateTime fullDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final precioConductor = _precioConductorActual;
      final asientos = int.tryParse(_asientosController.text) ?? 0;

      if (precioConductor <= 0) {
        _mostrarMensaje("Ingresa un precio válido para el conductor");
        setState(() => _isPublishing = false);
        return;
      }

      if (_precioRecomendado != null) {
        final min = TripMatePricing.minDriverPrice(_precioRecomendado!);
        final max = TripMatePricing.maxDriverPrice(_precioRecomendado!);
        if (precioConductor < min || precioConductor > max) {
          setState(() => _isPublishing = false);
          return;
        }
      }

      if (asientos <= 0 || asientos > _capacidadMax) {
        _mostrarMensaje(
          "Selecciona entre 1 y $_capacidadMax asientos disponibles",
        );
        setState(() => _isPublishing = false);
        return;
      }

      final precioPasajero = TripMatePricing.passengerPrice(precioConductor);

      final newTripRef = FirebaseFirestore.instance.collection('trips').doc();
      final batch = FirebaseFirestore.instance.batch();

      batch.set(newTripRef, {
        'tripId': newTripRef.id,
        'driverId': uid,
        'origen':
            _origenData?.toMap() ??
            {'address': _origenController.text, 'lat': 0, 'lng': 0},
        'destino':
            _destinoData?.toMap() ??
            {'address': _destinoController.text, 'lat': 0, 'lng': 0},
        'precio': precioPasajero,
        'precioConductor': precioConductor,
        'comisionTripMate': TripMatePricing.commission(precioConductor),
        'ivaComision': TripMatePricing.commissionIva(precioConductor),
        'calculoPrecio': {
          'distanciaKm': _distanciaEstimadaKm,
          'peajes': _peajesEstimados,
          'peajesDesdeGoogleRoutes': _peajesDesdeApi,
          'precioRecomendadoConductor': _precioRecomendado,
          'precioRecomendadoPasajero': _precioPasajeroRecomendado,
          'formula':
              '(bencina estimada + peajes) / 5 cupos; pasajero paga +10%',
        },
        'asientosDisponibles': asientos,
        'fechaSalida': Timestamp.fromDate(fullDateTime),
        'vehiculo': _vehiculoData,
        'fechaPublicacion': FieldValue.serverTimestamp(),
        'estado': 'disponible',
        'adminReviewStatus': 'visible',
      });

      final adminEventRef = FirebaseFirestore.instance
          .collection('admin_events')
          .doc();
      batch.set(adminEventRef, {
        'type': 'trip_published',
        'tripId': newTripRef.id,
        'driverId': uid,
        'status': 'pending_panel_sync',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;

      setState(() => _isPublishing = false);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
          content: const Text(
            "¡Tu viaje se ha publicado con éxito!",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _currentStep = 0;
                  _origenController.clear();
                  _destinoController.clear();
                  _precioController.clear();
                  _asientosController.clear();
                  _origenData = null;
                  _destinoData = null;
                  _precioRecomendado = null;
                  _precioPasajeroRecomendado = null;
                  _peajesEstimados = null;
                  _distanciaEstimadaKm = null;
                  _peajesDesdeApi = false;
                  _selectedDate = null;
                  _selectedTime = null;
                });
              },
              child: const Text(
                "ESTUPENDO",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint("Error al publicar: $e");
      _mostrarMensaje("Error al conectar con el servidor.");
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  void _mostrarMensaje(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: const Color(0xFF1A4371),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Publicar un Viaje",
          style: TextStyle(
            color: Color(0xFF1A4371),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFFF05A28)),
        ),
        child: Stepper(
          type: StepperType.horizontal,
          currentStep: _currentStep,
          onStepContinue: () async {
            if (_currentStep == 0 &&
                (_origenData == null || _destinoData == null)) {
              _mostrarMensaje("Por favor, selecciona origen y destino");
              return;
            }
            if (_currentStep == 1 &&
                (_selectedDate == null || _selectedTime == null)) {
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
          controlsBuilder: (context, details) {
            final bloqueaPublicacion = _currentStep == 2 && _precioFueraDeRango;

            return Padding(
              padding: const EdgeInsets.only(top: 30),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_isPublishing || bloqueaPublicacion)
                          ? null
                          : details.onStepContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: bloqueaPublicacion
                            ? Colors.grey[400]
                            : const Color(0xFFF05A28),
                        disabledBackgroundColor: Colors.grey[400],
                        disabledForegroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: _isPublishing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _currentStep == 2 ? "PUBLICAR" : "CONTINUAR",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  if (_currentStep > 0) ...[
                    const SizedBox(width: 15),
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text(
                        "ATRÁS",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
          steps: [
            Step(
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              title: const Text("Ruta"),
              content: Column(
                children: [
                  _buildInputCard(
                    icon: Icons.location_on,
                    hint: "Punto de partida",
                    controller: _origenController,
                    onTap: () => _abrirSelectorMapa(_origenController, true),
                  ),
                  const SizedBox(height: 15),
                  _buildInputCard(
                    icon: Icons.flag,
                    hint: "Punto de destino",
                    controller: _destinoController,
                    onTap: () => _abrirSelectorMapa(_destinoController, false),
                  ),
                ],
              ),
            ),
            Step(
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              title: const Text("Agenda"),
              content: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildPickerCard(
                          Icons.calendar_today,
                          _selectedDate == null
                              ? "Fecha"
                              : DateFormat('dd/MM/yyyy').format(_selectedDate!),
                          _selectDate,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildPickerCard(
                          Icons.access_time,
                          _selectedTime == null
                              ? "Hora"
                              : _selectedTime!.format(context),
                          _selectTime,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Step(
              isActive: _currentStep >= 2,
              title: const Text("Detalles"),
              content: Column(
                children: [
                  if (_misVehiculos.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: DropdownButtonFormField<Map<String, dynamic>>(
                        value: _vehiculoData,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: "Vehículo para este viaje",
                          prefixIcon: const Icon(
                            Icons.directions_car,
                            color: Color(0xFF2BB8D1),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: _misVehiculos.map((v) {
                          return DropdownMenuItem(
                            value: v,
                            child: Text(
                              "${v['marca']} ${v['modelo']} (${v['patente']})",
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        }).toList(),
                        onChanged: (nuevo) {
                          setState(() {
                            _vehiculoData = nuevo;
                            _capacidadMax = nuevo?['capacidad'] ?? 4;
                            _asientosController.clear();
                          });
                        },
                      ),
                    ),

                  if (_documentacionPendiente)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: const Text(
                        "Modo pruebas: puedes publicar aunque documentos o vehículo sigan pendientes de validación.",
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),

                  _buildInputCard(
                    icon: Icons.attach_money,
                    hint: "Precio que recibes por persona",
                    controller: _precioController,
                    isNumber: true,
                    formatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      TripMateFormat.inputCLP(),
                    ],
                  ),

                  if (_precioController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Pasajero paga aprox. ${TripMateFormat.currencyCLP(TripMatePricing.passengerPrice(int.tryParse(_precioController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0))} con comisión TripMate.",
                          style: const TextStyle(
                            color: Color(0xFF1A4371),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  _buildPriceRangeWarning(),

                  _buildRecommendedPriceCard(),

                  const SizedBox(height: 15),

                  _buildInputCard(
                    icon: Icons.event_seat,
                    hint: "Asientos (Máx: $_capacidadMax)",
                    controller: _asientosController,
                    isNumber: true,
                    onTap: _selectSeats,
                    formatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      TextInputFormatter.withFunction((old, newValue) {
                        if (newValue.text.isEmpty) return newValue;
                        final val = int.tryParse(newValue.text);
                        return (val != null && val <= _capacidadMax)
                            ? newValue
                            : old;
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

  Widget _buildInputCard({
    required IconData icon,
    required String hint,
    required TextEditingController controller,
    bool isNumber = false,
    List<TextInputFormatter>? formatters,
    VoidCallback? onTap,
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
        onChanged: (_) => setState(() {}),
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

  Widget _buildRecommendedPriceCard() {
    if (_origenData == null ||
        _destinoData == null ||
        _precioRecomendado == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8FA),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF2BB8D1).withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Color(0xFF1A4371), size: 20),
              SizedBox(width: 8),
              Text(
                "Precio recomendado por cupo",
                style: TextStyle(
                  color: Color(0xFF1A4371),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _priceInfoRow(
            "Recibes como conductor",
            TripMateFormat.currencyCLP(_precioRecomendado),
            isPrimary: true,
          ),
          _priceInfoRow(
            "Pasajero paga con comisión",
            TripMateFormat.currencyCLP(_precioPasajeroRecomendado ?? 0),
          ),
          if (_distanciaEstimadaKm != null)
            _priceInfoRow(
              "Distancia estimada",
              "${_distanciaEstimadaKm!.toStringAsFixed(1)} km",
            ),
          if (_peajesEstimados != null)
            _priceInfoRow(
              _peajesDesdeApi ? "Peajes de Google" : "Peajes estimados",
              TripMateFormat.currencyCLP(_peajesEstimados),
            ),
          const SizedBox(height: 6),
          Text(
            _peajesDesdeApi
                ? "Se calcula con distancia y peajes de Google Routes, dividiendo bencina + peajes entre 5 cupos."
                : "Google no entregó peajes para esta ruta; se usa una estimación y se divide bencina + peajes entre 5 cupos.",
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRangeWarning() {
    final minimo = _precioMinimoPermitido;
    final maximo = _precioMaximoPermitido;
    if (!_precioFueraDeRango || minimo == null || maximo == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10, bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E8),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFF05A28).withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFF05A28),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "El precio debe estar entre ${TripMateFormat.currencyCLP(minimo)} y ${TripMateFormat.currencyCLP(maximo)} para mantenerse dentro del rango recomendado.",
              style: const TextStyle(
                color: Color(0xFF9A4A00),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceInfoRow(String label, String value, {bool isPrimary = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: isPrimary ? const Color(0xFF1A4371) : Colors.black87,
                fontSize: 12,
                fontWeight: isPrimary ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              color: isPrimary ? const Color(0xFFF05A28) : Colors.black87,
              fontSize: isPrimary ? 14 : 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
            Text(
              text,
              style: TextStyle(
                color: (text != "Fecha" && text != "Hora")
                    ? Colors.black
                    : Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
