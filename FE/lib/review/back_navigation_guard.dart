import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Preserve normal route pops; handle back explicitly when a tab is the root.
class BackNavigationGuard extends StatefulWidget {
  final bool isHome;
  final Widget child;
  const BackNavigationGuard(
      {super.key, required this.isHome, required this.child});

  @override
  State<BackNavigationGuard> createState() => _BackNavigationGuardState();
}

class _BackNavigationGuardState extends State<BackNavigationGuard> {
  bool confirming = false;

  Future<void> handleRootBack() async {
    if (confirming) return;
    if (!widget.isHome) {
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }
    confirming = true;
    final exit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('앱을 종료할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('종료'),
          ),
        ],
      ),
    );
    confirming = false;
    if (mounted && exit == true) await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
        canPop: Navigator.canPop(context),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) handleRootBack();
        },
        child: widget.child,
      );
}
