import 'package:flutter_test/flutter_test.dart';
import 'package:savorsync/core/services/api_service.dart';

void main() {
  test('API configuration rejects empty URLs and embeds no credentials', () {
    expect(ApiService.isValidBaseUrl(''), isFalse);
    expect(ApiService.isValidBaseUrl('https://user:pass@example.test/api/v1'), isFalse);
    expect(ApiService.isValidBaseUrl('https://example.test/api/v1?token=x'), isFalse);
    expect(ApiService.isValidBaseUrl('https://example.test/other'), isFalse);
    expect(ApiService.isValidBaseUrl('http://example.test/api/v1'), isFalse);
    expect(ApiService.isValidBaseUrl('https://example.test/api/v1'), isTrue);
  });
}
