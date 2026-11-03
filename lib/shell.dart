import 'package:flutter/material.dart';
import 'updater.dart';
import 'screens/grades_tab.dart';
import 'screens/home_tab.dart';
import 'screens/reports_tab.dart';
import 'screens/settings_tab.dart';
import 'screens/students_tab.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;
  void go(int i) => setState(() => index = i);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Updater.check(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeTab(go: go),
      const StudentsTab(),
      const GradesTab(),
      const ReportsTab(),
      const SettingsTab(),
    ];
    return Scaffold(
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'الطلاب'),
          NavigationDestination(icon: Icon(Icons.grading_outlined), selectedIcon: Icon(Icons.grading), label: 'الدرجات'),
          NavigationDestination(icon: Icon(Icons.print_outlined), selectedIcon: Icon(Icons.print), label: 'التقارير'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }
}
