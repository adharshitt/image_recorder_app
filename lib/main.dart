import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateViewModel()),
      ],
      child: const ImageRecorderApp(),
    ),
  );
}

class AppStateViewModel extends ChangeNotifier {
  bool _isRecording = false;
  String? _selectedImagePath;

  bool get isRecording => _isRecording;
  String? get selectedImagePath => _selectedImagePath;

  void toggleRecording() {
    _isRecording = !_isRecording;
    notifyListeners();
  }

  void setImage(String path) {
    _selectedImagePath = path;
    notifyListeners();
  }
}

class ImageRecorderApp extends StatelessWidget {
  const ImageRecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Implementing flutter-theming-apps: Material 3, Seed Color, Adaptive Theme
    return MaterialApp(
      title: 'Halo Recorder',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB), // Primary Vibrant Blue from UI-UX-Pro-Max
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarThemeData(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// flutter-building-layouts: Responsive and clean layout handling constraints
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AppStateViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Halo Image Recorder', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(
              viewModel.isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
              color: viewModel.isRecording ? Colors.red : Colors.grey,
            ),
            onPressed: () {
              viewModel.toggleRecording();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(viewModel.isRecording ? 'Recording Started' : 'Recording Stopped & Saved')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0), // 8dp rhythm
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image, size: 64, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(
                        'Select an image to preview',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  // Simulate image selection
                  viewModel.setImage('assets/references/sample.png');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ImagePreviewScreen()),
                  );
                },
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Add Image'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16), // 44pt touch target minimum
                ),
              ),
              const SizedBox(height: 16),
              if (viewModel.isRecording)
                OutlinedButton.icon(
                  onPressed: viewModel.toggleRecording,
                  icon: const Icon(Icons.save),
                  label: const Text('Stop & Save Recording'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
            ],
          ),
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
      appBar: AppBar(
        title: const Text('Image Preview'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: viewModel.selectedImagePath != null 
                          ? const Icon(Icons.photo, size: 120) // Placeholder for actual Image.asset()
                          : const Text('No image selected'),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Done'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
