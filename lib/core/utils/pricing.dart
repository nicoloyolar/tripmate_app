import 'dart:math';

class TripMatePricing {
  static const double commissionRate = 0.10;
  static const double ivaRate = 0.19;
  static const double averageFuelPriceClp = 1597.3;
  static const double averageKmPerLiter = 16;
  static const int seatsIncludingDriver = 5;
  static const int estimatedTollPerKm = 40;
  static const double minRecommendedFactor = 0.75;
  static const double maxRecommendedFactor = 1.35;

  static double get fuelCostPerKm => averageFuelPriceClp / averageKmPerLiter;

  static int estimateTolls(double kilometers) {
    return roundToNearest((kilometers * estimatedTollPerKm).round(), 500);
  }

  static int recommendedDriverPrice(double kilometers, {int? tolls}) {
    final estimatedTolls = tolls ?? estimateTolls(kilometers);
    final tripCost = (fuelCostPerKm * kilometers) + estimatedTolls;
    return (tripCost / seatsIncludingDriver).round();
  }

  static int recommendedPassengerPrice(double kilometers, {int? tolls}) {
    return passengerPrice(recommendedDriverPrice(kilometers, tolls: tolls));
  }

  static int minDriverPrice(int recommendedPrice) {
    return roundToNearest(
      (recommendedPrice * minRecommendedFactor).round(),
      500,
    );
  }

  static int maxDriverPrice(int recommendedPrice) {
    return roundToNearest(
      (recommendedPrice * maxRecommendedFactor).round(),
      500,
    );
  }

  static int passengerPrice(int driverPrice) {
    return (driverPrice * (1 + commissionRate)).round();
  }

  static int commission(int driverPrice) {
    return max(0, passengerPrice(driverPrice) - driverPrice);
  }

  static int commissionIva(int driverPrice) {
    return (commission(driverPrice) * ivaRate / (1 + ivaRate)).round();
  }

  static int roundToNearest(int value, int step) {
    if (step <= 0) return value;
    return (value / step).round() * step;
  }
}
