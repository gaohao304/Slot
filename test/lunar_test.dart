import 'package:flutter_test/flutter_test.dart';
import 'package:slot/utils/lunar_calendar.dart';

void main() {
  test('2024 春节是正月初一', () {
    final lunar = solarToLunar(DateTime(2024, 2, 10));
    expect(lunar.month, 1);
    expect(lunar.day, 1);
    expect(lunar.isLeap, isFalse);
    expect(lunar.cellLabel, '正月');
  });

  test('2025 春节是正月初一', () {
    final lunar = solarToLunar(DateTime(2025, 1, 29));
    expect(lunar.month, 1);
    expect(lunar.day, 1);
    expect(lunar.cellLabel, '正月');
  });

  test('2026 春节是正月初一', () {
    final lunar = solarToLunar(DateTime(2026, 2, 17));
    expect(lunar.month, 1);
    expect(lunar.day, 1);
    expect(lunar.cellLabel, '正月');
  });

  test('初二显示日名', () {
    final lunar = solarToLunar(DateTime(2026, 2, 18));
    expect(lunar.day, 2);
    expect(lunar.cellLabel, '初二');
  });
}
