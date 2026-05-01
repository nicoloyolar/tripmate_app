import 'package:flutter/material.dart';

class SeatWheelPicker extends StatefulWidget {
  final int maxSeats;
  final int initialSeats;
  final String title;

  const SeatWheelPicker({
    super.key,
    required this.maxSeats,
    this.initialSeats = 1,
    this.title = "Selecciona asientos",
  });

  @override
  State<SeatWheelPicker> createState() => _SeatWheelPickerState();
}

class _SeatWheelPickerState extends State<SeatWheelPicker> {
  late int _selectedSeats;
  late FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _selectedSeats = widget.initialSeats.clamp(1, widget.maxSeats);
    _controller = FixedExtentScrollController(initialItem: _selectedSeats - 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Color(0xFF1A4371),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A4371)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 82,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                      ),
                      ListWheelScrollView.useDelegate(
                        controller: _controller,
                        itemExtent: 88,
                        diameterRatio: 1.4,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (index) {
                          setState(() => _selectedSeats = index + 1);
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: widget.maxSeats,
                          builder: (context, index) {
                            final seats = index + 1;
                            final selected = seats == _selectedSeats;
                            return Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 150),
                                style: TextStyle(
                                  fontSize: selected ? 56 : 32,
                                  fontWeight: FontWeight.bold,
                                  color: selected
                                      ? const Color(0xFF1A4371)
                                      : Colors.grey[400],
                                ),
                                child: Text("$seats"),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                _selectedSeats == 1 ? "1 asiento" : "$_selectedSeats asientos",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A4371),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selectedSeats),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF05A28),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    "CONFIRMAR",
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
    );
  }
}
