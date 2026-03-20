import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_education_app/logic/services/connectivity_service.dart';
import '../../screens/app/error_screen.dart';

class NetworkGuard extends StatefulWidget {
  final Widget child;

  const NetworkGuard({super.key, required this.child});

  @override
  State<NetworkGuard> createState() => _NetworkGuardState();
}

class _NetworkGuardState extends State<NetworkGuard> {
  final ConnectivityService _service = ConnectivityService();

  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool _isOnline = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _check();

    _sub = _service.connectivityStream.listen((results) {
      final online = results.isNotEmpty;

      if (mounted) {
        setState(() => _isOnline = online);
      }
    });
  }

  Future<void> _check() async {
    final online = await _service.isOnline();
    if (!mounted) return;

    setState(() {
      _isOnline = online;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isOnline) {
      return ErrorScreen(errorType: ErrorType.network, onRetry: _check);
    }

    return widget.child;
  }
}
