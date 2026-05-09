import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../../utils/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../auth/role_selection_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  // Online status
  bool _isOnline       = false;
  bool _togglingOnline = false;

  // Location
  double _currentLat = 0;
  double _currentLng = 0;

  // Available trips
  List  _availableTrips = [];
  bool  _loadingTrips   = false;

  // Active trip
  Map<String, dynamic>? _activeTrip;
  bool  _loadingActive  = false;

  // Earnings
  Map<String, dynamic>? _earnings;

  // Nav
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _getLocation();
    _loadEarnings();
    _checkActiveTrip();
  }

  // ── Location ───────────────────────────────────────────

  Future<void> _getLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _currentLat = pos.latitude;
      _currentLng = pos.longitude;

      // Push location to backend
      await ApiService.updateLocation(_currentLat, _currentLng);

      // Start continuous location updates
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 20,
        ),
      ).listen((pos) async {
        _currentLat = pos.latitude;
        _currentLng = pos.longitude;
        if (_isOnline) {
          await ApiService.updateLocation(_currentLat, _currentLng);
        }
      });
    } catch (_) {}
  }

  // ── Toggle Online ──────────────────────────────────────

  Future<void> _toggleOnline() async {
    setState(() => _togglingOnline = true);
    final res = await ApiService.toggleOnline();
    if (res['success']) {
      setState(() => _isOnline = res['data']['is_online']);
      _showSnack(res['data']['message'], isError: false);
      if (_isOnline) _loadAvailableTrips();
    } else {
      _showSnack(res['error'], isError: true);
    }
    setState(() => _togglingOnline = false);
  }

  // ── Available Trips ────────────────────────────────────

  Future<void> _loadAvailableTrips() async {
    if (!_isOnline) return;
    setState(() => _loadingTrips = true);
    final res = await ApiService.getAvailableTrips();
    if (res['success']) {
      setState(() => _availableTrips = res['data']['trips'] ?? []);
    }
    setState(() => _loadingTrips = false);
  }

  // ── Active Trip ────────────────────────────────────────

  Future<void> _checkActiveTrip() async {
    setState(() => _loadingActive = true);
    final res = await ApiService.getDriverActiveTrip();
    if (res['success']) {
      setState(() => _activeTrip = res['data']['active_trip']);
    }
    setState(() => _loadingActive = false);
  }

  // ── Accept Trip ────────────────────────────────────────

  Future<void> _acceptTrip(int tripId) async {
    final res = await ApiService.acceptTrip(tripId);
    if (res['success']) {
      _showSnack('Trip accepted! Head to pickup. 📍', isError: false);
      setState(() => _availableTrips.clear());
      await _checkActiveTrip();
    } else {
      _showSnack(res['error'], isError: true);
    }
  }

  // ── Trip Actions ───────────────────────────────────────

  Future<void> _tripAction(String action) async {
    if (_activeTrip == null) return;
    final tripId = _activeTrip!['id'];
    Map<String, dynamic> res;

    switch (action) {
      case 'arrived':  res = await ApiService.markArrived(tripId);  break;
      case 'start':    res = await ApiService.startTrip(tripId);    break;
      case 'complete': res = await ApiService.completeTrip(tripId); break;
      default: return;
    }

    if (res['success']) {
      if (action == 'complete') {
        _showCompletionDialog(res['data']);
        setState(() => _activeTrip = null);
        _loadEarnings();
      } else {
        _showSnack(_actionMessage(action), isError: false);
        await _checkActiveTrip();
      }
    } else {
      _showSnack(res['error'], isError: true);
    }
  }

  String _actionMessage(String action) {
    switch (action) {
      case 'arrived':  return 'Marked as arrived! Waiting for rider. 🕐';
      case 'start':    return 'Trip started! Drive safely. 🛣️';
      default: return '';
    }
  }

  // ── Cancel Trip ────────────────────────────────────────

  Future<void> _cancelTrip() async {
    final reason = await _showCancelDialog();
    if (reason == null || _activeTrip == null) return;

    final res = await ApiService.cancelDriverTrip(_activeTrip!['id'], reason);
    if (res['success']) {
      setState(() => _activeTrip = null);
      _showSnack('Trip cancelled.', isError: false);
      if (_isOnline) _loadAvailableTrips();
    } else {
      _showSnack(res['error'], isError: true);
    }
  }

  // ── Earnings ───────────────────────────────────────────

  Future<void> _loadEarnings() async {
    final res = await ApiService.getEarningsSummary();
    if (res['success']) {
      setState(() => _earnings = res['data']);
    }
  }

  // ── Logout ─────────────────────────────────────────────

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (r) => false);
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ═══════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _navIndex,
        children: [
          _homeTab(),
          _earningsTab(),
          _historyTab(),
          _profileTab(),
        ],
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }

  // ── Home Tab ───────────────────────────────────────────

  Widget _homeTab() {
    return SafeArea(
      child: Column(children: [
        _topBar(),
        Expanded(
          child: _loadingActive
            ? const Center(child: CircularProgressIndicator())
            : _activeTrip != null
              ? _activeTripSection()
              : _onlineSection(),
        ),
      ]),
    );
  }

  // ── Top Bar ────────────────────────────────────────────

  Widget _topBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(children: [
        // Avatar
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppColors.driverColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person_rounded,
              color: AppColors.driverColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hello, ${AuthService.name.split(' ').first}! 👋',
                style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
              Text(_isOnline ? '🟢 Online — Ready for trips' : '🔴 Offline',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: _isOnline ? AppColors.success : AppColors.textSecondary)),
            ],
          ),
        ),
        // Wallet chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.driverColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [
            const Icon(Icons.account_balance_wallet_rounded,
                color: AppColors.driverColor, size: 16),
            const SizedBox(width: 6),
            Text('₹${AuthService.walletBalance.toStringAsFixed(0)}',
              style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: AppColors.driverColor)),
          ]),
        ),
      ]),
    );
  }

  // ── Online Section ─────────────────────────────────────

  Widget _onlineSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        // Online Toggle Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isOnline
                ? [AppColors.success, const Color(0xFF059669)]
                : [AppColors.driverColor, const Color(0xFF6D28D9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: [
            Text(_isOnline ? 'You are Online' : 'You are Offline',
              style: GoogleFonts.poppins(
                fontSize: 22, fontWeight: FontWeight.w700,
                color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              _isOnline
                ? 'You can receive ride requests now'
                : 'Go online to start accepting rides',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13, color: Colors.white70)),
            const SizedBox(height: 24),

            // Big Toggle Button
            GestureDetector(
              onTap: _togglingOnline ? null : _toggleOnline,
              child: Container(
                width: 110, height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: _togglingOnline
                  ? const Center(child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 3))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isOnline
                            ? Icons.power_settings_new_rounded
                            : Icons.power_settings_new_rounded,
                          color: Colors.white, size: 40),
                        const SizedBox(height: 4),
                        Text(_isOnline ? 'GO\nOFFLINE' : 'GO\nONLINE',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 11, fontWeight: FontWeight.w800,
                            color: Colors.white)),
                      ],
                    ),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 20),

        // Today stats
        if (_earnings != null) _todayStatsRow(),

        const SizedBox(height: 20),

        // Available trips
        if (_isOnline) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Available Rides',
                style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
              TextButton.icon(
                onPressed: _loadAvailableTrips,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text('Refresh',
                  style: GoogleFonts.poppins(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _loadingTrips
            ? const Center(child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator()))
            : _availableTrips.isEmpty
              ? _noTripsCard()
              : Column(
                  children: _availableTrips
                    .map((t) => _availableTripCard(t))
                    .toList()),
        ],
      ]),
    );
  }

  // ── Today Stats Row ────────────────────────────────────

  Widget _todayStatsRow() {
    final today = _earnings?['today'] ?? {};
    return Row(children: [
      Expanded(child: _statCard(
        '₹${today['earnings'] ?? 0}', 'Today\'s Earnings',
        Icons.currency_rupee_rounded, AppColors.success)),
      const SizedBox(width: 12),
      Expanded(child: _statCard(
        '${today['trips'] ?? 0}', 'Today\'s Trips',
        Icons.directions_car_rounded, AppColors.driverColor)),
      const SizedBox(width: 12),
      Expanded(child: _statCard(
        '${_earnings?['avg_rating'] ?? 5.0}⭐', 'Rating',
        Icons.star_rounded, AppColors.warning)),
    ]);
  }

  Widget _statCard(String value, String label, IconData icon, Color color) =>
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
          color: AppColors.shadow, blurRadius: 6,
          offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.poppins(
          fontSize: 14, fontWeight: FontWeight.w800,
          color: AppColors.textPrimary)),
        Text(label, textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 9, color: AppColors.textSecondary)),
      ]),
    );

  // ── Available Trip Card ────────────────────────────────

  Widget _availableTripCard(Map trip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: AppColors.shadow, blurRadius: 8,
          offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Text(_vehicleEmoji(trip['vehicle_type']),
                style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                (trip['vehicle_type'] as String).toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: AppColors.driverColor)),
            ]),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('₹${trip['estimated_fare']}',
                style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w800,
                  color: AppColors.success)),
            ),
          ],
        ),

        const Divider(height: 16),

        // Pickup
        _tripLocRow(Icons.radio_button_checked_rounded,
            AppColors.success, trip['pickup_address'] ?? ''),
        const SizedBox(height: 6),
        // Drop
        _tripLocRow(Icons.location_on_rounded,
            AppColors.error, trip['drop_address'] ?? ''),

        const SizedBox(height: 12),

        // Distance / duration / earnings
        Row(children: [
          _tripMeta('${trip['distance_km']} km', Icons.straighten_rounded),
          const SizedBox(width: 16),
          _tripMeta('${trip['duration_min']} min', Icons.timer_outlined),
          const SizedBox(width: 16),
          _tripMeta(trip['payment_method'] ?? 'cash', Icons.payment_rounded),
          const Spacer(),
          // Your earnings
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Your earnings',
              style: GoogleFonts.poppins(
                fontSize: 10, color: AppColors.textSecondary)),
            Text('₹${trip['driver_earnings'] ?? ''}',
              style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: AppColors.driverColor)),
          ]),
        ]),

        const SizedBox(height: 12),

        // Accept button
        SizedBox(
          width: double.infinity, height: 46,
          child: ElevatedButton(
            onPressed: () => _acceptTrip(trip['id']),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.driverColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text('Accept Ride',
              style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  // ── Active Trip Section ────────────────────────────────

  Widget _activeTripSection() {
    final trip   = _activeTrip!;
    final status = trip['status'] as String;
    final rider  = trip['rider'];

    final actionConfig = {
      'accepted': {
        'label': 'Mark Arrived at Pickup',
        'action': 'arrived',
        'color': AppColors.info,
        'icon': Icons.location_on_rounded,
        'statusLabel': '🚗 Heading to pickup',
      },
      'arrived': {
        'label': 'Start Trip',
        'action': 'start',
        'color': AppColors.primary,
        'icon': Icons.play_arrow_rounded,
        'statusLabel': '📍 Arrived at pickup',
      },
      'started': {
        'label': 'Complete Trip',
        'action': 'complete',
        'color': AppColors.success,
        'icon': Icons.check_circle_rounded,
        'statusLabel': '🛣️ Trip in progress',
      },
    };

    final cfg = actionConfig[status];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        // Status banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (cfg?['color'] as Color? ?? AppColors.warning)
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (cfg?['color'] as Color? ?? AppColors.warning)
                  .withOpacity(0.3)),
          ),
          child: Row(children: [
            Icon(cfg?['icon'] as IconData? ?? Icons.info_rounded,
              color: cfg?['color'] as Color? ?? AppColors.warning,
              size: 24),
            const SizedBox(width: 12),
            Text(cfg?['statusLabel'] as String? ?? '',
              style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w600,
                color: cfg?['color'] as Color? ?? AppColors.warning)),
          ]),
        ),

        const SizedBox(height: 16),

        // Trip card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
              color: AppColors.shadow, blurRadius: 10,
              offset: const Offset(0, 4))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Trip code + fare
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
              Text('#${trip['trip_code']}',
                style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₹${trip['estimated_fare']}',
                  style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: AppColors.driverColor)),
                Text('Your cut: ₹${trip['driver_earnings'] ?? ''}',
                  style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.success)),
              ]),
            ]),

            const Divider(height: 20),

            // Locations
            _tripLocRow(Icons.radio_button_checked_rounded,
                AppColors.success, trip['pickup_address'] ?? ''),
            const SizedBox(height: 8),
            _tripLocRow(Icons.location_on_rounded,
                AppColors.error, trip['drop_address'] ?? ''),

            const Divider(height: 20),

            // Rider info
            if (rider != null) Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rider['name'] ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600)),
                  Text('Rider', style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textSecondary)),
                ],
              )),
              // Call rider
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.call_rounded,
                      color: AppColors.success, size: 18),
                ),
              ),
            ]),

            // Delivery extra info
            if (trip['service_type'] == 'delivery' &&
                trip['receiver_name'] != null) ...[
              const Divider(height: 20),
              Text('📦 Delivery Details',
                style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Text('Receiver: ${trip['receiver_name']}',
                style: GoogleFonts.poppins(
                  fontSize: 13, color: AppColors.textSecondary)),
              if (trip['receiver_phone'] != null)
                Text('Phone: ${trip['receiver_phone']}',
                  style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textSecondary)),
              if (trip['package_desc'] != null)
                Text('Package: ${trip['package_desc']}',
                  style: GoogleFonts.poppins(
                    fontSize: 13, color: AppColors.textSecondary)),
            ],
          ]),
        ),

        const SizedBox(height: 16),

        // Action button
        if (cfg != null)
          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton.icon(
              onPressed: () => _tripAction(cfg['action'] as String),
              icon: Icon(cfg['icon'] as IconData, size: 20),
              label: Text(cfg['label'] as String,
                style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: cfg['color'] as Color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),

        const SizedBox(height: 10),

        // Cancel (only before trip starts)
        if (status != 'started')
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _cancelTrip,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('Cancel Trip',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
      ]),
    );
  }

  // ── Earnings Tab ───────────────────────────────────────

  Widget _earningsTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text('My Earnings',
            style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),

          // Wallet balance card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.driverColor, Color(0xFF6D28D9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text('Wallet Balance',
                style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.white70)),
              const SizedBox(height: 6),
              Text('₹${AuthService.walletBalance.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 36, fontWeight: FontWeight.w800,
                  color: Colors.white)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showWithdrawDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.driverColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text('Withdraw Money',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 20),

          // Period stats
          if (_earnings != null) ...[
            _periodCard('Today',      _earnings!['today']),
            const SizedBox(height: 12),
            _periodCard('This Week',  _earnings!['this_week']),
            const SizedBox(height: 12),
            _periodCard('This Month', _earnings!['this_month']),
            const SizedBox(height: 12),
            _periodCard('All Time',   _earnings!['all_time']),
          ] else
            const Center(child: CircularProgressIndicator()),
        ]),
      ),
    );
  }

  Widget _periodCard(String label, Map? data) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(
        color: AppColors.shadow, blurRadius: 6,
        offset: const Offset(0, 2))],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
      Text(label, style: GoogleFonts.poppins(
        fontSize: 14, fontWeight: FontWeight.w600,
        color: AppColors.textPrimary)),
      Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('₹${data?['earnings'] ?? 0}',
            style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w800,
              color: AppColors.driverColor)),
          Text('${data?['trips'] ?? 0} trips',
            style: GoogleFonts.poppins(
              fontSize: 11, color: AppColors.textSecondary)),
        ]),
      ]),
    ]),
  );

  // ── History Tab ────────────────────────────────────────

  Widget _historyTab() {
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Text('Trip History',
            style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: FutureBuilder(
            future: ApiService.getDriverHistory(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final res = snap.data as Map<String, dynamic>?;
              if (res == null || !res['success']) {
                return Center(child: Text('Could not load trips',
                  style: GoogleFonts.poppins(
                    color: AppColors.textSecondary)));
              }
              final trips = res['data']['trips'] as List;
              if (trips.isEmpty) {
                return _emptyState('No trips yet!',
                    'Accept your first ride and it will appear here.', '🚗');
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: trips.length,
                itemBuilder: (_, i) => _historyCard(trips[i]),
              );
            },
          ),
        ),
      ]),
    );
  }

  // ── Profile Tab ────────────────────────────────────────

  Widget _profileTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.driverColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded,
                color: AppColors.driverColor, size: 40),
          ),
          const SizedBox(height: 12),
          Text(AuthService.name,
            style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w700)),
          Text('+91 ${AuthService.phone}',
            style: GoogleFonts.poppins(
              fontSize: 13, color: AppColors.textSecondary)),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('✅ Approved Driver',
              style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: AppColors.success)),
          ),
          const SizedBox(height: 24),

          _profileMenuItem(Icons.bar_chart_rounded, 'Earnings',
              () => setState(() => _navIndex = 1)),
          _profileMenuItem(Icons.history_rounded, 'Trip History',
              () => setState(() => _navIndex = 2)),
          _profileMenuItem(Icons.account_balance_rounded,
              'Bank / UPI Details', () {}),
          _profileMenuItem(Icons.description_rounded,
              'My Documents', () {}),
          _profileMenuItem(Icons.help_outline_rounded,
              'Help & Support', () {}),
          const Divider(height: 32),
          _profileMenuItem(Icons.logout_rounded, 'Logout', _logout,
              color: AppColors.error),
        ]),
      ),
    );
  }

  // ── Bottom Nav ─────────────────────────────────────────

  Widget _bottomNav() => NavigationBar(
    selectedIndex: _navIndex,
    onDestinationSelected: (i) => setState(() => _navIndex = i),
    backgroundColor: AppColors.white,
    indicatorColor: AppColors.driverColor.withOpacity(0.12),
    destinations: [
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home_rounded,
            color: AppColors.driverColor),
        label: 'Home'),
      NavigationDestination(
        icon: const Icon(Icons.currency_rupee_outlined),
        selectedIcon: const Icon(Icons.currency_rupee_rounded,
            color: AppColors.driverColor),
        label: 'Earnings'),
      NavigationDestination(
        icon: const Icon(Icons.history_outlined),
        selectedIcon: const Icon(Icons.history_rounded,
            color: AppColors.driverColor),
        label: 'History'),
      NavigationDestination(
        icon: const Icon(Icons.person_outline_rounded),
        selectedIcon: const Icon(Icons.person_rounded,
            color: AppColors.driverColor),
        label: 'Profile'),
    ],
  );

  // ── Dialogs ────────────────────────────────────────────

  void _showCompletionDialog(Map data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 40),
          ),
          const SizedBox(height: 16),
          Text('Trip Completed! 🎉',
            style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _completionRow('Total Fare',
              '₹${data['actual_fare'] ?? 0}'),
          _completionRow('Your Earnings',
              '₹${data['your_earnings'] ?? 0}',
              valueColor: AppColors.success),
          _completionRow('Platform Fee',
              '₹${data['commission'] ?? 0}'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (_isOnline) _loadAvailableTrips();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.driverColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Continue',
                style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _completionRow(String label, String value,
      {Color? valueColor}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
      Text(label, style: GoogleFonts.poppins(
        fontSize: 13, color: AppColors.textSecondary)),
      Text(value, style: GoogleFonts.poppins(
        fontSize: 14, fontWeight: FontWeight.w700,
        color: valueColor ?? AppColors.textPrimary)),
    ]),
  );

  Future<String?> _showCancelDialog() async {
    String reason = 'Rider not found at pickup';
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel Trip?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Select reason:',
            style: GoogleFonts.poppins(fontSize: 14)),
          const SizedBox(height: 12),
          ...['Rider not found at pickup',
              'Rider cancelled verbally',
              'Emergency',
              'Other'].map((r) => RadioListTile<String>(
            value: r, groupValue: reason,
            title: Text(r, style: GoogleFonts.poppins(fontSize: 13)),
            onChanged: (v) => reason = v!,
            activeColor: AppColors.driverColor,
          )),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Back', style: GoogleFonts.poppins())),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, reason),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            child: Text('Cancel Trip',
              style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog() {
    final ctrl = TextEditingController();
    final upiCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24, right: 24, top: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Withdraw Money',
            style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Available: ₹${AuthService.walletBalance.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          TextField(
            controller: upiCtrl,
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'UPI ID (e.g. name@upi)',
              prefixIcon: const Icon(Icons.payment_rounded),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            style: GoogleFonts.poppins(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Amount (min ₹50)',
              prefixText: '₹ ',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(ctrl.text) ?? 0;
                if (amt < 50) return;
                final res = await ApiService.requestWithdrawal(
                    amt, upiCtrl.text.trim());
                Navigator.pop(context);
                if (res['success']) {
                  await AuthService.updateWallet(
                    res['data']['remaining_balance'] ?? 0.0);
                  setState(() {});
                  _showSnack(
                    '₹$amt withdrawal requested! 💸', isError: false);
                } else {
                  _showSnack(res['error'], isError: true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.driverColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text('Request Withdrawal',
                style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Small Helpers ──────────────────────────────────────

  Widget _noTripsCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(children: [
      const Text('🚖', style: TextStyle(fontSize: 36)),
      const SizedBox(height: 8),
      Text('No rides available right now',
        style: GoogleFonts.poppins(
          fontSize: 14, fontWeight: FontWeight.w600,
          color: AppColors.textPrimary)),
      const SizedBox(height: 4),
      Text('Pull to refresh or wait for new requests',
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 12, color: AppColors.textSecondary)),
    ]),
  );

  Widget _tripLocRow(IconData icon, Color color, String address) =>
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(address,
        maxLines: 2, overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          fontSize: 13, color: AppColors.textPrimary))),
    ]);

  Widget _tripMeta(String value, IconData icon) => Row(children: [
    Icon(icon, size: 13, color: AppColors.textSecondary),
    const SizedBox(width: 3),
    Text(value, style: GoogleFonts.poppins(
      fontSize: 11, color: AppColors.textSecondary)),
  ]);

  Widget _historyCard(Map trip) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(
        color: AppColors.shadow, blurRadius: 6,
        offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('#${trip['trip_code']}',
          style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: AppColors.textSecondary)),
        _statusBadge(trip['status']),
      ]),
      const SizedBox(height: 6),
      Text(trip['pickup_address'] ?? '',
        maxLines: 1, overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          fontSize: 13, color: AppColors.textPrimary)),
      Text('→ ${trip['drop_address'] ?? ''}',
        maxLines: 1, overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          fontSize: 13, color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('₹${trip['driver_earnings'] ?? trip['estimated_fare']}',
          style: GoogleFonts.poppins(
            fontSize: 15, fontWeight: FontWeight.w700,
            color: AppColors.driverColor)),
        Text('${trip['distance_km']} km',
          style: GoogleFonts.poppins(
            fontSize: 12, color: AppColors.textSecondary)),
      ]),
    ]),
  );

  Widget _statusBadge(String status) {
    final colors = {
      'completed': AppColors.success, 'cancelled': AppColors.error,
      'started'  : AppColors.primary, 'requested': AppColors.warning,
    };
    final color = colors[status] ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _profileMenuItem(IconData icon, String label,
      VoidCallback onTap, {Color? color}) => ListTile(
    onTap: onTap,
    leading: Icon(icon, color: color ?? AppColors.textSecondary, size: 22),
    title: Text(label, style: GoogleFonts.poppins(
      fontSize: 14, fontWeight: FontWeight.w500,
      color: color ?? AppColors.textPrimary)),
    trailing: color == null
      ? const Icon(Icons.arrow_forward_ios_rounded,
          size: 14, color: AppColors.textSecondary)
      : null,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  Widget _emptyState(String title, String sub, String emoji) =>
    Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text(title, style: GoogleFonts.poppins(
          fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(sub, textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13, color: AppColors.textSecondary)),
      ],
    ));

  String _vehicleEmoji(String? type) {
    const map = {
      'bike': '🏍️', 'auto': '🛺', 'mini': '🚗',
      'sedan': '🚙', 'suv': '🚐', 'truck': '🚛',
    };
    return map[type] ?? '🚗';
  }
}
