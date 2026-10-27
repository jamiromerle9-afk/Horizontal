import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';

List<CameraDescription> _cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    _cameras = await availableCameras();
  } catch (e) {
    print('Camera error: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Horizon Lock Camera',
      theme: ThemeData.dark(),
      home: const CameraScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  double _rollAngle = 0.0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.microphone].request();
    _initCamera();
    _initSensors();
  }

  void _initCamera() async {
    if (_cameras.isEmpty) return;
    _controller = CameraController(
      _cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  void _initSensors() {
    _accelSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      double angle = atan2(event.x, event.y);
      setState(() {
        _rollAngle = angle;
      });
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _accelSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -_rollAngle,
            child: Transform.scale(
              scale: 1.3,
              child: Center(
                child: CameraPreview(_controller!),
              ),
            ),
          ),
          Positioned(
            child: Container(
              width: 200,
              height: 2,
              color: (_rollAngle.abs() < 0.05) ? Colors.greenAccent : Colors.white.withOpacity(0.7),
            ),
          ),
          Positioned(
            child: Container(
              width: 2,
              height: 40,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          Positioned(
            top: 50,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Tilt Angle: ${(_rollAngle * 180 / pi).toStringAsFixed(1)}°',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: () async {
                try {
                  final image = await _controller!.takePicture();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Photo saved: ${image.path}')),
                  );
                } catch (e) {
                  print(e);
                }
              },
              child: const Icon(Icons.camera_alt, color: Colors.black, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}

