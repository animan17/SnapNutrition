import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CommonAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      centerTitle: true,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Snap',
            style: GoogleFonts.raleway(
              textStyle: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.blue,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Text(
            'Nutrition',
            style: GoogleFonts.raleway(
              textStyle: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w300,
                color: Colors.black87,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade200,
                Colors.blue.shade400,
                Colors.blue.shade600,
              ],
            ),
          ),
          height: 2.0,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}