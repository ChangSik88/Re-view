import 'package:flutter/material.dart';

class StoryFieldDialog extends StatefulWidget {
  final String label, initial;
  const StoryFieldDialog(
      {super.key, required this.label, required this.initial});
  @override
  State<StoryFieldDialog> createState() => _StoryFieldDialogState();
}

class _StoryFieldDialogState extends State<StoryFieldDialog> {
  late final controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text('${widget.label} 수정'),
          content: TextField(
              controller: controller,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              maxLength: 1000,
              decoration:
                  InputDecoration(hintText: '${widget.label} 정보를 입력해 주세요')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소')),
            FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('수정 완료'))
          ]);
}
