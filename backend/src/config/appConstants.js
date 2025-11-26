/**
 * App Constants
 * Converted from lib/config/app_config.dart
 * Backend-only constants (removed Flutter-specific UI constants)
 */

/**
 * App-wide constants
 */
export const AppConstants = {
  // App info
  appName: 'SAHLA Delivery',
  appVersion: '1.0.0',
  appBuildNumber: '1',

  // Supported locales
  supportedLocales: ['en', 'ar', 'fr'],

  // Phone number validation
  minPhoneLength: 8,
  maxPhoneLength: 15,

  // Pagination
  defaultPageSize: 20,
  maxPageSize: 100,

  // Image quality settings
  imageQuality: 85,
  thumbnailQuality: 60,

  // Cache durations (in milliseconds)
  cacheShort: 5 * 60 * 1000, // 5 minutes
  cacheMedium: 60 * 60 * 1000, // 1 hour
  cacheLong: 7 * 24 * 60 * 60 * 1000, // 7 days

  // Cache expiration (in minutes)
  cacheExpirationMinutes: 30,
  userCacheExpirationMinutes: 60,

  // Default values
  defaultUserId: 'current_user_id',
  defaultUserName: 'Guest User',

  // Storage keys (for reference, not used in backend)
  authTokenKey: 'auth_token',
  refreshTokenKey: 'refresh_token',
  userIdKey: 'user_id',
  userDataKey: 'user_data',
  viewHistoryKey: 'view_history',
  favoritesKey: 'favorites',
  offlineDataKey: 'offline_data',
  lastSyncKey: 'last_sync',

  // Cache keys
  favoritesCacheKey: 'favorites_cache',
  userCacheKey: 'user_cache',

  // Offline sync settings
  maxOfflineItems: 1000,
  syncRetryDelay: 5 * 60 * 1000, // 5 minutes
  maxSyncRetries: 3,

  // App dimensions (for reference)
  defaultPadding: 16.0,
  defaultRadius: 12.0,

  // Currency and locale
  currencySymbol: 'DA',
};

/**
 * API constants
 */
export const ApiConstants = {
  // API timeout (in milliseconds)
  timeout: 30 * 1000, // 30 seconds
  shortTimeout: 10 * 1000, // 10 seconds

  // Pagination
  defaultPageSize: 20,
  maxPageSize: 100,

  // HTTP Status Codes
  success: 200,
  created: 201,
  noContent: 204,
  badRequest: 400,
  unauthorized: 401,
  forbidden: 403,
  notFound: 404,
  conflict: 409,
  unprocessableEntity: 422,
  internalServerError: 500,
  serviceUnavailable: 503,

  // Error Messages
  networkError: 'Network connection error',
  serverError: 'Server error occurred',
  unauthorizedError: 'Unauthorized access',
  notFoundError: 'Resource not found',
  validationError: 'Validation error',
  timeoutError: 'Request timeout',
  unknownError: 'Unknown error occurred',
};

/**
 * Delivery man constants
 * Converted from lib/config/delivery_man_constants.dart
 */
export const DeliveryManConstants = {
  // Minimum requirements
  minAge: 18,
  minExperienceYears: 0,
  minVehicleYear: 1990,
  maxPhoneLength: 15,

  // Vehicle types
  vehicleTypes: ['Motorcycle', 'Bicycle', 'Car', 'Scooter', 'E-bike'],

  // Availability options
  availabilityOptions: [
    'Full-time',
    'Part-time',
    'Weekends only',
    'Evenings only',
    'Flexible',
  ],

  // Status values
  status: {
    pending: 'pending',
    approved: 'approved',
    rejected: 'rejected',
    active: 'active',
    inactive: 'inactive',
  },

  // Error messages
  errorMessages: {
    network_error: 'Please check your internet connection',
    server_error:
      'Service temporarily unavailable. Please try again later',
    duplicate_application: 'You have already submitted an application',
    invalid_phone: 'Please enter a valid phone number',
    invalid_year: 'Please enter a valid year (1990-2030)',
    missing_license: 'You must have a valid driving license',
    missing_vehicle: 'You must have a reliable vehicle',
  },

  // Get invalid year error message
  getInvalidYearError() {
    const currentYear = new Date().getFullYear();
    return `Please enter a valid year (1990-${currentYear + 1})`;
  },
};

export default {
  AppConstants,
  ApiConstants,
  DeliveryManConstants,
};
