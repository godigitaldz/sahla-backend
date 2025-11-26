/// Google Maps configuration
class MapsConfig {
  // Google Maps API key - hardcoded for simplicity
  static const String googleMapsApiKey =
      'AIzaSyD8tfdyk3NtBqIt6UYyThcwZR1ACyZ5fcg';

  // API Base URLs
  static const String directionsApiBaseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';
  static const String placesApiBaseUrl =
      'https://maps.googleapis.com/maps/api/place';
  static const String distanceMatrixApiBaseUrl =
      'https://maps.googleapis.com/maps/api/distancematrix/json';
  static const String roadsApiBaseUrl = 'https://roads.googleapis.com/v1';
  static const String staticMapsApiBaseUrl =
      'https://maps.googleapis.com/maps/api/staticmap';
  static const String streetViewApiBaseUrl =
      'https://maps.googleapis.com/maps/api/streetview';
  static const String timeZoneApiBaseUrl =
      'https://maps.googleapis.com/maps/api/timezone/json';
  static const String mapsEmbedApiBaseUrl =
      'https://www.google.com/maps/embed/v1';

  // Enhanced Google Cloud APIs
  static const String translationApiBaseUrl =
      'https://translation.googleapis.com/language/translate/v2';
  static const String visionApiBaseUrl =
      'https://vision.googleapis.com/v1/images:annotate';
  static const String naturalLanguageApiBaseUrl =
      'https://language.googleapis.com/v1/documents';

  // Route settings
  static const String defaultTravelMode = 'driving';
  static const String defaultUnits = 'metric';
  static const bool enableAlternatives = false;

  // Route colors
  static const int restaurantToCustomerRouteColor = 0xFF2196F3; // Blue
  static const int deliveryRouteColor = 0xFFd47b00; // Orange
  static const double routeOpacity = 0.8;
  static const int routeWidth = 5;

  // Route patterns
  static const List<int> dashedPattern = [15, 8]; // dash length, gap length
  static const List<int> solidPattern = []; // empty for solid line

  // Places API settings
  static const int defaultPlacesRadius = 5000; // 5km
  static const int maxPlacesResults = 20;
  static const List<String> restaurantTypes = [
    'restaurant',
    'food',
    'meal_takeaway'
  ];

  // Distance Matrix settings
  static const int maxOrigins = 25;
  static const int maxDestinations = 25;
  static const String defaultDistanceMatrixMode = 'driving';

  // Roads API settings
  static const bool defaultInterpolate = true;
  static const int maxSnapPoints = 100;

  // Static Maps settings
  static const int defaultMapWidth = 400;
  static const int defaultMapHeight = 300;
  static const int defaultMapZoom = 15;
  static const String defaultMapType = 'roadmap';

  // Street View settings
  static const int defaultStreetViewWidth = 400;
  static const int defaultStreetViewHeight = 300;
  static const int defaultStreetViewHeading = 0;
  static const int defaultStreetViewPitch = 0;
  static const int defaultStreetViewFov = 90;

  // Time Zone settings
  static const String defaultTimeZoneLanguage = 'en';

  // Maps Embed settings
  static const int defaultEmbedWidth = 400;
  static const int defaultEmbedHeight = 300;
  static const int defaultEmbedZoom = 15;

  // Delivery settings
  static const double defaultDeliveryRadius = 10.0; // 10km
  static const int defaultDeliveryTimeMinutes = 30;
  static const int maxDeliveryTimeMinutes = 120;

  // Location accuracy settings
  static const double locationAccuracyThreshold = 10.0; // meters
  static const int locationUpdateIntervalSeconds = 30;
  static const int maxLocationHistory = 100;

  // Cache settings
  static const int routeCacheMinutes = 15;
  static const int placesCacheMinutes = 60;
  static const int distanceMatrixCacheMinutes = 5;
  static const int timeZoneCacheHours = 24;
}
