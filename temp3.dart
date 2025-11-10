import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Speech + Location Alert',
      debugShowCheckedModeBanner: false,
      home: SpeechRecognizerPage(),
    );
  }
}

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

  final String _discordWebhookUrl =
      'https://discord.com/api/webhooks/1437344855260135465/faZqktzbIyX5YZ3XmKzeyOdgmXV6AzzdVBi03QjtzlmMr85nQtxTx6OxfHAZvKWkqY1h';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onStatus: _onSpeechStatus,
      onError: _onSpeechError,
    );
    setState(() {
      _statusMessage = _speechEnabled
          ? '음성 인식 준비 완료. START를 누르세요.'
          : '마이크 권한이 없습니다.';
    });
  }

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

  Future<void> _startListening() async {
    await _speechToText.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(hours: 1),
      localeId: 'ko_KR',
    );
    setState(() {
      _isListening = true;
      _statusMessage = '듣고 있습니다... "살려주세요"를 말하세요.';
    });
    print('🎧 음성 감지 중');
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  void _onSpeechResult(result) async {
    if (result.finalResult) {
      String normalized = result.recognizedWords
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '')
          .replaceAll(RegExp(r'[^\uac00-\ud7a3a-z0-9]'), '');

      // ✅ 키워드 감지 로직
      if (normalized.contains('살려주세요')) {
        print('🎤 음성 감지 완료');
        await _speechToText.stop();

        final position = await _getCurrentLocation();
        double? lat = position?.latitude;
        double? lon = position?.longitude;

        final now = DateTime.now();
        final timestamp =
            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} "
            "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

        final embed = {
          "embeds": [
            {
              "title": "🚨 긴급 음성 감지",
              "color": 16711680,
              "fields": [
                {"name": "📢 인식된 문장", "value": "살려주세요"},
                {
                  "name": "📍 위치",
                  "value": (lat != null && lon != null)
                      ? "위도: `$lat`\n경도: `$lon`"
                      : "위치 정보를 가져오지 못했습니다."
                },
                {"name": "🕒 시간", "value": timestamp}
              ],
              "footer": {"text": "Silent Guard"}
            }
          ]
        };

        try {
          final response = await http.post(
            Uri.parse(_discordWebhookUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(embed),
          );

          if (response.statusCode == 204) {
            print('📡 정보 전송 완료');
            _showSnackBar('✅ Discord 전송 성공!');
          } else {
            print('📡 전송 실패 (${response.statusCode})');
          }
        } catch (e) {
          print('📡 전송 오류: $e');
        }
      } else {
        // ✅ 다른 키워드 감지
        print('🟡 다른 키워드 감지됨: ${result.recognizedWords}');
        Future.delayed(const Duration(milliseconds: 300), _startListening);
      }
    }
  }

  void _onSpeechStatus(String status) {
    setState(() {
      _isListening = status == 'listening';
      if (status == 'done') {
        Future.delayed(const Duration(milliseconds: 300), _startListening);
      }
    });
  }

  void _onSpeechError(error) {
    setState(() {
      _isListening = false;
      _statusMessage = '오류 발생: ${error.errorMsg}';
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('음성 인식 + 간단 로그'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
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
