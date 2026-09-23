  import 'dart:convert';
import 'package:http/http.dart' as http;

class GroqService {
  static const String _apiKey = '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';
  static const String _apiUrl = 'https://api.groq.com/openai/v1/chat/completions';

  Future<List<String>> getPredictiveAdjustments(double visibility, int probability) async {
    if (_apiKey == 'YOUR_GROQ_API_KEY') {
      // Return dummy data if key is not set to prevent errors
      return [
        'Please add Groq API Key to see real AI predictions.',
      ];
    }

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.1-8b-instant',
          'messages': [
            {
              'role': 'system',
              'content': 'You are an AI safety system for a mining fleet. Your task is to provide exactly 2 brief, actionable fleet safety adjustments based on the current weather conditions. Return ONLY a valid JSON array of strings.'
            },
            {
              'role': 'user',
              'content': 'Current visibility is $visibility meters. Fog probability is $probability%. Generate 2 brief, actionable fleet adjustments (e.g., "Reduce speed to 15km/h").'
            }
          ],
          'temperature': 0.7,
          'max_tokens': 150,
          'response_format': { 'type': 'json_object' } // We will parse the array
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        // Parse the stringified JSON array
        try {
           final parsedArray = jsonDecode(content);
           if (parsedArray is List) {
             return parsedArray.map((e) => e.toString()).toList();
           } else if (parsedArray is Map) {
             // Sometimes the model wraps it in an object if response_format is json_object
             if (parsedArray.values.first is List) {
               return (parsedArray.values.first as List).map((e) => e.toString()).toList();
             }
           }
        } catch(e) {
          // If JSON parsing fails, just return the raw text split by newlines
           return content.split('\n').where((line) => line.trim().isNotEmpty).toList();
        }
      } else {
        print('Groq Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Exception calling Groq: $e');
    }
    
    // Fallback if API fails
    return [
      'Reduce fleet speed due to visibility.',
      'Maintain safe distance between vehicles.'
    ];
  }
}
