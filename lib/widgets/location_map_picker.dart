import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Tap/drag map to pick professional location.
class LocationMapPicker extends StatefulWidget {
  final double lat;
  final double lng;
  final ValueChanged<LatLng> onLocationChanged;

  const LocationMapPicker({
    super.key,
    required this.lat,
    required this.lng,
    required this.onLocationChanged,
  });

  @override
  State<LocationMapPicker> createState() => _LocationMapPickerState();
}

class _LocationMapPickerState extends State<LocationMapPicker> {
  GoogleMapController? _controller;
  late LatLng _position;

  @override
  void initState() {
    super.initState();
    _position = LatLng(
      widget.lat != 0 ? widget.lat : 31.5204,
      widget.lng != 0 ? widget.lng : 74.3587,
    );
  }

  @override
  void didUpdateWidget(LocationMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lat != oldWidget.lat || widget.lng != oldWidget.lng) {
      if (widget.lat != 0 || widget.lng != 0) {
        _position = LatLng(widget.lat, widget.lng);
        _controller?.animateCamera(CameraUpdate.newLatLng(_position));
      }
    }
  }

  void _updatePosition(LatLng pos) {
    setState(() => _position = pos);
    widget.onLocationChanged(pos);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 220,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: _position, zoom: 15),
          onMapCreated: (c) => _controller = c,
          markers: {
            Marker(
              markerId: const MarkerId('selected'),
              position: _position,
              draggable: true,
              onDragEnd: _updatePosition,
            ),
          },
          onTap: _updatePosition,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: false,
        ),
      ),
    );
  }
}
