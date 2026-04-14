import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

// ─────────────────────────────────────────────
// CONSTANTS — replace with your ZegoCloud keys
// ─────────────────────────────────────────────
final String kZegoAppID = dotenv.env['ZEGO_APP_ID']!; // Your App ID
final String kZegoAppSign = dotenv.env['ZEGO_APP_SIGN']!; // Your App Sign

class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
    required this.userID,
    required this.userName,
    required this.channel,
    this.isVideoCall = true,
  });

  final String userID;
  final String userName;
  final String channel;
  final bool isVideoCall;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  ZegoUIKitPrebuiltCallConfig _buildCallConfig() {
    final config = widget.isVideoCall
        ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
        : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();

    if (widget.isVideoCall) {
      config.turnOnCameraWhenJoining = true;
      config.turnOnMicrophoneWhenJoining = true;
      config.useSpeakerWhenJoining = true;
      config.bottomMenuBar.buttons = [
        ZegoCallMenuBarButtonName.toggleCameraButton,
        ZegoCallMenuBarButtonName.toggleMicrophoneButton,
        ZegoCallMenuBarButtonName.switchCameraButton,
        ZegoCallMenuBarButtonName.hangUpButton,
      ];
    } else {
      config.turnOnCameraWhenJoining = false;
      config.turnOnMicrophoneWhenJoining = true;
      config.useSpeakerWhenJoining = false;
      config.bottomMenuBar.buttons = [
        ZegoCallMenuBarButtonName.toggleMicrophoneButton,
        ZegoCallMenuBarButtonName.switchAudioOutputButton,
        ZegoCallMenuBarButtonName.hangUpButton,
      ];
    }

    return config;
  }

  ZegoUIKitPrebuiltCallEvents _buildEvents() {
    return ZegoUIKitPrebuiltCallEvents(
      onHangUpConfirmation:
          (
            ZegoCallHangUpConfirmationEvent event,
            Future<bool> Function() defaultAction,
          ) async {
            debugPrint('User tapped hang up');

            // 👉 Example: show confirmation dialog
            bool? shouldLeave = await _showHangUpDialog(context);

            if (shouldLeave!) {
              // 🔥 Important: this actually exits the call
              return await defaultAction.call();
            } else {
              return false;
            }
          },

      // ✅ Replaces the old onOnlySelfInRoom — handles all call-end reasons
      onCallEnd: (ZegoCallEndEvent event, VoidCallback defaultAction) {
        debugPrint('Call ended, reason: ${event.reason}');
        // MUST call defaultAction or navigate manually — SDK will not pop automatically
        defaultAction.call();
      },
    );
  }

  // ✅ Returns Future<bool?> to match ZegoCallHangUpConfirmationCallback
  Future<bool?> _showHangUpDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'End Call',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to end the call?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B5C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'End Call',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ZegoUIKitPrebuiltCall(
      appID: kZegoAppID as int,
      appSign: kZegoAppSign,
      userID: widget.userID,
      userName: widget.userName,
      callID: widget.channel,
      config: _buildCallConfig(),
      events: _buildEvents(),
    );
  }
}
