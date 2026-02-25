import 'package:flutter/material.dart';

class CyberInput extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final IconData icon;
  final Color accent;
  final bool isPassword;
  final Widget? suffixIcon;

  const CyberInput({
    super.key,
    this.controller,
    required this.hint,
    required this.icon,
    required this.accent,
    this.isPassword = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white, letterSpacing: 1),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white12, fontSize: 14),
          prefixIcon: Icon(icon, color: accent.withOpacity(0.7), size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()..color = Colors.white.withOpacity(0.03)..strokeWidth = 1.0;
    for (double i = 0; i < size.width; i += 30) canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    for (double i = 0; i < size.height; i += 30) canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

//By Reogie Mabawad