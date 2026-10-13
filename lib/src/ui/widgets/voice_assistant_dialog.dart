import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/app_localization.dart';
import '../../services/voice_assistant_service.dart';

/// Modal dialog for voice interaction with pulsing visual feedback.
class VoiceAssistantDialog extends StatefulWidget {
  const VoiceAssistantDialog({super.key});

  static Future<VoiceCommandResult?> show(BuildContext context) {
    return showModalBottomSheet<VoiceCommandResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VoiceAssistantDialog(),
    );
  }

  @override
  State<VoiceAssistantDialog> createState() => _VoiceAssistantDialogState();
}

class _VoiceAssistantDialogState extends State<VoiceAssistantDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  late final Animation<double> _scaleAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
    CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
  );

  String _transcript = '';
  VoiceCommandResult? _detectedResult;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _startVoiceSession();
  }

  Future<void> _startVoiceSession() async {
    final available = await VoiceAssistantService.instance.initialize();
    if (!mounted) return;

    setState(() => _initializing = false);

    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech recognition not available or permission denied.'),
        ),
      );
      Navigator.pop(context);
      return;
    }

    await HapticFeedback.selectionClick();

    await VoiceAssistantService.instance.startListening(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _transcript = result.rawTranscript;
          _detectedResult = result;
        });

        // If intent recognized with final certainty or silence
        if (result.intent != VoiceIntentType.unknown && result.rawTranscript.trim().length > 3) {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) {
              Navigator.pop(context, result);
            }
          });
        }
      },
    );
  }

  @override
  void dispose() {
    VoiceAssistantService.instance.stopListening();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTamil = AppLocale.instance.current == AppLanguage.tamil;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isTamil ? 'பேசுங்கள்...' : 'Listening...',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            isTamil
              ? 'எ.கா: "குறைந்த இருப்பு", "காலாவதி", "சேர் 10 பால்", "அரிசி"'
              : 'Try: "Low stock", "Expiring soon", "Add 5 Milk", "Sugar"',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // Pulsing microphone button
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
              ),
              child: Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                  ),
                  child: const Icon(Icons.mic, color: Colors.white, size: 32),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Recognized text output
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(minHeight: 56),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _transcript.isEmpty
                  ? (_initializing
                      ? 'Initializing voice engine...'
                      : (isTamil ? 'கேட்கிறது...' : 'Say something...'))
                  : '"$_transcript"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontStyle: _transcript.isEmpty ? FontStyle.italic : FontStyle.normal,
                fontWeight: _transcript.isEmpty ? FontWeight.normal : FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isTamil ? 'ரத்து செய்' : 'Cancel'),
              ),
              if (_detectedResult != null && _detectedResult!.rawTranscript.isNotEmpty) ...[
                const SizedBox(width: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: Text(isTamil ? 'செயல்படுத்து' : 'Apply'),
                  onPressed: () => Navigator.pop(context, _detectedResult),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
