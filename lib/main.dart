import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

const String workerUrl = "https://halo-vault-bridge.tryvoid.workers.dev";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateViewModel()),
      ],
      child: const ImageRecorderApp(),
    ),
  );
}

class CloudRecording {
  final String key;
  final double sizeInMb;
  final String uploaded;

  CloudRecording({required this.key, required this.sizeInMb, required this.uploaded});

  factory CloudRecording.fromJson(Map<String, dynamic> json) => CloudRecording(
        key: json['key'] ?? "unknown",
        sizeInMb: (json['size'] ?? 0) / 1024 / 1024,
        uploaded: json['uploaded'] ?? "Just now",
      );
}

class AppStateViewModel extends ChangeNotifier {
  bool _isRecording = false;
  File? _selectedImage;
  List<CloudRecording> _cloudHistory = [];
  final ImagePicker _picker = ImagePicker();

  AppStateViewModel() {
    refreshCloudHistory();
  }

  bool get isRecording => _isRecording;
  File? get selectedImage => _selectedImage;
  List<CloudRecording> get cloudHistory => _cloudHistory;

  Future<void> refreshCloudHistory() async {
    try {
      final response = await http.get(Uri.parse(workerUrl));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> objects = data['objects'] ?? [];
        _cloudHistory = objects.map((item) => CloudRecording.fromJson(item)).toList();
        _cloudHistory.sort((a, b) => b.key.compareTo(a.key));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Cloud Sync Error: $e');
    }
  }

  void toggleRecording() async {
    if (_isRecording) {
      final directory = await getApplicationDocumentsDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String localPath = '${directory.path}/temp_rec.mp4';
      
      final file = File(localPath);
      await file.writeAsString("HALO_VIDEO_DATA_$timestamp"); 

      try {
        final uploadUrl = Uri.parse("$workerUrl?key=halo_rec_$timestamp.mp4");
        await http.put(uploadUrl, body: await file.readAsBytes());
        await file.delete(); 
        await refreshCloudHistory();
      } catch (e) {
        debugPrint("Upload failed: $e");
      }
    }
    _isRecording = !_isRecording;
    notifyListeners();
  }

  Future<void> pickImage(BuildContext context) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      _selectedImage = File(image.path);
      notifyListeners();
      if (context.mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const ImagePreviewScreen()));
      }
    }
  }
}

class ImageRecorderApp extends StatelessWidget {
  const ImageRecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Halo Cloud',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
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
      appBar: AppBar(
        title: const Text('HALO CLOUD', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_done_rounded, color: Colors.blueAccent),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CloudVaultScreen())),
          ),
          Switch(
            value: viewModel.isRecording,
            onChanged: (v) => viewModel.toggleRecording(),
            activeTrackColor: Colors.red.withValues(alpha: 0.5),
            activeColor: Colors.red,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_upload_outlined, size: 120, color: Colors.white10),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => viewModel.pickImage(context),
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 60)),
              child: const Text('ADD IMAGE'),
            ),
          ],
        ),
      ),
    );
  }
}

class CloudVaultScreen extends StatelessWidget {
  const CloudVaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AppStateViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('R2 Cloud Vault')),
      body: RefreshIndicator(
        onRefresh: viewModel.refreshCloudHistory,
        child: viewModel.cloudHistory.isEmpty
            ? const Center(child: Text('Cloud is empty. Start recording!'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: viewModel.cloudHistory.length,
                itemBuilder: (context, index) {
                  final item = viewModel.cloudHistory[index];
                  return Card(
                    color: Colors.white.withValues(alpha: 0.05),
                    child: ListTile(
                      leading: const Icon(Icons.video_library, color: Colors.blue),
                      title: Text(item.key, style: const TextStyle(fontSize: 12)),
                      subtitle: Text("${item.sizeInMb.toStringAsFixed(2)} MB"),
                      trailing: const Icon(Icons.verified_user, color: Colors.green, size: 16),
                    ),
                  );
                },
              ),
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
      body: Center(
        child: viewModel.selectedImage != null 
          ? Image.file(viewModel.selectedImage!) 
          : const Text('No selection'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pop(context),
        child: const Icon(Icons.done),
      ),
    );
  }
}
