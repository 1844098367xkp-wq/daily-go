import 'package:flutter/services.dart';
import 'package:soundpool/soundpool.dart';

/// 声音与触觉协同管理服务 (声触合一、低延迟单例)
class SoundHapticService {
  SoundHapticService._internal();
  static final SoundHapticService instance = SoundHapticService._internal();

  Soundpool? _soundpool;
  int? _soundCompleteId;
  int? _soundCreateId;
  int? _soundDeleteId;
  bool _isSoundEnabled = true;

  /// 初始化并预加载音频资源到原生内存池
  Future<void> init() async {
    try {
      _soundpool = Soundpool.fromOptions(
        options: const SoundpoolOptions(
          maxStreams: 4,
          streamType: StreamType.music,
        ),
      );

      _soundCompleteId = await _loadSound('assets/sounds/task_complete.wav');
      _soundCreateId = await _loadSound('assets/sounds/task_create.wav');
      _soundDeleteId = await _loadSound('assets/sounds/task_delete.wav');
    } catch (_) {
      // 容错处理：若音频文件未配置或平台不支持，降级为纯触觉模式
    }
  }

  Future<int?> _loadSound(String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      return await _soundpool?.load(byteData);
    } catch (_) {
      return null;
    }
  }

  /// 1. 触发任务勾选完成 (Medium 触感 + 马林巴木音)
  Future<void> playTaskCompleted() async {
    // 毫秒级触觉反馈
    await HapticFeedback.mediumImpact();
    if (_isSoundEnabled && _soundCompleteId != null && _soundpool != null) {
      await _soundpool!.play(_soundCompleteId!);
    }
  }

  /// 2. 触发新建任务 (Light 轻触 + 微动开关咔哒音)
  Future<void> playTaskCreated() async {
    await HapticFeedback.lightImpact();
    if (_isSoundEnabled && _soundCreateId != null && _soundpool != null) {
      await _soundpool!.play(_soundCreateId!);
    }
  }

  /// 3. 触发撤销/删除 (Heavy/Rigid 微重感 + 柔和消散音)
  Future<void> playTaskDeleted() async {
    await HapticFeedback.heavyImpact();
    if (_isSoundEnabled && _soundDeleteId != null && _soundpool != null) {
      await _soundpool!.play(_soundDeleteId!);
    }
  }

  /// 切换静音开关
  void setSoundEnabled(bool enabled) {
    _isSoundEnabled = enabled;
  }

  /// 释放资源
  void dispose() {
    _soundpool?.dispose();
  }
}
