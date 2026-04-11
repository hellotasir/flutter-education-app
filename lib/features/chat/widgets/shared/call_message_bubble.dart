import 'package:flutter/material.dart';
import 'package:flutter_education_app/features/chat/models/chat_message_model.dart';

class CallMessageBubble extends StatelessWidget {
  const CallMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  final ChatMessageModel message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final call = message.callData;

    final isVideo = call?.callType == CallType.video;
    final isMissed = call?.callStatus == CallStatus.missed;
    final isDeclined = call?.callStatus == CallStatus.declined;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isVideo ? Icons.videocam_rounded : Icons.call_rounded,
          size: 14,
          color: isMe
              ? cs.onPrimary.withOpacity(0.8)
              : (isMissed || isDeclined ? cs.error : cs.primary),
        ),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.content,
              style: tt.bodySmall?.copyWith(
                color: isMe ? cs.onPrimary : cs.onSurface,
              ),
            ),
            if (call?.durationSeconds != null && call!.durationSeconds! > 0)
              Text(
                _fmtDuration(call.durationSeconds!),
                style: tt.labelSmall?.copyWith(
                  fontSize: 9,
                  color: isMe
                      ? cs.onPrimary.withOpacity(0.6)
                      : cs.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _fmtDuration(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) return '${h}h ${m}m ${sec}s';
    if (m > 0) return '${m}m ${sec}s';
    return '${sec}s';
  }
}
