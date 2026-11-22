import 'package:flutter/material.dart';

const ink = Color(0xFF2B2257);
const mut = Color(0xFF6A6392);
const pink = Color(0xFFE4648C);
const vio = Color(0xFF7A5AD0);
const lav2 = Color(0xFFEFE8FF);
const lav3 = Color(0xFFE1D6FB);
const lav4 = Color(0xFFC9B9F2);

TextStyle ts(double size, FontWeight w, Color c, {double? height, double ls = 0}) => TextStyle(
    fontFamily: 'Urbanist', fontSize: size, fontWeight: w, color: c, height: height, letterSpacing: ls);

// CSS "160deg" gradient
LinearGradient grad160(Color a, Color b) => LinearGradient(
    begin: const Alignment(-0.34, -0.94), end: const Alignment(0.34, 0.94), colors: [a, b]);

const pinkGrad = LinearGradient(
    begin: Alignment(-0.34, -0.94), end: Alignment(0.34, 0.94), colors: [Color(0xFFEF7FA0), Color(0xFFE0557F)]);
const violetGrad = LinearGradient(
    begin: Alignment(-0.34, -0.94), end: Alignment(0.34, 0.94), colors: [Color(0xFF8A6FE0), Color(0xFF5F43B6)]);

const springCurve = Cubic(0.35, 0.0, 0.1, 1.05);
const easeCurve = Cubic(0.4, 0.0, 0.1, 1.0);
