// =============================================================================
// 子任务 / 具体工作（Action）模型
// =============================================================================
// 从属于某个 Task（parentTaskId），用于任务详情页“拆分子任务”。
// 字段与 Task 类似：标题、开始时间、持续时间、截止、标签、完成状态等。
// 序列化：toMap / fromMap 用于 Hive 持久化。
// =============================================================================

class Action {
  Action({
    required this.id,
    required this.parentTaskId,
    required this.title,
    this.startTime,
    this.durationMinutes = 0,
    this.deadline,
    this.tags = const [],
    required this.createdAt,
    this.isCompleted = false,
    this.userId,
    this.deletedAt,
    this.updatedAt,
  });

  final String id;
  final String parentTaskId;
  final String title;
  final DateTime? startTime;
  final int durationMinutes;
  final DateTime? deadline;
  final List<String> tags;
  final DateTime createdAt;
  final bool isCompleted;
  final String? userId;
  final DateTime? deletedAt;
  final DateTime? updatedAt;

  /// 不可变拷贝
  Action copyWith({
    String? id,
    String? parentTaskId,
    String? title,
    DateTime? startTime,
    int? durationMinutes,
    DateTime? deadline,
    List<String>? tags,
    DateTime? createdAt,
    bool? isCompleted,
    String? userId,
    DateTime? deletedAt,
    DateTime? updatedAt,
  }) {
    return Action(
      id: id ?? this.id,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      deadline: deadline ?? this.deadline,
      tags: tags ?? List.from(this.tags),
      createdAt: createdAt ?? this.createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
      userId: userId ?? this.userId,
      deletedAt: deletedAt ?? this.deletedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 序列化为 Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'parentTaskId': parentTaskId,
      'title': title,
      'startTime': startTime?.toIso8601String(),
      'durationMinutes': durationMinutes,
      'deadline': deadline?.toIso8601String(),
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'isCompleted': isCompleted,
      'userId': userId,
      'deletedAt': deletedAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// 从 Map 反序列化
  factory Action.fromMap(Map<String, dynamic> map) {
    return Action(
      id: map['id'] as String,
      parentTaskId: map['parentTaskId'] as String,
      title: map['title'] as String,
      startTime: map['startTime'] != null
          ? DateTime.parse(map['startTime'] as String)
          : null,
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 0,
      deadline: map['deadline'] != null
          ? DateTime.parse(map['deadline'] as String)
          : null,
      tags: map['tags'] != null
          ? List<String>.from(map['tags'] as List)
          : [],
      createdAt: DateTime.parse(map['createdAt'] as String),
      isCompleted: (map['isCompleted'] as bool?) ?? false,
      userId: map['userId'] as String?,
      deletedAt: map['deletedAt'] != null
          ? DateTime.parse(map['deletedAt'] as String)
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }
}
