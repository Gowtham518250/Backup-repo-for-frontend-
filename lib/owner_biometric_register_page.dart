import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'security_service.dart';
import 'visual_widgets.dart';

/// After owner OTP (gate), or anytime from dashboard / Shop Details (`openedFromDashboard`).
class OwnerBiometricRegisterPage extends StatefulWidget {
  const OwnerBiometricRegisterPage({super.key, this.openedFromDashboard = false});

  /// When true: back pops the route; already-verified owners see manage/test UI instead of instant redirect.
  final bool openedFromDashboard;

  @override
  State<OwnerBiometricRegisterPage> createState() => _OwnerBiometricRegisterPageState();
}

class _OwnerBiometricRegisterPageState extends State<OwnerBiometricRegisterPage> {
  bool _bootstrapping = true;
  bool _submitting = false;
  bool _hardwareOk = false;
  String? _redirectNote;
  bool _reviewMode = false;
  bool _biometricOn = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await SecurityService.migrateLegacyOwnerBiometricStatus();
    if (!mounted) return;

    if (kIsWeb) {
      if (widget.openedFromDashboard) {
        setState(() {
          _bootstrapping = false;
          _hardwareOk = false;
          _redirectNote = 'Fingerprint and face login are available on the Android/iOS app only.';
        });
        return;
      }
      await SecurityService.setOwnerBiometricStatusDeclined();
      _goLeave();
      return;
    }

    final verified = await SecurityService.isOwnerBiometricVerificationComplete();
    if (verified && widget.openedFromDashboard) {
      final hw = await SecurityService.isBiometricHardwareAvailable();
      final bioOn = await SecurityService.isBiometricEnabled();
      setState(() {
        _bootstrapping = false;
        _reviewMode = true;
        _hardwareOk = hw;
        _biometricOn = bioOn;
      });
      return;
    }

    if (verified && !widget.openedFromDashboard) {
      _goLeave();
      return;
    }

    final hw = await SecurityService.isBiometricHardwareAvailable();
    if (!hw) {
      if (widget.openedFromDashboard) {
        setState(() {
          _bootstrapping = false;
          _hardwareOk = false;
          _redirectNote =
              'No fingerprint or face unlock detected on this device. Add one in phone Settings, or use PIN and OTP.';
        });
        return;
      }
      await SecurityService.setOwnerBiometricStatusDeclined();
      setState(() {
        _bootstrapping = false;
        _hardwareOk = false;
        _redirectNote =
            'This device has no enrolled fingerprint or face unlock. Biometric login stays off. You can use PIN and OTP.';
      });
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) _goLeave();
      return;
    }

    setState(() {
      _bootstrapping = false;
      _hardwareOk = true;
    });
  }

  void _goLeave() {
    if (!mounted) return;
    if (widget.openedFromDashboard) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    }
  }

  Future<void> _registerBiometric() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    bool ok = false;
    String? failure;
    try {
      ok = await SecurityService.authenticateBiometrically(
        reason: 'Confirm your enrolled fingerprint or face to enable owner login',
      );
    } catch (e) {
      failure = e.toString();
    }
    if (!mounted) return;
    if (ok) {
      await SecurityService.setOwnerBiometricStatusVerified();
      await SecurityService.setBiometricEnabled(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Biometric login enabled for this device.'),
          backgroundColor: AppColors.secondary,
        ),
      );
      if (widget.openedFromDashboard && _reviewMode) {
        setState(() {
          _submitting = false;
          _biometricOn = true;
        });
      } else {
        _goLeave();
      }
    } else {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failure == null
                ? 'Verification cancelled or failed. Check that a fingerprint/face is enrolled in phone Settings.'
                : 'Biometric error: $failure',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _testBiometric() async {
    setState(() => _submitting = true);
    final ok = await SecurityService.authenticateBiometrically(
      reason: 'Test fingerprint or face for Retail Mind',
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Biometric check succeeded.' : 'Biometric check failed or cancelled.'),
        backgroundColor: ok ? AppColors.secondary : Colors.redAccent,
      ),
    );
  }

  Future<void> _turnOffBiometricOnly() async {
    setState(() => _submitting = true);
    await SecurityService.setBiometricEnabled(false);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _biometricOn = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Biometric login is off. You can turn it on again here or from Shop Details.'),
        backgroundColor: Color(0xFF6B7280),
      ),
    );
  }

  Future<void> _decline() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await SecurityService.setOwnerBiometricStatusDeclined();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Biometric login is off. Enable later from Shop Details or the dashboard shortcut.'),
        backgroundColor: Color(0xFF6B7280),
      ),
    );
    _goLeave();
  }

  Widget _buildGateBody() {
    return Column(
      children: [
        Text(
          'Register your fingerprint or face for quick owner login. Enrollment is managed in your phone settings; here we only link this app to the biometrics already on the device.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 14,
            height: 1.45,
            color: Colors.white70,
          ),
        ),
        if (_redirectNote != null) ...[
          const SizedBox(height: 24),
          Text(
            _redirectNote!,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white60),
          ),
        ],
        const SizedBox(height: 36),
        if (_bootstrapping && _redirectNote == null)
          const Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(color: Color(0xFF818CF8)),
          ),
        if (!_bootstrapping && _hardwareOk) ...[
          if (_submitting)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: CircularProgressIndicator(color: Color(0xFF818CF8)),
            ),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _registerBiometric,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Register fingerprint / face',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: _submitting ? null : _decline,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                widget.openedFromDashboard
                    ? 'Not now'
                    : 'Not now (turn off biometric login)',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
        ],
        if (!_bootstrapping && !_hardwareOk && widget.openedFromDashboard && _redirectNote != null) ...[
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _goLeave,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF818CF8)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Close', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReviewBody() {
    return Column(
      children: [
        Text(
          _hardwareOk
              ? 'This device is registered for owner biometric login. You can test, turn login on or off, or close when done.'
              : 'Biometric hardware is not available. Use PIN and OTP.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 14, height: 1.45, color: Colors.white70),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Text(
            'Biometric login: ${_biometricOn ? "On" : "Off"}',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _biometricOn ? const Color(0xFF34D399) : Colors.white70,
            ),
          ),
        ),
        const SizedBox(height: 28),
        if (_submitting)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: CircularProgressIndicator(color: Color(0xFF818CF8)),
          ),
        if (_hardwareOk) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _submitting ? null : _testBiometric,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Test fingerprint / face', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          if (!_biometricOn)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _submitting ? null : _registerBiometric,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF34D399)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Turn on biometric login', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _submitting ? null : _turnOffBiometricOnly,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Turn off biometric login', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ),
        ],
        const SizedBox(height: 20),
        TextButton(
          onPressed: _submitting ? null : _goLeave,
          child: Text(
            'Done',
            style: GoogleFonts.poppins(color: const Color(0xFF818CF8), fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fingerprint_rounded, size: 56, color: Color(0xFF818CF8)),
            ),
            const SizedBox(height: 28),
            Text(
              'Device authentication',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            if (_reviewMode)
              _buildReviewBody()
            else
              _buildGateBody(),
          ],
        ),
      ),
    );

    final scaffold = Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: widget.openedFromDashboard
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: _submitting ? null : _goLeave,
              ),
            )
          : null,
      body: SafeArea(child: Center(child: body)),
    );

    if (widget.openedFromDashboard) {
      return scaffold;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) _decline();
      },
      child: scaffold,
    );
  }
}
