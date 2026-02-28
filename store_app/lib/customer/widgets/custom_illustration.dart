import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum IllustrationType {
  emptyCart,
  emptyOrders,
}

class CustomIllustration extends StatelessWidget {
  final IllustrationType type;
  final double size;

  const CustomIllustration({
    super.key,
    required this.type,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final primaryColor = kPrimaryBlue;
    final accentColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final bgColor = primaryColor.withOpacity(0.1);

    switch (type) {
      case IllustrationType.emptyCart:
        return _buildStack(
          icon: Icons.shopping_cart_outlined,
          secondaryIcon: Icons.add_shopping_cart,
          primaryColor: primaryColor,
          accentColor: accentColor,
          bgColor: bgColor,
        );
      case IllustrationType.emptyOrders:
        return _buildStack(
          icon: Icons.receipt_long_outlined,
          secondaryIcon: Icons.history,
          primaryColor: primaryColor,
          accentColor: accentColor,
          bgColor: bgColor,
        );
    }
  }

  Widget _buildStack({
    required IconData icon,
    required IconData secondaryIcon,
    required Color primaryColor,
    required Color accentColor,
    required Color bgColor,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Circle
          Container(
            width: size * 0.8,
            height: size * 0.8,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
          ),
          // Subtle Dots/Circles for tech/professional look
          ...List.generate(3, (index) {
            double offset = (index + 1) * 20.0;
            return Positioned(
              right: index.isEven ? offset : null,
              left: index.isOdd ? offset : null,
              top: index * 40.0,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
          // Main Icon
          Icon(
            icon,
            size: size * 0.45,
            color: primaryColor,
          ),
          // Secondary Floated Icon
          Positioned(
            right: size * 0.2,
            bottom: size * 0.25,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                secondaryIcon,
                size: size * 0.12,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
