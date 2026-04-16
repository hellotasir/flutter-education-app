import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

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
  // ✅ Moved inside the class — accessed lazily after dotenv.load() is done
  int get _appID => int.parse(dotenv.env['ZEGO_APP_ID']!);
  String get _appSign => dotenv.env['ZEGO_APP_SIGN']!;

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

            final bool? shouldLeave = await _showHangUpDialog(context);

            if (shouldLeave == true) {
              return await defaultAction.call();
            } else {
              return false;
            }
          },

      onCallEnd: (ZegoCallEndEvent event, VoidCallback defaultAction) {
        debugPrint('Call ended, reason: ${event.reason}');
        defaultAction.call();
      },
    );
  }

  Future<bool?> _showHangUpDialog(BuildContext context) {
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
      appID: _appID,
      appSign: _appSign,   
      userID: widget.userID,
      userName: widget.userName,
      callID: widget.channel,
      config: _buildCallConfig(),
      events: _buildEvents(),
    );
  }
}
