import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../auth/role_selection_screen.dart';

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  // Location
  String _currentAddress = 'Getting your location...';
  double _currentLat     = 0;
  double _currentLng     = 0;

  // Booking
  final _dropCtrl        = TextEditingController();
  String _selectedVehicle= 'auto';
  String _serviceType    = 'ride';
  bool   _showBooking    = false;

  // Fare
  Map<String, dynamic>? _fareData;
  bool   _loadingFare    = false;

  // Active trip
  Map<String, dynamic>? _activeTrip;
  bool   _loadingTrip    = false;

  // Bottom nav
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _getLocation();
    _checkActiveTrip();
  }

  // ── Location ───────────────────────────────────────────

  Future<void> _getLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() => _currentAddress = 'Location permission denied');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
      _currentLat = pos.latitude;
      _currentLng = pos.longitude;

      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        setState(() {
          _currentAddress =
            '${p.subLocality ?? ''}, ${p.locality ?? ''}, ${p.administrativeArea ?? ''}';
        });
      }
    } catch (e) {
      setState(() => _currentAddress = 'Unable to get location');
    }
  }

  // ── Active Trip ────────────────────────────────────────

  Future<void> _checkActiveTrip() async {
    setState(() => _loadingTrip = true);
    final res = await ApiService.getActiveTrip();
    if (res['success'] && res['data']['active_trip'] != null) {
      setState(() => _activeTrip = res['data']['active_trip']);
    }
    setState(() => _loadingTrip = false);
  }

  // ── Fare Estimate ──────────────────────────────────────

  Future<void> _estimateFare() async {
    if (_currentLat == 0) {
      _showSnack('Could not get your location. Try again.', isError: true);
      return;
    }
    if (_dropCtrl.text.trim().isEmpty) {
      _showSnack('Please enter drop location', isError: true);
      return;
    }
    setState(() { _loadingFare = true; _fareData = null; });

    // Use dummy drop coords for now (in real app use Google Places API)
    final res = await ApiService.estimateFare(
      pickupLat  : _currentLat,
      pickupLng  : _currentLng,
      dropLat    : _currentLat + 0.05,
      dropLng    : _currentLng + 0.05,
      vehicleType: _selectedVehicle,
      serviceType: _serviceType,
    );
    if (res['success']) {
      setState(() => _fareData = res['data']);
    } else {
      _showSnack(res['error'], isError: true);
    }
    setState(() => _loadingFare = false);
  }

  // ── Book Trip ──────────────────────────────────────────

  Future<void> _bookTrip() async {
    if (_fareData == null) { _estimateFare(); return; }
    setState(() => _loadingFare = true);

    final res = await ApiService.bookTrip({
      'pickup_address': _currentAddress,
      'pickup_lat'    : _currentLat,
      'pickup_lng'    : _currentLng,
      'drop_address'  : _dropCtrl.text.trim(),
      'drop_lat'      : _currentLat + 0.05,
      'drop_lng'      : _currentLng + 0.05,
      'vehicle_type'  : _selectedVehicle,
      'service_type'  : _serviceType,
      'payment_method': 'cash',
    });

    setState(() => _loadingFare = false);

    if (res['success']) {
      _showSnack('🚖 Ride booked! Looking for a driver...', isError: false);
      setState(() {
        _showBooking = false;
        _fareData    = null;
        _dropCtrl.clear();
      });
      await Future.delayed(const Duration(seconds: 2));
      _checkActiveTrip();
    } else {
      _showSnack(res['error'], isError: true);
    }
  }

  // ── Cancel Trip ────────────────────────────────────────

  Future<void> _cancelTrip() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel Ride?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to cancel this ride?',
          style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: Text('No', style: GoogleFonts.poppins())),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('Yes, Cancel',
              style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true || _activeTrip == null) return;

    final res = await ApiService.cancelRiderTrip(
        _activeTrip!['id'], 'Cancelled by rider');
    if (res['success']) {
      setState(() => _activeTrip = null);
      _showSnack('Ride cancelled.', isError: false);
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

  @override
  void dispose() {
    _dropCtrl.dispose();
    super.dispose();
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
          _historyTab(),
          _walletTab(),
          _profileTab(),
        ],
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }

  // ── Home Tab ───────────────────────────────────────────

  Widget _homeTab() {
    return SafeArea(
      child: Column(
        children: [
          _topBar(),
          Expanded(
            child: _loadingTrip
              ? const Center(child: CircularProgressIndicator())
              : _activeTrip != null
                ? _activeTripCard()
                : _bookingSection(),
          ),
        ],
      ),
    );
  }

  // ── Top Bar ────────────────────────────────────────────

  Widget _topBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hello, ${AuthService.name.split(' ').first}! 👋',
                    style: GoogleFonts.poppins(
                      fontSize: 20, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_rounded,
                        color: AppColors.primary, size: 14),
                    const SizedBox(width: 4),
                    Expanded(child: Text(_currentAddress,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textSecondary))),
                  ]),
                ],
              ),
            ),
            // Wallet chip
            GestureDetector(
              onTap: () => setState(() => _navIndex = 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(children: [
                  const Icon(Icons.account_balance_wallet_rounded,
                      color: AppColors.primary, size: 16),
                  const SizedBox(width: 6),
                  Text('₹${AuthService.walletBalance.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
                ]),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Booking Section ────────────────────────────────────

  Widget _bookingSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Where To Search Bar ───────────────────────
          GestureDetector(
            onTap: _openSearchPage,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(50),
                boxShadow: [BoxShadow(
                  color: AppColors.shadow, blurRadius: 12,
                  offset: const Offset(0, 4))],
              ),
              child: Row(children: [
                const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 22),
                const SizedBox(width: 12),
                Text('Where to?',
                  style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary)),
              ]),
            ),
          ),

          const SizedBox(height: 28),

          // ── For You Section ───────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('For you',
                style: GoogleFonts.poppins(
                  fontSize: 17, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
              const Icon(Icons.arrow_forward_rounded,
                size: 20, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 1.0,
              children: AppConstants.vehicleTypes.map((v) =>
                _vehicleCard(v['type'], v['icon'], v['label'])
              ).toList(),
            ),
          ),

          const SizedBox(height: 28),

          // ── Services Section ──────────────────────────
          Text('Services',
            style: GoogleFonts.poppins(
              fontSize: 17, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 1.0,
              children: AppConstants.services.map((s) =>
                _serviceItemCard(s['type'], s['icon'], s['label'])
              ).toList(),
            ),
          ),

          const SizedBox(height: 24),

          // ── Fare display ─────────────────────────────
          if (_loadingFare)
            const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ))
          else if (_fareData != null)
            _fareCard(),

          const SizedBox(height: 16),

          if (_fareData != null)
            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                onPressed: _loadingFare ? null : _bookTrip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  'Book Ride — ₹${_fareData!['estimated_fare']}',
                  style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Active Trip Card ───────────────────────────────────

  Widget _activeTripCard() {
    final trip   = _activeTrip!;
    final driver = trip['driver'];
    final status = trip['status'] as String;

    final statusConfig = {
      'requested' : {'label': 'Finding your driver...', 'color': AppColors.warning,   'icon': Icons.search_rounded},
      'accepted'  : {'label': 'Driver is on the way!',  'color': AppColors.info,      'icon': Icons.directions_car_rounded},
      'arrived'   : {'label': 'Driver has arrived!',    'color': AppColors.success,   'icon': Icons.location_on_rounded},
      'started'   : {'label': 'Trip in progress',       'color': AppColors.primary,   'icon': Icons.navigation_rounded},
    };
    final cfg = statusConfig[status] ?? statusConfig['requested']!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        // Status Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (cfg['color'] as Color).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (cfg['color'] as Color).withOpacity(0.3)),
          ),
          child: Row(children: [
            Icon(cfg['icon'] as IconData,
                color: cfg['color'] as Color, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text(cfg['label'] as String,
              style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w600,
                color: cfg['color'] as Color))),
            if (status == 'requested')
              SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cfg['color'] as Color)),
          ]),
        ),

        const SizedBox(height: 16),

        // Trip Details Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
              color: AppColors.shadow, blurRadius: 10,
              offset: const Offset(0, 4))],
          ),
          child: Column(children: [
            // Trip code
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Trip #${trip['trip_code']}',
                style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('₹${trip['estimated_fare']}',
                  style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
              ),
            ]),

            const Divider(height: 20),

            // Locations
            _tripLocationRow(Icons.radio_button_checked_rounded,
                AppColors.success, trip['pickup_address']),
            const SizedBox(height: 8),
            _tripLocationRow(Icons.location_on_rounded,
                AppColors.error, trip['drop_address']),

            // Driver info (if assigned)
            if (driver != null) ...[
              const Divider(height: 20),
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver['name'] ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                    Text(driver['vehicle'] ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textSecondary)),
                  ],
                )),
                // Call button
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call_rounded,
                        color: AppColors.success, size: 20),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              // Plate number
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.directions_car_rounded,
                      color: AppColors.textSecondary, size: 14),
                  const SizedBox(width: 6),
                  Text(driver['plate_number'] ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: 1)),
                ]),
              ),
            ],
          ]),
        ),

        const SizedBox(height: 16),

        // Refresh + Cancel
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _checkActiveTrip,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('Refresh', style: GoogleFonts.poppins()),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (status != 'started') ...[
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _cancelTrip,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: Text('Cancel', style: GoogleFonts.poppins()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ]),
      ]),
    );
  }

  // ── History Tab ────────────────────────────────────────

  Widget _historyTab() {
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Text('My Trips',
            style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: FutureBuilder(
            future: ApiService.getRiderHistory(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final res = snap.data as Map<String, dynamic>?;
              if (res == null || !res['success']) {
                return Center(child: Text('Could not load trips',
                  style: GoogleFonts.poppins(color: AppColors.textSecondary)));
              }
              final trips = res['data']['trips'] as List;
              if (trips.isEmpty) {
                return _emptyState('No trips yet!',
                    'Book your first ride and it will appear here.', '🚖');
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

  // ── Wallet Tab ─────────────────────────────────────────

  Widget _walletTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Wallet',
              style: GoogleFonts.poppins(
                fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),

            // Balance card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
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
                      fontSize: 14, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text('₹${AuthService.walletBalance.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 36, fontWeight: FontWeight.w800,
                      color: Colors.white)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _showAddMoneyDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: Text('+ Add Money',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Text('Recent Transactions',
              style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),

            FutureBuilder(
              future: ApiService.getWalletTransactions(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final res = snap.data as Map<String, dynamic>?;
                if (res == null || !res['success']) {
                  return Text('Could not load transactions',
                    style: GoogleFonts.poppins(color: AppColors.textSecondary));
                }
                final txns = res['data']['transactions'] as List;
                if (txns.isEmpty) {
                  return _emptyState('No transactions yet',
                      'Your wallet activity will show here', '💳');
                }
                return Column(
                  children: txns.map((t) => _txnRow(t)).toList());
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Profile Tab ────────────────────────────────────────

  Widget _profileTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Avatar
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded,
                  color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 12),
            Text(AuthService.name,
              style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
            Text('+91 ${AuthService.phone}',
              style: GoogleFonts.poppins(
                fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 24),

            // Menu items
            _profileMenuItem(Icons.history_rounded,      'My Trips',
                () => setState(() => _navIndex = 1)),
            _profileMenuItem(Icons.account_balance_wallet_rounded, 'Wallet',
                () => setState(() => _navIndex = 2)),
            _profileMenuItem(Icons.local_offer_rounded,  'Offers & Promos',  () {}),
            _profileMenuItem(Icons.help_outline_rounded, 'Help & Support',   () {}),
            _profileMenuItem(Icons.info_outline_rounded, 'About KloqRide',   () {}),
            const Divider(height: 32),
            _profileMenuItem(Icons.logout_rounded, 'Logout', _logout,
                color: AppColors.error),
          ],
        ),
      ),
    );
  }

  // ── Bottom Nav ─────────────────────────────────────────

  Widget _bottomNav() {
    return NavigationBar(
      selectedIndex: _navIndex,
      onDestinationSelected: (i) => setState(() => _navIndex = i),
      backgroundColor: AppColors.white,
      indicatorColor: AppColors.primary.withOpacity(0.12),
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home_rounded, color: AppColors.primary),
          label: 'Home'),
        NavigationDestination(
          icon: const Icon(Icons.history_outlined),
          selectedIcon: const Icon(Icons.history_rounded, color: AppColors.primary),
          label: 'Trips'),
        NavigationDestination(
          icon: const Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: const Icon(Icons.account_balance_wallet_rounded,
              color: AppColors.primary),
          label: 'Wallet'),
        NavigationDestination(
          icon: const Icon(Icons.person_outline_rounded),
          selectedIcon: const Icon(Icons.person_rounded, color: AppColors.primary),
          label: 'Profile'),
      ],
    );
  }

  // ── Helper Widgets ─────────────────────────────────────

  Widget _locationRow({
    required IconData icon, required Color iconColor,
    String? text, TextEditingController? controller, String? hint,
    bool isReadOnly = false,
  }) => Row(children: [
    Icon(icon, color: iconColor, size: 22),
    const SizedBox(width: 12),
    Expanded(
      child: isReadOnly
        ? Text(text ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 14, color: AppColors.textSecondary))
        : TextField(
            controller: controller,
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(
                color: AppColors.textHint, fontSize: 14),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
    ),
  ]);



  Widget _vehicleCard(String type, IconData iconData, String label) {
    final selected = _selectedVehicle == type;
    return GestureDetector(
      onTap: () {
        setState(() { 
          _selectedVehicle = type; 
          _serviceType = ''; // Deselect service if vehicle selected
          _fareData = null; 
        });
        _openSearchPage();
      },
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.08) : AppColors.white,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider, 
            width: selected ? 2 : 1.5),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: AppColors.primary.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2)
              )
          ],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(iconData, size: 30,
            color: selected ? AppColors.primary : AppColors.textSecondary),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.poppins(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textPrimary)),
        ]),
      ),
    );
  }

  Widget _serviceItemCard(String type, IconData iconData, String label) {
    final selected = _serviceType == type;
    return GestureDetector(
      onTap: () {
        setState(() { 
          _serviceType = type; 
          _selectedVehicle = ''; // Deselect vehicle if service selected
          _fareData = null; 
        });
        _openSearchPage();
      },
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.08) : AppColors.white,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider, 
            width: selected ? 2 : 1.5),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: AppColors.primary.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2)
              )
          ],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(iconData, size: 30, 
            color: selected ? AppColors.primary : AppColors.textSecondary),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.poppins(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textPrimary)),
        ]),
      ),
    );
  }

  void _openSearchPage() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            Text('Where are you going?', 
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
            
            const SizedBox(height: 20),
            
            // Pickup input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                decoration: InputDecoration(
                  border: InputBorder.none,
                  icon: const Icon(Icons.my_location_rounded, color: AppColors.primary, size: 20),
                  hintText: 'Current Location',
                  hintStyle: GoogleFonts.poppins(color: AppColors.textSecondary),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Destination input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  icon: const Icon(Icons.location_on_rounded, color: AppColors.error, size: 20),
                  hintText: 'Search destination',
                  hintStyle: GoogleFonts.poppins(color: AppColors.textSecondary),
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Dummy list of recent places
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.background,
                child: Icon(Icons.home_rounded, color: AppColors.textPrimary),
              ),
              title: Text('Home', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              subtitle: Text('123 Main Street', style: GoogleFonts.poppins(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _estimateFare(); // trigger fake fare
              },
            ),
            const Divider(color: AppColors.divider),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.background,
                child: Icon(Icons.work_rounded, color: AppColors.textPrimary),
              ),
              title: Text('Work', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              subtitle: Text('456 Business Park', style: GoogleFonts.poppins(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _estimateFare(); // trigger fake fare
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _fareCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
    ),
    child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Estimated Fare',
          style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary)),
        Text('₹${_fareData!['estimated_fare']}',
          style: GoogleFonts.poppins(
            fontSize: 22, fontWeight: FontWeight.w800,
            color: AppColors.primary)),
      ]),
      const Divider(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _fareRow('Distance', '${_fareData!['distance_km']} km'),
        _fareRow('Time',     '${_fareData!['duration_min']} min'),
        _fareRow('Base',     '₹${_fareData!['base_fare']}'),
      ]),
      if ((_fareData!['surge_multiplier'] ?? 1.0) > 1.0) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '⚡ ${_fareData!['surge_multiplier']}x Surge Pricing Active',
            style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: AppColors.warning)),
        ),
      ],
    ]),
  );

  Widget _fareRow(String label, String value) => Column(children: [
    Text(value, style: GoogleFonts.poppins(
      fontSize: 14, fontWeight: FontWeight.w700,
      color: AppColors.textPrimary)),
    Text(label, style: GoogleFonts.poppins(
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
      const SizedBox(height: 8),
      Text(trip['pickup_address'] ?? '',
        maxLines: 1, overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textPrimary)),
      Text('→ ${trip['drop_address'] ?? ''}',
        maxLines: 1, overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('₹${trip['actual_fare'] ?? trip['estimated_fare']}',
          style: GoogleFonts.poppins(
            fontSize: 15, fontWeight: FontWeight.w700,
            color: AppColors.primary)),
        Text('${trip['distance_km']} km',
          style: GoogleFonts.poppins(
            fontSize: 12, color: AppColors.textSecondary)),
      ]),
    ]),
  );

  Widget _statusBadge(String status) {
    final colors = {
      'completed': AppColors.success,
      'cancelled': AppColors.error,
      'started'  : AppColors.primary,
      'requested': AppColors.warning,
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

  Widget _tripLocationRow(IconData icon, Color color, String address) =>
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(address,
        style: GoogleFonts.poppins(
          fontSize: 13, color: AppColors.textPrimary))),
    ]);

  Widget _txnRow(Map txn) {
    final isCredit = txn['type'] == 'credit' || txn['type'] == 'bonus'
        || txn['type'] == 'refund';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: (isCredit ? AppColors.success : AppColors.error)
                .withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isCredit ? Icons.arrow_downward_rounded
                     : Icons.arrow_upward_rounded,
            color: isCredit ? AppColors.success : AppColors.error,
            size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(txn['description'] ?? '',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w500,
                color: AppColors.textPrimary)),
            Text('Balance: ₹${txn['balance_after']}',
              style: GoogleFonts.poppins(
                fontSize: 11, color: AppColors.textSecondary)),
          ],
        )),
        Text('${isCredit ? '+' : '-'}₹${txn['amount']}',
          style: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: isCredit ? AppColors.success : AppColors.error)),
      ]),
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

  Widget _quickTips() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('💡 Quick Tips',
          style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: AppColors.primary)),
        const SizedBox(height: 8),
        _tip('Add money to wallet for faster checkout'),
        _tip('Use referral code to earn ₹30 for each friend'),
        _tip('Rate your driver to help the community'),
      ],
    ),
  );

  Widget _tip(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      const Icon(Icons.check_circle_rounded,
          color: AppColors.primary, size: 14),
      const SizedBox(width: 6),
      Expanded(child: Text(text,
        style: GoogleFonts.poppins(
          fontSize: 12, color: AppColors.textSecondary))),
    ]),
  );

  Widget _emptyState(String title, String sub, String emoji) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(emoji, style: const TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      Text(title, style: GoogleFonts.poppins(
        fontSize: 16, fontWeight: FontWeight.w600,
        color: AppColors.textPrimary)),
      const SizedBox(height: 4),
      Text(sub, textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 13, color: AppColors.textSecondary)),
    ]),
  );

  void _showAddMoneyDialog() {
    final ctrl = TextEditingController();
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
          Text('Add Money to Wallet',
            style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          // Quick amounts
          Wrap(spacing: 10, children: [100, 200, 500, 1000].map((amt) =>
            ActionChip(
              label: Text('₹$amt', style: GoogleFonts.poppins()),
              onPressed: () => ctrl.text = '$amt',
            )).toList()),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            style: GoogleFonts.poppins(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Enter amount',
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
                if (amt < 10) return;
                final res = await ApiService.addMoneyToWallet(amt);
                Navigator.pop(context);
                if (res['success']) {
                  await AuthService.updateWallet(
                    res['data']['new_balance'] ?? 0.0);
                  setState(() {});
                  _showSnack('₹$amt added to wallet! 💰', isError: false);
                } else {
                  _showSnack(res['error'], isError: true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text('Add Money',
                style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}
