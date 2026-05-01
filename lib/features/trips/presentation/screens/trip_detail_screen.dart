// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:tripmate_app/core/services/payment_service.dart';
import 'package:tripmate_app/core/utils/formatters.dart';
import 'package:tripmate_app/core/utils/pricing.dart';
import 'package:tripmate_app/features/chat/presentation/screens/chat_screen.dart';
import 'package:tripmate_app/features/profile/presentation/screens/payment_methods_screen.dart';
import 'package:tripmate_app/features/profile/presentation/screens/public_profile_screen.dart';
import 'package:tripmate_app/features/trips/presentation/widgets/seat_wheel_picker.dart';

class TripDetailScreen extends StatefulWidget {
  final Map<String, dynamic> tripData;

  const TripDetailScreen({super.key, required this.tripData});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  int _cantidadSeleccionada = 1;
  final TextEditingController _comentarioController = TextEditingController();

  @override
  void dispose() {
    _comentarioController.dispose();
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

  Future<void> _seleccionarAsientosReserva(int maxSeats) async {
    final seats = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (context) => SeatWheelPicker(
          maxSeats: maxSeats,
          initialSeats: _cantidadSeleccionada,
          title: "Asientos a reservar",
        ),
      ),
    );

    if (seats != null) {
      setState(() => _cantidadSeleccionada = seats);
    }
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
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: driverId.isEmpty
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      PublicProfileScreen(userId: driverId),
                                ),
                              ),
                        child: CircleAvatar(
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
                      ),
                      const SizedBox(height: 15),
                      Text(
                        nombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star, color: Color(0xFFFFD700), size: 16),
                          Icon(Icons.star, color: Color(0xFFFFD700), size: 16),
                          Icon(Icons.star, color: Color(0xFFFFD700), size: 16),
                          SizedBox(width: 5),
                          Text(
                            "4.8",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
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
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        "Asientos a reservar",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A4371),
                        ),
                      ),
                      subtitle: const Text("Toca para elegir con contador"),
                      trailing: Container(
                        width: 58,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F4F8),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          "$_cantidadSeleccionada",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A4371),
                          ),
                        ),
                      ),
                      onTap: () => _seleccionarAsientosReserva(cuposMaximos),
                    ),
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

                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (cuposMaximos > 0 && !soyElConductor)
                            ? const Color(0xFFF05A28)
                            : Colors.grey[400],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: (cuposMaximos > 0 && !soyElConductor)
                            ? 4
                            : 0,
                      ),
                      onPressed: (cuposMaximos > 0 && !soyElConductor)
                          ? () => _processBooking(
                              context,
                              _cantidadSeleccionada,
                              _comentarioController.text,
                            )
                          : null,
                      child: Text(
                        soyElConductor
                            ? "ESTE ES TU VIAJE"
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

        final docs = snapshot.data?.docs ?? [];
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
              "SOLICITUDES Y PASAJEROS",
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
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final booking = docs[index].data() as Map<String, dynamic>;
                  final passengerId = booking['passengerId'] ?? '';
                  return FutureBuilder<Map<String, dynamic>?>(
                    future: _getDriverData(passengerId),
                    builder: (context, snapshot) {
                      final passenger = snapshot.data;
                      final nombre = (passenger?['nombre'] ?? 'Pasajero')
                          .toString()
                          .split(' ')
                          .first;
                      final fotoUrl = passenger?['photoUrl'];

                      return GestureDetector(
                        onTap: passengerId.toString().isEmpty
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      PublicProfileScreen(userId: passengerId),
                                ),
                              ),
                        child: SizedBox(
                          width: 62,
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundImage:
                                    (fotoUrl != null && fotoUrl.isNotEmpty)
                                    ? NetworkImage(fotoUrl)
                                    : null,
                                child: (fotoUrl == null || fotoUrl.isEmpty)
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
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
