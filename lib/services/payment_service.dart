import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

enum VoteBundlePaymentStatus { completed, failed, canceled, pending }

/// Result of starting a Ziina checkout: where to send the user next.
class ZiinaCheckoutIntent {
  final String paymentId;
  final String redirectUrl;

  const ZiinaCheckoutIntent({required this.paymentId, required this.redirectUrl});
}

/// Talks to the `ziina-create-payment` Supabase edge function, which keeps
/// the Ziina secret access token server-side and creates a hosted payment
/// intent for the selected vote bundle.
class PaymentService {
  PaymentService._();

  static Future<ZiinaCheckoutIntent> createFilmVoteCheckout({
    required String filmId,
    required String bundleId,
  }) async {
    if (!SupabaseService.isConfigured) {
      throw StateError('Payment is unavailable while the backend is disconnected.');
    }
    final response = await SupabaseService.client.functions.invoke(
      'ziina-create-film-vote-payment',
      body: {'filmId': filmId, 'bundleId': bundleId},
    );

    final data = response.data;
    if (data is! Map ||
        data['redirectUrl'] is! String ||
        data['paymentId'] is! String) {
      throw const FormatException('Invalid payment response.');
    }

    final redirectUrl = Uri.tryParse(data['redirectUrl'] as String);
    if (redirectUrl == null ||
        redirectUrl.scheme != 'https' ||
        redirectUrl.host.isEmpty) {
      throw const FormatException('Invalid payment redirect URL.');
    }

    return ZiinaCheckoutIntent(
      paymentId: data['paymentId'] as String,
      redirectUrl: redirectUrl.toString(),
    );
  }

  /// Waits for Ziina's signed webhook to confirm the payment in Supabase.
  /// The hosted checkout redirect alone is not proof that a payment completed.
  static Future<VoteBundlePaymentStatus> waitForConfirmation(
    String paymentId,
  ) async {
    if (!SupabaseService.isConfigured) {
      throw StateError('Payment is unavailable while the backend is disconnected.');
    }
    const attempts = 15;
    const delay = Duration(seconds: 2);

    for (var attempt = 0; attempt < attempts; attempt++) {
      final response = await SupabaseService.client
          .from('film_vote_payments')
          .select('status')
          .eq('id', paymentId)
          .maybeSingle();

      if (response == null || response['status'] is! String) {
        throw const FormatException('Payment record was not found.');
      }

      final status = switch (response['status']) {
        'completed' => VoteBundlePaymentStatus.completed,
        'failed' => VoteBundlePaymentStatus.failed,
        'canceled' => VoteBundlePaymentStatus.canceled,
        'pending' => VoteBundlePaymentStatus.pending,
        _ => throw const FormatException('Unknown payment status.'),
      };
      if (status != VoteBundlePaymentStatus.pending) return status;

      if (attempt < attempts - 1) {
        await Future<void>.delayed(delay);
      }
    }

    return VoteBundlePaymentStatus.pending;
  }

  static String messageFor(Object error) {
    if (error is FunctionException) {
      final message = error.details is Map ? error.details['error'] : null;
      if (message is String && message.isNotEmpty) return message;
      return error.reasonPhrase ?? 'Payment is not available right now.';
    }
    if (error is FormatException) return error.message;
    if (error is StateError) return error.message.toString();
    return 'Payment is not available right now. Please try again.';
  }
}
