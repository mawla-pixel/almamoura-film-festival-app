import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/payment_service.dart';

class PaymentCallbackScreen extends StatefulWidget {
  final String paymentId;

  const PaymentCallbackScreen({super.key, required this.paymentId});

  @override
  State<PaymentCallbackScreen> createState() => _PaymentCallbackScreenState();
}

class _PaymentCallbackScreenState extends State<PaymentCallbackScreen> {
  VoteBundlePaymentStatus? _status;
  String? _error;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPayment());
  }

  Future<void> _checkPayment() async {
    setState(() {
      _isChecking = true;
      _error = null;
    });
    try {
      final status = await PaymentService.waitForConfirmation(widget.paymentId);
      if (mounted) setState(() => _status = status);
    } catch (error) {
      if (mounted) {
        setState(() => _error = PaymentService.messageFor(error));
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _returnToApp() async {
    final home = Uri.base.replace(query: '', fragment: '');
    final opened = await launchUrl(home, webOnlyWindowName: '_self');
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not return to the festival app.')),
      );
    }
  }

  String get _statusMessage {
    if (_error != null) return _error!;
    return switch (_status) {
      VoteBundlePaymentStatus.completed => 'Payment received and confirmed.',
      VoteBundlePaymentStatus.failed => 'Payment failed. Please try again.',
      VoteBundlePaymentStatus.canceled => 'Payment was cancelled.',
      VoteBundlePaymentStatus.pending =>
        'Payment is still processing. Check again shortly.',
      null => 'Checking payment status…',
    };
  }

  @override
  Widget build(BuildContext context) {
    final isPending =
        _error != null || _status == VoteBundlePaymentStatus.pending;
    return Scaffold(
      appBar: AppBar(title: const Text('Payment status')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isChecking)
                  const CircularProgressIndicator()
                else
                  Icon(
                    _status == VoteBundlePaymentStatus.completed
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    size: 56,
                    color: _status == VoteBundlePaymentStatus.completed
                        ? Colors.green
                        : null,
                  ),
                const SizedBox(height: 20),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 20),
                if (isPending)
                  OutlinedButton(
                    onPressed: _isChecking ? null : _checkPayment,
                    child: const Text('Check again'),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _returnToApp,
                  child: const Text('Return to festival'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
