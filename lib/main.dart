import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bool kScreenshotMode = bool.fromEnvironment('SCREENSHOT_MODE');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DeploOperationsApp());
}

class DeploOperationsApp extends StatelessWidget {
  const DeploOperationsApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF0070E0);
    const secondary = Color(0xFF0000E0);
    const surface = Color(0xFFF6F2EA);

    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: primary,
          onPrimary: Colors.white,
          secondary: secondary,
          onSecondary: const Color(0xFF1E1209),
          tertiary: const Color(0xFF237A86),
          surface: surface,
          surfaceContainerHighest: const Color(0xFFE8DED0),
          onSurface: const Color(0xFF182027),
        );

    return MaterialApp(
      title: 'DECLOQUEMENT ERIC PIERRE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: surface,
        appBarTheme: const AppBarTheme(
          backgroundColor: surface,
          foregroundColor: Color(0xFF182027),
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFE1D7C7)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD6CAB9)),
          ),
        ),
      ),
      home: const OperationsBootstrap(),
    );
  }
}

class OperationsBootstrap extends StatefulWidget {
  const OperationsBootstrap({super.key});

  @override
  State<OperationsBootstrap> createState() => _OperationsBootstrapState();
}

class _OperationsBootstrapState extends State<OperationsBootstrap> {
  late final Future<OperationsStore> _storeFuture = OperationsStore.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OperationsStore>(
      future: _storeFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return OperationsScope(
          store: snapshot.data!,
          child: const OperationsShell(),
        );
      },
    );
  }
}

class OperationsScope extends InheritedNotifier<OperationsStore> {
  const OperationsScope({
    required OperationsStore store,
    required super.child,
    super.key,
  }) : super(notifier: store);

  static OperationsStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<OperationsScope>();
    assert(scope != null, 'OperationsScope is missing');
    return scope!.notifier!;
  }
}

class OperationsStore extends ChangeNotifier {
  OperationsStore._({
    required SharedPreferences? preferences,
    required bool readOnly,
    required List<TaskRecord> tasks,
    required List<PatientRecord> patients,
    required List<RevenueRecord> revenue,
    required List<AuditRecord> audit,
    required AppPreferences preferencesState,
  }) : _preferences = preferences,
       _readOnly = readOnly,
       _tasks = tasks,
       _patients = patients,
       _revenue = revenue,
       _audit = audit,
       _preferencesState = preferencesState;

  static const _tasksKey = 'operations.tasks.v1';
  static const _patientsKey = 'operations.patients.v1';
  static const _revenueKey = 'operations.revenue.v1';
  static const _auditKey = 'operations.audit.v1';
  static const _preferencesKey = 'operations.preferences.v1';

  final SharedPreferences? _preferences;
  final bool _readOnly;
  final List<TaskRecord> _tasks;
  final List<PatientRecord> _patients;
  final List<RevenueRecord> _revenue;
  final List<AuditRecord> _audit;
  AppPreferences _preferencesState;

  List<TaskRecord> get tasks => List.unmodifiable(_tasks);
  List<PatientRecord> get patients => List.unmodifiable(_patients);
  List<RevenueRecord> get revenue => List.unmodifiable(_revenue);
  List<AuditRecord> get audit => List.unmodifiable(_audit);
  AppPreferences get preferences => _preferencesState;

  int get openTasks => _tasks.where((task) => !task.done).length;
  int get completedTasks => _tasks.length - openTasks;
  int get activePatients => _patients.where((patient) => patient.active).length;
  int get flaggedPatients => _patients
      .where((patient) => patient.riskLevel != RiskLevel.stable)
      .length;
  double get collectedRevenue => _revenue
      .where((item) => item.status == RevenueStatus.collected)
      .fold(0, (sum, item) => sum + item.amount);
  double get pendingRevenue => _revenue
      .where((item) => item.status == RevenueStatus.pending)
      .fold(0, (sum, item) => sum + item.amount);

  static Future<OperationsStore> load() async {
    if (kScreenshotMode) {
      return OperationsStore._(
        preferences: null,
        readOnly: true,
        tasks: _seedTasks(),
        patients: _seedPatients(),
        revenue: _seedRevenue(),
        audit: _seedAudit(),
        preferencesState: const AppPreferences(
          compactLists: false,
          reviewWindow: 'Daily',
          reminderTone: 'Quiet',
        ),
      );
    }

    final preferences = await SharedPreferences.getInstance();
    final tasks = _decodeList(
      preferences.getString(_tasksKey),
      TaskRecord.fromJson,
    );
    final patients = _decodeList(
      preferences.getString(_patientsKey),
      PatientRecord.fromJson,
    );
    final revenue = _decodeList(
      preferences.getString(_revenueKey),
      RevenueRecord.fromJson,
    );
    final audit = _decodeList(
      preferences.getString(_auditKey),
      AuditRecord.fromJson,
    );
    final preferenceState = preferences.getString(_preferencesKey);

    return OperationsStore._(
      preferences: preferences,
      readOnly: false,
      tasks: tasks,
      patients: patients,
      revenue: revenue,
      audit: audit,
      preferencesState: preferenceState == null
          ? const AppPreferences(
              compactLists: false,
              reviewWindow: 'Daily',
              reminderTone: 'Quiet',
            )
          : AppPreferences.fromJson(
              jsonDecode(preferenceState) as Map<String, dynamic>,
            ),
    );
  }

  static List<T> _decodeList<T>(
    String? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw == null || raw.isEmpty) {
      return <T>[];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> addTask({
    required String title,
    required String owner,
    required String due,
    required Priority priority,
  }) async {
    final task = TaskRecord(
      id: _newId('task'),
      title: title.trim(),
      owner: owner.trim(),
      due: due.trim(),
      priority: priority,
      done: false,
    );
    _tasks.insert(0, task);
    _appendAudit(
      area: 'Task',
      action: 'Task added',
      details: '${task.title} assigned to ${task.owner}',
    );
    await _save();
  }

  Future<void> toggleTask(String id) async {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index == -1) {
      return;
    }

    final current = _tasks[index];
    _tasks[index] = current.copyWith(done: !current.done);
    _appendAudit(
      area: 'Task',
      action: _tasks[index].done ? 'Task closed' : 'Task reopened',
      details: current.title,
    );
    await _save();
  }

  Future<void> addPatient({
    required String name,
    required String code,
    required String nextAction,
    required RiskLevel riskLevel,
    required String notes,
  }) async {
    final patient = PatientRecord(
      id: _newId('patient'),
      name: name.trim(),
      code: code.trim(),
      nextAction: nextAction.trim(),
      notes: notes.trim(),
      riskLevel: riskLevel,
      active: true,
      updatedAt: DateTime.now(),
    );
    _patients.insert(0, patient);
    _appendAudit(
      area: 'Patient',
      action: 'Patient record created',
      details: '${patient.name} queued for ${patient.nextAction}',
    );
    await _save();
  }

  Future<void> updatePatientStatus(String id, bool active) async {
    final index = _patients.indexWhere((patient) => patient.id == id);
    if (index == -1) {
      return;
    }

    final patient = _patients[index];
    _patients[index] = patient.copyWith(
      active: active,
      updatedAt: DateTime.now(),
    );
    _appendAudit(
      area: 'Patient',
      action: active ? 'Patient reactivated' : 'Patient archived',
      details: patient.name,
    );
    await _save();
  }

  Future<void> addRevenue({
    required String label,
    required double amount,
    required RevenueStatus status,
    required String period,
  }) async {
    final record = RevenueRecord(
      id: _newId('revenue'),
      label: label.trim(),
      amount: amount,
      status: status,
      period: period.trim(),
    );
    _revenue.insert(0, record);
    _appendAudit(
      area: 'Revenue',
      action: 'Revenue item logged',
      details: '${record.label} - ${formatMoney(record.amount)}',
    );
    await _save();
  }

  Future<void> updatePreferences(AppPreferences preferences) async {
    _preferencesState = preferences;
    _appendAudit(
      area: 'Settings',
      action: 'Workspace preferences updated',
      details: '${preferences.reviewWindow} review window',
    );
    await _save();
  }

  void _appendAudit({
    required String area,
    required String action,
    required String details,
  }) {
    _audit.insert(
      0,
      AuditRecord(
        id: _newId('audit'),
        area: area,
        action: action,
        details: details,
        createdAt: DateTime.now(),
      ),
    );
    if (_audit.length > 60) {
      _audit.removeRange(60, _audit.length);
    }
  }

  Future<void> _save() async {
    notifyListeners();
    if (_readOnly || _preferences == null) {
      return;
    }

    await Future.wait([
      _preferences.setString(
        _tasksKey,
        jsonEncode(_tasks.map((task) => task.toJson()).toList()),
      ),
      _preferences.setString(
        _patientsKey,
        jsonEncode(_patients.map((patient) => patient.toJson()).toList()),
      ),
      _preferences.setString(
        _revenueKey,
        jsonEncode(_revenue.map((item) => item.toJson()).toList()),
      ),
      _preferences.setString(
        _auditKey,
        jsonEncode(_audit.map((item) => item.toJson()).toList()),
      ),
      _preferences.setString(
        _preferencesKey,
        jsonEncode(_preferencesState.toJson()),
      ),
    ]);
  }

  static String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  static List<TaskRecord> _seedTasks() => [
    const TaskRecord(
      id: 'task-1',
      title: 'Close morning intake checklist',
      owner: 'Front desk',
      due: 'Today 10:30',
      priority: Priority.high,
      done: false,
    ),
    const TaskRecord(
      id: 'task-2',
      title: 'Verify billing notes for yesterday',
      owner: 'Operations',
      due: 'Today 12:00',
      priority: Priority.medium,
      done: false,
    ),
    const TaskRecord(
      id: 'task-3',
      title: 'Archive signed treatment forms',
      owner: 'Records',
      due: 'Today 15:00',
      priority: Priority.low,
      done: true,
    ),
    const TaskRecord(
      id: 'task-4',
      title: 'Prepare weekly revenue review',
      owner: 'Management',
      due: 'Friday',
      priority: Priority.high,
      done: false,
    ),
  ];

  static List<PatientRecord> _seedPatients() => [
    PatientRecord(
      id: 'patient-1',
      name: 'Amina B.',
      code: 'PT-1048',
      nextAction: 'Follow-up call',
      notes: 'Insurance documents checked. Awaiting confirmation.',
      riskLevel: RiskLevel.watch,
      active: true,
      updatedAt: DateTime(2026, 5, 11, 9, 20),
    ),
    PatientRecord(
      id: 'patient-2',
      name: 'Karim R.',
      code: 'PT-1051',
      nextAction: 'Review care plan',
      notes: 'Clinical summary ready for practitioner review.',
      riskLevel: RiskLevel.urgent,
      active: true,
      updatedAt: DateTime(2026, 5, 11, 13, 10),
    ),
    PatientRecord(
      id: 'patient-3',
      name: 'Nadia M.',
      code: 'PT-1036',
      nextAction: 'Confirm appointment',
      notes: 'No outstanding documents.',
      riskLevel: RiskLevel.stable,
      active: true,
      updatedAt: DateTime(2026, 5, 10, 16, 45),
    ),
  ];

  static List<RevenueRecord> _seedRevenue() => [
    const RevenueRecord(
      id: 'revenue-1',
      label: 'Consultations',
      amount: 18400,
      status: RevenueStatus.collected,
      period: 'May week 2',
    ),
    const RevenueRecord(
      id: 'revenue-2',
      label: 'Pending invoices',
      amount: 6200,
      status: RevenueStatus.pending,
      period: 'May week 2',
    ),
    const RevenueRecord(
      id: 'revenue-3',
      label: 'Care packages',
      amount: 9700,
      status: RevenueStatus.collected,
      period: 'May week 1',
    ),
  ];

  static List<AuditRecord> _seedAudit() => [
    AuditRecord(
      id: 'audit-1',
      area: 'Patient',
      action: 'Care plan marked for review',
      details: 'Karim R. requires practitioner validation',
      createdAt: DateTime(2026, 5, 11, 13, 15),
    ),
    AuditRecord(
      id: 'audit-2',
      area: 'Revenue',
      action: 'Pending invoice noted',
      details: 'May week 2 pending balance added',
      createdAt: DateTime(2026, 5, 11, 12, 5),
    ),
    AuditRecord(
      id: 'audit-3',
      area: 'Task',
      action: 'Task closed',
      details: 'Signed treatment forms archived',
      createdAt: DateTime(2026, 5, 10, 17, 40),
    ),
  ];
}

enum Priority { low, medium, high }

enum RiskLevel { stable, watch, urgent }

enum RevenueStatus { collected, pending }

class TaskRecord {
  const TaskRecord({
    required this.id,
    required this.title,
    required this.owner,
    required this.due,
    required this.priority,
    required this.done,
  });

  final String id;
  final String title;
  final String owner;
  final String due;
  final Priority priority;
  final bool done;

  TaskRecord copyWith({bool? done}) => TaskRecord(
    id: id,
    title: title,
    owner: owner,
    due: due,
    priority: priority,
    done: done ?? this.done,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'owner': owner,
    'due': due,
    'priority': priority.name,
    'done': done,
  };

  factory TaskRecord.fromJson(Map<String, dynamic> json) => TaskRecord(
    id: json['id'] as String,
    title: json['title'] as String,
    owner: json['owner'] as String,
    due: json['due'] as String,
    priority: Priority.values.byName(json['priority'] as String),
    done: json['done'] as bool,
  );
}

class PatientRecord {
  const PatientRecord({
    required this.id,
    required this.name,
    required this.code,
    required this.nextAction,
    required this.notes,
    required this.riskLevel,
    required this.active,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String code;
  final String nextAction;
  final String notes;
  final RiskLevel riskLevel;
  final bool active;
  final DateTime updatedAt;

  PatientRecord copyWith({bool? active, DateTime? updatedAt}) => PatientRecord(
    id: id,
    name: name,
    code: code,
    nextAction: nextAction,
    notes: notes,
    riskLevel: riskLevel,
    active: active ?? this.active,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'nextAction': nextAction,
    'notes': notes,
    'riskLevel': riskLevel.name,
    'active': active,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory PatientRecord.fromJson(Map<String, dynamic> json) => PatientRecord(
    id: json['id'] as String,
    name: json['name'] as String,
    code: json['code'] as String,
    nextAction: json['nextAction'] as String,
    notes: json['notes'] as String,
    riskLevel: RiskLevel.values.byName(json['riskLevel'] as String),
    active: json['active'] as bool,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}

class RevenueRecord {
  const RevenueRecord({
    required this.id,
    required this.label,
    required this.amount,
    required this.status,
    required this.period,
  });

  final String id;
  final String label;
  final double amount;
  final RevenueStatus status;
  final String period;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'amount': amount,
    'status': status.name,
    'period': period,
  };

  factory RevenueRecord.fromJson(Map<String, dynamic> json) => RevenueRecord(
    id: json['id'] as String,
    label: json['label'] as String,
    amount: (json['amount'] as num).toDouble(),
    status: RevenueStatus.values.byName(json['status'] as String),
    period: json['period'] as String,
  );
}

class AuditRecord {
  const AuditRecord({
    required this.id,
    required this.area,
    required this.action,
    required this.details,
    required this.createdAt,
  });

  final String id;
  final String area;
  final String action;
  final String details;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'area': area,
    'action': action,
    'details': details,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AuditRecord.fromJson(Map<String, dynamic> json) => AuditRecord(
    id: json['id'] as String,
    area: json['area'] as String,
    action: json['action'] as String,
    details: json['details'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class AppPreferences {
  const AppPreferences({
    required this.compactLists,
    required this.reviewWindow,
    required this.reminderTone,
  });

  final bool compactLists;
  final String reviewWindow;
  final String reminderTone;

  AppPreferences copyWith({
    bool? compactLists,
    String? reviewWindow,
    String? reminderTone,
  }) => AppPreferences(
    compactLists: compactLists ?? this.compactLists,
    reviewWindow: reviewWindow ?? this.reviewWindow,
    reminderTone: reminderTone ?? this.reminderTone,
  );

  Map<String, dynamic> toJson() => {
    'compactLists': compactLists,
    'reviewWindow': reviewWindow,
    'reminderTone': reminderTone,
  };

  factory AppPreferences.fromJson(Map<String, dynamic> json) => AppPreferences(
    compactLists: json['compactLists'] as bool? ?? false,
    reviewWindow: json['reviewWindow'] as String? ?? 'Daily',
    reminderTone: json['reminderTone'] as String? ?? 'Quiet',
  );
}

class OperationsShell extends StatefulWidget {
  const OperationsShell({super.key});

  @override
  State<OperationsShell> createState() => _OperationsShellState();
}

class _OperationsShellState extends State<OperationsShell> {
  int _index = 0;

  static const _titles = [
    'Operations',
    'Patients',
    'Revenue',
    'Audit',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DashboardScreen(),
      const PatientScreen(),
      const RevenueScreen(),
      const AuditScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                'Local only',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.badge_outlined),
            selectedIcon: Icon(Icons.badge),
            label: 'Patients',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Revenue',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Audit',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = OperationsScope.of(context);

    return ListView(
      key: const ValueKey('dashboard-screen'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const BrandHeader(),
        const SizedBox(height: 18),
        ResponsiveMetricGrid(
          children: [
            MetricTile(
              label: 'Open tasks',
              value: '${store.openTasks}',
              icon: Icons.fact_check_outlined,
              tone: MetricTone.primary,
            ),
            MetricTile(
              label: 'Active records',
              value: '${store.activePatients}',
              icon: Icons.folder_shared_outlined,
              tone: MetricTone.teal,
            ),
            MetricTile(
              label: 'Flagged',
              value: '${store.flaggedPatients}',
              icon: Icons.priority_high_rounded,
              tone: MetricTone.copper,
            ),
            MetricTile(
              label: 'Collected',
              value: formatMoney(store.collectedRevenue),
              icon: Icons.payments_outlined,
              tone: MetricTone.green,
            ),
          ],
        ),
        const SizedBox(height: 22),
        SectionHeader(
          title: 'Today',
          action: TextButton.icon(
            key: const ValueKey('open-task-form'),
            onPressed: () => showTaskSheet(context),
            icon: const Icon(Icons.add_task),
            label: const Text('Add task'),
          ),
        ),
        const SizedBox(height: 8),
        if (store.tasks.isEmpty)
          const EmptyState(
            icon: Icons.fact_check_outlined,
            title: 'No tasks yet',
            message: 'Add the next operational action to start the day.',
          )
        else
          ...store.tasks.take(4).map((task) => TaskCard(task: task)),
        const SizedBox(height: 22),
        const SectionHeader(title: 'Operational focus'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Records stay on this device',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tasks, patient notes, revenue entries, and audit history are saved locally for daily business control.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 172,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('docs/featured.png', fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFF07111E).withValues(alpha: 0.92),
                    const Color(0xFF07111E).withValues(alpha: 0.52),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.secondary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      child: Text(
                        'OPERATIONS WORKSPACE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSecondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'DECLOQUEMENT ERIC PIERRE',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tasks, patient records, audits, and revenue in one private phone workspace.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PatientScreen extends StatelessWidget {
  const PatientScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = OperationsScope.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-patient-record',
        key: const ValueKey('add-patient'),
        onPressed: () => showPatientSheet(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add record'),
      ),
      body: ListView(
        key: const ValueKey('patients-screen'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          ResponsiveMetricGrid(
            children: [
              MetricTile(
                label: 'Active',
                value: '${store.activePatients}',
                icon: Icons.group_outlined,
                tone: MetricTone.primary,
              ),
              MetricTile(
                label: 'Watch list',
                value: '${store.flaggedPatients}',
                icon: Icons.health_and_safety_outlined,
                tone: MetricTone.copper,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Patient records'),
          const SizedBox(height: 8),
          if (store.patients.isEmpty)
            const EmptyState(
              icon: Icons.badge_outlined,
              title: 'No patient records',
              message: 'Create a local record with the next action and status.',
            )
          else
            ...store.patients.map((patient) => PatientCard(patient: patient)),
        ],
      ),
    );
  }
}

class RevenueScreen extends StatelessWidget {
  const RevenueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = OperationsScope.of(context);
    final total = store.collectedRevenue + store.pendingRevenue;
    final collectedRatio = total == 0 ? 0.0 : store.collectedRevenue / total;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-revenue-item',
        key: const ValueKey('add-revenue'),
        onPressed: () => showRevenueSheet(context),
        icon: const Icon(Icons.add_chart),
        label: const Text('Log item'),
      ),
      body: ListView(
        key: const ValueKey('revenue-screen'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          ResponsiveMetricGrid(
            children: [
              MetricTile(
                label: 'Collected',
                value: formatMoney(store.collectedRevenue),
                icon: Icons.account_balance_wallet_outlined,
                tone: MetricTone.green,
              ),
              MetricTile(
                label: 'Pending',
                value: formatMoney(store.pendingRevenue),
                icon: Icons.pending_actions_outlined,
                tone: MetricTone.copper,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Collection progress',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 14,
                      value: collectedRatio.clamp(0, 1),
                      backgroundColor: const Color(0xFFE6D8C3),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${(collectedRatio * 100).round()}% of tracked revenue is collected.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Revenue items'),
          const SizedBox(height: 8),
          if (store.revenue.isEmpty)
            const EmptyState(
              icon: Icons.insights_outlined,
              title: 'No revenue items',
              message: 'Log collected or pending revenue for local analysis.',
            )
          else
            ...store.revenue.map((record) => RevenueCard(record: record)),
        ],
      ),
    );
  }
}

class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = OperationsScope.of(context);

    return ListView(
      key: const ValueKey('audit-screen'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const SectionHeader(title: 'Audit log'),
        const SizedBox(height: 8),
        if (store.audit.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No audit activity',
            message:
                'New tasks, records, revenue, and settings updates appear here.',
          )
        else
          ...store.audit.map((item) => AuditCard(record: item)),
      ],
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = OperationsScope.of(context);
    final preferences = store.preferences;

    return ListView(
      key: const ValueKey('settings-screen'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DECLOQUEMENT ERIC PIERRE',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Private operational tracking for daily business control.',
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    StatusChip(label: 'No account'),
                    StatusChip(label: 'No cloud sync'),
                    StatusChip(label: 'Local storage'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: SwitchListTile(
            title: const Text('Compact list density'),
            subtitle: const Text('Show tighter task and record cards.'),
            value: preferences.compactLists,
            onChanged: (value) => store.updatePreferences(
              preferences.copyWith(compactLists: value),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _PreferencePicker(
          title: 'Review window',
          value: preferences.reviewWindow,
          values: const ['Daily', 'Weekly', 'Monthly'],
          onChanged: (value) => store.updatePreferences(
            preferences.copyWith(reviewWindow: value),
          ),
        ),
        const SizedBox(height: 12),
        _PreferencePicker(
          title: 'Reminder tone',
          value: preferences.reminderTone,
          values: const ['Quiet', 'Focused', 'Urgent'],
          onChanged: (value) => store.updatePreferences(
            preferences.copyWith(reminderTone: value),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.privacy_tip_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Privacy',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'The app does not use network services, accounts, analytics, advertising identifiers, contacts, location, camera, microphone, or files outside its own app storage.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PreferencePicker extends StatelessWidget {
  const _PreferencePicker({
    required this.title,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String title;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: [
                for (final item in values)
                  ButtonSegment<String>(value: item, label: Text(item)),
              ],
              selected: {value},
              onSelectionChanged: (selected) => onChanged(selected.single),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  const TaskCard({required this.task, super.key});

  final TaskRecord task;

  @override
  Widget build(BuildContext context) {
    final store = OperationsScope.of(context);
    final compact = store.preferences.compactLists;

    return Card(
      margin: EdgeInsets.only(bottom: compact ? 8 : 12),
      child: CheckboxListTile(
        value: task.done,
        onChanged: (_) => store.toggleTask(task.id),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            decoration: task.done ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text('${task.owner} - ${task.due}'),
        secondary: PriorityPill(priority: task.priority),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }
}

class PatientCard extends StatelessWidget {
  const PatientCard({required this.patient, super.key});

  final PatientRecord patient;

  @override
  Widget build(BuildContext context) {
    final store = OperationsScope.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        key: ValueKey('patient-${patient.id}'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                PatientDetailScreen(store: store, patientId: patient.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: riskColor(
                  patient.riskLevel,
                ).withValues(alpha: 0.14),
                foregroundColor: riskColor(patient.riskLevel),
                child: Text(initialFor(patient.name)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('${patient.code} - ${patient.nextAction}'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        StatusChip(
                          label: patient.active ? 'Active' : 'Archived',
                        ),
                        StatusChip(label: riskLabel(patient.riskLevel)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class PatientDetailScreen extends StatelessWidget {
  const PatientDetailScreen({
    required this.store,
    required this.patientId,
    super.key,
  });

  final OperationsStore store;
  final String patientId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final patient = store.patients.firstWhere(
          (item) => item.id == patientId,
          orElse: () => store.patients.first,
        );

        return Scaffold(
          appBar: AppBar(title: const Text('Patient detail')),
          body: ListView(
            key: const ValueKey('patient-detail-screen'),
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: riskColor(
                              patient.riskLevel,
                            ).withValues(alpha: 0.14),
                            foregroundColor: riskColor(patient.riskLevel),
                            child: Text(initialFor(patient.name)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  patient.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Text(patient.code),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      DetailRow(
                        label: 'Next action',
                        value: patient.nextAction,
                      ),
                      DetailRow(
                        label: 'Risk level',
                        value: riskLabel(patient.riskLevel),
                      ),
                      DetailRow(
                        label: 'Last update',
                        value: formatDateTime(patient.updatedAt),
                      ),
                      const Divider(height: 28),
                      Text(
                        'Notes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(patient.notes),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () =>
                    store.updatePatientStatus(patient.id, !patient.active),
                icon: Icon(
                  patient.active ? Icons.archive_outlined : Icons.unarchive,
                ),
                label: Text(
                  patient.active ? 'Archive record' : 'Reactivate record',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class RevenueCard extends StatelessWidget {
  const RevenueCard({required this.record, super.key});

  final RevenueRecord record;

  @override
  Widget build(BuildContext context) {
    final color = record.status == RevenueStatus.collected
        ? const Color(0xFF2D7D46)
        : const Color(0xFF96611F);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          foregroundColor: color,
          child: Icon(
            record.status == RevenueStatus.collected
                ? Icons.done_rounded
                : Icons.schedule_rounded,
          ),
        ),
        title: Text(
          record.label,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('${record.period} - ${statusLabel(record.status)}'),
        trailing: Text(
          formatMoney(record.amount),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class AuditCard extends StatelessWidget {
  const AuditCard({required this.record, super.key});

  final AuditRecord record;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
              foregroundColor: Theme.of(context).colorScheme.primary,
              child: Text(initialFor(record.area)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.action,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(record.details),
                  const SizedBox(height: 8),
                  Text(
                    '${record.area} - ${formatDateTime(record.createdAt)}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResponsiveMetricGrid extends StatelessWidget {
  const ResponsiveMetricGrid({required this.children, super.key});

  final List<MetricTile> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 680 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: constraints.maxWidth >= 680 ? 1.55 : 1.28,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: children,
        );
      },
    );
  }
}

enum MetricTone { primary, teal, copper, green }

class MetricTile extends StatelessWidget {
  const MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final MetricTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      MetricTone.primary => Theme.of(context).colorScheme.primary,
      MetricTone.teal => const Color(0xFF237A86),
      MetricTone.copper => const Color(0xFFA66B2F),
      MetricTone.green => const Color(0xFF2D7D46),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const Spacer(),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, this.action, super.key});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        ?action,
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 34, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class PriorityPill extends StatelessWidget {
  const PriorityPill({required this.priority, super.key});

  final Priority priority;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      Priority.low => const Color(0xFF237A86),
      Priority.medium => const Color(0xFFA66B2F),
      Priority.high => const Color(0xFFB63E31),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          priorityLabel(priority),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class DetailRow extends StatelessWidget {
  const DetailRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

Future<void> showTaskSheet(BuildContext context) {
  final store = OperationsScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => TaskForm(store: store),
  );
}

Future<void> showPatientSheet(BuildContext context) {
  final store = OperationsScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => PatientForm(store: store),
  );
}

Future<void> showRevenueSheet(BuildContext context) {
  final store = OperationsScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => RevenueForm(store: store),
  );
}

class TaskForm extends StatefulWidget {
  const TaskForm({required this.store, super.key});

  final OperationsStore store;

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _owner = TextEditingController();
  final _due = TextEditingController(text: 'Today');
  Priority _priority = Priority.medium;

  @override
  void dispose() {
    _title.dispose();
    _owner.dispose();
    _due.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: 'Add task',
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              key: const ValueKey('task-title'),
              controller: _title,
              label: 'Task',
              icon: Icons.task_alt,
            ),
            const SizedBox(height: 12),
            AppTextField(
              key: const ValueKey('task-owner'),
              controller: _owner,
              label: 'Owner',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 12),
            AppTextField(
              key: const ValueKey('task-due'),
              controller: _due,
              label: 'Due',
              icon: Icons.event_outlined,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<Priority>(
              initialValue: _priority,
              decoration: const InputDecoration(
                labelText: 'Priority',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              items: Priority.values
                  .map(
                    (priority) => DropdownMenuItem(
                      value: priority,
                      child: Text(priorityLabel(priority)),
                    ),
                  )
                  .toList(),
              onChanged: (priority) {
                if (priority != null) {
                  setState(() => _priority = priority);
                }
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('save-task'),
                onPressed: () async {
                  if (_formKey.currentState?.validate() != true) {
                    return;
                  }
                  await widget.store.addTask(
                    title: _title.text,
                    owner: _owner.text,
                    due: _due.text,
                    priority: _priority,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save task'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PatientForm extends StatefulWidget {
  const PatientForm({required this.store, super.key});

  final OperationsStore store;

  @override
  State<PatientForm> createState() => _PatientFormState();
}

class _PatientFormState extends State<PatientForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _nextAction = TextEditingController();
  final _notes = TextEditingController();
  RiskLevel _riskLevel = RiskLevel.stable;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _nextAction.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: 'Add patient record',
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              key: const ValueKey('patient-name'),
              controller: _name,
              label: 'Name',
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 12),
            AppTextField(
              key: const ValueKey('patient-code'),
              controller: _code,
              label: 'Record code',
              icon: Icons.qr_code_2,
            ),
            const SizedBox(height: 12),
            AppTextField(
              key: const ValueKey('patient-action'),
              controller: _nextAction,
              label: 'Next action',
              icon: Icons.next_plan_outlined,
            ),
            const SizedBox(height: 12),
            AppTextField(
              key: const ValueKey('patient-notes'),
              controller: _notes,
              label: 'Notes',
              icon: Icons.notes_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<RiskLevel>(
              initialValue: _riskLevel,
              decoration: const InputDecoration(
                labelText: 'Risk level',
                prefixIcon: Icon(Icons.health_and_safety_outlined),
              ),
              items: RiskLevel.values
                  .map(
                    (risk) => DropdownMenuItem(
                      value: risk,
                      child: Text(riskLabel(risk)),
                    ),
                  )
                  .toList(),
              onChanged: (risk) {
                if (risk != null) {
                  setState(() => _riskLevel = risk);
                }
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('save-patient'),
                onPressed: () async {
                  if (_formKey.currentState?.validate() != true) {
                    return;
                  }
                  await widget.store.addPatient(
                    name: _name.text,
                    code: _code.text,
                    nextAction: _nextAction.text,
                    riskLevel: _riskLevel,
                    notes: _notes.text,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save record'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RevenueForm extends StatefulWidget {
  const RevenueForm({required this.store, super.key});

  final OperationsStore store;

  @override
  State<RevenueForm> createState() => _RevenueFormState();
}

class _RevenueFormState extends State<RevenueForm> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _amount = TextEditingController();
  final _period = TextEditingController(text: 'Current week');
  RevenueStatus _status = RevenueStatus.collected;

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    _period.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: 'Log revenue',
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              key: const ValueKey('revenue-label'),
              controller: _label,
              label: 'Label',
              icon: Icons.sell_outlined,
            ),
            const SizedBox(height: 12),
            AppTextField(
              key: const ValueKey('revenue-amount'),
              controller: _amount,
              label: 'Amount',
              icon: Icons.payments_outlined,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                final parsed = double.tryParse((value ?? '').trim());
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            AppTextField(
              key: const ValueKey('revenue-period'),
              controller: _period,
              label: 'Period',
              icon: Icons.calendar_month_outlined,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<RevenueStatus>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(Icons.assignment_turned_in_outlined),
              ),
              items: RevenueStatus.values
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(statusLabel(status)),
                    ),
                  )
                  .toList(),
              onChanged: (status) {
                if (status != null) {
                  setState(() => _status = status);
                }
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('save-revenue'),
                onPressed: () async {
                  if (_formKey.currentState?.validate() != true) {
                    return;
                  }
                  await widget.store.addRevenue(
                    label: _label.text,
                    amount: double.parse(_amount.text.trim()),
                    status: _status,
                    period: _period.text,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save item'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FormSheet extends StatelessWidget {
  const FormSheet({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator:
          validator ??
          (value) {
            if ((value ?? '').trim().isEmpty) {
              return 'Required';
            }
            return null;
          },
    );
  }
}

String priorityLabel(Priority priority) => switch (priority) {
  Priority.low => 'Low',
  Priority.medium => 'Medium',
  Priority.high => 'High',
};

String riskLabel(RiskLevel riskLevel) => switch (riskLevel) {
  RiskLevel.stable => 'Stable',
  RiskLevel.watch => 'Watch',
  RiskLevel.urgent => 'Urgent',
};

Color riskColor(RiskLevel riskLevel) => switch (riskLevel) {
  RiskLevel.stable => const Color(0xFF237A86),
  RiskLevel.watch => const Color(0xFFA66B2F),
  RiskLevel.urgent => const Color(0xFFB63E31),
};

String statusLabel(RevenueStatus status) => switch (status) {
  RevenueStatus.collected => 'Collected',
  RevenueStatus.pending => 'Pending',
};

String formatMoney(double amount) {
  final rounded = amount.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < rounded.length; i++) {
    final remaining = rounded.length - i;
    buffer.write(rounded[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(' ');
    }
  }
  return '${buffer.toString()} MAD';
}

String formatDateTime(DateTime value) {
  final date =
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  final time =
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}

String initialFor(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
}
