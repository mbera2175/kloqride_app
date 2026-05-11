import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';
import 'driver_step3_license.dart';

class DriverStep2Vehicle extends StatefulWidget {
  final String  phone;
  final String  otp;
  final String  fullName;
  final String? email;
  final String  gender;
  final String  language;
  final String? referral;

  const DriverStep2Vehicle({
    super.key,
    required this.phone,
    required this.otp,
    required this.fullName,
    this.email,
    required this.gender,
    required this.language,
    this.referral,
  });

  @override
  State<DriverStep2Vehicle> createState() => _DriverStep2VehicleState();
}

class _DriverStep2VehicleState extends State<DriverStep2Vehicle> {
  final _plateCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();

  String _vehicleType  = 'auto';
  List<String> _selectedServices = ['ride'];
  int    _regYear      = DateTime.now().year;
  int    _expireYear   = DateTime.now().year + 1;
  String _error        = '';

  final List<Map<String, dynamic>> _vehicles = [
    {'type': 'bike',      'icon': Icons.two_wheeler_rounded,      'label': 'Bike'},
    {'type': 'auto',      'icon': Icons.local_taxi_rounded,       'label': 'Auto'},
    {'type': 'toto',      'icon': Icons.electric_rickshaw_rounded,'label': 'Toto'},
    {'type': 'mini',      'icon': Icons.directions_car_rounded,   'label': 'Mini'},
    {'type': 'sedan',     'icon': Icons.time_to_leave_rounded,    'label': 'Sedan'},
    {'type': 'suv',       'icon': Icons.airport_shuttle_rounded,  'label': 'SUV'},
    {'type': 'ambulance', 'icon': Icons.medical_services_rounded, 'label': 'Ambulance'},
  ];

  void _next() {
    if (_plateCtrl.text.trim().isEmpty ||
        _brandCtrl.text.trim().isEmpty ||
        _modelCtrl.text.trim().isEmpty ||
        _colorCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please fill all vehicle details');
      return;
    }
    if (_expireYear <= _regYear) {
      setState(() => _error = 'Expiry year must be after registration year');
      return;
    }
    setState(() => _error = '');
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DriverStep3License(
        phone       : widget.phone,
        otp         : widget.otp,
        fullName    : widget.fullName,
        email       : widget.email,
        gender      : widget.gender,
        language    : widget.language,
        referral    : widget.referral,
        vehicleType : _vehicleType,
        serviceType : _selectedServices.join(','),
        plateNumber : _plateCtrl.text.trim().toUpperCase(),
        brand       : _brandCtrl.text.trim(),
        model       : _modelCtrl.text.trim(),
        color       : _colorCtrl.text.trim(),
        regYear     : _regYear,
        expireYear  : _expireYear,
      ),
    ));
  }

  void _skip() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DriverStep3License(
        phone      : widget.phone,
        otp        : widget.otp,
        fullName   : widget.fullName,
        email      : widget.email,
        gender     : widget.gender,
        language   : widget.language,
        referral   : widget.referral,
        vehicleType: _vehicleType,
        serviceType: _selectedServices.join(','),
        plateNumber: '',
        brand      : '',
        model      : '',
        color      : '',
        regYear    : _regYear,
        expireYear : _expireYear,
      ),
    ));
  }

  @override
  void dispose() {
    _plateCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context)),
        title: Text('Vehicle Details',
          style: GoogleFonts.poppins(
            fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: _skip,
            child: Text('Skip',
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary, fontSize: 14)),
          ),
        ],
      ),
      body: Column(children: [
        _stepBar(2),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _stepTitle('Vehicle Details', Icons.directions_car_rounded),
                const SizedBox(height: 4),
                Text('Step 2 of 4',
                  style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 24),

                // ── Vehicle Type ──────────────────────
                _label('Vehicle Type *'),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.1,
                  children: _vehicles.map((v) =>
                    _vehicleCard(v['type'], v['icon'], v['label'])).toList(),
                ),

                const SizedBox(height: 16),

                // ── Service Type ──────────────────────
                _label('Service Type *'),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.5,
                  children: [
                    _serviceCard('ride', Icons.person_rounded, 'Rides', 'Passengers'),
                    if (_vehicleType == 'bike' || _vehicleType == 'toto')
                      _serviceCard('delivery', Icons.inventory_2_rounded, 'Delivery', 'Packages'),
                    if (_vehicleType == 'bike') ...[
                      _serviceCard('food', Icons.fastfood_rounded, 'Food', 'Meals'),
                      _serviceCard('medicine', Icons.medical_information_rounded, 'Medicine', 'Meds'),
                    ]
                  ],
                ),

                const SizedBox(height: 16),

                // ── Brand ─────────────────────────────
                _label('Vehicle Brand *'),
                _textField(_brandCtrl, 'e.g. Honda, Bajaj, Maruti',
                    Icons.branding_watermark_outlined,
                    capitalization: TextCapitalization.words),

                const SizedBox(height: 16),

                // ── Model ─────────────────────────────
                _label('Vehicle Model *'),
                _textField(_modelCtrl, 'e.g. Activa, Swift, Pulsar',
                    Icons.directions_car_outlined,
                    capitalization: TextCapitalization.words),

                const SizedBox(height: 16),

                // ── Color ─────────────────────────────
                _label('Vehicle Color *'),
                _textField(_colorCtrl, 'e.g. White, Black, Silver',
                    Icons.color_lens_outlined,
                    capitalization: TextCapitalization.words),

                const SizedBox(height: 16),

                // ── Plate Number ──────────────────────
                _label('Registration / Plate Number *'),
                _textField(_plateCtrl, 'e.g. WB01AB1234',
                    Icons.pin_outlined,
                    capitalization: TextCapitalization.characters),

                const SizedBox(height: 16),

                // ── Registration Year ─────────────────
                _label('Registration Year *'),
                _yearDropdown(
                  value  : _regYear,
                  from   : DateTime.now().year - 20,
                  to     : DateTime.now().year,
                  onChanged: (v) => setState(() => _regYear = v!),
                ),

                const SizedBox(height: 16),

                // ── Expiry Year ───────────────────────
                _label('Registration Expiry Year *'),
                _yearDropdown(
                  value  : _expireYear,
                  from   : DateTime.now().year,
                  to     : DateTime.now().year + 15,
                  onChanged: (v) => setState(() => _expireYear = v!),
                ),

                // ── Error ─────────────────────────────
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _errorBox(_error),
                ],

                const SizedBox(height: 32),

                _nextBtn('Continue to License Details →', _next),

                const SizedBox(height: 12),

                Center(child: TextButton(
                  onPressed: _skip,
                  child: Text('Skip this step',
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecondary, fontSize: 13)),
                )),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ── Small widgets ──────────────────────────────────────

  Widget _vehicleCard(String type, IconData iconData, String label) {
    final selected = _vehicleType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _vehicleType = type;
          _selectedServices = ['ride']; // Reset on vehicle change
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? AppColors.driverColor.withOpacity(0.08)
              : AppColors.white,
          border: Border.all(
            color: selected ? AppColors.driverColor : AppColors.divider,
            width: selected ? 2 : 1.5),
          borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(iconData, size: 26, color: selected ? AppColors.driverColor : AppColors.textPrimary),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: selected
                  ? AppColors.driverColor
                  : AppColors.textPrimary)),
          ]),
      ),
    );
  }

  Widget _serviceCard(
      String type, IconData iconData, String title, String sub) {
    final selected = _selectedServices.contains(type);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (selected) {
            if (_selectedServices.length > 1) { // Prevent deselecting if it's the only one
              _selectedServices.remove(type);
            }
          } else {
            if (_vehicleType != 'bike' && _vehicleType != 'toto') {
              _selectedServices = ['ride']; // Enforce only ride for cars
            } else {
              _selectedServices.add(type);
            }
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.driverColor.withOpacity(0.08)
              : AppColors.white,
          border: Border.all(
            color: selected ? AppColors.driverColor : AppColors.divider,
            width: selected ? 2 : 1.5),
          borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(iconData, size: 24, color: selected ? AppColors.driverColor : AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: selected
                      ? AppColors.driverColor
                      : AppColors.textPrimary)),
                Text(sub, style: GoogleFonts.poppins(
                  fontSize: 10, color: AppColors.textSecondary)),
            ]),
          )
        ]),
      ),
    );
  }

  Widget _yearDropdown({
    required int value,
    required int from,
    required int to,
    required void Function(int?) onChanged,
  }) {
    final years = List.generate(to - from + 1, (i) => from + i).reversed.toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider, width: 1.5),
        borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value, isExpanded: true,
          style: GoogleFonts.poppins(
            fontSize: 14, color: AppColors.textPrimary),
          items: years.map((y) => DropdownMenuItem(
            value: y, child: Text('$y'))).toList(),
          onChanged: onChanged)));
  }

  Widget _stepBar(int current) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    child: Column(children: [
      Row(children: List.generate(4, (i) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          height: 4,
          decoration: BoxDecoration(
            color: i < current
                ? AppColors.driverColor
                : AppColors.divider,
            borderRadius: BorderRadius.circular(2)))))),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
        _stepLabel('Personal', 1, current),
        _stepLabel('Vehicle',  2, current),
        _stepLabel('License',  3, current),
        _stepLabel('Docs',     4, current),
      ]),
    ]));

  Widget _stepLabel(String label, int step, int current) => Text(label,
    style: GoogleFonts.poppins(
      fontSize: 10,
      fontWeight: step <= current
          ? FontWeight.w700 : FontWeight.w400,
      color: step <= current
          ? AppColors.driverColor : AppColors.textHint));

  Widget _stepTitle(String title, IconData icon) => Row(children: [
    Icon(icon, color: AppColors.driverColor, size: 22),
    const SizedBox(width: 8),
    Text(title, style: GoogleFonts.poppins(
      fontSize: 18, fontWeight: FontWeight.w700,
      color: AppColors.textPrimary))]);

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: GoogleFonts.poppins(
      fontSize: 13, fontWeight: FontWeight.w500,
      color: AppColors.textPrimary)));

  Widget _textField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputType type = TextInputType.text,
  }) => TextFormField(
    controller: ctrl,
    keyboardType: type,
    textCapitalization: capitalization,
    style: GoogleFonts.poppins(fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        color: AppColors.textHint, fontSize: 14),
      prefixIcon: Icon(icon,
        color: AppColors.textSecondary, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.divider, width: 1.5)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.divider, width: 1.5)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.driverColor, width: 2)),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14, vertical: 14)));

  Widget _errorBox(String msg) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.error.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      const Icon(Icons.error_outline,
        color: AppColors.error, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(msg, style: GoogleFonts.poppins(
        fontSize: 13, color: AppColors.error))),
    ]));

  Widget _nextBtn(String label, VoidCallback onTap) => SizedBox(
    width: double.infinity, height: 54,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.driverColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
        elevation: 0),
      child: Text(label, style: GoogleFonts.poppins(
        fontSize: 15, fontWeight: FontWeight.w600))));
}
