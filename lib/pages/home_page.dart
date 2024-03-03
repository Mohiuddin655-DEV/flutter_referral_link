import 'package:flutter/material.dart';

import '../services/referral_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final etField = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Home",
          style: TextStyle(
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Theme
            .of(context)
            .primaryColor,
      ),
      body: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: TextField(
                controller: etField,
                decoration: const InputDecoration(
                  hintText: "LINK",
                ),
              ),
            ),
            const SizedBox(height: 24),
            XButton(
              text: "Plan 1",
              onClick: () {
                ReferralService.i
                    .generateCode(uid: "user_1", plan: 1)
                    .then((v) => setState(() => etField.text = v));
              },
            ),
            const SizedBox(height: 24),
            XButton(
              text: "Plan 2",
              onClick: () {
                ReferralService.i
                    .generateCode(uid: "user_1", plan: 2)
                    .then((v) => setState(() => etField.text = v));
              },
            ),
            const SizedBox(height: 24),
            XButton(
              text: "Plan 3",
              onClick: () {
                ReferralService.i
                    .generateCode(uid: "user_1", plan: 3)
                    .then((v) => setState(() => etField.text = v));
              },
            ),
            const SizedBox(height: 24),
            XButton(
              text: "Store IP",
              onClick: () {
                ReferralService.i.storeIpByPath(etField.text);
              },
            ),
            const SizedBox(height: 24),
            XButton(
              text: "Redeem",
              onClick: () {
                ReferralService.i.redeem("user_2");
              },
            ),
          ],
        ),
      ),
    );
  }
}

class XButton extends StatelessWidget {
  final String text;
  final VoidCallback onClick;

  const XButton({
    super.key,
    required this.text,
    required this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClick,
      child: Container(
        decoration: BoxDecoration(
          color: Theme
              .of(context)
              .primaryColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
