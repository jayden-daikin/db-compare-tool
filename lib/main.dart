import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'state/comparison_state.dart';

void main() {
  runApp(const DbCompareApp());
}

class DbCompareApp extends StatelessWidget {
  const DbCompareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ComparisonState(),
      child: MaterialApp(
        title: 'DB Compare Tool',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ButtonStyle(
              mouseCursor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.disabled)
                      ? SystemMouseCursors.basic
                      : SystemMouseCursors.click),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: ButtonStyle(
              mouseCursor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.disabled)
                      ? SystemMouseCursors.basic
                      : SystemMouseCursors.click),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: ButtonStyle(
              mouseCursor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.disabled)
                      ? SystemMouseCursors.basic
                      : SystemMouseCursors.click),
            ),
          ),
          iconButtonTheme: IconButtonThemeData(
            style: ButtonStyle(
              mouseCursor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.disabled)
                      ? SystemMouseCursors.basic
                      : SystemMouseCursors.click),
            ),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
