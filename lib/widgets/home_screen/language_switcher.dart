import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:google_fonts/google_fonts.dart";
import "package:provider/provider.dart";

import "../../l10n/app_localizations.dart";
import "../../services/language_preference_service.dart";

/// Language switcher constants for maintainability
class LanguageSwitcherConstants {
  static const double containerSize = 37.5;
  static const double borderRadius = 18.75;
  static const double flagFontSize = 15;
  static const double dropdownWidth = 200;
  static const double dropdownItemHeight = 50;
  static const Duration animationDuration = Duration(milliseconds: 200);

  static const Map<String, Map<String, String>> supportedLanguages = {
    "en": {"name": "English", "flag": "🇺🇸", "localizedKey": "english"},
    "ar": {"name": "العربية", "flag": "🇩🇿", "localizedKey": "arabic"},
    "fr": {"name": "Français", "flag": "🇫🇷", "localizedKey": "french"},
  };
}

/// Dropdown position calculator for better positioning logic
class DropdownPositionCalculator {
  static OverlayEntry createDropdownEntry({
    required BuildContext context,
    required GlobalKey anchorKey,
    required WidgetBuilder builder,
  }) {
    final renderBox =
        anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      throw Exception("Anchor not found");
    }

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenSize = MediaQuery.of(context).size;

    return OverlayEntry(
      builder: (context) => Positioned(
        left: _calculateHorizontalPosition(position, size, screenSize, context),
        top: _calculateVerticalPosition(position, size, screenSize),
        child: builder(context),
      ),
    );
  }

  static double _calculateHorizontalPosition(
      Offset position, Size size, Size screenSize, BuildContext context) {
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    const dropdownWidth = LanguageSwitcherConstants.dropdownWidth;

    if (isRTL) {
      return (position.dx + size.width - dropdownWidth)
          .clamp(8.0, screenSize.width - dropdownWidth - 8.0);
    } else {
      return position.dx.clamp(8.0, screenSize.width - dropdownWidth - 8.0);
    }
  }

  static double _calculateVerticalPosition(
      Offset position, Size size, Size screenSize) {
    const dropdownHeight =
        200.0; // Approximate height for 3 items (3 languages)

    // Check if there"s enough space below the button
    if (position.dy + size.height + 8 + dropdownHeight < screenSize.height) {
      // Open downward
      return position.dy + size.height + 8;
    } else {
      // Open upward
      return position.dy - dropdownHeight - 8;
    }
  }
}

/// Analytics service for language switcher interactions
class LanguageSwitcherAnalyticsService {
  static void logEvent(String eventName, Map<String, dynamic> parameters) {
    // In a real implementation, this would send to Firebase Analytics, Mixpanel, etc.
    debugPrint("🌐 LanguageSwitcher Analytics: $eventName - $parameters");
  }
}

class LanguageSwitcher extends StatefulWidget {
  const LanguageSwitcher({
    super.key,
    this.onLanguageChanged,
  });

  final VoidCallback? onLanguageChanged;

  @override
  State<LanguageSwitcher> createState() => _LanguageSwitcherState();
}

class _LanguageSwitcherState extends State<LanguageSwitcher>
    with SingleTickerProviderStateMixin {
  final GlobalKey _anchorKey = GlobalKey();
  bool _menuOpen = false;
  OverlayEntry? _overlayEntry;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: LanguageSwitcherConstants.animationDuration,
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    // Clean up overlay entry if it exists
    _overlayEntry?.remove();
    _overlayEntry = null;

    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<LanguagePreferenceService, String>(
      selector: (context, languageService) => languageService.currentLanguage,
      builder: (context, currentLanguageCode, child) {
        final flag = _getLanguageFlag(currentLanguageCode);
        final languageName = _getLanguageName(currentLanguageCode);

        return Semantics(
          label: "Language switcher, current language: $languageName",
          hint: "Double tap to change language",
          button: true,
          child: GestureDetector(
            key: _anchorKey,
            onTap: _toggleMenu,
            child: Container(
              width: LanguageSwitcherConstants.containerSize,
              height: LanguageSwitcherConstants.containerSize,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                    LanguageSwitcherConstants.borderRadius),
              ),
              child: Center(
                child: AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _menuOpen ? _scaleAnimation.value : 1.0,
                      child: Text(
                        flag,
                        style: const TextStyle(
                            fontSize: LanguageSwitcherConstants.flagFontSize),
                        semanticsLabel:
                            "", // Hide flag from semantics since we have the label above
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getLanguageFlag(String languageCode) {
    try {
      final language =
          LanguageSwitcherConstants.supportedLanguages[languageCode];
      if (language != null) {
        return language["flag"]!;
      }

      // Fallback for unsupported languages
      debugPrint("⚠️ Unsupported language code: $languageCode");
      return "🌐"; // Globe emoji as fallback
    } on Exception catch (e) {
      debugPrint("❌ Error getting language flag: $e");
      return "🌐"; // Globe emoji as fallback
    }
  }

  String _getLanguageName(String languageCode) {
    try {
      final language =
          LanguageSwitcherConstants.supportedLanguages[languageCode];
      if (language != null) {
        return language["name"]!;
      }

      // Fallback for unsupported languages
      debugPrint("⚠️ Unsupported language code: $languageCode");
      return "English"; // Default fallback
    } on Exception catch (e) {
      debugPrint("❌ Error getting language name: $e");
      return "English"; // Default fallback
    }
  }

  Future<void> _toggleMenu() async {
    // Provide haptic feedback
    await HapticFeedback.lightImpact();

    if (_menuOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    setState(() {
      _menuOpen = true;
    });

    // Start animation
    _animationController.forward();

    // Ensure the widget is laid out before accessing RenderBox
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final overlayEntry = DropdownPositionCalculator.createDropdownEntry(
          context: context,
          anchorKey: _anchorKey,
          builder: (context) => Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            elevation: 4,
            child: Container(
              width: LanguageSwitcherConstants.dropdownWidth,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _getLanguageOptions(),
              ),
            ),
          ),
        );

        // Store overlay entry reference
        _overlayEntry = overlayEntry;

        // Show custom dropdown overlay
        Overlay.of(context).insert(overlayEntry);

        // Handle dismissal
        GestureDetector(
          onTap: _closeMenu,
          child: Container(color: Colors.transparent),
        );
      } on Exception catch (e) {
        debugPrint("❌ Error opening language menu: $e");
        setState(() {
          _menuOpen = false;
        });
      }
    });
  }

  void _closeMenu() {
    // Remove overlay entry if it exists
    _overlayEntry?.remove();
    _overlayEntry = null;

    // Reverse animation and then close menu
    _animationController.reverse().then((_) {
      setState(() {
        _menuOpen = false;
      });
    });
  }

  List<Widget> _getLanguageOptions() {
    const languages = LanguageSwitcherConstants.supportedLanguages;

    return languages.entries.map((entry) {
      final languageCode = entry.key;
      final languageData = entry.value;

      return Column(
        children: [
          _buildLanguageOption(languageCode, languageData),
          if (languageCode != languages.keys.last)
            Container(
              height: 1,
              color: Colors.grey.withValues(alpha: 0.1),
              margin: const EdgeInsets.symmetric(horizontal: 8),
            ),
        ],
      );
    }).toList();
  }

  Widget _buildLanguageOption(
      String languageCode, Map<String, String> languageData) {
    final languageService = context.read<LanguagePreferenceService>();
    final currentLanguage = languageService.currentLanguage;
    final isRTL = currentLanguage == "ar";
    final localizations = AppLocalizations.of(context);

    return Container(
      height: LanguageSwitcherConstants.dropdownItemHeight,
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 1),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            // Haptic feedback for language selection
            await HapticFeedback.selectionClick();

            try {
              // Validate the locale is supported
              if (!LanguageSwitcherConstants.supportedLanguages
                  .containsKey(languageCode)) {
                throw Exception("Unsupported language: $languageCode");
              }

              // Log analytics event
              LanguageSwitcherAnalyticsService.logEvent("language_selected", {
                "previous_language": currentLanguage,
                "new_language": languageCode,
                "source": "dropdown_menu",
              });

              // Change language preference
              await _changeLanguagePreference(languageCode);

              // Close the menu after language change
              _closeMenu();
            } on Exception catch (e) {
              debugPrint("❌ Error changing language: $e");
              _showErrorFeedback();
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isRTL ? 8 : 16,
              vertical: 12,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment:
                  isRTL ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (isRTL) ...[
                  Text(
                    localizations != null
                        ? _getLocalizedLanguageName(languageCode, localizations)
                        : languageData["name"]!,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF424242),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    languageData["flag"]!,
                    style: const TextStyle(fontSize: 16),
                  ),
                ] else ...[
                  Text(
                    languageData["flag"]!,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    localizations != null
                        ? _getLocalizedLanguageName(languageCode, localizations)
                        : languageData["name"]!,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF424242),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getLocalizedLanguageName(
      String code, AppLocalizations localizations) {
    try {
      final language = LanguageSwitcherConstants.supportedLanguages[code];
      if (language != null) {
        switch (code) {
          case "en":
            return localizations.english;
          case "ar":
            return localizations.arabic;
          case "fr":
            return localizations.french;
          default:
            return language["name"]!;
        }
      }

      // Fallback for unsupported languages
      debugPrint("⚠️ Unsupported language code for localization: $code");
      return "English";
    } on Exception catch (e) {
      debugPrint("❌ Error getting localized language name: $e");
      return "English";
    }
  }

  Future<void> _changeLanguagePreference(String languageCode) async {
    try {
      final languageService = context.read<LanguagePreferenceService>();

      // Log analytics event before changing language
      LanguageSwitcherAnalyticsService.logEvent("language_change_attempted", {
        "previous_language": languageService.currentLanguage,
        "new_language": languageCode,
        "source": "dropdown_selection",
      });

      // Update language preference in user profile
      final success = await languageService.setLanguage(languageCode);

      if (success) {
        // Call the callback if provided
        widget.onLanguageChanged?.call();

        // Show success feedback
        _showSuccessFeedback(Locale(languageCode));
      } else {
        _showErrorFeedback();
      }
    } on Exception catch (e) {
      debugPrint("❌ Error changing language preference: $e");
      _showErrorFeedback();
    }
  }

  void _showSuccessFeedback(Locale newLocale) {
    final localizations = AppLocalizations.of(context);
    if (localizations != null && context.mounted) {
      final languageName =
          _getLocalizedLanguageName(newLocale.languageCode, localizations);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Language changed to $languageName",
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          backgroundColor: const Color(0xFFd47b00),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  void _showErrorFeedback() {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Failed to change language. Please try again."),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }
}
