import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_message.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_client.dart';
import '../services/chat_service.dart';
import '../services/chat_store.dart';
import '../services/chat_prefs.dart';
import '../services/settings_service.dart';
import '../services/module_service.dart';
import '../services/notification_service.dart';
import '../data/worship_content.dart';

/// شاشة محادثة مباشرة مع جاسر — نفس تجربة واتساب بالضبط، بس داخل التطبيق.
/// تدعم: نص، تسجيل صوت (المايك)، ورفع صور/PDF ليقرأها جاسر ويحفظ بياناتها.
class ChatScreen extends StatefulWidget {
  /// عند فتحها من إشعار الصباح: اعرض رسالة الصباح فوراً (تجاوز حارس مرة/يوم).
  final bool forceMorning;

  /// عند فتحها من إشعار دواء: جاسر يسأل عن الجرعة داخل المحادثة.
  final int? pendingMedId;
  final String? pendingMedName;

  /// عند فتحها من إشعار «فائدة اليوم»: تُعرض الفائدة داخل المحادثة.
  final bool showFaidah;

  const ChatScreen({super.key, this.forceMorning = false, this.pendingMedId, this.pendingMedName, this.showFaidah = false});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
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

  String _nick = '';

  // ترحيب يستخدم اللقب الذي اختاره المستخدم (بدل "أبو جاسر" الثابت)
  String get _welcomeText =>
      'يسعد أوقاتك${_nick.isNotEmpty ? ' يا $_nick' : ' يالغالي'} 🌅\n'
      'سكرتيرك جاسر في خدمتك.\n'
      'مواعيدك وأدويتك ومهامك محفوظة عندي، وأنبّهك بها في وقتها — وأنت عِش يومك وبالك مرتاح.\n'
      'أمرني إيش أخدمك فيه؟';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadHistory();
    ChatPrefs.clearSignal.addListener(_onClearRequested);
  }

  /// إصلاح: رسالة الصباح كانت تنضاف فقط عند إنشاء الشاشة من جديد —
  /// فلو بقي التطبيق فاتحاً بالخلفية من أمس ورجع له المستخدم بعد الساعة
  /// المحددة (أو كان الجوال طافياً وقتها وضاع الإشعار)، ما كانت تظهر.
  /// الآن: كل ما رجع التطبيق للواجهة نعيد الفحص — الحارس اليومي
  /// (jasir_morning_shown) يمنع التكرار.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeShowMorning();
      _pullInbox(); // تقارير وصلت والتطبيق بالخلفية → اعرضها فور الرجوع
      _pullPendingMed(); // جرعة حان وقتها والتطبيق بالخلفية → اعرض تأكيدها
    }
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
    // اقرأ اللقب أولاً حتى يظهر الترحيب باسم المستخدم
    try {
      final s = await SettingsService().getSettings();
      _nick = ((s['nickname'] as String?) ?? '').trim();
    } catch (_) {}
    final saved = await ChatStore.load();
    if (saved.isNotEmpty && mounted) {
      setState(() {
        _messages
          ..clear()
          ..addAll(saved);
      });
    } else {
      // أول مرة: اعرض ترحيباً باسم المستخدم (اللقب) بدل الرسالة العامة
      if (mounted && _nick.isNotEmpty) {
        setState(() {
          _messages
            ..clear()
            ..add(ChatMessage(text: _welcomeText, isMe: false));
        });
      }
      _persist(); // احفظ رسالة الترحيب أول مرة
    }
    // مهم: نعرض سؤال الدواء فوراً قبل نداءات الشبكة — كان مؤجّلاً خلف
    // await _pullInbox() فيدخل المستخدم ويلقى المحادثة «بدون رسالة» حتى
    // ينتهي طلب الوارد (أو يفشل بعد مهلة). الآن يظهر السؤال حالاً.
    _maybeAskMedConfirm();
    _maybeShowFaidah();
    _jumpToEnd();
    await _maybeShowMorning();
    await _pullInbox();
    await _pullPendingMed(); // جرعة مستحقّة غير مؤكّدة (مستقل عن ضغط الإشعار)
  }

  bool _faidahShown = false;
  void _maybeShowFaidah() {
    if (!widget.showFaidah || _faidahShown || !mounted) return;
    _faidahShown = true;
    final idx = DateTime.now().difference(DateTime(2020, 1, 1)).inDays % dailyFawaid.length;
    final f = dailyFawaid[idx];
    setState(() => _messages.add(ChatMessage(
          text: '💡 فائدة اليوم — ${f.kind}\n\n${f.text}\n\n${f.explanation}\n\nالمصدر: ${f.source}',
          isMe: false,
        )));
    _persist();
    _scrollToBottom();
  }

  /// يسحب وارد السيرفر (تقرير الأمن، التحليلات...) ويعرضه كرسائل جاسر
  /// داخل المحادثة — تبقى في السجل — ثم يعلّمها مقروءة.
  Future<void> _pullInbox() async {
    try {
      final res = await ApiClient.instance.dio.get('/api/v1/inbox/unseen');
      final items = (res.data is List) ? res.data as List : [];
      if (items.isEmpty || !mounted) return;
      final ids = <int>[];
      setState(() {
        for (final it in items) {
          final m = Map<String, dynamic>.from(it as Map);
          final title = (m['title'] ?? '').toString();
          final body = (m['body'] ?? '').toString();
          if (body.isEmpty && title.isEmpty) continue;
          _messages.add(ChatMessage(
            text: title.isNotEmpty ? '$title\n\n$body' : body,
            isMe: false,
          ));
          final id = int.tryParse((m['id'] ?? '').toString());
          if (id != null) ids.add(id);
        }
      });
      _persist();
      _scrollToBottom();
      if (ids.isNotEmpty) {
        await ApiClient.instance.dio.post('/api/v1/inbox/seen', data: {'ids': ids});
      }
    } catch (_) {/* بدون شبكة/سيرفر — يُعاد بالمحاولة الجاية */}
  }

  // ── تأكيد الدواء داخل المحادثة (فُتحت من إشعار دواء) ──────────────
  int? _medPromptId;
  String _medPromptName = '';
  bool _medBusy = false;

  bool _medAsked = false;
  void _maybeAskMedConfirm() {
    final id = widget.pendingMedId;
    if (id == null || id <= 0 || !mounted || _medAsked) return;
    _showMedPrompt(id, (widget.pendingMedName ?? '').isNotEmpty ? widget.pendingMedName! : 'دوائك');
  }

  void _showMedPrompt(int id, String name) {
    if (_medAsked || !mounted) return;
    _medAsked = true; // حارس: لا يتكرر السؤال لو استُدعي مرتين
    setState(() {
      _medPromptId = id;
      _medPromptName = name;
      _messages.add(ChatMessage(text: 'حان وقت دواء *$name* 💊\nأخذته؟', isMe: false));
    });
    _persist();
    _scrollToBottom();
  }

  /// الحل الجذري لعطل «الدواء ما يظهر بالمحادثة»: بدل الاعتماد على توجيه
  /// ضغط الإشعار (يفشل على iOS أحياناً فيبقى على الرئيسية)، نسحب من السيرفر
  /// أي جرعة مستحقّة غير مؤكّدة ونعرض تأكيدها تلقائياً أول ما تُفتح المحادثة.
  Future<void> _pullPendingMed() async {
    if (_medAsked) return; // إشعار الدواء عُرض فعلاً (من الضغط)
    try {
      final res = await ApiClient.instance.dio.get('/api/v1/meds/pending-confirm');
      final list = (res.data is List) ? res.data as List : [];
      if (list.isEmpty || !mounted || _medAsked) return;
      final m = Map<String, dynamic>.from(list.first as Map);
      final id = int.tryParse((m['medId'] ?? '').toString()) ?? 0;
      final name = (m['name'] ?? 'دوائك').toString();
      if (id > 0) _showMedPrompt(id, name);
    } catch (_) {/* بلا شبكة — يُعاد بالفتح القادم */}
  }

  Future<void> _confirmMedTaken() async {
    final id = _medPromptId;
    if (id == null || _medBusy) return;
    setState(() {
      _medBusy = true;
      _messages.add(ChatMessage(text: 'نعم، أخذته ✅', isMe: true));
    });
    _persist();
    _scrollToBottom();
    try {
      await ModuleService('/api/v1/meds').action(id, 'taken');
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(text: 'تمام، سجّلت إنك أخذت *$_medPromptName* ✅\nصحّة وعافية 🌿', isMe: false));
        _medPromptId = null;
        _medBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(text: 'تعذّر تسجيل الجرعة — تحقق من الاتصال وجرّب مرة ثانية 🙏', isMe: false));
        _medBusy = false;
      });
    }
    _persist();
    _scrollToBottom();
  }

  Future<void> _snoozeMed() async {
    final id = _medPromptId;
    if (id == null || _medBusy) return;
    setState(() {
      _medBusy = true;
      _messages.add(ChatMessage(text: 'أعطني ١٠ دقائق ⏰', isMe: true));
    });
    try {
      await NotificationService.scheduleAt(
        50000 + id,
        '💊 تذكير دواء',
        '$_medPromptName — تكرّم أكّد إنك أخذته',
        DateTime.now().add(const Duration(minutes: 10)),
        payload: 'med|$id|$_medPromptName',
      );
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(text: 'طيب، بذكّرك بعد ١٠ دقائق ⏰\nلا تنسى دواء *$_medPromptName*', isMe: false));
      _medPromptId = null;
      _medBusy = false;
    });
    _persist();
    _scrollToBottom();
  }

  /// يقفز لآخر المحادثة بعد اكتمال البناء (عدّة محاولات لضمان النزول).
  void _jumpToEnd() {
    for (final ms in [80, 300, 650]) {
      Future.delayed(Duration(milliseconds: ms), () {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  /// يعرض رسالة الصباح داخل المحادثة (مرّة واحدة يومياً بعد وقتها) —
  /// يحلّ مشكلة "الإشعار يجي والرسالة مو موجودة في التطبيق".
  Future<void> _maybeShowMorning() async {
    try {
      final force = widget.forceMorning; // فُتحت من إشعار الصباح → اعرض فوراً
      const storage = FlutterSecureStorage();
      final now = DateTime.now();
      final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final alreadyShown = await storage.read(key: 'jasir_morning_shown') == today;
      if (!force && alreadyShown) return;
      // فُتحت من الإشعار لكن الرسالة معروضة اليوم فعلاً → لا نكرّرها
      // (كان الضغط الثاني على الإشعار يضيف نسخة ثانية ويحفظها)، نكتفي
      // بالنزول لآخر المحادثة حيث الرسالة.
      if (force && alreadyShown) {
        _scrollToBottom();
        return;
      }
      final s = await SettingsService().getSettings();
      final enabled = s['morning_enabled'] == 1 || s['morning_enabled'] == true;
      if (!force && !enabled) return;
      final t = (s['morning_time'] as String?)?.isNotEmpty == true ? s['morning_time'] as String : '07:00';
      final p = t.split(':');
      final due = DateTime(now.year, now.month, now.day, int.tryParse(p[0]) ?? 7, int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
      if (!force && now.isBefore(due)) return; // لسّا ما حان وقتها اليوم
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
  /// زر المرفق يعرض خيارين: الصور (معرض الجهاز مباشرة) أو الملفات (PDF).
  /// كان يفتح «الملفات» فقط — والمستخدم غالباً صوره في تطبيق الصور.
  Future<void> _pickAttachment() async {
    FocusManager.instance.primaryFocus?.unfocus(); // أنزل الكيبورد قبل فتح المنتقي
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: Theme.of(ctx).colorScheme.primary),
              title: const Text('الصور', textAlign: TextAlign.right),
              subtitle: const Text('من معرض صور الجهاز', textAlign: TextAlign.right),
              onTap: () => Navigator.pop(ctx, 'photos'),
            ),
            ListTile(
              leading: Icon(Icons.description_outlined, color: Theme.of(ctx).colorScheme.primary),
              title: const Text('ملف PDF', textAlign: TextAlign.right),
              subtitle: const Text('من تطبيق الملفات', textAlign: TextAlign.right),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'photos') {
      await _pickFromGallery();
    } else if (choice == 'file') {
      await _pickPdf();
    }
  }

  /// معرض الصور: FileType.image يفتح منتقي الصور الأصلي (PHPicker على iOS —
  /// بلا إذن مكتبة الصور لأنه يعمل خارج التطبيق).
  Future<void> _pickFromGallery() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذرت قراءة الصورة')));
        return;
      }
      final ext = (file.extension ?? '').toLowerCase();
      final mimetype = ext == 'png' ? 'image/png' : 'image/jpeg';
      await _sendMediaBytes(bytes, mimetype, label: '🖼 ${file.name}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر اختيار الصورة')));
    }
  }

  Future<void> _pickPdf() async {
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
    WidgetsBinding.instance.removeObserver(this);
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
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (_recording)
          Container(
            width: double.infinity,
            color: cs.errorContainer,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.fiber_manual_record, color: cs.onErrorContainer, size: 14),
                const SizedBox(width: 6),
                Text('جاري التسجيل... اضغط زر المايك مرة ثانية للإيقاف والإرسال', style: TextStyle(color: cs.onErrorContainer)),
              ],
            ),
          ),
        Expanded(
          child: ValueListenableBuilder<String>(
            valueListenable: ChatPrefs.background,
            builder: (context, bgId, _) => Container(
              decoration: ChatPrefs.decoration(bgId),
              // إصلاح تعليق الكيبورد: السحب داخل المحادثة يُنزل الكيبورد،
              // واللمس على أي مكان خارج حقل الكتابة يُنزله أيضاً.
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                child: ListView.builder(
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
        ),
        // زرا تأكيد الجرعة داخل المحادثة (يظهران فقط عند فتحها من إشعار دواء)
        if (_medPromptId != null)
          SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _medBusy ? null : _confirmMedTaken,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('نعم، أخذته'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _medBusy ? null : _snoozeMed,
                    icon: const Icon(Icons.snooze, size: 18),
                    label: const Text('أعطني ١٠ دقائق'),
                  ),
                ),
              ]),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: _sending ? null : _pickAttachment,
                  icon: const Icon(Icons.attach_file),
                  tooltip: 'إرفاق صورة أو PDF',
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textAlign: TextAlign.right,
                    minLines: 1,
                    maxLines: 6,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
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
                    backgroundColor: _recording ? cs.error : cs.surfaceContainerHighest,
                    foregroundColor: _recording ? cs.onError : cs.onSurfaceVariant,
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
