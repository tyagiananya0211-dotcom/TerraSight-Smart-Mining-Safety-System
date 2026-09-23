import 'dart:convert';
import 'package:http/http.dart' as http;

class MineApiService {
  Future<Map<String, dynamic>> getMineData() async {
    try {
      final response = await http
          .get(
            Uri.parse('https://dummyjson.com/products/1'),
          )
          .timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        jsonDecode(response.body);

        return {
          'mine_name': 'Bailadila Mine',

          'location': 'Iron Ore Production Unit',

          'image_url':
              'https://img.freepik.com/premium-photo/vehicles-coal-mine-view_575980-17906.jpg',

          'total_dumpers': 128,
          'moving': 94,
          'on_hold': 14,
          'maintenance': 20,
        };
      }

      return _fallbackData();
    } catch (e) {
      return _fallbackData();
    }
  }

  Map<String, dynamic> _fallbackData() {
    return {
      'mine_name': 'Bailadila Mine',

      'location': 'Iron Ore Production Unit',

      'image_url':
      'https://img.freepik.com/premium-photo/vehicles-coal-mine-view_575980-17906.jpg',

      'total_dumpers': 128,
      'moving': 94,
      'on_hold': 14,
      'maintenance': 20,
    };
  }
}