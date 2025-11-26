// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'سهلة';

  @override
  String get createTask => 'إنشاء مهمة إفريلي';

  @override
  String get describeYourNeed => 'اوصف حاجتك';

  @override
  String get phoneNumber => 'رقم الهاتف';

  @override
  String get secondPhoneOptional => 'هاتف ثاني (اختياري)';

  @override
  String get useSecondPhoneAsPrimary => 'استخدم الهاتف الثاني كرئيسي';

  @override
  String get locationPurpose => 'الغرض من الموقع';

  @override
  String get addAnotherLocation => 'إضافة موقع آخر';

  @override
  String added(Object count) {
    return 'تم إضافة: $count';
  }

  @override
  String get taskImageOptional => 'صورة المهمة (اختياري)';

  @override
  String get addImage => 'إضافة صورة';

  @override
  String get tapToSelectFromGallery => 'اضغط لاختيار من المعرض';

  @override
  String get changeImage => 'تغيير الصورة';

  @override
  String get remove => 'إزالة';

  @override
  String get uploading => 'جاري الرفع...';

  @override
  String get pickDateTime => 'اختر التاريخ والوقت';

  @override
  String get createTaskButton => 'إنشاء المهمة';

  @override
  String get creating => 'جاري الإنشاء...';

  @override
  String get taskCreatedSuccessfully => 'تم إنشاء المهمة بنجاح';

  @override
  String get tasksDescription => 'وصف المهام:';

  @override
  String get tasksLocations => 'مواقع المهام:';

  @override
  String get contactPhone => 'هاتف الاتصال:';

  @override
  String get imagesPreview => 'معاينة الصور:';

  @override
  String get noImages => 'لا توجد صور';

  @override
  String get backToEdit => 'العودة للتعديل';

  @override
  String get selectLocationOnMap => 'اختر موقعاً على الخريطة...';

  @override
  String get gettingAddress => 'جاري الحصول على العنوان...';

  @override
  String get loadingMap => 'جاري تحميل الخريطة...';

  @override
  String get confirmLocation => 'تأكيد الموقع';

  @override
  String get getCurrentLocation => 'الحصول على الموقع الحالي';

  @override
  String get useYourCurrentLocation => 'استخدم موقعك الحالي';

  @override
  String get noResultsFound => 'لم يتم العثور على نتائج';

  @override
  String get home => 'الرئيسية';

  @override
  String get orders => 'الطلبات';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get settings => 'الإعدادات';

  @override
  String get search => 'بحث';

  @override
  String get searchRestaurants => 'البحث في المطاعم...';

  @override
  String get searchMenuItems => 'البحث في عناصر القائمة...';

  @override
  String get categories => 'الفئات';

  @override
  String get cuisines => 'المطابخ';

  @override
  String get restaurants => 'المطاعم';

  @override
  String get menuItems => 'عناصر القائمة';

  @override
  String get freeDelivery => 'توصيل مجاني';

  @override
  String get location => 'الموقع';

  @override
  String get cuisine => 'نوع المطبخ';

  @override
  String get category => 'الفئة';

  @override
  String get price => 'السعر';

  @override
  String get selectCuisineType => 'اختر نوع المطبخ';

  @override
  String get selectCategories => 'اختر الفئات';

  @override
  String get minimumOrderRange => 'نطاق الحد الأدنى للطلب';

  @override
  String get priceRange => 'نطاق السعر';

  @override
  String get clear => 'مسح';

  @override
  String get done => 'تم';

  @override
  String get noCuisinesAvailable => 'لا توجد أنواع مطابخ متاحة';

  @override
  String get noCategoriesAvailable => 'لا توجد فئات متاحة';

  @override
  String get loadingCategories => 'جاري تحميل الفئات...';

  @override
  String get addNewDrinksMenu => 'إضافة قائمة مشروبات جديدة';

  @override
  String get addDrinksByCreatingVariants =>
      'أضف المشروبات عن طريق إنشاء خيارات. كل خيار يمثل مشروباً مختلفاً (مثل كوكا كولا، فانتا، سبرايت).';

  @override
  String get smartDetectionActive => 'الكشف الذكي نشط';

  @override
  String get smartDetectionDescription =>
      'سيتم مطابقة كل خيار تلقائياً مع صورة المشروب الصحيحة من المجموعة بناءً على اسمه (مثل كوكا كولا → صورة كوكا كولا).';

  @override
  String get foodImages => 'صور الطعام';

  @override
  String get reviewYourMenuItem => 'مراجعة عنصر القائمة الخاص بك';

  @override
  String get uploadFoodImages => 'رفع صور الطعام';

  @override
  String get addHighQualityPhotos =>
      'أضف صور عالية الجودة لطبقك (مطلوب على الأقل 1 صورة)';

  @override
  String get camera => 'الكاميرا';

  @override
  String get gallery => 'المعرض';

  @override
  String get atLeastOneImageRequired => 'مطلوب صورة واحدة على الأقل';

  @override
  String get notSelected => 'غير محدد';

  @override
  String get notEntered => 'غير مدخل';

  @override
  String get noneAdded => 'لم يتم إضافة أي شيء';

  @override
  String get noneUploaded => 'لم يتم رفع أي شيء';

  @override
  String get images => 'الصور';

  @override
  String get min => 'دقيقة';

  @override
  String get max => 'الحد الأقصى';

  @override
  String get to => 'إلى';

  @override
  String get preparationTime => 'وقت التحضير';

  @override
  String get minutes => 'دقيقة';

  @override
  String get unknownRestaurant => 'مطعم غير معروف';

  @override
  String get currency => 'دج';

  @override
  String get noItemsAvailable => 'لا توجد عناصر متاحة';

  @override
  String get viewAll => 'عرض الكل';

  @override
  String get noMenuItemsAvailable => 'لا توجد عناصر قائمة متاحة';

  @override
  String get debugInfoWillAppearInConsole =>
      'ستظهر معلومات التصحيح في سجلات وحدة التحكم';

  @override
  String get failedToLoadMenuItems => 'فشل في تحميل عناصر القائمة';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String noItemsFoundForSearch(Object searchQuery) {
    return 'لم يتم العثور على عناصر لـ \"$searchQuery\"';
  }

  @override
  String get noItemsMatchFilters => 'لا توجد عناصر تطابق المرشحات الخاصة بك';

  @override
  String get tryAdjustingSearchTerms =>
      'حاول تعديل مصطلحات البحث أو تصفح جميع العناصر المتاحة.';

  @override
  String get tryRemovingFilters =>
      'حاول إزالة بعض المرشحات أو تعديل معايير البحث للعثور على المزيد من العناصر.';

  @override
  String get checkBackLaterForNewItems =>
      'تحقق مرة أخرى لاحقاً للحصول على عناصر قائمة جديدة أو حاول تحديث الصفحة.';

  @override
  String get clearFilters => 'مسح المرشحات';

  @override
  String get browseAllItems => 'تصفح جميع العناصر';

  @override
  String get bestChoices => 'أفضل الخيارات';

  @override
  String get noOffersAvailable => 'لا توجد عروض متاحة';

  @override
  String get checkBackLaterForNewDeals =>
      'تحقق مرة أخرى لاحقاً للحصول على صفقات جديدة';

  @override
  String get addToCart => 'إضافة إلى السلة';

  @override
  String get confirmOrder => 'تأكيد الطلب';

  @override
  String get add => 'أضف';

  @override
  String get item => 'عنصر';

  @override
  String get addedToCart => 'تم إضافته إلى السلة';

  @override
  String get unknownItem => 'عنصر غير معروف';

  @override
  String get addedToFavorites => 'تم إضافته إلى المفضلة';

  @override
  String get removedFromFavorites => 'تم إزالته من المفضلة';

  @override
  String get failedToUpdateFavorite => 'فشل في تحديث المفضلة';

  @override
  String get specialNote => 'ملاحظة خاصة';

  @override
  String get addSpecialInstructions => 'أضف أي تعليمات خاصة...';

  @override
  String get mainItemQuantity => 'كمية العنصر الرئيسي';

  @override
  String get saveAndAddAnotherOrder => 'حفظ وإضافة طلب آخر';

  @override
  String get totalPrice => 'السعر الإجمالي';

  @override
  String get filterRestaurants => 'تصفية المطاعم';

  @override
  String get clearAll => 'مسح الكل';

  @override
  String get applyFilters => 'تطبيق المرشحات';

  @override
  String get enterCityOrArea => 'أدخل المدينة أو المنطقة';

  @override
  String get map => 'الخريطة';

  @override
  String get minimumRating => 'الحد الأدنى للتقييم';

  @override
  String get deliveryFeeRange => 'نطاق رسوم التوصيل';

  @override
  String get status => 'الحالة';

  @override
  String get openNow => 'مفتوح الآن';

  @override
  String get cuisineType => 'نوع المطبخ';

  @override
  String get pleaseSelectCategoryFirst => 'اختر الفئة أولاً';

  @override
  String get restaurantCategory => 'فئة المطعم';

  @override
  String get selectCategory => 'اختر الفئة';

  @override
  String get pleaseSelectCategory => 'يرجى اختيار فئة';

  @override
  String get selectedLocation => 'الموقع المحدد';

  @override
  String get tapToSelectLocation => 'اضغط لاختيار الموقع';

  @override
  String get pleaseSelectLocation => 'يرجى اختيار موقع على الخريطة';

  @override
  String get locationPermissionDenied => 'تم رفض إذن الموقع';

  @override
  String get locationPermissionsPermanentlyDenied =>
      'تم رفض أذونات الموقع نهائياً. يرجى التفعيل في الإعدادات.';

  @override
  String get locationServicesDisabled => 'خدمات الموقع معطلة';

  @override
  String get failedToGetCurrentLocation => 'فشل في الحصول على الموقع الحالي';

  @override
  String get delivery => 'توصيل';

  @override
  String get pickup => 'استلام';

  @override
  String get dineIn => 'تناول في المكان';

  @override
  String get rating => 'التقييم';

  @override
  String get reviews => 'المراجعات';

  @override
  String get distance => 'المسافة';

  @override
  String get removeFromCart => 'إزالة من السلة';

  @override
  String get viewCart => 'عرض السلة';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get register => 'إنشاء حساب';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get rememberMe => 'تذكرني';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get notificationSettings => 'إعدادات الإشعارات';

  @override
  String get enableNotifications => 'تفعيل الإشعارات';

  @override
  String get disableNotifications => 'تعطيل الإشعارات';

  @override
  String get language => 'اللغة';

  @override
  String get english => 'الإنجليزية';

  @override
  String get french => 'الفرنسية';

  @override
  String get arabic => 'العربية';

  @override
  String get theme => 'المظهر';

  @override
  String get lightMode => 'المظهر الفاتح';

  @override
  String get darkMode => 'المظهر الداكن';

  @override
  String get systemTheme => 'مظهر النظام';

  @override
  String get about => 'حول التطبيق';

  @override
  String get help => 'المساعدة';

  @override
  String get contactUs => 'تواصل معنا';

  @override
  String get termsOfService => 'شروط الخدمة';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get error => 'خطأ';

  @override
  String get success => 'نجح';

  @override
  String get warning => 'تحذير';

  @override
  String get info => 'معلومات';

  @override
  String get ok => 'موافق';

  @override
  String get cancel => 'إلغاء';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String get confirm => 'تأكيد';

  @override
  String get delete => 'حذف';

  @override
  String get edit => 'تعديل';

  @override
  String get save => 'حفظ';

  @override
  String get submit => 'إرسال';

  @override
  String get update => 'تحديث';

  @override
  String get loading => 'جاري التحميل...';

  @override
  String get pleaseWait => 'يرجى الانتظار...';

  @override
  String get noInternetConnection => 'لا يوجد اتصال بالإنترنت';

  @override
  String get somethingWentWrong => 'حدث خطأ ما';

  @override
  String get tryAgain => 'حاول مرة أخرى';

  @override
  String get enableLocation => 'تفعيل الموقع';

  @override
  String get locationPermissionRequired => 'إذن الموقع مطلوب';

  @override
  String get cameraPermissionDenied => 'تم رفض إذن الكاميرا';

  @override
  String get cameraPermissionRequired => 'إذن الكاميرا مطلوب';

  @override
  String get galleryPermissionRequired => 'إذن المعرض مطلوب';

  @override
  String get searchResultsFor => 'نتائج البحث عن';

  @override
  String get favorites => 'المفضلة';

  @override
  String get addToFavorites => 'إضافة إلى المفضلة';

  @override
  String get removeFromFavorites => 'إزالة من المفضلة';

  @override
  String get cart => 'السلة';

  @override
  String get cartEmpty => 'سلتك فارغة';

  @override
  String get total => 'المجموع:';

  @override
  String get subtotal => 'المجموع الفرعي';

  @override
  String get tax => 'الضريبة';

  @override
  String get deliveryFee => 'رسوم التوصيل';

  @override
  String get serviceFee => 'رسوم الخدمة';

  @override
  String get order => 'الطلب';

  @override
  String get orderPlaced => 'تم الطلب';

  @override
  String get orderConfirmed => 'تم تأكيد الطلب';

  @override
  String get orderPreparing => 'جاري التحضير';

  @override
  String get orderReady => 'الطلب جاهز';

  @override
  String get orderPickedUp => 'تم استلام الطلب';

  @override
  String get orderDelivered => 'تم التوصيل';

  @override
  String get orderCancelled => 'تم إلغاء الطلب';

  @override
  String get payment => 'الدفع';

  @override
  String get paymentMethod => 'طريقة الدفع';

  @override
  String get cashOnDelivery => 'الدفع عند التسليم';

  @override
  String get cardPayment => 'دفع بالبطاقة';

  @override
  String get walletPayment => 'دفع بالمحفظة';

  @override
  String get restaurant => 'المطعم';

  @override
  String get restaurantDetails => 'تفاصيل المطعم';

  @override
  String get restaurantMenu => 'قائمة المطعم';

  @override
  String get restaurantReviews => 'مراجعات المطعم';

  @override
  String get restaurantHours => 'ساعات العمل';

  @override
  String get restaurantLocation => 'موقع المطعم';

  @override
  String get restaurantContact => 'تواصل مع المطعم';

  @override
  String get deliveryAddress => 'عنوان التوصيل';

  @override
  String get addAddress => 'إضافة عنوان';

  @override
  String get editAddress => 'تعديل العنوان';

  @override
  String get selectAddress => 'اختر العنوان';

  @override
  String get editProfile => 'تعديل الملف الشخصي';

  @override
  String get personalInformation => 'المعلومات الشخصية';

  @override
  String get accountSettings => 'إعدادات الحساب';

  @override
  String get welcome => 'مرحباً';

  @override
  String get welcomeBack => 'مرحباً بعودتك';

  @override
  String get signInToContinue => 'سجل دخولك للمتابعة';

  @override
  String get createAccount => 'إنشاء حساب';

  @override
  String get signUp => 'إنشاء حساب';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get verification => 'التحقق';

  @override
  String get verifyPhone => 'التحقق من الهاتف';

  @override
  String get verifyEmail => 'التحقق من البريد الإلكتروني';

  @override
  String get verificationCode => 'رمز التحقق';

  @override
  String get resendCode => 'إعادة إرسال الرمز';

  @override
  String get allYourNeedsInOneApp => 'كل احتياجاتك في تطبيق واحد !';

  @override
  String get enterPhoneNumber => 'أدخل رقم الهاتف';

  @override
  String get changePhoneNumber => 'تغيير رقم الهاتف';

  @override
  String get verifyAndContinue => 'التحقق والمتابعة';

  @override
  String get continueButton => 'متابعة';

  @override
  String get continueAsGuest => 'المتابعة كضيف';

  @override
  String get didntReceiveCode => 'لم تستلم الرمز؟ ';

  @override
  String resendIn(int seconds) {
    return 'إعادة الإرسال خلال $secondsث';
  }

  @override
  String get requestNewCode => 'طلب رمز جديد';

  @override
  String codeExpiresIn(int minutes, int seconds) {
    return 'ينتهي الرمز خلال $minutesد $secondsث';
  }

  @override
  String get verificationCodeExpired => 'انتهت صلاحية رمز التحقق';

  @override
  String get verificationCodeExpiredMessage =>
      'انتهت صلاحية رمز التحقق. يرجى طلب رمز جديد.';

  @override
  String get sixDigitCode => 'يرجى إدخال رمز مكون من 6 أرقام';

  @override
  String get byContinuingYouAgree => 'بالمتابعة، أنت توافق على ';

  @override
  String get byClickingContinueYouAcknowledge =>
      'بالنقر على زر المتابعة، أنت تقر بأنك قد قرأت ووافقت على ';

  @override
  String verificationCodeSentTo(String countryCode, String phoneNumber) {
    return 'تم إرسال رمز التحقق إلى +$countryCode$phoneNumber';
  }

  @override
  String get validationRequired => 'مطلوب';

  @override
  String get validationEmailInvalid => 'عنوان بريد إلكتروني غير صالح';

  @override
  String get validationPhoneInvalid =>
      'يرجى إدخال رقم هاتف صالح (10 أرقام على الأقل)';

  @override
  String get validationPasswordTooShort => 'كلمة المرور قصيرة جداً';

  @override
  String get validationPasswordMismatch => 'كلمات المرور غير متطابقة';

  @override
  String get logoutConfirmation => 'هل أنت متأكد من أنك تريد تسجيل الخروج؟';

  @override
  String get tapToChangePhoto => 'اضغط لتغيير الصورة';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get fullNameRequired => 'الاسم الكامل *';

  @override
  String get nameTooShort => 'يجب أن يكون الاسم حرفين على الأقل';

  @override
  String get dateOfBirth => 'تاريخ الميلاد';

  @override
  String get saveChanges => 'حفظ التغييرات';

  @override
  String get noDraftTasks => 'لا توجد مهام مسودة للمراجعة';

  @override
  String get taskDescription => 'وصف المهمة:';

  @override
  String get taskLocations => 'مواقع المهمة';

  @override
  String get noPhoneProvided => 'لم يتم توفير هاتف';

  @override
  String get primaryLocation => 'الموقع الأساسي';

  @override
  String get additionalLocation => 'موقع إضافي';

  @override
  String get unknownAddress => 'عنوان غير معروف';

  @override
  String get taskProcess => 'عملية المهمة';

  @override
  String get taskDetails => 'تفاصيل المهمة';

  @override
  String get taskLocationsCount => 'مواقع المهمة';

  @override
  String get tapToViewMap => 'انقر لعرض الخريطة مع جميع المواقع';

  @override
  String get unknownPurpose => 'غرض الموقع';

  @override
  String get deliverTo => 'توصيل إلى';

  @override
  String get tapToEnableLocation => 'اضغط لتمكين الوصول للموقع';

  @override
  String get gpsDisabled => 'GPS معطل - اضغط لتمكينه';

  @override
  String get detectingLocation => 'جاري اكتشاف الموقع...';

  @override
  String get locationOptions => 'خيارات الموقع';

  @override
  String get selectOnMap => 'اختر على الخريطة';

  @override
  String get chooseLocationInteractive =>
      'اختر الموقع باستخدام الخريطة التفاعلية';

  @override
  String get refreshLocation => 'تحديث الموقع';

  @override
  String get getCurrentLocationBetter => 'الحصول على الموقع الحالي بدقة أفضل';

  @override
  String get noMin => 'لا يوجد حد أدنى';

  @override
  String get estimatedDeliveryTime => 'وقت التوصيل المتوقع';

  @override
  String get filter => 'تصفية';

  @override
  String get apply => 'تطبيق';

  @override
  String get sortBy => 'ترتيب حسب';

  @override
  String get deliveryTime => 'وقت التوصيل';

  @override
  String get alphabetical => 'أبجدي';

  @override
  String get popular => 'شائع';

  @override
  String get trending => 'رائج';

  @override
  String get newItem => 'جديد';

  @override
  String get featured => 'مميز';

  @override
  String get menuItemDetails => 'تفاصيل عنصر القائمة';

  @override
  String get ingredients => 'المكونات';

  @override
  String get allergens => 'مسببات الحساسية';

  @override
  String get nutritionalInfo => 'المعلومات الغذائية';

  @override
  String get customize => 'تخصيص';

  @override
  String get share => 'مشاركة';

  @override
  String get activeOrders => 'الطلبات النشطة';

  @override
  String get orderSummary => 'ملخص الطلب';

  @override
  String get orderDetails => 'تفاصيل الطلب';

  @override
  String get trackOrder => 'تتبع الطلب';

  @override
  String get orderStatus => 'حالة الطلب';

  @override
  String get estimatedArrival => 'الوصول المتوقع';

  @override
  String get delivered => 'تم التسليم';

  @override
  String get preparing => 'جاري التحضير';

  @override
  String get ready => 'جاهز';

  @override
  String get pickedUp => 'تم الاستلام';

  @override
  String get cancelled => 'ملغي';

  @override
  String get promoCode => 'رمز الخصم';

  @override
  String get applyPromo => 'تطبيق رمز الخصم';

  @override
  String get addNewAddress => 'إضافة عنوان جديد';

  @override
  String get changeAddress => 'تغيير العنوان';

  @override
  String get orderUpdates => 'تحديثات الطلبات';

  @override
  String get promotionalOffers => 'العروض الترويجية';

  @override
  String get newRestaurants => 'مطاعم جديدة';

  @override
  String get deliveryUpdates => 'تحديثات التوصيل';

  @override
  String get checkBackLater => 'تحقق لاحقاً';

  @override
  String get loadingCuisines => 'جاري تحميل المطابخ...';

  @override
  String get pleaseSelectCuisineType => 'يرجى اختيار نوع مطبخ';

  @override
  String get noMinimum => 'لا يوجد حد أدنى';

  @override
  String get algerianDinar => 'دج';

  @override
  String restaurantInfoFormat(
      Object city,
      Object deliveryFee,
      Object deliveryTime,
      Object minimumCommande,
      Object minimumOrder,
      Object workingHours) {
    return '$deliveryTime • $minimumOrder • $city • $deliveryFee • $workingHours';
  }

  @override
  String restaurantNameLabel(Object restaurantName) {
    return 'اسم المطعم: $restaurantName';
  }

  @override
  String restaurantDetailsLabel(Object infoText) {
    return 'تفاصيل المطعم: $infoText';
  }

  @override
  String doubleTapToRemove(Object restaurantName) {
    return 'انقر نقراً مزدوجاً لإزالة $restaurantName من المفضلة';
  }

  @override
  String doubleTapToAdd(Object restaurantName) {
    return 'انقر نقراً مزدوجاً لإضافة $restaurantName إلى المفضلة';
  }

  @override
  String get available => 'متاح';

  @override
  String get notAvailable => 'غير متاح';

  @override
  String get priceLabel => 'السعر';

  @override
  String get ratingLabel => 'التقييم';

  @override
  String get reviewsLabel => 'المراجعات';

  @override
  String get distanceLabel => 'المسافة';

  @override
  String get deliveryTimeLabel => 'وقت التوصيل';

  @override
  String get cuisineLabel => 'نوع المطبخ';

  @override
  String get categoryLabel => 'الفئة';

  @override
  String get featuredLabel => 'مميز';

  @override
  String get popularLabel => 'شائع';

  @override
  String get trendingLabel => 'رائج';

  @override
  String get newLabel => 'جديد';

  @override
  String get bestChoicesLabel => 'أفضل الخيارات';

  @override
  String get viewAllLabel => 'عرض الكل';

  @override
  String get restaurantsLabel => 'المطاعم';

  @override
  String get menuItemsLabel => 'عناصر القائمة';

  @override
  String get searchRestaurantsLabel => 'البحث في المطاعم';

  @override
  String get filterLabel => 'تصفية';

  @override
  String get applyLabel => 'تطبيق';

  @override
  String get clearAllLabel => 'مسح الكل';

  @override
  String get priceRangeLabel => 'نطاق السعر';

  @override
  String get sortByLabel => 'ترتيب حسب';

  @override
  String get distanceSort => 'المسافة';

  @override
  String get ratingSort => 'التقييم';

  @override
  String get deliveryTimeSort => 'وقت التوصيل';

  @override
  String get alphabeticalSort => 'أبجدي';

  @override
  String get noRestaurantsFound => 'لم يتم العثور على مطاعم';

  @override
  String get tryAdjustingSearch => 'حاول تعديل معايير البحث';

  @override
  String get loadingRestaurants => 'جاري تحميل المطاعم...';

  @override
  String get errorLoadingRestaurants => 'خطأ في تحميل المطاعم';

  @override
  String get retryLabel => 'إعادة المحاولة';

  @override
  String restaurantsCount(Object count) {
    return '$count مطعم';
  }

  @override
  String get minimumOrderLabel => 'الحد الأدنى';

  @override
  String get deliveryFeeLabel => 'رسوم التوصيل';

  @override
  String get cityLabel => 'المدينة';

  @override
  String get workingHoursLabel => 'ساعات العمل';

  @override
  String get openLabel => 'مفتوح';

  @override
  String get closedLabel => 'مغلق';

  @override
  String get minLabel => 'دقيقة';

  @override
  String get noMinLabel => 'لا يوجد حد أدنى';

  @override
  String get freeDeliveryLabel => 'توصيل مجاني';

  @override
  String restaurantLogoLabel(Object restaurantName) {
    return 'شعار مطعم $restaurantName';
  }

  @override
  String get viewAllButton => 'عرض الكل';

  @override
  String get liveUpdatesTitle => 'التحديثات المباشرة';

  @override
  String get justNow => 'الآن';

  @override
  String minutesAgo(Object min, Object minutes) {
    return 'منذ $minutes دقيقة';
  }

  @override
  String hoursAgo(int count, String plural) {
    return 'منذ $count $plural';
  }

  @override
  String daysAgo(int count, String plural) {
    return 'منذ $count $plural';
  }

  @override
  String get todayLabel => 'اليوم';

  @override
  String get tomorrowLabel => 'غداً';

  @override
  String get openingHoursLabel => 'ساعات الفتح';

  @override
  String get closingHoursLabel => 'ساعات الإغلاق';

  @override
  String menuItemNameLabel(Object itemName) {
    return 'عنصر القائمة: $itemName';
  }

  @override
  String get menuItemName => 'اسم عنصر القائمة';

  @override
  String get enterTheNameOfYourMenuItem => 'أدخل اسم عنصر القائمة الخاص بك';

  @override
  String menuItemPriceLabel(Object price) {
    return 'السعر: $price دج';
  }

  @override
  String menuItemDescriptionLabel(Object description) {
    return 'الوصف: $description';
  }

  @override
  String get ingredientsLabel => 'المكونات';

  @override
  String get allergensLabel => 'مسببات الحساسية';

  @override
  String get nutritionalInfoLabel => 'المعلومات الغذائية';

  @override
  String get customizeLabel => 'تخصيص';

  @override
  String get shareLabel => 'مشاركة';

  @override
  String get activeOrdersLabel => 'الطلبات النشطة';

  @override
  String get orderSummaryLabel => 'ملخص الطلب';

  @override
  String get orderDetailsLabel => 'تفاصيل الطلب';

  @override
  String get trackOrderLabel => 'تتبع الطلب';

  @override
  String get orderStatusLabel => 'حالة الطلب';

  @override
  String get estimatedArrivalLabel => 'الوصول المتوقع';

  @override
  String get deliveredLabel => 'تم التوصيل';

  @override
  String get preparingLabel => 'قيد التحضير';

  @override
  String get readyLabel => 'جاهز';

  @override
  String get pickedUpLabel => 'تم الاستلام';

  @override
  String get cancelledLabel => 'ملغي';

  @override
  String get paymentMethodLabel => 'طريقة الدفع';

  @override
  String get cashOnDeliveryLabel => 'الدفع عند التسليم';

  @override
  String get cardPaymentLabel => 'دفع بالبطاقة';

  @override
  String get walletPaymentLabel => 'دفع بالمحفظة';

  @override
  String get promoCodeLabel => 'رمز الخصم';

  @override
  String get applyPromoLabel => 'تطبيق رمز الخصم';

  @override
  String get deliveryAddressLabel => 'عنوان التوصيل';

  @override
  String get addNewAddressLabel => 'إضافة عنوان جديد';

  @override
  String get selectAddressLabel => 'اختر العنوان';

  @override
  String get changeAddressLabel => 'تغيير العنوان';

  @override
  String get notificationsLabel => 'الإشعارات';

  @override
  String get notificationSettingsLabel => 'إعدادات الإشعارات';

  @override
  String get orderUpdatesLabel => 'تحديثات الطلبات';

  @override
  String get promotionalOffersLabel => 'العروض الترويجية';

  @override
  String get newRestaurantsLabel => 'مطاعم جديدة';

  @override
  String get deliveryUpdatesLabel => 'تحديثات التوصيل';

  @override
  String get nameMinLength => 'يجب أن يكون الاسم حرفين على الأقل';

  @override
  String get invalidImageError =>
      'صورة غير صالحة. يرجى اختيار صورة صالحة أقل من 5 ميجابايت.';

  @override
  String get profileImageUpdated => 'تم تحديث صورة الملف الشخصي بنجاح!';

  @override
  String imageUploadFailed(Object error) {
    return 'فشل في رفع الصورة: $error';
  }

  @override
  String errorOccurred(Object error) {
    return 'خطأ: $error';
  }

  @override
  String get profileUpdated => 'تم تحديث الملف الشخصي بنجاح!';

  @override
  String profileUpdateError(Object error) {
    return 'خطأ في تحديث الملف الشخصي: $error';
  }

  @override
  String get becomeDeliveryMan => 'كن عامل توصيل';

  @override
  String get becomeSahlaPartner => 'كن شريك سحلى';

  @override
  String get growWithSahla => 'انمو مع خدمات سحلى';

  @override
  String get tapToDetectLocation => 'اضغط لاكتشاف الموقع';

  @override
  String get deliveryUnavailable => 'التوصيل غير متاح';

  @override
  String get pickLocation => 'اختر الموقع';

  @override
  String get editLocation => 'تعديل الموقع';

  @override
  String get proceedOrDiscard => 'المتابعة أو الإلغاء؟';

  @override
  String get proceedOrDiscardMessage =>
      'لقد قمت بتفعيل خدمات الموقع. هل تريد المتابعة مع الموقع المحدد أم إلغاء التغييرات؟';

  @override
  String get locationEditedMessage =>
      'لقد قمت بتعديل الموقع. هل تريد المتابعة مع الموقع المحدد أم إلغاء التغييرات؟';

  @override
  String get proceed => 'متابعة';

  @override
  String get discard => 'إلغاء';

  @override
  String get approximatePrice => 'السعر التقريبي';

  @override
  String get addSecondaryPhone => 'إضافة رقم هاتف ثانوي؟';

  @override
  String get chooseLocationOnMap => 'اختر الموقع باستخدام الخريطة التفاعلية';

  @override
  String get createIfriliTask => 'إنشاء مهمة إفرلي';

  @override
  String get required => 'مطلوب';

  @override
  String get dropPinOnMapFirst => 'ضع علامة على الخريطة أولاً';

  @override
  String get pleaseDropPinOrAddLocations =>
      'يرجى وضع علامة على الخريطة أو إضافة مواقع';

  @override
  String errorUploadingImage(Object error) {
    return 'خطأ في رفع الصورة: $error';
  }

  @override
  String get reviewIfriliTasks => 'مراجعة مهام إفرلي';

  @override
  String get noDraftTasksToReview => 'لا توجد مهام مسودة للمراجعة';

  @override
  String get confirmCreateTasks => 'تأكيد وإنشاء المهام';

  @override
  String failedToCreateTasks(Object error) {
    return 'فشل في إنشاء المهام: $error';
  }

  @override
  String get tapToViewMapWithLocations => 'اضغط لعرض الخريطة مع جميع المواقع';

  @override
  String locationCount(Object count, Object plural) {
    return '$count موقع';
  }

  @override
  String get pending => 'في الانتظار';

  @override
  String get costReview => 'مراجعة التكلفة';

  @override
  String get costAgreed => 'تم الاتفاق على التكلفة';

  @override
  String get assigned => 'مُعيّن';

  @override
  String get completed => 'مكتمل';

  @override
  String get taskLocationsSection => 'مواقع المهمة:';

  @override
  String failedToOpenMapView(Object error) {
    return 'فشل في فتح عرض الخريطة: $error';
  }

  @override
  String get deliveryManApplication => 'طلب سائق التوصيل';

  @override
  String get joinOurDeliveryTeam => 'انضم إلى فريق التوصيل لدينا!';

  @override
  String get earnMoneyHelpingPeople =>
      'اكسب المال أثناء مساعدة الناس في الحصول على طعامهم';

  @override
  String get enterYourFullName => 'أدخل اسمك الكامل';

  @override
  String get pleaseEnterYourFullName => 'يرجى إدخال اسمك الكامل';

  @override
  String get phoneNumberRequired => 'رقم الهاتف *';

  @override
  String get enterYourPhoneNumber => 'أدخل رقم هاتفك';

  @override
  String get pleaseEnterYourPhoneNumber => 'يرجى إدخال رقم هاتفك';

  @override
  String get addressRequired => 'العنوان *';

  @override
  String get enterYourCurrentAddress => 'أدخل عنوانك الحالي';

  @override
  String get pleaseEnterYourAddress => 'يرجى إدخال عنوانك';

  @override
  String get vehicleInformation => 'معلومات المركبة';

  @override
  String get vehicleTypeRequired => 'نوع المركبة *';

  @override
  String get vehicleModelRequired => 'طراز المركبة *';

  @override
  String get enterYourVehicleModel => 'أدخل طراز مركبتك';

  @override
  String get pleaseEnterYourVehicleModel => 'يرجى إدخال طراز مركبتك';

  @override
  String get vehicleYearRequired => 'سنة المركبة *';

  @override
  String get enterYourVehicleYear => 'أدخل سنة مركبتك';

  @override
  String get pleaseEnterYourVehicleYear => 'يرجى إدخال سنة مركبتك';

  @override
  String get vehicleColorRequired => 'لون المركبة *';

  @override
  String get enterYourVehicleColor => 'أدخل لون مركبتك';

  @override
  String get pleaseEnterYourVehicleColor => 'يرجى إدخال لون مركبتك';

  @override
  String get licenseNumberRequired => 'رقم الرخصة *';

  @override
  String get enterYourDrivingLicenseNumber => 'أدخل رقم رخصة القيادة الخاصة بك';

  @override
  String get pleaseEnterYourLicenseNumber => 'يرجى إدخال رقم رخصتك';

  @override
  String get availability => 'التوفر';

  @override
  String get availabilityRequired => 'التوفر *';

  @override
  String get previousExperienceOptional => 'الخبرة السابقة (اختياري)';

  @override
  String get describePreviousExperience =>
      'صف أي خبرة سابقة في التوصيل أو خدمة العملاء';

  @override
  String get requirements => 'المتطلبات';

  @override
  String get haveValidDrivingLicense => 'لدي رخصة قيادة صالحة';

  @override
  String get haveReliableVehicle => 'لدي مركبة موثوقة';

  @override
  String get availableOnWeekends => 'متاح في عطلات نهاية الأسبوع';

  @override
  String get availableInEvenings => 'متاح في المساء';

  @override
  String get benefitsOfJoining => 'فوائد الانضمام';

  @override
  String get flexibleEarningOpportunities => 'فرص كسب مرنة';

  @override
  String get workOnYourOwnSchedule => 'اعمل حسب جدولك الزمني الخاص';

  @override
  String get deliverInYourLocalArea => 'قم بالتوصيل في منطقتك المحلية';

  @override
  String get supportTeam => 'فريق دعم على مدار 24/7';

  @override
  String get performanceBonuses => 'مكافآت الأداء';

  @override
  String get submitApplication => 'إرسال الطلب';

  @override
  String get resetForm => 'إعادة تعيين النموذج';

  @override
  String get submittingApplication => 'جاري إرسال الطلب...';

  @override
  String get applicationSubmittedSuccessfully =>
      'تم إرسال الطلب بنجاح! سنقوم بمراجعته خلال 24-48 ساعة.';

  @override
  String get submitApplicationConfirmation => 'إرسال الطلب؟';

  @override
  String get confirmApplicationSubmission =>
      'هل أنت متأكد من أنك تريد إرسال طلب التوصيل الخاص بك؟ تأكد من أن جميع المعلومات صحيحة.';

  @override
  String get termsAndConditions =>
      'بإرسال هذا الطلب، فإنك توافق على شروطنا وأحكامنا وسياسة الخصوصية.';

  @override
  String get validationNameRequired => 'يرجى إدخال اسمك الكامل';

  @override
  String get validationPhoneRequired => 'يرجى إدخال رقم هاتفك';

  @override
  String get validationPhoneFormat => 'يرجى إدخال تنسيق رقم هاتف صالح';

  @override
  String get validationAddressRequired => 'يرجى إدخال عنوانك';

  @override
  String get validationVehicleTypeRequired => 'يرجى اختيار نوع المركبة';

  @override
  String get validationVehicleModelRequired => 'يرجى إدخال طراز المركبة';

  @override
  String get validationVehicleYearRequired => 'يرجى إدخال سنة المركبة';

  @override
  String get validationVehicleColorRequired => 'يرجى إدخال لون المركبة';

  @override
  String get validationLicenseNumberRequired => 'يرجى إدخال رقم الرخصة';

  @override
  String get validationAvailabilityRequired => 'يرجى اختيار التوفر';

  @override
  String get validationLicenseRequired => 'يجب أن يكون لديك رخصة قيادة صالحة';

  @override
  String get validationVehicleRequired => 'يجب أن يكون لديك مركبة موثوقة';

  @override
  String errorSubmittingApplication(Object error) {
    return 'خطأ في إرسال الطلب: $error';
  }

  @override
  String get errorUnexpected => 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.';

  @override
  String get errorNetwork => 'يرجى التحقق من اتصال الإنترنت الخاص بك';

  @override
  String get errorServer =>
      'الخدمة غير متاحة مؤقتاً. يرجى المحاولة مرة أخرى لاحقاً';

  @override
  String get errorDuplicateApplication => 'لقد قدمت طلباً بالفعل';

  @override
  String get alreadyExists => 'يوجد بالفعل';

  @override
  String get availableForVariants => 'متاح للأصناف';

  @override
  String get optional => 'اختياري';

  @override
  String get selectVariantsForSupplement =>
      'اختر الأصناف التي سيكون هذا المكمل متاحاً لها. اتركه فارغاً لجميع الأصناف.';

  @override
  String get errorInvalidYear => 'يرجى إدخال سنة صالحة (1990-2030)';

  @override
  String get errorMissingLicense => 'يجب أن يكون لديك رخصة قيادة صالحة';

  @override
  String get errorMissingVehicle => 'يجب أن يكون لديك مركبة موثوقة';

  @override
  String get applicationDraftSaved => 'تم حفظ المسودة';

  @override
  String get applicationDraftRestored => 'تم استعادة المسودة';

  @override
  String get yourOrder => 'طلبك';

  @override
  String get items => 'عناصر';

  @override
  String get enterPromoCode => 'أدخل رمز الخصم';

  @override
  String get promoCodeApplied => 'تم تطبيق رمز الخصم بنجاح!';

  @override
  String get promoCodeRemoved => 'تم إزالة رمز الخصم';

  @override
  String get promoCodeNotApplicable =>
      'رمز الخصم غير قابل للتطبيق على سلتك الحالية';

  @override
  String get invalidPromoCode => 'رمز خصم غير صالح';

  @override
  String get errorApplyingPromoCode =>
      'خطأ في تطبيق رمز الخصم. يرجى المحاولة مرة أخرى.';

  @override
  String get errorRemovingPromoCode => 'خطأ في إزالة رمز الخصم';

  @override
  String get clearCart => 'مسح السلة';

  @override
  String get clearCartConfirmation =>
      'هل أنت متأكد من أنك تريد إزالة جميع العناصر من سلتك؟';

  @override
  String get discount => 'خصم';

  @override
  String get size => 'الحجم';

  @override
  String get regular => 'عادي';

  @override
  String get noItemsInOrder => 'لا توجد عناصر في هذا الطلب';

  @override
  String get orderNumber => 'طلب رقم';

  @override
  String get variant => 'النوع';

  @override
  String get supplements => 'الإضافات';

  @override
  String get drinks => 'المشروبات';

  @override
  String get drinksByRestaurant => 'مشروبات المطعم';

  @override
  String get variants => 'الخيارات';

  @override
  String get forVariant => 'لـ';

  @override
  String get customizeIngredients => 'المكونات';

  @override
  String get customizeOrder => 'خصص طلبك';

  @override
  String get tapToEdit => 'انقر للتعديل';

  @override
  String get tapToExpand => 'انقر للتوسيع';

  @override
  String get addSupplements => 'الإضافات';

  @override
  String get mainPackIngredients => 'مكونات الحزمة الرئيسية';

  @override
  String get freeDrinksIncluded => 'المشروبات المجانية المضمنة';

  @override
  String chooseUpToComplimentaryDrink(int count, String drink, String plural) {
    return 'اختر حتى $count $drink مجاني$plural';
  }

  @override
  String get savedOrders => 'الطلبات المحفوظة';

  @override
  String get choosePreferencesForEachItem => 'اختر تفضيلاتك لكل عنصر';

  @override
  String get chooseVariant => 'اختر مايناسب ذوقك';

  @override
  String get ingredientPreferences => 'تفضيلات المكونات';

  @override
  String get normal => 'عادي';

  @override
  String get more => 'المزيد';

  @override
  String get less => 'أقل';

  @override
  String get wantMore => 'أريد المزيد';

  @override
  String get defaultOption => 'افتراضي';

  @override
  String get specialInstructions => 'تعليمات خاصة:';

  @override
  String get removeItem => 'إزالة العنصر';

  @override
  String get removeItemConfirmation => 'هل أنت متأكد من أنك تريد إزالة';

  @override
  String get fromYourOrder => 'من طلبك؟';

  @override
  String get invalidCartItemData => 'بيانات عنصر السلة غير صالحة';

  @override
  String get deliveryDetails => 'تفاصيل التوصيل';

  @override
  String get useCurrentLocation => 'استخدام الموقع الحالي';

  @override
  String get chooseOnMap => 'اختر على الخريطة';

  @override
  String get loadingAddress => 'جاري تحميل العنوان...';

  @override
  String get noAddressSelected => 'لم يتم اختيار عنوان';

  @override
  String get secondaryPhoneOptional => 'رقم هاتف ثانوي (اختياري)';

  @override
  String get preparingOrder => 'جاري تحضير طلبك في المطعم...';

  @override
  String get preparingOrderSubtext =>
      'يمكنك إغلاق هذا وتتبع الطلب مباشرة في أي وقت.';

  @override
  String get readyForPickup => 'جاهز للاستلام';

  @override
  String get deliveryPartnerPickup => 'سيقوم شريك التوصيل بجلب طلبك قريباً.';

  @override
  String get pleaseSelectDeliveryLocation =>
      'يرجى اختيار خيار موقع التوصيل أولاً';

  @override
  String get pleaseSelectDeliveryLocationOption => 'يرجى اختيار موقع التوصيل';

  @override
  String get failedToConfirmOrder => 'فشل في تأكيد الطلب';

  @override
  String get switchMapType => 'تبديل نوع الخريطة';

  @override
  String get selectedOnMap => 'تم اختياره على الخريطة';

  @override
  String get yourCartIsEmpty => 'سلتك فارغة';

  @override
  String get addDeliciousItems => 'أضف بعض الأطباق اللذيذة للبدء!';

  @override
  String get browseMenu => 'تصفح القائمة';

  @override
  String get tapFloatingCartIcon =>
      'اضغط على أيقونة السلة العائمة عند إضافة العناصر';

  @override
  String get cannotPlaceCall => 'لا يمكن إجراء مكالمة على هذا الجهاز';

  @override
  String get failedToOpenDialer => 'فشل في فتح طالب الهاتف';

  @override
  String get mapLoadingError => 'خطأ في تحميل الخريطة';

  @override
  String get deliveryPartner => 'شريك التوصيل';

  @override
  String get onTheWay => 'في الطريق';

  @override
  String get phoneNumberNotAvailable => 'رقم الهاتف غير متوفر';

  @override
  String get updateLocation => 'تحديث الموقع';

  @override
  String get placed => 'تم الطلب';

  @override
  String get confirmReception => 'تأكيد الاستلام';

  @override
  String get receptionConfirmed => 'تم تأكيد الاستلام';

  @override
  String get failedToConfirmReception => 'فشل في تأكيد الاستلام';

  @override
  String get failedToConfirm => 'فشل في التأكيد';

  @override
  String get unitPrice => 'سعر الوحدة:';

  @override
  String get quantity => 'الكمية:';

  @override
  String get itemName => 'اسم العنصر:';

  @override
  String get totalAmount => 'المبلغ الإجمالي:';

  @override
  String get dateAt => 'في';

  @override
  String get tasksAndOrders => 'المهام والطلبات';

  @override
  String get active => 'نشط';

  @override
  String get enablePermissions => 'تفعيل الأذونات';

  @override
  String get permissionsDescription =>
      'نستخدم موقعك لإظهار المطاعم القريبة وحالة التوصيل، والإشعارات لإبقائك على اطلاع.';

  @override
  String get locationPermissionTitle => 'الموقع (أثناء استخدام التطبيق)';

  @override
  String get locationPermissionSubtitle =>
      'للخرائط والنتائج القريبة وتتبع التوصيل المباشر.';

  @override
  String get notificationsPermissionTitle => 'الإشعارات';

  @override
  String get notificationsPermissionSubtitle =>
      'احصل على تحديثات الطلبات والتنبيهات المهمة.';

  @override
  String get allowAll => 'السماح للكل';

  @override
  String get skipForNow => 'تخطي الآن';

  @override
  String get becomeRestaurantOwner => 'كن مالك مطعم';

  @override
  String get restaurantOwnerApplication => 'طلب مالك مطعم';

  @override
  String get joinOurRestaurantNetwork => 'انضم إلى شبكة المطاعم!';

  @override
  String get growYourRestaurantBusiness => 'نمي عملك في المطاعم مع سهلة';

  @override
  String get serviceAndBasicInfo => 'الخدمة والمعلومات الأساسية';

  @override
  String get additionalDetails => 'تفاصيل إضافية';

  @override
  String get selectService => 'اختر الخدمة';

  @override
  String get pleaseSelectService => 'يرجى اختيار خدمة';

  @override
  String get pleaseSelectServiceType => 'يرجى اختيار نوع الخدمة';

  @override
  String get restaurantName => 'اسم المطعم';

  @override
  String get restaurantNameRequired => 'اسم المطعم مطلوب';

  @override
  String get enterRestaurantName => 'أدخل اسم المطعم';

  @override
  String get pleaseEnterRestaurantName => 'يرجى إدخال اسم المطعم';

  @override
  String get pleaseEnterValidName => 'يرجى إدخال اسم صحيح (2-100 حرف)';

  @override
  String get restaurantDescription => 'وصف المطعم';

  @override
  String get enterRestaurantDescription => 'أدخل وصف المطعم';

  @override
  String get restaurantPhone => 'هاتف المطعم';

  @override
  String get restaurantPhoneRequired => 'هاتف المطعم مطلوب';

  @override
  String get enterRestaurantPhone => 'أدخل هاتف المطعم';

  @override
  String get pleaseEnterRestaurantPhone => 'يرجى إدخال هاتف المطعم';

  @override
  String get pleaseEnterValidPhone => 'يرجى إدخال رقم هاتف صحيح';

  @override
  String get restaurantAddress => 'عنوان المطعم';

  @override
  String get restaurantAddressRequired => 'عنوان المطعم مطلوب';

  @override
  String get pleaseSelectRestaurantAddress => 'يرجى اختيار عنوان المطعم';

  @override
  String get pleaseSelectLocationWithinAlgeria =>
      'يرجى اختيار موقع داخل الجزائر';

  @override
  String get wilaya => 'الولاية';

  @override
  String get pleaseSelectWilaya => 'يرجى اختيار ولاية';

  @override
  String get groceryType => 'نوع البقالة';

  @override
  String get pleaseSelectGroceryType => 'يرجى اختيار نوع البقالة';

  @override
  String get superMarket => 'سوبر ماركت';

  @override
  String get boucherie => 'جزارة';

  @override
  String get patisserie => 'مخبزة';

  @override
  String get fruitsVegetables => 'فواكه وخضروات';

  @override
  String get bakery => 'مخبز';

  @override
  String get seafood => 'مأكولات بحرية';

  @override
  String get dairy => 'ألبان';

  @override
  String get other => 'أخرى';

  @override
  String get logoUpload => 'رفع الشعار';

  @override
  String get logoUploadedSuccessfully => 'تم رفع الشعار بنجاح!';

  @override
  String get failedToUploadLogo => 'فشل في رفع الشعار';

  @override
  String get logoRemoved => 'تم إزالة الشعار';

  @override
  String get configureWorkingHours => 'تكوين ساعات العمل';

  @override
  String get pleaseConfigureWorkingHours => 'يرجى تكوين ساعات العمل';

  @override
  String get pleaseFixWorkingHoursConflicts => 'يرجى إصلاح تعارضات ساعات العمل';

  @override
  String get socialMediaOptional => 'وسائل التواصل الاجتماعي (اختياري)';

  @override
  String get facebook => 'فيسبوك';

  @override
  String get instagram => 'إنستغرام';

  @override
  String get tiktok => 'تيك توك';

  @override
  String get pleaseEnterValidUrl => 'يرجى إدخال رابط صحيح';

  @override
  String get reachThousandsOfFoodLovers => 'الوصول إلى آلاف محبي الطعام';

  @override
  String get detailedAnalyticsAndInsights => 'تحليلات ورؤى مفصلة';

  @override
  String get customerSupport => 'دعم العملاء على مدار الساعة';

  @override
  String get securePaymentProcessing => 'معالجة دفع آمنة';

  @override
  String get deliveryPartnerIntegration => 'تكامل شركاء التوصيل';

  @override
  String get connectionRestored => 'تم استعادة الاتصال';

  @override
  String get pleaseCheckInternetConnection => 'يرجى التحقق من اتصال الإنترنت';

  @override
  String get restaurantRequestSubmittedSuccessfully =>
      'تم إرسال طلب المطعم بنجاح!';

  @override
  String get failedToSubmitRequest => 'فشل في إرسال الطلب';

  @override
  String get formRestoredFromPreviousSession =>
      'تم استعادة النموذج من الجلسة السابقة';

  @override
  String get workingHours => 'ساعات العمل';

  @override
  String get monday => 'الاثنين';

  @override
  String get tuesday => 'الثلاثاء';

  @override
  String get wednesday => 'الأربعاء';

  @override
  String get thursday => 'الخميس';

  @override
  String get friday => 'الجمعة';

  @override
  String get saturday => 'السبت';

  @override
  String get sunday => 'الأحد';

  @override
  String get adrar => 'أدرار';

  @override
  String get chlef => 'الشلف';

  @override
  String get laghouat => 'الأغواط';

  @override
  String get oumElBouaghi => 'أم البواقي';

  @override
  String get batna => 'باتنة';

  @override
  String get bejaia => 'بجاية';

  @override
  String get biskra => 'بسكرة';

  @override
  String get bechar => 'بشار';

  @override
  String get blida => 'البليدة';

  @override
  String get bouira => 'البويرة';

  @override
  String get tamanrasset => 'تمنراست';

  @override
  String get tebessa => 'تبسة';

  @override
  String get tlemcen => 'تلمسان';

  @override
  String get tiaret => 'تيارت';

  @override
  String get tiziOuzou => 'تيزي وزو';

  @override
  String get algiers => 'الجزائر';

  @override
  String get djelfa => 'الجلفة';

  @override
  String get jijel => 'جيجل';

  @override
  String get setif => 'سطيف';

  @override
  String get saida => 'سعيدة';

  @override
  String get skikda => 'سكيكدة';

  @override
  String get sidiBelAbbes => 'سيدي بلعباس';

  @override
  String get annaba => 'عنابة';

  @override
  String get guelma => 'قالمة';

  @override
  String get constantine => 'قسنطينة';

  @override
  String get medea => 'المدية';

  @override
  String get mostaganem => 'مستغانم';

  @override
  String get msila => 'المسيلة';

  @override
  String get mascara => 'معسكر';

  @override
  String get ouargla => 'ورقلة';

  @override
  String get oran => 'وهران';

  @override
  String get elBayadh => 'البيض';

  @override
  String get illizi => 'إليزي';

  @override
  String get bordjBouArreridj => 'برج بوعريريج';

  @override
  String get boumerdes => 'بومرداس';

  @override
  String get elTarf => 'الطارف';

  @override
  String get tindouf => 'تندوف';

  @override
  String get tissemsilt => 'تيسمسيلت';

  @override
  String get elOued => 'الوادي';

  @override
  String get khenchela => 'خنشلة';

  @override
  String get soukAhras => 'سوق أهراس';

  @override
  String get tipaza => 'تيبازة';

  @override
  String get mila => 'ميلة';

  @override
  String get ainDefla => 'عين الدفلى';

  @override
  String get naama => 'النعامة';

  @override
  String get ainTemouchent => 'عين تيموشنت';

  @override
  String get ghardaia => 'غرداية';

  @override
  String get relizane => 'غليزان';

  @override
  String get timimoun => 'تيميمون';

  @override
  String get bordjBadjiMokhtar => 'برج باجي مختار';

  @override
  String get ouledDjellal => 'أولاد جلال';

  @override
  String get beniAbbes => 'بني عباس';

  @override
  String get inSalah => 'عين صالح';

  @override
  String get inGuezzam => 'عين قزام';

  @override
  String get touggourt => 'تقرت';

  @override
  String get djanet => 'جانت';

  @override
  String get elMghair => 'المغير';

  @override
  String get elMenia => 'المنيعة';

  @override
  String get previous => 'السابق';

  @override
  String get next => 'التالي';

  @override
  String get submitting => 'جاري الإرسال...';

  @override
  String get restaurantLogo => 'شعار المطعم';

  @override
  String get tapToAddLogo => 'اضغط لإضافة الشعار';

  @override
  String get upload => 'رفع';

  @override
  String get selectYourWilaya => 'اختر ولايتك';

  @override
  String get grocery => 'بقالة';

  @override
  String get handyman => 'حرفي';

  @override
  String get homeFood => 'طعام منزلي';

  @override
  String get plateNumberRequired => 'رقم اللوحة *';

  @override
  String get enterYourVehiclePlateNumber => 'أدخل رقم لوحة المركبة';

  @override
  String get validationPlateNumberRequired => 'يرجى إدخال رقم اللوحة';

  @override
  String get tapToViewFullSize => 'اضغط لعرض بالحجم الكامل';

  @override
  String get onePhoto => 'صورة واحدة';

  @override
  String get manageMenu => 'إدارة القائمة';

  @override
  String get userNotAuthenticated => 'المستخدم غير مصادق عليه';

  @override
  String get noRestaurantFound =>
      'لم يتم العثور على مطعم. يرجى زيارة لوحة التحكم أولاً.';

  @override
  String get failedToLoadMenuData => 'فشل في تحميل بيانات القائمة';

  @override
  String get allCuisines => 'جميع المطابخ';

  @override
  String get allCategories => 'جميع الفئات';

  @override
  String get name => 'الاسم';

  @override
  String get date => 'التاريخ';

  @override
  String get allItems => 'جميع العناصر';

  @override
  String get noItemsFoundMatchingFilters =>
      'لم يتم العثور على عناصر تطابق المرشحات الخاصة بك';

  @override
  String get noMenuItemsYet => 'لا توجد عناصر قائمة بعد';

  @override
  String get tapPlusButtonToAddFirstItem => 'اضغط على زر + لإضافة أول عنصر';

  @override
  String get loadingMoreItems => 'جاري تحميل المزيد من العناصر...';

  @override
  String get unavailable => 'غير متوفر';

  @override
  String get addItem => 'إضافة عنصر';

  @override
  String get menuItemUpdatedAndRefreshed => 'تم تحديث عنصر القائمة وتحديثه';

  @override
  String successfullyHidItem(String itemName) {
    return 'تم إخفاء \"$itemName\" بنجاح';
  }

  @override
  String successfullyShowedItem(String itemName) {
    return 'تم إظهار \"$itemName\" بنجاح';
  }

  @override
  String failedToUpdateAvailability(String itemName) {
    return 'فشل في تحديث التوفر لـ \"$itemName\"';
  }

  @override
  String errorUpdatingAvailability(String error) {
    return 'خطأ في تحديث التوفر: $error';
  }

  @override
  String get deleteMenuItem => 'حذف عنصر القائمة';

  @override
  String deleteMenuItemConfirmation(String itemName) {
    return 'هل أنت متأكد من أنك تريد حذف \"$itemName\"؟ لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String deletingItem(String itemName) {
    return 'جاري حذف \"$itemName\"...';
  }

  @override
  String successfullyDeletedItem(String itemName) {
    return 'تم حذف \"$itemName\" بنجاح';
  }

  @override
  String failedToDeleteItem(String itemName) {
    return 'فشل في حذف \"$itemName\"';
  }

  @override
  String errorDeletingItem(String error) {
    return 'خطأ في حذف العنصر: $error';
  }

  @override
  String get dietaryInfo => 'المعلومات الغذائية';

  @override
  String get spicy => 'حار';

  @override
  String get vegetarian => 'نباتي';

  @override
  String get traditional => 'تقليدي';

  @override
  String get glutenFree => 'خالي من الجلوتين';

  @override
  String get description => 'الوصف';

  @override
  String get mainIngredients => 'المكونات الرئيسية';

  @override
  String get listMainIngredientsIfNoDescription =>
      'سرد المكونات الرئيسية إذا لم يتم توفير وصف';

  @override
  String get addIngredient => 'إضافة مكون';

  @override
  String get defaultVariant => 'افتراضي';

  @override
  String get pricingAndSizes => 'التسعير والأحجام';

  @override
  String get variantsAndPricing => 'الخيارات والتسعير';

  @override
  String get addNewVariant => 'إضافة خيار جديد';

  @override
  String get createDifferentVersionsOfDish =>
      'إنشاء إصدارات مختلفة من طبقك (مثل كلاسيكي، حار، نباتي)';

  @override
  String get variantName => 'اسم الخيار';

  @override
  String get addVariant => 'إضافة خيار';

  @override
  String get eachVariantCanHaveDifferentSizes =>
      'يمكن أن يكون لكل خيار أحجام وأسعار مختلفة';

  @override
  String get forSelectedVariant => 'للخيار المحدد';

  @override
  String get standard => 'قياسي';

  @override
  String get dishSupplements => 'إضافات الطبق';

  @override
  String get addSupplement => 'إضافة مكمل';

  @override
  String get supplementExamples =>
      'أمثلة: شيدر +50 دج، جبنة إضافية +30 دج، صلصة حارة +20 دج';

  @override
  String get availableForAllVariants => 'متاح لجميع الخيارات';

  @override
  String get availableFor => 'متاح لـ';

  @override
  String get addFlavorAndSize => 'إضافة نكهة وحجم';

  @override
  String get availableForSelectedVariant => 'متاح للخيار المحدد';

  @override
  String get currentlyUnavailable => 'غير متوفر حالياً';

  @override
  String reviewTitle(String title) {
    return 'مراجعة $title';
  }

  @override
  String get reviewMenuItem => 'عنصر القائمة';

  @override
  String get reviewRestaurant => 'المطعم';

  @override
  String get reviewOrder => 'الطلب رقم';

  @override
  String get reviewMenuItemSubtitle => 'شارك رأيك حول هذا الطبق';

  @override
  String get reviewRestaurantSubtitle => 'كيف كانت تجربتك؟';

  @override
  String get reviewOrderSubtitle => 'قيّم تجربة طلبك الكاملة';

  @override
  String get howWouldYouRateIt => 'كيف تقيّمه؟';

  @override
  String get ratingPoor => 'ضعيف';

  @override
  String get ratingFair => 'مقبول';

  @override
  String get ratingGood => 'جيد';

  @override
  String get ratingVeryGood => 'جيد جداً';

  @override
  String get ratingExcellent => 'ممتاز';

  @override
  String get selectRating => 'اختر التقييم';

  @override
  String get shareYourExperience => 'شارك تجربتك';

  @override
  String get shareYourExperienceOptional => 'شارك تجربتك (اختياري)';

  @override
  String get tellOthersAboutExperience => 'أخبر الآخرين عن تجربتك...';

  @override
  String alsoEnjoying(String restaurantName) {
    return 'هل استمتعت أيضاً بـ $restaurantName؟';
  }

  @override
  String get shareRestaurantExperience => 'شارك تجربتك في المطعم';

  @override
  String get rateOverallService => 'قيّم الخدمة بشكل عام';

  @override
  String thankYouForRating(String restaurantName) {
    return 'شكراً لتقييمك لـ $restaurantName!';
  }

  @override
  String get addPhotos => 'إضافة صور';

  @override
  String get addPhotosOptional => 'إضافة صور (اختياري)';

  @override
  String get addPhotosButton => 'إضافة صور';

  @override
  String get addMorePhotos => 'إضافة المزيد من الصور';

  @override
  String get submitReview => 'إرسال المراجعة';

  @override
  String get restaurantReviewSubmittedSuccessfully =>
      'تم إرسال مراجعة المطعم بنجاح!';

  @override
  String get failedToSubmitRestaurantReview =>
      'فشل إرسال مراجعة المطعم. يرجى المحاولة مرة أخرى.';

  @override
  String get errorOccurredTryAgain => 'حدث خطأ. يرجى المحاولة مرة أخرى.';

  @override
  String get pleaseSelectValidRating => 'يرجى اختيار تقييم صحيح';

  @override
  String get menuItemNotFound => 'لم يتم العثور على عنصر القائمة';

  @override
  String get restaurantNotFound => 'لم يتم العثور على المطعم';

  @override
  String get orderNotFound => 'لم يتم العثور على الطلب';

  @override
  String get reviewSubmittedSuccessfully => 'تم إرسال المراجعة بنجاح!';

  @override
  String get failedToSubmitReview =>
      'فشل إرسال المراجعة. يرجى المحاولة مرة أخرى.';

  @override
  String get addReview => 'إضافة مراجعة';

  @override
  String get viewAllReviews => 'عرض جميع المراجعات';

  @override
  String get reviewsScreenTitle => 'المراجعات';

  @override
  String get noReviewsYet => 'لا توجد مراجعات بعد';

  @override
  String get beTheFirstToReview => 'كن أول من يراجع';

  @override
  String get oops => 'عذراً!';

  @override
  String get failedToLoadReviews => 'فشل في تحميل المراجعات';

  @override
  String get allReviews => 'جميع المراجعات';

  @override
  String get newest => 'الأحدث';

  @override
  String get oldest => 'الأقدم';

  @override
  String get highestRated => 'الأعلى تقييماً';

  @override
  String get lowestRated => 'الأقل تقييماً';

  @override
  String monthsAgo(int count, String plural) {
    return 'منذ $count $plural';
  }

  @override
  String get verifiedUser => 'مستخدم موثق';

  @override
  String get anonymousUser => 'مستخدم مجهول';

  @override
  String reviewForMenuItem(String menuItem) {
    return 'مراجعة لـ $menuItem';
  }

  @override
  String get prep => 'التحضير';

  @override
  String get closesAt => 'يُغلق على';

  @override
  String get opensAt => 'يُفتح على';

  @override
  String get viewReviews => 'عرض المراجعات';

  @override
  String get minOrder => 'الحد الأدنى';

  @override
  String get deliveryFeeShort => 'رسوم التوصيل';

  @override
  String get avgDeliveryTime => 'متوسط وقت التوصيل';

  @override
  String get limited => 'محدود';

  @override
  String get expired => 'منتهي الصلاحية';

  @override
  String get limitedTimeOffers => 'عروض لفترة محدودة';

  @override
  String get free => 'مجاني';

  @override
  String get removedIngredients => 'المكونات المحذوفة';

  @override
  String get itemsLabel => 'العناصر';

  @override
  String get noItemsSelected => 'لم يتم اختيار أي عناصر';

  @override
  String get errorLoadingOrderSummary => 'خطأ في تحميل ملخص الطلب';
}
