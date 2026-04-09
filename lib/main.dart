import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateViewModel(prefs)),
      ],
      child: const ImageRecorderApp(),
    ),
  );
}

class RecordingModel {
  final String id;
  final String path;
  final DateTime date;
  final String name;

  RecordingModel({required this.id, required this.path, required this.date, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'path': path, 'date': date.toIso8601String(), 'name': name};

  factory RecordingModel.fromJson(Map<String, dynamic> json) => RecordingModel(
        id: json['id'],
        path: json['path'],
        date: DateTime.parse(json['date']),
        name: json['name'],
      );
}

class AppStateViewModel extends ChangeNotifier {
  final SharedPreferences prefs;
  bool _isRecording = false;
  File? _selectedImage;
  List<RecordingModel> _history = [];
  final ImagePicker _picker = ImagePicker();

  AppStateViewModel(this.prefs) {
    _loadHistory();
  }

  bool get isRecording => _isRecording;
  File? get selectedImage => _selectedImage;
  List<RecordingModel> get history => _history;

  void _loadHistory() {
    final String? historyJson = prefs.getString('recording_history');
    if (historyJson != null) {
      final List<dynamic> decoded = jsonDecode(historyJson);
      _history = decoded.map((item) => RecordingModel.fromJson(item)).toList();
      _history.sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();
    }
  }

  Future<void> _saveHistory() async {
    final String encoded = jsonEncode(_history.map((e) => e.toJson()).toList());
    await prefs.setString('recording_history', encoded);
  }

  void toggleRecording() async {
    if (_isRecording) {
      final directory = await getApplicationDocumentsDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String mockPath = '${directory.path}/recording_$timestamp.mp4';
      
      // In a real build with native code, the file would be written here.
      // For the UI demo, we'll create an empty file if it doesn't exist.
      final file = File(mockPath);
      if (!await file.exists()) {
        await file.create();
      }

      final newRecord = RecordingModel(
        id: timestamp,
        path: mockPath,
        date: DateTime.now(),
        name: 'Session #$timestamp',
      );
      
      _history.insert(0, newRecord);
      await _saveHistory();
    }
    _isRecording = !_isRecording;
    notifyListeners();
  }

  Future<void> pickImage(BuildContext context) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        _selectedImage = File(image.path);
        notifyListeners();
        if (context.mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ImagePreviewScreen()));
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void deleteRecord(String id) async {
    _history.removeWhere((element) => element.id == id);
    await _saveHistory();
    notifyListeners();
  }

  Future<void> downloadRecording(RecordingModel record) async {
    final file = File(record.path);
    if (await file.exists()) {
      await Share.shareXFiles([XFile(record.path)], text: 'Check out my HALO recording!');
    }
  }
}

class ImageRecorderApp extends StatelessWidget {
  const ImageRecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Halo Recorder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
          surface: const Color(0xFF0A0A0A),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AppStateViewModel>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: AppBar(
              title: const Text('HALO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 2)),
              backgroundColor: Colors.black.withValues(alpha: 0.3),
              actions: [
                IconButton(
                  icon: const Icon(Icons.history_rounded, size: 28),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryScreen())),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: viewModel.toggleRecording,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: viewModel.isRecording ? Colors.red.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: viewModel.isRecording ? Colors.red : Colors.white24),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            viewModel.isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
                            color: viewModel.isRecording ? Colors.red : Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            viewModel.isRecording ? 'REC' : 'IDLE',
                            style: TextStyle(
                              color: viewModel.isRecording ? Colors.red : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.8, -0.6),
            radius: 1.2,
            colors: [Color(0xFF1E3A8A), Color(0xFF0A0A0A)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Spacer(),
                const Icon(Icons.blur_on_rounded, size: 100, color: Colors.blueAccent),
                const SizedBox(height: 32),
                const Text('Elite Experience', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text(
                  'Your captures are now tracked and saved locally in your private history vault.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16, height: 1.5),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => viewModel.pickImage(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 64),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    elevation: 20,
                    shadowColor: Colors.blue.withValues(alpha: 0.4),
                  ),
                  child: const Text('ADD IMAGE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AppStateViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Vault History'), backgroundColor: Colors.transparent),
      body: viewModel.history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.white.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  Text('No recordings yet', style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: viewModel.history.length,
              itemBuilder: (context, index) {
                final item = viewModel.history[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.videocam_rounded, color: Colors.blueAccent),
                    ),
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${item.date.day}/${item.date.month} • ${item.date.hour}:${item.date.minute}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_circle_outline_rounded, color: Colors.greenAccent),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => VideoPlayerScreen(videoPath: item.path)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.download_rounded, color: Colors.white70),
                          onPressed: () => viewModel.downloadRecording(item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                          onPressed: () => viewModel.deleteRecord(item.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String videoPath;
  const VideoPlayerScreen({super.key, required this.videoPath});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Playback'), backgroundColor: Colors.transparent),
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(_controller),
                    VideoProgressIndicator(_controller, allowScrubbing: true),
                    Positioned(
                      bottom: 20,
                      child: FloatingActionButton(
                        mini: true,
                        onPressed: () {
                          setState(() {
                            _controller.value.isPlaying ? _controller.pause() : _controller.play();
                          });
                        },
                        child: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
                      ),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}

class ImagePreviewScreen extends StatelessWidget {
  const ImagePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AppStateViewModel>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              child: Hero(
                tag: 'selected_image',
                child: viewModel.selectedImage != null
                    ? Image.file(viewModel.selectedImage!, fit: BoxFit.contain)
                    : const Center(child: Text('No image found')),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  color: Colors.white.withValues(alpha: 0.05),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Visual Verified', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
