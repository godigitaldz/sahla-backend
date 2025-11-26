import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../utils/responsive_sizing.dart';

/// Best Choices section title widget with navigation
///
/// Displays the "Best Choices" title with "Explore More" text (without parentheses) and arrow
/// Taps navigate to the menu items list screen
class BestChoicesTitle extends StatelessWidget {
  const BestChoicesTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: MediaQuery.of(context).padding.left,
        right: MediaQuery.of(context).padding.right,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: MediaQuery.of(context).padding.left + 16,
          right: MediaQuery.of(context).padding.right + 8,
          bottom: 8,
        ),
        child: GestureDetector(
          onTap: () async {
            await Navigator.of(context).pushNamed("/menu-items-list");
          },
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: <Widget>[
              Image.asset(
                Localizations.localeOf(context).languageCode == 'ar'
                    ? 'assets/icon/bestchoices_ar.png'
                    : 'assets/icon/bestchoices_en.png',
                height: ResponsiveSizing.fontSize(31.5, context),
                fit: BoxFit.contain,
              ),
              const Spacer(),
              Text(
                Localizations.localeOf(context).languageCode == 'ar'
                    ? 'استكشف المزيد'
                    : Localizations.localeOf(context).languageCode == 'fr'
                        ? 'Explorer plus'
                        : 'Explore More',
                style: GoogleFonts.inter(
                  fontSize: ResponsiveSizing.fontSize(13, context),
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
                textDirection: Directionality.of(context),
              ),
              const SizedBox(width: 8),
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.keyboard_arrow_left
                    : Icons.keyboard_arrow_right,
                size: ResponsiveSizing.fontSize(16, context) * 1,
                color: Colors.grey.shade600,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
