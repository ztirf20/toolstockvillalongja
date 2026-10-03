import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final NumberFormat money = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
final DateFormat dateTimeFmt = DateFormat('MMM d, y • h:mm a');

const List<String> kCategories = [
  'Hand Tools',
  'Power Tools',
  'Fasteners',
  'Building Materials',
  'Electrical',
  'Plumbing',
  'Paint & Supplies',
  'Safety Gear',
  'Other',
];

const List<String> kUnits = [
  'pcs',
  'box',
  'pack',
  'set',
  'pair',
  'roll',
  'bag',
  'kg',
  'm',
  'liter',
];

String greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

String initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String dayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('EEE, MMM d, y').format(d);
}

IconData categoryIcon(String category) => switch (category) {
      'Hand Tools' => Icons.hardware,
      'Power Tools' => Icons.power,
      'Fasteners' => Icons.settings,
      'Building Materials' => Icons.foundation,
      'Electrical' => Icons.electrical_services,
      'Plumbing' => Icons.plumbing,
      'Paint & Supplies' => Icons.format_paint,
      'Safety Gear' => Icons.health_and_safety,
      _ => Icons.inventory_2,
    };