import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/task_model.dart';
import '../repositories/task_repository.dart';
import '../theme/app_theme.dart';
import '../services/sound_haptic_service.dart';
import '../services/time_parser_service.dart';
import '../widgets/precise_time_picker_dialog.dart';

/// 灵感备忘箱独立页面 (IdeaInboxScreen)
/// 完整满足产品交互要求：
/// 1. 独立全屏页面，展示所有沉淀与未排期的灵感清单
/// 2. 醒目的【+ 记新灵感】新建按键
/// 3. 点击灵感可配置具体日期与时分秒，一键将灵感“安置到对应日期的日程”
/// 4. 每一条灵感可点击看详细并就地修改
/// 5. 保存和删除时均执行二次弹窗确认
class IdeaInboxScreen extends StatefulWidget {
  final TaskRepository repository;

  const IdeaInboxScreen({
    super.key,
    required this.repository,
  });

  @override
  State<IdeaInboxScreen> createState() => _IdeaInboxScreenState();
}

class _IdeaInboxScreenState extends State<IdeaInboxScreen> {
  List<TaskModel> _ideas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadIdeas();
  }

  Future<void> _loadIdeas() async {
    setState(() => _isLoading = true);
    final list = await widget.repository.getArchivedTasks();
    if (mounted) {
      setState(() {
        _ideas = list;
        _isLoading = false;
      });
    }
  }

  /// 1. 新建灵感
  void _openCreateIdeaDialog() {
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? AppTheme.cardDark : Colors.white;
    final primaryTextColor = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final primaryColor = isDark ? AppTheme.primaryDark : AppTheme.primaryLight;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.badgeIdeaDark : AppTheme.badgeIdeaLight).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lightbulb_rounded,
                  size: 20,
                  color: isDark ? AppTheme.badgeIdeaDark : AppTheme.badgeIdeaLight,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '记一条新灵感',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: primaryTextColor),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                style: TextStyle(color: primaryTextColor, fontSize: 15),
                decoration: InputDecoration(
                  labelText: '灵感标题',
                  hintText: '如：想读的书、某个创意想法...',
                  labelStyle: TextStyle(color: primaryColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 3,
                style: TextStyle(color: primaryTextColor, fontSize: 14),
                decoration: InputDecoration(
                  labelText: '灵感备注 / 详细内容 (可选)',
                  hintText: '写下更多背景或思考...',
                  labelStyle: TextStyle(color: AppTheme.textSecondaryLight),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                final notes = notesController.text.trim();
                final now = DateTime.now().millisecondsSinceEpoch;

                final newIdea = TaskModel(
                  id: const Uuid().v4(),
                  title: title,
                  rawInput: notes.isEmpty ? null : notes,
                  targetDate: 'INBOX',
                  status: TaskStatus.archived,
                  createdAt: now,
                  updatedAt: now,
                  archivedAt: now,
                );

                await widget.repository.createTask(newIdea);
                SoundHapticService.instance.playTaskCreated();
                Navigator.of(ctx).pop();
                _loadIdeas();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已收录至灵感备忘箱'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('收录灵感'),
            ),
          ],
        );
      },
    );
  }

  /// 2. 查看详细并就地修改（保存/删除均提示确认）
  void _openDetailAndEditDialog(TaskModel idea) {
    final titleController = TextEditingController(text: idea.title);
    final notesController = TextEditingController(text: idea.rawInput ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? AppTheme.cardDark : Colors.white;
    final primaryTextColor = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final primaryColor = isDark ? AppTheme.primaryDark : AppTheme.primaryLight;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: Row(
            children: [
              Icon(Icons.edit_note_rounded, color: primaryColor, size: 24),
              const SizedBox(width: 8),
              Text(
                '灵感详情与编辑',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: primaryTextColor),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: titleController,
                  style: TextStyle(color: primaryTextColor, fontSize: 15.5, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: '灵感标题',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 4,
                  style: TextStyle(color: primaryTextColor, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: '灵感详细内容 / 备忘',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '收录时间: ${TimeParserService.formatDate(DateTime.fromMillisecondsSinceEpoch(idea.createdAt))}',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryLight),
                ),
              ],
            ),
          ),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 选项 A: 安排到日程
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    _scheduleIdeaToDate(idea);
                  },
                  icon: const Icon(Icons.event_available_rounded, size: 18),
                  label: const Text('安置到指定日期日程'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    // 选项 B: 删除灵感 (触发二次确认)
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          _confirmDeleteIdea(dialogCtx, idea);
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Colors.redAccent),
                        label: const Text('删除灵感', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 选项 C: 保存修改 (触发二次确认)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _confirmSaveIdea(
                            dialogCtx,
                            idea,
                            titleController.text.trim(),
                            notesController.text.trim(),
                          );
                        },
                        icon: const Icon(Icons.save_rounded, size: 17),
                        label: const Text('保存修改'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// 保存二次确认弹窗
  void _confirmSaveIdea(BuildContext parentCtx, TaskModel idea, String newTitle, String newNotes) {
    if (newTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('灵感标题不能为空')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (confirmCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('确认保存修改？', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: const Text('是否确认将对该灵感的修改保存到本地？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(confirmCtx).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(confirmCtx).pop(); // 关闭确认框
                Navigator.of(parentCtx).pop(); // 关闭编辑框

                final updated = idea.copyWith(
                  title: newTitle,
                  rawInput: newNotes.isEmpty ? null : newNotes,
                );
                await widget.repository.updateTask(updated);
                SoundHapticService.instance.playSelectionClick();
                _loadIdeas();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已成功保存灵感修改'), duration: Duration(seconds: 2)),
                  );
                }
              },
              child: const Text('确认保存'),
            ),
          ],
        );
      },
    );
  }

  /// 删除二次确认弹窗
  void _confirmDeleteIdea(BuildContext parentCtx, TaskModel idea) {
    showDialog(
      context: context,
      builder: (confirmCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('确认删除该灵感？', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: const Text('此操作将永久移除该条灵感，无法撤销。是否确认？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(confirmCtx).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(confirmCtx).pop(); // 关闭确认框
                Navigator.of(parentCtx).pop(); // 关闭编辑框

                await widget.repository.deleteTask(idea.id);
                SoundHapticService.instance.playTaskDeleted();
                _loadIdeas();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已成功删除该灵感'), duration: Duration(seconds: 2)),
                  );
                }
              },
              child: const Text('确认删除'),
            ),
          ],
        );
      },
    );
  }

  /// 3. 将灵感安置到具体日期的日程里 (调用精确时分秒与闹钟配置)
  Future<void> _scheduleIdeaToDate(TaskModel idea) async {
    final now = DateTime.now();
    final result = await PreciseTimePickerDialog.show(
      context,
      initialDateTime: now,
      initialHasAlarm: true,
    );

    if (result != null) {
      final targetDate = result['targetDate'] as String;
      final timeSlot = result['timeSlot'] as String?;
      final hasAlarm = (result['hasAlarm'] as bool?) ?? false;
      final customSoundPath = result['customSoundPath'] as String?;

      final scheduledTask = idea.copyWith(
        targetDate: targetDate,
        timeSlot: timeSlot,
        hasAlarm: hasAlarm,
        customSoundPath: customSoundPath,
        status: TaskStatus.todo,
      );

      await widget.repository.updateTask(scheduledTask);
      SoundHapticService.instance.playTaskCreated();
      _loadIdeas();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ 已成功安置到 $targetDate 日程！'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final secondaryTextColor = AppTheme.textSecondaryLight;
    final primaryColor = isDark ? AppTheme.primaryDark : AppTheme.primaryLight;
    final cardBg = isDark ? AppTheme.cardDark : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryTextColor, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.badgeIdeaBgDark : AppTheme.badgeIdeaBgLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lightbulb_rounded,
                size: 18,
                color: isDark ? AppTheme.badgeIdeaDark : AppTheme.badgeIdeaLight,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '灵感备忘箱',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_ideas.length}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primaryColor),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateIdeaDialog,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('记新灵感', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _ideas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: (isDark ? AppTheme.primaryDark : AppTheme.primaryLight).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 48,
                          color: isDark ? AppTheme.badgeIdeaDark : AppTheme.badgeIdeaLight,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '灵感箱暂无备忘事项',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '随时将尚未想好具体日期的奇思妙想记录于此。\n点击右下角按钮即可开始。',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: secondaryTextColor, height: 1.4),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: _ideas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final idea = _ideas[idx];
                    return InkWell(
                      onTap: () => _openDetailAndEditDialog(idea),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          boxShadow: AppTheme.cardShadow(isDark),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    idea.title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: primaryTextColor,
                                    ),
                                  ),
                                ),
                                // 安置到日程快捷按钮
                                ElevatedButton.icon(
                                  onPressed: () => _scheduleIdeaToDate(idea),
                                  icon: const Icon(Icons.calendar_month_rounded, size: 14),
                                  label: const Text('安置到日程', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: const Size(0, 32),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                ),
                              ],
                            ),
                            if (idea.rawInput != null && idea.rawInput!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                idea.rawInput!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, color: secondaryTextColor, height: 1.35),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded, size: 13, color: secondaryTextColor),
                                const SizedBox(width: 4),
                                Text(
                                  '收录于 ${TimeParserService.formatDate(DateTime.fromMillisecondsSinceEpoch(idea.createdAt))}',
                                  style: TextStyle(fontSize: 11.5, color: secondaryTextColor),
                                ),
                                const Spacer(),
                                Text(
                                  '点击查看详情 / 编辑',
                                  style: TextStyle(fontSize: 11.5, color: primaryColor),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
