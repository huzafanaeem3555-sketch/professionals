import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ProfessionalDetailsScreen extends StatelessWidget {
  const ProfessionalDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    final name = args['name'] ?? args['displayName'] ?? 'Professional';
    final phone = args['phone'] ?? args['phoneNumber'] ?? '';
    final lat = (args['lat'] ?? 0).toDouble();
    final lng = (args['lng'] ?? 0).toDouble();

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phone: $phone', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: LatLng(lat, lng), zoom: 14),
                markers: {Marker(markerId: const MarkerId('p'), position: LatLng(lat, lng))},
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                // Create booking flow: navigate back for now
                Navigator.pop(context);
              },
              child: const Text('Book (creates booking in DB)'),
            ),
          ],
        ),
      ),
    );
  }
}

