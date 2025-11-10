import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

// =======================================================
// 1. 앱 진입점
// =======================================================
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Speech to Discord Demo',
      debugShowCheckedModeBanner: false,
      home: SpeechRecognizerPage(),
    );
  }
}

// =======================================================
// 2. 메인 페이지
// =======================================================
class SpeechRecognizerPage extends StatefulWidget {
  const SpeechRecognizerPage({super.key});

  @override
  State<SpeechRecognizerPage> createState() => _SpeechRecognizerPageState();
}

class _SpeechRecognizerPageState extends State<SpeechRecognizerPage> {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _statusMessage = '준비 중...';

  // ✅ 여기에 너의 Discord Webhook URL 붙여넣기
  final String _discordWebhookUrl =
      'https://discord.com/api/webhooks/1437344855260135465/faZqktzbIyX5YZ3XmKzeyOdgmXV6AzzdVBi03QjtzlmMr85nQtxTx6OxfHAZvKWkqY1h';

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
  Future<void> _initSpeech() async {
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
  }

  // =======================================================
  // 4. 리스닝 토글
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
      setState(() {
        _statusMessage = '리스닝 시작 실패.';
        _isListening = false;
      });
    }
  }

  // =======================================================
  // 6. 음성 인식 결과 처리 + Discord 전송
  // =======================================================
  void _onSpeechResult(result) async {
    if (result.finalResult) {
      String recognizedWords = result.recognizedWords.toLowerCase().trim();
      String normalized = recognizedWords
          .replaceAll(RegExp(r'\s+'), '')
          .replaceAll(RegExp(r'[^\uac00-\ud7a3a-z0-9]'), '');

      print('인식된 원문: $recognizedWords');
      print('정규화된 결과: $normalized');

      if (normalized.contains('살려주세요')) {
        await _speechToText.stop();

        print('---------------------------');
        print('        음성인식완료        ');
        print('---------------------------');

        setState(() {
          _statusMessage = '🚨 음성인식완료 - Discord로 전송 중...';
        });

        // ✅ Discord Webhook 메시지 전송
        try {
          final response = await http.post(
            Uri.parse(_discordWebhookUrl),
            headers: {'Content-Type': 'application/json'},
            body: '{"content": "🚨 **음성인식 완료!** 사용자가 `살려주세요`를 말했습니다."}',
          );

          if (response.statusCode == 204) {
            print('✅ Discord 전송 성공');
            _showSnackBar('✅ Discord 알림 전송 완료!');
            setState(() {
              _statusMessage = '✅ Discord 알림 전송 완료!';
            });
          } else {
            print('⚠️ Discord 응답 코드: ${response.statusCode}');
            _showSnackBar('⚠️ Discord 전송 실패 (${response.statusCode})');
          }
        } catch (e) {
          print('전송 오류: $e');
          _showSnackBar('⚠️ Discord 전송 오류');
        }
      } else {
        Future.delayed(const Duration(milliseconds: 300), _startListening);
      }
    }
  }

  // =======================================================
  // 7. 상태 및 에러 콜백
  // =======================================================
  void _onSpeechStatus(String status) {
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
    print('Speech status: $status');
  }

  void _onSpeechError(error) {
    print('Speech error: $error');
    if (mounted) {
      setState(() {
        _isListening = false;
        _statusMessage = '오류 발생: ${error.errorMsg}';
      });
    }
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
        title: const Text('음성 인식 → Discord 알림'),
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
