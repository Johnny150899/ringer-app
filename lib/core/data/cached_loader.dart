import 'package:flutter/foundation.dart';

/// Shows local data before the network request and retains it on failure.
class CachedLoader<T> extends ChangeNotifier {
  CachedLoader({required this.read, required this.fetch, required this.write});
  final Future<T?> Function() read;
  final Future<T> Function() fetch;
  final Future<void> Function(T) write;
  T? data;
  bool updating = false;
  bool cached = false;
  Object? error;
  bool _disposed = false;
  Future<void>? _pending;

  Future<void> start() async {
    try {
      data = await read();
    } catch (_) {
      /* Cache is optional. */
    }
    if (_disposed) return;
    cached = data != null;
    _notify();
    await refresh();
  }

  Future<void> refresh() =>
      _pending ??= _refresh().whenComplete(() => _pending = null);

  Future<void> _refresh() async {
    if (_disposed) return;
    updating = true;
    error = null;
    _notify();
    try {
      final fresh = await fetch();
      if (_disposed) return;
      data = fresh;
      cached = false;
      try {
        await write(fresh);
      } catch (_) {
        /* Keep fresh data. */
      }
    } catch (failure) {
      error = failure;
    } finally {
      updating = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
