import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_message.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/chat_service.dart';
import '../services/chat_store.dart';
import '../services/chat_prefs.dart';
import '../services/settings_service.dart';

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

  static const String _welcomeText =
      'يسعد أوقاتك أبو جاسر يالغالي 🌅\n'
      'سكرتيرك جاسر في خدمتك.\n'
      'مواعيدك وأدويتك ومهامك محفوظة عندي، وأنبّهك بها في وقتها — وأنت عِش يومك وبالك مرتاح.\n'
      'أمرني إيش أخدمك فيه؟';

  @override
  void initState() {
    super.initState();
    _loadHistory();
    ChatPrefs.clearSignal.addListener(_onClearRequested);
  }

  void _onClearRequested() {
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..add(ChatMessage(text: _welcomeText, isMe: false));
    });
    ChatStore.clear();
    _persist();
  }

  Future<void> _loadHistory() async {
    final saved = await ChatStore.load();
    if (saved.isNotEmpty && mounted) {
      setState(() {
        _messages
          ..clear()
          ..addAll(saved);
      });
      _scrollToBottom();
    } else {
      _persist(); // احفظ رسالة الترحيب أول مرة
    }
    _maybeShowMorning();
  }

  /// يعرض رسالة الصباح داخل المحادثة (مرّة واحدة يومياً بعد وقتها) —
  /// يحلّ مشكلة "الإشعار يجي والرسالة مو موجودة في التطبيق".
  Future<void> _maybeShowMorning() async {
    try {
      const storage = FlutterSecureStorage();
      final now = DateTime.now();
      final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      if (await storage.read(key: 'jasir_morning_shown') == today) return;
      final s = await SettingsService().getSettings();
      final enabled = s['morning_enabled'] == 1 || s['morning_enabled'] == true;
      if (!enabled) return;
      final t = (s['morning_time'] as String?)?.isNotEmpty == true ? s['morning_time'] as String : '07:00';
      final p = t.split(':');
      final due = DateTime(now.year, now.month, now.day, int.tryParse(p[0]) ?? 7, int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
      if (now.isBefore(due)) return; // لسّا ما حان وقتها اليوم
      final txt = await SettingsService().previewMorning();
      if (txt.trim().isEmpty || !mounted) return;
      setState(() => _messages.add(ChatMessage(text: txt, isMe: false)));
      _persist();
      _scrollToBottom();
      await storage.write(key: 'jasir_morning_shown', value: today);
    } catch (_) {}
  }

  void _persist() => ChatStore.save(_messages);

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
    _persist();
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
    _persist();
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
    _persist();
  }

  @override
  void dispose() {
    ChatPrefs.clearSignal.removeListener(_onClearRequested);
    _controller.dispose();
    _scrollController.dispose();
    _recSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Widget _bubble(ChatMessage m) {
    final isMe = m.isMe;
    final cs = Theme.of(context).colorScheme;
    // وفق الهوية: فقاعة المستخدم بلون جاسر الأساسي، وفقاعة جاسر سطح محايد بحدّ.
    final bg = isMe ? cs.primary : cs.surface;
    final fg = isMe ? cs.onPrimary : cs.onSurface;
    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: isMe ? null : Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (m.hasMedia) _mediaContent(m),
          if (m.text.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: m.hasMedia ? 8 : 0),
              child: Text(m.text, textAlign: TextAlign.right, style: TextStyle(color: fg, fontSize: 15)),
            ),
        ],
      ),
    );
    if (isMe) return Align(alignment: Alignment.centerLeft, child: bubble);
    // رد جاسر: نجمة تميّزه بأنه من المساعد
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6, right: 4),
            child: CircleAvatar(
              radius: 13,
              backgroundColor: cs.primary,
              child: Icon(Icons.auto_awesome, size: 14, color: cs.onPrimary),
            ),
          ),
          Flexible(child: bubble),
        ],
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
          child: ValueListenableBuilder<String>(
            valueListenable: ChatPrefs.background,
            builder: (context, bgId, _) => Container(
              decoration: ChatPrefs.decoration(bgId),
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
                    // لون النص يتبع الثيم حتى يظهر في المود الداكن
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالتك لجاسر...',
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline)),
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
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
