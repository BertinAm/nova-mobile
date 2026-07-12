import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  /// Get a human-readable description of the user's current location.
  /// Returns null if location cannot be determined.
  Future<String?> describeCurrentLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) {
        return 'You are at coordinates ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}.';
      }

      final p = placemarks.first;
      final parts = <String>[];

      // Build a richly descriptive address for spoken output
      if (p.name != null && p.name!.isNotEmpty && p.name != p.thoroughfare) {
        parts.add(p.name!);
      }
      if (p.thoroughfare != null && p.thoroughfare!.isNotEmpty) {
        final suffix = p.subThoroughfare != null && p.subThoroughfare!.isNotEmpty
            ? '${p.subThoroughfare} ${p.thoroughfare}'
            : p.thoroughfare!;
        parts.add(suffix);
      }
      if (p.subLocality != null && p.subLocality!.isNotEmpty) {
        parts.add(p.subLocality!);
      }
      if (p.locality != null && p.locality!.isNotEmpty) {
        parts.add(p.locality!);
      }
      if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) {
        parts.add(p.administrativeArea!);
      }
      if (p.country != null && p.country!.isNotEmpty) {
        parts.add(p.country!);
      }

      if (parts.isEmpty) {
        return 'You are at coordinates ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}.';
      }

      return 'You are at ${parts.join(', ')}.';
    } catch (e) {
      debugPrint('LocationService error: $e');
      return null;
    }
  }
}
