import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_floating_window/flutter_floating_window.dart';
import 'package:media_projection_screenshot/media_projection_screenshot.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui' as ui;

class FloatingScreenshotWidget extends StatefulWidget {
  const FloatingScreenshotWidget({super.key});

  @override
  State<FloatingScreenshotWidget> createState() => _FloatingScreenshotWidgetState();
}

class _FloatingScreenshotWidgetState extends State<FloatingScreenshotWidget> {
  String? _windowId;
  bool _isCapturing = false;
  final _manager = FloatingWindowManager.instance;

  @override
  void initState() {
    super.initState();
    _initFloatingWindow();
  }

  Future<void> _initFloatingWindow() async {
    // Check and request overlay permission
    var hasPermission = await _manager.hasOverlayPermission();
    if (!hasPermission) {
      hasPermission = await _manager.requestOverlayPermission();
    }
    if (!hasPermission) {
      debugPrint('[TrackOS] 浮窗权限被拒绝');
      return;
    }

    // Listen for window click events
    _manager.eventStream.listen(_handleWindowEvent);

    // Create the floating window
    final config = FloatingWindowConfig(
      width: 60,
      height: 60,
      title: 'TrackOS 截图',
      isDraggable: true,
      isResizable: false,
      showCloseButton: false,
      stayOnTop: true,
      opacity: 0.8,
      backgroundColor: Colors.blue.value,
      cornerRadius: 30.0,
      initialX: null,
      initialY: 200,
    );

    _windowId = await _manager.createWindow(config);
    debugPrint('[TrackOS] 浮窗已创建: $_windowId');
  }

  void _handleWindowEvent(FloatingWindowEvent event) {
    if (event.windowId != _windowId) return;

    if (event.type == FloatingWindowEventType.windowClicked) {
      _captureAndUploadScreenshot();
    }
  }

  Future<void> _captureAndUploadScreenshot() async {
    if (_isCapturing) return;
    _isCapturing = true;

    try {
      // Get screen size using Flutter's low-level API
      final screenSize = PlatformDispatcher.instance.views.first.physicalSize;
      final devicePixelRatio = PlatformDispatcher.instance.views.first.devicePixelRatio;

      final screenshotPlugin = MediaProjectionScreenshot();
      final result = await screenshotPlugin.takeCapture(
        x: 0,
        y: 0,
        width: screenSize.width.toInt(),
        height: screenSize.height.toInt(),
      );

      if (result != null) {
        // Convert raw bytes to JPG format
        final image = img.decodeImage(result);
        if (image != null) {
          final jpgData = img.encodeJpg(image, quality: 85);

          // Save to file with timestamp
          final appDir = await getApplicationDocumentsDirectory();
          final screenshotsDir = Directory('${appDir.path}/screenshots');
          if (!await screenshotsDir.exists()) {
            await screenshotsDir.create(recursive: true);
          }

          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final filePath = '${screenshotsDir.path}/screenshot_$timestamp.jpg';
          await File(filePath).writeAsBytes(jpgData);

          debugPrint('[TrackOS] 截图已保存: $filePath');

          // Upload to server
          await _uploadScreenshot(filePath);
        }
      }
    } catch (e) {
      debugPrint('[TrackOS] 截图失败: $e');
    } finally {
      _isCapturing = false;
    }
  }

  Future<void> _uploadScreenshot(String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverUrl =
          prefs.getString('server_url') ?? 'https://track-api.rethinkos.com';

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: 'screenshot.jpg',
        ),
      });

      final response = await Dio().post(
        '$serverUrl/api/screenshots/upload',
        data: formData,
      );

      if (response.statusCode == 200) {
        debugPrint('[TrackOS] 截图上传成功');
        // Optionally delete local file after successful upload
        await File(filePath).delete();
      } else {
        debugPrint('[TrackOS] 截图上传失败: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[TrackOS] 上传失败: $e');
    }
  }

  @override
  void dispose() {
    if (_windowId != null) {
      _manager.closeWindow(_windowId!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // Invisible in main app UI
  }
}
