import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';
import 'auth_service.dart';

class ApiService {
  static final String _base = AppConstants.baseUrl;

  // ── Headers ─────────────────────────────────────────────
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
  };

  static Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${AuthService.token}',
  };

  // ── Generic request handler ──────────────────────────────
  static Future<Map<String, dynamic>> _handle(http.Response res) async {
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return {'success': true, 'data': data, 'status': res.statusCode};
    }
    String error = 'Something went wrong';
    if (data is Map) {
      if (data['detail'] is String)      error = data['detail'];
      else if (data['detail'] is List)   error = (data['detail'] as List).join(', ');
    }
    return {'success': false, 'error': error, 'status': res.statusCode};
  }

  // ═══════════════════════════════════════════════════════
  //  AUTH
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> sendOtp(String phone, String role) async {
    final res = await http.post(Uri.parse('$_base/auth/otp/send'),
      headers: _headers,
      body: jsonEncode({'phone': phone, 'role': role}));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> otpLogin(String phone, String otp) async {
    final res = await http.post(Uri.parse('$_base/auth/otp/login'),
      headers: _headers,
      body: jsonEncode({'phone': phone, 'otp': otp}));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> passwordLogin(String phone, String password) async {
    final res = await http.post(Uri.parse('$_base/auth/password/login'),
      headers: _headers,
      body: jsonEncode({'phone': phone, 'password': password}));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> registerRider(Map<String, dynamic> body) async {
    final res = await http.post(Uri.parse('$_base/auth/rider/register'),
      headers: _headers, body: jsonEncode(body));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> registerDriver(Map<String, dynamic> body) async {
    final res = await http.post(Uri.parse('$_base/auth/driver/register'),
      headers: _headers, body: jsonEncode(body));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getMe() async {
    final res = await http.get(Uri.parse('$_base/auth/me'),
      headers: _authHeaders);
    return _handle(res);
  }

  // ═══════════════════════════════════════════════════════
  //  RIDER
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> estimateFare({
    required double pickupLat, required double pickupLng,
    required double dropLat,   required double dropLng,
    required String vehicleType,
    String serviceType = 'ride',
  }) async {
    final res = await http.post(Uri.parse('$_base/rider/trips/estimate'),
      headers: _authHeaders,
      body: jsonEncode({
        'pickup_lat'  : pickupLat,  'pickup_lng': pickupLng,
        'drop_lat'    : dropLat,    'drop_lng'  : dropLng,
        'vehicle_type': vehicleType,'service_type': serviceType,
      }));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> bookTrip(Map<String, dynamic> body) async {
    final res = await http.post(Uri.parse('$_base/rider/trips/book'),
      headers: _authHeaders, body: jsonEncode(body));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getActiveTrip() async {
    final res = await http.get(Uri.parse('$_base/rider/trips/active'),
      headers: _authHeaders);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getRiderHistory({int limit = 20, int offset = 0}) async {
    final res = await http.get(
      Uri.parse('$_base/rider/trips/history?limit=$limit&offset=$offset'),
      headers: _authHeaders);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> cancelRiderTrip(int tripId, String reason) async {
    final res = await http.post(Uri.parse('$_base/rider/trips/$tripId/cancel'),
      headers: _authHeaders, body: jsonEncode({'reason': reason}));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> rateDriver(int tripId, int score, String? comment) async {
    final res = await http.post(Uri.parse('$_base/rider/trips/$tripId/rate'),
      headers: _authHeaders,
      body: jsonEncode({'score': score, 'comment': comment}));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> applyPromo(String code, double fare) async {
    final res = await http.get(
      Uri.parse('$_base/rider/promo/apply?code=$code&fare=$fare'),
      headers: _authHeaders);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getSavedAddresses() async {
    final res = await http.get(Uri.parse('$_base/rider/addresses'),
      headers: _authHeaders);
    return _handle(res);
  }

  // ═══════════════════════════════════════════════════════
  //  DRIVER
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> updateLocation(double lat, double lng) async {
    final res = await http.patch(
      Uri.parse('$_base/driver/location?lat=$lat&lng=$lng'),
      headers: _authHeaders);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> toggleOnline() async {
    final res = await http.patch(Uri.parse('$_base/driver/toggle-online'),
      headers: _authHeaders);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getAvailableTrips() async {
    final res = await http.get(Uri.parse('$_base/driver/trips/available'),
      headers: _authHeaders);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getDriverActiveTrip() async {
    final res = await http.get(Uri.parse('$_base/driver/trips/active'),
      headers: _authHeaders);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> acceptTrip(int tripId) async {
    final res = await http.patch(Uri.parse('$_base/driver/trips/$tripId/accept'),
      headers: _authHeaders);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> markArrived(int tripId) async {
    final res = await http.patch(Uri.parse('$_base/driver/trips/$tripId/arrived'),
      headers: _authHeaders);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> startTrip(int tripId) async {
    final res = await http.patch(Uri.parse('$_base/driver/trips/$tripId/start'),
      headers: _authHeaders);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> completeTrip(int tripId) async {
    final res = await http.patch(Uri.parse('$_base/driver/trips/$tripId/complete'),
      headers: _authHeaders);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> cancelDriverTrip(int tripId, String reason) async {
    final res = await http.patch(Uri.parse('$_base/driver/trips/$tripId/cancel'),
      headers: _authHeaders, body: jsonEncode({'reason': reason}));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getEarningsSummary() async {
    final res = await http.get(Uri.parse('$_base/driver/earnings/summary'),
      headers: _authHeaders);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> requestWithdrawal(
      double amount, String? upiId) async {
    final res = await http.post(Uri.parse('$_base/driver/earnings/withdraw'),
      headers: _authHeaders,
      body: jsonEncode({'amount': amount, 'upi_id': upiId}));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getDriverHistory({int limit = 20, int offset = 0}) async {
    final res = await http.get(
      Uri.parse('$_base/driver/trips/history?limit=$limit&offset=$offset'),
      headers: _authHeaders);
    return _handle(res);
  }

  // ═══════════════════════════════════════════════════════
  //  SHARED
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> getNotifications({bool unread = false}) async {
    final res = await http.get(
      Uri.parse('$_base/notifications?unread_only=$unread'),
      headers: _authHeaders);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> markAllRead() async {
    final res = await http.patch(Uri.parse('$_base/notifications/read-all'),
      headers: _authHeaders);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getWalletBalance() async {
    final res = await http.get(Uri.parse('$_base/wallet/balance'),
      headers: _authHeaders);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getWalletTransactions() async {
    final res = await http.get(Uri.parse('$_base/wallet/transactions'),
      headers: _authHeaders);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> addMoneyToWallet(double amount) async {
    final res = await http.post(Uri.parse('$_base/wallet/add-money'),
      headers: _authHeaders, body: jsonEncode({'amount': amount}));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> createSupportTicket(
      String category, String subject, String message, {int? tripId}) async {
    final res = await http.post(Uri.parse('$_base/support/tickets'),
      headers: _authHeaders,
      body: jsonEncode({
        'category': category, 'subject': subject,
        'message': message,   'trip_id': tripId,
      }));
    return _handle(res);
  }
}
