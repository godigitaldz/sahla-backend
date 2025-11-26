import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Sahla'**
  String get appName;

  /// No description provided for @createTask.
  ///
  /// In en, this message translates to:
  /// **'Create Ifrili Task'**
  String get createTask;

  /// No description provided for @describeYourNeed.
  ///
  /// In en, this message translates to:
  /// **'Describe your need'**
  String get describeYourNeed;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @secondPhoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Second phone (optional)'**
  String get secondPhoneOptional;

  /// No description provided for @useSecondPhoneAsPrimary.
  ///
  /// In en, this message translates to:
  /// **'Use second phone as primary'**
  String get useSecondPhoneAsPrimary;

  /// No description provided for @locationPurpose.
  ///
  /// In en, this message translates to:
  /// **'Location purpose'**
  String get locationPurpose;

  /// No description provided for @addAnotherLocation.
  ///
  /// In en, this message translates to:
  /// **'Add another location'**
  String get addAnotherLocation;

  /// No description provided for @added.
  ///
  /// In en, this message translates to:
  /// **'Added: {count}'**
  String added(Object count);

  /// No description provided for @taskImageOptional.
  ///
  /// In en, this message translates to:
  /// **'Task Image (Optional)'**
  String get taskImageOptional;

  /// No description provided for @addImage.
  ///
  /// In en, this message translates to:
  /// **'Add Image'**
  String get addImage;

  /// No description provided for @tapToSelectFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Tap to select from gallery'**
  String get tapToSelectFromGallery;

  /// No description provided for @changeImage.
  ///
  /// In en, this message translates to:
  /// **'Change Image'**
  String get changeImage;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get uploading;

  /// No description provided for @pickDateTime.
  ///
  /// In en, this message translates to:
  /// **'Pick date & time'**
  String get pickDateTime;

  /// No description provided for @createTaskButton.
  ///
  /// In en, this message translates to:
  /// **'Create Task'**
  String get createTaskButton;

  /// No description provided for @creating.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get creating;

  /// No description provided for @taskCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Task created successfully'**
  String get taskCreatedSuccessfully;

  /// No description provided for @tasksDescription.
  ///
  /// In en, this message translates to:
  /// **'Tasks Description:'**
  String get tasksDescription;

  /// No description provided for @tasksLocations.
  ///
  /// In en, this message translates to:
  /// **'Tasks Locations:'**
  String get tasksLocations;

  /// No description provided for @contactPhone.
  ///
  /// In en, this message translates to:
  /// **'Contact Phone:'**
  String get contactPhone;

  /// No description provided for @imagesPreview.
  ///
  /// In en, this message translates to:
  /// **'Images Preview:'**
  String get imagesPreview;

  /// No description provided for @noImages.
  ///
  /// In en, this message translates to:
  /// **'No images'**
  String get noImages;

  /// No description provided for @backToEdit.
  ///
  /// In en, this message translates to:
  /// **'Back to edit'**
  String get backToEdit;

  /// No description provided for @selectLocationOnMap.
  ///
  /// In en, this message translates to:
  /// **'Select a location on the map...'**
  String get selectLocationOnMap;

  /// No description provided for @gettingAddress.
  ///
  /// In en, this message translates to:
  /// **'Getting address...'**
  String get gettingAddress;

  /// No description provided for @loadingMap.
  ///
  /// In en, this message translates to:
  /// **'Loading map...'**
  String get loadingMap;

  /// No description provided for @confirmLocation.
  ///
  /// In en, this message translates to:
  /// **'Confirm Location'**
  String get confirmLocation;

  /// No description provided for @getCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Get current location'**
  String get getCurrentLocation;

  /// No description provided for @useYourCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use your current location'**
  String get useYourCurrentLocation;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchRestaurants.
  ///
  /// In en, this message translates to:
  /// **'Search restaurants...'**
  String get searchRestaurants;

  /// No description provided for @searchMenuItems.
  ///
  /// In en, this message translates to:
  /// **'Search menu items...'**
  String get searchMenuItems;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @cuisines.
  ///
  /// In en, this message translates to:
  /// **'Cuisines'**
  String get cuisines;

  /// No description provided for @restaurants.
  ///
  /// In en, this message translates to:
  /// **'Restaurants'**
  String get restaurants;

  /// No description provided for @menuItems.
  ///
  /// In en, this message translates to:
  /// **'Menu items'**
  String get menuItems;

  /// No description provided for @freeDelivery.
  ///
  /// In en, this message translates to:
  /// **'Free delivery'**
  String get freeDelivery;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @cuisine.
  ///
  /// In en, this message translates to:
  /// **'Cuisine'**
  String get cuisine;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @selectCuisineType.
  ///
  /// In en, this message translates to:
  /// **'Select Cuisine Type'**
  String get selectCuisineType;

  /// No description provided for @selectCategories.
  ///
  /// In en, this message translates to:
  /// **'Select Categories'**
  String get selectCategories;

  /// No description provided for @minimumOrderRange.
  ///
  /// In en, this message translates to:
  /// **'Minimum Order Range'**
  String get minimumOrderRange;

  /// No description provided for @priceRange.
  ///
  /// In en, this message translates to:
  /// **'Price Range'**
  String get priceRange;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @noCuisinesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No cuisines available'**
  String get noCuisinesAvailable;

  /// No description provided for @noCategoriesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No categories available'**
  String get noCategoriesAvailable;

  /// No description provided for @loadingCategories.
  ///
  /// In en, this message translates to:
  /// **'Loading categories...'**
  String get loadingCategories;

  /// No description provided for @addNewDrinksMenu.
  ///
  /// In en, this message translates to:
  /// **'Add New Drinks Menu'**
  String get addNewDrinksMenu;

  /// No description provided for @addDrinksByCreatingVariants.
  ///
  /// In en, this message translates to:
  /// **'Add drinks by creating variants. Each variant represents a different drink (e.g., Coca Cola, Fanta, Sprite).'**
  String get addDrinksByCreatingVariants;

  /// No description provided for @smartDetectionActive.
  ///
  /// In en, this message translates to:
  /// **'Smart Detection Active'**
  String get smartDetectionActive;

  /// No description provided for @smartDetectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Each variant will be automatically matched with the correct drink image from our bucket based on its name (e.g., Coca Cola → Coca Cola image).'**
  String get smartDetectionDescription;

  /// No description provided for @foodImages.
  ///
  /// In en, this message translates to:
  /// **'Food Images'**
  String get foodImages;

  /// No description provided for @reviewYourMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Review Your Menu Item'**
  String get reviewYourMenuItem;

  /// No description provided for @uploadFoodImages.
  ///
  /// In en, this message translates to:
  /// **'Upload Food Images'**
  String get uploadFoodImages;

  /// No description provided for @addHighQualityPhotos.
  ///
  /// In en, this message translates to:
  /// **'Add high-quality photos of your dish (at least 1 required)'**
  String get addHighQualityPhotos;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @atLeastOneImageRequired.
  ///
  /// In en, this message translates to:
  /// **'At least one image is required'**
  String get atLeastOneImageRequired;

  /// No description provided for @notSelected.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get notSelected;

  /// No description provided for @notEntered.
  ///
  /// In en, this message translates to:
  /// **'Not entered'**
  String get notEntered;

  /// No description provided for @noneAdded.
  ///
  /// In en, this message translates to:
  /// **'None added'**
  String get noneAdded;

  /// No description provided for @noneUploaded.
  ///
  /// In en, this message translates to:
  /// **'None uploaded'**
  String get noneUploaded;

  /// No description provided for @images.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get images;

  /// No description provided for @min.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get min;

  /// No description provided for @max.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get max;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'to'**
  String get to;

  /// No description provided for @preparationTime.
  ///
  /// In en, this message translates to:
  /// **'Preparation Time'**
  String get preparationTime;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minutes;

  /// No description provided for @unknownRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Unknown Restaurant'**
  String get unknownRestaurant;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'DZD'**
  String get currency;

  /// No description provided for @noItemsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No items available'**
  String get noItemsAvailable;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @noMenuItemsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No menu items available'**
  String get noMenuItemsAvailable;

  /// No description provided for @debugInfoWillAppearInConsole.
  ///
  /// In en, this message translates to:
  /// **'Debugging info will appear in console logs'**
  String get debugInfoWillAppearInConsole;

  /// No description provided for @failedToLoadMenuItems.
  ///
  /// In en, this message translates to:
  /// **'Failed to load menu items'**
  String get failedToLoadMenuItems;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @noItemsFoundForSearch.
  ///
  /// In en, this message translates to:
  /// **'No items found for \"{searchQuery}\"'**
  String noItemsFoundForSearch(Object searchQuery);

  /// No description provided for @noItemsMatchFilters.
  ///
  /// In en, this message translates to:
  /// **'No items match your filters'**
  String get noItemsMatchFilters;

  /// No description provided for @tryAdjustingSearchTerms.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your search terms or browse all available items.'**
  String get tryAdjustingSearchTerms;

  /// No description provided for @tryRemovingFilters.
  ///
  /// In en, this message translates to:
  /// **'Try removing some filters or adjusting your search criteria to find more items.'**
  String get tryRemovingFilters;

  /// No description provided for @checkBackLaterForNewItems.
  ///
  /// In en, this message translates to:
  /// **'Check back later for new menu items or try refreshing the page.'**
  String get checkBackLaterForNewItems;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear Filters'**
  String get clearFilters;

  /// No description provided for @browseAllItems.
  ///
  /// In en, this message translates to:
  /// **'Browse All Items'**
  String get browseAllItems;

  /// No description provided for @bestChoices.
  ///
  /// In en, this message translates to:
  /// **'Best Choices'**
  String get bestChoices;

  /// No description provided for @noOffersAvailable.
  ///
  /// In en, this message translates to:
  /// **'No offers available'**
  String get noOffersAvailable;

  /// No description provided for @checkBackLaterForNewDeals.
  ///
  /// In en, this message translates to:
  /// **'Check back later for new deals'**
  String get checkBackLaterForNewDeals;

  /// No description provided for @addToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to Cart'**
  String get addToCart;

  /// No description provided for @confirmOrder.
  ///
  /// In en, this message translates to:
  /// **'Confirm Order'**
  String get confirmOrder;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @item.
  ///
  /// In en, this message translates to:
  /// **'item'**
  String get item;

  /// No description provided for @addedToCart.
  ///
  /// In en, this message translates to:
  /// **'added to cart'**
  String get addedToCart;

  /// No description provided for @unknownItem.
  ///
  /// In en, this message translates to:
  /// **'Unknown Item'**
  String get unknownItem;

  /// No description provided for @addedToFavorites.
  ///
  /// In en, this message translates to:
  /// **'added to favorites'**
  String get addedToFavorites;

  /// No description provided for @removedFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'removed from favorites'**
  String get removedFromFavorites;

  /// No description provided for @failedToUpdateFavorite.
  ///
  /// In en, this message translates to:
  /// **'Failed to update favorite'**
  String get failedToUpdateFavorite;

  /// No description provided for @specialNote.
  ///
  /// In en, this message translates to:
  /// **'Special Note'**
  String get specialNote;

  /// No description provided for @addSpecialInstructions.
  ///
  /// In en, this message translates to:
  /// **'Add any special instructions...'**
  String get addSpecialInstructions;

  /// No description provided for @mainItemQuantity.
  ///
  /// In en, this message translates to:
  /// **'Main Item Quantity'**
  String get mainItemQuantity;

  /// No description provided for @saveAndAddAnotherOrder.
  ///
  /// In en, this message translates to:
  /// **'Save & Add Another Order'**
  String get saveAndAddAnotherOrder;

  /// No description provided for @totalPrice.
  ///
  /// In en, this message translates to:
  /// **'Total Price'**
  String get totalPrice;

  /// No description provided for @filterRestaurants.
  ///
  /// In en, this message translates to:
  /// **'Filter Restaurants'**
  String get filterRestaurants;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @applyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply Filters'**
  String get applyFilters;

  /// No description provided for @enterCityOrArea.
  ///
  /// In en, this message translates to:
  /// **'Enter city or area'**
  String get enterCityOrArea;

  /// No description provided for @map.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// No description provided for @minimumRating.
  ///
  /// In en, this message translates to:
  /// **'Minimum Rating'**
  String get minimumRating;

  /// No description provided for @deliveryFeeRange.
  ///
  /// In en, this message translates to:
  /// **'Delivery Fee Range'**
  String get deliveryFeeRange;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @openNow.
  ///
  /// In en, this message translates to:
  /// **'Open Now'**
  String get openNow;

  /// No description provided for @cuisineType.
  ///
  /// In en, this message translates to:
  /// **'Cuisine Type'**
  String get cuisineType;

  /// No description provided for @pleaseSelectCategoryFirst.
  ///
  /// In en, this message translates to:
  /// **'Select category first'**
  String get pleaseSelectCategoryFirst;

  /// No description provided for @restaurantCategory.
  ///
  /// In en, this message translates to:
  /// **'Restaurant Category'**
  String get restaurantCategory;

  /// No description provided for @selectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select category'**
  String get selectCategory;

  /// No description provided for @pleaseSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Please select a category'**
  String get pleaseSelectCategory;

  /// No description provided for @selectedLocation.
  ///
  /// In en, this message translates to:
  /// **'Selected Location'**
  String get selectedLocation;

  /// No description provided for @tapToSelectLocation.
  ///
  /// In en, this message translates to:
  /// **'Tap to select location'**
  String get tapToSelectLocation;

  /// No description provided for @pleaseSelectLocation.
  ///
  /// In en, this message translates to:
  /// **'Please select a location on the map'**
  String get pleaseSelectLocation;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied'**
  String get locationPermissionDenied;

  /// No description provided for @locationPermissionsPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permissions are permanently denied. Please enable in settings.'**
  String get locationPermissionsPermanentlyDenied;

  /// No description provided for @locationServicesDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled'**
  String get locationServicesDisabled;

  /// No description provided for @failedToGetCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Failed to get current location'**
  String get failedToGetCurrentLocation;

  /// No description provided for @delivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get delivery;

  /// No description provided for @pickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get pickup;

  /// No description provided for @dineIn.
  ///
  /// In en, this message translates to:
  /// **'Dine-in'**
  String get dineIn;

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @removeFromCart.
  ///
  /// In en, this message translates to:
  /// **'Remove from Cart'**
  String get removeFromCart;

  /// No description provided for @viewCart.
  ///
  /// In en, this message translates to:
  /// **'View Cart'**
  String get viewCart;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get rememberMe;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationSettings;

  /// No description provided for @enableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get enableNotifications;

  /// No description provided for @disableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Disable Notifications'**
  String get disableNotifications;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @french.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get french;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @systemTheme.
  ///
  /// In en, this message translates to:
  /// **'System Theme'**
  String get systemTheme;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUs;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get info;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @pleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait...'**
  String get pleaseWait;

  /// No description provided for @noInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noInternetConnection;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @enableLocation.
  ///
  /// In en, this message translates to:
  /// **'Enable location'**
  String get enableLocation;

  /// No description provided for @locationPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Location permission required'**
  String get locationPermissionRequired;

  /// No description provided for @cameraPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera permission denied'**
  String get cameraPermissionDenied;

  /// No description provided for @cameraPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Camera permission required'**
  String get cameraPermissionRequired;

  /// No description provided for @galleryPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Gallery permission required'**
  String get galleryPermissionRequired;

  /// No description provided for @searchResultsFor.
  ///
  /// In en, this message translates to:
  /// **'Search results for'**
  String get searchResultsFor;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @addToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addToFavorites;

  /// No description provided for @removeFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFromFavorites;

  /// No description provided for @cart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// No description provided for @cartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get cartEmpty;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total:'**
  String get total;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @tax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get tax;

  /// No description provided for @deliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery Fee'**
  String get deliveryFee;

  /// No description provided for @serviceFee.
  ///
  /// In en, this message translates to:
  /// **'Service Fee'**
  String get serviceFee;

  /// No description provided for @order.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get order;

  /// No description provided for @orderPlaced.
  ///
  /// In en, this message translates to:
  /// **'Order Placed'**
  String get orderPlaced;

  /// No description provided for @orderConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Order Confirmed'**
  String get orderConfirmed;

  /// No description provided for @orderPreparing.
  ///
  /// In en, this message translates to:
  /// **'Order Preparing'**
  String get orderPreparing;

  /// No description provided for @orderReady.
  ///
  /// In en, this message translates to:
  /// **'Order Ready'**
  String get orderReady;

  /// No description provided for @orderPickedUp.
  ///
  /// In en, this message translates to:
  /// **'Order Picked Up'**
  String get orderPickedUp;

  /// No description provided for @orderDelivered.
  ///
  /// In en, this message translates to:
  /// **'Order Delivered'**
  String get orderDelivered;

  /// No description provided for @orderCancelled.
  ///
  /// In en, this message translates to:
  /// **'Order Cancelled'**
  String get orderCancelled;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// No description provided for @cashOnDelivery.
  ///
  /// In en, this message translates to:
  /// **'Cash on Delivery'**
  String get cashOnDelivery;

  /// No description provided for @cardPayment.
  ///
  /// In en, this message translates to:
  /// **'Card Payment'**
  String get cardPayment;

  /// No description provided for @walletPayment.
  ///
  /// In en, this message translates to:
  /// **'Wallet Payment'**
  String get walletPayment;

  /// No description provided for @restaurant.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get restaurant;

  /// No description provided for @restaurantDetails.
  ///
  /// In en, this message translates to:
  /// **'Restaurant Details'**
  String get restaurantDetails;

  /// No description provided for @restaurantMenu.
  ///
  /// In en, this message translates to:
  /// **'Restaurant Menu'**
  String get restaurantMenu;

  /// No description provided for @restaurantReviews.
  ///
  /// In en, this message translates to:
  /// **'Restaurant Reviews'**
  String get restaurantReviews;

  /// No description provided for @restaurantHours.
  ///
  /// In en, this message translates to:
  /// **'Restaurant Hours'**
  String get restaurantHours;

  /// No description provided for @restaurantLocation.
  ///
  /// In en, this message translates to:
  /// **'Restaurant Location'**
  String get restaurantLocation;

  /// No description provided for @restaurantContact.
  ///
  /// In en, this message translates to:
  /// **'Restaurant Contact'**
  String get restaurantContact;

  /// No description provided for @deliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Delivery Address'**
  String get deliveryAddress;

  /// No description provided for @addAddress.
  ///
  /// In en, this message translates to:
  /// **'Add Address'**
  String get addAddress;

  /// No description provided for @editAddress.
  ///
  /// In en, this message translates to:
  /// **'Edit Address'**
  String get editAddress;

  /// No description provided for @selectAddress.
  ///
  /// In en, this message translates to:
  /// **'Select Address'**
  String get selectAddress;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @personalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInformation;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get accountSettings;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @signInToContinue.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInToContinue;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @verification.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get verification;

  /// No description provided for @verifyPhone.
  ///
  /// In en, this message translates to:
  /// **'Verify Phone'**
  String get verifyPhone;

  /// No description provided for @verifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Verify Email'**
  String get verifyEmail;

  /// No description provided for @verificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification Code'**
  String get verificationCode;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendCode;

  /// No description provided for @allYourNeedsInOneApp.
  ///
  /// In en, this message translates to:
  /// **'All Your Needs In One App !'**
  String get allYourNeedsInOneApp;

  /// No description provided for @enterPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter phone number'**
  String get enterPhoneNumber;

  /// No description provided for @changePhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Change Phone Number'**
  String get changePhoneNumber;

  /// No description provided for @verifyAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Verify & Continue'**
  String get verifyAndContinue;

  /// Continue button text
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @continueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get continueAsGuest;

  /// No description provided for @didntReceiveCode.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive the code? '**
  String get didntReceiveCode;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String resendIn(int seconds);

  /// No description provided for @requestNewCode.
  ///
  /// In en, this message translates to:
  /// **'Request New Code'**
  String get requestNewCode;

  /// No description provided for @codeExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'Code expires in {minutes}m {seconds}s'**
  String codeExpiresIn(int minutes, int seconds);

  /// No description provided for @verificationCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'Verification code has expired'**
  String get verificationCodeExpired;

  /// No description provided for @verificationCodeExpiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Verification code has expired. Please request a new one.'**
  String get verificationCodeExpiredMessage;

  /// No description provided for @sixDigitCode.
  ///
  /// In en, this message translates to:
  /// **'Please enter a 6-digit code'**
  String get sixDigitCode;

  /// No description provided for @byContinuingYouAgree.
  ///
  /// In en, this message translates to:
  /// **'By continuing you agree to our '**
  String get byContinuingYouAgree;

  /// No description provided for @byClickingContinueYouAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'By clicking on the button continue, you acknowledge that you have read and accepted the '**
  String get byClickingContinueYouAcknowledge;

  /// No description provided for @verificationCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Verification code sent to +{countryCode}{phoneNumber}'**
  String verificationCodeSentTo(String countryCode, String phoneNumber);

  /// No description provided for @validationRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get validationRequired;

  /// No description provided for @validationEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address'**
  String get validationEmailInvalid;

  /// No description provided for @validationPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number (at least 10 digits)'**
  String get validationPhoneInvalid;

  /// No description provided for @validationPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password too short'**
  String get validationPasswordTooShort;

  /// No description provided for @validationPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get validationPasswordMismatch;

  /// No description provided for @logoutConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get logoutConfirmation;

  /// No description provided for @tapToChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Tap to change photo'**
  String get tapToChangePhoto;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @fullNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Full Name *'**
  String get fullNameRequired;

  /// No description provided for @nameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters'**
  String get nameTooShort;

  /// No description provided for @dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dateOfBirth;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @noDraftTasks.
  ///
  /// In en, this message translates to:
  /// **'No draft tasks to review'**
  String get noDraftTasks;

  /// No description provided for @taskDescription.
  ///
  /// In en, this message translates to:
  /// **'Task Description:'**
  String get taskDescription;

  /// No description provided for @taskLocations.
  ///
  /// In en, this message translates to:
  /// **'Task Locations'**
  String get taskLocations;

  /// No description provided for @noPhoneProvided.
  ///
  /// In en, this message translates to:
  /// **'No phone provided'**
  String get noPhoneProvided;

  /// No description provided for @primaryLocation.
  ///
  /// In en, this message translates to:
  /// **'Primary Location'**
  String get primaryLocation;

  /// No description provided for @additionalLocation.
  ///
  /// In en, this message translates to:
  /// **'Additional Location'**
  String get additionalLocation;

  /// No description provided for @unknownAddress.
  ///
  /// In en, this message translates to:
  /// **'Unknown address'**
  String get unknownAddress;

  /// No description provided for @taskProcess.
  ///
  /// In en, this message translates to:
  /// **'Task Process'**
  String get taskProcess;

  /// No description provided for @taskDetails.
  ///
  /// In en, this message translates to:
  /// **'Task Details'**
  String get taskDetails;

  /// No description provided for @taskLocationsCount.
  ///
  /// In en, this message translates to:
  /// **'Task Locations'**
  String get taskLocationsCount;

  /// No description provided for @tapToViewMap.
  ///
  /// In en, this message translates to:
  /// **'Tap to view map with all locations'**
  String get tapToViewMap;

  /// No description provided for @unknownPurpose.
  ///
  /// In en, this message translates to:
  /// **'Location purpose'**
  String get unknownPurpose;

  /// No description provided for @deliverTo.
  ///
  /// In en, this message translates to:
  /// **'Deliver to'**
  String get deliverTo;

  /// No description provided for @tapToEnableLocation.
  ///
  /// In en, this message translates to:
  /// **'Tap to enable location access'**
  String get tapToEnableLocation;

  /// No description provided for @gpsDisabled.
  ///
  /// In en, this message translates to:
  /// **'GPS disabled - tap to enable'**
  String get gpsDisabled;

  /// No description provided for @detectingLocation.
  ///
  /// In en, this message translates to:
  /// **'Detecting location...'**
  String get detectingLocation;

  /// No description provided for @locationOptions.
  ///
  /// In en, this message translates to:
  /// **'Location Options'**
  String get locationOptions;

  /// No description provided for @selectOnMap.
  ///
  /// In en, this message translates to:
  /// **'Select on Map'**
  String get selectOnMap;

  /// No description provided for @chooseLocationInteractive.
  ///
  /// In en, this message translates to:
  /// **'Choose location using interactive map'**
  String get chooseLocationInteractive;

  /// No description provided for @refreshLocation.
  ///
  /// In en, this message translates to:
  /// **'Refresh Location'**
  String get refreshLocation;

  /// No description provided for @getCurrentLocationBetter.
  ///
  /// In en, this message translates to:
  /// **'Get current location with better accuracy'**
  String get getCurrentLocationBetter;

  /// No description provided for @noMin.
  ///
  /// In en, this message translates to:
  /// **'No minimum'**
  String get noMin;

  /// No description provided for @estimatedDeliveryTime.
  ///
  /// In en, this message translates to:
  /// **'Estimated delivery time'**
  String get estimatedDeliveryTime;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @deliveryTime.
  ///
  /// In en, this message translates to:
  /// **'Delivery time'**
  String get deliveryTime;

  /// No description provided for @alphabetical.
  ///
  /// In en, this message translates to:
  /// **'Alphabetical'**
  String get alphabetical;

  /// No description provided for @popular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get popular;

  /// No description provided for @trending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get trending;

  /// No description provided for @newItem.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newItem;

  /// No description provided for @featured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get featured;

  /// No description provided for @menuItemDetails.
  ///
  /// In en, this message translates to:
  /// **'Menu Item Details'**
  String get menuItemDetails;

  /// No description provided for @ingredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get ingredients;

  /// No description provided for @allergens.
  ///
  /// In en, this message translates to:
  /// **'Allergens'**
  String get allergens;

  /// No description provided for @nutritionalInfo.
  ///
  /// In en, this message translates to:
  /// **'Nutritional Information'**
  String get nutritionalInfo;

  /// No description provided for @customize.
  ///
  /// In en, this message translates to:
  /// **'Customize'**
  String get customize;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @activeOrders.
  ///
  /// In en, this message translates to:
  /// **'Active Orders'**
  String get activeOrders;

  /// No description provided for @orderSummary.
  ///
  /// In en, this message translates to:
  /// **'Order Summary'**
  String get orderSummary;

  /// No description provided for @orderDetails.
  ///
  /// In en, this message translates to:
  /// **'Order Details'**
  String get orderDetails;

  /// No description provided for @trackOrder.
  ///
  /// In en, this message translates to:
  /// **'Track Order'**
  String get trackOrder;

  /// No description provided for @orderStatus.
  ///
  /// In en, this message translates to:
  /// **'Order Status'**
  String get orderStatus;

  /// No description provided for @estimatedArrival.
  ///
  /// In en, this message translates to:
  /// **'Estimated Arrival'**
  String get estimatedArrival;

  /// No description provided for @delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get delivered;

  /// No description provided for @preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get preparing;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @pickedUp.
  ///
  /// In en, this message translates to:
  /// **'Picked Up'**
  String get pickedUp;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @promoCode.
  ///
  /// In en, this message translates to:
  /// **'Promo Code'**
  String get promoCode;

  /// No description provided for @applyPromo.
  ///
  /// In en, this message translates to:
  /// **'Apply Promo Code'**
  String get applyPromo;

  /// No description provided for @addNewAddress.
  ///
  /// In en, this message translates to:
  /// **'Add New Address'**
  String get addNewAddress;

  /// No description provided for @changeAddress.
  ///
  /// In en, this message translates to:
  /// **'Change Address'**
  String get changeAddress;

  /// No description provided for @orderUpdates.
  ///
  /// In en, this message translates to:
  /// **'Order Updates'**
  String get orderUpdates;

  /// No description provided for @promotionalOffers.
  ///
  /// In en, this message translates to:
  /// **'Promotional Offers'**
  String get promotionalOffers;

  /// No description provided for @newRestaurants.
  ///
  /// In en, this message translates to:
  /// **'New Restaurants'**
  String get newRestaurants;

  /// No description provided for @deliveryUpdates.
  ///
  /// In en, this message translates to:
  /// **'Delivery Updates'**
  String get deliveryUpdates;

  /// No description provided for @checkBackLater.
  ///
  /// In en, this message translates to:
  /// **'Check back later'**
  String get checkBackLater;

  /// No description provided for @loadingCuisines.
  ///
  /// In en, this message translates to:
  /// **'Loading cuisines...'**
  String get loadingCuisines;

  /// No description provided for @pleaseSelectCuisineType.
  ///
  /// In en, this message translates to:
  /// **'Please select a cuisine type'**
  String get pleaseSelectCuisineType;

  /// No description provided for @noMinimum.
  ///
  /// In en, this message translates to:
  /// **'No minimum'**
  String get noMinimum;

  /// No description provided for @algerianDinar.
  ///
  /// In en, this message translates to:
  /// **'DA'**
  String get algerianDinar;

  /// No description provided for @restaurantInfoFormat.
  ///
  /// In en, this message translates to:
  /// **'{deliveryTime} • {minimumOrder} • {city} • {deliveryFee} • {workingHours}'**
  String restaurantInfoFormat(
      Object city,
      Object deliveryFee,
      Object deliveryTime,
      Object minimumCommande,
      Object minimumOrder,
      Object workingHours);

  /// No description provided for @restaurantNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Restaurant name: {restaurantName}'**
  String restaurantNameLabel(Object restaurantName);

  /// No description provided for @restaurantDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Restaurant details: {infoText}'**
  String restaurantDetailsLabel(Object infoText);

  /// No description provided for @doubleTapToRemove.
  ///
  /// In en, this message translates to:
  /// **'Double tap to remove {restaurantName} from favorites'**
  String doubleTapToRemove(Object restaurantName);

  /// No description provided for @doubleTapToAdd.
  ///
  /// In en, this message translates to:
  /// **'Double tap to add {restaurantName} to favorites'**
  String doubleTapToAdd(Object restaurantName);

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not Available'**
  String get notAvailable;

  /// No description provided for @priceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get priceLabel;

  /// No description provided for @ratingLabel.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get ratingLabel;

  /// No description provided for @reviewsLabel.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviewsLabel;

  /// No description provided for @distanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distanceLabel;

  /// No description provided for @deliveryTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Delivery Time'**
  String get deliveryTimeLabel;

  /// No description provided for @cuisineLabel.
  ///
  /// In en, this message translates to:
  /// **'Cuisine'**
  String get cuisineLabel;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @featuredLabel.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get featuredLabel;

  /// No description provided for @popularLabel.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get popularLabel;

  /// No description provided for @trendingLabel.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get trendingLabel;

  /// No description provided for @newLabel.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newLabel;

  /// No description provided for @bestChoicesLabel.
  ///
  /// In en, this message translates to:
  /// **'Best Choices'**
  String get bestChoicesLabel;

  /// No description provided for @viewAllLabel.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAllLabel;

  /// No description provided for @restaurantsLabel.
  ///
  /// In en, this message translates to:
  /// **'Restaurants'**
  String get restaurantsLabel;

  /// No description provided for @menuItemsLabel.
  ///
  /// In en, this message translates to:
  /// **'Menu Items'**
  String get menuItemsLabel;

  /// No description provided for @searchRestaurantsLabel.
  ///
  /// In en, this message translates to:
  /// **'Search restaurants'**
  String get searchRestaurantsLabel;

  /// No description provided for @filterLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filterLabel;

  /// No description provided for @applyLabel.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyLabel;

  /// No description provided for @clearAllLabel.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAllLabel;

  /// No description provided for @priceRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Price Range'**
  String get priceRangeLabel;

  /// No description provided for @sortByLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortByLabel;

  /// No description provided for @distanceSort.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distanceSort;

  /// No description provided for @ratingSort.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get ratingSort;

  /// No description provided for @deliveryTimeSort.
  ///
  /// In en, this message translates to:
  /// **'Delivery time'**
  String get deliveryTimeSort;

  /// No description provided for @alphabeticalSort.
  ///
  /// In en, this message translates to:
  /// **'Alphabetical'**
  String get alphabeticalSort;

  /// No description provided for @noRestaurantsFound.
  ///
  /// In en, this message translates to:
  /// **'No restaurants found'**
  String get noRestaurantsFound;

  /// No description provided for @tryAdjustingSearch.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your search criteria'**
  String get tryAdjustingSearch;

  /// No description provided for @loadingRestaurants.
  ///
  /// In en, this message translates to:
  /// **'Loading restaurants...'**
  String get loadingRestaurants;

  /// No description provided for @errorLoadingRestaurants.
  ///
  /// In en, this message translates to:
  /// **'Error loading restaurants'**
  String get errorLoadingRestaurants;

  /// No description provided for @retryLabel.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryLabel;

  /// No description provided for @restaurantsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} restaurants'**
  String restaurantsCount(Object count);

  /// No description provided for @minimumOrderLabel.
  ///
  /// In en, this message translates to:
  /// **'Min Order'**
  String get minimumOrderLabel;

  /// No description provided for @deliveryFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Delivery Fee'**
  String get deliveryFeeLabel;

  /// No description provided for @cityLabel.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get cityLabel;

  /// No description provided for @workingHoursLabel.
  ///
  /// In en, this message translates to:
  /// **'Working Hours'**
  String get workingHoursLabel;

  /// No description provided for @openLabel.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openLabel;

  /// No description provided for @closedLabel.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closedLabel;

  /// No description provided for @minLabel.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minLabel;

  /// No description provided for @noMinLabel.
  ///
  /// In en, this message translates to:
  /// **'No Min'**
  String get noMinLabel;

  /// No description provided for @freeDeliveryLabel.
  ///
  /// In en, this message translates to:
  /// **'Free delivery'**
  String get freeDeliveryLabel;

  /// No description provided for @restaurantLogoLabel.
  ///
  /// In en, this message translates to:
  /// **'{restaurantName} restaurant logo'**
  String restaurantLogoLabel(Object restaurantName);

  /// No description provided for @viewAllButton.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAllButton;

  /// No description provided for @liveUpdatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Live Updates'**
  String get liveUpdatesTitle;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String minutesAgo(Object min, Object minutes);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} {plural} ago'**
  String hoursAgo(int count, String plural);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} {plural} ago'**
  String daysAgo(int count, String plural);

  /// No description provided for @todayLabel.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayLabel;

  /// No description provided for @tomorrowLabel.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrowLabel;

  /// No description provided for @openingHoursLabel.
  ///
  /// In en, this message translates to:
  /// **'Opening Hours'**
  String get openingHoursLabel;

  /// No description provided for @closingHoursLabel.
  ///
  /// In en, this message translates to:
  /// **'Closing Hours'**
  String get closingHoursLabel;

  /// No description provided for @menuItemNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Menu item: {itemName}'**
  String menuItemNameLabel(Object itemName);

  /// No description provided for @menuItemName.
  ///
  /// In en, this message translates to:
  /// **'Menu Item Name'**
  String get menuItemName;

  /// No description provided for @enterTheNameOfYourMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Enter the name of your menu item'**
  String get enterTheNameOfYourMenuItem;

  /// No description provided for @menuItemPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price: {price} DA'**
  String menuItemPriceLabel(Object price);

  /// No description provided for @menuItemDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description: {description}'**
  String menuItemDescriptionLabel(Object description);

  /// No description provided for @ingredientsLabel.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get ingredientsLabel;

  /// No description provided for @allergensLabel.
  ///
  /// In en, this message translates to:
  /// **'Allergens'**
  String get allergensLabel;

  /// No description provided for @nutritionalInfoLabel.
  ///
  /// In en, this message translates to:
  /// **'Nutritional Information'**
  String get nutritionalInfoLabel;

  /// No description provided for @customizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Customize'**
  String get customizeLabel;

  /// No description provided for @shareLabel.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareLabel;

  /// No description provided for @activeOrdersLabel.
  ///
  /// In en, this message translates to:
  /// **'Active Orders'**
  String get activeOrdersLabel;

  /// No description provided for @orderSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Order Summary'**
  String get orderSummaryLabel;

  /// No description provided for @orderDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Order Details'**
  String get orderDetailsLabel;

  /// No description provided for @trackOrderLabel.
  ///
  /// In en, this message translates to:
  /// **'Track Order'**
  String get trackOrderLabel;

  /// No description provided for @orderStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Order Status'**
  String get orderStatusLabel;

  /// No description provided for @estimatedArrivalLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimated Arrival'**
  String get estimatedArrivalLabel;

  /// No description provided for @deliveredLabel.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get deliveredLabel;

  /// No description provided for @preparingLabel.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get preparingLabel;

  /// No description provided for @readyLabel.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get readyLabel;

  /// No description provided for @pickedUpLabel.
  ///
  /// In en, this message translates to:
  /// **'Picked Up'**
  String get pickedUpLabel;

  /// No description provided for @cancelledLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelledLabel;

  /// No description provided for @paymentMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethodLabel;

  /// No description provided for @cashOnDeliveryLabel.
  ///
  /// In en, this message translates to:
  /// **'Cash on Delivery'**
  String get cashOnDeliveryLabel;

  /// No description provided for @cardPaymentLabel.
  ///
  /// In en, this message translates to:
  /// **'Card Payment'**
  String get cardPaymentLabel;

  /// No description provided for @walletPaymentLabel.
  ///
  /// In en, this message translates to:
  /// **'Wallet Payment'**
  String get walletPaymentLabel;

  /// No description provided for @promoCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Promo Code'**
  String get promoCodeLabel;

  /// No description provided for @applyPromoLabel.
  ///
  /// In en, this message translates to:
  /// **'Apply Promo Code'**
  String get applyPromoLabel;

  /// No description provided for @deliveryAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Delivery Address'**
  String get deliveryAddressLabel;

  /// No description provided for @addNewAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Add New Address'**
  String get addNewAddressLabel;

  /// No description provided for @selectAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Select Address'**
  String get selectAddressLabel;

  /// No description provided for @changeAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Change Address'**
  String get changeAddressLabel;

  /// No description provided for @notificationsLabel.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsLabel;

  /// No description provided for @notificationSettingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationSettingsLabel;

  /// No description provided for @orderUpdatesLabel.
  ///
  /// In en, this message translates to:
  /// **'Order Updates'**
  String get orderUpdatesLabel;

  /// No description provided for @promotionalOffersLabel.
  ///
  /// In en, this message translates to:
  /// **'Promotional Offers'**
  String get promotionalOffersLabel;

  /// No description provided for @newRestaurantsLabel.
  ///
  /// In en, this message translates to:
  /// **'New Restaurants'**
  String get newRestaurantsLabel;

  /// No description provided for @deliveryUpdatesLabel.
  ///
  /// In en, this message translates to:
  /// **'Delivery Updates'**
  String get deliveryUpdatesLabel;

  /// No description provided for @nameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters'**
  String get nameMinLength;

  /// No description provided for @invalidImageError.
  ///
  /// In en, this message translates to:
  /// **'Invalid image. Please select a valid image under 5MB.'**
  String get invalidImageError;

  /// No description provided for @profileImageUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile image updated successfully!'**
  String get profileImageUpdated;

  /// No description provided for @imageUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload image: {error}'**
  String imageUploadFailed(Object error);

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorOccurred(Object error);

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdated;

  /// No description provided for @profileUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Error updating profile: {error}'**
  String profileUpdateError(Object error);

  /// No description provided for @becomeDeliveryMan.
  ///
  /// In en, this message translates to:
  /// **'Become Delivery Man'**
  String get becomeDeliveryMan;

  /// No description provided for @becomeSahlaPartner.
  ///
  /// In en, this message translates to:
  /// **'Become Sahla Partner'**
  String get becomeSahlaPartner;

  /// No description provided for @growWithSahla.
  ///
  /// In en, this message translates to:
  /// **'Grow with Sahla services'**
  String get growWithSahla;

  /// No description provided for @tapToDetectLocation.
  ///
  /// In en, this message translates to:
  /// **'Tap to detect location'**
  String get tapToDetectLocation;

  /// No description provided for @deliveryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Delivery unavailable'**
  String get deliveryUnavailable;

  /// No description provided for @pickLocation.
  ///
  /// In en, this message translates to:
  /// **'Pick Location'**
  String get pickLocation;

  /// No description provided for @editLocation.
  ///
  /// In en, this message translates to:
  /// **'Edit Location'**
  String get editLocation;

  /// No description provided for @proceedOrDiscard.
  ///
  /// In en, this message translates to:
  /// **'Proceed or Discard?'**
  String get proceedOrDiscard;

  /// No description provided for @proceedOrDiscardMessage.
  ///
  /// In en, this message translates to:
  /// **'You have activated location services. Do you want to proceed with the selected location or discard the changes?'**
  String get proceedOrDiscardMessage;

  /// No description provided for @locationEditedMessage.
  ///
  /// In en, this message translates to:
  /// **'You have edited the location. Do you want to proceed with the selected location or discard the changes?'**
  String get locationEditedMessage;

  /// No description provided for @proceed.
  ///
  /// In en, this message translates to:
  /// **'Proceed'**
  String get proceed;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @approximatePrice.
  ///
  /// In en, this message translates to:
  /// **'Approximate Price'**
  String get approximatePrice;

  /// No description provided for @addSecondaryPhone.
  ///
  /// In en, this message translates to:
  /// **'Add secondary phone?'**
  String get addSecondaryPhone;

  /// No description provided for @chooseLocationOnMap.
  ///
  /// In en, this message translates to:
  /// **'Choose location using interactive map'**
  String get chooseLocationOnMap;

  /// No description provided for @createIfriliTask.
  ///
  /// In en, this message translates to:
  /// **'Create Ifrili Task'**
  String get createIfriliTask;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @dropPinOnMapFirst.
  ///
  /// In en, this message translates to:
  /// **'Drop a pin on the map first'**
  String get dropPinOnMapFirst;

  /// No description provided for @pleaseDropPinOrAddLocations.
  ///
  /// In en, this message translates to:
  /// **'Please drop a pin on the map or add locations'**
  String get pleaseDropPinOrAddLocations;

  /// No description provided for @errorUploadingImage.
  ///
  /// In en, this message translates to:
  /// **'Error uploading image: {error}'**
  String errorUploadingImage(Object error);

  /// No description provided for @reviewIfriliTasks.
  ///
  /// In en, this message translates to:
  /// **'Review Ifrili Tasks'**
  String get reviewIfriliTasks;

  /// No description provided for @noDraftTasksToReview.
  ///
  /// In en, this message translates to:
  /// **'No draft tasks to review'**
  String get noDraftTasksToReview;

  /// No description provided for @confirmCreateTasks.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Create Tasks'**
  String get confirmCreateTasks;

  /// No description provided for @failedToCreateTasks.
  ///
  /// In en, this message translates to:
  /// **'Failed to create tasks: {error}'**
  String failedToCreateTasks(Object error);

  /// No description provided for @tapToViewMapWithLocations.
  ///
  /// In en, this message translates to:
  /// **'Tap to view map with all locations'**
  String get tapToViewMapWithLocations;

  /// No description provided for @locationCount.
  ///
  /// In en, this message translates to:
  /// **'{count} location{plural}'**
  String locationCount(Object count, Object plural);

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @costReview.
  ///
  /// In en, this message translates to:
  /// **'Cost Review'**
  String get costReview;

  /// No description provided for @costAgreed.
  ///
  /// In en, this message translates to:
  /// **'Cost Agreed'**
  String get costAgreed;

  /// No description provided for @assigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get assigned;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @taskLocationsSection.
  ///
  /// In en, this message translates to:
  /// **'Task Locations:'**
  String get taskLocationsSection;

  /// No description provided for @failedToOpenMapView.
  ///
  /// In en, this message translates to:
  /// **'Failed to open map view: {error}'**
  String failedToOpenMapView(Object error);

  /// No description provided for @deliveryManApplication.
  ///
  /// In en, this message translates to:
  /// **'Delivery Man Application'**
  String get deliveryManApplication;

  /// No description provided for @joinOurDeliveryTeam.
  ///
  /// In en, this message translates to:
  /// **'Join Our Delivery Team!'**
  String get joinOurDeliveryTeam;

  /// No description provided for @earnMoneyHelpingPeople.
  ///
  /// In en, this message translates to:
  /// **'Earn money while helping people get their food'**
  String get earnMoneyHelpingPeople;

  /// No description provided for @enterYourFullName.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get enterYourFullName;

  /// No description provided for @pleaseEnterYourFullName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name'**
  String get pleaseEnterYourFullName;

  /// No description provided for @phoneNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone Number *'**
  String get phoneNumberRequired;

  /// No description provided for @enterYourPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get enterYourPhoneNumber;

  /// No description provided for @pleaseEnterYourPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number'**
  String get pleaseEnterYourPhoneNumber;

  /// No description provided for @addressRequired.
  ///
  /// In en, this message translates to:
  /// **'Address *'**
  String get addressRequired;

  /// No description provided for @enterYourCurrentAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter your current address'**
  String get enterYourCurrentAddress;

  /// No description provided for @pleaseEnterYourAddress.
  ///
  /// In en, this message translates to:
  /// **'Please enter your address'**
  String get pleaseEnterYourAddress;

  /// No description provided for @vehicleInformation.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Information'**
  String get vehicleInformation;

  /// No description provided for @vehicleTypeRequired.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Type *'**
  String get vehicleTypeRequired;

  /// No description provided for @vehicleModelRequired.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Model *'**
  String get vehicleModelRequired;

  /// No description provided for @enterYourVehicleModel.
  ///
  /// In en, this message translates to:
  /// **'Enter your vehicle model'**
  String get enterYourVehicleModel;

  /// No description provided for @pleaseEnterYourVehicleModel.
  ///
  /// In en, this message translates to:
  /// **'Please enter your vehicle model'**
  String get pleaseEnterYourVehicleModel;

  /// No description provided for @vehicleYearRequired.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Year *'**
  String get vehicleYearRequired;

  /// No description provided for @enterYourVehicleYear.
  ///
  /// In en, this message translates to:
  /// **'Enter your vehicle year'**
  String get enterYourVehicleYear;

  /// No description provided for @pleaseEnterYourVehicleYear.
  ///
  /// In en, this message translates to:
  /// **'Please enter your vehicle year'**
  String get pleaseEnterYourVehicleYear;

  /// No description provided for @vehicleColorRequired.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Color *'**
  String get vehicleColorRequired;

  /// No description provided for @enterYourVehicleColor.
  ///
  /// In en, this message translates to:
  /// **'Enter your vehicle color'**
  String get enterYourVehicleColor;

  /// No description provided for @pleaseEnterYourVehicleColor.
  ///
  /// In en, this message translates to:
  /// **'Please enter your vehicle color'**
  String get pleaseEnterYourVehicleColor;

  /// No description provided for @licenseNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'License Number *'**
  String get licenseNumberRequired;

  /// No description provided for @enterYourDrivingLicenseNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter your driving license number'**
  String get enterYourDrivingLicenseNumber;

  /// No description provided for @pleaseEnterYourLicenseNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter your license number'**
  String get pleaseEnterYourLicenseNumber;

  /// No description provided for @availability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get availability;

  /// No description provided for @availabilityRequired.
  ///
  /// In en, this message translates to:
  /// **'Availability *'**
  String get availabilityRequired;

  /// No description provided for @previousExperienceOptional.
  ///
  /// In en, this message translates to:
  /// **'Previous Experience (Optional)'**
  String get previousExperienceOptional;

  /// No description provided for @describePreviousExperience.
  ///
  /// In en, this message translates to:
  /// **'Describe any previous delivery or customer service experience'**
  String get describePreviousExperience;

  /// No description provided for @requirements.
  ///
  /// In en, this message translates to:
  /// **'Requirements'**
  String get requirements;

  /// No description provided for @haveValidDrivingLicense.
  ///
  /// In en, this message translates to:
  /// **'I have a valid driving license'**
  String get haveValidDrivingLicense;

  /// No description provided for @haveReliableVehicle.
  ///
  /// In en, this message translates to:
  /// **'I have a reliable vehicle'**
  String get haveReliableVehicle;

  /// No description provided for @availableOnWeekends.
  ///
  /// In en, this message translates to:
  /// **'Available on weekends'**
  String get availableOnWeekends;

  /// No description provided for @availableInEvenings.
  ///
  /// In en, this message translates to:
  /// **'Available in evenings'**
  String get availableInEvenings;

  /// No description provided for @benefitsOfJoining.
  ///
  /// In en, this message translates to:
  /// **'Benefits of Joining'**
  String get benefitsOfJoining;

  /// No description provided for @flexibleEarningOpportunities.
  ///
  /// In en, this message translates to:
  /// **'Flexible earning opportunities'**
  String get flexibleEarningOpportunities;

  /// No description provided for @workOnYourOwnSchedule.
  ///
  /// In en, this message translates to:
  /// **'Work on your own schedule'**
  String get workOnYourOwnSchedule;

  /// No description provided for @deliverInYourLocalArea.
  ///
  /// In en, this message translates to:
  /// **'Deliver in your local area'**
  String get deliverInYourLocalArea;

  /// No description provided for @supportTeam.
  ///
  /// In en, this message translates to:
  /// **'24/7 support team'**
  String get supportTeam;

  /// No description provided for @performanceBonuses.
  ///
  /// In en, this message translates to:
  /// **'Performance bonuses'**
  String get performanceBonuses;

  /// No description provided for @submitApplication.
  ///
  /// In en, this message translates to:
  /// **'Submit Application'**
  String get submitApplication;

  /// No description provided for @resetForm.
  ///
  /// In en, this message translates to:
  /// **'Reset Form'**
  String get resetForm;

  /// No description provided for @submittingApplication.
  ///
  /// In en, this message translates to:
  /// **'Submitting application...'**
  String get submittingApplication;

  /// No description provided for @applicationSubmittedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Application submitted successfully! We\'ll review it within 24-48 hours.'**
  String get applicationSubmittedSuccessfully;

  /// No description provided for @submitApplicationConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Submit Application?'**
  String get submitApplicationConfirmation;

  /// No description provided for @confirmApplicationSubmission.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to submit your delivery application? Make sure all information is correct.'**
  String get confirmApplicationSubmission;

  /// No description provided for @termsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'By submitting this application, you agree to our terms and conditions and privacy policy.'**
  String get termsAndConditions;

  /// No description provided for @validationNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name'**
  String get validationNameRequired;

  /// No description provided for @validationPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number'**
  String get validationPhoneRequired;

  /// No description provided for @validationPhoneFormat.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number format'**
  String get validationPhoneFormat;

  /// No description provided for @validationAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your address'**
  String get validationAddressRequired;

  /// No description provided for @validationVehicleTypeRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select a vehicle type'**
  String get validationVehicleTypeRequired;

  /// No description provided for @validationVehicleModelRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your vehicle model'**
  String get validationVehicleModelRequired;

  /// No description provided for @validationVehicleYearRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your vehicle year'**
  String get validationVehicleYearRequired;

  /// No description provided for @validationVehicleColorRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your vehicle color'**
  String get validationVehicleColorRequired;

  /// No description provided for @validationLicenseNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your license number'**
  String get validationLicenseNumberRequired;

  /// No description provided for @validationAvailabilityRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select your availability'**
  String get validationAvailabilityRequired;

  /// No description provided for @validationLicenseRequired.
  ///
  /// In en, this message translates to:
  /// **'You must have a valid driving license'**
  String get validationLicenseRequired;

  /// No description provided for @validationVehicleRequired.
  ///
  /// In en, this message translates to:
  /// **'You must have a reliable vehicle'**
  String get validationVehicleRequired;

  /// No description provided for @errorSubmittingApplication.
  ///
  /// In en, this message translates to:
  /// **'Error submitting application: {error}'**
  String errorSubmittingApplication(Object error);

  /// No description provided for @errorUnexpected.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again.'**
  String get errorUnexpected;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Please check your internet connection'**
  String get errorNetwork;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'Service temporarily unavailable. Please try again later'**
  String get errorServer;

  /// No description provided for @errorDuplicateApplication.
  ///
  /// In en, this message translates to:
  /// **'You have already submitted an application'**
  String get errorDuplicateApplication;

  /// No description provided for @alreadyExists.
  ///
  /// In en, this message translates to:
  /// **'already exists'**
  String get alreadyExists;

  /// No description provided for @availableForVariants.
  ///
  /// In en, this message translates to:
  /// **'Available for Variants'**
  String get availableForVariants;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @selectVariantsForSupplement.
  ///
  /// In en, this message translates to:
  /// **'Select which variants this supplement is available for. Leave empty for all variants.'**
  String get selectVariantsForSupplement;

  /// No description provided for @errorInvalidYear.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid year (1990-2030)'**
  String get errorInvalidYear;

  /// No description provided for @errorMissingLicense.
  ///
  /// In en, this message translates to:
  /// **'You must have a valid driving license'**
  String get errorMissingLicense;

  /// No description provided for @errorMissingVehicle.
  ///
  /// In en, this message translates to:
  /// **'You must have a reliable vehicle'**
  String get errorMissingVehicle;

  /// No description provided for @applicationDraftSaved.
  ///
  /// In en, this message translates to:
  /// **'Draft saved'**
  String get applicationDraftSaved;

  /// No description provided for @applicationDraftRestored.
  ///
  /// In en, this message translates to:
  /// **'Draft restored'**
  String get applicationDraftRestored;

  /// No description provided for @yourOrder.
  ///
  /// In en, this message translates to:
  /// **'Your Order'**
  String get yourOrder;

  /// No description provided for @items.
  ///
  /// In en, this message translates to:
  /// **'items'**
  String get items;

  /// No description provided for @enterPromoCode.
  ///
  /// In en, this message translates to:
  /// **'Enter promo code'**
  String get enterPromoCode;

  /// No description provided for @promoCodeApplied.
  ///
  /// In en, this message translates to:
  /// **'Promo code applied successfully!'**
  String get promoCodeApplied;

  /// No description provided for @promoCodeRemoved.
  ///
  /// In en, this message translates to:
  /// **'Promo code removed'**
  String get promoCodeRemoved;

  /// No description provided for @promoCodeNotApplicable.
  ///
  /// In en, this message translates to:
  /// **'Promo code is not applicable to your current cart'**
  String get promoCodeNotApplicable;

  /// No description provided for @invalidPromoCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid promo code'**
  String get invalidPromoCode;

  /// No description provided for @errorApplyingPromoCode.
  ///
  /// In en, this message translates to:
  /// **'Error applying promo code. Please try again.'**
  String get errorApplyingPromoCode;

  /// No description provided for @errorRemovingPromoCode.
  ///
  /// In en, this message translates to:
  /// **'Error removing promo code'**
  String get errorRemovingPromoCode;

  /// No description provided for @clearCart.
  ///
  /// In en, this message translates to:
  /// **'Clear Cart'**
  String get clearCart;

  /// No description provided for @clearCartConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove all items from your cart?'**
  String get clearCartConfirmation;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// No description provided for @regular.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get regular;

  /// No description provided for @noItemsInOrder.
  ///
  /// In en, this message translates to:
  /// **'No items in this order'**
  String get noItemsInOrder;

  /// No description provided for @orderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order #'**
  String get orderNumber;

  /// No description provided for @variant.
  ///
  /// In en, this message translates to:
  /// **'Variant'**
  String get variant;

  /// No description provided for @supplements.
  ///
  /// In en, this message translates to:
  /// **'Supplements'**
  String get supplements;

  /// No description provided for @drinks.
  ///
  /// In en, this message translates to:
  /// **'Drinks'**
  String get drinks;

  /// No description provided for @drinksByRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Drinks by Restaurant'**
  String get drinksByRestaurant;

  /// No description provided for @variants.
  ///
  /// In en, this message translates to:
  /// **'Variants'**
  String get variants;

  /// No description provided for @forVariant.
  ///
  /// In en, this message translates to:
  /// **'for'**
  String get forVariant;

  /// No description provided for @customizeIngredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get customizeIngredients;

  /// No description provided for @customizeOrder.
  ///
  /// In en, this message translates to:
  /// **'Customize Your Order'**
  String get customizeOrder;

  /// No description provided for @tapToEdit.
  ///
  /// In en, this message translates to:
  /// **'Tap to edit'**
  String get tapToEdit;

  /// No description provided for @tapToExpand.
  ///
  /// In en, this message translates to:
  /// **'Tap to expand'**
  String get tapToExpand;

  /// No description provided for @addSupplements.
  ///
  /// In en, this message translates to:
  /// **'Add Supplements'**
  String get addSupplements;

  /// No description provided for @mainPackIngredients.
  ///
  /// In en, this message translates to:
  /// **'Main Pack Ingredients'**
  String get mainPackIngredients;

  /// No description provided for @freeDrinksIncluded.
  ///
  /// In en, this message translates to:
  /// **'Free Drinks Included'**
  String get freeDrinksIncluded;

  /// No description provided for @chooseUpToComplimentaryDrink.
  ///
  /// In en, this message translates to:
  /// **'Choose up to {count} complimentary {drink}{plural}'**
  String chooseUpToComplimentaryDrink(int count, String drink, String plural);

  /// No description provided for @savedOrders.
  ///
  /// In en, this message translates to:
  /// **'Saved Orders'**
  String get savedOrders;

  /// No description provided for @choosePreferencesForEachItem.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferences for each item'**
  String get choosePreferencesForEachItem;

  /// No description provided for @chooseVariant.
  ///
  /// In en, this message translates to:
  /// **'Pick your choice'**
  String get chooseVariant;

  /// No description provided for @ingredientPreferences.
  ///
  /// In en, this message translates to:
  /// **'Ingredient Preferences'**
  String get ingredientPreferences;

  /// No description provided for @normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normal;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @less.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get less;

  /// No description provided for @wantMore.
  ///
  /// In en, this message translates to:
  /// **'Want more'**
  String get wantMore;

  /// No description provided for @defaultOption.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultOption;

  /// No description provided for @specialInstructions.
  ///
  /// In en, this message translates to:
  /// **'Special Instructions:'**
  String get specialInstructions;

  /// No description provided for @removeItem.
  ///
  /// In en, this message translates to:
  /// **'Remove Item'**
  String get removeItem;

  /// No description provided for @removeItemConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove'**
  String get removeItemConfirmation;

  /// No description provided for @fromYourOrder.
  ///
  /// In en, this message translates to:
  /// **'from your order?'**
  String get fromYourOrder;

  /// No description provided for @invalidCartItemData.
  ///
  /// In en, this message translates to:
  /// **'Invalid cart item data'**
  String get invalidCartItemData;

  /// No description provided for @deliveryDetails.
  ///
  /// In en, this message translates to:
  /// **'Delivery Details'**
  String get deliveryDetails;

  /// No description provided for @useCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use Current Location'**
  String get useCurrentLocation;

  /// No description provided for @chooseOnMap.
  ///
  /// In en, this message translates to:
  /// **'Choose on Map'**
  String get chooseOnMap;

  /// No description provided for @loadingAddress.
  ///
  /// In en, this message translates to:
  /// **'Loading address...'**
  String get loadingAddress;

  /// No description provided for @noAddressSelected.
  ///
  /// In en, this message translates to:
  /// **'No address selected'**
  String get noAddressSelected;

  /// No description provided for @secondaryPhoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Secondary phone (optional)'**
  String get secondaryPhoneOptional;

  /// No description provided for @preparingOrder.
  ///
  /// In en, this message translates to:
  /// **'Preparing your order at the restaurant...'**
  String get preparingOrder;

  /// No description provided for @preparingOrderSubtext.
  ///
  /// In en, this message translates to:
  /// **'You can close this and track live at any time.'**
  String get preparingOrderSubtext;

  /// No description provided for @readyForPickup.
  ///
  /// In en, this message translates to:
  /// **'Ready for pickup'**
  String get readyForPickup;

  /// No description provided for @deliveryPartnerPickup.
  ///
  /// In en, this message translates to:
  /// **'A delivery partner will pick up your order soon.'**
  String get deliveryPartnerPickup;

  /// No description provided for @pleaseSelectDeliveryLocation.
  ///
  /// In en, this message translates to:
  /// **'Please select a delivery location option first'**
  String get pleaseSelectDeliveryLocation;

  /// No description provided for @pleaseSelectDeliveryLocationOption.
  ///
  /// In en, this message translates to:
  /// **'Please select a delivery location'**
  String get pleaseSelectDeliveryLocationOption;

  /// No description provided for @failedToConfirmOrder.
  ///
  /// In en, this message translates to:
  /// **'Failed to confirm order'**
  String get failedToConfirmOrder;

  /// No description provided for @switchMapType.
  ///
  /// In en, this message translates to:
  /// **'Switch map type'**
  String get switchMapType;

  /// No description provided for @selectedOnMap.
  ///
  /// In en, this message translates to:
  /// **'Selected on map'**
  String get selectedOnMap;

  /// No description provided for @yourCartIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get yourCartIsEmpty;

  /// No description provided for @addDeliciousItems.
  ///
  /// In en, this message translates to:
  /// **'Add some delicious items to get started!'**
  String get addDeliciousItems;

  /// No description provided for @browseMenu.
  ///
  /// In en, this message translates to:
  /// **'Browse Menu'**
  String get browseMenu;

  /// No description provided for @tapFloatingCartIcon.
  ///
  /// In en, this message translates to:
  /// **'Tap the floating cart icon when you add items'**
  String get tapFloatingCartIcon;

  /// No description provided for @cannotPlaceCall.
  ///
  /// In en, this message translates to:
  /// **'Cannot place a call on this device'**
  String get cannotPlaceCall;

  /// No description provided for @failedToOpenDialer.
  ///
  /// In en, this message translates to:
  /// **'Failed to open dialer'**
  String get failedToOpenDialer;

  /// No description provided for @mapLoadingError.
  ///
  /// In en, this message translates to:
  /// **'Map Loading Error'**
  String get mapLoadingError;

  /// No description provided for @deliveryPartner.
  ///
  /// In en, this message translates to:
  /// **'Delivery Partner'**
  String get deliveryPartner;

  /// No description provided for @onTheWay.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get onTheWay;

  /// No description provided for @phoneNumberNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Phone number not available'**
  String get phoneNumberNotAvailable;

  /// No description provided for @updateLocation.
  ///
  /// In en, this message translates to:
  /// **'Update Location'**
  String get updateLocation;

  /// No description provided for @placed.
  ///
  /// In en, this message translates to:
  /// **'Placed'**
  String get placed;

  /// No description provided for @confirmReception.
  ///
  /// In en, this message translates to:
  /// **'Confirm Reception'**
  String get confirmReception;

  /// No description provided for @receptionConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Reception confirmed'**
  String get receptionConfirmed;

  /// No description provided for @failedToConfirmReception.
  ///
  /// In en, this message translates to:
  /// **'Failed to confirm reception'**
  String get failedToConfirmReception;

  /// No description provided for @failedToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Failed to confirm'**
  String get failedToConfirm;

  /// No description provided for @unitPrice.
  ///
  /// In en, this message translates to:
  /// **'Unit Price:'**
  String get unitPrice;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity:'**
  String get quantity;

  /// No description provided for @itemName.
  ///
  /// In en, this message translates to:
  /// **'Item Name:'**
  String get itemName;

  /// No description provided for @totalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total Amount:'**
  String get totalAmount;

  /// No description provided for @dateAt.
  ///
  /// In en, this message translates to:
  /// **'at'**
  String get dateAt;

  /// No description provided for @tasksAndOrders.
  ///
  /// In en, this message translates to:
  /// **'Tasks & Orders'**
  String get tasksAndOrders;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'active'**
  String get active;

  /// No description provided for @enablePermissions.
  ///
  /// In en, this message translates to:
  /// **'Enable Permissions'**
  String get enablePermissions;

  /// No description provided for @permissionsDescription.
  ///
  /// In en, this message translates to:
  /// **'We use your location to show nearby restaurants and delivery status, and notifications to keep you updated.'**
  String get permissionsDescription;

  /// No description provided for @locationPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Location (While Using the App)'**
  String get locationPermissionTitle;

  /// No description provided for @locationPermissionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For maps, nearby results, and live delivery tracking.'**
  String get locationPermissionSubtitle;

  /// No description provided for @notificationsPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsPermissionTitle;

  /// No description provided for @notificationsPermissionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get order updates and important alerts.'**
  String get notificationsPermissionSubtitle;

  /// No description provided for @allowAll.
  ///
  /// In en, this message translates to:
  /// **'Allow All'**
  String get allowAll;

  /// No description provided for @skipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow;

  /// No description provided for @becomeRestaurantOwner.
  ///
  /// In en, this message translates to:
  /// **'Become Restaurant Owner'**
  String get becomeRestaurantOwner;

  /// No description provided for @restaurantOwnerApplication.
  ///
  /// In en, this message translates to:
  /// **'Restaurant Owner Application'**
  String get restaurantOwnerApplication;

  /// No description provided for @joinOurRestaurantNetwork.
  ///
  /// In en, this message translates to:
  /// **'Join Our Restaurant Network!'**
  String get joinOurRestaurantNetwork;

  /// No description provided for @growYourRestaurantBusiness.
  ///
  /// In en, this message translates to:
  /// **'Grow your restaurant business with Sahla'**
  String get growYourRestaurantBusiness;

  /// No description provided for @serviceAndBasicInfo.
  ///
  /// In en, this message translates to:
  /// **'Service & Basic Info'**
  String get serviceAndBasicInfo;

  /// No description provided for @additionalDetails.
  ///
  /// In en, this message translates to:
  /// **'Additional Details'**
  String get additionalDetails;

  /// No description provided for @selectService.
  ///
  /// In en, this message translates to:
  /// **'Select service'**
  String get selectService;

  /// No description provided for @pleaseSelectService.
  ///
  /// In en, this message translates to:
  /// **'Please select a service'**
  String get pleaseSelectService;

  /// No description provided for @pleaseSelectServiceType.
  ///
  /// In en, this message translates to:
  /// **'Please select a service type'**
  String get pleaseSelectServiceType;

  /// No description provided for @restaurantName.
  ///
  /// In en, this message translates to:
  /// **'Restaurant Name'**
  String get restaurantName;

  /// No description provided for @restaurantNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Restaurant name is required'**
  String get restaurantNameRequired;

  /// No description provided for @enterRestaurantName.
  ///
  /// In en, this message translates to:
  /// **'Enter restaurant name'**
  String get enterRestaurantName;

  /// No description provided for @pleaseEnterRestaurantName.
  ///
  /// In en, this message translates to:
  /// **'Please enter restaurant name'**
  String get pleaseEnterRestaurantName;

  /// No description provided for @pleaseEnterValidName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid name (2-100 characters)'**
  String get pleaseEnterValidName;

  /// No description provided for @restaurantDescription.
  ///
  /// In en, this message translates to:
  /// **'Restaurant Description'**
  String get restaurantDescription;

  /// No description provided for @enterRestaurantDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter restaurant description'**
  String get enterRestaurantDescription;

  /// No description provided for @restaurantPhone.
  ///
  /// In en, this message translates to:
  /// **'Restaurant Phone'**
  String get restaurantPhone;

  /// No description provided for @restaurantPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Restaurant phone is required'**
  String get restaurantPhoneRequired;

  /// No description provided for @enterRestaurantPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter restaurant phone'**
  String get enterRestaurantPhone;

  /// No description provided for @pleaseEnterRestaurantPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter restaurant phone'**
  String get pleaseEnterRestaurantPhone;

  /// No description provided for @pleaseEnterValidPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number'**
  String get pleaseEnterValidPhone;

  /// No description provided for @restaurantAddress.
  ///
  /// In en, this message translates to:
  /// **'Restaurant Address'**
  String get restaurantAddress;

  /// No description provided for @restaurantAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'Restaurant address is required'**
  String get restaurantAddressRequired;

  /// No description provided for @pleaseSelectRestaurantAddress.
  ///
  /// In en, this message translates to:
  /// **'Please select restaurant address'**
  String get pleaseSelectRestaurantAddress;

  /// No description provided for @pleaseSelectLocationWithinAlgeria.
  ///
  /// In en, this message translates to:
  /// **'Please select a location within Algeria'**
  String get pleaseSelectLocationWithinAlgeria;

  /// No description provided for @wilaya.
  ///
  /// In en, this message translates to:
  /// **'Wilaya'**
  String get wilaya;

  /// No description provided for @pleaseSelectWilaya.
  ///
  /// In en, this message translates to:
  /// **'Please select a wilaya'**
  String get pleaseSelectWilaya;

  /// No description provided for @groceryType.
  ///
  /// In en, this message translates to:
  /// **'Grocery Type'**
  String get groceryType;

  /// No description provided for @pleaseSelectGroceryType.
  ///
  /// In en, this message translates to:
  /// **'Please select a grocery type'**
  String get pleaseSelectGroceryType;

  /// No description provided for @superMarket.
  ///
  /// In en, this message translates to:
  /// **'Super Market'**
  String get superMarket;

  /// No description provided for @boucherie.
  ///
  /// In en, this message translates to:
  /// **'Butchery'**
  String get boucherie;

  /// No description provided for @patisserie.
  ///
  /// In en, this message translates to:
  /// **'Pastry Shop'**
  String get patisserie;

  /// No description provided for @fruitsVegetables.
  ///
  /// In en, this message translates to:
  /// **'Fruits & Vegetables'**
  String get fruitsVegetables;

  /// No description provided for @bakery.
  ///
  /// In en, this message translates to:
  /// **'Bakery'**
  String get bakery;

  /// No description provided for @seafood.
  ///
  /// In en, this message translates to:
  /// **'Seafood'**
  String get seafood;

  /// No description provided for @dairy.
  ///
  /// In en, this message translates to:
  /// **'Dairy'**
  String get dairy;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @logoUpload.
  ///
  /// In en, this message translates to:
  /// **'Logo Upload'**
  String get logoUpload;

  /// No description provided for @logoUploadedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Logo uploaded successfully!'**
  String get logoUploadedSuccessfully;

  /// No description provided for @failedToUploadLogo.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload logo'**
  String get failedToUploadLogo;

  /// No description provided for @logoRemoved.
  ///
  /// In en, this message translates to:
  /// **'Logo removed'**
  String get logoRemoved;

  /// No description provided for @configureWorkingHours.
  ///
  /// In en, this message translates to:
  /// **'Configure Working Hours'**
  String get configureWorkingHours;

  /// No description provided for @pleaseConfigureWorkingHours.
  ///
  /// In en, this message translates to:
  /// **'Please configure working hours'**
  String get pleaseConfigureWorkingHours;

  /// No description provided for @pleaseFixWorkingHoursConflicts.
  ///
  /// In en, this message translates to:
  /// **'Please fix working hours conflicts'**
  String get pleaseFixWorkingHoursConflicts;

  /// No description provided for @socialMediaOptional.
  ///
  /// In en, this message translates to:
  /// **'Social Media (optional)'**
  String get socialMediaOptional;

  /// No description provided for @facebook.
  ///
  /// In en, this message translates to:
  /// **'Facebook'**
  String get facebook;

  /// No description provided for @instagram.
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get instagram;

  /// No description provided for @tiktok.
  ///
  /// In en, this message translates to:
  /// **'TikTok'**
  String get tiktok;

  /// No description provided for @pleaseEnterValidUrl.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid URL'**
  String get pleaseEnterValidUrl;

  /// No description provided for @reachThousandsOfFoodLovers.
  ///
  /// In en, this message translates to:
  /// **'Reach thousands of food lovers'**
  String get reachThousandsOfFoodLovers;

  /// No description provided for @detailedAnalyticsAndInsights.
  ///
  /// In en, this message translates to:
  /// **'Detailed analytics and insights'**
  String get detailedAnalyticsAndInsights;

  /// No description provided for @customerSupport.
  ///
  /// In en, this message translates to:
  /// **'24/7 customer support'**
  String get customerSupport;

  /// No description provided for @securePaymentProcessing.
  ///
  /// In en, this message translates to:
  /// **'Secure payment processing'**
  String get securePaymentProcessing;

  /// No description provided for @deliveryPartnerIntegration.
  ///
  /// In en, this message translates to:
  /// **'Delivery partner integration'**
  String get deliveryPartnerIntegration;

  /// No description provided for @connectionRestored.
  ///
  /// In en, this message translates to:
  /// **'Connection restored'**
  String get connectionRestored;

  /// No description provided for @pleaseCheckInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'Please check internet connection'**
  String get pleaseCheckInternetConnection;

  /// No description provided for @restaurantRequestSubmittedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Restaurant request submitted successfully!'**
  String get restaurantRequestSubmittedSuccessfully;

  /// No description provided for @failedToSubmitRequest.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit request'**
  String get failedToSubmitRequest;

  /// No description provided for @formRestoredFromPreviousSession.
  ///
  /// In en, this message translates to:
  /// **'Form restored from previous session'**
  String get formRestoredFromPreviousSession;

  /// No description provided for @workingHours.
  ///
  /// In en, this message translates to:
  /// **'Working Hours'**
  String get workingHours;

  /// No description provided for @monday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get thursday;

  /// No description provided for @friday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday;

  /// No description provided for @sunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// No description provided for @adrar.
  ///
  /// In en, this message translates to:
  /// **'Adrar'**
  String get adrar;

  /// No description provided for @chlef.
  ///
  /// In en, this message translates to:
  /// **'Chlef'**
  String get chlef;

  /// No description provided for @laghouat.
  ///
  /// In en, this message translates to:
  /// **'Laghouat'**
  String get laghouat;

  /// No description provided for @oumElBouaghi.
  ///
  /// In en, this message translates to:
  /// **'Oum El Bouaghi'**
  String get oumElBouaghi;

  /// No description provided for @batna.
  ///
  /// In en, this message translates to:
  /// **'Batna'**
  String get batna;

  /// No description provided for @bejaia.
  ///
  /// In en, this message translates to:
  /// **'Béjaïa'**
  String get bejaia;

  /// No description provided for @biskra.
  ///
  /// In en, this message translates to:
  /// **'Biskra'**
  String get biskra;

  /// No description provided for @bechar.
  ///
  /// In en, this message translates to:
  /// **'Béchar'**
  String get bechar;

  /// No description provided for @blida.
  ///
  /// In en, this message translates to:
  /// **'Blida'**
  String get blida;

  /// No description provided for @bouira.
  ///
  /// In en, this message translates to:
  /// **'Bouïra'**
  String get bouira;

  /// No description provided for @tamanrasset.
  ///
  /// In en, this message translates to:
  /// **'Tamanrasset'**
  String get tamanrasset;

  /// No description provided for @tebessa.
  ///
  /// In en, this message translates to:
  /// **'Tébessa'**
  String get tebessa;

  /// No description provided for @tlemcen.
  ///
  /// In en, this message translates to:
  /// **'Tlemcen'**
  String get tlemcen;

  /// No description provided for @tiaret.
  ///
  /// In en, this message translates to:
  /// **'Tiaret'**
  String get tiaret;

  /// No description provided for @tiziOuzou.
  ///
  /// In en, this message translates to:
  /// **'Tizi Ouzou'**
  String get tiziOuzou;

  /// No description provided for @algiers.
  ///
  /// In en, this message translates to:
  /// **'Algiers'**
  String get algiers;

  /// No description provided for @djelfa.
  ///
  /// In en, this message translates to:
  /// **'Djelfa'**
  String get djelfa;

  /// No description provided for @jijel.
  ///
  /// In en, this message translates to:
  /// **'Jijel'**
  String get jijel;

  /// No description provided for @setif.
  ///
  /// In en, this message translates to:
  /// **'Sétif'**
  String get setif;

  /// No description provided for @saida.
  ///
  /// In en, this message translates to:
  /// **'Saïda'**
  String get saida;

  /// No description provided for @skikda.
  ///
  /// In en, this message translates to:
  /// **'Skikda'**
  String get skikda;

  /// No description provided for @sidiBelAbbes.
  ///
  /// In en, this message translates to:
  /// **'Sidi Bel Abbès'**
  String get sidiBelAbbes;

  /// No description provided for @annaba.
  ///
  /// In en, this message translates to:
  /// **'Annaba'**
  String get annaba;

  /// No description provided for @guelma.
  ///
  /// In en, this message translates to:
  /// **'Guelma'**
  String get guelma;

  /// No description provided for @constantine.
  ///
  /// In en, this message translates to:
  /// **'Constantine'**
  String get constantine;

  /// No description provided for @medea.
  ///
  /// In en, this message translates to:
  /// **'Médéa'**
  String get medea;

  /// No description provided for @mostaganem.
  ///
  /// In en, this message translates to:
  /// **'Mostaganem'**
  String get mostaganem;

  /// No description provided for @msila.
  ///
  /// In en, this message translates to:
  /// **'M\'Sila'**
  String get msila;

  /// No description provided for @mascara.
  ///
  /// In en, this message translates to:
  /// **'Mascara'**
  String get mascara;

  /// No description provided for @ouargla.
  ///
  /// In en, this message translates to:
  /// **'Ouargla'**
  String get ouargla;

  /// No description provided for @oran.
  ///
  /// In en, this message translates to:
  /// **'Oran'**
  String get oran;

  /// No description provided for @elBayadh.
  ///
  /// In en, this message translates to:
  /// **'El Bayadh'**
  String get elBayadh;

  /// No description provided for @illizi.
  ///
  /// In en, this message translates to:
  /// **'Illizi'**
  String get illizi;

  /// No description provided for @bordjBouArreridj.
  ///
  /// In en, this message translates to:
  /// **'Bordj Bou Arréridj'**
  String get bordjBouArreridj;

  /// No description provided for @boumerdes.
  ///
  /// In en, this message translates to:
  /// **'Boumerdès'**
  String get boumerdes;

  /// No description provided for @elTarf.
  ///
  /// In en, this message translates to:
  /// **'El Tarf'**
  String get elTarf;

  /// No description provided for @tindouf.
  ///
  /// In en, this message translates to:
  /// **'Tindouf'**
  String get tindouf;

  /// No description provided for @tissemsilt.
  ///
  /// In en, this message translates to:
  /// **'Tissemsilt'**
  String get tissemsilt;

  /// No description provided for @elOued.
  ///
  /// In en, this message translates to:
  /// **'El Oued'**
  String get elOued;

  /// No description provided for @khenchela.
  ///
  /// In en, this message translates to:
  /// **'Khenchela'**
  String get khenchela;

  /// No description provided for @soukAhras.
  ///
  /// In en, this message translates to:
  /// **'Souk Ahras'**
  String get soukAhras;

  /// No description provided for @tipaza.
  ///
  /// In en, this message translates to:
  /// **'Tipaza'**
  String get tipaza;

  /// No description provided for @mila.
  ///
  /// In en, this message translates to:
  /// **'Mila'**
  String get mila;

  /// No description provided for @ainDefla.
  ///
  /// In en, this message translates to:
  /// **'Aïn Defla'**
  String get ainDefla;

  /// No description provided for @naama.
  ///
  /// In en, this message translates to:
  /// **'Naâma'**
  String get naama;

  /// No description provided for @ainTemouchent.
  ///
  /// In en, this message translates to:
  /// **'Aïn Témouchent'**
  String get ainTemouchent;

  /// No description provided for @ghardaia.
  ///
  /// In en, this message translates to:
  /// **'Ghardaïa'**
  String get ghardaia;

  /// No description provided for @relizane.
  ///
  /// In en, this message translates to:
  /// **'Relizane'**
  String get relizane;

  /// No description provided for @timimoun.
  ///
  /// In en, this message translates to:
  /// **'Timimoun'**
  String get timimoun;

  /// No description provided for @bordjBadjiMokhtar.
  ///
  /// In en, this message translates to:
  /// **'Bordj Badji Mokhtar'**
  String get bordjBadjiMokhtar;

  /// No description provided for @ouledDjellal.
  ///
  /// In en, this message translates to:
  /// **'Ouled Djellal'**
  String get ouledDjellal;

  /// No description provided for @beniAbbes.
  ///
  /// In en, this message translates to:
  /// **'Béni Abbès'**
  String get beniAbbes;

  /// No description provided for @inSalah.
  ///
  /// In en, this message translates to:
  /// **'In Salah'**
  String get inSalah;

  /// No description provided for @inGuezzam.
  ///
  /// In en, this message translates to:
  /// **'In Guezzam'**
  String get inGuezzam;

  /// No description provided for @touggourt.
  ///
  /// In en, this message translates to:
  /// **'Touggourt'**
  String get touggourt;

  /// No description provided for @djanet.
  ///
  /// In en, this message translates to:
  /// **'Djanet'**
  String get djanet;

  /// No description provided for @elMghair.
  ///
  /// In en, this message translates to:
  /// **'El M\'Ghair'**
  String get elMghair;

  /// No description provided for @elMenia.
  ///
  /// In en, this message translates to:
  /// **'El Menia'**
  String get elMenia;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @submitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get submitting;

  /// No description provided for @restaurantLogo.
  ///
  /// In en, this message translates to:
  /// **'Restaurant Logo'**
  String get restaurantLogo;

  /// No description provided for @tapToAddLogo.
  ///
  /// In en, this message translates to:
  /// **'Tap to add logo'**
  String get tapToAddLogo;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @selectYourWilaya.
  ///
  /// In en, this message translates to:
  /// **'Select your wilaya'**
  String get selectYourWilaya;

  /// No description provided for @grocery.
  ///
  /// In en, this message translates to:
  /// **'Grocery'**
  String get grocery;

  /// No description provided for @handyman.
  ///
  /// In en, this message translates to:
  /// **'Handyman'**
  String get handyman;

  /// No description provided for @homeFood.
  ///
  /// In en, this message translates to:
  /// **'Home Food'**
  String get homeFood;

  /// No description provided for @plateNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Plate Number *'**
  String get plateNumberRequired;

  /// No description provided for @enterYourVehiclePlateNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter your vehicle plate number'**
  String get enterYourVehiclePlateNumber;

  /// No description provided for @validationPlateNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your plate number'**
  String get validationPlateNumberRequired;

  /// No description provided for @tapToViewFullSize.
  ///
  /// In en, this message translates to:
  /// **'Tap to view full size'**
  String get tapToViewFullSize;

  /// No description provided for @onePhoto.
  ///
  /// In en, this message translates to:
  /// **'1 Photo'**
  String get onePhoto;

  /// No description provided for @manageMenu.
  ///
  /// In en, this message translates to:
  /// **'Manage Menu'**
  String get manageMenu;

  /// No description provided for @userNotAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'User not authenticated'**
  String get userNotAuthenticated;

  /// No description provided for @noRestaurantFound.
  ///
  /// In en, this message translates to:
  /// **'No restaurant found. Please visit the dashboard first.'**
  String get noRestaurantFound;

  /// No description provided for @failedToLoadMenuData.
  ///
  /// In en, this message translates to:
  /// **'Failed to load menu data'**
  String get failedToLoadMenuData;

  /// No description provided for @allCuisines.
  ///
  /// In en, this message translates to:
  /// **'All Cuisines'**
  String get allCuisines;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get allCategories;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @allItems.
  ///
  /// In en, this message translates to:
  /// **'All Items'**
  String get allItems;

  /// No description provided for @noItemsFoundMatchingFilters.
  ///
  /// In en, this message translates to:
  /// **'No items found matching your filters'**
  String get noItemsFoundMatchingFilters;

  /// No description provided for @noMenuItemsYet.
  ///
  /// In en, this message translates to:
  /// **'No menu items yet'**
  String get noMenuItemsYet;

  /// No description provided for @tapPlusButtonToAddFirstItem.
  ///
  /// In en, this message translates to:
  /// **'Tap the + button to add your first item'**
  String get tapPlusButtonToAddFirstItem;

  /// No description provided for @loadingMoreItems.
  ///
  /// In en, this message translates to:
  /// **'Loading more items...'**
  String get loadingMoreItems;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get addItem;

  /// No description provided for @menuItemUpdatedAndRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Menu item updated and refreshed'**
  String get menuItemUpdatedAndRefreshed;

  /// No description provided for @successfullyHidItem.
  ///
  /// In en, this message translates to:
  /// **'Successfully hid \"{itemName}\"'**
  String successfullyHidItem(String itemName);

  /// No description provided for @successfullyShowedItem.
  ///
  /// In en, this message translates to:
  /// **'Successfully showed \"{itemName}\"'**
  String successfullyShowedItem(String itemName);

  /// No description provided for @failedToUpdateAvailability.
  ///
  /// In en, this message translates to:
  /// **'Failed to update availability for \"{itemName}\"'**
  String failedToUpdateAvailability(String itemName);

  /// No description provided for @errorUpdatingAvailability.
  ///
  /// In en, this message translates to:
  /// **'Error updating availability: {error}'**
  String errorUpdatingAvailability(String error);

  /// No description provided for @deleteMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Delete Menu Item'**
  String get deleteMenuItem;

  /// No description provided for @deleteMenuItemConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{itemName}\"? This action cannot be undone.'**
  String deleteMenuItemConfirmation(String itemName);

  /// No description provided for @deletingItem.
  ///
  /// In en, this message translates to:
  /// **'Deleting \"{itemName}\"...'**
  String deletingItem(String itemName);

  /// No description provided for @successfullyDeletedItem.
  ///
  /// In en, this message translates to:
  /// **'Successfully deleted \"{itemName}\"'**
  String successfullyDeletedItem(String itemName);

  /// No description provided for @failedToDeleteItem.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete \"{itemName}\"'**
  String failedToDeleteItem(String itemName);

  /// No description provided for @errorDeletingItem.
  ///
  /// In en, this message translates to:
  /// **'Error deleting item: {error}'**
  String errorDeletingItem(String error);

  /// No description provided for @dietaryInfo.
  ///
  /// In en, this message translates to:
  /// **'Dietary Info'**
  String get dietaryInfo;

  /// No description provided for @spicy.
  ///
  /// In en, this message translates to:
  /// **'Spicy'**
  String get spicy;

  /// No description provided for @vegetarian.
  ///
  /// In en, this message translates to:
  /// **'Vegetarian'**
  String get vegetarian;

  /// No description provided for @traditional.
  ///
  /// In en, this message translates to:
  /// **'Traditional'**
  String get traditional;

  /// No description provided for @glutenFree.
  ///
  /// In en, this message translates to:
  /// **'Gluten Free'**
  String get glutenFree;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @mainIngredients.
  ///
  /// In en, this message translates to:
  /// **'Main Ingredients'**
  String get mainIngredients;

  /// No description provided for @listMainIngredientsIfNoDescription.
  ///
  /// In en, this message translates to:
  /// **'List main ingredients if no description provided'**
  String get listMainIngredientsIfNoDescription;

  /// No description provided for @addIngredient.
  ///
  /// In en, this message translates to:
  /// **'Add ingredient'**
  String get addIngredient;

  /// No description provided for @defaultVariant.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultVariant;

  /// No description provided for @pricingAndSizes.
  ///
  /// In en, this message translates to:
  /// **'Pricing & Sizes'**
  String get pricingAndSizes;

  /// No description provided for @variantsAndPricing.
  ///
  /// In en, this message translates to:
  /// **'Variants & Pricing'**
  String get variantsAndPricing;

  /// No description provided for @addNewVariant.
  ///
  /// In en, this message translates to:
  /// **'Add New Variant'**
  String get addNewVariant;

  /// No description provided for @createDifferentVersionsOfDish.
  ///
  /// In en, this message translates to:
  /// **'Create different versions of your dish (e.g., Classic, Spicy, Vegetarian)'**
  String get createDifferentVersionsOfDish;

  /// No description provided for @variantName.
  ///
  /// In en, this message translates to:
  /// **'Variant name'**
  String get variantName;

  /// No description provided for @addVariant.
  ///
  /// In en, this message translates to:
  /// **'Add variant'**
  String get addVariant;

  /// No description provided for @eachVariantCanHaveDifferentSizes.
  ///
  /// In en, this message translates to:
  /// **'Each variant can have different sizes and prices'**
  String get eachVariantCanHaveDifferentSizes;

  /// No description provided for @forSelectedVariant.
  ///
  /// In en, this message translates to:
  /// **'For selected variant'**
  String get forSelectedVariant;

  /// No description provided for @standard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get standard;

  /// No description provided for @dishSupplements.
  ///
  /// In en, this message translates to:
  /// **'Dish Supplements'**
  String get dishSupplements;

  /// No description provided for @addSupplement.
  ///
  /// In en, this message translates to:
  /// **'Add Supplement'**
  String get addSupplement;

  /// No description provided for @supplementExamples.
  ///
  /// In en, this message translates to:
  /// **'Examples: Chidar +50 DA, Extra Cheese +30 DA, Spicy Sauce +20 DA'**
  String get supplementExamples;

  /// No description provided for @availableForAllVariants.
  ///
  /// In en, this message translates to:
  /// **'Available for all variants'**
  String get availableForAllVariants;

  /// No description provided for @availableFor.
  ///
  /// In en, this message translates to:
  /// **'Available for'**
  String get availableFor;

  /// No description provided for @addFlavorAndSize.
  ///
  /// In en, this message translates to:
  /// **'Add Flavor & Size'**
  String get addFlavorAndSize;

  /// No description provided for @availableForSelectedVariant.
  ///
  /// In en, this message translates to:
  /// **'Available for selected variant'**
  String get availableForSelectedVariant;

  /// No description provided for @currentlyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Currently unavailable'**
  String get currentlyUnavailable;

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review {title}'**
  String reviewTitle(String title);

  /// No description provided for @reviewMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Menu Item'**
  String get reviewMenuItem;

  /// No description provided for @reviewRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get reviewRestaurant;

  /// No description provided for @reviewOrder.
  ///
  /// In en, this message translates to:
  /// **'Order #'**
  String get reviewOrder;

  /// No description provided for @reviewMenuItemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share your thoughts about this dish'**
  String get reviewMenuItemSubtitle;

  /// No description provided for @reviewRestaurantSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How was your experience?'**
  String get reviewRestaurantSubtitle;

  /// No description provided for @reviewOrderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rate your overall order experience'**
  String get reviewOrderSubtitle;

  /// No description provided for @howWouldYouRateIt.
  ///
  /// In en, this message translates to:
  /// **'How would you rate it?'**
  String get howWouldYouRateIt;

  /// No description provided for @ratingPoor.
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get ratingPoor;

  /// No description provided for @ratingFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get ratingFair;

  /// No description provided for @ratingGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get ratingGood;

  /// No description provided for @ratingVeryGood.
  ///
  /// In en, this message translates to:
  /// **'Very Good'**
  String get ratingVeryGood;

  /// No description provided for @ratingExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get ratingExcellent;

  /// No description provided for @selectRating.
  ///
  /// In en, this message translates to:
  /// **'Select rating'**
  String get selectRating;

  /// No description provided for @shareYourExperience.
  ///
  /// In en, this message translates to:
  /// **'Share your experience'**
  String get shareYourExperience;

  /// No description provided for @shareYourExperienceOptional.
  ///
  /// In en, this message translates to:
  /// **'Share your experience (optional)'**
  String get shareYourExperienceOptional;

  /// No description provided for @tellOthersAboutExperience.
  ///
  /// In en, this message translates to:
  /// **'Tell others about your experience...'**
  String get tellOthersAboutExperience;

  /// No description provided for @alsoEnjoying.
  ///
  /// In en, this message translates to:
  /// **'Also enjoying {restaurantName}?'**
  String alsoEnjoying(String restaurantName);

  /// No description provided for @shareRestaurantExperience.
  ///
  /// In en, this message translates to:
  /// **'Share your restaurant experience'**
  String get shareRestaurantExperience;

  /// No description provided for @rateOverallService.
  ///
  /// In en, this message translates to:
  /// **'Rate the overall service'**
  String get rateOverallService;

  /// No description provided for @thankYouForRating.
  ///
  /// In en, this message translates to:
  /// **'Thank you for rating {restaurantName}!'**
  String thankYouForRating(String restaurantName);

  /// No description provided for @addPhotos.
  ///
  /// In en, this message translates to:
  /// **'Add photos'**
  String get addPhotos;

  /// No description provided for @addPhotosOptional.
  ///
  /// In en, this message translates to:
  /// **'Add photos (optional)'**
  String get addPhotosOptional;

  /// No description provided for @addPhotosButton.
  ///
  /// In en, this message translates to:
  /// **'Add Photos'**
  String get addPhotosButton;

  /// No description provided for @addMorePhotos.
  ///
  /// In en, this message translates to:
  /// **'Add More Photos'**
  String get addMorePhotos;

  /// No description provided for @submitReview.
  ///
  /// In en, this message translates to:
  /// **'Submit Review'**
  String get submitReview;

  /// No description provided for @restaurantReviewSubmittedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Restaurant review submitted successfully!'**
  String get restaurantReviewSubmittedSuccessfully;

  /// No description provided for @failedToSubmitRestaurantReview.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit restaurant review. Please try again.'**
  String get failedToSubmitRestaurantReview;

  /// No description provided for @errorOccurredTryAgain.
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please try again.'**
  String get errorOccurredTryAgain;

  /// No description provided for @pleaseSelectValidRating.
  ///
  /// In en, this message translates to:
  /// **'Please select a valid rating'**
  String get pleaseSelectValidRating;

  /// No description provided for @menuItemNotFound.
  ///
  /// In en, this message translates to:
  /// **'Menu item not found'**
  String get menuItemNotFound;

  /// No description provided for @restaurantNotFound.
  ///
  /// In en, this message translates to:
  /// **'Restaurant not found'**
  String get restaurantNotFound;

  /// No description provided for @orderNotFound.
  ///
  /// In en, this message translates to:
  /// **'Order not found'**
  String get orderNotFound;

  /// No description provided for @reviewSubmittedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Review submitted successfully!'**
  String get reviewSubmittedSuccessfully;

  /// No description provided for @failedToSubmitReview.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit review. Please try again.'**
  String get failedToSubmitReview;

  /// No description provided for @addReview.
  ///
  /// In en, this message translates to:
  /// **'Add Review'**
  String get addReview;

  /// No description provided for @viewAllReviews.
  ///
  /// In en, this message translates to:
  /// **'View all reviews'**
  String get viewAllReviews;

  /// No description provided for @reviewsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviewsScreenTitle;

  /// No description provided for @noReviewsYet.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get noReviewsYet;

  /// No description provided for @beTheFirstToReview.
  ///
  /// In en, this message translates to:
  /// **'Be the first to review'**
  String get beTheFirstToReview;

  /// No description provided for @oops.
  ///
  /// In en, this message translates to:
  /// **'Oops!'**
  String get oops;

  /// No description provided for @failedToLoadReviews.
  ///
  /// In en, this message translates to:
  /// **'Failed to load reviews'**
  String get failedToLoadReviews;

  /// No description provided for @allReviews.
  ///
  /// In en, this message translates to:
  /// **'All Reviews'**
  String get allReviews;

  /// No description provided for @newest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get newest;

  /// No description provided for @oldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get oldest;

  /// No description provided for @highestRated.
  ///
  /// In en, this message translates to:
  /// **'Highest Rated'**
  String get highestRated;

  /// No description provided for @lowestRated.
  ///
  /// In en, this message translates to:
  /// **'Lowest Rated'**
  String get lowestRated;

  /// No description provided for @monthsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} {plural} ago'**
  String monthsAgo(int count, String plural);

  /// No description provided for @verifiedUser.
  ///
  /// In en, this message translates to:
  /// **'Verified User'**
  String get verifiedUser;

  /// No description provided for @anonymousUser.
  ///
  /// In en, this message translates to:
  /// **'Anonymous User'**
  String get anonymousUser;

  /// No description provided for @reviewForMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Review for {menuItem}'**
  String reviewForMenuItem(String menuItem);

  /// No description provided for @prep.
  ///
  /// In en, this message translates to:
  /// **'Prep'**
  String get prep;

  /// No description provided for @closesAt.
  ///
  /// In en, this message translates to:
  /// **'Closes at'**
  String get closesAt;

  /// No description provided for @opensAt.
  ///
  /// In en, this message translates to:
  /// **'Opens at'**
  String get opensAt;

  /// No description provided for @viewReviews.
  ///
  /// In en, this message translates to:
  /// **'View Reviews'**
  String get viewReviews;

  /// No description provided for @minOrder.
  ///
  /// In en, this message translates to:
  /// **'Min Order'**
  String get minOrder;

  /// No description provided for @deliveryFeeShort.
  ///
  /// In en, this message translates to:
  /// **'Delivery Fee'**
  String get deliveryFeeShort;

  /// No description provided for @avgDeliveryTime.
  ///
  /// In en, this message translates to:
  /// **'Avg Delivery Time'**
  String get avgDeliveryTime;

  /// No description provided for @limited.
  ///
  /// In en, this message translates to:
  /// **'LIMITED'**
  String get limited;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'EXPIRED'**
  String get expired;

  /// Title for Limited Time Offers section
  ///
  /// In en, this message translates to:
  /// **'Limited time offers'**
  String get limitedTimeOffers;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'FREE'**
  String get free;

  /// No description provided for @removedIngredients.
  ///
  /// In en, this message translates to:
  /// **'Removed Ingredients'**
  String get removedIngredients;

  /// No description provided for @itemsLabel.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get itemsLabel;

  /// No description provided for @noItemsSelected.
  ///
  /// In en, this message translates to:
  /// **'No items selected'**
  String get noItemsSelected;

  /// No description provided for @errorLoadingOrderSummary.
  ///
  /// In en, this message translates to:
  /// **'Error loading order summary'**
  String get errorLoadingOrderSummary;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
