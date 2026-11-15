import 'package:flutter/material.dart';

class NoPushAnimationMaterialPageRoute<T> extends MaterialPageRoute<T> {
  NoPushAnimationMaterialPageRoute({required super.builder, super.settings});

  @override
  Duration get transitionDuration => Duration.zero; // disable push animation

  @override
  Duration get reverseTransitionDuration => Duration.zero; // avoid overlapping pages during replacement
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
