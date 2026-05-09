import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
const String baseUrl = 'https://kloqride-backend-production.up.railway.app';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  HttpOverrides.global = MyHttpOverrides();
  runApp(const KloqRideApp());
}

class KloqRideApp extends StatelessWidget {
  const KloqRideApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '🚖 Kloq Ride',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

// ─── LOGIN ───────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/password/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': _phoneController.text,
          'password': _passwordController.text,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['access_token']);
        await prefs.setString('name', data['full_name'] ?? '');
        if (mounted) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      } else {
        final error = jsonDecode(response.body);
        _showError(error['detail'] ?? 'Login failed.');
      }
    } catch (e) {
      _showError('Connection error. Try again.');
    }
    setState(() => _loading = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.amber[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text('🚖', style: TextStyle(fontSize: 64)),
              const Text('Kloq Ride',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const Text('Bengali-first ride hailing',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('Login', style: TextStyle(fontSize: 18)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SendOTPScreen())),
                child: const Text('No account? Register here'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── SEND OTP ────────────────────────────────────────────────
class SendOTPScreen extends StatefulWidget {
  const SendOTPScreen({super.key});
  @override
  State<SendOTPScreen> createState() => _SendOTPScreenState();
}

class _SendOTPScreenState extends State<SendOTPScreen> {
  final _phoneController = TextEditingController();
  bool _loading = false;

  Future<void> _sendOTP() async {
    setState(() => _loading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/otp/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': _phoneController.text}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final devOtp = data['dev_otp']?.toString() ?? '';
        if (mounted) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => RegisterScreen(
              phone: _phoneController.text,
              devOtp: devOtp,
            ),
          ));
        }
      } else {
        final error = jsonDecode(response.body);
        _showError(error['detail'] ?? 'Failed to send OTP.');
      }
    } catch (e) {
      _showError('Connection error. Try again.');
    }
    setState(() => _loading = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register'), backgroundColor: Colors.amber),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text('Enter your phone number',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 24),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _sendOTP,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Send OTP', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── REGISTER ────────────────────────────────────────────────
class RegisterScreen extends StatefulWidget {
  final String phone;
  final String devOtp;
  const RegisterScreen({super.key, required this.phone, this.devOtp = ''});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.devOtp.isNotEmpty) {
      _otpController.text = widget.devOtp;
    }
  }

  Future<void> _register() async {
    setState(() => _loading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register/rider'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': _nameController.text,
          'phone': widget.phone,
          'otp': _otpController.text,
          'password': _passwordController.text,
          'language': 'bn',
        }),
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['access_token']);
        await prefs.setString('name', data['full_name'] ?? '');
        if (mounted) {
          Navigator.pushAndRemoveUntil(context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false);
        }
      } else {
        final error = jsonDecode(response.body);
        _showError(error['detail'] ?? 'Registration failed.');
      }
    } catch (e) {
      _showError('Connection error. Try again.');
    }
    setState(() => _loading = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Complete Registration'),
          backgroundColor: Colors.amber),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('OTP sent to ${widget.phone}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (widget.devOtp.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  children: [
                    const Text('🔧 DEV MODE - Your OTP:',
                        style: TextStyle(color: Colors.green)),
                    Text(widget.devOtp,
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            letterSpacing: 8)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _otpController,
              decoration: const InputDecoration(
                labelText: 'Enter OTP',
                prefixIcon: Icon(Icons.sms),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Set Password',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Register', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── HOME ────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _name = '';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _name = prefs.getString('name') ?? 'Rider');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚖 Kloq Ride'),
        backgroundColor: Colors.amber,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (context.mounted) {
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('স্বাগতম, $_name! 🙏',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold)),
            const Text('আজ কোথায় যাবেন?',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 32),
            _MenuCard(
              icon: Icons.directions_car,
              title: 'Book a Ride',
              subtitle: 'Find a driver near you',
              color: Colors.amber,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const BookRideScreen())),
            ),
            const SizedBox(height: 16),
            _MenuCard(
              icon: Icons.history,
              title: 'Trip History',
              subtitle: 'View your past rides',
              color: Colors.blue,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const TripHistoryScreen())),
            ),
            const SizedBox(height: 16),
            _MenuCard(
              icon: Icons.account_balance_wallet,
              title: 'Wallet',
              subtitle: 'Manage your balance',
              color: Colors.green,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}

// ─── BOOK RIDE ───────────────────────────────────────────────
class BookRideScreen extends StatefulWidget {
  const BookRideScreen({super.key});
  @override
  State<BookRideScreen> createState() => _BookRideScreenState();
}

class _BookRideScreenState extends State<BookRideScreen> {
  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  bool _loading = false;
  String? _result;

  Future<void> _bookRide() async {
    setState(() {
      _loading = true;
      _result = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final response = await http.post(
        Uri.parse('$baseUrl/trips/book'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
  'pickup_address': _pickupController.text,
  'pickup_lat': 22.5726,
  'pickup_lng': 88.3639,
  'drop_address': _dropController.text,
  'drop_lat': 22.5200,
  'drop_lng': 88.3800,
  'vehicle_type': 'auto',
  'payment_method': 'cash',
}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() => _result = '✅ Ride booked! Driver is on the way.');
      } else {
        final error = jsonDecode(response.body);
        setState(
            () => _result = '❌ ${error['detail'] ?? 'Booking failed.'}');
      }
    } catch (e) {
      setState(() => _result = '❌ Connection error.');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Book a Ride'),
          backgroundColor: Colors.amber),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _pickupController,
              decoration: const InputDecoration(
                labelText: 'Pickup Location',
                prefixIcon: Icon(Icons.location_on, color: Colors.green),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _dropController,
              decoration: const InputDecoration(
                labelText: 'Drop Location',
                prefixIcon: Icon(Icons.location_on, color: Colors.red),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _bookRide,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Book Ride 🚖',
                        style: TextStyle(fontSize: 18)),
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 24),
              Text(_result!, style: const TextStyle(fontSize: 18)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── TRIP HISTORY ────────────────────────────────────────────
class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});
  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  List trips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final response = await http.get(
        Uri.parse('$baseUrl/trips/my'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        setState(() => trips = jsonDecode(response.body));
      }
    } catch (e) {
      // handle error
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Trip History'),
          backgroundColor: Colors.amber),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : trips.isEmpty
              ? const Center(
                  child: Text('No trips yet! Book your first ride 🚖'))
              : ListView.builder(
                  itemCount: trips.length,
                  itemBuilder: (context, index) {
                    final trip = trips[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: const Icon(Icons.directions_car,
                            color: Colors.amber),
                        title: Text(
                            '${trip['pickup_location']} → ${trip['drop_location']}'),
                        subtitle: Text('Status: ${trip['status']}'),
                      ),
                    );
                  },
                ),
    );
  }
}
