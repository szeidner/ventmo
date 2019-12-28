import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dialogflow/dialogflow_v2.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_debounce_it/just_debounce_it.dart';
import 'package:speech_recognition/speech_recognition.dart';

void main() {
  // set a dark status bar for iOS and Android
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.white, // Color for Android
      statusBarBrightness:
          Brightness.dark // Dark == white status bar -- for IOS.
      ));

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ventmo',
      theme: ThemeData.dark()
          .copyWith(scaffoldBackgroundColor: const Color(0xFF000000)),
      debugShowCheckedModeBanner: false,
      home: Home(),
    );
  }
}

enum TtsState { playing, stopped }

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  SpeechRecognition _speechRecognition;
  bool _isAvailable = false;
  bool _isListening = false;

  FlutterTts flutterTts;
  dynamic languages;
  String language;
  double volume = 0.5;
  double pitch = 1.0;
  double rate = 0.5;

  String _newVoiceText;
  String _status = "Initializing...";
  TtsState ttsState = TtsState.stopped;

  get isPlaying => ttsState == TtsState.playing;

  get isStopped => ttsState == TtsState.stopped;

  final List<String> _messages = <String>[];

  String resultText = "";

  @override
  void initState() {
    super.initState();
    // speech to text
    initSpeechRecognizer();

    // text to speech
    initTTS();
  }

  void startListening() {
    if (_isAvailable && !_isListening) {
      setState(() => _isListening = true);
      _speechRecognition
          .listen(locale: "en_US")
          .then((result) => print('$result'));
    }
  }

  Future _getLanguages() async {
    languages = await flutterTts.getLanguages;
    if (languages != null) setState(() => languages);
  }

  Future _speak() async {
    await flutterTts.setVolume(volume);
    await flutterTts.setSpeechRate(rate);
    await flutterTts.setPitch(pitch);

    if (_newVoiceText != null) {
      if (_newVoiceText.isNotEmpty) {
        var result = await flutterTts.speak(_newVoiceText);
        if (result == 1) setState(() => ttsState = TtsState.playing);
      }
    }
  }

  Future _stop() async {
    var result = await flutterTts.stop();
    if (result == 1) setState(() => ttsState = TtsState.stopped);
  }

  Future<void> initTTS() async {
    flutterTts = FlutterTts();

    _getLanguages();

    flutterTts.setStartHandler(() {
      if (_isListening) {
        _speechRecognition.cancel().then((result) => setState(() {
              _isListening = false;
              _status = "NOT LISTENING";
            }));
      }

      print("playing");
      ttsState = TtsState.playing;
    });

    flutterTts.setCompletionHandler(() {
      setState(() {
        print("Complete");
        ttsState = TtsState.stopped;
      });
      startListening();
    });

    flutterTts.setErrorHandler((msg) {
      setState(() {
        print("error");
        ttsState = TtsState.stopped;
      });
      startListening();
    });
  }

  void initSpeechRecognizer() {
    _speechRecognition = SpeechRecognition();

    _speechRecognition.setAvailabilityHandler(
      (bool result) {
        setState(() => _isAvailable = result);
        if (result) {
          setState(() => _status = "AVAILABLE");
        } else {
          setState(() => _status = "NOT AVAILABLE");
        }
      },
    );

    _speechRecognition.setRecognitionStartedHandler(
      () {
        setState(() {
          _isListening = true;
          _status = "LISTENING";
        });
      },
    );

    _speechRecognition.setRecognitionResultHandler(
      (String speech) => setState(() {
        resultText = speech;
        _handleSubmitted(speech);
      }),
    );

    _speechRecognition.setRecognitionCompleteHandler(
      () {
        setState(() {
          _isListening = false;
          _status = "NOT LISTENING";
        });
      },
    );

    _speechRecognition.activate().then((result) {
      setState(() => _isAvailable = result);
      if (result) {
        startListening();
      } else {
        setState(() {
          _status = "NOT AVAILABLE";
        });
      }
      setState(() => _isAvailable = result);
    });
  }

  void response(query) async {
    print('Send to AI: $query');

    // send to AI and get response
    AuthGoogle authGoogle =
        await AuthGoogle(fileJson: "assets/credentials.json").build();
    Dialogflow dialogflow =
        Dialogflow(authGoogle: authGoogle, language: Language.english);
    AIResponse response = await dialogflow.detectIntent(query);

    // send response from AI to TTS
    setState(() {
      _newVoiceText = response.getMessage() ?? "";
    });
    print('Received from AI: ${response.getMessage()}');

    await _speak();
  }

  void _handleSubmitted(String text) {
    if (_messages.isNotEmpty && _messages.last == text) return;

    setState(() {
      _messages.insert(0, text);
    });

    Debounce.milliseconds(1000, response, [text]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Center(
                  child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: 35.0,
                ),
                child: Text(
                  _status,
                  style: TextStyle(fontSize: 14.0),
                  textAlign: TextAlign.center,
                ),
              )),
              Container(
                width: MediaQuery.of(context).size.width * 0.8,
                padding: EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 12.0,
                ),
                child: Text(
                  resultText,
                  style: TextStyle(fontSize: 24.0),
                ),
              ),
//              Row(
//                mainAxisAlignment: MainAxisAlignment.center,
//                children: <Widget>[
//                  Padding(
//                    padding: const EdgeInsets.only(bottom: 50.0),
//                    child: FloatingActionButton(
//                      child: Icon(Icons.mic),
//                      onPressed: () {
//                        if (_isAvailable && !_isListening) {
//                          // start listening
//                          startListening();
//                        } else if (_isListening) {
//                          // stop
//                          _speechRecognition.cancel().then(
//                                (result) =>
//                                    setState(() => _isListening = result),
//                              );
//                        }
//                      },
//                      backgroundColor: _isListening ? Colors.red : Colors.white,
//                    ),
//                  ),
//                ],
//              ),
            ]),
      ),
    );
  }
}
