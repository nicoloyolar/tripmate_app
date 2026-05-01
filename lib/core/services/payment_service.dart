import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentService {
  static Future<Map<String, dynamic>?> defaultPaymentMethod() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('payment_methods')
        .where('isDefault', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return {'id': snapshot.docs.first.id, ...snapshot.docs.first.data()};
  }

  static Future<DocumentReference<Map<String, dynamic>>> createPaymentIntent({
    required String bookingId,
    required String tripId,
    required String passengerId,
    required String driverId,
    required int amount,
    required int driverAmount,
    required int commission,
    required int iva,
    required Map<String, dynamic> paymentMethod,
  }) async {
    final ref = FirebaseFirestore.instance.collection('payment_intents').doc();
    await ref.set({
      'paymentIntentId': ref.id,
      'bookingId': bookingId,
      'tripId': tripId,
      'passengerId': passengerId,
      'driverId': driverId,
      'amount': amount,
      'driverAmount': driverAmount,
      'commission': commission,
      'iva': iva,
      'currency': 'CLP',
      'status': 'authorized_pending_driver_acceptance',
      'paymentMethodId': paymentMethod['id'],
      'paymentMethodLabel': paymentMethod['label'],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref;
  }
}
