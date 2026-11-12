import 'package:flutter/material.dart';

/// 窗口比手机大时，把界面收进 390×844 的 iPhone 画布；真机上铺满屏幕。
class IphoneFrame extends StatelessWidget {
  const IphoneFrame({super.key, required this.child});

  final Widget child;

  static const _width = 390.0;
  static const _height = 844.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 520 || constraints.maxHeight > 920;
        if (!wide) return child;

        final media = MediaQuery.of(context);
        return ColoredBox(
          color: const Color(0xFF0B0F14),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(44),
              child: SizedBox(
                width: _width,
                height: _height,
                child: MediaQuery(
                  data: media.copyWith(
                    size: const Size(_width, _height),
                    padding: const EdgeInsets.only(top: 54, bottom: 28),
                    viewPadding: const EdgeInsets.only(top: 54, bottom: 28),
                  ),
                  child: Stack(
                    children: [
                      child,
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _StatusBar(),
                      ),
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 8,
                        child: _HomeIndicator(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return IgnorePointer(
      child: SizedBox(
        height: 54,
        child: Padding(
          padding: const EdgeInsets.only(left: 28, right: 22, top: 14),
          child: Row(
            children: [
              Text(
                '$hh:$mm',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              const Icon(Icons.signal_cellular_alt, size: 16),
              const SizedBox(width: 4),
              const Icon(Icons.wifi, size: 16),
              const SizedBox(width: 4),
              const Icon(Icons.battery_full, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeIndicator extends StatelessWidget {
  const _HomeIndicator();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 128,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}
