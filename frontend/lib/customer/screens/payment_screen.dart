import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/booking_model.dart';
import '../../core/services/api_exception.dart';
import '../../core/services/futsal_api.dart';

/// Opens eSewa's or Khalti's payment page, then has the server check with
/// the gateway. Returns the confirmed booking, or null if it wasn't paid
/// (the customer can try again from the Bookings tab while the slot is held).
Future<BookingModel?> payForBooking(BuildContext context, String bookingId, PaymentStart start) async {
  final messenger = ScaffoldMessenger.of(context);
  await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => PaymentScreen(start: start)));
  // However the page was left, ask the server: only eSewa/Khalti know for sure.
  try {
    return await FutsalApi.verifyPayment(bookingId);
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text('${e.message} Your slot is held for 15 minutes; tap "Pay now" in Bookings to try again.'),
    ));
    return null;
  }
}

/// The gateway's own page in a WebView. Closes itself when the gateway
/// sends the customer back to our return address.
class PaymentScreen extends StatefulWidget {
  final PaymentStart start;

  const PaymentScreen({super.key, required this.start});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _finished = false;

  String get _name => widget.start.gateway == 'khalti' ? 'Khalti' : 'eSewa';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
        onNavigationRequest: (request) {
          if (request.url.startsWith(widget.start.returnUrlPrefix)) {
            _finish();
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        // Some redirects skip onNavigationRequest; catch those too.
        onPageStarted: (url) {
          if (url.startsWith(widget.start.returnUrlPrefix)) _finish();
        },
      ));
    if (widget.start.gateway == 'esewa') {
      _controller.loadHtmlString(_esewaForm());
    } else {
      _controller.loadRequest(Uri.parse(widget.start.paymentUrl));
    }
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    Navigator.pop(context);
  }

  /// eSewa needs a form POST, so the page submits one straight away.
  String _esewaForm() {
    const escape = HtmlEscape();
    final inputs = widget.start.fields.entries
        .map((field) => '<input type="hidden" name="${escape.convert(field.key)}" value="${escape.convert(field.value)}">')
        .join();
    return '<html><body onload="document.forms[0].submit()" style="font-family:sans-serif;text-align:center;'
        'padding-top:40vh">Opening eSewa…<form method="POST" action="${escape.convert(widget.start.formUrl)}">'
        '$inputs</form></body></html>';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Pay with $_name', style: AppTextStyles.subheading),
        leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Close', onPressed: _finish),
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(value: _progress / 100, minHeight: 3),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
