import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/transaction_model.dart';
import 'mock_parser_service.dart';

/// AI-backed parser using OpenAI Chat Completions API.
/// Falls back to local regex-based MockParserService on any failure.
class AIParserService {
  AIParserService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final MockParserService _fallback = MockParserService();

  /// Parse user input into a ParsedTransaction using OpenAI.
  /// Never throws; returns null only when no usable amount can be found.
  Future<ParsedTransaction?> parse(String rawText,
      {String defaultCurrency = 'RSD'}) async {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) return null;

    String? apiKey;
    try {
      // flutter_dotenv throws NotInitializedError if not loaded; guard for that.
      apiKey = dotenv.isInitialized ? dotenv.env['OPENAI_API_KEY'] : null;
    } catch (_) {
      apiKey = null;
    }
    if (apiKey == null || apiKey.isEmpty) {
      // No key configured – always fallback to local parser.
      // ignore: avoid_print
      print('[AIParser] OPENAI_API_KEY missing, using fallback parser.');
      return _fallbackOrSimple(trimmed);
    }

    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');

    final body = jsonEncode({
      'model': 'gpt-4o-mini',
      'temperature': 0,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a financial transaction parser.\n'
                  'Extract structured JSON only.\n'
                  'Do not explain.\n'
                  'Return valid JSON only.\n'
                  'If information is missing, infer reasonably.\n'
                  'Expected JSON format:\n'
                  '{\"type\": \"expense | income | savings | investment\",'
                  ' \"amount\": 0,'
                  ' \"currency\": \"$defaultCurrency\",'
                  ' \"category\": \"\",'
                  ' \"categoryGroup\": \"needs | wants | savings\"}',
        },
        {
          'role': 'user',
          'content': trimmed,
        },
      ],
    });

    // Debug: log prompt we are sending (without API key).
    // ignore: avoid_print
    print('[AIParser] Request body: $body');

    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        // ignore: avoid_print
        print(
            '[AIParser] Non-200 status ${response.statusCode}, using fallback.');
        // ignore: avoid_print
        print('[AIParser] Response body: ${response.body}');
        return _fallbackOrSimple(trimmed);
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = decoded['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        // ignore: avoid_print
        print('[AIParser] No choices in response, using fallback.');
        return _fallbackOrSimple(trimmed);
      }

      final message = choices.first['message'] as Map<String, dynamic>?;
      final content = message?['content'];
      if (content == null || content is! String) {
        // ignore: avoid_print
        print('[AIParser] Missing/invalid content, using fallback.');
        return _fallbackOrSimple(trimmed);
      }

       // Debug: log raw assistant content before we try to parse JSON.
       // ignore: avoid_print
       print('[AIParser] Raw assistant content: $content');

      Map<String, dynamic> json;
      try {
        json = jsonDecode(content) as Map<String, dynamic>;
      } catch (e) {
        // ignore: avoid_print
        print('[AIParser] JSON parse error: $e, using fallback.');
        return _fallbackOrSimple(trimmed);
      }

      final dynamic rawAmount = json['amount'];
      double amount = 0;
      if (rawAmount is num) {
        amount = rawAmount.toDouble();
      } else if (rawAmount is String) {
        // Handle strings like "1450", "1,450", or "1450 RSD"
        final match = RegExp(r'[\d]+[.,]?\d*').firstMatch(rawAmount);
        if (match != null) {
          final str = match.group(0)?.replaceAll(',', '.') ?? '';
          amount = double.tryParse(str) ?? 0;
        }
      }
      if (amount <= 0) {
        // ignore: avoid_print
        print('[AIParser] Non-positive amount from AI ($rawAmount), using fallback.');
        return _fallbackOrSimple(trimmed);
      }

      final category = (json['category'] as String?)?.trim();
      final groupRaw = (json['categoryGroup'] as String?)?.toLowerCase().trim();
      String categoryGroup;
      switch (groupRaw) {
        case kCategoryGroupNeeds:
          categoryGroup = kCategoryGroupNeeds;
          break;
        case kCategoryGroupSavings:
          categoryGroup = kCategoryGroupSavings;
          break;
        default:
          categoryGroup = kCategoryGroupWants;
      }

      final parsed = ParsedTransaction(
        amount: amount,
        category: category?.isNotEmpty == true ? category! : 'Misc',
        merchant: null,
        categoryGroup: categoryGroup,
      );

      // ignore: avoid_print
      print('[AIParser] Parsed via OpenAI: '
          'amount=$amount, category=${parsed.category}, group=$categoryGroup');

      return parsed;
    } on TimeoutException {
      // ignore: avoid_print
      print('[AIParser] Timeout, using fallback parser.');
      return _fallbackOrSimple(trimmed);
    } catch (e) {
      // ignore: avoid_print
      print('[AIParser] Error $e, using fallback parser.');
      return _fallbackOrSimple(trimmed);
    }
  }

  ParsedTransaction? _fallbackOrSimple(String text) {
    final fromMock = _fallback.parse(text);
    if (fromMock != null) {
      return fromMock;
    }

    // Simple regex fallback as a last resort.
    final match = RegExp(r'[\d]+[.,]?\d*').firstMatch(text);
    if (match == null) return null;
    final str = match.group(0)?.replaceAll(',', '.') ?? '';
    final amount = double.tryParse(str);
    if (amount == null || amount <= 0) return null;

    return ParsedTransaction(
      amount: amount,
      category: 'Misc',
      merchant: null,
      categoryGroup: kCategoryGroupWants,
    );
  }
}

