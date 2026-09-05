import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LockHoldDialog extends StatefulWidget {
  final DateTime date;
  final String title;
  const LockHoldDialog({super.key, required this.date, this.title = 'രജിസ്റ്റർ ലോക്ക് ചെയ്തിരിക്കുന്നു'});

  @override
  State<LockHoldDialog> createState() => _LockHoldDialogState();
}

class _LockHoldDialogState extends State<LockHoldDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isUnlocked = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _isUnlocked = true);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.of(context).pop(true);
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${DateFormat('dd-MMM-yyyy').format(widget.date)} തിയതിക്കായുള്ള രജിസ്റ്റർ മുൻപേ സേവ് ചെയ്തിട്ടുള്ളതാണ്.\n\nഅബദ്ധത്തിൽ മാറ്റങ്ങൾ വരാതിരിക്കാൻ ഇത് ലോക്ക് ചെയ്തിരിക്കുന്നു. തിരുത്തലുകൾ വരുത്താൻ താഴെയുള്ള ഐക്കണിൽ 5 സെക്കൻഡ് അമർത്തി പിടിക്കുക.',
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          GestureDetector(
            onTapDown: (_) => _controller.forward(),
            onTapUp: (_) => _controller.reverse(),
            onTapCancel: () => _controller.reverse(),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: _controller.value,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                        backgroundColor: Colors.white12,
                        strokeWidth: 6,
                      ),
                    ),
                    Icon(
                      _isUnlocked ? Icons.lock_open : Icons.lock,
                      color: _isUnlocked ? Colors.greenAccent : Colors.redAccent,
                      size: 40,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _isUnlocked ? 'അൺലോക്ക് ചെയ്തു!' : 'പുതിയൊരു തിയതി തിരഞ്ഞെടുക്കാൻ ദയവായി Cancel ക്ലിക്ക് ചെയ്യുക',
            style: TextStyle(
              color: _isUnlocked ? Colors.greenAccent : Colors.white54,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
