import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'pages/home_page.dart';
import 'pages/redirect_page.dart';
import 'routes.dart';

GoRouter router = GoRouter(
  errorBuilder: (context, state) => const ErrorScreen(),
  routes: <RouteBase>[
    GoRoute(
      path: kHome,
      builder: (context, state) {
        return const HomePage();
      },
      routes: <RouteBase>[
        GoRoute(
          name: kReferral,
          path: kReferral,
          builder: (context, state) {
            return RedirectPage(path: state.uri.toString());
          },
        ),
      ],
    ),
  ],
);

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Error",
          style: TextStyle(
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        backgroundColor: Theme
            .of(context)
            .primaryColor,
      ),
      body: SafeArea(
        child: Center(
          child: Text(
            "No screen found!",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }
}
