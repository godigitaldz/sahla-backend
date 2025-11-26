/**
 * Maps Configuration
 * Converted from lib/config/maps_config.dart
 */

export const MapsConfig = {
  // Google Maps API key - should be in environment variables
  googleMapsApiKey: process.env.GOOGLE_MAPS_API_KEY || '',

  // API Base URLs
  directionsApiBaseUrl: 'https://maps.googleapis.com/maps/api/directions/json',
  placesApiBaseUrl: 'https://maps.googleapis.com/maps/api/place',
  distanceMatrixApiBaseUrl:
    'https://maps.googleapis.com/maps/api/distancematrix/json',
  roadsApiBaseUrl: 'https://roads.googleapis.com/v1',
  staticMapsApiBaseUrl: 'https://maps.googleapis.com/maps/api/staticmap',
  streetViewApiBaseUrl: 'https://maps.googleapis.com/maps/api/streetview',
  timeZoneApiBaseUrl: 'https://maps.googleapis.com/maps/api/timezone/json',
  mapsEmbedApiBaseUrl: 'https://www.google.com/maps/embed/v1',

  // Enhanced Google Cloud APIs
  translationApiBaseUrl:
    'https://translation.googleapis.com/language/translate/v2',
  visionApiBaseUrl: 'https://vision.googleapis.com/v1/images:annotate',
  naturalLanguageApiBaseUrl:
    'https://language.googleapis.com/v1/documents',

  // Route settings
  defaultTravelMode: 'driving',
  defaultUnits: 'metric',
  enableAlternatives: false,

  // Places API settings
  defaultPlacesRadius: 5000, // 5km
  maxPlacesResults: 20,
  restaurantTypes: ['restaurant', 'food', 'meal_takeaway'],

  // Distance Matrix settings
  maxOrigins: 25,
  maxDestinations: 25,
  defaultDistanceMatrixMode: 'driving',

  // Roads API settings
  defaultInterpolate: true,
  maxSnapPoints: 100,

  // Static Maps settings
  defaultMapWidth: 400,
  defaultMapHeight: 300,
  defaultMapZoom: 15,
  defaultMapType: 'roadmap',

  // Street View settings
  defaultStreetViewWidth: 400,
  defaultStreetViewHeight: 300,
  defaultStreetViewHeading: 0,
  defaultStreetViewPitch: 0,
  defaultStreetViewFov: 90,

  // Time Zone settings
  defaultTimeZoneLanguage: 'en',

  // Maps Embed settings
  defaultEmbedWidth: 400,
  defaultEmbedHeight: 300,
  defaultEmbedZoom: 15,

  // Delivery settings
  defaultDeliveryRadius: 10.0, // 10km
  defaultDeliveryTimeMinutes: 30,
  maxDeliveryTimeMinutes: 120,

  // Location accuracy settings
  locationAccuracyThreshold: 10.0, // meters
  locationUpdateIntervalSeconds: 30,
  maxLocationHistory: 100,

  // Cache settings (in minutes)
  routeCacheMinutes: 15,
  placesCacheMinutes: 60,
  distanceMatrixCacheMinutes: 5,
  timeZoneCacheHours: 24,
};

export default MapsConfig;
