// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class VehicleDetailScreen extends StatefulWidget {
  final Map<String, dynamic> vehicle;

  const VehicleDetailScreen({super.key, required this.vehicle});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _colorController = TextEditingController();
  final _patenteController = TextEditingController();
  final _capacidadController = TextEditingController();

  late Map<String, dynamic> _vehicle;
  bool _isEditing = false;
  bool _isSaving = false;
  File? _fotoPatente;
  File? _fotoPadron;
  String? _fotoPatenteUrl;
  String? _fotoPadronUrl;

  @override
  void initState() {
    super.initState();
    _vehicle = Map<String, dynamic>.from(widget.vehicle);
    _fotoPatenteUrl = _stringValue('fotoPatenteUrl', fallback: '');
    _fotoPadronUrl = _stringValue('fotoPadronUrl', fallback: '');
    _syncControllers();
  }

  @override
  void dispose() {
    _marcaController.dispose();
    _modeloController.dispose();
    _colorController.dispose();
    _patenteController.dispose();
    _capacidadController.dispose();
    super.dispose();
  }

  void _syncControllers() {
    _marcaController.text = _stringValue('marca', fallback: '');
    _modeloController.text = _stringValue('modelo', fallback: '');
    _colorController.text = _stringValue('color', fallback: '');
    _patenteController.text = _stringValue('patente', fallback: '');
    _capacidadController.text = _stringValue('capacidad', fallback: '');
  }

  String _stringValue(String key, {String fallback = "No informado"}) {
    final value = _vehicle[key];
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  bool get _hasFotoPatente =>
      _fotoPatente != null ||
      (_fotoPatenteUrl != null && _fotoPatenteUrl!.trim().isNotEmpty);

  bool get _hasFotoPadron =>
      _fotoPadron != null ||
      (_fotoPadronUrl != null && _fotoPadronUrl!.trim().isNotEmpty);

  String get _statusLabel {
    if (_vehicle['verificado'] == true) return "Vehículo verificado";
    final status = _stringValue('status', fallback: 'pendiente').toLowerCase();
    if (status == 'rechazado') return "Rechazado";
    if (status == 'aprobado') return "Aprobado";
    return "En revisión";
  }

  Color get _statusColor {
    if (_vehicle['verificado'] == true) return Colors.green;
    final status = _stringValue('status', fallback: 'pendiente').toLowerCase();
    if (status == 'rechazado') return Colors.redAccent;
    return Colors.orange;
  }

  Future<void> _seleccionarImagen(String tipo, ImageSource source) async {
    final image = await _picker.pickImage(source: source, imageQuality: 70);
    if (image == null) return;

    setState(() {
      if (tipo == 'patente') _fotoPatente = File(image.path);
      if (tipo == 'padron') _fotoPadron = File(image.path);
    });
  }

  Future<void> _mostrarOrigenImagen(String tipo) async {
    if (!_isEditing) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.photo_camera,
                  color: Color(0xFFF05A28),
                ),
                title: const Text("Tomar foto"),
                onTap: () {
                  Navigator.pop(context);
                  _seleccionarImagen(tipo, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: Color(0xFF2BB8D1),
                ),
                title: const Text("Elegir desde galería"),
                onTap: () {
                  Navigator.pop(context);
                  _seleccionarImagen(tipo, ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _subirArchivo(File file, String folder, String uid) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child(folder)
        .child('$uid-${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasFotoPatente || !_hasFotoPadron) {
      _notificar("Sube la foto de patente y padrón/SOAP", esError: true);
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);

    try {
      final nuevaFotoPatenteUrl = _fotoPatente == null
          ? _fotoPatenteUrl
          : await _subirArchivo(_fotoPatente!, 'vehiculos/patentes', uid);
      final nuevaFotoPadronUrl = _fotoPadron == null
          ? _fotoPadronUrl
          : await _subirArchivo(_fotoPadron!, 'vehiculos/padrones', uid);

      final updatedVehicle = {
        ..._vehicle,
        'marca': _marcaController.text.trim(),
        'modelo': _modeloController.text.trim(),
        'color': _colorController.text.trim(),
        'patente': _patenteController.text.trim().toUpperCase(),
        'capacidad': int.tryParse(_capacidadController.text.trim()) ?? 4,
        'fotoPatenteUrl': nuevaFotoPatenteUrl,
        'fotoPadronUrl': nuevaFotoPadronUrl,
        'verificado': false,
        'status': 'pendiente',
        'updatedAt': Timestamp.now(),
      };

      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final userDoc = await userRef.get();
      final data = userDoc.data() ?? {};
      final currentVehicles = List<dynamic>.from(data['vehiculos'] ?? []);
      final index = _findVehicleIndex(currentVehicles);

      if (index >= 0) {
        currentVehicles[index] = updatedVehicle;
        await userRef.update({'vehiculos': currentVehicles});
      } else {
        await userRef.set({
          'vehiculos': FieldValue.arrayUnion([updatedVehicle]),
        }, SetOptions(merge: true));
      }

      final vehicleId = updatedVehicle['vehicleId']?.toString();
      if (vehicleId != null && vehicleId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('vehicles')
            .doc(vehicleId)
            .set({
              ...updatedVehicle,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }

      setState(() {
        _vehicle = Map<String, dynamic>.from(updatedVehicle);
        _fotoPatente = null;
        _fotoPadron = null;
        _fotoPatenteUrl = nuevaFotoPatenteUrl;
        _fotoPadronUrl = nuevaFotoPadronUrl;
        _isEditing = false;
      });
      _notificar("Vehículo actualizado y enviado a revisión", esError: false);
    } catch (e) {
      _notificar("No pudimos guardar los cambios", esError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  int _findVehicleIndex(List<dynamic> vehicles) {
    final vehicleId = _vehicle['vehicleId']?.toString();
    final patente = _vehicle['patente']?.toString();

    return vehicles.indexWhere((item) {
      if (item is! Map) return false;
      if (vehicleId != null &&
          vehicleId.isNotEmpty &&
          item['vehicleId']?.toString() == vehicleId) {
        return true;
      }
      return patente != null &&
          patente.isNotEmpty &&
          item['patente']?.toString() == patente;
    });
  }

  void _cancelarEdicion() {
    setState(() {
      _isEditing = false;
      _fotoPatente = null;
      _fotoPadron = null;
      _fotoPatenteUrl = _stringValue('fotoPatenteUrl', fallback: '');
      _fotoPadronUrl = _stringValue('fotoPadronUrl', fallback: '');
      _syncControllers();
    });
  }

  void _notificar(String message, {required bool esError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: esError ? Colors.redAccent : const Color(0xFF1A4371),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
        "${_stringValue('marca', fallback: 'Vehículo')} ${_stringValue('modelo', fallback: '')}"
            .trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(
          _isEditing ? "Editar vehículo" : "Detalle del vehículo",
          style: const TextStyle(
            color: Color(0xFF1A4371),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A4371)),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_note, color: Color(0xFF1A4371)),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(title),
              const SizedBox(height: 20),
              _sectionTitle("INFORMACIÓN"),
              _infoGroup([
                _vehicleField(Icons.directions_car, "Marca", _marcaController),
                _vehicleField(
                  Icons.settings_suggest,
                  "Modelo",
                  _modeloController,
                ),
                _vehicleField(
                  Icons.palette_outlined,
                  "Color",
                  _colorController,
                ),
                _vehicleField(Icons.badge, "Patente", _patenteController),
                _vehicleField(
                  Icons.event_seat,
                  "Capacidad",
                  _capacidadController,
                  keyboardType: TextInputType.number,
                ),
              ]),
              const SizedBox(height: 20),
              _sectionTitle("DOCUMENTOS"),
              _infoGroup([
                _documentTile(
                  label: "Foto patente",
                  hasFile: _hasFotoPatente,
                  localFile: _fotoPatente,
                  onTap: () => _mostrarOrigenImagen('patente'),
                ),
                _documentTile(
                  label: "Padrón / SOAP",
                  hasFile: _hasFotoPadron,
                  localFile: _fotoPadron,
                  onTap: () => _mostrarOrigenImagen('padron'),
                ),
              ]),
              if (_isEditing) ...[
                const SizedBox(height: 24),
                _buildEditActions(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF8FA),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.directions_car_rounded,
                  color: Color(0xFF2BB8D1),
                  size: 34,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? "Vehículo" : title,
                      style: const TextStyle(
                        color: Color(0xFF1A4371),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _stringValue('patente', fallback: 'Sin patente'),
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _statusColor.withOpacity(0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _vehicle['verificado'] == true
                      ? Icons.verified_user
                      : Icons.access_time_filled_rounded,
                  color: _statusColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  _statusLabel,
                  style: TextStyle(
                    color: _statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _infoGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _vehicleField(
    IconData icon,
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    if (!_isEditing) {
      return ListTile(
        leading: Icon(icon, color: const Color(0xFF2BB8D1)),
        title: Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        subtitle: Text(
          controller.text.isEmpty ? "No informado" : controller.text,
          style: const TextStyle(
            color: Color(0xFF1A4371),
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: label == "Patente"
            ? TextCapitalization.characters
            : TextCapitalization.words,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return "Campo requerido";
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF2BB8D1)),
          filled: true,
          fillColor: const Color(0xFFF8F9FB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _documentTile({
    required String label,
    required bool hasFile,
    required File? localFile,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: _isEditing ? onTap : null,
      leading: Icon(
        hasFile ? Icons.check_circle : Icons.pending_outlined,
        color: hasFile ? Colors.green : Colors.orange,
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF1A4371),
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        localFile != null
            ? "Nueva foto seleccionada"
            : hasFile
            ? "Documento subido"
            : "Pendiente",
        style: TextStyle(color: hasFile ? Colors.green : Colors.orange),
      ),
      trailing: _isEditing
          ? const Icon(Icons.camera_alt_outlined, color: Color(0xFFF05A28))
          : null,
    );
  }

  Widget _buildEditActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _guardarCambios,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF05A28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    "GUARDAR CAMBIOS",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _isSaving ? null : _cancelarEdicion,
          child: const Text(
            "CANCELAR",
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
