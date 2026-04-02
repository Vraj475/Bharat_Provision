import 'package:flutter/material.dart';

class LogoutRedirectPage extends StatefulWidget {
  const LogoutRedirectPage({super.key});

  @override
  State<LogoutRedirectPage> createState() => _LogoutRedirectPageState();
}

class _LogoutRedirectPageState extends State<LogoutRedirectPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.shrink());
  }
}
