import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'home_screen.dart';
import 'dashboard_screen.dart';
import 'websocket_service.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    _cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error initializing camera: $e');
    _cameras = [];
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Replace with your distinct endpoints
  // e.g. 'ws://http://34.39.173.82/dashboard'
  final WebSocketService _dashboardWs = WebSocketService(
    'ws://34.39.173.82/ws/dashboard',
  );

  // e.g. 'ws://10.0.2.2:5000/trigger'
  final WebSocketService _triggerWs = WebSocketService(
    'ws://34.39.173.82/ws/camera',
  );

  @override
  void initState() {
    super.initState();
    _dashboardWs.connect();
    _triggerWs.connect();
  }

  @override
  void dispose() {
    _dashboardWs.disconnect();
    _triggerWs.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fire App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: MainScreen(dashboardWs: _dashboardWs, triggerWs: _triggerWs),
    );
  }
}

class MainScreen extends StatefulWidget {
  final WebSocketService dashboardWs;
  final WebSocketService triggerWs;

  const MainScreen({
    super.key,
    required this.dashboardWs,
    required this.triggerWs,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    final CameraDescription? firstCamera = _cameras.isNotEmpty
        ? _cameras.first
        : null;

    _screens = [
      HomeScreen(
        webSocketService: widget.triggerWs,
        camera: firstCamera,
      ), // Use Trigger WS & Camera
      DashboardScreen(webSocketService: widget.dashboardWs), // Use Dashboard WS
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.cloud_upload),
            label: 'Capture',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
        ],
      ),
    );
  }
}
