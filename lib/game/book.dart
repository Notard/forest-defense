import 'package:url_launcher/url_launcher.dart';

/// 메인 화면 책 소개 (14-3단계): 이 게임을 만든 사람이 쓴 책과 서점 링크.
abstract final class Book {
  static const stores = [
    (name: '예스24', url: 'https://www.yes24.com/product/goods/197774521'),
    (name: '교보문고', url: 'https://product.kyobobook.co.kr/detail/S000221582195'),
    (name: '알라딘', url: 'https://www.aladin.co.kr/shop/wproduct.aspx?ItemId=403862833'),
  ];
}

/// 브라우저(웹은 새 탭)로 연다. 열지 못하면 false.
Future<bool> openLink(String url) async {
  try {
    return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
  } catch (_) {
    return false;
  }
}
