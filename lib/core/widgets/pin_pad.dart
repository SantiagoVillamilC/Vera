import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vera/core/theme/app_theme.dart';

class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.length, required this.filled});

  final int length;
  final int filled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final isFilled = i < filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: isFilled ? 16 : 14,
          height: isFilled ? 16 : 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isFilled ? AppGradients.brand : null,
            color: isFilled ? null : AppColors.surfaceVariant,
            border: isFilled
                ? null
                : Border.all(color: AppColors.border, width: 1.5),
            boxShadow: isFilled
                ? [
                    BoxShadow(
                      color: AppColors.gradientMid.withAlpha(100),
                      blurRadius: 8,
                    )
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

class NumPad extends StatelessWidget {
  const NumPad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    this.onBiometric,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onBiometric;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRow(['1', '2', '3']),
        const SizedBox(height: 16),
        _buildRow(['4', '5', '6']),
        const SizedBox(height: 16),
        _buildRow(['7', '8', '9']),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _BiometricKey(onBiometric: onBiometric),
            const SizedBox(width: 20),
            _NumKey(label: '0', onTap: () => onDigit('0')),
            const SizedBox(width: 20),
            _DeleteKey(onDelete: onDelete),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.asMap().entries.map((e) {
        return Padding(
          padding: EdgeInsets.only(right: e.key < 2 ? 20 : 0),
          child: _NumKey(label: e.value, onTap: () => onDigit(e.value)),
        );
      }).toList(),
    );
  }
}

class _NumKey extends StatelessWidget {
  const _NumKey({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(38),
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceVariant,
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w300,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteKey extends StatelessWidget {
  const _DeleteKey({required this.onDelete});
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onDelete();
        },
        borderRadius: BorderRadius.circular(38),
        child: Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: const Icon(
            Icons.backspace_outlined,
            color: AppColors.textSecondary,
            size: 26,
          ),
        ),
      ),
    );
  }
}

class _BiometricKey extends StatelessWidget {
  const _BiometricKey({this.onBiometric});
  final VoidCallback? onBiometric;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onBiometric,
        borderRadius: BorderRadius.circular(38),
        child: Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: Icon(
            Icons.fingerprint_rounded,
            color: onBiometric != null ? AppColors.gradientStart : AppColors.textMuted,
            size: 34,
          ),
        ),
      ),
    );
  }
}
