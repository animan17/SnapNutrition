import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TestDateDialog extends StatelessWidget {
  const TestDateDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Date for Testing'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null && context.mounted) {
                Navigator.pop(context, date.toString().split(' ')[0]);
              }
            },
            child: const Text('Pick a Date'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Use Current Date'),
          ),
        ],
      ),
    );
  }
}