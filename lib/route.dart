import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'details_page.dart';
import 'home_page.dart';
import 'inner_details_page.dart';

GoRouter router = GoRouter(
  errorBuilder: (context, state) => const ErrorScreen(),
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) {
        return const HomePage();
      },
      routes: <RouteBase>[
        GoRoute(
          path: 'details',
          builder: (context, state) {
            var data = state.extra;
            var path = state.uri.toString();
            return DetailsPage(
              path: path,
              data: data is String ? data : "",
            );
          },
        ),
        GoRoute(
          name: "sub_details",
          path: 'sub_details/:page/:sq',
          builder: (context, state) {
            var data = state.extra;
            var path = state.uri.toString();
            return SubDetailsPage(
              path: path,
              data: data is String ? data : "",
            );
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
        backgroundColor: Theme.of(context).primaryColor,
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
