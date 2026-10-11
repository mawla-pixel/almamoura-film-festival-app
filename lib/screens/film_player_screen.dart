import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/playback_service.dart';

class FilmPlayerScreen extends StatefulWidget {
  final String filmId;
  final String filmTitle;

  const FilmPlayerScreen({
    super.key,
    required this.filmId,
    required this.filmTitle,
  });

  @override
  State<FilmPlayerScreen> createState() => _FilmPlayerScreenState();
}

class _FilmPlayerScreenState extends State<FilmPlayerScreen> {
  WebViewController? _controller;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlayback();
  }

  Future<void> _loadPlayback() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _controller = null;
    });

    try {
      final session = await PlaybackService.createSession(widget.filmId);
      if (!mounted) return;

      final host = session.embedUrl.host;
      if (!_isAllowedPlayerHost(host)) {
        throw const FormatException('Playback host is not allowed.');
      }

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onWebResourceError: (error) {
              if (!mounted) return;
              setState(() {
                _errorMessage = error.description;
                _isLoading = false;
              });
            },
            onPageFinished: (_) {
              if (!mounted) return;
              setState(() => _isLoading = false);
            },
            onNavigationRequest: (request) {
              final uri = Uri.tryParse(request.url);
              return uri != null && _isAllowedPlayerHost(uri.host)
                  ? NavigationDecision.navigate
                  : NavigationDecision.prevent;
            },
          ),
        )
        ..loadRequest(session.embedUrl);

      setState(() {
        _controller = controller;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = PlaybackService.messageFor(error);
        _isLoading = false;
      });
    }
  }

  bool _isAllowedPlayerHost(String host) {
    return host == 'iframe.mediadelivery.net' ||
        host.endsWith('.mediadelivery.net');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.filmTitle),
      ),
      body: Center(
        child: _errorMessage != null
            ? _UnavailablePlayback(
                message: _errorMessage!,
                onRetry: _loadPlayback,
              )
            : _controller == null
            ? const CircularProgressIndicator(color: Colors.white)
            : Stack(
                fit: StackFit.expand,
                children: [
                  WebViewWidget(controller: _controller!),
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                ],
              ),
      ),
    );
  }
}

class _UnavailablePlayback extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _UnavailablePlayback({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_disabled, color: Colors.white70, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Trailer playback is unavailable',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}
