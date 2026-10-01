import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// In-app page that leaves the site's own colors alone.
///
/// Android's algorithmic darkening recolors light pages into the wrong hues.
/// [WebTone] turns that off for every WebView; this page also refuses to
/// inject CSS, so the document renders the way Chrome renders it.
class LegalPage extends StatefulWidget {
  const LegalPage({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  late final WebViewController _controller;
  var _loading = true;
  var _failed = false;
  var _allowPop = false;
  var _leaving = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _loading = true;
                _failed = false;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == false) return;
            if (mounted) {
              setState(() {
                _failed = true;
                _loading = false;
              });
            }
          },
          onHttpError: (error) {
            final uri = error.request?.uri;
            if (uri != null && uri.toString() != widget.url) return;
            final code = error.response?.statusCode ?? 0;
            if (code < 400) return;
            if (mounted) {
              setState(() {
                _failed = true;
                _loading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      platform
        ..setUseWideViewPort(true)
        ..enableZoom(true)
        ..setMediaPlaybackRequiresUserGesture(true)
        ..setVerticalScrollBarEnabled(true)
        ..setHorizontalScrollBarEnabled(false);
    }
  }

  Future<void> _leave() async {
    if (_allowPop || _leaving) return;
    _leaving = true;
    final back = await _controller.canGoBack();
    if (!mounted) return;
    if (back) {
      _leaving = false;
      await _controller.goBack();
      return;
    }
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    const bar = Color(0xFFFFFFFF);
    const fg = Color(0xFF202124);
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _leave();
      },
      child: Scaffold(
        backgroundColor: bar,
        appBar: AppBar(
          backgroundColor: bar,
          foregroundColor: fg,
          surfaceTintColor: bar,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: fg),
            onPressed: _leave,
          ),
          title: Text(widget.title, style: const TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 18)),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading && !_failed)
              const ColoredBox(
                color: bar,
                child: Center(child: CircularProgressIndicator(color: Color(0xFF1A73E8))),
              ),
            if (_failed)
              const ColoredBox(
                color: bar,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'This page could not be opened. Check the connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: fg, fontSize: 16),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
