// =============================================================================
// 任务（Task）模型
// =============================================================================
// 收件箱中的主实体，可设置计划开始时间、持续时间、截止时间、提醒时间、
// 所属列表、标签、备注；可拆分为多个子任务（Action）。删除为软删除（deletedAt）。
// 序列化：toMap / fromMap 用于 Hive 等持久化。
// =============================================================================

class Task {
  Task({
    required this.id,
    required this.title,
    this.startTime,
    this.durationMinutes = 0,
    this.deadline,
    this.reminderAt,
    this.tags = const [],
    this.listName,
    required this.createdAt,
    this.isCompleted = false,
    this.userId,
    this.notes = '',
    this.deletedAt,
    this.updatedAt,
    this.pinned = false,
    this.repeat = '',
    this.anytime = false,
  });

  final String id;
  final String title;
  /// 计划开始时间；仅日期时可为当天 00:00（“随时”任务）
  final DateTime? startTime;
  /// 持续分钟数；0 表示无固定时长或“随时”
  final int durationMinutes;
  final DateTime? deadline;
  /// 提醒触发时间，用于本地通知
  final DateTime? reminderAt;
  final List<String> tags;
  /// 所属列表名称（列表视图分组）
  final String? listName;
  final DateTime createdAt;
  final bool isCompleted;
  final String? userId;
  final String notes;
  /// 软删除时间，非 null 表示在垃圾箱
  final DateTime? deletedAt;
  final DateTime? updatedAt;
  /// 锁定后，自动计划不会挪动这条任务
  final bool pinned;
  /// 重复规则的编码；空字符串表示不重复
  final String repeat;
  /// 勾选后没有固定开始钟点，即使填了持续时间
  final bool anytime;

  /// 不可变拷贝；clearReminderAt: true 时显式清空 reminderAt
  Task copyWith({
    String? id,
    String? title,
    DateTime? startTime,
    int? durationMinutes,
    DateTime? deadline,
    DateTime? reminderAt,
    bool clearReminderAt = false,
    List<String>? tags,
    String? listName,
    DateTime? createdAt,
    bool? isCompleted,
    String? userId,
    String? notes,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    DateTime? updatedAt,
    bool? pinned,
    String? repeat,
    bool? anytime,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      deadline: deadline ?? this.deadline,
      reminderAt: clearReminderAt ? null : (reminderAt ?? this.reminderAt),
      tags: tags ?? List.from(this.tags),
      listName: listName ?? this.listName,
      createdAt: createdAt ?? this.createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
      userId: userId ?? this.userId,
      notes: notes ?? this.notes,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      updatedAt: updatedAt ?? this.updatedAt,
      pinned: pinned ?? this.pinned,
      repeat: repeat ?? this.repeat,
      anytime: anytime ?? this.anytime,
    );
  }

  /// 序列化为 Map，供 Hive 等存储
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'startTime': startTime?.toIso8601String(),
      'durationMinutes': durationMinutes,
      'deadline': deadline?.toIso8601String(),
      'reminderAt': reminderAt?.toIso8601String(),
      'tags': tags,
      'listName': listName,
      'createdAt': createdAt.toIso8601String(),
      'isCompleted': isCompleted,
      'userId': userId,
      'notes': notes,
      'deletedAt': deletedAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'pinned': pinned,
      'repeat': repeat,
      'anytime': anytime,
    };
  }

  /// 从 Map 反序列化（兼容旧数据缺字段）
  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      title: map['title'] as String,
      startTime: map['startTime'] != null
          ? DateTime.parse(map['startTime'] as String)
          : null,
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 0,
      deadline: map['deadline'] != null
          ? DateTime.parse(map['deadline'] as String)
          : null,
      reminderAt: map['reminderAt'] != null
          ? DateTime.parse(map['reminderAt'] as String)
          : null,
      tags: map['tags'] != null
          ? List<String>.from(map['tags'] as List)
          : [],
      listName: map['listName'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      isCompleted: (map['isCompleted'] as bool?) ?? false,
      userId: map['userId'] as String?,
      notes: (map['notes'] as String?) ?? '',
      deletedAt: map['deletedAt'] != null
          ? DateTime.parse(map['deletedAt'] as String)
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
      pinned: (map['pinned'] as bool?) ?? false,
      repeat: (map['repeat'] as String?) ?? '',
      anytime: (map['anytime'] as bool?) ?? false,
    );
  }
}
