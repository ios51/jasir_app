import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';

/// شاشة محادثة مباشرة مع جاسر — نفس تجربة واتساب بالضبط، بس داخل التطبيق.
/// تدعم: نص، تسجيل صوت (المايك)، ورفع صور/PDF ليقرأها جاسر ويحفظ بياناتها.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _service = ChatService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _recSub;
  final BytesBuilder _pcmBuffer = BytesBuilder();

  final List<ChatMessage> _messages = [
    ChatMessage(
      text: 'أهلاً بك! أنا جاسر 🤖\nاكتب لي أي شي تحتاجه، أو أرسل رسالة صوتية، أو صورة/PDF لوثيقة عشان أقرأها وأحفظ بياناتها.',
      isMe: false,
    ),
  ];
  bool _sending = false;
  bool _recording = false;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── إرسال نص ──────────────────────────────────────────────────────
  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add(ChatMessage(text: text, isMe: true));
      _sending = true;
    });
    _controller.clear();
    _scrollToBottom();
    try {
      final replies = await _service.sendMessage(text);
      _appendReplies(replies);
    } catch (e) {
      _appendError('تعذر إرسال الرسالة، تحقق من الاتصال وحاول مرة ثانية');
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  // ── تسجيل صوتي عبر المايك ─────────────────────────────────────────
  Future<void> _toggleRecording() async {
    if (_recording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('التطبيق يحتاج إذن الميكروفون عشان يسجل صوتك')));
        }
        return;
      }
      _pcmBuffer.clear();
      final stream = await _recorder.startStream(
        const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1),
      );
      _recSub = stream.listen((chunk) => _pcmBuffer.add(chunk));
      setState(() => _recording = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر بدء التسجيل')));
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder.stop();
    } catch (_) {}
    await _recSub?.cancel();
    _recSub = null;
    if (mounted) setState(() => _recording = false);

    final pcm = _pcmBuffer.takeBytes();
    if (pcm.isEmpty) return;
    final wav = _pcmToWav(pcm, sampleRate: 16000, numChannels: 1, bitsPerSample: 16);
    await _sendMediaBytes(wav, 'audio/wav', label: '🎤 رسالة صوتية');
  }

  /// يبني رأس WAV قياسي (44 بايت) فوق بيانات PCM16 الخام — بدون أي مكتبات
  /// خارجية أو ملفات مؤقتة، يشتغل بنفس الطريقة على الويب والجوال.
  Uint8List _pcmToWav(Uint8List pcm, {required int sampleRate, required int numChannels, required int bitsPerSample}) {
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final blockAlign = numChannels * bitsPerSample ~/ 8;
    final dataLength = pcm.length;

    final header = BytesBuilder();
    void wStr(String s) => header.add(ascii.encode(s));
    void wU32(int v) => header.add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);
    void wU16(int v) => header.add([v & 0xff, (v >> 8) & 0xff]);

    wStr('RIFF');
    wU32(36 + dataLength);
    wStr('WAVE');
    wStr('fmt ');
    wU32(16);
    wU16(1); // PCM
    wU16(numChannels);
    wU32(sampleRate);
    wU32(byteRate);
    wU16(blockAlign);
    wU16(bitsPerSample);
    wStr('data');
    wU32(dataLength);

    final out = BytesBuilder();
    out.add(header.toBytes());
    out.add(pcm);
    return out.toBytes();
  }

  // ── رفع صورة أو PDF ───────────────────────────────────────────────
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذرت قراءة الملف')));
        return;
      }
      final ext = (file.extension ?? '').toLowerCase();
      String mimetype;
      String label;
      if (ext == 'pdf') {
        mimetype = 'application/pdf';
        label = '📄 ${file.name}';
      } else {
        mimetype = ext == 'png' ? 'image/png' : 'image/jpeg';
        label = '🖼 ${file.name}';
      }
      await _sendMediaBytes(bytes, mimetype, label: label);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر اختيار الملف')));
    }
  }

  Future<void> _sendMediaBytes(Uint8List bytes, String mimetype, {required String label}) async {
    debugPrint('[chat] sending media: $mimetype, ${bytes.length} bytes');
    setState(() {
      _messages.add(ChatMessage(text: label, isMe: true));
      _sending = true;
    });
    _scrollToBottom();
    try {
      final replies = await _service.sendMedia(bytes: bytes, mimetype: mimetype);
      debugPrint('[chat] media replies: $replies');
      _appendReplies(replies);
    } catch (e) {
      debugPrint('[chat] media error: $e');
      _appendError('تعذر إرسال الملف، تحقق من الاتصال وحاول مرة ثانية');
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  void _appendReplies(List<ChatReply> replies) {
    if (!mounted) return;
    setState(() {
      if (replies.isEmpty) {
        _messages.add(ChatMessage(text: '...', isMe: false));
      } else {
        for (final r in replies) {
          if (r.isMedia) {
            _messages.add(ChatMessage(
              text: r.caption ?? '',
              isMe: false,
              mediaBytes: r.bytes,
              mediaMimetype: r.mimetype,
              mediaFilename: r.filename,
            ));
          } else {
            _messages.add(ChatMessage(text: r.text ?? '', isMe: false));
          }
        }
      }
    });
  }

  Future<void> _openMedia(ChatMessage m) async {
    if (!m.hasMedia) return;
    final b64 = base64Encode(m.mediaBytes!);
    final uri = Uri.parse('data:${m.mediaMimetype};base64,$b64');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح الملف')));
      }
    }
  }

  void _appendError(String text) {
    if (!mounted) return;
    setState(() => _messages.add(ChatMessage(text: text, isMe: false)));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _recSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Widget _bubble(ChatMessage m) {
    final isMe = m.isMe;
    return Align(
      alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? Colors.teal.shade50 : Colors.teal,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (m.hasMedia) _mediaContent(m),
            if (m.text.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: m.hasMedia ? 8 : 0),
                child: Text(
                  m.text,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: isMe ? Colors.black87 : Colors.white, fontSize: 15),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _mediaContent(ChatMessage m) {
    if (m.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: GestureDetector(
          onTap: () => _openMedia(m),
          child: Image.memory(m.mediaBytes!, fit: BoxFit.cover),
        ),
      );
    }
    // PDF أو أي ملف آخر → بطاقة مع زر فتح/تنزيل
    return InkWell(
      onTap: () => _openMedia(m),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                m.mediaFilename ?? 'فتح الملف',
                style: const TextStyle(color: Colors.white, decoration: TextDecoration.underline),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_recording)
          Container(
            width: double.infinity,
            color: Colors.red.shade50,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
                SizedBox(width: 6),
                Text('جاري التسجيل... اضغط زر المايك مرة ثانية للإيقاف والإرسال', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: _messages.length + (_sending ? 1 : 0),
            itemBuilder: (context, i) {
              if (i >= _messages.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                );
              }
              return _bubble(_messages[i]);
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: _sending ? null : _pickFile,
                  icon: const Icon(Icons.attach_file),
                  tooltip: 'إرفاق صورة أو PDF',
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textAlign: TextAlign.right,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالتك لجاسر...',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  onPressed: _sending ? null : _toggleRecording,
                  icon: Icon(_recording ? Icons.stop : Icons.mic),
                  style: IconButton.styleFrom(
                    backgroundColor: _recording ? Colors.red : Colors.grey.shade300,
                    foregroundColor: _recording ? Colors.white : Colors.black87,
                  ),
                  tooltip: _recording ? 'إيقاف التسجيل وإرسال' : 'تسجيل صوتي',
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send),
                  style: IconButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
