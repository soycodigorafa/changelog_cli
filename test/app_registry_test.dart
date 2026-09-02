import 'package:changelog_cli/src/app_registry.dart';
import 'package:test/test.dart';

void main() {
  test('tagFormatFor matches the bash APP_FORMAT transform', () {
    expect(tagFormatFor('zz_sample'), 'ZZ_Sample');
    expect(tagFormatFor('yy_demo'), 'YY_Demo');
    expect(tagFormatFor('xx_widget'), 'XX_Widget');
  });
}
