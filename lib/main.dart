import 'package:flutter/material.dart';

import 'src/shell/shell_scope.dart';
import 'src/tools/github_project/board_screen.dart';
import 'src/tools/tool.dart';

/// Registry of all tools in the box. Add new tools here — the side panel
/// picks them up automatically.
final tools = <Tool>[
  Tool(
    id: 'github_project',
    name: 'GitHub Projects',
    icon: ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.asset(
        'assets/icons/github_project.png',
        width: 26,
        height: 26,
        fit: BoxFit.cover,
      ),
    ),
    builder: (_) => const GitHubProjectBoardScreen(),
  ),
];

void main() => runApp(const MyToolBoxApp());

class MyToolBoxApp extends StatelessWidget {
  const MyToolBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Tool Box',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2DA44E)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2DA44E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}

/// Hosts the active tool and the side panel (drawer) for switching tools.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _activeIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tool = tools[_activeIndex];
    return Scaffold(
      key: _scaffoldKey,
      drawer: _drawer(context),
      // Each tool provides its own Scaffold/AppBar. ShellScope lets a tool's
      // app bar open this outer drawer.
      body: ShellScope(
        openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
        child: Builder(builder: tool.builder),
      ),
      drawerEdgeDragWidth: 40,
    );
  }

  Widget _drawer(BuildContext context) {
    final theme = Theme.of(context);
    return NavigationDrawer(
      selectedIndex: _activeIndex,
      onDestinationSelected: (i) {
        setState(() => _activeIndex = i);
        Navigator.pop(context);
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 16, 16),
          child: Row(
            children: [
              Icon(Icons.home_repair_service,
                  color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text('My Tool Box', style: theme.textTheme.titleMedium),
            ],
          ),
        ),
        for (final t in tools)
          NavigationDrawerDestination(
            icon: t.icon,
            label: Text(t.name),
          ),
      ],
    );
  }
}
