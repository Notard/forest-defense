/// 웹이 아닌 곳: 쓰지 않는다 (SoundBoard가 flame_audio로 낸다).
class WebSfx {
  static bool get available => false;
  static Future<void> load(Map<String, String> assets) async {}
  static void play(String name, double volume) {}
}
