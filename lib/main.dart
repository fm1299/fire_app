import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'dashboard_screen.dart';
import 'websocket_service.dart';
import 'api_service.dart';

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fire App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const IpConfigScreen(),
    );
  }
}

class IpConfigScreen extends StatefulWidget {
  const IpConfigScreen({super.key});

  @override
  State<IpConfigScreen> createState() => _IpConfigScreenState();
}

class _IpConfigScreenState extends State<IpConfigScreen> {
  final TextEditingController _ipController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedIp();
  }

  Future<void> _loadSavedIp() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('server_ip');
    setState(() {
      _ipController.text = savedIp ?? '34.39.173.82';
      _isLoading = false;
    });
  }

  Future<void> _saveAndProceed() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an IP address')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_ip', ip);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => AppContainer(serverIp: ip)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Configuration'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.wifi, size: 80, color: Colors.deepOrange),
            const SizedBox(height: 20),
            const Text(
              'Enter Server IP Address',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'This will be used for API calls and WebSocket connections.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'Server IP',
                hintText: 'e.g., 192.168.1.100 or 34.39.173.82',
                prefixIcon: Icon(Icons.dns),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _saveAndProceed,
              icon: const Icon(Icons.check),
              label: const Text('Connect'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppContainer extends StatefulWidget {
  final String serverIp;

  const AppContainer({super.key, required this.serverIp});

  @override
  State<AppContainer> createState() => _AppContainerState();
}

class _AppContainerState extends State<AppContainer> {
  late WebSocketService _dashboardWs;
  late WebSocketService _triggerWs;
  late ApiService _apiService;

  @override
  void initState() {
    super.initState();
    _dashboardWs = WebSocketService('ws://${widget.serverIp}/ws/dashboard');
    _triggerWs = WebSocketService('ws://${widget.serverIp}/ws/camera');
    _apiService = ApiService(
      baseUrl: 'http://${widget.serverIp}/api/verify-fire',
    );

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
    return MainScreen(
      dashboardWs: _dashboardWs,
      triggerWs: _triggerWs,
      apiService: _apiService,
    );
  }
}

class MainScreen extends StatefulWidget {
  final WebSocketService dashboardWs;
  final WebSocketService triggerWs;
  final ApiService apiService;

  const MainScreen({
    super.key,
    required this.dashboardWs,
    required this.triggerWs,
    required this.apiService,
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
        apiService: widget.apiService,
      ),
      DashboardScreen(webSocketService: widget.dashboardWs),
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
