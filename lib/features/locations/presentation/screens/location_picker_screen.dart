// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tripmate_app/core/models/location_model.dart';
import 'package:tripmate_app/core/services/google_maps_service.dart';

class LocationPickerScreen extends StatefulWidget {
  final String title;
  final LocationData? initialLocation;

  const LocationPickerScreen({
    super.key,
    required this.title,
    this.initialLocation,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const LatLng _defaultCenter = LatLng(-33.4489, -70.6693);

  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  Timer? _cameraIdleDebounce;
  LatLng _selected = _defaultCenter;
  String _address = "Mueve el mapa o usa tu ubicación actual";
  List<dynamic> _predictions = [];
  bool _hasMapPosition = false;
  bool _isLoading = true;
  bool _isSearching = false;
  bool _suppressNextCameraIdle = false;
  DateTime? _ignoreCameraUpdatesUntil;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selected = LatLng(
        widget.initialLocation!.lat,
        widget.initialLocation!.lng,
      );
      _address = widget.initialLocation!.address;
      _searchController.text = widget.initialLocation!.address;
      _hasMapPosition = true;
      _isLoading = false;
    } else {
      _useCurrentLocation(silent: true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cameraIdleDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation({bool silent = false}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent) _notify("Activa la ubicación del dispositivo.");
        setState(() {
          _hasMapPosition = true;
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!silent) {
          _notify("Necesitamos permiso de ubicación para usar esta opción.");
        }
        setState(() {
          _hasMapPosition = true;
          _isLoading = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _selectPosition(
        LatLng(position.latitude, position.longitude),
        animate: true,
      );
    } catch (_) {
      if (!silent) _notify("No pudimos obtener tu ubicación actual.");
      setState(() {
        _hasMapPosition = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectPosition(
    LatLng position, {
    bool animate = false,
    String? preferredAddress,
  }) async {
    setState(() {
      _selected = position;
      _hasMapPosition = true;
      _isLoading = true;
    });

    if (animate) {
      _suppressNextCameraIdle = preferredAddress != null;
      _ignoreCameraUpdatesUntil = DateTime.now().add(
        const Duration(milliseconds: 1500),
      );
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(position, 16),
      );
    }

    final address =
        preferredAddress ??
        await GoogleMapsService.obtenerDireccion(
          position.latitude,
          position.longitude,
        );

    if (!mounted) return;
    setState(() {
      if (!GoogleMapsService.esDireccionGenerica(address)) {
        _address = address;
        _searchController.text = address;
      }
      _isLoading = false;
      _predictions = [];
    });
  }

  void _onCameraMove(CameraPosition position) {
    if (_shouldIgnoreCameraUpdate) return;

    _selected = position.target;
    if (!_isLoading) {
      setState(() => _isLoading = true);
    }
  }

  void _onCameraIdle() {
    if (_shouldIgnoreCameraUpdate) return;

    if (_suppressNextCameraIdle) {
      _suppressNextCameraIdle = false;
      return;
    }

    _cameraIdleDebounce?.cancel();
    _cameraIdleDebounce = Timer(const Duration(milliseconds: 350), () {
      _updateAddressFromCenter();
    });
  }

  Future<void> _updateAddressFromCenter() async {
    final position = _selected;
    final address = await GoogleMapsService.obtenerDireccion(
      position.latitude,
      position.longitude,
    );

    if (!mounted) return;
    setState(() {
      if (!GoogleMapsService.esDireccionGenerica(address)) {
        _address = address;
        _searchController.text = address;
      }
      _isLoading = false;
      _predictions = [];
    });
  }

  bool get _shouldIgnoreCameraUpdate {
    final until = _ignoreCameraUpdatesUntil;
    if (until == null) return false;
    if (DateTime.now().isBefore(until)) return true;
    _ignoreCameraUpdatesUntil = null;
    return false;
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 450), () async {
      if (value.trim().length < 3) {
        if (mounted) setState(() => _predictions = []);
        return;
      }

      setState(() => _isSearching = true);
      final results = await GoogleMapsService.buscarEnPlaces(value.trim());
      if (!mounted) return;
      setState(() {
        _predictions = results;
        _isSearching = false;
      });
    });
  }

  Future<void> _selectPrediction(dynamic place) async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final coords = await GoogleMapsService.obtenerCoordenadas(
      place['place_id'],
    );
    final position = LatLng(coords['lat'], coords['lng']);
    final description = (place['description'] ?? '').toString();

    _searchController.text = description;
    await _selectPosition(
      position,
      animate: true,
      preferredAddress: description,
    );
  }

  void _notify(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  void _confirmSelection() {
    Navigator.pop(
      context,
      LocationData(
        address: _address,
        lat: _selected.latitude,
        lng: _selected.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A4371)),
        titleTextStyle: const TextStyle(
          color: Color(0xFF1A4371),
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      body: Stack(
        children: [
          if (_hasMapPosition)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _selected,
                zoom: 13,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              onMapCreated: (controller) => _mapController = controller,
              onCameraMove: _onCameraMove,
              onCameraIdle: _onCameraIdle,
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A4371)),
            ),
          if (_hasMapPosition) _buildCenterPin(),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: SafeArea(bottom: false, child: _buildSearchPanel()),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Ubicación exacta",
                      style: TextStyle(
                        color: Color(0xFF1A4371),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isLoading ? "Buscando dirección..." : _address,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _confirmSelection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF05A28),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text(
                          "USAR ESTA UBICACIÓN",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterPin() {
    return Center(
      child: IgnorePointer(
        child: Transform.translate(
          offset: const Offset(0, -22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF05A28),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              CustomPaint(size: const Size(18, 12), painter: _PinTipPainter()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 18),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _searchController,
            autofocus: widget.initialLocation == null,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: "Escribe una dirección",
              prefixIcon: const Icon(Icons.search, color: Color(0xFF1A4371)),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (_searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _predictions = []);
                            },
                          )),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.my_location, color: Color(0xFF1A4371)),
            title: const Text(
              "Utilizar ubicación actual",
              style: TextStyle(
                color: Color(0xFF1A4371),
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _useCurrentLocation(),
          ),
          if (_predictions.isNotEmpty) const Divider(height: 1),
          if (_predictions.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _predictions.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final place = _predictions[index];
                  return ListTile(
                    leading: const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFF2BB8D1),
                    ),
                    title: Text(
                      place['description'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _selectPrediction(place),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PinTipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFF05A28);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
