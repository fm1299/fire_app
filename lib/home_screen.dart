import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';

import 'api_service.dart';
import 'websocket_service.dart';

class HomeScreen extends StatefulWidget {
  final WebSocketService webSocketService;
  final CameraDescription? camera;
  final ApiService apiService;

  const HomeScreen({
    super.key,
    required this.webSocketService,
    this.camera,
    required this.apiService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ApiService _apiService;
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  CameraController? _cameraController;
  StreamSubscription? _wsSubscription;

  File? _imageFile;
  String? _audioPath;
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isUploading = false;
  bool _isAutoMode = false;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService;
    _initializeCamera();
    _listenToWebSocket();
  }

  Future<void> _initializeCamera() async {
    if (widget.camera != null) {
      _cameraController = CameraController(
        widget.camera!,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      try {
        await _cameraController!.initialize();
        if (mounted) setState(() {});
      } catch (e) {
        print('Camera initialization error: $e');
      }
    }
  }

  void _listenToWebSocket() {
    _wsSubscription = widget.webSocketService.stream.listen((message) {
      if (_isAutoMode && message.toString().contains("TRIGGER")) {
        print("Auto-Trigger Received!");
        _performAutoCapture();
      }
    });
  }

  Future<void> _performAutoCapture() async {
    if (_isUploading || _isRecording) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Auto-Capture Triggered!'),
        backgroundColor: Colors.orange,
      ),
    );

    // 1. Capture Image (Hands-Free)
    await _takePicture();

    // 2. Record Audio
    await _startRecording();
    await Future.delayed(const Duration(seconds: 3));
    await _stopRecording();

    // 3. Upload
    await _uploadMedia();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _cameraController?.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Camera Handling
  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showSnackBar('Camera not initialized');
      return;
    }
    if (_cameraController!.value.isTakingPicture) return;

    try {
      final XFile image = await _cameraController!.takePicture();
      if (mounted) {
        setState(() {
          _imageFile = File(image.path);
        });
      }
    } catch (e) {
      _showSnackBar('Error taking picture: $e');
    }
  }

  // Gallery Handling
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e');
    }
  }

  // Audio Handling
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path =
            '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(const RecordConfig(), path: path);

        if (mounted) {
          setState(() {
            _isRecording = true;
            _audioPath = null;
          });
        }
      } else {
        _showSnackBar('Microphone permission not granted');
      }
    } catch (e) {
      _showSnackBar('Error starting record: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _audioPath = path;
        });
      }
    } catch (e) {
      _showSnackBar('Error stopping record: $e');
    }
  }

  Future<void> _playRecording() async {
    try {
      if (_audioPath != null) {
        Source urlSource = DeviceFileSource(_audioPath!);
        await _audioPlayer.play(urlSource);
        setState(() {
          _isPlaying = true;
        });
        _audioPlayer.onPlayerComplete.listen((event) {
          if (mounted) {
            setState(() {
              _isPlaying = false;
            });
          }
        });
      }
    } catch (e) {
      _showSnackBar('Error playing audio: $e');
    }
  }

  Future<void> _stopPlayback() async {
    await _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
    });
  }

  // Upload Handling
  Future<void> _uploadMedia() async {
    if (_imageFile == null && _audioPath == null) {
      _showSnackBar('Please select an image or record audio first.');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    bool success = await _apiService.uploadMedia(
      imageFile: _imageFile,
      audioPath: _audioPath,
      deviceName: "SensorNode_01", // Or retrieve from local storage
    );

    if (mounted) {
      setState(() {
        _isUploading = false;
      });
    }

    if (success) {
      _showSnackBar('Upload Successful!', isError: false);
      if (mounted) {
        setState(() {
          _imageFile = null;
          _audioPath = null;
        });
      }
    } else {
      _showSnackBar('Upload Failed.');
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fire App Media Upload')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Auto Mode Switch
            Card(
              color: _isAutoMode ? Colors.green[100] : null,
              child: SwitchListTile(
                title: const Text('Auto Mode (Listen for Trigger)'),
                subtitle: Text(
                  _isAutoMode
                      ? 'Waiting for fire trigger...'
                      : 'Manual control',
                ),
                value: _isAutoMode,
                onChanged: (val) {
                  setState(() {
                    _isAutoMode = val;
                  });
                },
              ),
            ),
            const SizedBox(height: 10),

            // Camera Preview / Image Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Live Camera / Evidence',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 300,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(color: Colors.grey),
                      ),
                      child: _imageFile != null
                          ? Image.file(_imageFile!, fit: BoxFit.cover)
                          : (_cameraController != null &&
                                    _cameraController!.value.isInitialized
                                ? CameraPreview(_cameraController!)
                                : const Center(
                                    child: Text(
                                      "Camera not initialized",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  )),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _takePicture,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Capture Now'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _pickImageFromGallery,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Audio Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Audio',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_isRecording)
                      const Text(
                        'Recording...',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (_audioPath != null && !_isRecording)
                      const Text(
                        'Audio Recorded',
                        style: TextStyle(color: Colors.green),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        GestureDetector(
                          onLongPress: _startRecording,
                          onLongPressUp: _stopRecording,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_isRecording) {
                                _stopRecording();
                              } else {
                                _startRecording();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isRecording ? Colors.red : null,
                              foregroundColor: _isRecording
                                  ? Colors.white
                                  : null,
                            ),
                            child: Text(_isRecording ? 'Stop' : 'Record'),
                          ),
                        ),
                        if (_audioPath != null)
                          ElevatedButton.icon(
                            onPressed: _isPlaying
                                ? _stopPlayback
                                : _playRecording,
                            icon: Icon(
                              _isPlaying ? Icons.stop : Icons.play_arrow,
                            ),
                            label: Text(_isPlaying ? 'Stop' : 'Play'),
                          ),
                      ],
                    ),
                    const Text(
                      'Tap or Press & Hold to Record',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            // Upload Button
            ElevatedButton(
              onPressed: _isUploading ? null : _uploadMedia,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: _isUploading
                  ? const CircularProgressIndicator()
                  : const Text('Send to Server'),
            ),
          ],
        ),
      ),
    );
  }
}
