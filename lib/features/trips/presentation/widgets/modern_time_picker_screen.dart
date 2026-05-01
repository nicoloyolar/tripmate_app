import 'package:flutter/material.dart';

class ModernTimePickerScreen extends StatefulWidget {
  final TimeOfDay initialTime;

  const ModernTimePickerScreen({super.key, required this.initialTime});

  @override
  State<ModernTimePickerScreen> createState() => _ModernTimePickerScreenState();
}

class _ModernTimePickerScreenState extends State<ModernTimePickerScreen> {
  late int _hour;
  late int _minute;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  static const List<int> _minuteOptions = [
    0,
    5,
    10,
    15,
    20,
    25,
    30,
    35,
    40,
    45,
    50,
    55,
  ];

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = _nearestMinute(widget.initialTime.minute);
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(
      initialItem: _minuteOptions.indexOf(_minute),
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  static int _nearestMinute(int minute) {
    return _minuteOptions.reduce(
      (current, next) =>
          (minute - next).abs() < (minute - current).abs() ? next : current,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text(
          "Hora de salida",
          style: TextStyle(
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
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 26),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 22,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${_twoDigits(_hour)}:${_twoDigits(_minute)}",
                          style: const TextStyle(
                            fontSize: 54,
                            color: Color(0xFF1A4371),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 26),
                        Row(
                          children: [
                            Expanded(
                              child: _buildWheel(
                                label: "Hora",
                                controller: _hourController,
                                itemCount: 24,
                                selectedValue: _hour,
                                itemBuilder: (index) => _twoDigits(index),
                                onSelectedItemChanged: (index) {
                                  setState(() => _hour = index);
                                },
                              ),
                            ),
                            Container(
                              width: 34,
                              alignment: Alignment.center,
                              child: const Text(
                                ":",
                                style: TextStyle(
                                  color: Color(0xFF1A4371),
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: _buildWheel(
                                label: "Min",
                                controller: _minuteController,
                                itemCount: _minuteOptions.length,
                                selectedValue: _minuteOptions.indexOf(_minute),
                                itemBuilder: (index) =>
                                    _twoDigits(_minuteOptions[index]),
                                onSelectedItemChanged: (index) {
                                  setState(
                                    () => _minute = _minuteOptions[index],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(
                    context,
                    TimeOfDay(hour: _hour, minute: _minute),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF05A28),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    "USAR ESTA HORA",
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

  Widget _buildWheel({
    required String label,
    required FixedExtentScrollController controller,
    required int itemCount,
    required int selectedValue,
    required String Function(int index) itemBuilder,
    required ValueChanged<int> onSelectedItemChanged,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF1A4371),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FB),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE6EBF2)),
                ),
              ),
              ListWheelScrollView.useDelegate(
                controller: controller,
                itemExtent: 72,
                diameterRatio: 1.45,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: onSelectedItemChanged,
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: itemCount,
                  builder: (context, index) {
                    final selected = index == selectedValue;
                    return Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 150),
                        style: TextStyle(
                          fontSize: selected ? 44 : 28,
                          fontWeight: FontWeight.bold,
                          color: selected
                              ? const Color(0xFF1A4371)
                              : Colors.grey[400],
                        ),
                        child: Text(itemBuilder(index)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
