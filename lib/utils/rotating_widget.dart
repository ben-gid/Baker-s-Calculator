import 'package:flutter/material.dart';

class RotatingIcon extends StatefulWidget{
  final bool expanded;
  final double rotationFraction;
  final Duration duration;
  final Icon child;

  const RotatingIcon({
    required this.expanded,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.rotationFraction = 0.5,
    super.key,
  });

  @override
  State<RotatingIcon> createState() => _RotatingIconState();
}

class _RotatingIconState extends State<RotatingIcon> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _rotation = Tween<double>(begin: 0.0, end: widget.rotationFraction).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RotatingIcon oldWidget){
    super.didUpdateWidget(oldWidget);

    if (widget.expanded != oldWidget.expanded) {
      if (widget.expanded){
        _controller.forward();
      } else {
        _controller.reverse();
      } 
    } 
  }

  @override
  Widget build(BuildContext build) {
    return RotationTransition(turns: _rotation, child: widget.child);
  }
}