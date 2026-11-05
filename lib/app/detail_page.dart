import 'package:flutter/material.dart';

// Content owns its scroll region; the footer stays reachable above the keyboard.
class DetailPage extends StatelessWidget {
  const DetailPage({
    required this.title,
    required this.content,
    this.actions = const [],
    super.key,
  });
  final Widget title, content;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: title),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Padding(padding: const EdgeInsets.all(20), child: content),
        ),
      ),
    ),
    persistentFooterButtons: actions.isEmpty ? null : actions,
  );
}

class FormSurface extends StatelessWidget {
  const FormSurface({
    required this.title,
    required this.content,
    required this.actions,
    this.asPage = false,
    super.key,
  });
  final Widget title, content;
  final List<Widget> actions;
  final bool asPage;
  @override
  Widget build(BuildContext context) => asPage
      ? DetailPage(title: title, content: content, actions: actions)
      : AlertDialog(title: title, content: content, actions: actions);
}
