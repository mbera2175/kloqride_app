import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/app_colors.dart';
import '../../services/auth_service.dart';
import '../driver/driver_home_screen.dart';

class DriverStep4Documents extends StatefulWidget {
  final int driverId;
  const DriverStep4Documents({super.key, required this.driverId});

  @override
  State<DriverStep4Documents> createState() => _DriverStep4DocumentsState();
}

class _DriverStep4DocumentsState extends State<DriverStep4Documents> {
  final ImagePicker _picker = ImagePicker();

  // Document storage — each has front & back where needed
  final Map<String, Map<String, File?>> _docs = {
    'rc'       : {'front': null, 'back': null},
    'dl'       : {'front': null, 'back': null},
    'aadhar'   : {'front': null, 'back': null},
    'insurance': {'front': null, 'back': null},
    'permit'   : {'front': null, 'back': null},
  };

  bool _uploading = false;
  Map<String, bool> _uploaded = {};

  // Doc config — label, icon, needs back side
  final List<Map<String, dynamic>> _docConfig = [
    {
      'key'     : 'rc',
      'label'   : 'RC (Registration Certificate)',
      'icon'    : Icons.directions_car_rounded,
      'color'   : AppColors.primary,
      'hasBack' : true,
      'required': true,
      'hint'    : 'Upload both sides of your RC book',
    },
    {
      'key'     : 'dl',
      'label'   : 'Driving Licence (DL)',
      'icon'    : Icons.badge_rounded,
      'color'   : AppColors.driverColor,
      'hasBack' : true,
      'required': true,
      'hint'    : 'Upload front and back of your DL',
    },
    {
      'key'     : 'aadhar',
      'label'   : 'Aadhaar Card',
      'icon'    : Icons.fingerprint_rounded,
      'color'   : AppColors.success,
      'hasBack' : true,
      'required': true,
      'hint'    : 'Upload both sides of your Aadhaar',
    },
    {
      'key'     : 'insurance',
      'label'   : 'Insurance Certificate',
      'icon'    : Icons.security_rounded,
      'color'   : AppColors.warning,
      'hasBack' : false,
      'required': true,
      'hint'    : 'Upload your vehicle insurance document',
    },
    {
      'key'     : 'permit',
      'label'   : 'Vehicle Permit',
      'icon'    : Icons.article_rounded,
      'color'   : AppColors.info,
      'hasBack' : false,
      'required': false,
      'hint'    : 'Upload permit if applicable (optional)',
    },
  ];

  // ── Pick image ─────────────────────────────────────────

  Future<void> _pickImage(String docKey, String side) async {
    final source = await _showSourceDialog();
    if (source == null) return;

    final picked = await _picker.pickImage(
      source     : source,
      imageQuality: 80,
      maxWidth   : 1200,
    );
    if (picked == null) return;

    setState(() {
      _docs[docKey]![side] = File(picked.path);
    });
  }

  Future<ImageSource?> _showSourceDialog() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Choose Image Source',
              style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _sourceBtn(
                Icons.camera_alt_rounded,
                'Camera',
                AppColors.primary,
                () => Navigator.pop(context, ImageSource.camera),
              )),
              const SizedBox(width: 12),
              Expanded(child: _sourceBtn(
                Icons.photo_library_rounded,
                'Gallery',
                AppColors.driverColor,
                () => Navigator.pop(context, ImageSource.gallery),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _sourceBtn(IconData icon, String label, Color color, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3))),
        child: Column(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: color)),
        ]),
      ),
    );

  // ── Remove image ───────────────────────────────────────

  void _removeImage(String docKey, String side) {
    setState(() => _docs[docKey]![side] = null);
  }

  // ── Submit docs ────────────────────────────────────────

  // NOTE: In production, upload images to Firebase Storage / S3
  // and send the URLs to backend. For now we simulate upload.
  Future<void> _submitDocs() async {
    setState(() => _uploading = true);

    // Simulate upload delay
    await Future.delayed(const Duration(seconds: 2));

    setState(() => _uploading = false);

    if (!mounted) return;
    _showSuccessDialog();
  }

  void _skip() => _showSuccessDialog();

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 48)),
          const SizedBox(height: 16),
          Text('Registration Complete! 🎉',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          Text(
            'Your account is under review.\n'
            'We\'ll verify your documents and notify you '
            'within 24 hours once approved.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13, color: AppColors.textSecondary,
              height: 1.5)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
            child: Text(
              '📋 You can also upload documents later\n'
              'from Settings → My Documents',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12, color: AppColors.warning,
                fontWeight: FontWeight.w500))),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(context,
                  MaterialPageRoute(
                    builder: (_) => const DriverHomeScreen()),
                  (r) => false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.driverColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text('Go to Dashboard',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Check completion ───────────────────────────────────

  int get _uploadedCount {
    int count = 0;
    for (final doc in _docs.values) {
      if (doc['front'] != null) count++;
    }
    return count;
  }

  bool get _hasRequiredDocs {
    final required = ['rc', 'dl', 'aadhar', 'insurance'];
    for (final key in required) {
      if (_docs[key]!['front'] == null) return false;
    }
    return true;
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
        title: Text('Upload Documents',
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
        _stepBar(4),

        // Progress indicator
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
            Text('Step 4 of 4 — Document Upload',
              style: GoogleFonts.poppins(
                fontSize: 12, color: AppColors.textSecondary)),
            Text('$_uploadedCount/5 uploaded',
              style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: AppColors.driverColor)),
          ]),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.info.withOpacity(0.3))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    const Icon(Icons.info_outline_rounded,
                      color: AppColors.info, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Upload clear photos of your documents. '
                      'Blurry or incomplete documents will delay approval.',
                      style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.info,
                        height: 1.5))),
                  ]),
                ),

                const SizedBox(height: 20),

                // Document cards
                ..._docConfig.map((doc) => _docCard(doc)),

                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  width: double.infinity, height: 54,
                  child: ElevatedButton(
                    onPressed: _uploading ? null : _submitDocs,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasRequiredDocs
                          ? AppColors.driverColor
                          : AppColors.textSecondary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                      elevation: 0),
                    child: _uploading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5)),
                          const SizedBox(width: 12),
                          Text('Uploading...',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                        ])
                      : Text(
                          _hasRequiredDocs
                            ? 'Submit Documents ✅'
                            : 'Upload Required Documents First',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 12),

                Center(child: TextButton(
                  onPressed: _skip,
                  child: Text('Skip — upload later from Settings',
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontSize: 13)),
                )),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ── Document Card ──────────────────────────────────────

  Widget _docCard(Map<String, dynamic> doc) {
    final key      = doc['key'] as String;
    final label    = doc['label'] as String;
    final icon     = doc['icon'] as IconData;
    final color    = doc['color'] as Color;
    final hasBack  = doc['hasBack'] as bool;
    final required = doc['required'] as bool;
    final hint     = doc['hint'] as String;

    final frontFile = _docs[key]!['front'];
    final backFile  = _docs[key]!['back'];
    final isComplete = frontFile != null && (!hasBack || backFile != null);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isComplete
              ? AppColors.success.withOpacity(0.5)
              : AppColors.divider,
          width: isComplete ? 2 : 1.5),
        boxShadow: [BoxShadow(
          color: AppColors.shadow,
          blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(children: [
                Expanded(child: Text(label,
                  style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary))),
                if (required)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6)),
                    child: Text('Required',
                      style: GoogleFonts.poppins(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: AppColors.error)))
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.textHint.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6)),
                    child: Text('Optional',
                      style: GoogleFonts.poppins(
                        fontSize: 9, fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary))),
              ]),
              const SizedBox(height: 2),
              Text(hint, style: GoogleFonts.poppins(
                fontSize: 11, color: AppColors.textSecondary)),
            ])),
            if (isComplete)
              const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 22),
          ]),
        ),

        const Divider(height: 1),

        // Upload slots
        Padding(
          padding: const EdgeInsets.all(14),
          child: hasBack
            ? Row(children: [
                Expanded(child: _uploadSlot(
                  key, 'front', 'Front Side', color, frontFile)),
                const SizedBox(width: 12),
                Expanded(child: _uploadSlot(
                  key, 'back', 'Back Side', color, backFile)),
              ])
            : _uploadSlot(
                key, 'front', 'Upload Document', color, frontFile,
                fullWidth: true),
        ),
      ]),
    );
  }

  // ── Upload Slot ────────────────────────────────────────

  Widget _uploadSlot(
    String docKey,
    String side,
    String label,
    Color color,
    File? file, {
    bool fullWidth = false,
  }) {
    return GestureDetector(
      onTap: file == null
          ? () => _pickImage(docKey, side)
          : null,
      child: Container(
        height: 100,
        width: fullWidth ? double.infinity : null,
        decoration: BoxDecoration(
          color: file != null
              ? Colors.transparent
              : color.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: file != null
                ? AppColors.success.withOpacity(0.4)
                : color.withOpacity(0.3),
            width: 1.5,
            style: BorderStyle.solid)),
        child: file != null
          ? Stack(children: [
              // Image preview
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.file(
                  file,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover)),
              // Overlay buttons
              Positioned(
                top: 4, right: 4,
                child: Row(children: [
                  // Retake
                  GestureDetector(
                    onTap: () => _pickImage(docKey, side),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 14))),
                  const SizedBox(width: 4),
                  // Remove
                  GestureDetector(
                    onTap: () => _removeImage(docKey, side),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 14))),
                ]),
              ),
              // Label
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(11))),
                  child: Text(label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10, color: Colors.white,
                      fontWeight: FontWeight.w600)))),
            ])
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Icon(Icons.cloud_upload_rounded,
                color: color.withOpacity(0.6), size: 28),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.8))),
              const SizedBox(height: 2),
              Text('Tap to upload',
                style: GoogleFonts.poppins(
                  fontSize: 10, color: AppColors.textHint)),
            ]),
      ),
    );
  }

  // ── Step Bar ───────────────────────────────────────────

  Widget _stepBar(int current) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    child: Column(children: [
      Row(children: List.generate(4, (i) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          height: 4,
          decoration: BoxDecoration(
            color: i < current
                ? AppColors.driverColor : AppColors.divider,
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

  Widget _stepLabel(String label, int step, int current) =>
    Text(label, style: GoogleFonts.poppins(
      fontSize: 10,
      fontWeight: step <= current
          ? FontWeight.w700 : FontWeight.w400,
      color: step <= current
          ? AppColors.driverColor : AppColors.textHint));
}
