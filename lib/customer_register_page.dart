import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'api_client.dart';

class CustomerRegisterPage extends StatefulWidget {
  const CustomerRegisterPage({super.key});

  @override
  State<CustomerRegisterPage> createState() => _CustomerRegisterPageState();
}

class _CustomerRegisterPageState extends State<CustomerRegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  
  bool _isLoading = false;
  String? _error;

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiClient.postJson(ApiClient.customerRegister, {
        "name": _nameController.text.trim(),
        "email": _emailController.text.trim(),
        "phone": _phoneController.text.trim(),
        "password": _passwordController.text.trim(),
        "city": _cityController.text.trim(),
        "address": _addressController.text.trim(),
        "role": "CUSTOMER",  // 🔧 FIX: Explicitly set role to CUSTOMER
        "is_active": true     // 🔧 FIX: Set is_active to true
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        final data = jsonDecode(response.body);
        final tokenValue = data['access_token'] ?? data['token'];
        final refreshTokenValue = data['refresh_token'];
        
        // Store token for auto-login if needed
        final prefs = await SharedPreferences.getInstance();
        if (tokenValue != null) {
          await prefs.setString('auth_token', tokenValue.toString());
        }
        if (refreshTokenValue != null) {
          await prefs.setString('refresh_token', refreshTokenValue.toString());
        }
        await prefs.setString('user_id', data['customer_id'].toString());
        await prefs.setString('user_type', 'CUSTOMER');
        await prefs.setString('user_name', data['name'] ?? data['user_name'] ?? _nameController.text.trim());
        await prefs.setString('user_email', _emailController.text.trim());
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration successful! Please login.'), backgroundColor: Colors.green));
        Navigator.pop(context);
      } else {
        setState(() {
          _error = jsonDecode(response.body)['detail'] ?? 'Registration failed';
        });
      }
    } catch (e) {
      setState(() => _error = 'Connection failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildField(String hint, IconData icon, TextEditingController controller, {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          prefixIcon: Icon(icon, color: Colors.white54),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Create Account', style: GoogleFonts.poppins(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                _buildField('Full Name', Icons.person, _nameController),
                _buildField('Email Address', Icons.email, _emailController),
                _buildField('Phone Number', Icons.phone, _phoneController),
                _buildField('Password', Icons.lock, _passwordController, obscure: true),
                _buildField('City', Icons.location_city, _cityController),
                _buildField('Full Address', Icons.home, _addressController),
                
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 16),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Sign Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
