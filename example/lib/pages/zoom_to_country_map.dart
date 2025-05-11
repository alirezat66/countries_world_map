import 'package:flutter/material.dart';
import 'package:countries_world_map/countries_world_map.dart';
import 'package:countries_world_map/src/map_controller.dart';
import 'package:countries_world_map/data/maps/world_map.dart'; // Import SMapWorld
import 'package:countries_world_map/src/painter.dart'; // Import SimpleMapInstruction
import 'dart:convert'; // Required for jsonDecode

class ZoomToCountryMap extends StatefulWidget {
  const ZoomToCountryMap({Key? key}) : super(key: key);

  @override
  _ZoomToCountryMapState createState() => _ZoomToCountryMapState();
}

class _ZoomToCountryMapState extends State<ZoomToCountryMap> with TickerProviderStateMixin {
  final MapController _mapController = MapController(
    selectionColor: Colors.red.withOpacity(0.5), // Example selection color
    selectionBorder: const CountryBorder(
        color: Colors.black, width: 2.0), // Example selection border
  );

  // Example list of country codes to zoom to
  final List<String> _countryCodes = ['US', 'CA', 'GB', 'DE', 'JP', 'AU'];
  String? _selectedCountryCode;

  // Need to parse instructions once to get the list of SimpleMapInstruction
  List<SimpleMapInstruction> _allCountryInstructions = [];
  Size _mapSize = Size.zero; // To store the actual render size of the map

  @override
  void initState() {
    super.initState();
    // Decode instructions and convert to SimpleMapInstruction list
    Map mapData =
        jsonDecode(SMapWorld.instructions); // Use SMapWorld.instructions
    _allCountryInstructions = List<SimpleMapInstruction>.from(
        mapData['i'].map((item) => SimpleMapInstruction.fromJson(item)));
    _applyInitialZoom();
  }
  
  @override
  void dispose() {
    // Dispose the animation controller when the widget is disposed
    _mapController.disposeAnimationController();
    super.dispose();
  }

  // Method to apply initial zoom
  void _applyInitialZoom() {
    // Create a transformation matrix
    Matrix4 transform = Matrix4.identity();

    // Apply a scale factor of 8.0 as requested
    double zoomFactor = 4.0;
    transform.scale(zoomFactor);

    // Center the map
    double translateX = _mapSize.width / 2 * (1 - zoomFactor);
    double translateY = _mapSize.height / 2 * (1 - zoomFactor);
    transform.translate(translateX, translateY);

    // Apply the transformation
    _mapController.setTransform(transform);
    _mapController.notifyListeners();
  }
  
  // Method to zoom in
  void _zoomIn() {
    // Get the current scale from the transformation matrix
    double currentScale = _mapController.currentTransform.getMaxScaleOnAxis();
    
    // Calculate new scale (increase by 25%)
    double newScale = currentScale * 1.25;
    
    // Apply the new scale while maintaining the center point
    _applyZoom(newScale);
  }
  
  // Method to zoom out
  void _zoomOut() {
    // Get the current scale from the transformation matrix
    double currentScale = _mapController.currentTransform.getMaxScaleOnAxis();
    
    // Calculate new scale (decrease by 20%)
    double newScale = currentScale * 0.8;
    
    // Apply the new scale while maintaining the center point
    _applyZoom(newScale);
  }
  
  // Helper method to apply zoom while maintaining the center point
  void _applyZoom(double scale) {
    // Create a transformation matrix
    Matrix4 transform = Matrix4.identity();
    
    // Apply the scale factor
    transform.scale(scale);
    
    // Center the map
    double translateX = _mapSize.width / 2 * (1 - scale);
    double translateY = _mapSize.height / 2 * (1 - scale);
    transform.translate(translateX, translateY);
    
    // Apply the transformation
    _mapController.setTransform(transform);
    _mapController.notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Optionally add an AppBar back if needed with the selector
      // appBar: AppBar(
      //   title: const Text('Zoom to Country Example'),
      // ),
      body: Center(
        // Center the column
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _mapSize = constraints.biggest;
                  return GestureDetector(
                    onPanUpdate: (details) {
                      // Update the transformation matrix based on drag delta
                      Matrix4 transform = Matrix4.identity()
                        ..translate(details.delta.dx, details.delta.dy)
                        ..multiply(_mapController
                            .currentTransform); // Apply translation to current transform
                      _mapController.setTransform(transform);
                    },
                    child: SimpleMap(
                      instructions: SMapWorld.instructions,
                      controller: _mapController,
                      defaultColor: Colors.blueGrey.shade100,
                      fit: BoxFit.cover, // Cover the entire screen
                      colors: const {
                        'US':
                            Colors.green, // Example: color US green by default
                        'CA': Colors
                            .orange, // Example: color CA orange by default
                      },
                      countryBorder: const CountryBorder(
                          color: Colors.blueGrey, width: 0.5),
                      callback: (id, name, tapDetails) {
                        // Highlight the selected country and animate zooming to it
                        _mapController.selectedCountryId = id;
                        _mapController.animatedZoomToCountry(
                            id, _allCountryInstructions, _mapSize, this);
                        print('Tapped on $name ($id)');
                      },
                    ),
                  );
                },
              ),
            ),
            Padding(
              // Add padding around the dropdown
              padding: const EdgeInsets.all(8.0),
              child: DropdownButton<String>(
                hint: const Text('Select a country to zoom'),
                value: _selectedCountryCode,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedCountryCode = newValue;
                    });
                    // Highlight and animate zooming to the selected country
                    _mapController.selectedCountryId = newValue;
                    _mapController.animatedZoomToCountry(
                        newValue, _allCountryInstructions, _mapSize, this);
                  }
                },
                items:
                    _countryCodes.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                        value), // You might want to display country names here
                  );
                }).toList(),
              ),
            ),
            // Optionally add back the Reset button if needed
            // ElevatedButton(
            //   onPressed: () {
            //     setState(() {
            //       _selectedCountryCode = null;
            //     });
            //     _mapController.resetView(); // Reset to world view
            //   },
            //   child: const Text('Reset View'),
            // ),
            const SizedBox(height: 20), // Add some spacing
            
            // Add zoom control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  heroTag: "btn_zoom_out",
                  onPressed: _zoomOut,
                  child: const Icon(Icons.zoom_out),
                  tooltip: 'Zoom Out',
                ),
                const SizedBox(width: 20), // Space between buttons
                FloatingActionButton(
                  heroTag: "btn_zoom_in",
                  onPressed: _zoomIn,
                  child: const Icon(Icons.zoom_in),
                  tooltip: 'Zoom In',
                ),
              ],
            ),
            const SizedBox(height: 20), // Add spacing after buttons
          ],
        ),
      ),
    );
  }
}

// Helper to convert list of dynamic maps to list of SimpleMapInstruction
extension on SimpleMapInstruction {
  static List<SimpleMapInstruction> listFromJson(List<dynamic> jsonList) {
    return jsonList.map((json) => SimpleMapInstruction.fromJson(json)).toList();
  }
}
