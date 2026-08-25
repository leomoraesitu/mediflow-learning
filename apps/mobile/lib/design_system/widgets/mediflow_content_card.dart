import 'package:flutter/material.dart';
import 'package:mediflow_mobile/design_system/app_spacing.dart';

class MediFlowContentCard extends StatelessWidget {
  const MediFlowContentCard({required this.child, super.key});

  final Widget child;

  static const double _maxWidth = 480;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: SizedBox(
            width: double.infinity,
            child: Card(
              margin: const EdgeInsets.all(AppSpacing.lg),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
