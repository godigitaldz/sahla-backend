import 'dart:async';

class DebounceService {
  static final DebounceService _instance = DebounceService._internal();
  factory DebounceService() => _instance;
  DebounceService._internal();

  Timer? _timer;

  /// Debounce a function call by the specified duration
  /// If called again before the duration expires, the previous call is canceled
  void call(Function function,
      {Duration duration = const Duration(milliseconds: 300)}) {
    _timer?.cancel();
    _timer = Timer(duration, () {
      function();
    });
  }

  /// Cancel the current debounced operation
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Dispose of the debounce service
  void dispose() {
    cancel();
  }
}
