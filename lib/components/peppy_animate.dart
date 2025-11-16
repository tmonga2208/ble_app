import 'package:flutter/material.dart';

class PeppyLogoAnimation extends StatefulWidget {
  const PeppyLogoAnimation({super.key});

  @override
  State<PeppyLogoAnimation> createState() => _PeppyLogoAnimationState();
}

class _PeppyLogoAnimationState extends State<PeppyLogoAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scale = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Image.asset("assets/images/peppy.png", width: 350, height: 350),
    );
  }
}
