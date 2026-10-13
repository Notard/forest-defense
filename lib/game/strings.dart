/// 화면에 나오는 모든 문구. 글자를 고칠 때는 여기만 바꾼다.
///
/// 폰트(Gaegu Bold)는 필요한 글자만 남긴 파일이라, 새 문구를 넣으면
/// `python tools/subset_font.py <원본 경로>`로 폰트를 다시 만들어야 한다.
/// `test/font_coverage_test.dart`가 빠진 글자를 찾아 준다.
abstract final class Strings {
  static const title = '숲 지키기';

  static String wave(int current, int total) => '웨이브 $current / $total';

  /// 웨이브가 시작될 때 가운데에 잠깐 뜨는 글자.
  static String waveBanner(int number) => '웨이브 $number';

  /// 마지막 큰 무리 웨이브 경고.
  static const bigWave = '큰 무리가 몰려와요!';
}
