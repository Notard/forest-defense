import 'package:flutter/material.dart';

import 'game/config.dart';
import 'game/strings.dart';

/// 화면이 세로로 길면(휴대폰을 세워 들면) 게임 위에 "가로로 돌려 주세요"를 덮는다 (15단계).
/// 설치한 PWA는 매니페스트가 가로로 고정하지만, 브라우저 탭과 창 크기를 바꾼 Windows 창은 세로가 될 수 있다.
/// 세로가 되는 순간 [onPortrait]를 부른다 (판이면 일시정지).
class PortraitGuard extends StatefulWidget {
  const PortraitGuard({super.key, required this.child, this.onPortrait});

  final Widget child;
  final VoidCallback? onPortrait;

  /// 세로로 보는 화면: 높이가 너비보다 길다.
  static bool isPortrait(Size s) => s.height > s.width;

  @override
  State<PortraitGuard> createState() => _PortraitGuardState();
}

class _PortraitGuardState extends State<PortraitGuard> {
  bool _wasPortrait = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final portrait = PortraitGuard.isPortrait(c.biggest);
      if (portrait && !_wasPortrait) {
        WidgetsBinding.instance.addPostFrameCallback((_) => widget.onPortrait?.call());
      }
      _wasPortrait = portrait;
      return Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (portrait)
            ColoredBox(
              color: const Color(0xF21F3A1A),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.screen_rotation, size: 72, color: Color(0xFFFFE6A8)),
                    const SizedBox(height: 20),
                    Text(
                      Strings.rotate,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: GameConfig.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 30,
                        color: Color(0xFFFFF4DC),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}
