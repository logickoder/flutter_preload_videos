import 'dart:developer';

import 'package:flutter/foundation.dart';

import '../api.service.dart';
import '../constants.dart';
import 'preload.service.dart';
import 'preload.state.dart';

class PreloadController extends ValueNotifier<PreloadState> {
  PreloadController(super.value);

  static const _tag = 'PreloadController:';

  void setLoading() {
    value = value.copyWith(isLoading: true);
  }

  void play(int index) async {
    /// Condition to fetch new videos
    final bool shouldFetch = (index + kPreloadLimit) % kNextLimit == 0 &&
        value.urls.length == index + kPreloadLimit;

    if (shouldFetch) {
      PreloadService.createIsolate(index);
    }

    /// Next / Prev video decider
    if (index > value.focusedIndex) {
      await PreloadService.playNext(
        index: index,
        state: value,
        updateState: (state) => value = state,
      );
    } else {
      await PreloadService.playPrevious(
        index: index,
        state: value,
        updateState: (state) => value = state,
      );
    }

    value = value.copyWith(focusedIndex: index);
  }

  void updateUrl(List<String> urls) async {
    /// Add new urls to current urls
    value = value.copyWith(urls: value.urls + urls);

    /// Initialize new url
    await _initializeControllerAtIndex(value.focusedIndex + 1);

    value = value.copyWith(
      reloadCounter: value.reloadCounter + 1,
      isLoading: false,
    );

    log('$_tag new videos added');
  }

  Future<void> getVideosFromApi() async {
    /// Fetch first 5 videos from api
    final urls = await ApiService.getVideos();
    value = value.copyWith(urls: value.urls + urls);

    /// Initialize 1st video
    await _initializeControllerAtIndex(0);

    /// Play 1st video
    await PreloadService.playControllerAtIndex(index: 0, state: value);

    /// Initialize 2nd video
    await _initializeControllerAtIndex(1);

    value = value.copyWith(
      reloadCounter: value.reloadCounter + 1,
    );
  }

  Future<void> _initializeControllerAtIndex(int index) async {
    await PreloadService.initializeControllerAtIndex(
      index: index,
      state: value,
      updateState: (state) => value = state,
    );
  }
}
