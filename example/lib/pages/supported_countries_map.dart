import 'dart:convert';

import 'package:countries_world_map/countries_world_map.dart';
import 'package:countries_world_map/data/maps/world_map.dart';
import 'package:flutter/material.dart';

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:countries_world_map/countries_world_map.dart';
import 'package:countries_world_map/data/maps/world_map.dart';

class SupportedCountriesMap extends StatefulWidget {
  const SupportedCountriesMap({Key? key}) : super(key: key);

  @override
  _SupportedCountriesMapState createState() => _SupportedCountriesMapState();
}

class _SupportedCountriesMapState extends State<SupportedCountriesMap>
    with SingleTickerProviderStateMixin {
  // Controller for the InteractiveViewer
  final TransformationController _transformationController =
      TransformationController();

  // Animation controller for smooth transitions
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  // Country selection
  String? selectedCountry;

  // Store country center points
  final Map<String, Offset> _countryCenters = {};

  // Test dropdown
  List<String> _topCountries = [
    'us',
    'ca',
    'gb',
    'fr',
    'de',
    'jp',
    'au',
    'br',
    'ru',
    'in',
    'cn',
    'it',
    'es',
    'mx',
    'kr',
    'sa',
    'za',
    'eg',
    'tr',
    'id',
    'ng'
  ];

  @override
  void initState() {
    super.initState();
    _calculateCountryCenters();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration:
          Duration(milliseconds: 500), // Animation duration - adjust as needed
    );

    _animationController.addListener(() {
      if (_animation != null) {
        _transformationController.value = _animation!.value;
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Calculate center points for common countries
  void _calculateCountryCenters() {
    try {
      Map<String, dynamic> mapData = json.decode(SMapWorld.instructions);
      double width = mapData['w'].toDouble();
      double height = mapData['h'].toDouble();

      List paths = mapData['i'];
      for (var path in paths) {
        try {
          String id = path['u'];
          List<String> instructions = List<String>.from(path['i']);

          // Calculate bounding box
          double minX = double.infinity, minY = double.infinity;
          double maxX = -double.infinity, maxY = -double.infinity;
          int pointCount = 0;

          for (String instruction in instructions) {
            if (instruction.startsWith('m') || instruction.startsWith('l')) {
              List<String> coords = instruction.substring(1).split(',');
              if (coords.length >= 2) {
                double x = double.parse(coords[0]);
                double y = double.parse(coords[1]);

                minX = x < minX ? x : minX;
                minY = y < minY ? y : minY;
                maxX = x > maxX ? x : maxX;
                maxY = y > maxY ? y : maxY;
                pointCount++;
              }
            }
          }

          if (pointCount > 0) {
            // Calculate center point in pixels
            double centerX = (minX + maxX) / 2 * width;
            double centerY = (minY + maxY) / 2 * height;
            _countryCenters[id] = Offset(centerX, centerY);
          }
        } catch (e) {
          print('Error processing country: $e');
        }
      }

      print('Calculated ${_countryCenters.length} country centers');
    } catch (e) {
      print('Error calculating centers: $e');
    }
  }

  // Method to center on a country with animation
  void _centerOnCountry(String countryId) {
    if (!_countryCenters.containsKey(countryId)) {
      print('Country center not found: $countryId');
      return;
    }

    try {
      // Get the build context size
      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final Size viewportSize = renderBox.size;

      // Get the current scale
      final double currentScale =
          _transformationController.value.getMaxScaleOnAxis();

      // Get the center of the country
      final Offset center = _countryCenters[countryId]!;

      // Create a new matrix that preserves scale but centers on the country
      final Matrix4 targetMatrix = Matrix4.identity()
        ..scale(currentScale, currentScale)
        ..translate(
          -center.dx + viewportSize.width / (2 * currentScale),
          -center.dy + viewportSize.height / (2 * currentScale),
        );

      // Create an animation from current to target matrix
      _animation = Matrix4Tween(
        begin: _transformationController.value,
        end: targetMatrix,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut, // Smooth animation curve
      ));

      // Reset and start the animation
      _animationController.reset();
      _animationController.forward();

      print('Animating to country: $countryId, scale: $currentScale');
    } catch (e) {
      print('Error centering country: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main map with InteractiveViewer
          InteractiveViewer(
            transformationController: _transformationController,
            maxScale: 75.0,
            constrained: true,
            child: SimpleMap(
              instructions: SMapWorld.instructions,
              defaultColor: Colors.grey,
              colors: _getCountryColors(),
              countryBorder: CountryBorder(color: Colors.white),
              callback: (id, name, tapDetails) {
                setState(() {
                  selectedCountry = id;
                });
                _centerOnCountry(id);
              },
            ),
          ),

          // Country selector dropdown
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              width: 200,
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Test Country Centering",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  DropdownButton<String>(
                    isExpanded: true,
                    hint: Text('Select a country'),
                    value: selectedCountry,
                    items: _topCountries.map((code) {
                      return DropdownMenuItem(
                        value: code,
                        child: Text(_getCountryName(code)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedCountry = value;
                        });
                        _centerOnCountry(value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // Status text
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: Text(
                  selectedCountry != null
                      ? 'Selected: ${_getCountryName(selectedCountry!)}'
                      : 'Tap a country to center it',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),

          // Zoom controls
          Positioned(
            bottom: 80,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  child: Icon(Icons.add),
                  tooltip: 'Zoom in',
                  onPressed: () {
                    // Create a smooth zoom animation
                    final Matrix4 currentMatrix =
                        _transformationController.value;
                    final double currentScale =
                        currentMatrix.getMaxScaleOnAxis();

                    if (currentScale < 75.0) {
                      final Matrix4 targetMatrix = Matrix4.copy(currentMatrix)
                        ..scale(1.5);

                      _animation = Matrix4Tween(
                        begin: currentMatrix,
                        end: targetMatrix,
                      ).animate(CurvedAnimation(
                        parent: _animationController,
                        curve: Curves.easeInOut,
                      ));

                      _animationController.reset();
                      _animationController.forward();
                    }
                  },
                ),
                SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  child: Icon(Icons.remove),
                  tooltip: 'Zoom out',
                  onPressed: () {
                    // Create a smooth zoom out animation
                    final Matrix4 currentMatrix =
                        _transformationController.value;
                    final double currentScale =
                        currentMatrix.getMaxScaleOnAxis();

                    if (currentScale > 0.2) {
                      final Matrix4 targetMatrix = Matrix4.copy(currentMatrix)
                        ..scale(1 / 1.5);

                      _animation = Matrix4Tween(
                        begin: currentMatrix,
                        end: targetMatrix,
                      ).animate(CurvedAnimation(
                        parent: _animationController,
                        curve: Curves.easeInOut,
                      ));

                      _animationController.reset();
                      _animationController.forward();
                    }
                  },
                ),
              ],
            ),
          ),

          // Go to details button
          if (selectedCountry != null)
            Positioned(
              bottom: 80,
              left: 20,
              child: FloatingActionButton.extended(
                icon: Icon(Icons.map),
                label: Text('View Country'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CountryPage(country: selectedCountry!),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // Get country colors with highlighted selection
  Map<String, Color> _getCountryColors() {
    Map<String, Color> colors = {};
    for (String code in _topCountries) {
      colors[code] = (code == selectedCountry) ? Colors.blue : Colors.green;
    }
    return colors;
  }

  // Convert country code to name
  String _getCountryName(String code) {
    Map<String, String> names = {
      'us': 'United States',
      'ca': 'Canada',
      'gb': 'United Kingdom',
      'fr': 'France',
      'de': 'Germany',
      'jp': 'Japan',
      'au': 'Australia',
      'br': 'Brazil',
      'ru': 'Russia',
      'in': 'India',
      'cn': 'China',
      'it': 'Italy',
      'es': 'Spain',
      'mx': 'Mexico',
      'kr': 'South Korea',
      'sa': 'Saudi Arabia',
      'za': 'South Africa',
      'eg': 'Egypt',
      'tr': 'Turkey',
      'id': 'Indonesia',
      'ng': 'Nigeria',
    };
    return names[code] ?? code.toUpperCase();
  }
}

class CountryPage extends StatefulWidget {
  final String country;

  const CountryPage({required this.country, Key? key}) : super(key: key);

  @override
  _CountryPageState createState() => _CountryPageState();
}

class _CountryPageState extends State<CountryPage> {
  late String state;
  late String instruction;
  late List<Map<String, dynamic>> properties;
  late Map<String, Color?> keyValuesPaires;

  // Add these new fields
  final TransformationController _transformationController =
      TransformationController();
  final GlobalKey _mapKey = GlobalKey();

  @override
  void initState() {
    instruction = getInstructions(widget.country);
    if (instruction != "NOT SUPPORTED") {
      properties = getProperties(instruction);
      properties.sort((a, b) => a['name'].compareTo(b['name']));
      keyValuesPaires = {};
      properties.forEach((element) {
        keyValuesPaires.addAll({element['id']: element['color']});
      });

      state = 'Tap a state, prefecture or province';
    } else {
      state = 'This country is not supported';
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.blue),
        title: Text(
          widget.country.toUpperCase() + ' - ' + state,
          style: TextStyle(color: Colors.blue),
        ),
      ),
      body: instruction == "NOT SUPPORTED"
          ? Center(child: Text("This country is not supported"))
          : Column(
              children: [
                Expanded(
                  child: Row(children: [
                    Expanded(
                        child: Center(
                            child: SimpleMap(
                      defaultColor: Colors.grey.shade300,
                      key: Key(properties.toString()),
                      colors: keyValuesPaires,
                      instructions: instruction,
                      callback: (id, name, tapDetails) {
                        setState(() {
                          state = name;

                          int i = properties
                              .indexWhere((element) => element['id'] == id);

                          properties[i]['color'] =
                              properties[i]['color'] == Colors.green
                                  ? null
                                  : Colors.green;
                          keyValuesPaires[properties[i]['id']] =
                              properties[i]['color'];

                          // Add this line to center the selected state/province
                          centerOnState(id);
                        });
                      },
                    ))),
                    if (MediaQuery.of(context).size.width > 800)
                      SizedBox(
                          width: 320,
                          height: MediaQuery.of(context).size.height,
                          child: Card(
                            margin: EdgeInsets.all(16),
                            elevation: 8,
                            child: ListView(
                              children: [
                                for (int i = 0; i < properties.length; i++)
                                  ListTile(
                                    title: Text(properties[i]['name']),
                                    leading: Container(
                                      margin: EdgeInsets.only(top: 8),
                                      width: 20,
                                      height: 20,
                                      color: properties[i]['color'] ??
                                          Colors.grey.shade300,
                                    ),
                                    subtitle: Text(properties[i]['id']),
                                    onTap: () {
                                      setState(() {
                                        properties[i]['color'] = properties[i]
                                                    ['color'] ==
                                                Colors.green
                                            ? null
                                            : Colors.green;
                                        keyValuesPaires[properties[i]['id']] =
                                            properties[i]['color'];
                                      });
                                    },
                                  )
                              ],
                            ),
                          )),
                  ]),
                ),
                if (MediaQuery.of(context).size.width < 800)
                  SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: Card(
                        margin: EdgeInsets.all(16),
                        elevation: 8,
                        child: ListView(
                          children: [
                            for (int i = 0; i < properties.length; i++)
                              ListTile(
                                title: Text(properties[i]['name']),
                                leading: Container(
                                  margin: EdgeInsets.only(top: 8),
                                  width: 20,
                                  height: 20,
                                  color: properties[i]['color'] ??
                                      Colors.grey.shade300,
                                ),
                                subtitle: Text(properties[i]['id']),
                                onTap: () {
                                  setState(() {
                                    properties[i]['color'] =
                                        properties[i]['color'] == Colors.green
                                            ? null
                                            : Colors.green;
                                    keyValuesPaires[properties[i]['id']] =
                                        properties[i]['color'];
                                  });
                                },
                              )
                          ],
                        ),
                      )),
              ],
            ),
    );
  }

  List<Map<String, dynamic>> getProperties(String input) {
    Map<String, dynamic> instructions = json.decode(input);

    List paths = instructions['i'];

    List<Map<String, dynamic>> properties = [];

    paths.forEach((element) {
      properties.add({
        'name': element['n'],
        'id': element['u'],
        'color': null,
      });
    });

    return properties;
  }

  String getInstructions(String id) {
    switch (id) {
      case 'ar':
        return SMapArgentina.instructions;

      case 'at':
        return SMapAustria.instructions;

      case 'ad':
        return SMapAndorra.instructions;

      case 'ao':
        return SMapAngola.instructions;

      case 'am':
        return SMapArmenia.instructions;

      case 'au':
        return SMapAustralia.instructions;

      case 'az':
        return SMapAzerbaijan.instructions;

      case 'bs':
        return SMapBahamas.instructions;

      case 'bh':
        return SMapBahrain.instructions;

      case 'bd':
        return SMapBangladesh.instructions;

      case 'by':
        return SMapBelarus.instructions;

      case 'be':
        return SMapBelgium.instructions;

      case 'bt':
        return SMapBhutan.instructions;

      case 'bo':
        return SMapBolivia.instructions;

      case 'bw':
        return SMapBotswana.instructions;

      case 'br':
        return SMapBrazil.instructions;

      case 'bn':
        return SMapBrunei.instructions;

      case 'bg':
        return SMapBulgaria.instructions;

      case 'bf':
        return SMapBurkinaFaso.instructions;

      case 'bi':
        return SMapBurundi.instructions;

      case 'ca':
        return SMapCanada.instructions;

      case 'cm':
        return SMapCameroon.instructions;

      case 'cf':
        return SMapCentralAfricanRepublic.instructions;

      case 'cv':
        return SMapCapeVerde.instructions;

      case 'td':
        return SMapChad.instructions;

      case 'cn':
        return SMapChina.instructions;

      case 'ch':
        return SMapSwitzerland.instructions;

      case 'cd':
        return SMapCongoDR.instructions;

      case 'cg':
        return SMapCongoBrazzaville.instructions;

      case 'co':
        return SMapColombia.instructions;

      case 'cr':
        return SMapCostaRica.instructions;

      case 'hr':
        return SMapCroatia.instructions;

      case 'cu':
        return SMapCuba.instructions;

      case 'cl':
        return SMapChile.instructions;

      case 'ci':
        return SMapIvoryCoast.instructions;

      case 'cy':
        return SMapCyprus.instructions;

      case 'cz':
        return SMapCzechRepublic.instructions;

      case 'dk':
        return SMapDenmark.instructions;

      case 'dj':
        return SMapDjibouti.instructions;

      case 'do':
        return SMapDominicanRepublic.instructions;

      case 'ec':
        return SMapEcuador.instructions;

      case 'es':
        return SMapSpain.instructions;

      case 'eg':
        return SMapEgypt.instructions;

      case 'et':
        return SMapEthiopia.instructions;

      case 'sv':
        return SMapElSalvador.instructions;

      case 'ee':
        return SMapEstonia.instructions;

      case 'fo':
        return SMapFaroeIslands.instructions;

      case 'fi':
        return SMapFinland.instructions;

      case 'fr':
        return SMapFrance.instructions;

      case 'gb':
        return SMapUnitedKingdom.instructions;

      case 'ge':
        return SMapGeorgia.instructions;

      case 'de':
        return SMapGermany.instructions;

      case 'gr':
        return SMapGreece.instructions;

      case 'gt':
        return SMapGuatemala.instructions;

      case 'gn':
        return SMapGuinea.instructions;

      case 'hi':
        return SMapHaiti.instructions;

      case 'hk':
        return SMapHongKong.instructions;

      case 'hn':
        return SMapHonduras.instructions;

      case 'hu':
        return SMapHungary.instructions;

      case 'in':
        return SMapIndia.instructions;

      case 'id':
        return SMapIndonesia.instructions;

      case 'il':
        return SMapIsrael.instructions;

      case 'ir':
        return SMapIran.instructions;

      case 'iq':
        return SMapIraq.instructions;

      case 'ie':
        return SMapIreland.instructions;

      case 'it':
        return SMapItaly.instructions;

      case 'jm':
        return SMapJamaica.instructions;

      case 'jp':
        return SMapJapan.instructions;

      case 'kz':
        return SMapKazakhstan.instructions;

      case 'ke':
        return SMapKenya.instructions;

      case 'xk':
        return SMapKosovo.instructions;

      case 'kg':
        return SMapKyrgyzstan.instructions;

      case 'la':
        return SMapLaos.instructions;

      case 'lv':
        return SMapLatvia.instructions;

      case 'li':
        return SMapLiechtenstein.instructions;

      case 'lt':
        return SMapLithuania.instructions;

      case 'lu':
        return SMapLuxembourg.instructions;

      case 'mk':
        return SMapMacedonia.instructions;

      case 'ml':
        return SMapMali.instructions;

      case 'mt':
        return SMapMalta.instructions;

      case 'mz':
        return SMapMozambique.instructions;

      case 'mx':
        return SMapMexico.instructions;

      case 'md':
        return SMapMoldova.instructions;

      case 'me':
        return SMapMontenegro.instructions;

      case 'ma':
        return SMapMorocco.instructions;

      case 'mm':
        return SMapMyanmar.instructions;

      case 'my':
        return SMapMalaysia.instructions;

      case 'na':
        return SMapNamibia.instructions;

      case 'np':
        return SMapNepal.instructions;

      case 'nl':
        return SMapNetherlands.instructions;

      case 'nz':
        return SMapNewZealand.instructions;

      case 'ni':
        return SMapNicaragua.instructions;

      case 'ng':
        return SMapNigeria.instructions;

      case 'no':
        return SMapNorway.instructions;

      case 'om':
        return SMapOman.instructions;

      case 'ps':
        return SMapPalestine.instructions;

      case 'pk':
        return SMapPakistan.instructions;

      case 'ph':
        return SMapPhilippines.instructions;

      case 'pa':
        return SMapPanama.instructions;

      case 'pe':
        return SMapPeru.instructions;

      case 'pr':
        return SMapPuertoRico.instructions;

      case 'py':
        return SMapParaguay.instructions;

      case 'pl':
        return SMapPoland.instructions;

      case 'pt':
        return SMapPortugal.instructions;

      case 'qa':
        return SMapQatar.instructions;

      case 'ro':
        return SMapRomania.instructions;

      case 'ru':
        return SMapRussia.instructions;

      case 'rw':
        return SMapRwanda.instructions;

      case 'sa':
        return SMapSaudiArabia.instructions;

      case 'rs':
        return SMapSerbia.instructions;

      case 'sd':
        return SMapSudan.instructions;

      case 'sg':
        return SMapSingapore.instructions;

      case 'sl':
        return SMapSierraLeone.instructions;

      case 'sk':
        return SMapSlovakia.instructions;

      case 'si':
        return SMapSlovenia.instructions;

      case 'kr':
        return SMapSouthKorea.instructions;

      case 'lk':
        return SMapSriLanka.instructions;

      case 'se':
        return SMapSweden.instructions;

      case 'sy':
        return SMapSyria.instructions;

      case 'tw':
        return SMapTaiwan.instructions;

      case 'tj':
        return SMapTajikistan.instructions;

      case 'th':
        return SMapThailand.instructions;

      case 'tr':
        return SMapTurkey.instructions;

      case 'ug':
        return SMapUganda.instructions;

      case 'ua':
        return SMapUkraine.instructions;

      case 'ae':
        return SMapUnitedArabEmirates.instructions;

      case 'us':
        return SMapUnitedStates.instructions2;

      case 'uy':
        return SMapUruguay.instructions;

      case 'uz':
        return SMapUzbekistan.instructions;

      case 've':
        return SMapVenezuela.instructions;

      case 'vn':
        return SMapVietnam.instructions;

      case 'ye':
        return SMapYemen.instructions;

      case 'za':
        return SMapSouthAfrica.instructions;

      case 'zm':
        return SMapZambia.instructions;

      case 'zw':
        return SMapZimbabwe.instructions;

      default:
        return 'NOT SUPPORTED';
    }
  }

  void centerOnState(String id) {
    void centerOnState(String stateId) {
      try {
        // Get the center of the state by analyzing its path
        Map<String, dynamic> countryData = json.decode(instruction);
        double mapWidth = countryData['w'].toDouble();
        double mapHeight = countryData['h'].toDouble();

        // Find the state's path data
        List paths = countryData['i'];
        List<String>? statePath;

        for (var path in paths) {
          if (path['u'] == stateId) {
            statePath = List<String>.from(path['i']);
            break;
          }
        }

        if (statePath == null) {
          print('State path not found for: $stateId');
          return;
        }

        // Calculate bounds of the state
        double minX = double.infinity;
        double minY = double.infinity;
        double maxX = -double.infinity;
        double maxY = -double.infinity;
        int pointCount = 0;

        for (String instruction in statePath) {
          if (instruction.startsWith('m') || instruction.startsWith('l')) {
            List<String> coords = instruction.substring(1).split(',');
            if (coords.length >= 2) {
              double x = double.parse(coords[0]);
              double y = double.parse(coords[1]);

              minX = x < minX ? x : minX;
              minY = y < minY ? y : minY;
              maxX = x > maxX ? x : maxX;
              maxY = y > maxY ? y : maxY;
              pointCount++;
            }
          }
        }

        if (pointCount > 0) {
          // Calculate center point
          double centerX = (minX + maxX) / 2 * mapWidth;
          double centerY = (minY + maxY) / 2 * mapHeight;

          // Get current scale
          final double currentScale =
              _transformationController.value.getMaxScaleOnAxis();

          // Get viewport size
          final RenderBox? mapBox =
              _mapKey.currentContext?.findRenderObject() as RenderBox?;
          if (mapBox == null) return;

          final Size viewportSize = mapBox.size;

          // Calculate transformation matrix
          final Matrix4 matrix = Matrix4.identity()
            ..scale(currentScale, currentScale)
            ..translate(
              -centerX + viewportSize.width / (2 * currentScale),
              -centerY + viewportSize.height / (2 * currentScale),
            );

          // Apply transformation
          _transformationController.value = matrix;
        }
      } catch (e) {
        print('Error centering on state: $e');
      }
    }
  }
}
