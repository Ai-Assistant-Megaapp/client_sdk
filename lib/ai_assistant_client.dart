import 'dart:convert';

import 'package:client_sdk/MessageModel.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

class AiAssistantClient extends StatefulWidget {
  final String token;
  final Color accentColor;
  final Color primaryColor;
  final Widget? sendIcon;
  final String? initMessage;
  final String? placeholder;

  const AiAssistantClient(
      {super.key,
      required this.token,
      this.accentColor = Colors.blueAccent,
      this.primaryColor = Colors.black12,
      this.sendIcon,
      this.initMessage,
      this.placeholder});

  @override
  _AiAssistantClientState createState() {
    return _AiAssistantClientState();
  }

  static void logOut() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('cachedMessagesAiClientSDK');
    prefs.remove('cachedUUIDAiClientSDK');
  }
}

class _AiAssistantClientState extends State<AiAssistantClient> {
  final _uuidGenerator = const Uuid();
  final String _serverUrl = 'https://ai.airun.one/webhook/client_sdk';
  final TextEditingController _comment = TextEditingController();
  final ScrollController _controller = ScrollController();
  List<MessageModel> _messages = List.empty(growable: true);
  String _uuid = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    checkAndGenerateUUID();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 500), () {
      _controller.animateTo(
        _controller.position.maxScrollExtent,
        duration: const Duration(seconds: 1),
        curve: Curves.fastOutSlowIn,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _controller,
            padding: EdgeInsets.zero,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: <Widget>[
              ..._messages.map((e) => Container(
                    margin: EdgeInsets.only(
                        top: 8,
                        bottom: 8,
                        right: (e.sender == 'assistant' ? 100 : 16),
                        left: (e.sender == 'assistant' ? 16 : 100)),
                    alignment: e.sender == 'assistant' ? Alignment.topLeft : Alignment.topRight,
                    child: IntrinsicWidth(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                            color: e.sender == 'assistant' ? widget.primaryColor : widget.accentColor,
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          e.text ?? '',
                          style: TextStyle(color: e.sender == 'assistant' ? Colors.black : Colors.white),
                        ),
                      ),
                    ),
                  )),
              if (_isLoading)
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 8, right: 100, left: 16),
                  alignment: Alignment.topLeft,
                  child: IntrinsicWidth(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: widget.primaryColor, borderRadius: BorderRadius.circular(12)),
                      child: const Row(
                        children: [
                          SizedBox(width: 8),
                          SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey)),
                          SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                )
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4, right: 4),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(color: widget.primaryColor, borderRadius: BorderRadius.circular(12)),
          child: TextField(
              textInputAction: TextInputAction.send,
              onSubmitted: (value) async {
                if (_comment.text.isNotEmpty) {
                  await sendMessageToServer(_comment.text);
                }
              },
              autofocus: true,
              controller: _comment,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: InputBorder.none,
                  hintText: widget.placeholder ?? 'Сообщение',
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  suffixIcon: InkWell(
                    onTap: () async {
                      if (_comment.text.isNotEmpty) {
                        await sendMessageToServer(_comment.text);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: widget.sendIcon ?? Icon(Icons.send, color: widget.accentColor),
                    ),
                  ))),
        )
      ],
    );
  }

  Future<void> checkAndGenerateUUID() async {
    final cachedUUID = await loadUUIDFromCache();
    if (cachedUUID != null) {
      _uuid = cachedUUID;
    } else {
      final newUUID = _uuidGenerator.v4();
      _uuid = newUUID;
      await saveUUIDToCache(newUUID);
    }
    await getLastMessages();
  }

  Future<void> getLastMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getString('cachedMessagesAiClientSDK') ?? '';
    if (list.isNotEmpty) {
      try {
        final json = jsonDecode(list);
        _messages = (json as List).map((e) => MessageModel.fromJson(e)).toList();
        setState(() {});
        _scrollDown();
      } catch (e) {}
    } else if ((widget.initMessage ?? '').isNotEmpty) {
      await sendMessageToServer(widget.initMessage!);
    }
  }

  Future<void> addMessages(MessageModel messageModel) async {
    setState(() {
      _messages.add(messageModel);
      _comment.clear();
      _scrollDown();
    });
    final jsonList = _messages.map((message) => message.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cachedMessagesAiClientSDK', jsonString);
  }

  Future<void> saveUUIDToCache(String uuid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cachedUUIDAiClientSDK', uuid);
  }

  Future<String?> loadUUIDFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('cachedUUIDAiClientSDK');
  }

  Future<void> sendMessageToServer(String text) async {
    try {
      await addMessages(MessageModel(chatId: _uuid, sender: 'user', text: text));
      setState(() {
        _isLoading = true;
      });
      final response = await http
          .post(
            Uri.parse('$_serverUrl/${widget.token}'),
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode({'message': text, 'chat_id': _uuid}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final message = jsonDecode(response.body)['message'];
        await addMessages(MessageModel(chatId: _uuid, sender: 'assistant', text: message));
      } else {
        showError('Ошибка при отправке');
      }
    } catch (e) {
      showError('Ошибка при отправке $e');
    }
    setState(() {
      _isLoading = false;
    });
  }

  void showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: Colors.red,
      ),
    );
  }
}
