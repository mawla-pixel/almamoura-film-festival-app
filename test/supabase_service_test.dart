import 'package:flutter_test/flutter_test.dart';

import 'package:almamoura_film_festival/services/supabase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Supabase uses the configured project', () {
    expect(SupabaseService.isConfigured, isTrue);
  });
}
