class AppConstants {
  // ── API ──────────────────────────────────────────────
  static const String baseUrl = 'https://kloqridebackendv2-production.up.railway.app';

  // ── App Info ─────────────────────────────────────────
  static const String appName    = 'KloqRide';
  static const String appVersion = '1.0.0';
  static const String currency   = '₹';
  static const String countryCode= '+91';

  // ── Storage Keys ─────────────────────────────────────
  static const String keyToken    = 'auth_token';
  static const String keyUserId   = 'user_id';
  static const String keyRole     = 'user_role';
  static const String keyName     = 'user_name';
  static const String keyPhone    = 'user_phone';
  static const String keyLanguage = 'app_language';

  // ── Languages ────────────────────────────────────────
  static const List<Map<String, String>> languages = [
    {'code': 'en', 'name': 'English',  'native': 'English'},
    {'code': 'hi', 'name': 'Hindi',    'native': 'हिन्दी'},
    {'code': 'bn', 'name': 'Bengali',  'native': 'বাংলা'},
  ];

  // ── Vehicle Types ─────────────────────────────────────
  static const List<Map<String, dynamic>> vehicleTypes = [
    {'type': 'bike',  'label': 'Bike',  'icon': '🏍️', 'capacity': 1},
    {'type': 'auto',  'label': 'Auto',  'icon': '🛺', 'capacity': 3},
    {'type': 'mini',  'label': 'Mini',  'icon': '🚗', 'capacity': 4},
    {'type': 'sedan', 'label': 'Sedan', 'icon': '🚙', 'capacity': 4},
    {'type': 'suv',   'label': 'SUV',   'icon': '🚐', 'capacity': 6},
  ];
}
