import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

// ─────────────────────────────────────────────────────────────────────────────
// Gemini API endpoint (v1beta + gemini-2.0-flash for stability)
// ─────────────────────────────────────────────────────────────────────────────
const String _kPrefsGeminiKey  = 'GEMINI_KEY';
const String _kPrefsBackendUrl = 'BACKEND_URL';

// ─────────────────────────────────────────────────────────────────────────────
// Safe Gemini API call  (mirrors the React callGemini() function from the spec)
// ─────────────────────────────────────────────────────────────────────────────
Future<String> _callGemini(String prompt, String backendUrl, String apiKey) async {
  // Instead of calling Gemini directly, we call our Flask backend
  final uri = Uri.parse('$backendUrl/ai-insights');

  try {
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'prompt': prompt,
        'apiKey': apiKey,
      }),
    ).timeout(const Duration(seconds: 45));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['text'] ?? 'No response content.';
    } else {
      final data = json.decode(response.body);
      throw Exception(data['error'] ?? 'Backend error ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Failed to reach AI backend: $e');
  }
}

// Internal exception to carry retry-after value
class _RateLimitException implements Exception {
  final int seconds;
  _RateLimitException(String? header)
      : seconds = int.tryParse(header ?? '') ?? 30;
}

// ─────────────────────────────────────────────────────────────────────────────
// Parse bullet / numbered list from raw Gemini text
// ─────────────────────────────────────────────────────────────────────────────
List<String> _parseBullets(String text) {
  return text
      .split('\n')
      .map((l) => l.trim())
      .where((l) =>
          l.startsWith('•') ||
          l.startsWith('-') ||
          l.startsWith('*') ||
          RegExp(r'^\d+[\.\)]').hasMatch(l))
      .map((l) => l.replaceFirst(RegExp(r'^[•\-\*\d]+[\.\)]\s*'), '').trim())
      .where((l) => l.isNotEmpty)
      .take(3)
      .toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// AppState
// ─────────────────────────────────────────────────────────────────────────────
class AppState extends ChangeNotifier {
  // ── Config ──────────────────────────────────────────────────────────────────
  String backendUrl   = 'http://127.0.0.1:5000';
  String geminiApiKey = 'AIzaSyB9oUL1LCI3CfTY7fuYtt-f61Nw3Q_2cN0';

  // ── Data ────────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> dataset = [];
  String biasColumn  = 'gender';
  bool   isAnalyzing = false;

  // ── Results ─────────────────────────────────────────────────────────────────
  double              accuracy       = 0.0;
  double              biasScore      = 0.0;
  Map<String, double> selectionRates = {};
  List<Map<String, dynamic>> featureImpacts = [];
  String apiMessage    = '';
  String aiExplanation = '';

  // ── Analytics ───────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> biasTrend      = [];
  List<Map<String, dynamic>> biasTrendBefore = [];
  List<Map<String, dynamic>> accuracyByGroup = [];
  Map<String, dynamic>       beforeAfter     = {};
  // Real run-by-run history (replaces fake month trend)
  List<Map<String, dynamic>> analysisHistory = [];

  // ── Gemini state ─────────────────────────────────────────────────────────────
  bool         isGeminiLoading      = false;
  String       geminiError          = '';
  List<String> aiRecommendations    = [];
  int          geminiCooldownSeconds = 0;

  // Internal: prevent duplicate concurrent calls
  bool   _geminiCallInProgress = false;
  Timer? _cooldownTimer;
  // Minimum milliseconds between calls (debounce)
  static const int _kMinCallIntervalMs = 2000;
  DateTime _lastGeminiCall = DateTime.fromMillisecondsSinceEpoch(0);

  // ── Init: load persisted settings ────────────────────────────────────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    geminiApiKey = prefs.getString(_kPrefsGeminiKey)  ?? 'AIzaSyB9oUL1LCI3CfTY7fuYtt-f61Nw3Q_2cN0';
    backendUrl   = prefs.getString(_kPrefsBackendUrl) ?? 'http://127.0.0.1:5000';
    notifyListeners();
  }

  // ── Persist settings (localStorage equivalent) ───────────────────────────────
  Future<void> updateGeminiApiKey(String key) async {
    geminiApiKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsGeminiKey, geminiApiKey);
    notifyListeners();
  }

  Future<void> updateBackendUrl(String url) async {
    backendUrl = url.trim().isEmpty ? 'http://127.0.0.1:5000' : url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsBackendUrl, backendUrl);
    notifyListeners();
  }

  void updateBiasColumn(String column) {
    biasColumn = column;
    notifyListeners();
  }

  // ── Dataset helpers ──────────────────────────────────────────────────────────
  void addDatasetRow(Map<String, dynamic> row) {
    dataset.add(row);
    notifyListeners();
  }

  void setDataset(List<Map<String, dynamic>> data) {
    dataset = data;
    notifyListeners();
  }

  void removeDatasetRow(int index) {
    if (index >= 0 && index < dataset.length) {
      dataset.removeAt(index);
      notifyListeners();
    }
  }

  // ── Cooldown timer (countdown only — NO auto-retry) ────────────────────────
  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    geminiCooldownSeconds = seconds;
    notifyListeners();

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (geminiCooldownSeconds <= 1) {
        t.cancel();
        geminiCooldownSeconds = 0;
        // Just update the error to invite a manual retry — no auto-loop
        geminiError = 'Rate limit window cleared. Click Refresh Insights to retry.';
        notifyListeners();
      } else {
        geminiCooldownSeconds--;
        geminiError = 'Rate limit reached. Please wait $geminiCooldownSeconds seconds, then click Retry.';
        notifyListeners();
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // fetchGeminiInsights — production-ready, debounced, de-duplicated
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> fetchGeminiInsights() async {
    // Guard: active cooldown (rate-limit window)
    if (geminiCooldownSeconds > 0) {
      geminiError = 'Please wait $geminiCooldownSeconds s before retrying.';
      notifyListeners();
      return;
    }

    // Guard: duplicate concurrent call
    if (_geminiCallInProgress) return;

    // Guard: debounce — minimum 2 s between calls
    final now = DateTime.now();
    final elapsed = now.difference(_lastGeminiCall).inMilliseconds;
    if (elapsed < _kMinCallIntervalMs) {
      await Future.delayed(Duration(milliseconds: _kMinCallIntervalMs - elapsed));
    }

    _geminiCallInProgress = true;
    isGeminiLoading       = true;
    geminiError           = '';
    notifyListeners();

    try {
      final pct     = (accuracy  * 100).toStringAsFixed(1);
      final biasPct = (biasScore * 100).toStringAsFixed(1);

      // ── Prompt: Combined Explanation + Recommendations (1 call only) ───────
      final combinedPrompt = '''
You are an expert AI ethics and fairness analyst. 
The AI model has an accuracy of $pct% and a bias score of $biasPct% for the "$biasColumn" attribute.

Part 1: Explanation
Write a professional 1-2 paragraph diagnostic explanation. Explain why this bias likely occurs, its real-world impact, and if it requires intervention.

Part 2: Recommendations
Give exactly 3 clear, actionable recommendations to reduce this bias. 
Format each as a numbered list item (1. 2. 3.). Keep each recommendation under 25 words.
''';

      final resultText = await _callGemini(combinedPrompt, backendUrl, geminiApiKey);
      _lastGeminiCall = DateTime.now();

      // Split the result into explanation and recommendations based on "1." or "Part 2"
      final lines = resultText.split('\n');
      final explanationLines = <String>[];
      final recsLines = <String>[];
      bool inRecs = false;

      for (var line in lines) {
        if (line.trim().startsWith('1.') || line.toLowerCase().contains('part 2') || line.toLowerCase().contains('recommendation')) {
          inRecs = true;
        }
        if (inRecs) {
          recsLines.add(line);
        } else {
          explanationLines.add(line);
        }
      }

      // Clean up explanation
      aiExplanation = explanationLines.join('\n').replaceAll(RegExp(r'\**Part 1:?.*\**'), '').trim();
      if (aiExplanation.isEmpty) aiExplanation = resultText; // fallback

      // Parse recommendations
      final parsed = _parseBullets(recsLines.join('\n'));
      aiRecommendations = parsed.isNotEmpty
          ? parsed
          : recsLines
              .where((l) => l.trim().startsWith(RegExp(r'\d\.')))
              .map((l) => l.trim())
              .toList();

    } on _RateLimitException catch (e) {
      geminiError = 'Rate limit reached. Please wait ${e.seconds} seconds, then click Retry.';
      _startCooldown(e.seconds);
    } on TimeoutException {
      geminiError = 'Request timed out. Check your connection and retry.';
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      geminiError = msg.contains('Missing API key')
          ? 'No API key set. Add your Gemini key in Settings.'
          : 'AI temporarily unavailable. $msg';
    } finally {
      _geminiCallInProgress = false;
      isGeminiLoading       = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // analyzeData — calls Flask backend; does NOT auto-trigger Gemini
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> analyzeData({bool fixBias = false}) async {
    if (dataset.isEmpty) {
      apiMessage = 'Dataset is empty. Please upload data first.';
      notifyListeners();
      return;
    }

    isAnalyzing = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'dataset':     dataset,
          'bias_column': biasColumn,
          'fix_bias':    fixBias,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        accuracy  = (data['accuracy'] ?? 0.0).toDouble();
        biasScore = (data['bias']     ?? 0.0).toDouble();

        if (data['rates'] != null) {
          selectionRates = Map<String, double>.from(
            (data['rates'] as Map).map(
              (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
            ),
          );
        }

        if (data['feature_impacts'] != null) {
          featureImpacts = List<Map<String, dynamic>>.from(data['feature_impacts']);
        }
        if (data['bias_trend']        != null) biasTrend       = List<Map<String, dynamic>>.from(data['bias_trend']);
        if (data['bias_trend_before'] != null) biasTrendBefore = List<Map<String, dynamic>>.from(data['bias_trend_before']);
        if (data['accuracy_by_group'] != null) accuracyByGroup = List<Map<String, dynamic>>.from(data['accuracy_by_group']);
        if (data['before_after']      != null) beforeAfter     = Map<String, dynamic>.from(data['before_after']);

        apiMessage   = data['message']     ?? 'Analysis complete';
        // Use Flask explanation as baseline; Gemini enriches it on "Refresh Insights"
        aiExplanation = data['explanation'] ?? '';

        // ── Record real run history (Option 3: run-by-run tracking) ──────────
        analysisHistory.add({
          'run':      analysisHistory.length + 1,
          'bias':     biasScore,
          'accuracy': accuracy,
          'fixBias':  fixBias,
          'label':    fixBias ? 'Fix #${analysisHistory.length + 1}' : 'Run #${analysisHistory.length + 1}',
        });
        // Cap history to last 10 runs
        if (analysisHistory.length > 10) analysisHistory.removeAt(0);

      } else {
        final errorMsg = json.decode(response.body)['error'] ?? 'Unknown error';
        apiMessage = 'Backend Error: $errorMsg';
      }
    } catch (e) {
      apiMessage = 'Failed to connect to backend: $e';
    } finally {
      isAnalyzing = false;
      notifyListeners();
    }
    // ⚠️ Gemini is NOT auto-called here — prevents rate limit exhaustion.
    // User explicitly clicks "Refresh Insights" to trigger Gemini.
  }

  // ── Report builder ───────────────────────────────────────────────────────────
  String buildReport() {
    final fairness = ((1 - biasScore) * 100).round();
    final sb = StringBuffer();
    sb.writeln('═══════════════════════════════════════');
    sb.writeln('       FairAI Guardian Pro — Report     ');
    sb.writeln('═══════════════════════════════════════');
    sb.writeln('Bias Column : $biasColumn');
    sb.writeln('Accuracy    : ${(accuracy * 100).toStringAsFixed(1)}%');
    sb.writeln('Bias Score  : ${(biasScore * 100).toStringAsFixed(1)}%');
    sb.writeln('Fairness    : $fairness / 100');
    sb.writeln();
    sb.writeln('── AI Explanation ──────────────────────');
    sb.writeln(aiExplanation.isNotEmpty ? aiExplanation : 'Not generated yet.');
    sb.writeln();
    sb.writeln('── Recommendations ─────────────────────');
    if (aiRecommendations.isEmpty) {
      sb.writeln('Not generated yet.');
    } else {
      for (int i = 0; i < aiRecommendations.length; i++) {
        sb.writeln('${i + 1}. ${aiRecommendations[i]}');
      }
    }
    sb.writeln('═══════════════════════════════════════');
    return sb.toString();
  }

  // ── Sample data ──────────────────────────────────────────────────────────────
  void loadSampleData() {
    setDataset([
      {"age": 28, "gender": "Female", "experience": 4.5,  "test_score": 88, "selected": 1},
      {"age": 34, "gender": "Male",   "experience": 8.0,  "test_score": 92, "selected": 1},
      {"age": 25, "gender": "Male",   "experience": 2.0,  "test_score": 65, "selected": 0},
      {"age": 41, "gender": "Female", "experience": 12.5, "test_score": 85, "selected": 0},
      {"age": 29, "gender": "Male",   "experience": 5.0,  "test_score": 78, "selected": 0},
      {"age": 31, "gender": "Female", "experience": 6.5,  "test_score": 90, "selected": 1},
      {"age": 26, "gender": "Male",   "experience": 3.0,  "test_score": 70, "selected": 0},
      {"age": 38, "gender": "Female", "experience": 10.0, "test_score": 82, "selected": 1},
      {"age": 27, "gender": "Female", "experience": 3.5,  "test_score": 75, "selected": 0},
      {"age": 35, "gender": "Male",   "experience": 9.0,  "test_score": 95, "selected": 1},
    ]);
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }
}
