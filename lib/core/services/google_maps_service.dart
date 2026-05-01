import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleMapsService {
  static const String _apiKey = "AIzaSyDSk6VOMIPTV8alKM1tqGLIin31RgLEo6Q";

  static Future<List<dynamic>> buscarEnPlaces(String input) async {
    String url =
        "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$_apiKey&components=country:cl";
    var response = await http.get(Uri.parse(url));
    return response.statusCode == 200
        ? json.decode(response.body)['predictions']
        : [];
  }

  static Future<Map<String, dynamic>> obtenerCoordenadas(String placeId) async {
    String url =
        "https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry&key=$_apiKey";
    var response = await http.get(Uri.parse(url));
    final location = json.decode(
      response.body,
    )['result']['geometry']['location'];
    return {'lat': location['lat'], 'lng': location['lng']};
  }

  static Future<double?> obtenerDistanciaRutaKm({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
  }) async {
    final url =
        "https://maps.googleapis.com/maps/api/distancematrix/json?origins=$originLat,$originLng&destinations=$destinationLat,$destinationLng&mode=driving&language=es&key=$_apiKey";
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return null;

    final data = json.decode(response.body);
    final rows = data['rows'] as List<dynamic>? ?? [];
    if (rows.isEmpty) return null;

    final elements = rows.first['elements'] as List<dynamic>? ?? [];
    if (elements.isEmpty) return null;

    final element = elements.first as Map<String, dynamic>;
    if (element['status'] != 'OK') return null;

    final meters = element['distance']?['value'];
    if (meters is! num) return null;

    return meters / 1000;
  }

  static Future<RouteCostData?> obtenerRutaConPeajes({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
  }) async {
    final response = await http.post(
      Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes'),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask':
            'routes.distanceMeters,routes.travelAdvisory.tollInfo',
      },
      body: json.encode({
        'origin': {
          'location': {
            'latLng': {'latitude': originLat, 'longitude': originLng},
          },
        },
        'destination': {
          'location': {
            'latLng': {'latitude': destinationLat, 'longitude': destinationLng},
          },
        },
        'travelMode': 'DRIVE',
        'routingPreference': 'TRAFFIC_UNAWARE',
        'extraComputations': ['TOLLS'],
        'routeModifiers': {
          'vehicleInfo': {'emissionType': 'GASOLINE'},
        },
        'languageCode': 'es-CL',
        'units': 'METRIC',
      }),
    );

    if (response.statusCode != 200) return null;

    final data = json.decode(response.body);
    final routes = data['routes'] as List<dynamic>? ?? [];
    if (routes.isEmpty) return null;

    final route = routes.first as Map<String, dynamic>;
    final distanceMeters = route['distanceMeters'];
    final tollInfo = route['travelAdvisory']?['tollInfo'];
    final estimatedPrices = tollInfo?['estimatedPrice'] as List<dynamic>? ?? [];

    int? tollsClp;
    for (final price in estimatedPrices) {
      if (price is! Map<String, dynamic>) continue;
      if (price['currencyCode'] != 'CLP') continue;
      tollsClp = _moneyToClp(price);
      break;
    }

    return RouteCostData(
      distanceKm: distanceMeters is num ? distanceMeters / 1000 : null,
      tollsClp: tollsClp,
      tollsAvailable: estimatedPrices.isNotEmpty,
    );
  }

  static int _moneyToClp(Map<String, dynamic> money) {
    final units = int.tryParse((money['units'] ?? '0').toString()) ?? 0;
    final nanos = money['nanos'];
    final roundedNanos = nanos is num ? (nanos / 1000000000).round() : 0;
    return units + roundedNanos;
  }

  static Future<String> obtenerDireccion(double lat, double lng) async {
    final url =
        "https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_apiKey&language=es&components=country:CL";
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return "Ubicación seleccionada";

    final results =
        json.decode(response.body)['results'] as List<dynamic>? ?? [];
    if (results.isEmpty) return "Ubicación seleccionada";

    final specificResult = results.cast<Map<String, dynamic>>().firstWhere((
      result,
    ) {
      final formatted = (result['formatted_address'] ?? '').toString();
      final types = List<String>.from(result['types'] ?? []);
      return formatted.isNotEmpty &&
          formatted.toLowerCase() != 'chile' &&
          !types.contains('country');
    }, orElse: () => Map<String, dynamic>.from(results.first));

    final formattedAddress = (specificResult['formatted_address'] ?? '')
        .toString()
        .trim();

    if (formattedAddress.isEmpty || formattedAddress.toLowerCase() == 'chile') {
      return "Ubicación seleccionada";
    }

    return formattedAddress;
  }

  static bool esDireccionGenerica(String address) {
    final normalized = address.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'chile' ||
        normalized == 'ubicación seleccionada' ||
        normalized == 'ubicacion seleccionada';
  }
}

class RouteCostData {
  final double? distanceKm;
  final int? tollsClp;
  final bool tollsAvailable;

  const RouteCostData({
    required this.distanceKm,
    required this.tollsClp,
    required this.tollsAvailable,
  });
}
