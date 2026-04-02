import 'package:flutter/material.dart';
import 'package:tripmate_app/features/auth/presentation/screens/profile_screen.dart';
import 'package:tripmate_app/features/bookings/presentation/screens/booking_screen.dart';
import 'package:tripmate_app/features/home/presentation/screens/home_screen.dart';
import 'package:tripmate_app/features/trips/presentation/screens/publish_trip_screen.dart';
import 'package:tripmate_app/features/trips/presentation/screens/trips_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const HomeScreen(),
      const PublishTripScreen(),
      const TripsScreen(), 
      const BookingsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1A4371),
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Buscar"),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: "Publicar"),
          BottomNavigationBarItem(icon: Icon(Icons.drive_eta_outlined), label: "Viajes"),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: "Reservas"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Perfil"),
        ],
      ),
    );
  }
}