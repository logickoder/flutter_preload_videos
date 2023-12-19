import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'preload/background.service.dart';
import 'preload/preload.controller.dart';
import 'preload/preload.state.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({super.key});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  final controller = PreloadController(PreloadState.initial());

  @override
  void initState() {
    Future.delayed(Duration.zero, () async {
      BackgroundService.createListenerForTask(
        task: 'loading',
        callback: (data) => controller.setLoading(),
      );
      BackgroundService.createListenerForTask(
        task: 'videos',
        callback: (data) => controller.updateUrl(data),
      );
      await controller.getVideosFromApi();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder(
        valueListenable: controller,
        builder: (context, state, _) {
          return PageView.builder(
            itemCount: state.urls.length,
            scrollDirection: Axis.vertical,
            onPageChanged: (index) => controller.play(index),
            itemBuilder: (context, index) => state.focusedIndex == index
                ? VideoWidget(
                    // Is at end and isLoading
                    isLoading:
                        state.isLoading && index == state.urls.length - 1,
                    controller: state.controllers[index]!,
                  )
                : const SizedBox(),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    BackgroundService.removeListenerForTask('loading');
    BackgroundService.removeListenerForTask('videos');
    super.dispose();
  }
}

/// Custom Feed Widget consisting video
class VideoWidget extends StatelessWidget {
  const VideoWidget({
    super.key,
    required this.isLoading,
    required this.controller,
  });

  final bool isLoading;
  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: VideoPlayer(controller)),
        AnimatedCrossFade(
          alignment: Alignment.bottomCenter,
          sizeCurve: Curves.decelerate,
          duration: const Duration(milliseconds: 400),
          firstChild: const Padding(
            padding: EdgeInsets.all(10.0),
            child: CircularProgressIndicator.adaptive(),
          ),
          secondChild: const SizedBox(),
          crossFadeState:
              isLoading ? CrossFadeState.showFirst : CrossFadeState.showSecond,
        ),
      ],
    );
  }
}
