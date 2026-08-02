import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/auth_api.dart';

const _codeLength = 6;
const _resendCooldownSeconds = 60;

/// Confirms the user actually owns the email they entered, then hands off
/// to [onVerified] — reused by both Sign Up (verify → create account) and
/// Forgot Password (verify → go choose a new password), so what happens
/// after a correct code is entered is the caller's decision, not this
/// screen's.
class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String title;
  final Future<void> Function(BuildContext context) onVerified;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.title,
    required this.onVerified,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _controllers = List.generate(_codeLength, (_) => TextEditingController());
  final _focusNodes = List.generate(_codeLength, (_) => FocusNode());

  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorText;
  Timer? _resendTimer;
  int _secondsUntilResend = _resendCooldownSeconds;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCooldown() {
    setState(() => _secondsUntilResend = _resendCooldownSeconds);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsUntilResend <= 1) {
        timer.cancel();
        setState(() => _secondsUntilResend = 0);
      } else {
        setState(() => _secondsUntilResend -= 1);
      }
    });
  }

  String get _enteredCode => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < _codeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() => _errorText = null);
    if (_enteredCode.length == _codeLength) {
      _verify();
    }
  }

  Future<void> _verify() async {
    if (_enteredCode.length != _codeLength || _isVerifying) return;

    setState(() {
      _isVerifying = true;
      _errorText = null;
    });

    try {
      await AuthApi.verifyOtp(widget.email, _enteredCode);
      if (!mounted) return;
      await widget.onVerified(context);
    } on ApiException catch (e) {
      setState(() {
        _errorText = e.message;
        for (final c in _controllers) {
          c.clear();
        }
      });
      _focusNodes.first.requestFocus();
    } catch (_) {
      setState(() => _errorText = 'Could not reach the server. Is the backend running?');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    if (_secondsUntilResend > 0 || _isResending) return;

    setState(() => _isResending = true);
    try {
      await AuthApi.sendOtp(widget.email);
      _startResendCooldown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A new code has been sent.')),
        );
      }
    } on ApiException catch (e) {
      setState(() => _errorText = e.message);
    } catch (_) {
      setState(() => _errorText = 'Could not reach the server. Is the backend running?');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryGreen),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Icon(Icons.mark_email_read_outlined, size: 56, color: AppColors.primaryGreen),
              const SizedBox(height: 20),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  children: [
                    const TextSpan(text: 'We sent a 6-digit code to '),
                    TextSpan(text: widget.email, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_codeLength, (index) => _DigitBox(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      hasError: _errorText != null,
                      onChanged: (value) => _onDigitChanged(index, value),
                    )),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(_errorText!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.dangerText, fontSize: 13)),
              ],
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isVerifying ? null : _verify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: _isVerifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Text('Verify', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 20),
              Center(
                child: _secondsUntilResend > 0
                    ? Text(
                        'Resend code in ${_secondsUntilResend}s',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      )
                    : TextButton(
                        onPressed: _isResending ? null : _resend,
                        child: Text(
                          _isResending ? 'Sending...' : 'Resend code',
                          style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.w700),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DigitBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final ValueChanged<String> onChanged;

  const _DigitBox({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 56,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: hasError ? AppColors.dangerText : AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
          ),
        ),
      ),
    );
  }
}
