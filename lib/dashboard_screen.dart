import 'dart:convert';
import 'package:flutter/material.dart';
import 'websocket_service.dart';

class DashboardScreen extends StatefulWidget {
  final WebSocketService webSocketService;

  const DashboardScreen({super.key, required this.webSocketService});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Default values
  double _temp = 0.0;
  double _smoke = 0.0;
  String _status = 'Normal';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IoT Dashboard')),
      body: StreamBuilder(
        stream: widget.webSocketService.stream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            try {
              // Assuming JSON format: {"temp": 25.5, "smoke": 120, "status": "Normal"}
              final data = jsonDecode(snapshot.data.toString());
              if (data is Map) {
                _temp = (data['temp'] ?? 0.0).toDouble();
                _smoke = (data['smoke'] ?? 0.0).toDouble();
                _status = data['status'] ?? 'Unknown';
              }
            } catch (e) {
              print('Error parsing JSON: $e');
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Card
                Card(
                  color: _getStatusColor(_status),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        const Text(
                          'SYSTEM STATUS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _status.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Sensor Grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildSensorCard(
                      'Temperature',
                      '$_temp °C',
                      Icons.thermostat,
                    ),
                    _buildSensorCard('Smoke Level', '$_smoke', Icons.cloud),
                    // Add more sensors here if needed
                  ],
                ),
                const SizedBox(height: 20),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: Text('Waiting for data...')),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'normal':
        return Colors.green;
      case 'risk':
        return Colors.orange;
      case 'fire':
      case 'confirmed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSensorCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Theme.of(context).primaryColor),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
