// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:tripmate_app/core/services/payment_service.dart';
import 'package:tripmate_app/core/utils/formatters.dart';
import 'package:tripmate_app/core/utils/pricing.dart';
import 'package:tripmate_app/core/utils/validators.dart';
import 'package:tripmate_app/features/chat/presentation/screens/chat_screen.dart';
import 'package:tripmate_app/features/profile/presentation/screens/payment_methods_screen.dart';
import 'package:tripmate_app/features/profile/presentation/screens/public_profile_screen.dart';

class TripDetailScreen extends StatefulWidget {
  final Map<String, dynamic> tripData;

  const TripDetailScreen({super.key, required this.tripData});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  int _cantidadSeleccionada = 1;
  final TextEditingController _seatController = TextEditingController(
    text: '1',
  );
  final TextEditingController _comentarioController = TextEditingController();
  final List<TextEditingController> _companionNameControllers = [];
  final List<TextEditingController> _companionRutControllers = [];

  @override
  void dispose() {
    _seatController.dispose();
    _comentarioController.dispose();
    for (final controller in _companionNameControllers) {
      controller.dispose();
    }
    for (final controller in _companionRutControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String _cap(String? s) => (s == null || s.isEmpty)
      ? ''
      : s[0].toUpperCase() + s.substring(1).toLowerCase();

  Future<Map<String, dynamic>?> _getDriverData(String uid) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
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

  _DriverRating _ratingFromUserData(Map<String, dynamic>? userData) {
    if (userData == null) return const _DriverRating.empty();

    final rawRating =
        userData['ratingAverage'] ??
        userData['averageRating'] ??
        userData['rating'] ??
        userData['calificacionPromedio'] ??
        userData['promedioCalificacion'];
    final rawCount =
        userData['ratingCount'] ??
        userData['ratingsCount'] ??
        userData['reviewCount'] ??
        userData['calificacionesCount'] ??
        userData['totalReviews'];

    final rating = rawRating is num
        ? rawRating.toDouble().clamp(0.0, 5.0).toDouble()
        : double.tryParse(
            rawRating?.toString() ?? '',
          )?.clamp(0.0, 5.0).toDouble();
    final count = rawCount is num
        ? rawCount.toInt()
        : int.tryParse(rawCount?.toString() ?? '');

    if (rating == null || rating <= 0 || count == 0) {
      return const _DriverRating.empty();
    }

    return _DriverRating(rating: rating, count: count);
  }

  void _syncCompanionControllers(int seats) {
    final companionsCount = (seats - 1).clamp(0, seats).toInt();

    while (_companionNameControllers.length < companionsCount) {
      _companionNameControllers.add(TextEditingController());
      _companionRutControllers.add(TextEditingController());
    }

    while (_companionNameControllers.length > companionsCount) {
      _companionNameControllers.removeLast().dispose();
      _companionRutControllers.removeLast().dispose();
    }
  }

  List<Map<String, dynamic>> _additionalPassengersData() {
    return List.generate(_companionNameControllers.length, (index) {
      return {
        'nombre': _companionNameControllers[index].text.trim(),
        'rut': _companionRutControllers[index].text.trim(),
        'hasTripMateAccount': false,
      };
    });
  }

  String? _companionValidationError() {
    for (var i = 0; i < _companionNameControllers.length; i++) {
      final name = _companionNameControllers[i].text.trim();
      final rut = _companionRutControllers[i].text.trim();

      if (name.isEmpty || rut.isEmpty) {
        return "Completa nombre y RUT del acompañante ${i + 1}";
      }

      if (!TripMateValidators.validarRutChileno(rut)) {
        return "El RUT del acompañante ${i + 1} no es válido";
      }
    }

    return null;
  }

  Future<void> _processBooking(
    BuildContext context,
    int cantidad,
    String comentario,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _mostrarMensaje(
        context,
        "Debes iniciar sesión para reservar",
        isError: true,
      );
      return;
    }

    if (user.uid == widget.tripData['driverId']) {
      _mostrarMensaje(
        context,
        "No puedes reservar tu propio viaje",
        isError: true,
      );
      return;
    }

    final String? tripId = widget.tripData['id'] ?? widget.tripData['tripId'];
    if (tripId == null) {
      _mostrarMensaje(
        context,
        "Error: ID del viaje no encontrado",
        isError: true,
      );
      return;
    }

    final DocumentReference tripRef = FirebaseFirestore.instance
        .collection('trips')
        .doc(tripId);

    try {
      final companionError = _companionValidationError();
      if (companionError != null) {
        _mostrarMensaje(context, companionError, isError: true);
        return;
      }

      final additionalPassengers = _additionalPassengersData();
      final paymentMethod = await PaymentService.defaultPaymentMethod();
      if (paymentMethod == null) {
        final added = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (context) => const PaymentMethodsScreen()),
        );
        if (added != true) {
          _mostrarMensaje(
            context,
            "Agrega un método de pago para reservar tu cupo.",
            isError: true,
          );
          return;
        }
      }

      final selectedPaymentMethod =
          paymentMethod ?? await PaymentService.defaultPaymentMethod();
      if (selectedPaymentMethod == null) return;

      String? newBookingId;
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot tripSnapshot = await transaction.get(tripRef);

        if (!tripSnapshot.exists) throw "El viaje ya no está disponible.";

        final tripData = tripSnapshot.data() as Map<String, dynamic>;
        int asientosDisponibles = tripData['asientosDisponibles'] ?? 0;

        if (asientosDisponibles >= cantidad) {
          DocumentReference bookingRef = FirebaseFirestore.instance
              .collection('bookings')
              .doc();
          newBookingId = bookingRef.id;
          final precioPasajero = widget.tripData['precio'] ?? 0;
          final precioConductor =
              widget.tripData['precioConductor'] ?? precioPasajero;
          final comision = widget.tripData['comisionTripMate'] ?? 0;
          final iva = widget.tripData['ivaComision'] ?? 0;

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
            'pasajerosAdicionales': additionalPassengers,
            'comentario': comentario.trim(),
            'status': 'pendiente',
            'paymentStatus': 'autorizado_pendiente_aceptacion',
            'paymentMethodId': selectedPaymentMethod['id'],
            'paymentMethodLabel': selectedPaymentMethod['label'],
            'precioConductor': precioConductor,
            'comisionTripMate': comision,
            'ivaComision': iva,
            'totalPasajero': precioPasajero * cantidad,
            'totalConductor': precioConductor * cantidad,
            'totalComisionTripMate': comision * cantidad,
            'totalIvaComision': iva * cantidad,
            'deleted': false,
          });
        } else {
          throw "Solo quedan $asientosDisponibles asientos disponibles.";
        }
      });

      if (newBookingId != null) {
        final precioPasajero = widget.tripData['precio'] ?? 0;
        final precioConductor =
            widget.tripData['precioConductor'] ?? precioPasajero;
        final comision = widget.tripData['comisionTripMate'] ?? 0;
        final iva = widget.tripData['ivaComision'] ?? 0;
        final paymentIntent = await PaymentService.createPaymentIntent(
          bookingId: newBookingId!,
          tripId: tripId,
          passengerId: user.uid,
          driverId: widget.tripData['driverId'],
          amount: precioPasajero * cantidad,
          driverAmount: precioConductor * cantidad,
          commission: comision * cantidad,
          iva: iva * cantidad,
          paymentMethod: selectedPaymentMethod,
        );

        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(newBookingId)
            .update({'paymentIntentId': paymentIntent.id});
      }

      if (mounted) {
        _mostrarMensaje(
          context,
          "Solicitud enviada. Quedará confirmada cuando el conductor la acepte.",
          isError: false,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _mostrarMensaje(context, e.toString(), isError: true);
    }
  }

  Future<void> _aceptarReserva(String bookingId) async {
    final String? tripId = widget.tripData['id'] ?? widget.tripData['tripId'];
    if (tripId == null) return;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final tripRef = FirebaseFirestore.instance
            .collection('trips')
            .doc(tripId);
        final bookingRef = FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId);
        final tripSnap = await transaction.get(tripRef);
        final bookingSnap = await transaction.get(bookingRef);

        if (!tripSnap.exists || !bookingSnap.exists) {
          throw "La solicitud ya no está disponible.";
        }

        final trip = tripSnap.data() as Map<String, dynamic>;
        final booking = bookingSnap.data() as Map<String, dynamic>;
        final status = (booking['status'] ?? '').toString().toLowerCase();
        final cantidad = booking['cantidadAsientos'] ?? 1;
        final asientos = trip['asientosDisponibles'] ?? 0;

        if (status != 'pendiente') {
          throw "Esta solicitud ya fue procesada.";
        }
        if (asientos < cantidad) {
          throw "No quedan suficientes asientos disponibles.";
        }

        transaction.update(tripRef, {
          'asientosDisponibles': asientos - cantidad,
        });
        transaction.update(bookingRef, {
          'status': 'confirmado',
          'paymentStatus': 'capturado',
          'acceptedAt': FieldValue.serverTimestamp(),
        });

        final paymentIntentId = booking['paymentIntentId'];
        if (paymentIntentId != null) {
          final paymentRef = FirebaseFirestore.instance
              .collection('payment_intents')
              .doc(paymentIntentId);
          transaction.update(paymentRef, {
            'status': 'captured',
            'capturedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      if (mounted) {
        _mostrarMensaje(
          context,
          "Pasajero aceptado. La reserva quedó confirmada.",
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) _mostrarMensaje(context, e.toString(), isError: true);
    }
  }

  Future<void> _rechazarReserva(String bookingId) async {
    try {
      final bookingRef = FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId);
      final booking = await bookingRef.get();
      final data = booking.data();

      final batch = FirebaseFirestore.instance.batch();
      batch.update(bookingRef, {
        'status': 'rechazado',
        'paymentStatus': 'liberado',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      final paymentIntentId = data?['paymentIntentId'];
      if (paymentIntentId != null) {
        batch.update(
          FirebaseFirestore.instance
              .collection('payment_intents')
              .doc(paymentIntentId),
          {'status': 'released', 'releasedAt': FieldValue.serverTimestamp()},
        );
      }

      await batch.commit();
      if (mounted) {
        _mostrarMensaje(context, "Solicitud rechazada.", isError: false);
      }
    } catch (e) {
      if (mounted) {
        _mostrarMensaje(context, "Error al rechazar: $e", isError: true);
      }
    }
  }

  Future<void> _cancelarViaje() async {
    final String? tripId = widget.tripData['id'] ?? widget.tripData['tripId'];
    if (tripId == null) return;

    try {
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('tripId', isEqualTo: tripId)
          .get();
      final cancellableBookings = bookingsSnapshot.docs.where((doc) {
        final status = (doc.data()['status'] ?? '').toString().toLowerCase();
        return status == 'pendiente' || status == 'confirmado';
      }).toList();

      final batch = FirebaseFirestore.instance.batch();
      final tripRef = FirebaseFirestore.instance.collection('trips').doc(tripId);

      batch.update(tripRef, {
        'estado': 'cancelado',
        'cancelledBy': 'driver',
        'cancelledAt': FieldValue.serverTimestamp(),
        'adminReviewStatus': 'cancelled_pending_review',
      });

      for (final bookingDoc in cancellableBookings) {
        final booking = bookingDoc.data();
        batch.update(bookingDoc.reference, {
          'status': 'cancelado',
          'paymentStatus': 'liberado',
          'cancelledBy': 'driver',
          'cancelledAt': FieldValue.serverTimestamp(),
        });

        final paymentIntentId = booking['paymentIntentId'];
        if (paymentIntentId != null) {
          batch.set(
            FirebaseFirestore.instance
                .collection('payment_intents')
                .doc(paymentIntentId.toString()),
            {
              'status': 'released',
              'releasedAt': FieldValue.serverTimestamp(),
              'releasedReason': 'driver_trip_cancellation',
            },
            SetOptions(merge: true),
          );
        }
      }

      batch.set(FirebaseFirestore.instance.collection('admin_events').doc(), {
        'type': 'trip_cancelled_by_driver',
        'tripId': tripId,
        'driverId': widget.tripData['driverId'],
        'affectedBookings': cancellableBookings.length,
        'status': 'pending_penalty_review',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;
      _mostrarMensaje(context, "Viaje cancelado correctamente.", isError: false);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        _mostrarMensaje(context, "Error al cancelar el viaje: $e", isError: true);
      }
    }
  }

  Future<void> _confirmarCancelarViaje() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Cancelar viaje",
          style: TextStyle(
            color: Color(0xFF1A4371),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          "Si cancelas este viaje, dejará de estar disponible para reservas. "
          "Las solicitudes pendientes y reservas confirmadas serán canceladas, "
          "los pagos autorizados serán liberados y TripMate podrá revisar multas, "
          "bloqueos temporales o impacto en tu reputación según la anticipación "
          "y pasajeros afectados.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("VOLVER"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text("SÍ, CANCELAR"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _cancelarViaje();
    }
  }

  void _abrirChatPasajero(String bookingId, Map<String, dynamic> booking) {
    final tripId = (widget.tripData['tripId'] ?? widget.tripData['id'] ?? '')
        .toString();
    final driverId = (widget.tripData['driverId'] ?? booking['driverId'] ?? '')
        .toString();
    final passengerId = (booking['passengerId'] ?? '').toString();

    if (tripId.isEmpty || driverId.isEmpty || passengerId.isEmpty) {
      _mostrarMensaje(
        context,
        "No se pudo abrir el chat de esta solicitud.",
        isError: true,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          bookingId: bookingId,
          tripId: tripId,
          driverId: driverId,
          passengerId: passengerId,
          title: "Chat con pasajero",
        ),
      ),
    );
  }

  int _maxReservableSeats(int availableSeats) {
    if (availableSeats <= 0) return 0;
    return availableSeats > 4 ? 4 : availableSeats;
  }

  void _setSelectedSeats(int seats, int maxSeats) {
    if (maxSeats <= 0) return;

    final nextSeats = seats.clamp(1, maxSeats).toInt();
    setState(() {
      _cantidadSeleccionada = nextSeats;
      _seatController.text = nextSeats.toString();
      _seatController.selection = TextSelection.collapsed(
        offset: _seatController.text.length,
      );
      _syncCompanionControllers(nextSeats);
    });
  }

  void _onSeatsInputChanged(String value, int maxSeats) {
    if (value.isEmpty || maxSeats <= 0) return;

    final parsed = int.tryParse(value);
    if (parsed == null) return;

    if (parsed < 1 || parsed > maxSeats) {
      _setSelectedSeats(parsed, maxSeats);
      return;
    }

    setState(() {
      _cantidadSeleccionada = parsed;
      _syncCompanionControllers(parsed);
    });
  }

  void _openPublicProfile(String userId) {
    if (userId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PublicProfileScreen(userId: userId),
      ),
    );
  }

  void _mostrarMensaje(
    BuildContext context,
    String msj, {
    bool isError = false,
  }) {
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
    final String estadoViaje = (widget.tripData['estado'] ?? 'disponible')
        .toString()
        .toLowerCase();
    final bool viajeCancelado = estadoViaje == 'cancelado';
    final int precioUnitario = widget.tripData['precio'] ?? 0;
    final int precioConductor =
        widget.tripData['precioConductor'] ?? precioUnitario;
    final int comision =
        widget.tripData['comisionTripMate'] ??
        TripMatePricing.commission(precioConductor);
    final int iva =
        widget.tripData['ivaComision'] ??
        TripMatePricing.commissionIva(precioConductor);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Resumen del Viaje",
          style: TextStyle(
            color: Color(0xFF1A4371),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
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
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 30,
                    horizontal: 20,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A4371),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                  child: InkWell(
                    onTap: driverId.isEmpty
                        ? null
                        : () => _openPublicProfile(driverId),
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            backgroundImage:
                                (fotoUrl != null && fotoUrl.isNotEmpty)
                                ? NetworkImage(fotoUrl)
                                : null,
                            child: (fotoUrl == null || fotoUrl.isEmpty)
                                ? const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Color(0xFF1A4371),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 15),
                          Text(
                            nombre,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          _buildDriverRating(_ratingFromUserData(userData)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            Padding(
              padding: const EdgeInsets.all(25.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "INFORMACIÓN DEL VIAJE",
                    style: TextStyle(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildRouteStep(
                    icon: Icons.radio_button_checked,
                    color: const Color(0xFF2BB8D1),
                    city: _cap(origenTexto), // <--- CAMBIADO
                    label: "Punto de partida",
                    isLast: false,
                  ),
                  _buildRouteStep(
                    icon: Icons.location_on,
                    color: const Color(0xFFF05A28),
                    city: _cap(destinoTexto), // <--- CAMBIADO
                    label: "Destino final",
                    isLast: true,
                  ),

                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F4F8),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          color: Color(0xFF1A4371),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _formatearFechaLarga(fechaSalida),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  const Text(
                    "VEHÍCULO",
                    style: TextStyle(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildVehicleSection(widget.tripData['vehiculo']),

                  const SizedBox(height: 25),

                  Row(
                    children: [
                      _infoCard(
                        Icons.event_seat,
                        "$cuposMaximos Cupos",
                        "Disponibles",
                      ),
                      const SizedBox(width: 15),
                      _infoCard(
                        Icons.payments_outlined,
                        TripMateFormat.currencyCLP(precioUnitario),
                        "Precio p/p",
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  if (!soyElConductor && cuposMaximos > 0) ...[
                    const Divider(),
                    const SizedBox(height: 15),
                    _buildSeatSelector(cuposMaximos),
                    _buildCompanionFields(),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _comentarioController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: "Ej: Llevo equipaje, ¿hay espacio?",
                        labelText: "Comentarios al conductor",
                        labelStyle: const TextStyle(
                          color: Color(0xFF1A4371),
                          fontSize: 13,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(
                            color: Color(0xFF1A4371),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        "Total a pagar: ${TripMateFormat.currencyCLP(precioUnitario * _cantidadSeleccionada)}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A4371),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPaymentSummary(
                      conductor: precioConductor * _cantidadSeleccionada,
                      comision: comision * _cantidadSeleccionada,
                      iva: iva * _cantidadSeleccionada,
                      total: precioUnitario * _cantidadSeleccionada,
                    ),
                  ],

                  if (soyElConductor) ...[
                    const Divider(),
                    const SizedBox(height: 15),
                    _buildConfirmedPassengers(
                      widget.tripData['tripId'] ?? widget.tripData['id'],
                    ),
                    const SizedBox(height: 20),
                    _buildPassengerRequests(
                      widget.tripData['tripId'] ?? widget.tripData['id'],
                    ),
                  ],

                  if (!soyElConductor) ...[
                    const SizedBox(height: 20),
                    _buildConfirmedPassengers(
                      widget.tripData['tripId'] ?? widget.tripData['id'],
                    ),
                  ],

                  const SizedBox(height: 30),

                  if (soyElConductor)
                    _buildDriverTripActions(viajeCancelado)
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              (cuposMaximos > 0 && !viajeCancelado)
                              ? const Color(0xFFF05A28)
                              : Colors.grey[400],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: (cuposMaximos > 0 && !viajeCancelado)
                              ? 4
                              : 0,
                        ),
                        onPressed: (cuposMaximos > 0 && !viajeCancelado)
                            ? () => _processBooking(
                                context,
                                _cantidadSeleccionada,
                                _comentarioController.text,
                              )
                            : null,
                        child: Text(
                          viajeCancelado
                              ? "VIAJE CANCELADO"
                              : (cuposMaximos > 0
                                    ? "SOLICITAR RESERVA"
                                    : "VIAJE AGOTADO"),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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

  Widget _buildPaymentSummary({
    required int conductor,
    required int comision,
    required int iva,
    required int total,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          _summaryRow("Valor del viaje", TripMateFormat.currencyCLP(conductor)),
          _summaryRow(
            "Comisión TripMate",
            TripMateFormat.currencyCLP(comision),
          ),
          _summaryRow(
            "IVA incluido en comisión",
            TripMateFormat.currencyCLP(iva),
          ),
          const Divider(),
          _summaryRow(
            "Total pasajero",
            TripMateFormat.currencyCLP(total),
            bold: true,
          ),
          const SizedBox(height: 6),
          const Text(
            "El pago quedará pendiente hasta que el conductor acepte la solicitud.",
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverTripActions(bool viajeCancelado) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            viajeCancelado ? "VIAJE CANCELADO" : "ESTE ES TU VIAJE",
            style: const TextStyle(
              color: Color(0xFF1A4371),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
        if (!viajeCancelado) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _confirmarCancelarViaje,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text(
              "CANCELAR VIAJE",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ],
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontSize: 12,
      fontWeight: bold ? FontWeight.bold : FontWeight.w500,
      color: bold ? const Color(0xFF1A4371) : Colors.black87,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }

  Widget _buildDriverRating(_DriverRating rating) {
    final text = rating.hasRating
        ? rating.rating.toStringAsFixed(1)
        : "Sin calificaciones";

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...List.generate(5, (index) {
          final starValue = index + 1;
          final icon = rating.rating >= starValue - 0.25
              ? Icons.star
              : rating.rating >= starValue - 0.75
              ? Icons.star_half
              : Icons.star_border;

          return Icon(icon, color: const Color(0xFFFFD700), size: 16);
        }),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSeatSelector(int availableSeats) {
    final maxSeats = _maxReservableSeats(availableSeats);
    final canRemove = _cantidadSeleccionada > 1;
    final canAdd = _cantidadSeleccionada < maxSeats;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Asientos a reservar",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A4371),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Puedes reservar entre 1 y $maxSeats cupo(s)",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _seatStepButton(
                icon: Icons.remove,
                enabled: canRemove,
                onPressed: () =>
                    _setSelectedSeats(_cantidadSeleccionada - 1, maxSeats),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _seatController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(1),
                  ],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A4371),
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF1A4371)),
                    ),
                  ),
                  onChanged: (value) => _onSeatsInputChanged(value, maxSeats),
                  onEditingComplete: () {
                    final parsed = int.tryParse(_seatController.text) ?? 1;
                    _setSelectedSeats(parsed, maxSeats);
                    FocusScope.of(context).unfocus();
                  },
                  onTapOutside: (_) {
                    final parsed = int.tryParse(_seatController.text) ?? 1;
                    _setSelectedSeats(parsed, maxSeats);
                  },
                ),
              ),
              const SizedBox(width: 12),
              _seatStepButton(
                icon: Icons.add,
                enabled: canAdd,
                onPressed: () =>
                    _setSelectedSeats(_cantidadSeleccionada + 1, maxSeats),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _seatStepButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 52,
      height: 52,
      child: IconButton.filled(
        onPressed: enabled ? onPressed : null,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFF05A28),
          disabledBackgroundColor: Colors.grey[300],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _buildCompanionFields() {
    if (_companionNameControllers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        const Text(
          "Acompañantes sin cuenta TripMate",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A4371),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(_companionNameControllers.length, (index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FB),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _companionNameControllers[index],
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: "Nombre acompañante ${index + 1}",
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _companionRutControllers[index],
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: "RUT acompañante ${index + 1}",
                    hintText: "12.345.678-9",
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  List<Map<String, dynamic>> _companionsFromBooking(
    Map<String, dynamic> booking,
  ) {
    final rawCompanions =
        booking['companions'] ??
        booking['acompanantes'] ??
        booking['acompañantes'] ??
        booking['pasajerosAdicionales'] ??
        booking['additionalPassengers'];

    if (rawCompanions is! List) return [];

    return rawCompanions
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Widget _buildPassengerRequests(String? tripId) {
    if (tripId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('tripId', isEqualTo: tripId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final booking = doc.data() as Map<String, dynamic>;
          return (booking['status'] ?? 'pendiente').toString().toLowerCase() ==
              'pendiente';
        }).toList();
        if (docs.isEmpty) {
          return const Text(
            "Aún no hay solicitudes para este viaje.",
            style: TextStyle(color: Colors.grey),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "SOLICITUDES PENDIENTES",
              style: TextStyle(
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            ...docs.map((doc) {
              final booking = doc.data() as Map<String, dynamic>;
              return _buildPassengerRequestCard(doc.id, booking);
            }),
          ],
        );
      },
    );
  }

  Widget _buildConfirmedPassengers(String? tripId) {
    if (tripId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('tripId', isEqualTo: tripId)
          .where('status', isEqualTo: 'confirmado')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "PASAJEROS CONFIRMADOS",
              style: TextStyle(
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            ...docs.map((doc) {
              final booking = doc.data() as Map<String, dynamic>;
              return _buildConfirmedPassengerCard(booking);
            }),
          ],
        );
      },
    );
  }

  Widget _buildConfirmedPassengerCard(Map<String, dynamic> booking) {
    final passengerId = booking['passengerId']?.toString() ?? '';
    final seatCount = booking['cantidadAsientos'] is int
        ? booking['cantidadAsientos'] as int
        : int.tryParse(booking['cantidadAsientos']?.toString() ?? '') ?? 1;
    final companions = _companionsFromBooking(booking);
    final missingCompanions = (seatCount - 1 - companions.length)
        .clamp(0, seatCount)
        .toInt();

    return FutureBuilder<Map<String, dynamic>?>(
      future: _getDriverData(passengerId),
      builder: (context, snapshot) {
        final passenger = snapshot.data;
        final nombre = passenger?['nombre'] ?? 'Pasajero TripMate';
        final rut = passenger?['rut']?.toString();
        final fotoUrl = passenger?['photoUrl'];

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: passengerId.isEmpty
                    ? null
                    : () => _openPublicProfile(passengerId),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundImage:
                          (fotoUrl != null && fotoUrl.toString().isNotEmpty)
                          ? NetworkImage(fotoUrl)
                          : null,
                      child: (fotoUrl == null || fotoUrl.toString().isEmpty)
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre.toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A4371),
                            ),
                          ),
                          Text(
                            rut == null || rut.isEmpty
                                ? "Cuenta TripMate"
                                : "RUT: $rut",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                      size: 20,
                    ),
                  ],
                ),
              ),
              if (companions.isNotEmpty || missingCompanions > 0) ...[
                const Divider(height: 20),
                ...companions.map(_buildCompanionRow),
                if (missingCompanions > 0)
                  Text(
                    "$missingCompanions acompañante(s) sin información registrada",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompanionRow(Map<String, dynamic> companion) {
    final nombre =
        companion['nombre'] ??
        companion['name'] ??
        companion['fullName'] ??
        'Acompañante';
    final rut = companion['rut'] ?? companion['documento'] ?? companion['id'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFFF1F4F8),
            child: Icon(Icons.person_outline, size: 20, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  rut == null || rut.toString().isEmpty
                      ? "Sin cuenta TripMate"
                      : "RUT: $rut",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerRequestCard(
    String bookingId,
    Map<String, dynamic> booking,
  ) {
    final passengerId = booking['passengerId'] ?? '';
    final status = (booking['status'] ?? 'pendiente').toString().toLowerCase();
    final isPending = status == 'pendiente';

    return FutureBuilder<Map<String, dynamic>?>(
      future: _getDriverData(passengerId),
      builder: (context, snapshot) {
        final passenger = snapshot.data;
        final nombre = passenger?['nombre'] ?? 'Pasajero';
        final fotoUrl = passenger?['photoUrl'];

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: (fotoUrl != null && fotoUrl.isNotEmpty)
                        ? NetworkImage(fotoUrl)
                        : null,
                    child: (fotoUrl == null || fotoUrl.isEmpty)
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A4371),
                          ),
                        ),
                        Text(
                          "${booking['cantidadAsientos'] ?? 1} asiento(s) - ${status.toUpperCase()}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if ((booking['comentario'] ?? '').toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      booking['comentario'],
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _abrirChatPasajero(bookingId, booking),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text("ABRIR CHAT"),
                  ),
                ),
              ),
              if (isPending)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _rechazarReserva(bookingId),
                          child: const Text("RECHAZAR"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _aceptarReserva(bookingId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF05A28),
                          ),
                          child: const Text(
                            "ACEPTAR",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.directions_car_filled,
            color: Color(0xFF2BB8D1),
            size: 30,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${_cap(marca)} ${_cap(modelo)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  "Color: ${_cap(color)}",
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F4F8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black12),
            ),
            child: Text(
              patente.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF2BB8D1)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF1A4371),
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteStep({
    required IconData icon,
    required Color color,
    required String city,
    required String label,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(icon, color: color, size: 28),
            if (!isLast)
              Container(width: 2, height: 40, color: Colors.grey[200]),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                city,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF1A4371),
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriverRating {
  final double rating;
  final int? count;

  const _DriverRating({required this.rating, this.count});

  const _DriverRating.empty() : rating = 0, count = 0;

  bool get hasRating => rating > 0 && count != 0;
}
