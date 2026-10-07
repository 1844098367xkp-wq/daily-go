import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// 声音与触觉协同管理服务 (支持短交互音效 + 强力闹钟循环响铃)
class SoundHapticService {
  SoundHapticService._internal();
  static final SoundHapticService instance = SoundHapticService._internal();

  AudioPlayer? _shortSfxPlayer;
  AudioPlayer? _alarmPlayer;

  bool _isSoundEnabled = true;
  bool _isAlarmRinging = false;
  Timer? _alarmHapticTimer;

  bool get isAlarmRinging => _isAlarmRinging;

  /// 初始化音频播放器
  Future<void> init() async {
    try {
      _shortSfxPlayer = AudioPlayer();
      await _shortSfxPlayer?.setPlayerMode(PlayerMode.lowLatency);

      _alarmPlayer = AudioPlayer();
      await _alarmPlayer?.setReleaseMode(ReleaseMode.loop); // 循环播放
    } catch (_) {}
  }

  // ==================== 微交互短音效 ====================

  /// 1. 触发任务勾选完成 (Medium 触感 + 马林巴木音)
  Future<void> playTaskCompleted() async {
    await HapticFeedback.mediumImpact();
    if (_isSoundEnabled && _shortSfxPlayer != null) {
      try {
        await _shortSfxPlayer!.play(
          AssetSource('sounds/task_complete.wav'),
          mode: PlayerMode.lowLatency,
        );
      } catch (_) {}
    }
  }

  /// 2. 触发新建任务 (Light 轻触 + 微动开关咔哒音)
  Future<void> playTaskCreated() async {
    await HapticFeedback.lightImpact();
    if (_isSoundEnabled && _shortSfxPlayer != null) {
      try {
        await _shortSfxPlayer!.play(
          AssetSource('sounds/task_create.wav'),
          mode: PlayerMode.lowLatency,
        );
      } catch (_) {}
    }
  }

  /// 3. 触发撤销/删除 (Heavy 微重感 + 柔和消散音)
  Future<void> playTaskDeleted() async {
    await HapticFeedback.heavyImpact();
    if (_isSoundEnabled && _shortSfxPlayer != null) {
      try {
        await _shortSfxPlayer!.play(
          AssetSource('sounds/task_delete.wav'),
          mode: PlayerMode.lowLatency,
        );
      } catch (_) {}
    }
  }

  // ==================== 强力闹钟循环播放与关闭 ====================

  /// 启动循环闹钟：音乐循环响铃，配合周期性脉冲振动，直到调用 stopAlarm()
  Future<void> startAlarm({String? customAudioPath}) async {
    if (_isAlarmRinging) return;
    _isAlarmRinging = true;

    // 1. 开启持续震动脉冲 (每 1 秒震动一次)
    _alarmHapticTimer?.cancel();
    _alarmHapticTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      if (_isAlarmRinging) {
        HapticFeedback.heavyImpact();
      }
    });

    // 2. 循环播放音乐
    if (_isSoundEnabled && _alarmPlayer != null) {
      try {
        await _alarmPlayer!.setReleaseMode(ReleaseMode.loop);

        if (customAudioPath != null &&
            customAudioPath.isNotEmpty &&
            File(customAudioPath).existsSync()) {
          // 播放手机本地自定义的音频文件 (MP3 / WAV / M4A)
          await _alarmPlayer!.play(DeviceFileSource(customAudioPath));
        } else {
          // 播放默认自带闹钟音效
          await _alarmPlayer!.play(AssetSource('sounds/task_complete.wav'));
        }
      } catch (_) {}
    }
  }

  /// 用户点击“关闭提醒”：立即停止循环响铃与震动
  Future<void> stopAlarm() async {
    _isAlarmRinging = false;
    _alarmHapticTimer?.cancel();
    _alarmHapticTimer = null;

    try {
      await _alarmPlayer?.stop();
    } catch (_) {}
  }

  void setSoundEnabled(bool enabled) {
    _isSoundEnabled = enabled;
  }

  void dispose() {
    stopAlarm();
    _shortSfxPlayer?.dispose();
    _alarmPlayer?.dispose();
  }
}
