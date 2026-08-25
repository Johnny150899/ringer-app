class NetworkPolicy {
  NetworkPolicy._();

  static const Duration requestTimeout = Duration(seconds: 8);
  static const Duration mediaTimeout = Duration(seconds: 15);
  static const Duration leagueCacheMaxAge = Duration(hours: 6);
  static const Duration newsCacheMaxAge = Duration(hours: 2);
}
