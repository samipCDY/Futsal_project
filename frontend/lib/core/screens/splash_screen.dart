import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _splashImage = AssetImage('assets/images/splash.jpg');

/// The full-screen Futsal Finder splash picture.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SizedBox.expand(child: Image(image: _splashImage, fit: BoxFit.cover)),
      ),
    );
  }
}

/// Shows [SplashScreen] for a moment when the app opens, then fades to [child].
class SplashGate extends StatefulWidget {
  final Widget child;

  const SplashGate({super.key, required this.child});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(_splashImage, context);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: _done ? widget.child : const SplashScreen(),
    );
  }
}
