import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Outcome reported back from [ZiinaCheckoutScreen] once the hosted
/// checkout redirects to our `io.supabase.almamoura://payment-callback`
/// scheme, or `null` if the user closed the screen manually.
enum ZiinaCheckoutResult { success, cancel, failure }

/// Screen 8: hosts Ziina's payment page in a WebView and detects the
/// success/cancel/failure redirect configured in `ziina-create-payment`.
class ZiinaCheckoutScreen extends StatefulWidget {
  final String redirectUrl;
  final String paymentId;

  const ZiinaCheckoutScreen({
    super.key,
    required this.redirectUrl,
    required this.paymentId,
  });

  @override
  State<ZiinaCheckoutScreen> createState() => _ZiinaCheckoutScreenState();
}

class _ZiinaCheckoutScreenState extends State<ZiinaCheckoutScreen> {
  static const _callbackScheme = 'io.supabase.almamoura';

  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onNavigationRequest: _handleNavigation,
        ),
      )
      ..loadRequest(Uri.parse(widget.redirectUrl));
  }

  NavigationDecision _handleNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null ||
        uri.scheme != _callbackScheme ||
        uri.host != 'payment-callback' ||
        uri.queryParameters['payment_id'] != widget.paymentId) {
      return NavigationDecision.navigate;
    }

    final status = uri.queryParameters['status'];
    final result = switch (status) {
      'success' => ZiinaCheckoutResult.success,
      'cancel' => ZiinaCheckoutResult.cancel,
      _ => ZiinaCheckoutResult.failure,
    };
    Navigator.of(context).pop(result);
    return NavigationDecision.prevent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
