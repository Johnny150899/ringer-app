import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringer_app/core/data/cached_loader.dart';

void main() {
  test(
    'cached data is visible while refresh is pending; failed refresh retains it',
    () async {
      final response = Completer<List<int>>();
      final fetching = Completer<void>();
      var writes = 0;
      final loader = CachedLoader<List<int>>(
        read: () async => [1, 2],
        fetch: () {
          fetching.complete();
          return response.future;
        },
        write: (_) async {
          writes++;
        },
      );
      final started = loader.start();
      await fetching.future;
      expect(loader.data, [1, 2]);
      expect(loader.cached, isTrue);
      expect(loader.updating, isTrue);
      response.completeError(Exception('offline'));
      await started;
      expect(loader.data, [1, 2]);
      expect(loader.error, isNotNull);
      expect(loader.updating, isFalse);
      expect(writes, 0);
      loader.dispose();
    },
  );

  test(
    'successful empty response removes stale items even if cache write fails',
    () async {
      final loader = CachedLoader<List<int>>(
        read: () async => [1],
        fetch: () async => [],
        write: (_) async => throw Exception('disk full'),
      );
      await loader.start();
      expect(loader.data, isEmpty);
      expect(loader.cached, isFalse);
      expect(loader.error, isNull);
      loader.dispose();
    },
  );

  test(
    'retry after cold offline start recovers and concurrent retries share request',
    () async {
      var calls = 0;
      final retry = Completer<List<int>>();
      final loader = CachedLoader<List<int>>(
        read: () async => null,
        fetch: () {
          calls++;
          if (calls == 1) throw Exception('offline');
          return retry.future;
        },
        write: (_) async {},
      );
      await loader.start();
      expect(loader.data, isNull);
      final first = loader.refresh();
      final second = loader.refresh();
      retry.complete([3]);
      await Future.wait([first, second]);
      expect(calls, 2);
      expect(loader.data, [3]);
      expect(loader.error, isNull);
      loader.dispose();
    },
  );
}
