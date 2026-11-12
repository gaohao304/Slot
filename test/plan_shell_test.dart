import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:slot/models/action.dart' as slot_action;
import 'package:slot/models/list_catalog.dart';
import 'package:slot/models/task.dart';
import 'package:slot/providers/app_settings.dart';
import 'package:slot/providers/schedule_provider.dart';
import 'package:slot/repositories/schedule_repository.dart';
import 'package:slot/screens/plan_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('slot_ui_');
  });

  tearDown(() async {
    await Hive.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  testWidgets('计划页在 iPhone 尺寸下能排开', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = await tester.runAsync(() async {
      Hive.init(dir.path);
      return Hive.openBox<String>('settings');
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ScheduleRepository>(create: (_) => _FakeRepository()),
          ChangeNotifierProvider(
            create: (context) => ScheduleProvider(
              repository: context.read<ScheduleRepository>(),
            ),
          ),
          ChangeNotifierProvider(create: (_) => AppSettings(settings!)),
        ],
        child: const MaterialApp(home: PlanShell()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('今天'), findsOneWidget);

    await tester.tap(find.byTooltip('月历'));
    await tester.pump();
    expect(find.textContaining('年'), findsWidgets);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('收件箱'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeRepository implements ScheduleRepository {
  @override
  Future<void> deleteActionPermanently(String id) async {}

  @override
  Future<void> deleteTaskPermanently(String id) async {}

  @override
  Future<slot_action.Action?> getActionById(String id) async => null;

  @override
  Future<List<slot_action.Action>> getActionsByDate(DateTime date) async => [];

  @override
  Future<List<slot_action.Action>> getActionsByTaskId(String taskId) async => [];

  @override
  Future<List<Task>> getAllTasks() async => [];

  @override
  Future<List<Task>> getCompletedTasks() async => [];

  @override
  Future<List<Task>> getInboxTasks() async => [];

  @override
  Future<List<String>> getKnownListNames() async => [];

  @override
  Future<List<String>> getKnownTagNames() async => [];

  @override
  Future<Task?> getTaskById(String id) async => null;

  @override
  Future<List<Task>> getTasksByDate(DateTime date) async => [];

  @override
  Future<List<Task>> getTasksByDeadlineDate(DateTime date) async => [];

  @override
  Future<List<Task>> getTasksByList(String listName) async => [];

  @override
  Future<List<Task>> getTasksByTag(String tag) async => [];

  @override
  Future<List<Task>> getTrashTasks() async => [];

  @override
  Future<void> saveAction(slot_action.Action action) async {}

  @override
  Future<void> saveTask(Task task) async {}

  @override
  Future<void> setKnownListNames(List<String> names) async {}

  @override
  Future<ListCatalog> getListCatalog() async => const ListCatalog();

  @override
  Future<void> setListCatalog(ListCatalog catalog) async {}

  @override
  Future<void> setKnownTagNames(List<String> names) async {}
}
