// user_chat_hospital.dart
import 'package:flutter/material.dart';

class UserChatHospitalScreen extends StatefulWidget {
  final String token;
  final String hospitalId;
  final String hospitalName;

  const UserChatHospitalScreen({
    super.key,
    required this.token,
    required this.hospitalId,
    required this.hospitalName,
  });

  @override
  State<UserChatHospitalScreen> createState() => _UserChatHospitalScreenState();
}

class _UserChatHospitalScreenState extends State<UserChatHospitalScreen> {
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      isMine: false,
      text: '안녕하세요 보호자님, 무엇을 도와드릴까요?',
      time: DateTime.now().subtract(const Duration(minutes: 5)),
      senderName: '김철수 원장',
    ),
    _ChatMessage(
      isMine: true,
      text: '요즘 강아지들이 먹는 간식 추천해줘.',
      time: DateTime.now().subtract(const Duration(minutes: 3)),
    ),
  ];

  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _inputCtrl.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final txt = _inputCtrl.text.trim();
    if (txt.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(isMine: true, text: txt, time: DateTime.now()));
    });
    _inputCtrl.clear();
    // 살짝 늦춰 스크롤 맨 아래로
    Future.delayed(const Duration(milliseconds: 60), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final topYellow = const Color(0xFFFFF4B8);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: topYellow,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          '채팅 문의',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 상단 안내 문구
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.transparent,
              child: const Text(
                '＊ 병원 원장님과의 채팅 공간입니다 ＊',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 12.5,
                ),
              ),
            ),

            // 메시지 영역
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                itemCount: _messages.length,
                itemBuilder: (_, i) {
                  final m = _messages[i];
                  final String? prevSenderName = i > 0 ? _messages[i - 1].senderName : null;
                  final showName = !m.isMine && (m.senderName?.isNotEmpty ?? false) && m.senderName != prevSenderName;
                  return _MessageRow(
                    message: m,
                    showName: showName,
                  );
                },
              ),
            ),

            // 입력창
            _InputBar(
              controller: _inputCtrl,
              focusNode: _focus,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── 모델 ─────────────────────────

class _ChatMessage {
  final bool isMine; // true: 사용자, false: 병원/원장
  final String text;
  final DateTime time;
  final String? senderName; // 의사/간호사 이름

  _ChatMessage({
    required this.isMine,
    required this.text,
    required this.time,
    this.senderName,
  });
}

// ───────────────────────── 위젯 ─────────────────────────

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message, required this.showName});
  final _ChatMessage message;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;

    final avatar = !isMine
        ? const CircleAvatar(
      radius: 16,
      backgroundColor: Color(0xFF7A3E2D), // 스샷 느낌의 브라운 톤
    )
        : const SizedBox(width: 32);

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.66,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F1F1), // 스샷의 연한 회색 버블
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMine ? 14 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 14),
          ),
        ),
        child: Text(
          message.text,
          style: const TextStyle(fontSize: 14.5, color: Colors.black87),
        ),
      ),
    );

    final name = showName
        ? Padding(
      padding: const EdgeInsets.only(left: 44, bottom: 4),
      child: Text(
        message.senderName!,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    )
        : const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment:
        isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMine) name,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMine) avatar,
              if (!isMine) const SizedBox(width: 8),
              bubble,
              if (isMine) const SizedBox(width: 8),
              if (isMine)
                const SizedBox(width: 32), // 상대 아바타 자리 맞춤용
            ],
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFFFF9D6); // 연한 노랑(상단 톤에 맞춤)
    final canSend = controller.text.trim().isNotEmpty;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        color: bg,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFEFEFEF)),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: '채팅 입력..',
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => (context as Element).markNeedsBuild(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: canSend ? onSend : null,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black54,
                  disabledBackgroundColor: Colors.white.withOpacity(0.7),
                  disabledForegroundColor: Colors.black26,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text('전송'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
