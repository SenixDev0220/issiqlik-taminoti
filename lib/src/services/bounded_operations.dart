import 'dart:async';

class BatchResult {
  const BatchResult({required this.completed, required this.failed, required this.uncertain});
  final int completed;
  final int failed;
  final int uncertain;
  bool get complete => failed == 0 && uncertain == 0;
}

/// Bounds concurrency and waits for every started task. A timeout is explicitly
/// uncertain: the backend may commit later, so callers must retain stable IDs.
Future<BatchResult> runBoundedBatches(List<Future<void> Function()> tasks, {
  int concurrency = 3,
  Duration timeout = const Duration(seconds: 20),
}) async {
  if (concurrency < 1 || concurrency > 8) throw ArgumentError.value(concurrency);
  var next = 0;
  var complete = 0;
  var failed = 0;
  var uncertain = 0;
  Future<void> worker() async {
    while (next < tasks.length) {
      final task = tasks[next++];
      try {
        await Future<void>.sync(task).timeout(timeout);
        complete++;
      } on TimeoutException {
        uncertain++;
      } catch (_) {
        failed++;
      }
    }
  }
  await Future.wait(List.generate(tasks.length < concurrency ? tasks.length : concurrency, (_) => worker()));
  return BatchResult(completed: complete, failed: failed, uncertain: uncertain);
}

class PartialOperationException implements Exception {
  const PartialOperationException(this.result);
  final BatchResult result;
}
