import 'package:cap/cap.dart';
import 'package:test/test.dart';

void main() {
  group('WordCap', () {
    test('fromWord', () {
      expect(WordCap.fromWord('HE8ll912o'), equals(WordCap.title));
      expect(WordCap.fromWord('he8ll912o'), equals(WordCap.lower));
      expect(WordCap.fromWord('HE8LL912O'), equals(WordCap.upper));
      expect(WordCap.fromWord('HE8ll91oO'), equals(WordCap.mixed));
      expect(WordCap.fromWord('891?/8'),    equals(WordCap.none));
    });
  });
}
