/// Bottom-navigation destinations, kept dependency-free so state and widgets
/// can both refer to them without import cycles.
abstract final class AppTab {
  static const int home = 0;
  static const int explore = 1;
  static const int collections = 2;
  static const int community = 3;
  static const int profile = 4;
}
