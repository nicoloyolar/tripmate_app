import 'dart:math' as math;
import 'package:tripmate_app/core/models/location_model.dart';

class GeoUtils {
  static double calcularDistancia(LocationData start, LocationData end) {
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
}