import '../constants/app_enums.dart';

extension LinkPriorityX on LinkPriority {
  String get label {
    switch (this) {
      case LinkPriority.high:
        return 'High';
      case LinkPriority.normal:
        return 'Normal';
      case LinkPriority.low:
        return 'Low';
    }
  }

  static LinkPriority fromString(String value) {
    switch (value.toLowerCase()) {
      case 'high':
        return LinkPriority.high;
      case 'low':
        return LinkPriority.low;
      default:
        return LinkPriority.normal;
    }
  }
}
