class LocalizationService {
  static const Map<String, Map<String, String>> _translations = {
    'en': {
      // App General
      'app_name': 'Sahla',
      'welcome': 'Welcome',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'retry': 'Retry',
      'cancel': 'Cancel',
      'ok': 'OK',
      'yes': 'Yes',
      'no': 'No',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'add': 'Add',
      'search': 'Search',
      'filter': 'Filter',
      'sort': 'Sort',
      'back': 'Back',
      'next': 'Next',
      'continue': 'Continue',
      'done': 'Done',
      'close': 'Close',

      // Navigation
      'home': 'Home',
      'search_tab': 'Search',
      'saved': 'Saved',
      'bookings': 'Bookings',
      'more': 'More',

      // Authentication
      'sign_in': 'Sign In',
      'sign_up': 'Sign Up',
      'sign_out': 'Sign Out',
      'email': 'Email',
      'password': 'Password',
      'confirm_password': 'Confirm Password',
      'forgot_password': 'Forgot Password?',
      'remember_me': 'Remember Me',
      'create_account': 'Create Account',
      'already_have_account': 'Already have an account?',
      'dont_have_account': "Don't have an account?",

      // Admin
      'admin_dashboard': 'Admin Dashboard',
      'car_approval': 'Car Approval',
      'pending_approval': 'Pending Approval',
      'approved_cars': 'Approved Cars',
      'rejected_cars': 'Rejected Cars',
      'approve': 'Approve',
      'reject': 'Reject',
      'approval_reason': 'Approval Reason',
      'rejection_reason': 'Rejection Reason',

      // Profile & Settings
      'profile': 'Profile',
      'edit_profile': 'Edit Profile',
      'settings': 'Settings',
      'language': 'Language',
      'currency': 'Currency',
      'notifications': 'Notifications',
      'location': 'Location Services',
      'analytics': 'Analytics & Data',
      'theme': 'Theme',
      'dark_mode': 'Dark Mode',
      'privacy': 'Privacy',
      'about': 'About',
      'version': 'Version',
      'support': 'Support',
      'terms': 'Terms of Service',
      'privacy_policy': 'Privacy Policy',

      // Favorites
      'favorites': 'Favorites',
      'add_to_favorites': 'Add to Favorites',
      'remove_from_favorites': 'Remove from Favorites',
      'no_favorites': 'No favorites yet',

      // Payments
      'payment': 'Payment',
      'payment_methods': 'Payment Methods',
      'add_payment_method': 'Add Payment Method',
      'credit_card': 'Credit Card',
      'debit_card': 'Debit Card',
      'paypal': 'PayPal',
      'total_amount': 'Total Amount',
      'pay_now': 'Pay Now',

      // Notifications
      'notification': 'Notification',
      'no_notifications': 'No notifications',
      'mark_as_read': 'Mark as Read',
      'clear_all': 'Clear All',

      // Error Messages
      'error_network': 'Network error. Please check your connection.',
      'error_server': 'Server error. Please try again later.',
      'error_authentication': 'Authentication failed. Please sign in again.',
      'error_permission': 'Permission denied.',
      'error_location': 'Location access denied.',
      'error_camera': 'Camera access denied.',
      'error_storage': 'Storage access denied.',

      // Success Messages
      'success_login': 'Successfully signed in!',
      'success_logout': 'Successfully signed out!',
      'success_booking': 'Booking confirmed!',
      'success_cancel': 'Booking cancelled!',
      'success_profile_update': 'Profile updated successfully!',
      'success_car_added': 'Car added successfully!',

      // Empty States
      'no_cars_available': 'No cars available',
      'no_bookings': 'No bookings yet',
      'no_search_results': 'No search results found',
      'no_internet': 'No internet connection',

      // Demo & Testing
      'multilingual_demo': 'Multilingual Demo',
      'demo_content': 'Demo Content',
      'language_changed': 'Language changed successfully!',
      'rtl_demo': 'RTL Support Demo',
      'rtl_notice':
          'This app supports right-to-left text direction for Arabic.',
      'test_localization': 'Test Localization',
      'test_dialog_title': 'Localization Test',
      'test_dialog_content':
          'This dialog demonstrates localized text in action.',
      'test_completed': 'Localization test completed!',

      // Currency Converter
      'currency_converter': 'Currency Converter',
      'exchange_rate': 'Exchange Rate',
      'quick_amounts': 'Quick Amounts',
      'popular_conversions': 'Popular Conversions',
      'rate_history': 'Rate History',
      'chart_placeholder': 'Rate chart coming soon',
      'select_currency': 'Select Currency',
      'from_currency': 'From Currency',
      'to_currency': 'To Currency',
      'amount': 'Amount',
      'converted_amount': 'Converted Amount',
      'exchange_rates': 'Exchange Rates',
      'last_updated': 'Last Updated',
    },
    'fr': {
      // App General
      'app_name': 'Sahla',
      'welcome': 'Bienvenue',
      'loading': 'Chargement...',
      'error': 'Erreur',
      'success': 'Succès',
      'retry': 'Réessayer',
      'cancel': 'Annuler',
      'ok': 'OK',
      'yes': 'Oui',
      'no': 'Non',
      'save': 'Enregistrer',
      'delete': 'Supprimer',
      'edit': 'Modifier',
      'add': 'Ajouter',
      'search': 'Rechercher',
      'filter': 'Filtrer',
      'sort': 'Trier',
      'back': 'Retour',
      'next': 'Suivant',
      'continue': 'Continuer',
      'done': 'Terminé',
      'close': 'Fermer',

      // Navigation
      'home': 'Accueil',
      'search_tab': 'Recherche',
      'saved': 'Enregistrés',
      'bookings': 'Réservations',
      'more': 'Plus',

      // Authentication
      'sign_in': 'Se connecter',
      'sign_up': "S'inscrire",
      'sign_out': 'Se déconnecter',
      'email': 'Email',
      'password': 'Mot de passe',
      'confirm_password': 'Confirmer le mot de passe',
      'forgot_password': 'Mot de passe oublié?',
      'remember_me': 'Se souvenir de moi',
      'create_account': 'Créer un compte',
      'already_have_account': 'Vous avez déjà un compte?',
      'dont_have_account': "Vous n'avez pas de compte?",

      // Admin
      'admin_dashboard': 'Tableau de bord admin',
      'car_approval': 'Approbation de voiture',
      'pending_approval': 'En attente d\'approbation',
      'approved_cars': 'Voitures approuvées',
      'rejected_cars': 'Voitures rejetées',
      'approve': 'Approuver',
      'reject': 'Rejeter',
      'approval_reason': "Raison d'approbation",
      'rejection_reason': 'Raison du rejet',

      // Profile & Settings
      'profile': 'Profil',
      'edit_profile': 'Modifier le profil',
      'settings': 'Paramètres',
      'language': 'Langue',
      'currency': 'Devise',
      'notifications': 'Notifications',
      'location': 'Services de localisation',
      'analytics': 'Analyses et données',
      'theme': 'Thème',
      'dark_mode': 'Mode sombre',
      'privacy': 'Confidentialité',
      'about': 'À propos',
      'version': 'Version',
      'support': 'Support',
      'terms': 'Conditions de service',
      'privacy_policy': 'Politique de confidentialité',

      // Favorites
      'favorites': 'Favoris',
      'add_to_favorites': 'Ajouter aux favoris',
      'remove_from_favorites': 'Retirer des favoris',
      'no_favorites': 'Aucun favori pour le moment',

      // Payments
      'payment': 'Paiement',
      'payment_methods': 'Méthodes de paiement',
      'add_payment_method': 'Ajouter une méthode de paiement',
      'credit_card': 'Carte de crédit',
      'debit_card': 'Carte de débit',
      'paypal': 'PayPal',
      'total_amount': 'Montant total',
      'pay_now': 'Payer maintenant',

      // Notifications
      'notification': 'Notification',
      'no_notifications': 'Aucune notification',
      'mark_as_read': 'Marquer comme lu',
      'clear_all': 'Tout effacer',

      // Error Messages
      'error_network': 'Erreur réseau. Vérifiez votre connexion.',
      'error_server': 'Erreur serveur. Réessayez plus tard.',
      'error_authentication':
          'Échec de l\'authentification. Connectez-vous à nouveau.',
      'error_permission': 'Permission refusée.',
      'error_location': 'Accès à la localisation refusé.',
      'error_camera': 'Accès à la caméra refusé.',
      'error_storage': 'Accès au stockage refusé.',

      // Success Messages
      'success_login': 'Connexion réussie!',
      'success_logout': 'Déconnexion réussie!',
      'success_booking': 'Réservation confirmée!',
      'success_cancel': 'Réservation annulée!',
      'success_profile_update': 'Profil mis à jour avec succès!',
      'success_car_added': 'Voiture ajoutée avec succès!',

      // Empty States
      'no_cars_available': 'Aucune voiture disponible',
      'no_bookings': 'Aucune réservation pour le moment',
      'no_search_results': 'Aucun résultat trouvé',
      'no_internet': 'Pas de connexion internet',

      // Demo & Testing
      'multilingual_demo': 'Démo Multilingue',
      'demo_content': 'Contenu de Démonstration',
      'language_changed': 'Langue changée avec succès!',
      'rtl_demo': 'Démo Support RTL',
      'rtl_notice':
          'Cette application prend en charge la direction de texte de droite à gauche pour l\'arabe.',
      'test_localization': 'Tester la Localisation',
      'test_dialog_title': 'Test de Localisation',
      'test_dialog_content':
          'Cette boîte de dialogue démontre le texte localisé en action.',
      'test_completed': 'Test de localisation terminé!',

      // Currency Converter
      'currency_converter': 'Convertisseur de Devises',
      'exchange_rate': 'Taux de Change',
      'quick_amounts': 'Montants Rapides',
      'popular_conversions': 'Conversions Populaires',
      'rate_history': 'Historique des Taux',
      'chart_placeholder': 'Graphique des taux bientôt disponible',
      'select_currency': 'Sélectionner la Devise',
      'from_currency': 'Devise Source',
      'to_currency': 'Devise Cible',
      'amount': 'Montant',
      'converted_amount': 'Montant Converti',
      'exchange_rates': 'Taux de Change',
      'last_updated': 'Dernière Mise à Jour',
    },
    'ar': {
      // App General
      'app_name': 'سهلة',
      'welcome': 'مرحباً',
      'loading': 'جاري التحميل...',
      'error': 'خطأ',
      'success': 'نجح',
      'retry': 'إعادة المحاولة',
      'cancel': 'إلغاء',
      'ok': 'موافق',
      'yes': 'نعم',
      'no': 'لا',
      'save': 'حفظ',
      'delete': 'حذف',
      'edit': 'تعديل',
      'add': 'إضافة',
      'search': 'بحث',
      'filter': 'تصفية',
      'sort': 'ترتيب',
      'back': 'رجوع',
      'next': 'التالي',
      'continue': 'متابعة',
      'done': 'تم',
      'close': 'إغلاق',

      // Navigation
      'home': 'الرئيسية',
      'search_tab': 'البحث',
      'saved': 'المحفوظة',
      'bookings': 'الحجوزات',
      'more': 'المزيد',

      // Authentication
      'sign_in': 'تسجيل الدخول',
      'sign_up': 'إنشاء حساب',
      'sign_out': 'تسجيل الخروج',
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'confirm_password': 'تأكيد كلمة المرور',
      'forgot_password': 'نسيت كلمة المرور؟',
      'remember_me': 'تذكرني',
      'create_account': 'إنشاء حساب',
      'already_have_account': 'لديك حساب بالفعل؟',
      'dont_have_account': 'ليس لديك حساب؟',

      // Admin
      'admin_dashboard': 'لوحة الإدارة',
      'car_approval': 'موافقة السيارة',
      'pending_approval': 'قيد الموافقة',
      'approved_cars': 'السيارات المعتمدة',
      'rejected_cars': 'السيارات المرفوضة',
      'approve': 'موافقة',
      'reject': 'رفض',
      'approval_reason': 'سبب الموافقة',
      'rejection_reason': 'سبب الرفض',

      // Profile & Settings
      'profile': 'الملف الشخصي',
      'edit_profile': 'تعديل الملف الشخصي',
      'settings': 'الإعدادات',
      'language': 'اللغة',
      'currency': 'العملة',
      'notifications': 'الإشعارات',
      'location': 'خدمات الموقع',
      'analytics': 'التحليلات والبيانات',
      'theme': 'المظهر',
      'dark_mode': 'الوضع الليلي',
      'privacy': 'الخصوصية',
      'about': 'حول',
      'version': 'الإصدار',
      'support': 'الدعم',
      'terms': 'شروط الخدمة',
      'privacy_policy': 'سياسة الخصوصية',

      // Favorites
      'favorites': 'المفضلة',
      'add_to_favorites': 'إضافة للمفضلة',
      'remove_from_favorites': 'إزالة من المفضلة',
      'no_favorites': 'لا توجد مفضلة حتى الآن',

      // Payments
      'payment': 'الدفع',
      'payment_methods': 'طرق الدفع',
      'add_payment_method': 'إضافة طريقة دفع',
      'credit_card': 'بطاقة ائتمان',
      'debit_card': 'بطاقة خصم',
      'paypal': 'باي بال',
      'total_amount': 'المبلغ الإجمالي',
      'pay_now': 'ادفع الآن',

      // Notifications
      'notification': 'إشعار',
      'no_notifications': 'لا توجد إشعارات',
      'mark_as_read': 'تحديد كمقروءة',
      'clear_all': 'مسح الكل',

      // Error Messages
      'error_network': 'خطأ في الشبكة. تحقق من اتصالك.',
      'error_server': 'خطأ في الخادم. حاول مرة أخرى لاحقاً.',
      'error_authentication': 'فشل في المصادقة. سجل الدخول مرة أخرى.',
      'error_permission': 'تم رفض الإذن.',
      'error_location': 'تم رفض الوصول للموقع.',
      'error_camera': 'تم رفض الوصول للكاميرا.',
      'error_storage': 'تم رفض الوصول للتخزين.',

      // Success Messages
      'success_login': 'تم تسجيل الدخول بنجاح!',
      'success_logout': 'تم تسجيل الخروج بنجاح!',
      'success_booking': 'تم تأكيد الحجز!',
      'success_cancel': 'تم إلغاء الحجز!',
      'success_profile_update': 'تم تحديث الملف الشخصي بنجاح!',
      'success_car_added': 'تم إضافة السيارة بنجاح!',

      // Empty States
      'no_cars_available': 'لا توجد سيارات متاحة',
      'no_bookings': 'لا توجد حجوزات حتى الآن',
      'no_search_results': 'لم يتم العثور على نتائج',
      'no_internet': 'لا يوجد اتصال بالإنترنت',

      // Demo & Testing
      'multilingual_demo': 'تجربة متعددة اللغات',
      'demo_content': 'محتوى تجريبي',
      'language_changed': 'تم تغيير اللغة بنجاح!',
      'rtl_demo': 'تجربة دعم الكتابة من اليمين لليسار',
      'rtl_notice':
          'يدعم هذا التطبيق اتجاه النص من اليمين إلى اليسار للغة العربية.',
      'test_localization': 'اختبار التعريب',
      'test_dialog_title': 'اختبار التعريب',
      'test_dialog_content': 'يوضح هذا الحوار النص المعرب في العمل.',
      'test_completed': 'اكتمل اختبار التعريب!',

      // Currency Converter
      'currency_converter': 'محول العملات',
      'exchange_rate': 'سعر الصرف',
      'quick_amounts': 'مبالغ سريعة',
      'popular_conversions': 'التحويلات الشائعة',
      'rate_history': 'تاريخ الأسعار',
      'chart_placeholder': 'مخطط الأسعار قريباً',
      'select_currency': 'اختر العملة',
      'from_currency': 'من العملة',
      'to_currency': 'إلى العملة',
      'amount': 'المبلغ',
      'converted_amount': 'المبلغ المحول',
      'exchange_rates': 'أسعار الصرف',
      'last_updated': 'آخر تحديث',
    },
  };

  static String getText(String key, String languageCode) {
    return _translations[languageCode]?[key] ??
        _translations['en']?[key] ??
        key;
  }

  static Map<String, String> getAllTexts(String languageCode) {
    return _translations[languageCode] ?? _translations['en']!;
  }

  static List<String> getSupportedLanguages() {
    return _translations.keys.toList();
  }

  static bool isRTL(String languageCode) {
    return languageCode == 'ar';
  }
}
