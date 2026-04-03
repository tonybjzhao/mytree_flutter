import 'package:flutter/material.dart';

import 'home_page.dart';
import 'tree_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final treeService = await TreeService.create();
  runApp(MyTreeApp(treeService: treeService));
}

/// Root widget: calm theme and single [HomePage].
class MyTreeApp extends StatelessWidget {
  const MyTreeApp({super.key, required this.treeService});

  final TreeService treeService;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF4A7C6E);

    return MaterialApp(
      title: 'MyTree',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
          surface: const Color(0xFFEFF5F0),
        ),
        scaffoldBackgroundColor: const Color(0xFFEFF5F0),
      ),
      home: HomePage(treeService: treeService),
    );
  }
}
