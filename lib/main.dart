import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final String name;
  final DateTime date;

  RecordingModel({required this.id, required this.name, required this.date});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'date': date.toIso8601String()};

  factory RecordingModel.fromJson(Map<String, dynamic> json) => RecordingModel(
        id: json['id'],
        name: json['name'],
        date: DateTime.parse(json['date']),
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
    final String? historyJson = prefs.getString('halo_history');
    if (historyJson != null) {
      final List<dynamic> decoded = jsonDecode(historyJson);
      _history = decoded.map((item) => RecordingModel.fromJson(item)).toList();
      _history.sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();
    }
  }

  Future<void> _saveHistory() async {
    final String encoded = jsonEncode(_history.map((e) => e.toJson()).toList());
    await prefs.setString('halo_history', encoded);
  }

  void toggleRecording() async {
    if (_isRecording) {
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final newRecord = RecordingModel(
        id: timestamp,
        name: 'HALO SESSION #$timestamp',
        date: DateTime.now(),
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
      debugPrint('Error: $e');
    }
  }

  void deleteRecord(String id) async {
    _history.removeWhere((element) => element.id == id);
    await _saveHistory();
    notifyListeners();
  }
}

class ImageRecorderApp extends StatelessWidget {
  const ImageRecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Halo Elite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
          surface: const Color(0xFF050505),
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
        preferredSize: const Size.fromHeight(80),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              title: const Text('HALO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26, letterSpacing: 4)),
              backgroundColor: Colors.white.withValues(alpha: 0.02),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.history_rounded, color: Colors.white70),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const VaultHistoryScreen())),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: Icon(
                      viewModel.isRecording ? Icons.stop_circle_rounded : Icons.radio_button_checked_rounded,
                      color: viewModel.isRecording ? Colors.redAccent : Colors.white38,
                      size: 32,
                    ),
                    onPressed: () {
                      viewModel.toggleRecording();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text(viewModel.isRecording ? 'Session Recording Active' : 'Session Saved to Vault'),
                          backgroundColor: viewModel.isRecording ? Colors.blueAccent : Colors.indigo,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Aesthetic
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0A0A0A), Color(0xFF000000)],
                ),
              ),
            ),
          ),
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2563EB).withValues(alpha: 0.08),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  const Icon(Icons.auto_awesome_mosaic_rounded, size: 80, color: Colors.blueAccent),
                  const SizedBox(height: 32),
                  const Text(
                    'Elite Capture',
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Add an image to start your visual verification session. Everything is tracked in your private vault.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 16, height: 1.6),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => viewModel.pickImage(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withValues(alpha: 0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'ADD IMAGE',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VaultHistoryScreen extends StatelessWidget {
  const VaultHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AppStateViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('PRIVATE VAULT'), centerTitle: true),
      body: viewModel.history.isEmpty
          ? const Center(child: Text('Vault is currently empty', style: TextStyle(color: Colors.white24)))
          : ListView.builder(
              padding: const EdgeInsets.all(24),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(
                      '${item.date.day}/${item.date.month} at ${item.date.hour}:${item.date.minute}',
                      style: const TextStyle(color: Colors.white24, fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                      onPressed: () => viewModel.deleteRecord(item.id),
                    ),
                  ),
                );
              },
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
                tag: 'halo_image',
                child: viewModel.selectedImage != null
                    ? Image.file(viewModel.selectedImage!, fit: BoxFit.contain)
                    : const Center(child: Text('Empty')),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 32,
            right: 32,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 64),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}
