import 'dart:async';
import 'dart:collection';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:open_route_service/open_route_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_compass/flutter_compass.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

//clase nodo para la creacion de los nodos del grafo
class Nodo {
  final String nombre;
  final LatLng ubicacion;
  Nodo? padre;
  List<Nodo> vecinos;

  Nodo(this.nombre, this.ubicacion, this.vecinos);

  @override
  String toString() {
    return 'Nodo(nombre: $nombre, vecinos: ${vecinos.map((n) => n.nombre).join(', ')})';
  }
}

//clase grafo para los nodos posibles para la creacion de la ruta
class Grafo {
  final List<Nodo> nodos;

  Grafo(this.nodos);

  void agregarNodo(Nodo nodo) {
    nodos.add(nodo);
  }

  void agregarArista(Nodo origen, Nodo destino) {
    origen.vecinos.add(destino);
    destino.vecinos.add(origen);
  }

  @override
  String toString() {
    return 'Grafo(nodos: ${nodos.join(', ')})';
  }
}

List<LatLng> buscarRutaMasCorta(Nodo origen, Nodo destino) {
  // Lista para almacenar las ciudades visitadas
  Set<Nodo> visitadas = {};

  // Cola para almacenar las ciudades por explorar
  Queue<Nodo> cola = Queue<Nodo>();

  // Agregar la ciudad de origen a la cola
  cola.add(origen);

  while (cola.isNotEmpty) {
    // Obtener la siguiente ciudad de la cola
    Nodo actual = cola.removeFirst();

    // Si la ciudad actual es el destino, regresar la ruta
    if (actual == destino) {
      return _reconstruirRuta(actual);
    }

    // Marcar la ciudad actual como visitada
    visitadas.add(actual);

    // Recorrer los vecinos de la ciudad actual
    for (Nodo vecino in actual.vecinos) {
      // Si el vecino no ha sido visitado, agregarlo a la cola
      if (!visitadas.contains(vecino)) {
        vecino.padre = actual;
        cola.add(vecino);
      }
    }
  }

  // Si no se encontró una ruta, regresar una lista vacía
  return [];
}

List<LatLng> _reconstruirRuta(Nodo destino) {
  List<Nodo> ruta = [];

  // Recorrer la ruta desde el destino hasta el origen
  Nodo? actual = destino;
  while (actual != null) {
    ruta.add(actual);
    actual = actual.padre;
  }

  // Invertir la ruta para que el origen esté al principio
  ruta.reversed;
  //solo regresar las coordenadas geograficas
  List<LatLng> points = ruta.map((n) => n.ubicacion).toList();
  return points;
}

class DraggableMarker extends StatelessWidget {
  final LatLng point;
  final Function(LatLng) onDragEnd;
  const DraggableMarker(
      {super.key, required this.point, required this.onDragEnd});

  @override
  Widget build(BuildContext context) {
    return Draggable(
      feedback: IconButton(
        onPressed: () {},
        icon: const Icon(Icons.location_on),
        color: Colors.black,
        iconSize: 45,
      ),
      onDragEnd: (details) {
        onDragEnd(LatLng(details.offset.dy, details.offset.dx));
      },
      child: IconButton(
        onPressed: () {},
        icon: const Icon(Icons.location_on),
        color: Colors.black,
        iconSize: 45,
      ),
    );
  }
}


class _MapScreenState extends State<MapScreen> {
  int layerStateIndex = 0;

  List<LatLng> specificLocations = [];


  String selectedUrlTemplate =
      "https://api.mapbox.com/styles/v1/damanger/clvib0pl6062501pkd0kw6syr/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoiZGFtYW5nZXIiLCJhIjoiY2x2ZWhxeHlvMGEwZjJrdDdrY2Vyd3FiYSJ9.guWHApecB_bW-R9gepkWuQ";

  List<String> layerUrlTemplates = [
    "https://api.mapbox.com/styles/v1/damanger/clvib0pl6062501pkd0kw6syr/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoiZGFtYW5nZXIiLCJhIjoiY2x2ZWhxeHlvMGEwZjJrdDdrY2Vyd3FiYSJ9.guWHApecB_bW-R9gepkWuQ",
    "https://api.mapbox.com/styles/v1/damanger/clvi9eotv05zt01nu5odv3dxn/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoiZGFtYW5nZXIiLCJhIjoiY2x2ZWhxeHlvMGEwZjJrdDdrY2Vyd3FiYSJ9.guWHApecB_bW-R9gepkWuQ",
  ];

  List<Marker> markers = []; // List to store markers

  // Variable para almacenar la dirección del dispositivo
  double _heading = 0.0;

  // Agrega una nueva variable de estado para controlar el modo de trazado
  bool isRouteDrawingMode = false;
  LatLng? myPoint;
  bool isLoading = false;
  bool showAdditionalButtons = false;
  TextEditingController searchController = TextEditingController();
  LatLng? searchLocation;
  late MapController mapController;

  //completar el grafo con los vecinos de cada nodo :

  // Crear las ciudades y sus vecinos

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    // Iniciar la escucha del sensor de brújula
    FlutterCompass.events?.listen((event) {
      setState(() {
        _heading = event.heading ?? 0.0;
      });
    });

    // Crear nodos
    Nodo arad = Nodo('Arad', const LatLng(46.18333, 21.31667), []);
    Nodo zerind = Nodo('Zerind', const LatLng(46.62251, 21.51741), []);
    Nodo oradea = Nodo('Oradea', const LatLng(47.0458, 21.91833), []);
    Nodo sibiu = Nodo('Sibiu', const LatLng(45.8, 24.15), []);
    Nodo fagaras = Nodo('Fagaras', const LatLng(45.85, 24.96667), []);
    Nodo bucharest = Nodo('Bucharest', const LatLng(44.43225, 26.10626), []);
    Nodo pitesti = Nodo('Pitesti', const LatLng(44.85, 24.86667), []);
    Nodo rimnicuVilcea =
    Nodo('Rimnicu Vilcea', const LatLng(45.1, 24.36667), []);
    Nodo timisoara = Nodo('Timisoara', const LatLng(45.75372, 21.22571), []);
    Nodo craiova = Nodo('Craiova', const LatLng(44.31667, 23.8), []);

// Crear grafo
    Grafo? grafo;

// Agregar nodos al grafo
    grafo = Grafo([
      arad,
      zerind,
      oradea,
      sibiu,
      fagaras,
      bucharest,
      pitesti,
      rimnicuVilcea,
      timisoara,
      craiova,
    ]);

    // Agregar aristas
    grafo.agregarArista(arad, zerind);
    grafo.agregarArista(arad, sibiu);
    grafo.agregarArista(arad, timisoara);
    grafo.agregarArista(zerind, arad);
    grafo.agregarArista(zerind, oradea);
    grafo.agregarArista(zerind, sibiu);
    grafo.agregarArista(oradea, zerind);
    grafo.agregarArista(oradea, sibiu);
    grafo.agregarArista(sibiu, arad);
    grafo.agregarArista(sibiu, zerind);
    grafo.agregarArista(sibiu, oradea);
    grafo.agregarArista(sibiu, fagaras);
    grafo.agregarArista(sibiu, rimnicuVilcea);
    grafo.agregarArista(fagaras, sibiu);
    grafo.agregarArista(fagaras, bucharest);
    grafo.agregarArista(bucharest, fagaras);
    grafo.agregarArista(bucharest, pitesti);
    grafo.agregarArista(bucharest, craiova);
    grafo.agregarArista(pitesti, bucharest);
    grafo.agregarArista(pitesti, rimnicuVilcea);
    grafo.agregarArista(rimnicuVilcea, sibiu);
    grafo.agregarArista(rimnicuVilcea, pitesti);
    grafo.agregarArista(rimnicuVilcea, craiova);
    grafo.agregarArista(timisoara, arad);
    grafo.agregarArista(craiova, bucharest);
    grafo.agregarArista(craiova, rimnicuVilcea);

// Buscar la ruta más corta entre Arad y Bucharest
    specificLocations = buscarRutaMasCorta(arad, bucharest);

    if (specificLocations.isNotEmpty) {
      drawRoutes(specificLocations);
      //dibujar las marcas de la ruta

    }
  }


  // Función para ajustar la rotación del mapa a 0°
  void _adjustMapRotation() {
    mapController.rotate(0.0);
  }

  Future<void> determineAndSetPosition() async {
    LocationPermission permission;
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permission denied';
      }
    }
    final Position position = await Geolocator.getCurrentPosition();
    setState(() {
      myPoint = LatLng(position.latitude, position.longitude);
    });
    mapController.move(
        myPoint!, 10); // Accede a mapController después de inicializarlo
  }

  Future<Position> determinePosition() async {
    LocationPermission permission;
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'error';
      }
    }
    return await Geolocator.getCurrentPosition();
  }

  Future<void> searchAndMoveToPlace(String query) async {
    List<Location> locations = await locationFromAddress(query);
    if (locations.isNotEmpty) {
      final LatLng newLocation =
      LatLng(locations[0].latitude, locations[0].longitude);
      setState(() {
        searchLocation = newLocation;
      });
      mapController.move(newLocation, 10);
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error'),
            content:
            const Text('No se encontró ningún lugar con esta búsqueda.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  List listOfPoints = [];
  List<LatLng> points = [];

  Future<List<LatLng>> getCoordinates(LatLng lat1, LatLng lat2) async {
    setState(() {
      isLoading = true;
    });

    final OpenRouteService client = OpenRouteService(
      apiKey: '5b3ce3597851110001cf62481d15c38eda2742818d1b9ff0e510ca77',
    );

    final List<ORSCoordinate> routeCoordinates =
    await client.directionsRouteCoordsGet(
      startCoordinate:
      ORSCoordinate(latitude: lat1.latitude, longitude: lat1.longitude),
      endCoordinate:
      ORSCoordinate(latitude: lat2.latitude, longitude: lat2.longitude),
    );

    final List<LatLng> routePoints = routeCoordinates
        .map((coordinate) => LatLng(coordinate.latitude, coordinate.longitude))
        .toList();

    setState(() {
      isLoading = false;
    });

    return routePoints; // Devuelve las coordenadas calculadas
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: myPoint == null
            ? ElevatedButton(
          onPressed: () {
            determineAndSetPosition();
          },
          child: const Text('Activar localización'),
        )
            : contenidodelmapa(),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const SizedBox(height: 10),
          FloatingActionButton(
            backgroundColor: Colors.blue,
            onPressed: () {
              setState(() {
                showAdditionalButtons = !showAdditionalButtons;
              });
            },
            child: const Icon(Icons.map, color: Colors.white, size: 35),
          ),
        ],
      ),
    );
  }

  Widget contenidodelmapa() {
    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialZoom: 10,
            maxZoom: 20,
            minZoom: 1,
            initialCenter: myPoint!,
            interactionOptions: const InteractionOptions(
                flags: ~InteractiveFlag.doubleTapDragZoom),
          ),
          children: [
            TileLayer(
              urlTemplate: selectedUrlTemplate,
              additionalOptions: const {
                'accessToken':
                'pk.eyJ1IjoiZGFtYW5nZXIiLCJhIjoiY2x2ZWhxeHlvMGEwZjJrdDdrY2Vyd3FiYSJ9.guWHApecB_bW-R9gepkWuQ',
                'id': 'mapbox.mapbox-streets'
              },
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: myPoint!,
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.directions_walk,
                    size: 60,
                    color: Colors.black,
                  ),
                ),
                // Add markers for each coordinate in specificLocations
                for (var point in specificLocations)
                  Marker(
                    point: point,
                    width: 60,
                    height: 60,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 40,// Customize marker color
                    ),
                  ),

              ],
            ),
            PolylineLayer(
              polylineCulling: false,
              polylines: [
                Polyline(
                  points: points,
                  color: Colors.blue,
                  strokeWidth: 5,
                ),
              ],
            ),
          ],
        ),
        Visibility(
          visible: isLoading,
          child: Container(
            color: Colors.black.withOpacity(0.7),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: GestureDetector(
            onTap: () {
              // Ajusta la rotación del mapa cuando se toca la brújula
              _adjustMapRotation();
            },
            child: Transform.rotate(
              angle: ((_heading ?? 0.0) * (3.1415 / 180) * -1),
              child: Image.asset(
                'assets/compass.png', // Ruta de tu ícono personalizado
                width: 100,
                height: 100,
              ),
            ),
          ),
        ),
        if (showAdditionalButtons)
          Positioned(
            bottom: 105,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  backgroundColor: Colors.blue,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Buscar ubicación'),
                          content: TextField(
                            controller: searchController,
                            decoration: const InputDecoration(
                              hintText: 'Ingrese la ubicación',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                searchAndMoveToPlace(searchController.text);
                                Navigator.of(context).pop();
                              },
                              child: const Text('Buscar'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child:
                  const Icon(Icons.search, color: Colors.white, size: 35),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  backgroundColor: Colors.green,
                  onPressed: () {
                    determineAndSetPosition();
                  },
                  child: const Icon(Icons.my_location,
                      color: Colors.white, size: 35),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  backgroundColor: Colors.orange,
                  onPressed: () {
                    // Incrementa el índice de estado y asegúrate de que se ajuste dentro de los límites
                    setState(() {
                      layerStateIndex =
                          (layerStateIndex + 1) % layerUrlTemplates.length;
                    });
                    // Cambia el urlTemplate al valor correspondiente al nuevo estado
                    changeUrlTemplate(layerUrlTemplates[layerStateIndex]);
                  },
                  child:
                  const Icon(Icons.layers, color: Colors.white, size: 35),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Función para cambiar el urlTemplate cuando se presiona el botón "layers"
  void changeUrlTemplate(String newUrlTemplate) {
    setState(() {
      selectedUrlTemplate = newUrlTemplate;
    });
  }

  Future<void> drawRoutes(List<LatLng> specificLocations) async {
    for (int i = 0; i < specificLocations.length - 1; i++) {
      List<LatLng> route =
      await getCoordinates(specificLocations[i], specificLocations[i + 1]);
      points.addAll(route);
    }
  }


}