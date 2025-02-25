import 'package:flutter/material.dart';

ThemeData lightMode = ThemeData(
  brightness: Brightness.light,
  colorScheme: ColorScheme.light(
    primary: Color(0xFF2C5282),          // Rich blue - professional but warm
    secondary: Color(0xFF718096),        // Balanced slate gray
    tertiary: Color(0xFF4299E1),         // Bright blue for accents
    surface: Colors.white,     // Dark slate for text
    onSurface: Color(0xFF2D3748),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFE6F0FF), // Light blue container
    secondaryContainer: Color(0xFFEDF2F7), // Light gray container
    error: Color(0xFFE53E3E),           // Clear red for errors
  ),
  // Enhanced visual hierarchy
  cardTheme: CardTheme(
    color: Colors.white,
    elevation: 2,
  ),
  // Refined text theme
  textTheme: TextTheme(
    headlineLarge: TextStyle(color: Color(0xFF2D3748), fontWeight: FontWeight.bold),
    bodyLarge: TextStyle(color: Color(0xFF4A5568)),
  ),
);

ThemeData darkMode = ThemeData(
  brightness: Brightness.dark,
  colorScheme: ColorScheme.dark(
    primary: Color(0xFF63B3ED),          // Vibrant blue that pops on dark
    secondary: Color(0xFF90CDF4),        // Lighter blue for secondary elements
    tertiary: Color(0xFF4299E1),         // Bright blue for accents
    surface: Color(0xFF2D3748),     // Light gray text
    onSurface: Color(0xFFE2E8F0),
    onPrimary: Color(0xFF1A202C),        // Dark text on primary
    primaryContainer: Color(0xFF2C5282),  // Darker blue container
    secondaryContainer: Color(0xFF2D3748), // Dark slate container
    error: Color(0xFFFC8181),            // Softer red for dark mode
  ),
  
  // Enhanced dark mode cards
  cardTheme: CardTheme(
    color: Color(0xFF2D3748),
    elevation: 3,
  ),

  
  // Refined dark mode text
  textTheme: TextTheme(
    headlineLarge: TextStyle(color: Color(0xFFE2E8F0), fontWeight: FontWeight.bold),
    bodyLarge: TextStyle(color: Color(0xFFCBD5E0)),
  ),
);