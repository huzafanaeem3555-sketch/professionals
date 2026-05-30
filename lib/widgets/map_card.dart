import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';

/// Reusable map card — shows a Google Map with a marker + Get Directions button
class MapCard extends StatefulWidget {
  final double lat;
  final double lng;
  final String title;
  final String? subtitle;
  final double height;

  const MapCard({
    super.key,
    required this.lat,
    required this.lng,
    required this.title,
    this.subtitle,
    this.height = 200,
  });

  @override
  State<MapCard> createState() => _MapCardState();
}

class _MapCardState extends State<MapCard> {
  GoogleMapController? _controller;

  late final CameraPosition _initialPosition;
  late final Set<Marker> _markers;

  @override
  void initState() {
    super.initState();
    _initialPosition = CameraPosition(
      target: LatLng(widget.lat, widget.lng),
      zoom: 14,
    );
    _markers = {
      Marker(
        markerId: const MarkerId('location'),
        position: LatLng(widget.lat, widget.lng),
        infoWindow: InfoWindow(
          title: widget.title,
          snippet: widget.subtitle,
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Map
            SizedBox(
              height: widget.height,
              child: GoogleMap(
                initialCameraPosition: _initialPosition,
                markers: _markers,
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                onMapCreated: (controller) {
                  _controller = controller;
                },
              ),
            ),
            // Bottom bar with Get Directions
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openInGoogleMaps(),
                    icon: const Icon(Icons.directions, size: 16),
                    label: const Text('Directions', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInGoogleMaps() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${widget.lat},${widget.lng}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback: open in browser
      final fallback = Uri.parse(
        'https://maps.google.com/?q=${widget.lat},${widget.lng}',
      );
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
