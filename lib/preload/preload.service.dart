import 'dart:developer';
import 'dart:isolate';

import 'package:video_player/video_player.dart';

import '../api.service.dart';
import '../constants.dart';
import 'background.service.dart';
import 'preload.state.dart';

typedef UpdateState = void Function(PreloadState state);

class PreloadService {
  static const _tag = 'PreloadService:';

  static Future<void> playNext({
    required int index,
    required PreloadState state,
    required UpdateState updateState,
  }) async {
    /// Play current video (already initialized)
    await playControllerAtIndex(
      index: index,
      state: state,
    );

    /// Stop [index - 1] controller
    await _stopControllerAtIndex(index: index - 1, state: state);

    /// Dispose [index - 2] controller
    _disposeControllerAtIndex(
      index: index - 2,
      state: state,
      updateState: updateState,
    );

    /// Initialize [index + 1] controller
    await initializeControllerAtIndex(
      index: index + 1,
      state: state,
      updateState: updateState,
    );
  }

  static Future<void> playPrevious({
    required int index,
    required PreloadState state,
    required UpdateState updateState,
  }) async {
    /// Play current video (already initialized)
    await playControllerAtIndex(
      index: index,
      state: state,
    );

    /// Stop [index + 1] controller
    await _stopControllerAtIndex(
      index: index + 1,
      state: state,
    );

    /// Dispose [index + 2] controller
    _disposeControllerAtIndex(
      index: index + 2,
      state: state,
      updateState: updateState,
    );

    /// Initialize [index - 1] controller
    await initializeControllerAtIndex(
      index: index - 1,
      state: state,
      updateState: updateState,
    );
  }

  static Future<void> initializeControllerAtIndex({
    required int index,
    required PreloadState state,
    required UpdateState updateState,
  }) async {
    if (state.urls.length > index && index >= 0) {
      final url = state.urls[index];

      /// Create new controller
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));

      /// Add controller to state
      updateState(
        state.copyWith(
          controllers: {
            ...state.controllers,
            index: controller,
          },
        ),
      );

      /// Initialize
      await controller.initialize();

      log('$_tag initialized $index');
    }
  }

  static Future<void> playControllerAtIndex({
    required int index,
    required PreloadState state,
  }) async {
    if (state.urls.length > index && index >= 0) {
      await state.controllers[index]!.play();

      log('$_tag playing $index for ${state.urls[index]}');
    }
  }

  static Future<void> _stopControllerAtIndex({
    required int index,
    required PreloadState state,
  }) async {
    if (state.urls.length > index && index >= 0) {
      final controller = state.controllers[index];

      await controller?.pause();
      if (controller?.value.duration != null) {
        await controller?.seekTo(const Duration());
      }

      log('$_tag stopped $index');
    }
  }

  static void _disposeControllerAtIndex({
    required int index,
    required PreloadState state,
    required UpdateState updateState,
  }) {
    if (state.urls.length > index && index >= 0) {
      /// Get controller at [index]
      final controller = state.controllers[index];

      /// Dispose controller
      controller?.dispose();

      if (controller != null) {
        /// Remove controller from state
        updateState(
          state.copyWith(
            controllers: {
              ...state.controllers,
            }..remove(index),
          ),
        );
      }

      log('$_tag disposed $index');
    }
  }

  /// Isolate to fetch videos in the background so that the video experience is not disturbed.
  /// Without isolate, the video will be paused whenever there is an API call
  /// because the main thread will be busy fetching new video URLs.
  ///
  /// https://blog.codemagic.io/understanding-flutter-isolates/
  static Future<void> createIsolate(int index) async {
    // Set loading to true
    BackgroundService.getProducerForTask('loading')?.send(true);

    ReceivePort mainReceivePort = ReceivePort();

    Isolate.spawn<SendPort>(_getVideosTask, mainReceivePort.sendPort);

    SendPort isolateSendPort = await mainReceivePort.first;

    ReceivePort isolateResponseReceivePort = ReceivePort();

    isolateSendPort.send([index, isolateResponseReceivePort.sendPort]);

    final isolateResponse = await isolateResponseReceivePort.first;

    BackgroundService.getProducerForTask('videos')?.send(isolateResponse);
  }

  static void _getVideosTask(SendPort mySendPort) async {
    ReceivePort isolateReceivePort = ReceivePort();

    mySendPort.send(isolateReceivePort.sendPort);

    await for (final message in isolateReceivePort) {
      if (message is List) {
        final int index = message[0];

        final SendPort isolateResponseSendPort = message[1];

        final urls = await ApiService.getVideos(id: index + kPreloadLimit);

        isolateResponseSendPort.send(urls);
      }
    }
  }
}
