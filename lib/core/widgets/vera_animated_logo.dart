import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vera/core/theme/app_theme.dart';

class VeraAnimatedLogo extends StatefulWidget {
  const VeraAnimatedLogo({super.key});

  @override
  State<VeraAnimatedLogo> createState() => _VeraAnimatedLogoState();
}

class _VeraAnimatedLogoState extends State<VeraAnimatedLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  // Entry
  late Animation<double> _entryOpacity;
  late Animation<double> _entryScale;

  // Accordion — cards fan open then close, continuously
  late Animation<double> _backAngle;
  late Animation<double> _frontAngle;
  late Animation<double> _backOffsetX;
  late Animation<double> _frontOffsetX;

  // Float
  late Animation<double> _float;
  late Animation<double> _shadowScale;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    // ── Entry (0→15%) ──────────────────────────────
    _entryOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.1, curve: Curves.easeOut),
      ),
    );
    _entryScale = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.18, curve: Curves.elasticOut),
      ),
    );

    // ── Accordion (runs full loop after entry, min=0.2) ──
    // Back card fans out counterclockwise (left)
    _backAngle = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: -0.22, end: -0.68)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: ConstantTween(-0.68),
        weight: 8,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.68, end: -0.22)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: ConstantTween(-0.22),
        weight: 12,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.18, 1.0),
      ),
    );

    // Front card fans out clockwise (right)
    _frontAngle = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: -0.22, end: 0.24)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: ConstantTween(0.24),
        weight: 8,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.24, end: -0.22)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: ConstantTween(-0.22),
        weight: 12,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.18, 1.0),
      ),
    );

    // Back card drifts left as it fans
    _backOffsetX = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -16.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
      TweenSequenceItem(tween: ConstantTween(-16.0), weight: 8),
      TweenSequenceItem(
        tween: Tween(begin: -16.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 12),
    ]).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.18, 1.0)),
    );

    // Front card drifts right as it fans
    _frontOffsetX = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 16.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
      TweenSequenceItem(tween: ConstantTween(16.0), weight: 8),
      TweenSequenceItem(
        tween: Tween(begin: 16.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 12),
    ]).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.18, 1.0)),
    );

    // Subtle float
    _float = Tween<double>(begin: 0.0, end: -8.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _shadowScale = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );

    _ctrl.forward().then((_) {
      _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Opacity(
          opacity: _entryOpacity.value,
          child: Transform.scale(
            scale: _entryScale.value,
            child: Transform.translate(
              offset: Offset(0, _float.value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 140,
                    height: 130,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Glow shadow
                        Positioned(
                          bottom: 4,
                          child: Container(
                            width: 80 * _shadowScale.value,
                            height: 12,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.gradientMid.withAlpha(80),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Back card
                        Transform.translate(
                          offset: Offset(_backOffsetX.value, 0),
                          child: Transform.rotate(
                            angle: _backAngle.value,
                            child: _Card(
                              width: 80,
                              height: 54,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1E2354), Color(0xFF141740)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              showDot: false,
                              shadowColor: Colors.black.withAlpha(60),
                            ),
                          ),
                        ),

                        // Middle card (static, always behind front)
                        Transform.rotate(
                          angle: -0.22,
                          child: _Card(
                            width: 80,
                            height: 54,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4A3FA0), Color(0xFF3730A3)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            showDot: false,
                            shadowColor: AppColors.gradientEnd.withAlpha(40),
                          ),
                        ),

                        // Front card
                        Transform.translate(
                          offset: Offset(_frontOffsetX.value, 0),
                          child: Transform.rotate(
                            angle: _frontAngle.value,
                            child: _Card(
                              width: 80,
                              height: 54,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFAB9FF8), Color(0xFF7B6FE8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              showDot: true,
                              shadowColor: AppColors.gradientMid.withAlpha(100),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'vera',
                    style: GoogleFonts.playfairDisplay(
                      color: AppColors.textPrimary,
                      fontSize: 52,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'billetera digital',
                    style: GoogleFonts.playfairDisplay(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.width,
    required this.height,
    required this.gradient,
    required this.showDot,
    required this.shadowColor,
  });

  final double width;
  final double height;
  final Gradient gradient;
  final bool showDot;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Top gloss
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: height * 0.42,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withAlpha(28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          if (showDot)
            Positioned(
              top: height * 0.22,
              left: width * 0.36,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withAlpha(80),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Compact icon version for other screens
class VeraCardIcon extends StatefulWidget {
  const VeraCardIcon({super.key, this.size = 56.0});
  final double size;

  @override
  State<VeraCardIcon> createState() => _VeraCardIconState();
}

class _VeraCardIconState extends State<VeraCardIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _backAngle;
  late Animation<double> _frontAngle;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _backAngle = Tween<double>(begin: -0.22, end: -0.62)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    _frontAngle = Tween<double>(begin: -0.22, end: 0.18)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final cardW = s * 0.72;
    final cardH = s * 0.49;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return SizedBox(
          width: s,
          height: s,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: _backAngle.value,
                child: _Card(
                  width: cardW,
                  height: cardH,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E2354), Color(0xFF141740)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  showDot: false,
                  shadowColor: Colors.black.withAlpha(50),
                ),
              ),
              Transform.rotate(
                angle: _frontAngle.value,
                child: _Card(
                  width: cardW,
                  height: cardH,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFAB9FF8), Color(0xFF7B6FE8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  showDot: true,
                  shadowColor: AppColors.gradientMid.withAlpha(80),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
