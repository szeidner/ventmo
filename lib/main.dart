import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dialogflow/dialogflow_v2.dart';
import 'package:flutter_tts/flutter_tts.dart';
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
    if (_isAvailable && !_isListening)
      _speechRecognition.listen(locale: "en_US").then((result) => () {
            print('$result');
          });
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

  Future _stop() async{
    var result = await flutterTts.stop();
    if (result == 1) setState(() => ttsState = TtsState.stopped);
  }

  Future<void> initTTS() async {
    flutterTts = FlutterTts();

    _getLanguages();

    flutterTts.setStartHandler(() {
      setState(() {
        print("playing");
        ttsState = TtsState.playing;
      });
    });

    flutterTts.setCompletionHandler(() {
      setState(() {
        print("Complete");
        ttsState = TtsState.stopped;
      });
    });

    flutterTts.setErrorHandler((msg) {
      setState(() {
        print("error");
        ttsState = TtsState.stopped;
      });
    });
  }

  void initSpeechRecognizer() {
    _speechRecognition = SpeechRecognition();

    _speechRecognition.setAvailabilityHandler(
      (bool result) => setState(() => _isAvailable = result),
    );

    _speechRecognition.setRecognitionStartedHandler(
      () => setState(() => _isListening = true),
    );

    _speechRecognition.setRecognitionResultHandler(
      (String speech) => setState(() {
        resultText = speech;
        _handleSubmitted(speech);
      }),
    );

    _speechRecognition.setRecognitionCompleteHandler(
      () => setState(() => _isListening = false),
    );

    _speechRecognition.activate().then(
          (result) => setState(() {
            _isAvailable = result;
          }),
        );
  }

  void response(query) async {
    // send to AI and get response
    AuthGoogle authGoogle =
    await AuthGoogle(fileJson: "assets/credentials.json").build();
    Dialogflow dialogflow =
    Dialogflow(authGoogle: authGoogle, language: Language.english);
    AIResponse response = await dialogflow.detectIntent(query);

    setState(() {
      _messages.insert(0, response.getMessage() ?? "");
    });

    // send response from AI to TTS
    setState(() {
      _newVoiceText = response.getMessage() ?? "";
    });
    print(response.getMessage());

    if (_isListening) {
      _speechRecognition.cancel().then(
            (result) =>
            setState(() => _isListening = result),
      );
    }

    await _speak();

    if (_isAvailable && !_isListening) {
      // start listening
      startListening();
    }
  }

  void _handleSubmitted(String text) {
    setState(() {
      _messages.insert(0, text);
    });
    response(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 50.0),
                    child: FloatingActionButton(
                      child: Icon(Icons.mic),
                      onPressed: () {
                        if (_isAvailable && !_isListening) {
                          // start listening
                          startListening();
                        } else if (_isListening) {
                          // stop
                          _speechRecognition.cancel().then(
                                (result) =>
                                    setState(() => _isListening = result),
                              );
                        }
                      },
                      backgroundColor: _isListening ? Colors.red : Colors.white,
                    ),
                  ),
                ],
              ),
            ]),
      ),
    );
  }
}
