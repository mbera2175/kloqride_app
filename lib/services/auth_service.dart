import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class AuthService {
  static SharedPreferences? _prefs;

  // ── Init ────────────────────────────────────────────────
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Save after login/register ───────────────────────────
  static Future<void> saveSession(Map<String, dynamic> data) async {
    await _prefs?.setString(AppConstants.keyToken,  data['access_token'] ?? '');
    await _prefs?.setString(AppConstants.keyRole,   data['role']         ?? '');
    await _prefs?.setString(AppConstants.keyName,   data['full_name']    ?? '');
    await _prefs?.setString(AppConstants.keyPhone,  data['phone']        ?? '');
    await _prefs?.setInt(   'user_id',              data['user_id']      ?? 0);
    await _prefs?.setDouble('wallet_balance',       (data['wallet_balance'] ?? 0.0).toDouble());
    if (data['driver_id'] != null) {
      await _prefs?.setInt('driver_id', data['driver_id']);
    }
    if (data['language'] != null) {
      await _prefs?.setString(AppConstants.keyLanguage, data['language']);
    }
  }

  // ── Getters ─────────────────────────────────────────────
  static String  get token         => _prefs?.getString(AppConstants.keyToken)  ?? '';
  static String  get role          => _prefs?.getString(AppConstants.keyRole)   ?? '';
  static String  get name          => _prefs?.getString(AppConstants.keyName)   ?? '';
  static String  get phone         => _prefs?.getString(AppConstants.keyPhone)  ?? '';
  static String  get language      => _prefs?.getString(AppConstants.keyLanguage) ?? 'en';
  static int     get userId        => _prefs?.getInt('user_id')                 ?? 0;
  static int     get driverId      => _prefs?.getInt('driver_id')               ?? 0;
  static double  get walletBalance => _prefs?.getDouble('wallet_balance')       ?? 0.0;
  static bool    get isLoggedIn    => token.isNotEmpty;
  static bool    get isDriver      => role == 'driver';
  static bool    get isRider       => role == 'rider';

  // ── Update wallet locally ────────────────────────────────
  static Future<void> updateWallet(double balance) async {
    await _prefs?.setDouble('wallet_balance', balance);
  }

  // ── Logout ──────────────────────────────────────────────
  static Future<void> logout() async {
    await _prefs?.clear();
  }
}
