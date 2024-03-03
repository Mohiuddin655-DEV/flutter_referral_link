import 'package:flutter/material.dart';
import 'package:flutter_referral_link/services/referral_service.dart';

class RedirectPage extends StatefulWidget {
  final String path;

  const RedirectPage({
    super.key,
    required this.path,
  });

  @override
  State<RedirectPage> createState() => _RedirectPageState();
}

class _RedirectPageState extends State<RedirectPage> {
  @override
  void initState() {
    ReferralService.i.storeIpByPath(widget.path);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.red,
    );
  }
}
