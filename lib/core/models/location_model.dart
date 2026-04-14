class LocationData {
  final String address;
  final double lat;
  final double lng;

  LocationData({
    required this.address, 
    required this.lat, 
    required this.lng
  });

  Map<String, dynamic> toMap() => {
    'address': address,
    'lat': lat,
    'lng': lng,
  };

  factory LocationData.fromMap(Map<String, dynamic> map) {
    return LocationData(
      address: map['address'] ?? '',
      lat: (map['lat'] ?? 0.0).toDouble(),
      lng: (map['lng'] ?? 0.0).toDouble(),
    );
  }
}