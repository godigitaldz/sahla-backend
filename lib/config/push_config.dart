/// Configure which push provider to use at build-time.
/// Set via --dart-define=USE_FCM=false to disable FCM, otherwise enabled by default.
class PushConfig {
  static const bool useFcm =
      bool.fromEnvironment('USE_FCM', defaultValue: true);
}
