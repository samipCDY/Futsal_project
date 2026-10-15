import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [uri] in the phone's dialer/email app. If there isn't one, copies
/// [value] instead so the user can still use it.
Future<void> openOrCopy(BuildContext context, Uri uri, String value) async {
  final opened = await launchUrl(uri).catchError((_) => false);
  if (opened || !context.mounted) return;
  await Clipboard.setData(ClipboardData(text: value));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied $value')));
  }
}

Future<void> callNumber(BuildContext context, String phone) =>
    openOrCopy(context, Uri(scheme: 'tel', path: phone), phone);
