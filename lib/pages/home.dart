import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:search_map_place/search_map_place.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:location/location.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'dart:async';

const String API_KEY = "AIzaSyDXGO1N3TwHtDryEvkzQToOkg1F0bP_020";

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  LocationData _currentLocation;
  LocationData _destinationLocation;
  Location _location;
  GoogleMapController _mapController;
  Set<Marker> _markers = Set<Marker>();
  Set<Polyline> _polylines = Set<Polyline>();
  BitmapDescriptor _currentBitmap;
  BitmapDescriptor _destinationBitmap;
  String _typeName = "Normal";

  @override
  void initState() {
    super.initState();
    _location = Location();
  }

  @override
  Widget build(BuildContext context) {
    MapType _mapType = MapType.normal;
    if(_typeName == 'Hybrid')
      _mapType = MapType.hybrid;
    return Scaffold(
      body: FutureBuilder<bool>(
        future: _start(),
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          if (snapshot.hasData) {
            return SafeArea(
              child: Stack(
                children: <Widget>[
                  GoogleMap(
                    onMapCreated: _onMapCreated,
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        _currentLocation.latitude,
                        _currentLocation.longitude
                      ),
                      zoom: 17.5,
                    ),
                    markers: _markers,
                    polylines: _polylines,
                    compassEnabled: true,
                    mapType: _mapType,
                  ),
                  Positioned(
                    top: 10,
                    right: 15,
                    left: 15,
                    child: Row(
                      children: <Widget>[
                        SearchMapPlaceWidget(
                          apiKey: API_KEY,
                          language: "pt-BR",
                          onSelected: (Place place) => setDestination(place),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          } else if (snapshot.hasError) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget> [
                Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 60,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text('Error: ${snapshot.error}'),
                )
              ],
            );
          } else {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget> [
                  SizedBox(
                    child: CircularProgressIndicator(),
                    width: 60,
                    height: 60,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text('Awaiting location...'),
                  )
                ],
              ),
            );
          }
        },
      ),
      floatingActionButton: SpeedDial(
        marginRight: 68,
        marginBottom: 20,
        animatedIcon: AnimatedIcons.menu_close,
        animatedIconTheme: IconThemeData(size: 22.0),
        overlayColor: Colors.black,
        overlayOpacity: 0.5,
        heroTag: 'speed-dial-hero-tag',
        elevation: 8.0,
        shape: CircleBorder(),
        children: [
          SpeedDialChild(
            child: Icon(Icons.directions_car),
            backgroundColor: Colors.orange,
            label: 'Current',
            onTap: () => centerMap(_currentLocation),
          ),
          SpeedDialChild(
            child: Icon(Icons.done),
            backgroundColor: Colors.orange,
            label: 'Destination',
            onTap: () => centerMap(_destinationLocation),
          ),
          SpeedDialChild(
            child: Icon(Icons.satellite),
            backgroundColor: Colors.green,
            label: 'Satellite',
            onTap: () => setState(() =>_typeName = "Hybrid"),
          ),
          SpeedDialChild(
            child: Icon(Icons.directions),
            backgroundColor: Colors.green,
            label: 'Normal',
            onTap: () => setState(() =>_typeName = "Normal"),
          ),
        ],
      ),
    );
  }

  Future <bool> _start() async {
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;
    _currentBitmap = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: 2.0), 'assets/images/driving_pin.png');
    _destinationBitmap  = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: 2.0), 'assets/images/destination_pin.png');
    _serviceEnabled = await _location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await _location.requestService();
      if (!_serviceEnabled)
        return Future<bool>.error("Service not enabled");
    }
    _permissionGranted = await _location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await _location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted)
        return Future<bool>.error("Permission denied");
    }
    _currentLocation = await _location.getLocation();
    addMark("current", _currentLocation);
    print("Current ${_currentLocation}");
    return true;
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void setDestination(Place place) async {
    final geolocation = await place.geolocation;
    _destinationLocation = LocationData.fromMap({
      "latitude": geolocation.coordinates.latitude,
      "longitude": geolocation.coordinates.longitude
    });
    print("Destination ${_destinationLocation}");
    setRoute();
    setState(() => addMark("destination", _destinationLocation));
    centerMap(_destinationLocation);
  }

  void addMark(String _tag, LocationData _markLocation) {
    BitmapDescriptor _bitmap;
    _markers.removeWhere((m) => m.markerId.value == _tag);
    Icon _icon;
    if (_tag == "current")
      _bitmap = _currentBitmap;
    else
      _bitmap = _destinationBitmap;
    _markers.add(Marker(
      markerId: MarkerId(_tag),
      position: LatLng(_markLocation.latitude, _markLocation.longitude),
      icon: _bitmap)
    );
  }

  void centerMap(LocationData _point) {
    if (_point != null) {
      _mapController.animateCamera(
        CameraUpdate.newLatLng(LatLng(_point.latitude, _point.longitude))
      );
    }
  }

  void setRoute() async {
    List<LatLng> _points = List<LatLng>();
    PolylinePoints polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      API_KEY,
      PointLatLng(_currentLocation.latitude, _currentLocation.longitude),
      PointLatLng(_destinationLocation.latitude, _destinationLocation.longitude)
    );
    result.points.forEach((PointLatLng point){
      _points.add(LatLng(point.latitude, point.longitude));
    });
    _polylines.clear();
    _polylines.add(Polyline(
      polylineId: PolylineId('route'),
      visible: true,
      points: _points,
      color: Colors.red,
    ));
  }
}
