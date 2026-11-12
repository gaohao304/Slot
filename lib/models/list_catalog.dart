import 'dart:convert';

/// 一个列表目录。里面的列表按用户排列的顺序保存。
class ListFolder {
  const ListFolder({required this.id, required this.name, this.lists = const []});

  final String id;
  final String name;
  final List<String> lists;

  ListFolder copyWith({String? name, List<String>? lists}) {
    return ListFolder(id: id, name: name ?? this.name, lists: lists ?? this.lists);
  }

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'lists': lists};

  factory ListFolder.fromMap(Map<String, dynamic> map) {
    return ListFolder(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      lists: _strings(map['lists']),
    );
  }
}

/// 列表首页的排布：未分组列表、目录，以及已存档。
class ListCatalog {
  const ListCatalog({
    this.loose = const [],
    this.folders = const [],
    this.archived = const [],
  });

  final List<String> loose;
  final List<ListFolder> folders;
  final List<String> archived;

  List<String> get allNames => [
        ...loose,
        for (final folder in folders) ...folder.lists,
        ...archived,
      ];

  bool contains(String name) => allNames.contains(name);

  ListCatalog copyWith({
    List<String>? loose,
    List<ListFolder>? folders,
    List<String>? archived,
  }) {
    return ListCatalog(
      loose: loose ?? this.loose,
      folders: folders ?? this.folders,
      archived: archived ?? this.archived,
    );
  }

  ListCatalog without(String name) {
    return ListCatalog(
      loose: loose.where((item) => item != name).toList(),
      folders: [
        for (final folder in folders)
          folder.copyWith(lists: folder.lists.where((item) => item != name).toList()),
      ],
      archived: archived.where((item) => item != name).toList(),
    );
  }

  /// 新名字已经存在时，只拿掉旧名字，任务会并入那个已有列表。
  ListCatalog renameList(String oldName, String newName) {
    if (oldName == newName) return this;
    if (contains(newName)) return without(oldName);
    String mapName(String item) => item == oldName ? newName : item;
    return ListCatalog(
      loose: loose.map(mapName).toList(),
      folders: [
        for (final folder in folders) folder.copyWith(lists: folder.lists.map(mapName).toList()),
      ],
      archived: archived.map(mapName).toList(),
    );
  }

  /// 把列表放到目录、已存档，或放回未分组的最上方。
  ListCatalog place(String name, {String? folderId, bool archive = false}) {
    final cleared = without(name);
    if (archive) {
      return cleared.copyWith(archived: [...cleared.archived, name]);
    }
    if (folderId != null && cleared.folders.any((folder) => folder.id == folderId)) {
      return cleared.copyWith(
        folders: [
          for (final folder in cleared.folders)
            if (folder.id == folderId) folder.copyWith(lists: [...folder.lists, name]) else folder,
        ],
      );
    }
    return cleared.copyWith(loose: [name, ...cleared.loose]);
  }

  String encode() => jsonEncode({
        'loose': loose,
        'folders': folders.map((folder) => folder.toMap()).toList(),
        'archived': archived,
      });

  factory ListCatalog.decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return ListCatalog(loose: decoded.map((item) => item as String).toList());
    }
    if (decoded is! Map) return const ListCatalog();
    final map = Map<String, dynamic>.from(decoded);
    return ListCatalog(
      loose: _strings(map['loose']),
      folders: (map['folders'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((item) => ListFolder.fromMap(Map<String, dynamic>.from(item)))
          .where((folder) => folder.id.isNotEmpty && folder.name.isNotEmpty)
          .toList(),
      archived: _strings(map['archived']),
    );
  }
}

List<String> _strings(Object? raw) {
  if (raw is! List) return [];
  return raw.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
}
