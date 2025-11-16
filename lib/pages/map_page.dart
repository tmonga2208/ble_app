// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'dart:async';

// class HeatMapPage extends StatefulWidget {
//   const HeatMapPage({Key? key}) : super(key: key);

//   @override
//   State<HeatMapPage> createState() => _HeatMapPageState();
// }

// class _HeatMapPageState extends State<HeatMapPage> {
//   late GoogleMapController _mapController;
//   final Completer<GoogleMapController> _controller = Completer();

//   // Sample data - Replace with your actual pepper spray usage data
//   final List<Map<String, dynamic>> _sprayLocations = [
//     {'lat': 37.7749, 'lng': -122.4194, 'intensity': 5},
//     {'lat': 37.7849, 'lng': -122.4094, 'intensity': 3},
//     {'lat': 37.7649, 'lng': -122.4294, 'intensity': 8},
//     {'lat': 37.7549, 'lng': -122.4394, 'intensity': 2},
//     {'lat': 37.7949, 'lng': -122.3994, 'intensity': 6},
//   ];

//   Set<Circle> _circles = {};
//   Set<Marker> _markers = {};

//   @override
//   void initState() {
//     super.initState();
//     _createHeatMapCircles();
//   }

//   void _createHeatMapCircles() {
//     for (var i = 0; i < _sprayLocations.length; i++) {
//       final location = _sprayLocations[i];
//       final intensity = location['intensity'] as int;

//       // Create circles for heat map effect
//       _circles.add(
//         Circle(
//           circleId: CircleId('circle_$i'),
//           center: LatLng(location['lat'], location['lng']),
//           radius: intensity * 100.0, // Radius based on intensity
//           fillColor: _getHeatColor(intensity).withOpacity(0.3),
//           strokeColor: _getHeatColor(intensity).withOpacity(0.5),
//           strokeWidth: 2,
//         ),
//       );

//       // Add markers
//       _markers.add(
//         Marker(
//           markerId: MarkerId('marker_$i'),
//           position: LatLng(location['lat'], location['lng']),
//           icon: BitmapDescriptor.defaultMarkerWithHue(_getMarkerHue(intensity)),
//           infoWindow: InfoWindow(
//             title: 'Usage Count: $intensity',
//             snippet: 'Tap for details',
//           ),
//         ),
//       );
//     }
//   }

//   Color _getHeatColor(int intensity) {
//     if (intensity >= 7) {
//       return Colors.red;
//     } else if (intensity >= 4) {
//       return Colors.orange;
//     } else {
//       return Colors.yellow;
//     }
//   }

//   double _getMarkerHue(int intensity) {
//     if (intensity >= 7) {
//       return BitmapDescriptor.hueRed;
//     } else if (intensity >= 4) {
//       return BitmapDescriptor.hueOrange;
//     } else {
//       return BitmapDescriptor.hueYellow;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF1C1C1E),
//       appBar: AppBar(
//         title: const Text('Pepper Spray Usage Heat Map'),
//         backgroundColor: Colors.green,
//         foregroundColor: Colors.white,
//         elevation: 0,
//       ),
//       body: Stack(
//         children: [
//           GoogleMap(
//             onMapCreated: (GoogleMapController controller) {
//               _controller.complete(controller);
//               _mapController = controller;
//             },
//             initialCameraPosition: CameraPosition(
//               target: LatLng(37.7749, -122.4194), // San Francisco
//               zoom: 12,
//             ),
//             circles: _circles,
//             markers: _markers,
//             mapType: MapType.normal,
//           ),
//           Positioned(
//             top: 16,
//             right: 16,
//             child: Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: const Color(0xFF1C1C1E),
//                 borderRadius: BorderRadius.circular(8),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.1),
//                     blurRadius: 8,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   const Text(
//                     'Heat Map Legend',
//                     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
//                   ),
//                   const SizedBox(height: 8),
//                   _buildLegendItem(Colors.red, 'High (7+)'),
//                   const SizedBox(height: 4),
//                   _buildLegendItem(Colors.orange, 'Medium (4-6)'),
//                   const SizedBox(height: 4),
//                   _buildLegendItem(Colors.yellow, 'Low (1-3)'),
//                 ],
//               ),
//             ),
//           ),
//           Positioned(
//             bottom: 16,
//             left: 16,
//             right: 16,
//             child: Container(
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: const Color(0xFF1C1C1E),
//                 borderRadius: BorderRadius.circular(12),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.1),
//                     blurRadius: 8,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Row(
//                     children: [
//                       Icon(Icons.info_outline, color: Colors.green, size: 20),
//                       const SizedBox(width: 8),
//                       const Text(
//                         'Usage Statistics',
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           fontSize: 16,
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     'Total activations: ${_sprayLocations.length}',
//                     style: const TextStyle(fontSize: 14),
//                   ),
//                   Text(
//                     'Highest usage area: Downtown',
//                     style: const TextStyle(fontSize: 14),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildLegendItem(Color color, String label) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Container(
//           width: 16,
//           height: 16,
//           decoration: BoxDecoration(
//             color: color.withOpacity(0.5),
//             shape: BoxShape.circle,
//             border: Border.all(color: color, width: 2),
//           ),
//         ),
//         const SizedBox(width: 8),
//         Text(label, style: const TextStyle(fontSize: 12)),
//       ],
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'dart:math' as math;

class HeatMapPage extends StatefulWidget {
  const HeatMapPage({Key? key}) : super(key: key);

  @override
  State<HeatMapPage> createState() => _HeatMapPageState();
}

class _HeatMapPageState extends State<HeatMapPage> {
  // Sample data - Replace with your actual pepper spray usage data
  final List<Map<String, dynamic>> _sprayLocations = [
    {
      'x': 0.25,
      'y': 0.35,
      'intensity': 8,
      'location': 'Connaught Place, Delhi',
    },
    {'x': 0.55, 'y': 0.45, 'intensity': 6, 'location': 'Bandra West, Mumbai'},
    {
      'x': 0.72,
      'y': 0.38,
      'intensity': 4,
      'location': 'Koramangala, Bangalore',
    },
    {'x': 0.35, 'y': 0.68, 'intensity': 7, 'location': 'Park Street, Kolkata'},
    {'x': 0.82, 'y': 0.25, 'intensity': 3, 'location': 'Anna Nagar, Chennai'},
    {'x': 0.62, 'y': 0.75, 'intensity': 5, 'location': 'FC Road, Pune'},
    {'x': 0.45, 'y': 0.58, 'intensity': 6, 'location': 'MG Road, Gurgaon'},
    {'x': 0.18, 'y': 0.48, 'intensity': 2, 'location': 'Sector 17, Chandigarh'},
  ];

  Map<String, dynamic>? _selectedLocation;
  double _zoomLevel = 1.0;

  void _handleTap(Offset position, BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    for (var location in _sprayLocations) {
      final x = location['x'] * size.width;
      final y = location['y'] * size.height;
      final intensity = location['intensity'] as int;
      final radius = intensity * 8.0;

      final distance = math.sqrt(
        math.pow(position.dx - x, 2) + math.pow(position.dy - y, 2),
      );

      if (distance <= radius) {
        setState(() {
          _selectedLocation = location;
        });
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        title: const Text('Pepper Spray Usage Heat Map'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Legend
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF2C2C2E),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem(Colors.red, 'High (7+)'),
                _buildLegendItem(Colors.orange, 'Medium (4-6)'),
                _buildLegendItem(Colors.yellow.shade700, 'Low (1-3)'),
              ],
            ),
          ),

          // Heat Map
          Expanded(
            child: GestureDetector(
              onTapDown: (details) {
                _handleTap(details.localPosition, context);
              },
              onScaleUpdate: (details) {
                setState(() {
                  _zoomLevel = (_zoomLevel * details.scale).clamp(0.5, 3.0);
                });
              },
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        CustomPaint(
                          size: Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          ),
                          painter: HeatMapPainter(
                            _sprayLocations,
                            _selectedLocation,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          // Statistics Panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selectedLocation != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedLocation!['location'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Intensity: ${_selectedLocation!['intensity']}/10',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _selectedLocation = null;
                          });
                        },
                      ),
                    ],
                  ),
                  const Divider(color: Colors.grey, height: 24),
                ],
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Usage Statistics',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Total activations: ${_sprayLocations.length}',
                  style: TextStyle(color: Colors.grey[300], fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Highest usage: ${_getHighestUsageArea()}',
                  style: TextStyle(color: Colors.grey[300], fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withOpacity(0.6),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  String _getHighestUsageArea() {
    if (_sprayLocations.isEmpty) return 'N/A';
    var highest = _sprayLocations.reduce(
      (a, b) => a['intensity'] > b['intensity'] ? a : b,
    );
    return highest['location'];
  }
}

class HeatMapPainter extends CustomPainter {
  final List<Map<String, dynamic>> locations;
  final Map<String, dynamic>? selectedLocation;

  HeatMapPainter(this.locations, this.selectedLocation);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background grid
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= 10; i++) {
      double pos = (size.width / 10) * i;
      canvas.drawLine(Offset(pos, 0), Offset(pos, size.height), gridPaint);
      pos = (size.height / 10) * i;
      canvas.drawLine(Offset(0, pos), Offset(size.width, pos), gridPaint);
    }

    // Draw heat circles
    for (var location in locations) {
      final x = location['x'] * size.width;
      final y = location['y'] * size.height;
      final intensity = location['intensity'] as int;

      // Outer glow
      final glowPaint = Paint()
        ..color = _getHeatColor(intensity).withOpacity(0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      canvas.drawCircle(Offset(x, y), intensity * 15.0, glowPaint);

      // Main circle
      final circlePaint = Paint()
        ..color = _getHeatColor(intensity).withOpacity(0.4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), intensity * 8.0, circlePaint);

      // Border
      final borderPaint = Paint()
        ..color = _getHeatColor(intensity)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(x, y), intensity * 8.0, borderPaint);

      // Center marker
      final markerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 4, markerPaint);

      // Label
      final textPainter = TextPainter(
        text: TextSpan(
          text: '$intensity',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y + intensity * 8.0 + 8),
      );

      // Show location name above circle if selected
      if (selectedLocation != null &&
          selectedLocation!['x'] == location['x'] &&
          selectedLocation!['y'] == location['y']) {
        final locationText = TextPainter(
          text: TextSpan(
            text: location['location'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        );
        locationText.layout(maxWidth: 200);

        // Background for text
        final textBg = Paint()
          ..color = Colors.black.withOpacity(0.7)
          ..style = PaintingStyle.fill;

        final bgRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, y - intensity * 8.0 - 30),
            width: locationText.width + 16,
            height: locationText.height + 8,
          ),
          const Radius.circular(8),
        );

        canvas.drawRRect(bgRect, textBg);

        locationText.paint(
          canvas,
          Offset(
            x - locationText.width / 2,
            y - intensity * 8.0 - 30 - locationText.height / 2 + 4,
          ),
        );
      }
    }
  }

  Color _getHeatColor(int intensity) {
    if (intensity >= 7) {
      return Colors.red;
    } else if (intensity >= 4) {
      return Colors.orange;
    } else {
      return Colors.yellow.shade700;
    }
  }

  @override
  bool shouldRepaint(HeatMapPainter oldDelegate) => true;

  @override
  bool hitTest(Offset position) => true;
}
