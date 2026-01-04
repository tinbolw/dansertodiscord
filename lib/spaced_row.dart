import 'package:flutter/material.dart';

class SpacedRow extends StatelessWidget {
  final List<Widget> children;

  const SpacedRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 4,
      children: children,
    );
  }
}