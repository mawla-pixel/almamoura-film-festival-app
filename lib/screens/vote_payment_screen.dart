import 'package:flutter/material.dart';

import '../data/festival_options.dart';
import '../models/film.dart';
import '../models/vote_bundle.dart';
import '../services/payment_service.dart';
import '../services/supabase_service.dart';
import 'ziina_checkout_screen.dart';

/// Screen 7: Vote checkout screen where users pick a vote bundle and
/// continue to payment.
class VotePaymentScreen extends StatefulWidget {
  final Film film;

  const VotePaymentScreen({super.key, required this.film});

  @override
  State<VotePaymentScreen> createState() => _VotePaymentScreenState();
}

class _VotePaymentScreenState extends State<VotePaymentScreen> {
  String _selectedId = FestivalOptions.voteBundles.first.id;
  bool _isProcessing = false;

  VoteBundle get _selected =>
      FestivalOptions.voteBundles.firstWhere((b) => b.id == _selectedId);

  Future<void> _continueToPayment() async {
    if (!SupabaseService.isSignedInPermanent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in with an account before purchasing votes.'),
        ),
      );
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final intent = await PaymentService.createFilmVoteCheckout(
        filmId: widget.film.id,
        bundleId: _selected.id,
      );
      if (!mounted) return;

      final result = await Navigator.of(context).push<ZiinaCheckoutResult>(
        MaterialPageRoute(
          builder: (_) => ZiinaCheckoutScreen(
            redirectUrl: intent.redirectUrl,
            paymentId: intent.paymentId,
          ),
        ),
      );
      if (!mounted) return;

      if (result == ZiinaCheckoutResult.success) {
        final status = await PaymentService.waitForConfirmation(
          intent.paymentId,
        );
        if (!mounted) return;

        final message = switch (status) {
          VoteBundlePaymentStatus.completed =>
            'Payment received and confirmed.',
          VoteBundlePaymentStatus.failed => 'Payment failed. Please try again.',
          VoteBundlePaymentStatus.canceled => 'Payment cancelled.',
          VoteBundlePaymentStatus.pending =>
            'Payment is still processing. Please check again shortly.',
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        if (status == VoteBundlePaymentStatus.completed) {
          Navigator.of(context).pop(true);
        }
      } else if (result == ZiinaCheckoutResult.cancel) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payment cancelled.')));
      } else if (result == ZiinaCheckoutResult.failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment failed. Please try again.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(PaymentService.messageFor(error))));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPurchase = SupabaseService.isSignedInPermanent;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            const Icon(Icons.theater_comedy_outlined, size: 20),
            Text(
              'Film Festival',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Icon(
              Icons.star_rounded,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Make your vote count',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Voting for ${widget.film.title}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Support the films you love and help filmmakers get '
            'discovered. Choose a voting bundle to continue.',
            style: TextStyle(color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey.shade200,
                  child: const Icon(
                    Icons.confirmation_number_outlined,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voting is a paid feature',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Each vote supports the festival and participating '
                        'filmmakers.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.info_outline, color: Colors.grey),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Choose your votes',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              Text('One-time payment', style: TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 12),
          ...FestivalOptions.voteBundles.map(
            (bundle) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _BundleTile(
                bundle: bundle,
                selected: _selectedId == bundle.id,
                onTap: () => setState(() => _selectedId = bundle.id),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Selected bundle',
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text(_selected.label),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total today',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _selected.priceLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessing || !canPurchase
                  ? null
                  : _continueToPayment,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_outline, size: 18),
              label: Text(
                _isProcessing
                    ? 'Please wait...'
                    : canPurchase
                    ? 'Continue to secure payment'
                    : SupabaseService.isConfigured
                    ? 'Sign in to purchase votes'
                    : 'Payments temporarily unavailable',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!canPurchase)
            const Text(
              'Sign in with a permanent account to purchase votes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          if (!canPurchase) const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.verified_user_outlined, size: 16, color: Colors.grey),
              SizedBox(width: 6),
              Text(
                'Secure checkout powered by Ziina',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Votes are non-refundable and can only be used during '
            'Almamoura Film Festival 2026.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _BundleTile extends StatelessWidget {
  final VoteBundle bundle;
  final bool selected;
  final VoidCallback onTap;

  const _BundleTile({
    required this.bundle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? Colors.black : Colors.grey.shade300,
                width: selected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bundle.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        bundle.description,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  bundle.priceLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          if (bundle.isBestValue)
            Positioned(
              top: -10,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'BEST VALUE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
