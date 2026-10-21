import 'dart:async';
import 'package:flutter/material.dart';
import '../services/match_chat_service.dart';

class MatchChat extends StatefulWidget {
  const MatchChat(
      {super.key,
      required this.room,
      required this.uid,
      required this.names,
      this.finished = false,
      this.serviceFactory = MatchChatService.new});
  final String room, uid;
  final Map<String, String> names;
  final bool finished;
  final MatchChatService Function(String, String) serviceFactory;
  @override
  State<MatchChat> createState() => _MatchChatState();
}

class _MatchChatState extends State<MatchChat> {
  late final MatchChatService _service;
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <String, ChatMessage>{};
  Timer? _timer, _cleanupTimer;
  bool _cleaning = false;
  String? _error;
  bool _sending = false, _polling = false, _expanded = false;
  @override
  void initState() {
    super.initState();
    _service = widget.serviceFactory(widget.room, widget.uid);
    if (!widget.finished) {
      _cleanupTimer = Timer.periodic(
          const Duration(seconds: 30), (_) => unawaited(_cleanup()));
    }
    unawaited(_cleanup(finished: widget.finished));
  }

  @override
  void didUpdateWidget(MatchChat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.finished && !oldWidget.finished) {
      _timer?.cancel();
      _cleanupTimer?.cancel();
      _messages.clear();
      unawaited(_cleanup(finished: true));
    }
  }

  Future<void> _cleanup({bool finished = false}) async {
    if (mounted) {
      setState(() => _messages.removeWhere(
          (_, message) => !message.expiresAt.isAfter(DateTime.now())));
    }
    if (_cleaning && !finished) return;
    _cleaning = true;
    try {
      await _service.cleanup(finished: finished);
    } catch (_) {
      // The persisted cleanup IDs are retried on the next connected attempt.
    } finally {
      _cleaning = false;
    }
  }

  Future<void> _poll() async {
    if (_polling || !_expanded || widget.finished) return;
    _polling = true;
    try {
      final messages = await _service.receive();
      if (!mounted || widget.finished) return;
      final follow = !_scroll.hasClients || _scroll.position.extentAfter < 40;
      setState(() {
        _error = null;
        _messages.removeWhere(
            (_, message) => message.expiresAt.isBefore(DateTime.now()));
        for (final message in messages) {
          _messages[message.id] = message;
        }
        while (_messages.length > 100) {
          _messages.remove(_messages.keys.first);
        }
      });
      if (follow) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Chat unavailable. Retrying…');
    } finally {
      _polling = false;
    }
  }

  Future<void> _send() async {
    if (_sending || _text.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await _service.send(_text.text);
      if (!mounted) return;
      _text.clear();
      await _poll();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Message could not send. Tap Send to retry.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cleanupTimer?.cancel();
    _service.dispose();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.finished) return const SizedBox.shrink();
    final messages = _messages.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return ExpansionTile(
        onExpansionChanged: (expanded) {
          _expanded = expanded;
          _timer?.cancel();
          if (expanded) {
            _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
            unawaited(_poll());
          }
        },
        title: const Text('Game chat'),
        subtitle: const Text('Temporary messages · no saved history'),
        children: [
          SizedBox(
              height: 180,
              child: ListView(controller: _scroll, children: [
                for (final message in messages)
                  Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: Text(
                          '${widget.names[message.sender] ?? "Player"}: ${message.text}'))
              ])),
          if (_error != null) Text(_error!),
          Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                Expanded(
                    child: TextField(
                        controller: _text,
                        maxLength: 500,
                        decoration: const InputDecoration(labelText: 'Message'),
                        onSubmitted: (_) => _send())),
                IconButton(
                    tooltip: 'Send',
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send))
              ])),
        ]);
  }
}
