import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// 声音与触觉协同管理服务 (声触合一、低延迟单例)
/// 采用官方活跃维护的 audioplayers，全面兼容 AGP 8 与现代移动架构
class SoundHapticService {
  SoundHapticService._internal();
  static final SoundHapticService instance = SoundHapticService._internal();

  AudioPlayer? _player;
  bool _isSoundEnabled = true;

  /// 初始化并配置低延迟音频播放器
  Future<void> init() async {
    try {
      _player = AudioPlayer();
      await _player?.setPlayerMode(PlayerMode.lowLatency);
    } catch (_) {
      // 容错降级：若平台音频服务不可用，平滑降级为纯触觉模式
    }
  }

  /// 1. 触发任务勾选完成 (Medium 触感 + 马林巴木音)
  Future<void> playTaskCompleted() async {
    // 毫秒级触觉反馈
    await HapticFeedback.mediumImpact();
    if (_isSoundEnabled && _player != null) {
      try {
        await _player!.play(
          AssetSource('sounds/task_complete.wav'),
          mode: PlayerMode.lowLatency,
        );
      } catch (_) {}
    }
  }

  /// 2. 触发新建任务 (Light 轻触 + 微动开关咔哒音)
  Future<void> playTaskCreated() async {
    await HapticFeedback.lightImpact();
    if (_isSoundEnabled && _player != null) {
      try {
        await _player!.play(
          AssetSource('sounds/task_create.wav'),
          mode: PlayerMode.lowLatency,
        );
      } catch (_) {}
    }
  }

  /// 3. 触发撤销/删除 (Heavy/Rigid 微重感 + 柔和消散音)
  Future<void> playTaskDeleted() async {
    await HapticFeedback.heavyImpact();
    if (_isSoundEnabled && _player != null) {
      try {
        await _player!.play(
          AssetSource('sounds/task_delete.wav'),
          mode: PlayerMode.lowLatency,
        );
      } catch (_) {}
    }
  }

  /// 切换静音开关
  void setSoundEnabled(bool enabled) {
    _isSoundEnabled = enabled;
  }

  /// 释放资源
  void dispose() {
    _player?.dispose();
  }
}
