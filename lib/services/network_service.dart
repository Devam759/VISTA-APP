import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// Central Network & Internet Service providing real-time connectivity status.
class NetworkService {
  NetworkService._internal();
  static final NetworkService instance = NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  final _controller = StreamController<bool>.broadcast();
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Initializes network listener
  void initialize() {
    _checkInitialStatus();

    _subscription = _connectivity.onConnectivityChanged.listen((results) async {
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (!hasNetwork) {
        _updateStatus(false);
      } else {
        final hasInternet = await _checkInternetAccess();
        _updateStatus(hasInternet);
      }
    });
  }

  Future<void> _checkInitialStatus() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (hasNetwork) {
        final hasInternet = await _checkInternetAccess();
        _updateStatus(hasInternet);
      } else {
        _updateStatus(false);
      }
    } catch (e) {
      debugPrint('NetworkService init error: $e');
    }
  }

  Future<bool> _checkInternetAccess() async {
    if (kIsWeb) return true; // Browser handles network routing directly
    try {
      return await InternetConnection().hasInternetAccess;
    } catch (_) {
      return true;
    }
  }

  void _updateStatus(bool isOnline) {
    if (_isOnline != isOnline) {
      _isOnline = isOnline;
      _controller.add(_isOnline);
      debugPrint('NetworkStatus: ${_isOnline ? "ONLINE" : "OFFLINE"}');
    }
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
