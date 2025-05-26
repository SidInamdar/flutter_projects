import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; // Import file_picker

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doc Q&A with Gemini',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ChatScreen(),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUserMessage;
  final bool isLoading; // To show a loading indicator for AI responses

  ChatMessage({required this.text, required this.isUserMessage, this.isLoading = false});
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  PlatformFile? _uploadedFile; // To store the uploaded file

  void _handleSubmitted(String text) {
    _textController.clear();
    if (text.isEmpty) return;

    setState(() {
      _messages.insert(0, ChatMessage(text: text, isUserMessage: true));
      // Simulate AI thinking and then respond (replace with actual API call later)
      _messages.insert(0, ChatMessage(text: '', isUserMessage: false, isLoading: true));
    });

    // TODO: Call Gemini API here
    // For now, simulate a delay and a dummy response
    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        _messages.removeAt(0); // Remove loading indicator
        _messages.insert(0, ChatMessage(text: "This is a placeholder response for: '$text'", isUserMessage: false));
      });
    });
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'md', 'pdf'], // Specify allowed extensions
      );

      if (result != null) {
        setState(() {
          _uploadedFile = result.files.first;
          _messages.insert(0, ChatMessage(text: "File selected: ${_uploadedFile!.name}", isUserMessage: false));
        });
        // TODO: Upload file to Firebase Storage
      } else {
        // User canceled the picker
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No file selected.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  Widget _buildTextComposer() {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: <Widget>[
            IconButton(
              icon: Icon(Icons.upload_file),
              onPressed: _pickFile, // Call pick file method
            ),
            Flexible(
              child: TextField(
                controller: _textController,
                onSubmitted: _handleSubmitted,
                decoration: InputDecoration.collapsed(hintText: 'Ask a question about the document...'),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: IconButton(
                icon: Icon(Icons.send),
                onPressed: () => _handleSubmitted(_textController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Document Q&A with Gemini'),
        actions: [
          if (_uploadedFile != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Chip(
                label: Text(_uploadedFile!.name),
                onDeleted: () {
                  setState(() {
                    _uploadedFile = null;
                    _messages.insert(0, ChatMessage(text: "File removed.", isUserMessage: false));
                  });
                },
              ),
            )
        ],
      ),
      body: Column(
        children: <Widget>[
          Flexible(
            child: ListView.builder(
              padding: EdgeInsets.all(8.0),
              reverse: true,
              itemBuilder: (_, int index) {
                final message = _messages[index];
                if (message.isLoading) {
                  return _buildLoadingIndicator();
                }
                return _buildMessage(message);
              },
              itemCount: _messages.length,
            ),
          ),
          Divider(height: 1.0),
          Container(
            decoration: BoxDecoration(color: Theme.of(context).cardColor),
            child: _buildTextComposer(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: message.isUserMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: <Widget>[
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: message.isUserMessage ? Colors.blue[100] : Colors.grey[200],
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: Text(message.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: CircularProgressIndicator(strokeWidth: 2.0,),
            ),
          ),
        ],
      ),
    );
  }
}