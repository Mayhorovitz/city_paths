import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart';

class DestinationSearchScreen extends StatelessWidget {
  const DestinationSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F2E9),
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: const Text("Search Destination"),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            Prediction? p = await PlacesAutocomplete.show(
              context: context,
              apiKey: dotenv.env['MAPS_API_KEY']!,
              mode: Mode.overlay,
              language: "en",
              components: [Component(Component.country, "il")],
            );

            if (p != null) {
              final places = GoogleMapsPlaces(
                apiKey: dotenv.env['MAPS_API_KEY']!,
              );
              final detail = await places.getDetailsByPlaceId(p.placeId!);
              final location = detail.result.geometry!.location;

              Navigator.pop(context, {
                "address": detail.result.formattedAddress,
                "latlng": [location.lat, location.lng],
              });
            }
          },
          child: const Text("Search Address"),
        ),
      ),
    );
  }
}
