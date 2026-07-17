import 'package:flutter/material.dart';

import 'src/shell/shell_scope.dart';
import 'src/shell/theme_controller.dart';
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

class MyToolBoxApp extends StatefulWidget {
  const MyToolBoxApp({super.key});

  @override
  State<MyToolBoxApp> createState() => _MyToolBoxAppState();
}

class _MyToolBoxAppState extends State<MyToolBoxApp> {
  final _theme = ThemeController();

  @override
  void initState() {
    super.initState();
    _theme.load();
  }

  @override
  void dispose() {
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _theme,
      builder: (context, _) => MaterialApp(
        title: 'Tool Box Mobile',
        debugShowCheckedModeBanner: false,
        themeMode: _theme.mode,
        theme: ThemeData(
          colorScheme:
              ColorScheme.fromSeed(seedColor: const Color(0xFF2DA44E)),
          useMaterial3: true,
        ),
        darkTheme: _githubSoftDarkTheme(),
        home: AppShell(theme: _theme),
      ),
    );
  }
}

/// Dark theme modeled on GitHub's "dark dimmed" (soft dark) palette.
ThemeData _githubSoftDarkTheme() {
  const canvas = Color(0xFF22272E); // canvas.default
  const inset = Color(0xFF1C2128); // canvas.inset
  const overlay = Color(0xFF2D333B); // canvas.overlay
  const fg = Color(0xFFADBAC7); // fg.default
  const fgMuted = Color(0xFF768390); // fg.muted
  const border = Color(0xFF444C56); // border.default
  const green = Color(0xFF57AB5A); // success.fg
  const greenBtn = Color(0xFF347D39); // btn.primary.bg
  const blue = Color(0xFF539BF5); // accent.fg

  const scheme = ColorScheme.dark(
    surface: canvas,
    onSurface: fg,
    surfaceContainerLowest: Color(0xFF171B21),
    surfaceContainerLow: inset,
    surfaceContainer: overlay,
    surfaceContainerHigh: overlay,
    surfaceContainerHighest: Color(0xFF373E47),
    primary: green,
    onPrimary: Colors.white,
    primaryContainer: greenBtn,
    onPrimaryContainer: Colors.white,
    secondary: blue,
    onSecondary: Color(0xFF0D1117),
    outline: fgMuted,
    outlineVariant: border,
    onSurfaceVariant: fgMuted,
    error: Color(0xFFE5534B),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    appBarTheme: const AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: fg,
    ),
    cardTheme: const CardThemeData(color: canvas),
    dividerColor: border,
  );
}

/// Hosts the active tool and the side panel (drawer) for switching tools.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.theme});

  final ThemeController theme;

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
          child: Text('Tool Box', style: theme.textTheme.titleMedium),
        ),
        for (final t in tools)
          NavigationDrawerDestination(
            icon: t.icon,
            label: Text(t.name),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 16, 28, 8),
          child: Divider(height: 1),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('ライト'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('ダーク'),
              ),
            ],
            selected: {widget.theme.isDark},
            onSelectionChanged: (s) => widget.theme.setDark(s.first),
            showSelectedIcon: false,
          ),
        ),
      ],
    );
  }
}
