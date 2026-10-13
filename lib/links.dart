import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Keep only digits and '+' (for tel: links)
String cleanPhone(String p) => p.replaceAll(RegExp(r'[^0-9+]'), '');

/// WhatsApp needs digits with country code and no '+'. 10-digit numbers get 91 (India).
String waNumber(String phone) {
  var d = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.length == 10) d = '91$d';
  return d;
}

Uri mapsSearchUri(String query) =>
    Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': query});

Uri mapsDirectionsUri(String destination) =>
    Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': destination});

Future<void> openUrl(BuildContext context, Uri uri) async {
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open this link on your device')),
    );
  }
}

Future<void> openWhatsApp(BuildContext context, String phone, String message) =>
    openUrl(context, Uri.parse('https://wa.me/${waNumber(phone)}?text=${Uri.encodeComponent(message)}'));

/// Opens WhatsApp's contact chooser with the text pre-filled
Future<void> shareOnWhatsApp(BuildContext context, String message) =>
    openUrl(context, Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}'));

Future<void> callNumber(BuildContext context, String phone) =>
    openUrl(context, Uri(scheme: 'tel', path: cleanPhone(phone)));

// ---------- small shared UI helpers ----------
Widget statusChip(String label, Color color) => Chip(
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      side: BorderSide(color: color),
      visualDensity: VisualDensity.compact,
    );

Widget actionChip(IconData icon, String label, VoidCallback onTap) => ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
