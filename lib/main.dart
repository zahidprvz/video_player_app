import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => VideoModel(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(), // Change the theme color to dark
        home: MyApp(),
      ),
    ),
  );
}

class VideoModel extends ChangeNotifier {
  VideoPlayerController? _controller;
  Timer? _hideTimer;
  bool _isVisible = true;

  VideoPlayerController? get controller => _controller;
  bool get isVisible => _isVisible;

  void updateController(VideoPlayerController controller) {
    _controller = controller;
    notifyListeners();
  }

  void seekVideo(Duration duration) {
    _controller?.seekTo(duration);
  }

  void forwardVideo(Duration duration) {
    _controller?.seekTo(_controller!.value.position + duration);
  }

  void backwardVideo(Duration duration) {
    _controller?.seekTo(_controller!.value.position - duration);
  }

  void toggleVisibility() {
    _isVisible = !_isVisible;
    notifyListeners();
    if (!_isVisible) {
      _startHideTimer();
    }
  }

  void _startHideTimer() {
    _hideTimer = Timer(const Duration(seconds: 10), () {
      _isVisible = true;
      notifyListeners();
    });
  }

  void cancelHideTimer() {
    _hideTimer?.cancel();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }
}

class VideoController {
  late VideoModel _model;

  VideoController(this._model);

  Future<void> pickVideo(BuildContext context) async {
    FilePickerResult? result =
    await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null) {
      File file = File(result.files.single.path!);
      VideoPlayerController controller = VideoPlayerController.file(file);
      await controller.initialize();
      controller.setLooping(true);
      _model.updateController(controller);
      controller.play(); // Start playing the video
      Navigator.of(context).push(MaterialPageRoute(builder: (context) {
        return Scaffold(
          body: VideoView(),
        );
      }));
    }
  }

  void togglePlayPause() {
    if (_model.controller!.value.isPlaying) {
      _model.controller!.pause();
    } else {
      _model.controller!.play();
    }
  }

  void rotateScreen(BuildContext context) {
    if (MediaQuery.of(context).orientation == Orientation.landscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
      ]);
    }
  }
}

class VideoView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = Provider.of<VideoModel>(context);
    if (model.controller != null) {
      return GestureDetector(
        onTap: () => model.toggleVisibility(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: <Widget>[
                Center(
                  child: AspectRatio(
                    aspectRatio: model.controller!.value.aspectRatio,
                    child: VideoPlayer(model.controller!),
                  ),
                ),
                AnimatedOpacity(
                  opacity: model.isVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: VideoControls(),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      Navigator.pop(context); // Go back to previous screen
                    },
                  ),
                ),
              ],
            );
          },
        ),
      );
    } else {
      return const Text('No video selected');
    }
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () {
                final videoController = VideoController(
                    Provider.of<VideoModel>(context, listen: false));
                videoController.pickVideo(context);
              },
              child: const Text('Pick a Video'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: VideoView(),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoControls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = Provider.of<VideoModel>(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: model.isVisible ? Colors.black.withOpacity(0.5) : Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: VideoProgressIndicator(
              model.controller!,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              colors: const VideoProgressColors(
                playedColor: Colors.red,
                bufferedColor: Colors.grey,
                backgroundColor: Colors.white,
              ),
              // Adjust the thickness here
              // thickness: 5,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.rotate_left),
                onPressed: () {
                  final videoController = VideoController(
                      Provider.of<VideoModel>(context, listen: false));
                  videoController.rotateScreen(context);
                },
              ),
              IconButton(
                icon: Icon(model.controller!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: () {
                  final videoController = VideoController(Provider.of<VideoModel>(context, listen: false));
                  videoController.togglePlayPause();
                },
              ),
              IconButton(
                icon: const Icon(Icons.replay_10),
                onPressed: () {
                  model.backwardVideo(const Duration(seconds: 10));
                },
              ),
              IconButton(
                icon: const Icon(Icons.forward_10),
                onPressed: () {
                  model.forwardVideo(const Duration(seconds: 10));
                },
              ),
              IconButton(
                icon: const Icon(Icons.stop),
                onPressed: () {
                  if (model.controller!.value.isPlaying) {
                    model.controller!.pause();
                    model.controller!.seekTo(Duration.zero);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}