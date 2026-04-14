import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleMapsService {
  static const String _apiKey = "AIzaSyDSk6VOMIPTV8alKM1tqGLIin31RgLEo6Q";

  static Future<List<dynamic>> buscarEnPlaces(String input) async {
    String url = "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$_apiKey&components=country:cl";
    var response = await http.get(Uri.parse(url));
    return response.statusCode == 200 ? json.decode(response.body)['predictions'] : [];
  }

  static Future<Map<String, dynamic>> obtenerCoordenadas(String placeId) async {
    String url = "https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry&key=$_apiKey";
    var response = await http.get(Uri.parse(url));
    final location = json.decode(response.body)['result']['geometry']['location'];
    return {'lat': location['lat'], 'lng': location['lng']};
  }
}