class DeepLinkConfig {
  // App URL schemes
  static const String appScheme = 'sahla';
  static const String appDomain = 'sahla-delivery.com';
  static const String appUrl = 'https://sahla-delivery.com';

  // Deep link patterns
  static const Map<String, String> linkPatterns = {
    'restaurant': '/restaurant/{restaurantId}',
    'order': '/order/{orderId}',
    'delivery': '/delivery/{deliveryId}',
    'favorites': '/favorites/{listName}',
    'search': '/search?{parameters}',
  };

  // Generate deep link URLs
  static String generateRestaurantLink(String restaurantId) {
    return '$appUrl/restaurant/$restaurantId';
  }

  static String generateOrderLink(String orderId) {
    return '$appUrl/order/$orderId';
  }

  static String generateDeliveryLink(String deliveryId) {
    return '$appUrl/delivery/$deliveryId';
  }

  static String generateFavoritesLink(String listName) {
    return '$appUrl/favorites/$listName';
  }

  static String generateSearchLink(Map<String, String> parameters) {
    final queryString = parameters.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$appUrl/search?$queryString';
  }

  // App store URLs (replace with actual URLs when published)
  static const Map<String, String> appStoreUrls = {
    'ios': 'https://apps.apple.com/app/sahla-delivery/id123456789',
    'android':
        'https://play.google.com/store/apps/details?id=com.sahla.delivery',
    'web': 'https://sahla-delivery.com',
  };

  // Social media sharing templates
  static const Map<String, String> socialTemplates = {
    'twitter':
        'Check out this amazing restaurant on Sahla! {url} #FoodDelivery #SahlaApp',
    'facebook': 'I found this great restaurant on Sahla - {url}',
    'whatsapp': 'Check out this restaurant: {url}',
    'telegram': '🍽️ Amazing restaurant on Sahla: {url}',
  };

  // Share text templates
  static const Map<String, String> shareTemplates = {
    'restaurant': '''
🍽️ {restaurantName} on Sahla!

📍 Located in {location}
🍕 Delicious food delivery
⭐ Highly rated by customers

Order now and enjoy fast delivery!
''',
    'order': '''
📦 Your order from {restaurantName} on Sahla!

🍽️ {orderItems}
👤 Delivered by {deliveryPerson}
📅 {deliveryTime}
💰 Total: {totalPrice}

Track your order in real-time!
''',
    'delivery': '''
🚚 Delivery confirmed on Sahla!

📦 Order: {orderId}
🍽️ From: {restaurantName}
👤 Customer: {customerName}
📅 Estimated delivery: {deliveryTime}
💰 Total: {totalPrice}

Your food is on the way! 🎉
''',
    'favorites': '''
❤️ My {listName} on Sahla!

{description}
🍽️ {restaurantCount} restaurants including: {restaurantNames}

Check out my favorite places!
''',
  };
}
