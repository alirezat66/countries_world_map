import 'package:flutter/material.dart';
import 'package:countries_world_map/src/map.dart'; // For CountryBorder
import 'package:countries_world_map/src/painter.dart'; // For SimpleMapInstruction
import 'dart:math'; // For min/max calculations
import 'package:vector_math/vector_math_64.dart' as vector_math; // For Vector3

/// A controller for managing the state and view of a SimpleMap widget.
class MapController extends ChangeNotifier {
  Matrix4 _currentTransform = Matrix4.identity();
  String? _selectedCountryId;
  Color _selectionColor;
  CountryBorder _selectionBorder;
  AnimationController? _animationController;

  /// The current transformation matrix applied to the map.
  Matrix4 get currentTransform => _currentTransform;

  /// The unique ID of the currently selected country.
  String? get selectedCountryId => _selectedCountryId;

  /// The fill color for the selected country.
  Color get selectionColor => _selectionColor;

  /// The border style for the selected country.
  CountryBorder get selectionBorder => _selectionBorder;

  /// Creates a MapController.
  ///
  /// [selectionColor] is the fill color for the selected country.
  /// [selectionBorder] is the border style for the selected country.
  MapController({
    Color selectionColor = Colors.blue, // Default selection color
    CountryBorder selectionBorder = const CountryBorder(color: Colors.black, width: 2.0), // Default selection border
  }) : _selectionColor = selectionColor, _selectionBorder = selectionBorder;

  /// Zooms and pans the map to center on the country with the given [countryCode].
  ///
  /// [countryCode] is the code of the country to zoom to (e.g., 'US').
  /// [allCountryInstructions] is the list of drawing instructions for all countries.
  /// [mapSize] is the size of the map canvas.
  void zoomToCountry(String countryCode, List<SimpleMapInstruction> allCountryInstructions, Size mapSize) {
    // Find the country instruction for the given country code.
    // We need to map the countryCode (e.g., 'US') to the uniqueID used in the instructions.
    // Assuming uniqueID matches countryCode for now, but this might need refinement.
    SimpleMapInstruction? targetCountry;
    for (var instruction in allCountryInstructions) {
      if (instruction.uniqueID.toLowerCase() == countryCode.toLowerCase()) {
        targetCountry = instruction;
        break;
      }
    }

    if (targetCountry == null) {
      print('Country with code $countryCode not found.');
      return;
    }

    // Calculate the bounding box of the target country.
    // Coordinates are normalized (0.0 to 1.0) and multiplied by mapSize in the painter.
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (var instruction in targetCountry.instructions) {
      if (instruction.length > 1) {
        List<String> coordinates = instruction.substring(1).split(',');
        if (coordinates.length == 2) {
          double x = double.parse(coordinates[0]);
          double y = double.parse(coordinates[1]);

          minX = min(minX, x);
          minY = min(minY, y);
          maxX = max(maxX, x);
          maxY = max(maxY, y);
        }
      }
    }

    // Calculate the center and size of the bounding box in normalized coordinates.
    double centerX = (minX + maxX) / 2.0;
    double centerY = (minY + maxY) / 2.0;
    double bboxWidth = maxX - minX;
    double bboxHeight = maxY - minY;

    // Calculate the required scale and translation.
    // We want to scale the bounding box to fit within the mapSize, with some padding.
    double padding = 0.1; // 10% padding
    double scaleX = mapSize.width / (bboxWidth * mapSize.width * (1.0 + padding));
    double scaleY = mapSize.height / (bboxHeight * mapSize.height * (1.0 + padding));
    double scale = min(scaleX, scaleY); // Use the smaller scale to fit both dimensions

    // Calculate the translation needed to center the scaled country.
    // The center of the bounding box in pixel coordinates is (centerX * mapSize.width, centerY * mapSize.height).
    // After scaling, this point needs to be moved to the center of the mapSize.
    double translateX = mapSize.width / 2.0 - (centerX * mapSize.width) * scale;
    double translateY = mapSize.height / 2.0 - (centerY * mapSize.height) * scale;

    // Create the transformation matrix.
    _currentTransform = Matrix4.identity()
      ..translate(translateX, translateY)
      ..scale(scale);

    _selectedCountryId = targetCountry.uniqueID;

    notifyListeners();
  }

  /// Sets the current transformation matrix applied to the map.
  void setTransform(Matrix4 transform) {
    _currentTransform = transform;
    notifyListeners();
  }

  /// Resets the map view to the default (world view).
  void resetView() {
    _currentTransform = Matrix4.identity();
    _selectedCountryId = null;
    notifyListeners();
  }

  /// Sets the unique ID of the currently selected country.
  set selectedCountryId(String? countryId) {
    _selectedCountryId = countryId;
    notifyListeners();
  }

  /// Sets the color and border style for the selected country.
  void setSelectedCountryStyle(Color color, CountryBorder border) {
    _selectionColor = color;
    _selectionBorder = border;
    notifyListeners(); // Notify listeners if style change should trigger redraw
  }

  /// Scrolls the map to center on the country with the given [countryCode] without changing the zoom level.
  ///
  /// [countryCode] is the code of the country to scroll to (e.g., 'US').
  /// [allCountryInstructions] is the list of drawing instructions for all countries.
  /// [mapSize] is the size of the map canvas.
  void scrollToCountry(String countryCode, List<SimpleMapInstruction> allCountryInstructions, Size mapSize) {
    // Find the country instruction for the given country code.
    SimpleMapInstruction? targetCountry;
    for (var instruction in allCountryInstructions) {
      if (instruction.uniqueID.toLowerCase() == countryCode.toLowerCase()) {
        targetCountry = instruction;
        break;
      }
    }

    if (targetCountry == null) {
      print('Country with code $countryCode not found.');
      return;
    }

    // Calculate the bounding box of the target country.
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (var instruction in targetCountry.instructions) {
      if (instruction.length > 1) {
        List<String> coordinates = instruction.substring(1).split(',');
        if (coordinates.length == 2) {
          double x = double.parse(coordinates[0]);
          double y = double.parse(coordinates[1]);

          minX = min(minX, x);
          minY = min(minY, y);
          maxX = max(maxX, x);
          maxY = max(maxY, y);
        }
      }
    }

    // Calculate the center of the bounding box in normalized coordinates.
    double centerX = (minX + maxX) / 2.0;
    double centerY = (minY + maxY) / 2.0;

    // Extract the current scale from the transformation matrix
    double currentScale = _currentTransform.getMaxScaleOnAxis();

    // Calculate the translation needed to center the country at the current scale.
    double translateX = mapSize.width / 2.0 - (centerX * mapSize.width) * currentScale;
    double translateY = mapSize.height / 2.0 - (centerY * mapSize.height) * currentScale;

    // Create the transformation matrix that preserves the current scale.
    _currentTransform = Matrix4.identity()
      ..translate(translateX, translateY)
      ..scale(currentScale);

    _selectedCountryId = targetCountry.uniqueID;

    notifyListeners();
  }

  /// Animates scrolling the map to center on the country with the given [countryCode].
  ///
  /// [countryCode] is the code of the country to scroll to (e.g., 'US').
  /// [allCountryInstructions] is the list of drawing instructions for all countries.
  /// [mapSize] is the size of the map canvas.
  /// [vsync] is the TickerProvider for the animation.
  /// [duration] is the duration of the animation (default: 500ms).
  void animatedScrollToCountry(
    String countryCode,
    List<SimpleMapInstruction> allCountryInstructions,
    Size mapSize,
    TickerProvider vsync, {
    Duration duration = const Duration(milliseconds: 500),
  }) {
    // Find the country instruction for the given country code.
    SimpleMapInstruction? targetCountry;
    for (var instruction in allCountryInstructions) {
      if (instruction.uniqueID.toLowerCase() == countryCode.toLowerCase()) {
        targetCountry = instruction;
        break;
      }
    }

    if (targetCountry == null) {
      print('Country with code $countryCode not found.');
      return;
    }

    // Calculate the bounding box of the target country.
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (var instruction in targetCountry.instructions) {
      if (instruction.length > 1) {
        List<String> coordinates = instruction.substring(1).split(',');
        if (coordinates.length == 2) {
          double x = double.parse(coordinates[0]);
          double y = double.parse(coordinates[1]);

          minX = min(minX, x);
          minY = min(minY, y);
          maxX = max(maxX, x);
          maxY = max(maxY, y);
        }
      }
    }

    // Calculate the center of the bounding box in normalized coordinates.
    double centerX = (minX + maxX) / 2.0;
    double centerY = (minY + maxY) / 2.0;

    // Extract the current scale from the transformation matrix
    double currentScale = _currentTransform.getMaxScaleOnAxis();

    // Store the starting transform
    Matrix4 startTransform = Matrix4.copy(_currentTransform);
    
    // Get the current viewport center in world coordinates
    double viewportCenterX = mapSize.width / 2.0;
    double viewportCenterY = mapSize.height / 2.0;
    
    // Calculate the target translation to center the country
    // This needs to account for the current scale
    double targetTranslateX = viewportCenterX - (centerX * mapSize.width) * currentScale;
    double targetTranslateY = viewportCenterY - (centerY * mapSize.height) * currentScale;
    
    // Create a target transform that preserves the current scale and other properties
    Matrix4 targetTransform = Matrix4.copy(startTransform);
    
    // Update only the translation component of the target transform
    targetTransform.setTranslation(vector_math.Vector3(targetTranslateX, targetTranslateY, 0));

    // Dispose the previous animation controller if it exists
    _animationController?.dispose();

    // Create a new animation controller
    _animationController = AnimationController(
      duration: duration,
      vsync: vsync,
    );

    // Create a tween for the animation
    Animation<double> animation = CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    );

    // Add a listener to update the transform during the animation
    _animationController!.addListener(() {
      // Get the current animation value (0.0 to 1.0)
      double t = animation.value;
      
      // Extract translation components from start and target transforms
      vector_math.Vector3 startTranslation = startTransform.getTranslation();
      vector_math.Vector3 targetTranslation = targetTransform.getTranslation();
      
      // Interpolate between start and target translations
      double newX = startTranslation.x + (targetTranslation.x - startTranslation.x) * t;
      double newY = startTranslation.y + (targetTranslation.y - startTranslation.y) * t;
      
      // Create a new transform that preserves all properties from the start transform
      // but updates the translation
      Matrix4 newTransform = Matrix4.copy(startTransform);
      newTransform.setTranslation(vector_math.Vector3(newX, newY, 0));
      
      // Update the current transform
      _currentTransform = newTransform;
      notifyListeners();
    });

    // Set the selected country ID
    _selectedCountryId = targetCountry.uniqueID;

    // Start the animation
    _animationController!.forward();
  }

  /// Disposes the animation controller.
  void disposeAnimationController() {
    _animationController?.dispose();
    _animationController = null;
  }
  
  /// Animates zooming and scrolling to a country with a smooth transition.
  ///
  /// This method handles both zooming and panning in a single animation,
  /// which works better at different zoom levels.
  ///
  /// [countryCode] is the code of the country to zoom to (e.g., 'US').
  /// [allCountryInstructions] is the list of drawing instructions for all countries.
  /// [mapSize] is the size of the map canvas.
  /// [vsync] is the TickerProvider for the animation.
  /// [targetScale] is the desired scale factor (optional, will calculate optimal if not provided).
  /// [duration] is the duration of the animation (default: 500ms).
  void animatedZoomToCountry(
    String countryCode,
    List<SimpleMapInstruction> allCountryInstructions,
    Size mapSize,
    TickerProvider vsync, {
    double? targetScale,
    Duration duration = const Duration(milliseconds: 500),
  }) {
    // Find the country instruction for the given country code
    SimpleMapInstruction? targetCountry;
    for (var instruction in allCountryInstructions) {
      if (instruction.uniqueID.toLowerCase() == countryCode.toLowerCase()) {
        targetCountry = instruction;
        break;
      }
    }

    if (targetCountry == null) {
      print('Country with code $countryCode not found.');
      return;
    }

    // Calculate the bounding box of the target country
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (var instruction in targetCountry.instructions) {
      if (instruction.length > 1) {
        List<String> coordinates = instruction.substring(1).split(',');
        if (coordinates.length == 2) {
          double x = double.parse(coordinates[0]);
          double y = double.parse(coordinates[1]);

          minX = min(minX, x);
          minY = min(minY, y);
          maxX = max(maxX, x);
          maxY = max(maxY, y);
        }
      }
    }

    // Calculate the center and size of the bounding box in normalized coordinates
    double centerX = (minX + maxX) / 2.0;
    double centerY = (minY + maxY) / 2.0;
    double bboxWidth = maxX - minX;
    double bboxHeight = maxY - minY;

    // Calculate the required scale to fit the country in the viewport with padding
    double padding = 0.2; // 20% padding
    double scaleX = mapSize.width / (bboxWidth * mapSize.width * (1.0 + padding));
    double scaleY = mapSize.height / (bboxHeight * mapSize.height * (1.0 + padding));
    double newScale = min(scaleX, scaleY); // Use the smaller scale to fit both dimensions
    
    // Use provided targetScale if specified
    if (targetScale != null) {
      newScale = targetScale;
    }

    // Calculate the translation needed to center the country at the new scale
    double newTranslateX = mapSize.width / 2.0 - (centerX * mapSize.width) * newScale;
    double newTranslateY = mapSize.height / 2.0 - (centerY * mapSize.height) * newScale;

    // Store the starting transform
    Matrix4 startTransform = Matrix4.copy(_currentTransform);
    
    // Get the current scale
    double startScale = startTransform.getMaxScaleOnAxis();
    
    // Get the current translation
    vector_math.Vector3 startTranslation = startTransform.getTranslation();

    // Dispose the previous animation controller if it exists
    _animationController?.dispose();

    // Create a new animation controller
    _animationController = AnimationController(
      duration: duration,
      vsync: vsync,
    );

    // Create a curved animation for a natural feel
    Animation<double> animation = CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    );

    // Add a listener to update the transform during the animation
    _animationController!.addListener(() {
      double t = animation.value;
      
      // Interpolate scale
      double interpolatedScale = startScale + (newScale - startScale) * t;
      
      // Interpolate translation
      double interpolatedX = startTranslation.x + (newTranslateX - startTranslation.x) * t;
      double interpolatedY = startTranslation.y + (newTranslateY - startTranslation.y) * t;
      
      // Create a new transform with the interpolated values
      Matrix4 newTransform = Matrix4.identity();
      newTransform.translate(interpolatedX, interpolatedY);
      newTransform.scale(interpolatedScale);
      
      // Update the current transform
      _currentTransform = newTransform;
      notifyListeners();
    });

    // Set the selected country ID
    _selectedCountryId = targetCountry.uniqueID;

    // Start the animation
    _animationController!.forward();
  }
}
