import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../widgets.dart';

class LegalPage extends StatefulWidget {
  const LegalPage({super.key, required this.title, required this.url, required this.light});

  final String title;
  final String url;
  final bool light;

  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  late final WebViewController _controller;
  var _failed = false;
  var _allowPop = false;
  var _leaving = false;

  static const _lightCss = '''
(function() {
  var css = 'html,body{background:#ffffff!important;color:#1a1a1a!important;} body *{color:#1a1a1a!important;background-color:transparent!important;border-color:#d5d5d5!important;} a,a *{color:#3d2a86!important;}';
  var node = document.getElementById('horizon-light');
  if (!node) {
    node = document.createElement('style');
    node.id = 'horizon-light';
    (document.head || document.documentElement).appendChild(node);
  }
  node.textContent = css;
  document.documentElement.style.background = '#ffffff';
  if (document.body) document.body.style.background = '#ffffff';
})();
''';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.light ? const Color(0xFFFFFFFF) : ink)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (widget.light) _controller.runJavaScript(_lightCss);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == false) return;
            if (mounted) setState(() => _failed = true);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
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
    final light = widget.light;
    final bar = light ? Colors.white : ink;
    final fg = light ? const Color(0xFF1A1A1A) : cream;
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
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: fg),
            onPressed: _leave,
          ),
          title: Text(widget.title, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_failed)
              ColoredBox(
                color: bar,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      light ? 'The privacy policy could not be opened.' : 'Support could not be opened.',
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
