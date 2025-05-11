import 'package:flutter/material.dart';
import 'dart:convert';

import '../components/canvas/touch_detector.dart';

import 'painter.dart';
import 'map_controller.dart'; // Import the new controller

/// This is the main widget that will paint the map based on the given insturctions (json).
class SimpleMap extends StatefulWidget {
  final String instructions;

  final CountryBorder? countryBorder;

  /// Default color for all countries. If not provided the default Color will be grey.
  final Color? defaultColor;

  /// This is basically a list of countries and colors to apply different colors to specific countries.
  final Map? colors;

  /// Triggered when a country is tapped.
  /// The first parameter is the isoCode of the country that was tapped.
  /// The second parameter is the TapUpDetails of the tap.
  final void Function(String id, String name, TapUpDetails tapDetails)?
      callback;

  /// This is the BoxFit that will be used to fit the map in the available space.
  /// If not provided the default BoxFit will be BoxFit.contain.
  final BoxFit? fit;

  /// Controller to manage the map's view state and selection.
  final MapController? controller;

  const SimpleMap({
    required this.instructions,
    this.defaultColor,
    this.colors,
    this.callback,
    this.fit,
    this.countryBorder,
    this.controller, // Add the controller parameter
    Key? key,
  }) : super(key: key);

  @override
  _SimpleMapState createState() => _SimpleMapState();
}

class _SimpleMapState extends State<SimpleMap> {
  @override
  void initState() {
    super.initState();
    // Add listener to the controller if provided
    widget.controller?.addListener(_onControllerUpdate);
  }

  @override
  void didUpdateWidget(covariant SimpleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Remove listener from old controller and add to new one if it changes
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onControllerUpdate);
      widget.controller?.addListener(_onControllerUpdate);
    }
  }

  @override
  void dispose() {
    // Remove listener when the widget is disposed
    widget.controller?.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    // Trigger a rebuild when the controller notifies listeners
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    Map map = jsonDecode(widget.instructions);

    double width = double.parse(map['w'].toString());
    double height = double.parse(map['h'].toString());
    List<Map<String, dynamic>> instruction =
        List<Map<String, dynamic>>.from(map['i']);

    // Get the current transform from the controller, default to identity if no controller
    final currentTransform = widget.controller?.currentTransform ?? Matrix4.identity();

    return FittedBox(
      fit: widget.fit ?? BoxFit.contain,
      child: RepaintBoundary(
          child: Transform( // Wrap with Transform
            transform: currentTransform,
            alignment: FractionalOffset.center, // Apply transform from center
            child: CanvasTouchDetector(
                builder: (context) => CustomPaint(
                      isComplex: true,
                      size: Size(width, height),
                      painter: SimpleMapPainter(
                          context: context,
                          instructions: instruction,
                          callback: (id, name, tapdetails) {
                            if (widget.callback != null) {
                              widget.callback!(id, name, tapdetails);
                            }
                          },
                          countryBorder: widget.countryBorder,
                          colors: widget.colors,
                          defaultColor: widget.defaultColor ?? Colors.grey,
                          // Pass selection details to the painter
                          selectedCountryId: widget.controller?.selectedCountryId,
                          selectionColor: widget.controller?.selectionColor ?? Colors.blue, // Use default if controller is null
                          selectionBorder: widget.controller?.selectionBorder ?? const CountryBorder(color: Colors.black, width: 2.0), // Use default if controller is null
                      ),
                    ))))
    );
  }
}

class CountryBorder {
  final Color color;
  final double width;

  const CountryBorder({
    required this.color,
    this.width = 1,
  });
}