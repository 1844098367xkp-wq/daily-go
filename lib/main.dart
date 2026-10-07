import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'repositories/task_repository.dart';
import 'services/sound_haptic_service.dart';
import 'theme/app_theme.dart';
import 'screens/today_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 设置系统沉浸式状态栏与导航栏
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  // 2. 初始化底层音频池与触觉服务 (仅耗费 <15ms)
  await SoundHapticService.instance.init();

  // 3. 实例化本地单机仓储
  final taskRepository = TaskRepository();

  runApp(DailyGoApp(repository: taskRepository));
}

/// 《每日行》应用入口根组件
class DailyGoApp extends StatelessWidget {
  final TaskRepository repository;

  const DailyGoApp({
    super.key,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '每日行',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // 跟随系统深浅色切换
      home: TodayScreen(repository: repository),
    );
  }
}
