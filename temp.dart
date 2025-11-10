import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:async';

// =======================================================
// 1. 앱 진입점 및 기본 설정
// =======================================================
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Simple Speech Recognizer',
      debugShowCheckedModeBanner: false,
      home: SpeechRecognizerPage(),
    );
  }
}

// =======================================================
// 2. 메인 위젯 및 로직
// =======================================================
class SpeechRecognizerPage extends StatefulWidget {
  const SpeechRecognizerPage({super.key});

  @override
  State<SpeechRecognizerPage> createState() => _SpeechRecognizerPageState();
}

class _SpeechRecognizerPageState extends State<SpeechRecognizerPage> {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false; // 음성 인식 초기화 성공 여부
  bool _isListening = false; // 현재 마이크로 듣고 있는 상태
  String _statusMessage = '준비 중...';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _speechToText.stop();
    super.dispose();
  }

  // =======================================================
  // 3. 음성 인식 초기화
  // =======================================================
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onStatus: _onSpeechStatus,
      onError: _onSpeechError,
    );

    if (mounted) {
      setState(() {
        _statusMessage = _speechEnabled
            ? '음성 인식 준비 완료. START를 누르세요.'
            : '마이크 권한이 없습니다.';
      });
    }

    if (!_speechEnabled) {
      _showSnackBar('마이크 권한을 허용해야 음성 인식이 가능합니다.');
    }
  }

  // =======================================================
  // 4. 리스닝 시작/중지 토글
  // =======================================================
  void _toggleListening() async {
    if (!_speechEnabled) {
      _showSnackBar('권한 문제로 시작할 수 없습니다.');
      return;
    }

    if (_isListening) {
      await _speechToText.stop();
    } else {
      await _startListening();
    }
  }

  // =======================================================
  // 5. 리스닝 시작
  // =======================================================
  Future<void> _startListening() async {
    try {
      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(hours: 1),
        localeId: 'ko_KR',
      );
      if (mounted) {
        setState(() {
          _isListening = true;
          _statusMessage = '듣고 있습니다... "살려주세요"를 말하세요.';
        });
      }
    } catch (e) {
      print("리스닝 시작 중 에러: $e");
      if (mounted) {
        setState(() {
          _statusMessage = '리스닝 시작 실패.';
          _isListening = false;
        });
      }
    }
  }

  // =======================================================
  // 6. 음성 인식 결과 처리 (정규화 개선판)
  // =======================================================
  void _onSpeechResult(result) {
    if (result.finalResult) {
      String recognizedWords = result.recognizedWords.toLowerCase().trim();

      // ⚙️ [핵심 추가] 공백/특수문자 제거 → 비교 정확도 향상
      String normalized = recognizedWords
          .replaceAll(RegExp(r'\s+'), '') // 모든 공백 제거
          .replaceAll(RegExp(r'[^\uac00-\ud7a3a-z0-9]'), ''); // 한글/영문/숫자 외 제거

      print('인식된 원문: $recognizedWords');
      print('정규화된 결과: $normalized');

      if (normalized.contains('살려주세요')) {
        _speechToText.stop();

        print('---------------------------');
        print('        음성인식완료        ');
        print('---------------------------');

        // TODO: 여기에 HTTP 요청이나 알림 전송 로직 추가
      } else if (normalized.isEmpty) {
        print('인식된 단어 없음 → 감시 재시작');
        Future.delayed(const Duration(milliseconds: 300), _startListening);
      } else {
        print('키워드("살려주세요") 아님: "$recognizedWords" → 감시 재시작');
        Future.delayed(const Duration(milliseconds: 300), _startListening);
      }
    }
  }

  // =======================================================
  // 7. 상태 및 에러 콜백
  // =======================================================
  void _onSpeechStatus(String status) {
    print('Speech status: $status');

    if (mounted) {
      setState(() {
        _isListening = status == 'listening';

        if (status == 'listening') {
          _statusMessage = '듣고 있습니다... "살려주세요"를 말하세요.';
        } else if (status == 'done') {
          _statusMessage = '감지 완료. 다시 감시를 시작합니다.';
          Future.delayed(const Duration(milliseconds: 300), _startListening);
        }
      });
    }
  }

  void _onSpeechError(error) {
    print('Speech error: $error');

    if (mounted) {
      setState(() {
        _isListening = false;
        _statusMessage = '오류 발생: ${error.errorMsg}';
      });
    }

    // 오류 발생 시 재시작 (안정성 ↑)
    Future.delayed(const Duration(seconds: 1), _startListening);
  }

  // =======================================================
  // 8. 스낵바 헬퍼
  // =======================================================
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // =======================================================
  // 9. UI
  // =======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('단순 음성 인식 테스트'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              softWrap: true,
              style: TextStyle(
                fontSize: 18,
                color: _isListening ? Colors.red : Colors.black87,
              ),
            ),
            const SizedBox(height: 50),
            FloatingActionButton.extended(
              onPressed: _toggleListening,
              label: Text(_isListening ? 'STOP' : 'START'),
              icon: Icon(_isListening ? Icons.stop : Icons.mic),
              backgroundColor: _isListening ? Colors.red : Colors.green,
            ),
          ],
        ),
      ),
    );
  }
}
