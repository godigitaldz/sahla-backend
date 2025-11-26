// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Sahla';

  @override
  String get createTask => 'Créer une tâche Ifrili';

  @override
  String get describeYourNeed => 'Décrivez votre besoin';

  @override
  String get phoneNumber => 'Numéro de téléphone';

  @override
  String get secondPhoneOptional => 'Deuxième téléphone (optionnel)';

  @override
  String get useSecondPhoneAsPrimary =>
      'Utiliser le deuxième téléphone comme principal';

  @override
  String get locationPurpose => 'Objectif de l\'emplacement';

  @override
  String get addAnotherLocation => 'Ajouter un autre emplacement';

  @override
  String added(Object count) {
    return 'Ajouté: $count';
  }

  @override
  String get taskImageOptional => 'Image de la tâche (Optionnel)';

  @override
  String get addImage => 'Ajouter une image';

  @override
  String get tapToSelectFromGallery =>
      'Appuyez pour sélectionner dans la galerie';

  @override
  String get changeImage => 'Changer l\'image';

  @override
  String get remove => 'Retirer';

  @override
  String get uploading => 'Téléchargement...';

  @override
  String get pickDateTime => 'Choisir la date et l\'heure';

  @override
  String get createTaskButton => 'Créer une tâche';

  @override
  String get creating => 'Création...';

  @override
  String get taskCreatedSuccessfully => 'Tâche créée avec succès';

  @override
  String get tasksDescription => 'Description des tâches:';

  @override
  String get tasksLocations => 'Emplacements des tâches:';

  @override
  String get contactPhone => 'Téléphone de contact:';

  @override
  String get imagesPreview => 'Aperçu des images:';

  @override
  String get noImages => 'Aucune image';

  @override
  String get backToEdit => 'Retour à la modification';

  @override
  String get selectLocationOnMap =>
      'Sélectionnez un emplacement sur la carte...';

  @override
  String get gettingAddress => 'Obtention de l\'adresse...';

  @override
  String get loadingMap => 'Chargement de la carte...';

  @override
  String get confirmLocation => 'Confirmer l\'emplacement';

  @override
  String get getCurrentLocation => 'Obtenir l\'emplacement actuel';

  @override
  String get useYourCurrentLocation => 'Utiliser votre emplacement actuel';

  @override
  String get noResultsFound => 'Aucun résultat trouvé';

  @override
  String get home => 'Accueil';

  @override
  String get orders => 'Commandes';

  @override
  String get profile => 'Profil';

  @override
  String get settings => 'Paramètres';

  @override
  String get search => 'Rechercher';

  @override
  String get searchRestaurants => 'Rechercher des restaurants...';

  @override
  String get searchMenuItems => 'Rechercher des articles du menu...';

  @override
  String get categories => 'Catégories';

  @override
  String get cuisines => 'Cuisines';

  @override
  String get restaurants => 'Restaurants';

  @override
  String get menuItems => 'Articles du menu';

  @override
  String get freeDelivery => 'Livraison gratuite';

  @override
  String get location => 'Emplacement';

  @override
  String get cuisine => 'Cuisine';

  @override
  String get category => 'Catégorie';

  @override
  String get price => 'Prix';

  @override
  String get selectCuisineType => 'Sélectionner le type de cuisine';

  @override
  String get selectCategories => 'Sélectionner les catégories';

  @override
  String get minimumOrderRange => 'Plage de commande minimale';

  @override
  String get priceRange => 'Plage de prix';

  @override
  String get clear => 'Effacer';

  @override
  String get done => 'Terminé';

  @override
  String get noCuisinesAvailable => 'Aucune cuisine disponible';

  @override
  String get noCategoriesAvailable => 'Aucune catégorie disponible';

  @override
  String get loadingCategories => 'Chargement des catégories...';

  @override
  String get addNewDrinksMenu => 'Ajouter un nouveau menu de boissons';

  @override
  String get addDrinksByCreatingVariants =>
      'Ajoutez des boissons en créant des variantes. Chaque variante représente une boisson différente (par ex. Coca Cola, Fanta, Sprite).';

  @override
  String get smartDetectionActive => 'Détection intelligente active';

  @override
  String get smartDetectionDescription =>
      'Chaque variante sera automatiquement associée à l\'image de boisson correcte de notre bucket selon son nom (par ex. Coca Cola → image Coca Cola).';

  @override
  String get foodImages => 'Images de nourriture';

  @override
  String get reviewYourMenuItem => 'Examiner votre article du menu';

  @override
  String get uploadFoodImages => 'Télécharger des images de nourriture';

  @override
  String get addHighQualityPhotos =>
      'Ajoutez des photos de haute qualité de votre plat (au moins 1 requis)';

  @override
  String get camera => 'Caméra';

  @override
  String get gallery => 'Galerie';

  @override
  String get atLeastOneImageRequired => 'Au moins une image est requise';

  @override
  String get notSelected => 'Non sélectionné';

  @override
  String get notEntered => 'Non saisi';

  @override
  String get noneAdded => 'Aucun ajouté';

  @override
  String get noneUploaded => 'Aucun téléchargé';

  @override
  String get images => 'Images';

  @override
  String get min => 'min';

  @override
  String get max => 'Max';

  @override
  String get to => 'à';

  @override
  String get preparationTime => 'Temps de préparation';

  @override
  String get minutes => 'min';

  @override
  String get unknownRestaurant => 'Restaurant inconnu';

  @override
  String get currency => 'DZD';

  @override
  String get noItemsAvailable => 'Aucun article disponible';

  @override
  String get viewAll => 'Voir tout';

  @override
  String get noMenuItemsAvailable => 'Aucun article du menu disponible';

  @override
  String get debugInfoWillAppearInConsole =>
      'Les informations de débogage apparaîtront dans les journaux de la console';

  @override
  String get failedToLoadMenuItems =>
      'Échec du chargement des articles du menu';

  @override
  String get retry => 'Réessayer';

  @override
  String noItemsFoundForSearch(Object searchQuery) {
    return 'Aucun article trouvé pour \"$searchQuery\"';
  }

  @override
  String get noItemsMatchFilters => 'Aucun article ne correspond à vos filtres';

  @override
  String get tryAdjustingSearchTerms =>
      'Essayez d\'ajuster vos termes de recherche ou parcourez tous les articles disponibles.';

  @override
  String get tryRemovingFilters =>
      'Essayez de retirer certains filtres ou d\'ajuster vos critères de recherche pour trouver plus d\'articles.';

  @override
  String get checkBackLaterForNewItems =>
      'Revenez plus tard pour de nouveaux articles du menu ou essayez d\'actualiser la page.';

  @override
  String get clearFilters => 'Effacer les filtres';

  @override
  String get browseAllItems => 'Parcourir tous les articles';

  @override
  String get bestChoices => 'Meilleurs choix';

  @override
  String get noOffersAvailable => 'Aucune offre disponible';

  @override
  String get checkBackLaterForNewDeals =>
      'Revenez plus tard pour de nouvelles offres';

  @override
  String get addToCart => 'Ajouter au panier';

  @override
  String get confirmOrder => 'Confirmer la commande';

  @override
  String get add => 'Ajouter';

  @override
  String get item => 'article';

  @override
  String get addedToCart => 'ajouté au panier';

  @override
  String get unknownItem => 'Article inconnu';

  @override
  String get addedToFavorites => 'ajouté aux favoris';

  @override
  String get removedFromFavorites => 'retiré des favoris';

  @override
  String get failedToUpdateFavorite => 'Échec de la mise à jour du favori';

  @override
  String get specialNote => 'Note spéciale';

  @override
  String get addSpecialInstructions => 'Ajoutez des instructions spéciales...';

  @override
  String get mainItemQuantity => 'Quantité de l\'article principal';

  @override
  String get saveAndAddAnotherOrder =>
      'Enregistrer et ajouter une autre commande';

  @override
  String get totalPrice => 'Prix total';

  @override
  String get filterRestaurants => 'Filtrer les restaurants';

  @override
  String get clearAll => 'Tout effacer';

  @override
  String get applyFilters => 'Appliquer les filtres';

  @override
  String get enterCityOrArea => 'Entrez la ville ou la zone';

  @override
  String get map => 'Carte';

  @override
  String get minimumRating => 'Note minimale';

  @override
  String get deliveryFeeRange => 'Plage de frais de livraison';

  @override
  String get status => 'Statut';

  @override
  String get openNow => 'Ouvert maintenant';

  @override
  String get cuisineType => 'Type de cuisine';

  @override
  String get pleaseSelectCategoryFirst => 'Sélectionnez d\'abord une catégorie';

  @override
  String get restaurantCategory => 'Catégorie de restaurant';

  @override
  String get selectCategory => 'Sélectionner une catégorie';

  @override
  String get pleaseSelectCategory => 'Veuillez sélectionner une catégorie';

  @override
  String get selectedLocation => 'Emplacement sélectionné';

  @override
  String get tapToSelectLocation => 'Appuyez pour sélectionner un emplacement';

  @override
  String get pleaseSelectLocation =>
      'Veuillez sélectionner un emplacement sur la carte';

  @override
  String get locationPermissionDenied => 'Autorisation de localisation refusée';

  @override
  String get locationPermissionsPermanentlyDenied =>
      'Les autorisations de localisation sont définitivement refusées. Veuillez les activer dans les paramètres.';

  @override
  String get locationServicesDisabled =>
      'Les services de localisation sont désactivés';

  @override
  String get failedToGetCurrentLocation =>
      'Échec de l\'obtention de l\'emplacement actuel';

  @override
  String get delivery => 'Livraison';

  @override
  String get pickup => 'À emporter';

  @override
  String get dineIn => 'Sur place';

  @override
  String get rating => 'Note';

  @override
  String get reviews => 'Avis';

  @override
  String get distance => 'Distance';

  @override
  String get removeFromCart => 'Retirer du panier';

  @override
  String get viewCart => 'Voir le panier';

  @override
  String get login => 'Connexion';

  @override
  String get register => 'S\'inscrire';

  @override
  String get logout => 'Déconnexion';

  @override
  String get email => 'E-mail';

  @override
  String get password => 'Mot de passe';

  @override
  String get confirmPassword => 'Confirmer le mot de passe';

  @override
  String get forgotPassword => 'Mot de passe oublié?';

  @override
  String get rememberMe => 'Se souvenir de moi';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationSettings => 'Paramètres de notification';

  @override
  String get enableNotifications => 'Activer les notifications';

  @override
  String get disableNotifications => 'Désactiver les notifications';

  @override
  String get language => 'Langue';

  @override
  String get english => 'Anglais';

  @override
  String get french => 'Français';

  @override
  String get arabic => 'Arabe';

  @override
  String get theme => 'Thème';

  @override
  String get lightMode => 'Mode clair';

  @override
  String get darkMode => 'Mode sombre';

  @override
  String get systemTheme => 'Thème système';

  @override
  String get about => 'À propos';

  @override
  String get help => 'Aide';

  @override
  String get contactUs => 'Nous contacter';

  @override
  String get termsOfService => 'Conditions d\'utilisation';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get error => 'Erreur';

  @override
  String get success => 'Succès';

  @override
  String get warning => 'Avertissement';

  @override
  String get info => 'Information';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Annuler';

  @override
  String get yes => 'Oui';

  @override
  String get no => 'Non';

  @override
  String get confirm => 'Confirmer';

  @override
  String get delete => 'Supprimer';

  @override
  String get edit => 'Modifier';

  @override
  String get save => 'Enregistrer';

  @override
  String get submit => 'Soumettre';

  @override
  String get update => 'Mettre à jour';

  @override
  String get loading => 'Chargement...';

  @override
  String get pleaseWait => 'Veuillez patienter...';

  @override
  String get noInternetConnection => 'Aucune connexion Internet';

  @override
  String get somethingWentWrong => 'Quelque chose s\'est mal passé';

  @override
  String get tryAgain => 'Réessayer';

  @override
  String get enableLocation => 'Activer la localisation';

  @override
  String get locationPermissionRequired =>
      'Autorisation de localisation requise';

  @override
  String get cameraPermissionDenied => 'Autorisation de caméra refusée';

  @override
  String get cameraPermissionRequired => 'Autorisation de caméra requise';

  @override
  String get galleryPermissionRequired => 'Autorisation de galerie requise';

  @override
  String get searchResultsFor => 'Résultats de recherche pour';

  @override
  String get favorites => 'Favoris';

  @override
  String get addToFavorites => 'Ajouter aux favoris';

  @override
  String get removeFromFavorites => 'Retirer des favoris';

  @override
  String get cart => 'Panier';

  @override
  String get cartEmpty => 'Votre panier est vide';

  @override
  String get total => 'Total:';

  @override
  String get subtotal => 'Sous-total';

  @override
  String get tax => 'Taxe';

  @override
  String get deliveryFee => 'Frais de livraison';

  @override
  String get serviceFee => 'Frais de service';

  @override
  String get order => 'Commande';

  @override
  String get orderPlaced => 'Commande passée';

  @override
  String get orderConfirmed => 'Commande confirmée';

  @override
  String get orderPreparing => 'Commande en préparation';

  @override
  String get orderReady => 'Commande prête';

  @override
  String get orderPickedUp => 'Commande récupérée';

  @override
  String get orderDelivered => 'Commande livrée';

  @override
  String get orderCancelled => 'Commande annulée';

  @override
  String get payment => 'Paiement';

  @override
  String get paymentMethod => 'Méthode de paiement';

  @override
  String get cashOnDelivery => 'Paiement à la livraison';

  @override
  String get cardPayment => 'Paiement par carte';

  @override
  String get walletPayment => 'Paiement par portefeuille';

  @override
  String get restaurant => 'Restaurant';

  @override
  String get restaurantDetails => 'Détails du restaurant';

  @override
  String get restaurantMenu => 'Menu du restaurant';

  @override
  String get restaurantReviews => 'Avis sur le restaurant';

  @override
  String get restaurantHours => 'Heures du restaurant';

  @override
  String get restaurantLocation => 'Emplacement du restaurant';

  @override
  String get restaurantContact => 'Contact du restaurant';

  @override
  String get deliveryAddress => 'Adresse de livraison';

  @override
  String get addAddress => 'Ajouter une adresse';

  @override
  String get editAddress => 'Modifier l\'adresse';

  @override
  String get selectAddress => 'Sélectionner une adresse';

  @override
  String get editProfile => 'Modifier le profil';

  @override
  String get personalInformation => 'Informations personnelles';

  @override
  String get accountSettings => 'Paramètres du compte';

  @override
  String get welcome => 'Bienvenue';

  @override
  String get welcomeBack => 'Bon retour';

  @override
  String get signInToContinue => 'Connectez-vous pour continuer';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get signUp => 'S\'inscrire';

  @override
  String get signIn => 'Se connecter';

  @override
  String get verification => 'Vérification';

  @override
  String get verifyPhone => 'Vérifier le téléphone';

  @override
  String get verifyEmail => 'Vérifier l\'e-mail';

  @override
  String get verificationCode => 'Code de vérification';

  @override
  String get resendCode => 'Renvoyer le code';

  @override
  String get allYourNeedsInOneApp => 'Tous Vos Besoins Dans Une Application !';

  @override
  String get enterPhoneNumber => 'Entrez le numéro de téléphone';

  @override
  String get changePhoneNumber => 'Changer le numéro de téléphone';

  @override
  String get verifyAndContinue => 'Vérifier et continuer';

  @override
  String get continueButton => 'Continuer';

  @override
  String get continueAsGuest => 'Continuer en tant qu\'invité';

  @override
  String get didntReceiveCode => 'Vous n\'avez pas reçu le code ? ';

  @override
  String resendIn(int seconds) {
    return 'Renvoyer dans ${seconds}s';
  }

  @override
  String get requestNewCode => 'Demander un nouveau code';

  @override
  String codeExpiresIn(int minutes, int seconds) {
    return 'Le code expire dans ${minutes}m ${seconds}s';
  }

  @override
  String get verificationCodeExpired => 'Le code de vérification a expiré';

  @override
  String get verificationCodeExpiredMessage =>
      'Le code de vérification a expiré. Veuillez en demander un nouveau.';

  @override
  String get sixDigitCode => 'Veuillez entrer un code à 6 chiffres';

  @override
  String get byContinuingYouAgree => 'En continuant, vous acceptez notre ';

  @override
  String get byClickingContinueYouAcknowledge =>
      'EN CLIQUANT sur le bouton continuer, vous reconnaissez avoir lu et accepté la ';

  @override
  String verificationCodeSentTo(String countryCode, String phoneNumber) {
    return 'Code de vérification envoyé à +$countryCode$phoneNumber';
  }

  @override
  String get validationRequired => 'Requis';

  @override
  String get validationEmailInvalid => 'Adresse e-mail invalide';

  @override
  String get validationPhoneInvalid =>
      'Veuillez entrer un numéro de téléphone valide (au moins 10 chiffres)';

  @override
  String get validationPasswordTooShort => 'Mot de passe trop court';

  @override
  String get validationPasswordMismatch =>
      'Les mots de passe ne correspondent pas';

  @override
  String get logoutConfirmation => 'Êtes-vous sûr de vouloir vous déconnecter?';

  @override
  String get tapToChangePhoto => 'Appuyez pour changer la photo';

  @override
  String get fullName => 'Nom complet';

  @override
  String get fullNameRequired => 'Nom complet *';

  @override
  String get nameTooShort => 'Le nom doit contenir au moins 2 caractères';

  @override
  String get dateOfBirth => 'Date de naissance';

  @override
  String get saveChanges => 'Enregistrer les modifications';

  @override
  String get noDraftTasks => 'Aucune tâche en brouillon à réviser';

  @override
  String get taskDescription => 'Description de la tâche:';

  @override
  String get taskLocations => 'Emplacements de la tâche';

  @override
  String get noPhoneProvided => 'Aucun téléphone fourni';

  @override
  String get primaryLocation => 'Emplacement principal';

  @override
  String get additionalLocation => 'Emplacement supplémentaire';

  @override
  String get unknownAddress => 'Adresse inconnue';

  @override
  String get taskProcess => 'Processus de la tâche';

  @override
  String get taskDetails => 'Détails de la tâche';

  @override
  String get taskLocationsCount => 'Emplacements de la tâche';

  @override
  String get tapToViewMap =>
      'Appuyez pour voir la carte avec tous les emplacements';

  @override
  String get unknownPurpose => 'Objectif de l\'emplacement';

  @override
  String get deliverTo => 'Livrer à';

  @override
  String get tapToEnableLocation =>
      'Appuyez pour activer l\'accès à la localisation';

  @override
  String get gpsDisabled => 'GPS désactivé - appuyez pour activer';

  @override
  String get detectingLocation => 'Détection de l\'emplacement...';

  @override
  String get locationOptions => 'Options de localisation';

  @override
  String get selectOnMap => 'Sélectionner sur la carte';

  @override
  String get chooseLocationInteractive =>
      'Choisir l\'emplacement à l\'aide de la carte interactive';

  @override
  String get refreshLocation => 'Actualiser l\'emplacement';

  @override
  String get getCurrentLocationBetter =>
      'Obtenir l\'emplacement actuel avec une meilleure précision';

  @override
  String get noMin => 'Pas de minimum';

  @override
  String get estimatedDeliveryTime => 'Temps de livraison estimé';

  @override
  String get filter => 'Filtrer';

  @override
  String get apply => 'Appliquer';

  @override
  String get sortBy => 'Trier par';

  @override
  String get deliveryTime => 'Temps de livraison';

  @override
  String get alphabetical => 'Alphabétique';

  @override
  String get popular => 'Populaire';

  @override
  String get trending => 'Tendance';

  @override
  String get newItem => 'Nouveau';

  @override
  String get featured => 'En vedette';

  @override
  String get menuItemDetails => 'Détails de l\'article du menu';

  @override
  String get ingredients => 'Ingrédients';

  @override
  String get allergens => 'Allergènes';

  @override
  String get nutritionalInfo => 'Informations nutritionnelles';

  @override
  String get customize => 'Personnaliser';

  @override
  String get share => 'Partager';

  @override
  String get activeOrders => 'Commandes actives';

  @override
  String get orderSummary => 'Résumé de la commande';

  @override
  String get orderDetails => 'Détails de la commande';

  @override
  String get trackOrder => 'Suivre la commande';

  @override
  String get orderStatus => 'Statut de la commande';

  @override
  String get estimatedArrival => 'Arrivée estimée';

  @override
  String get delivered => 'Livré';

  @override
  String get preparing => 'En préparation';

  @override
  String get ready => 'Prêt';

  @override
  String get pickedUp => 'Récupéré';

  @override
  String get cancelled => 'Annulé';

  @override
  String get promoCode => 'Code promo';

  @override
  String get applyPromo => 'Appliquer le code promo';

  @override
  String get addNewAddress => 'Ajouter une nouvelle adresse';

  @override
  String get changeAddress => 'Changer l\'adresse';

  @override
  String get orderUpdates => 'Mises à jour de commande';

  @override
  String get promotionalOffers => 'Offres promotionnelles';

  @override
  String get newRestaurants => 'Nouveaux restaurants';

  @override
  String get deliveryUpdates => 'Mises à jour de livraison';

  @override
  String get checkBackLater => 'Revenez plus tard';

  @override
  String get loadingCuisines => 'Chargement des cuisines...';

  @override
  String get pleaseSelectCuisineType =>
      'Veuillez sélectionner un type de cuisine';

  @override
  String get noMinimum => 'Pas de minimum';

  @override
  String get algerianDinar => 'DA';

  @override
  String restaurantInfoFormat(
      Object city,
      Object deliveryFee,
      Object deliveryTime,
      Object minimumCommande,
      Object minimumOrder,
      Object workingHours) {
    return '$deliveryTime • $minimumCommande • $city • $deliveryFee • $workingHours';
  }

  @override
  String restaurantNameLabel(Object restaurantName) {
    return 'Nom du restaurant: $restaurantName';
  }

  @override
  String restaurantDetailsLabel(Object infoText) {
    return 'Détails du restaurant: $infoText';
  }

  @override
  String doubleTapToRemove(Object restaurantName) {
    return 'Double appui pour retirer $restaurantName des favoris';
  }

  @override
  String doubleTapToAdd(Object restaurantName) {
    return 'Double appui pour ajouter $restaurantName aux favoris';
  }

  @override
  String get available => 'Disponible';

  @override
  String get notAvailable => 'Non disponible';

  @override
  String get priceLabel => 'Prix';

  @override
  String get ratingLabel => 'Note';

  @override
  String get reviewsLabel => 'Avis';

  @override
  String get distanceLabel => 'Distance';

  @override
  String get deliveryTimeLabel => 'Temps de livraison';

  @override
  String get cuisineLabel => 'Cuisine';

  @override
  String get categoryLabel => 'Catégorie';

  @override
  String get featuredLabel => 'En vedette';

  @override
  String get popularLabel => 'Populaire';

  @override
  String get trendingLabel => 'Tendance';

  @override
  String get newLabel => 'Nouveau';

  @override
  String get bestChoicesLabel => 'Meilleurs choix';

  @override
  String get viewAllLabel => 'Voir tout';

  @override
  String get restaurantsLabel => 'Restaurants';

  @override
  String get menuItemsLabel => 'Articles du menu';

  @override
  String get searchRestaurantsLabel => 'Rechercher restaurants';

  @override
  String get filterLabel => 'Filtrer';

  @override
  String get applyLabel => 'Appliquer';

  @override
  String get clearAllLabel => 'Tout effacer';

  @override
  String get priceRangeLabel => 'Plage de prix';

  @override
  String get sortByLabel => 'Trier par';

  @override
  String get distanceSort => 'Distance';

  @override
  String get ratingSort => 'Note';

  @override
  String get deliveryTimeSort => 'Temps de livraison';

  @override
  String get alphabeticalSort => 'Alphabétique';

  @override
  String get noRestaurantsFound => 'Aucun restaurant trouvé';

  @override
  String get tryAdjustingSearch =>
      'Essayez d\'ajuster vos critères de recherche';

  @override
  String get loadingRestaurants => 'Chargement des restaurants...';

  @override
  String get errorLoadingRestaurants =>
      'Erreur lors du chargement des restaurants';

  @override
  String get retryLabel => 'Réessayer';

  @override
  String restaurantsCount(Object count) {
    return '$count restaurants';
  }

  @override
  String get minimumOrderLabel => 'Commande min';

  @override
  String get deliveryFeeLabel => 'Frais de livraison';

  @override
  String get cityLabel => 'Ville';

  @override
  String get workingHoursLabel => 'Heures d\'ouverture';

  @override
  String get openLabel => 'Ouvert';

  @override
  String get closedLabel => 'Fermé';

  @override
  String get minLabel => 'min';

  @override
  String get noMinLabel => 'Pas de minimum';

  @override
  String get freeDeliveryLabel => 'Livraison gratuite';

  @override
  String restaurantLogoLabel(Object restaurantName) {
    return 'Logo du restaurant $restaurantName';
  }

  @override
  String get viewAllButton => 'Voir tout';

  @override
  String get liveUpdatesTitle => 'Mises à jour en direct';

  @override
  String get justNow => 'À l\'instant';

  @override
  String minutesAgo(Object min, Object minutes) {
    return '${min}m';
  }

  @override
  String hoursAgo(int count, String plural) {
    return 'il y a $count $plural';
  }

  @override
  String daysAgo(int count, String plural) {
    return 'il y a $count $plural';
  }

  @override
  String get todayLabel => 'Aujourd\'hui';

  @override
  String get tomorrowLabel => 'Demain';

  @override
  String get openingHoursLabel => 'Heures d\'ouverture';

  @override
  String get closingHoursLabel => 'Heures de fermeture';

  @override
  String menuItemNameLabel(Object itemName) {
    return 'Article du menu : $itemName';
  }

  @override
  String get menuItemName => 'Nom de l\'article du menu';

  @override
  String get enterTheNameOfYourMenuItem =>
      'Entrez le nom de votre article du menu';

  @override
  String menuItemPriceLabel(Object price) {
    return 'Prix: $price DA';
  }

  @override
  String menuItemDescriptionLabel(Object description) {
    return 'Description: $description';
  }

  @override
  String get ingredientsLabel => 'Ingrédients';

  @override
  String get allergensLabel => 'Allergènes';

  @override
  String get nutritionalInfoLabel => 'Informations nutritionnelles';

  @override
  String get customizeLabel => 'Personnaliser';

  @override
  String get shareLabel => 'Partager';

  @override
  String get activeOrdersLabel => 'Commandes actives';

  @override
  String get orderSummaryLabel => 'Résumé de la commande';

  @override
  String get orderDetailsLabel => 'Détails de la commande';

  @override
  String get trackOrderLabel => 'Suivre la commande';

  @override
  String get orderStatusLabel => 'Statut de la commande';

  @override
  String get estimatedArrivalLabel => 'Arrivée estimée';

  @override
  String get deliveredLabel => 'Livré';

  @override
  String get preparingLabel => 'En préparation';

  @override
  String get readyLabel => 'Prêt';

  @override
  String get pickedUpLabel => 'Récupéré';

  @override
  String get cancelledLabel => 'Annulé';

  @override
  String get paymentMethodLabel => 'Méthode de paiement';

  @override
  String get cashOnDeliveryLabel => 'Paiement à la livraison';

  @override
  String get cardPaymentLabel => 'Paiement par carte';

  @override
  String get walletPaymentLabel => 'Paiement par portefeuille';

  @override
  String get promoCodeLabel => 'Code promo';

  @override
  String get applyPromoLabel => 'Appliquer le code promo';

  @override
  String get deliveryAddressLabel => 'Adresse de livraison';

  @override
  String get addNewAddressLabel => 'Ajouter une nouvelle adresse';

  @override
  String get selectAddressLabel => 'Sélectionner une adresse';

  @override
  String get changeAddressLabel => 'Changer l\'adresse';

  @override
  String get notificationsLabel => 'Notifications';

  @override
  String get notificationSettingsLabel => 'Paramètres de notification';

  @override
  String get orderUpdatesLabel => 'Mises à jour de commande';

  @override
  String get promotionalOffersLabel => 'Offres promotionnelles';

  @override
  String get newRestaurantsLabel => 'Nouveaux restaurants';

  @override
  String get deliveryUpdatesLabel => 'Mises à jour de livraison';

  @override
  String get nameMinLength => 'Le nom doit contenir au moins 2 caractères';

  @override
  String get invalidImageError =>
      'Image invalide. Veuillez sélectionner une image valide de moins de 5 Mo.';

  @override
  String get profileImageUpdated => 'Image de profil mise à jour avec succès !';

  @override
  String imageUploadFailed(Object error) {
    return 'Échec du téléchargement de l\'image : $error';
  }

  @override
  String errorOccurred(Object error) {
    return 'Erreur: $error';
  }

  @override
  String get profileUpdated => 'Profil mis à jour avec succès !';

  @override
  String profileUpdateError(Object error) {
    return 'Erreur lors de la mise à jour du profil : $error';
  }

  @override
  String get becomeDeliveryMan => 'Devenir livreur';

  @override
  String get becomeSahlaPartner => 'Devenir partenaire Sahla';

  @override
  String get growWithSahla => 'Développez avec les services Sahla';

  @override
  String get tapToDetectLocation => 'Appuyez pour détecter l\'emplacement';

  @override
  String get deliveryUnavailable => 'Livraison indisponible';

  @override
  String get pickLocation => 'Choisir l\'emplacement';

  @override
  String get editLocation => 'Modifier l\'emplacement';

  @override
  String get proceedOrDiscard => 'Continuer ou Annuler?';

  @override
  String get proceedOrDiscardMessage =>
      'Vous avez activé les services de localisation. Voulez-vous continuer avec l\'emplacement sélectionné ou annuler les modifications?';

  @override
  String get locationEditedMessage =>
      'Vous avez modifié l\'emplacement. Voulez-vous continuer avec l\'emplacement sélectionné ou annuler les modifications?';

  @override
  String get proceed => 'Continuer';

  @override
  String get discard => 'Annuler';

  @override
  String get approximatePrice => 'Prix approximatif';

  @override
  String get addSecondaryPhone => 'Ajouter un numéro de téléphone secondaire?';

  @override
  String get chooseLocationOnMap =>
      'Choisir l\'emplacement à l\'aide de la carte interactive';

  @override
  String get createIfriliTask => 'Créer une tâche Ifrili';

  @override
  String get required => 'Requis';

  @override
  String get dropPinOnMapFirst => 'Placez d\'abord une épingle sur la carte';

  @override
  String get pleaseDropPinOrAddLocations =>
      'Veuillez placer une épingle sur la carte ou ajouter des emplacements';

  @override
  String errorUploadingImage(Object error) {
    return 'Erreur lors du téléchargement de l\'image : $error';
  }

  @override
  String get reviewIfriliTasks => 'Réviser les tâches Ifrili';

  @override
  String get noDraftTasksToReview => 'Aucune tâche en brouillon à réviser';

  @override
  String get confirmCreateTasks => 'Confirmer et créer les tâches';

  @override
  String failedToCreateTasks(Object error) {
    return 'Échec de la création des tâches : $error';
  }

  @override
  String get tapToViewMapWithLocations =>
      'Appuyez pour voir la carte avec tous les emplacements';

  @override
  String locationCount(Object count, Object plural) {
    return '$count location$plural';
  }

  @override
  String get pending => 'En attente';

  @override
  String get costReview => 'Révision du coût';

  @override
  String get costAgreed => 'Coût convenu';

  @override
  String get assigned => 'Assigné';

  @override
  String get completed => 'Terminé';

  @override
  String get taskLocationsSection => 'Emplacements de la tâche:';

  @override
  String failedToOpenMapView(Object error) {
    return 'Échec de l\'ouverture de la vue de la carte : $error';
  }

  @override
  String get deliveryManApplication => 'Candidature de livreur';

  @override
  String get joinOurDeliveryTeam => 'Rejoignez notre équipe de livraison !';

  @override
  String get earnMoneyHelpingPeople =>
      'Gagnez de l\'argent tout en aidant les gens à obtenir leur nourriture';

  @override
  String get enterYourFullName => 'Entrez votre nom complet';

  @override
  String get pleaseEnterYourFullName => 'Veuillez entrer votre nom complet';

  @override
  String get phoneNumberRequired => 'Numéro de téléphone *';

  @override
  String get enterYourPhoneNumber => 'Entrez votre numéro de téléphone';

  @override
  String get pleaseEnterYourPhoneNumber =>
      'Veuillez entrer votre numéro de téléphone';

  @override
  String get addressRequired => 'Adresse *';

  @override
  String get enterYourCurrentAddress => 'Entrez votre adresse actuelle';

  @override
  String get pleaseEnterYourAddress => 'Veuillez entrer votre adresse';

  @override
  String get vehicleInformation => 'Informations sur le véhicule';

  @override
  String get vehicleTypeRequired => 'Type de véhicule *';

  @override
  String get vehicleModelRequired => 'Modèle de véhicule *';

  @override
  String get enterYourVehicleModel => 'Entrez le modèle de votre véhicule';

  @override
  String get pleaseEnterYourVehicleModel =>
      'Veuillez entrer le modèle de votre véhicule';

  @override
  String get vehicleYearRequired => 'Année du véhicule *';

  @override
  String get enterYourVehicleYear => 'Entrez l\'année de votre véhicule';

  @override
  String get pleaseEnterYourVehicleYear =>
      'Veuillez entrer l\'année de votre véhicule';

  @override
  String get vehicleColorRequired => 'Couleur du véhicule *';

  @override
  String get enterYourVehicleColor => 'Entrez la couleur de votre véhicule';

  @override
  String get pleaseEnterYourVehicleColor =>
      'Veuillez entrer la couleur de votre véhicule';

  @override
  String get licenseNumberRequired => 'Numéro de permis *';

  @override
  String get enterYourDrivingLicenseNumber =>
      'Entrez votre numéro de permis de conduire';

  @override
  String get pleaseEnterYourLicenseNumber =>
      'Veuillez entrer votre numéro de permis';

  @override
  String get availability => 'Disponibilité';

  @override
  String get availabilityRequired => 'Disponibilité *';

  @override
  String get previousExperienceOptional => 'Expérience antérieure (optionnel)';

  @override
  String get describePreviousExperience =>
      'Décrivez toute expérience antérieure en livraison ou service client';

  @override
  String get requirements => 'Exigences';

  @override
  String get haveValidDrivingLicense => 'J\'ai un permis de conduire valide';

  @override
  String get haveReliableVehicle => 'J\'ai un véhicule fiable';

  @override
  String get availableOnWeekends => 'Disponible le week-end';

  @override
  String get availableInEvenings => 'Disponible en soirée';

  @override
  String get benefitsOfJoining => 'Avantages de rejoindre';

  @override
  String get flexibleEarningOpportunities => 'Opportunités de gains flexibles';

  @override
  String get workOnYourOwnSchedule => 'Travaillez selon votre propre horaire';

  @override
  String get deliverInYourLocalArea => 'Livrez dans votre région';

  @override
  String get supportTeam => 'Équipe de support 24/7';

  @override
  String get performanceBonuses => 'Bonus de performance';

  @override
  String get submitApplication => 'Soumettre la candidature';

  @override
  String get resetForm => 'Réinitialiser le formulaire';

  @override
  String get submittingApplication => 'Soumission de la candidature...';

  @override
  String get applicationSubmittedSuccessfully =>
      'Candidature soumise avec succès ! Nous l\'examinerons dans les 24 à 48 heures.';

  @override
  String get submitApplicationConfirmation => 'Soumettre la candidature ?';

  @override
  String get confirmApplicationSubmission =>
      'Êtes-vous sûr de vouloir soumettre votre candidature de livraison ? Assurez-vous que toutes les informations sont correctes.';

  @override
  String get termsAndConditions =>
      'En soumettant cette candidature, vous acceptez nos conditions générales et notre politique de confidentialité.';

  @override
  String get validationNameRequired => 'Veuillez entrer votre nom complet';

  @override
  String get validationPhoneRequired =>
      'Veuillez entrer votre numéro de téléphone';

  @override
  String get validationPhoneFormat =>
      'Veuillez entrer un format de numéro de téléphone valide';

  @override
  String get validationAddressRequired => 'Veuillez entrer votre adresse';

  @override
  String get validationVehicleTypeRequired =>
      'Veuillez sélectionner un type de véhicule';

  @override
  String get validationVehicleModelRequired =>
      'Veuillez entrer le modèle de votre véhicule';

  @override
  String get validationVehicleYearRequired =>
      'Veuillez entrer l\'année de votre véhicule';

  @override
  String get validationVehicleColorRequired =>
      'Veuillez entrer la couleur de votre véhicule';

  @override
  String get validationLicenseNumberRequired =>
      'Veuillez entrer votre numéro de permis';

  @override
  String get validationAvailabilityRequired =>
      'Veuillez sélectionner votre disponibilité';

  @override
  String get validationLicenseRequired =>
      'Vous devez avoir un permis de conduire valide';

  @override
  String get validationVehicleRequired => 'Vous devez avoir un véhicule fiable';

  @override
  String errorSubmittingApplication(Object error) {
    return 'Erreur lors de la soumission de la candidature : $error';
  }

  @override
  String get errorUnexpected =>
      'Une erreur inattendue s\'est produite. Veuillez réessayer.';

  @override
  String get errorNetwork => 'Veuillez vérifier votre connexion Internet';

  @override
  String get errorServer =>
      'Service temporairement indisponible. Veuillez réessayer plus tard';

  @override
  String get errorDuplicateApplication =>
      'Vous avez déjà soumis une candidature';

  @override
  String get alreadyExists => 'existe déjà';

  @override
  String get availableForVariants => 'Disponible pour les variantes';

  @override
  String get optional => 'Optionnel';

  @override
  String get selectVariantsForSupplement =>
      'Sélectionnez les variantes pour lesquelles ce supplément est disponible. Laissez vide pour toutes les variantes.';

  @override
  String get errorInvalidYear => 'Veuillez entrer une année valide (1990-2030)';

  @override
  String get errorMissingLicense =>
      'Vous devez avoir un permis de conduire valide';

  @override
  String get errorMissingVehicle => 'Vous devez avoir un véhicule fiable';

  @override
  String get applicationDraftSaved => 'Brouillon enregistré';

  @override
  String get applicationDraftRestored => 'Brouillon restauré';

  @override
  String get yourOrder => 'Your Commande';

  @override
  String get items => 'articles';

  @override
  String get enterPromoCode => 'Entrez le code promo';

  @override
  String get promoCodeApplied => 'Code promo appliqué avec succès !';

  @override
  String get promoCodeRemoved => 'Code promo supprimé';

  @override
  String get promoCodeNotApplicable =>
      'Le code promo n\'est pas applicable à votre panier actuel';

  @override
  String get invalidPromoCode => 'Code promo invalide';

  @override
  String get errorApplyingPromoCode =>
      'Erreur lors de l\'application du code promo. Veuillez réessayer.';

  @override
  String get errorRemovingPromoCode =>
      'Erreur lors de la suppression du code promo';

  @override
  String get clearCart => 'Vider le panier';

  @override
  String get clearCartConfirmation =>
      'Êtes-vous sûr de vouloir retirer tous les articles de votre panier ?';

  @override
  String get discount => 'Remise';

  @override
  String get size => 'Taille';

  @override
  String get regular => 'Régulier';

  @override
  String get noItemsInOrder => 'Aucun article dans cette commande';

  @override
  String get orderNumber => 'Commande n°';

  @override
  String get variant => 'Variante';

  @override
  String get supplements => 'Suppléments';

  @override
  String get drinks => 'boissons';

  @override
  String get drinksByRestaurant => 'Boissons par restaurant';

  @override
  String get variants => 'Variantes';

  @override
  String get forVariant => 'pour';

  @override
  String get customizeIngredients => 'Ingrédients';

  @override
  String get customizeOrder => 'Personnalisez votre commande';

  @override
  String get tapToEdit => 'Appuyez pour modifier';

  @override
  String get tapToExpand => 'Appuyez pour développer';

  @override
  String get addSupplements => 'Ajouter des suppléments';

  @override
  String get mainPackIngredients => 'Ingrédients principaux du pack';

  @override
  String get freeDrinksIncluded => 'Boissons gratuites incluses';

  @override
  String chooseUpToComplimentaryDrink(int count, String drink, String plural) {
    return 'Choisissez jusqu\'à $count $drink gratuit$plural';
  }

  @override
  String get savedOrders => 'Commandes enregistrées';

  @override
  String get choosePreferencesForEachItem =>
      'Choisissez vos préférences pour chaque article';

  @override
  String get chooseVariant => 'Choisissez votre favori';

  @override
  String get ingredientPreferences => 'Préférences d\'ingrédients';

  @override
  String get normal => 'Normal';

  @override
  String get more => 'Plus';

  @override
  String get less => 'Moins';

  @override
  String get wantMore => 'Vous en voulez plus';

  @override
  String get defaultOption => 'Option par défaut';

  @override
  String get specialInstructions => 'Instructions spéciales :';

  @override
  String get removeItem => 'Retirer l\'article';

  @override
  String get removeItemConfirmation => 'Êtes-vous sûr de vouloir retirer';

  @override
  String get fromYourOrder => 'de votre commande ?';

  @override
  String get invalidCartItemData => 'Données d\'article de panier invalides';

  @override
  String get deliveryDetails => 'Détails de livraison';

  @override
  String get useCurrentLocation => 'Utiliser l\'emplacement actuel';

  @override
  String get chooseOnMap => 'Choisir sur la carte';

  @override
  String get loadingAddress => 'Chargement de l\'adresse...';

  @override
  String get noAddressSelected => 'Aucune adresse sélectionnée';

  @override
  String get secondaryPhoneOptional => 'Téléphone secondaire (optionnel)';

  @override
  String get preparingOrder => 'Préparation de votre commande au restaurant...';

  @override
  String get preparingOrderSubtext =>
      'Vous pouvez fermer ceci et suivre en direct à tout moment.';

  @override
  String get readyForPickup => 'Prêt pour la récupération';

  @override
  String get deliveryPartnerPickup =>
      'Un partenaire de livraison récupérera votre commande bientôt.';

  @override
  String get pleaseSelectDeliveryLocation =>
      'Veuillez d\'abord sélectionner une option d\'emplacement de livraison';

  @override
  String get pleaseSelectDeliveryLocationOption =>
      'Veuillez sélectionner un emplacement de livraison';

  @override
  String get failedToConfirmOrder => 'Échec de la confirmation de la commande';

  @override
  String get switchMapType => 'Changer le type de carte';

  @override
  String get selectedOnMap => 'Sélectionné sur la carte';

  @override
  String get yourCartIsEmpty => 'Votre panier est vide';

  @override
  String get addDeliciousItems =>
      'Ajoutez de délicieux articles pour commencer !';

  @override
  String get browseMenu => 'Parcourir le menu';

  @override
  String get tapFloatingCartIcon =>
      'Appuyez sur l\'icône de panier flottante lorsque vous ajoutez des articles';

  @override
  String get cannotPlaceCall =>
      'Impossible de passer un appel sur cet appareil';

  @override
  String get failedToOpenDialer => 'Échec de l\'ouverture du composeur';

  @override
  String get mapLoadingError => 'Erreur de chargement de la carte';

  @override
  String get deliveryPartner => 'Partenaire de livraison';

  @override
  String get onTheWay => 'En chemin';

  @override
  String get phoneNumberNotAvailable => 'Numéro de téléphone non disponible';

  @override
  String get updateLocation => 'Mettre à jour l\'emplacement';

  @override
  String get placed => 'Passée';

  @override
  String get confirmReception => 'Confirmer la réception';

  @override
  String get receptionConfirmed => 'Réception confirmée';

  @override
  String get failedToConfirmReception =>
      'Échec de la confirmation de réception';

  @override
  String get failedToConfirm => 'Échec de la confirmation';

  @override
  String get unitPrice => 'Prix unitaire :';

  @override
  String get quantity => 'Quantité :';

  @override
  String get itemName => 'Nom de l\'article :';

  @override
  String get totalAmount => 'Montant total :';

  @override
  String get dateAt => 'à';

  @override
  String get tasksAndOrders => 'Tâches et commandes';

  @override
  String get active => 'actif';

  @override
  String get enablePermissions => 'Activer les permissions';

  @override
  String get permissionsDescription =>
      'Nous utilisons votre localisation pour afficher les restaurants à proximité et le statut de livraison, et les notifications pour vous tenir informé.';

  @override
  String get locationPermissionTitle =>
      'Localisation (pendant l\'utilisation de l\'application)';

  @override
  String get locationPermissionSubtitle =>
      'Pour les cartes, les résultats à proximité et le suivi de livraison en direct.';

  @override
  String get notificationsPermissionTitle => 'Notifications';

  @override
  String get notificationsPermissionSubtitle =>
      'Recevez les mises à jour de commande et les alertes importantes.';

  @override
  String get allowAll => 'Tout autoriser';

  @override
  String get skipForNow => 'Ignorer pour l\'instant';

  @override
  String get becomeRestaurantOwner => 'Become Restaurant Owner';

  @override
  String get restaurantOwnerApplication => 'Restaurant Owner Application';

  @override
  String get joinOurRestaurantNetwork => 'Join Our Restaurant Network!';

  @override
  String get growYourRestaurantBusiness =>
      'Grow your restaurant business with Sahla';

  @override
  String get serviceAndBasicInfo => 'Service & Basic Info';

  @override
  String get additionalDetails => 'Ajouteritional Details';

  @override
  String get selectService => 'Select service';

  @override
  String get pleaseSelectService => 'Please select a service';

  @override
  String get pleaseSelectServiceType => 'Please select a service type';

  @override
  String get restaurantName => 'Restaurant Name';

  @override
  String get restaurantNameRequired => 'Restaurant name is required';

  @override
  String get enterRestaurantName => 'Enter restaurant name';

  @override
  String get pleaseEnterRestaurantName => 'Please enter restaurant name';

  @override
  String get pleaseEnterValidName =>
      'Please enter a valid name (2-100 characters)';

  @override
  String get restaurantDescription => 'Restaurant Description';

  @override
  String get enterRestaurantDescription => 'Enter restaurant description';

  @override
  String get restaurantPhone => 'Restaurant Phone';

  @override
  String get restaurantPhoneRequired => 'Restaurant phone is required';

  @override
  String get enterRestaurantPhone => 'Enter restaurant phone';

  @override
  String get pleaseEnterRestaurantPhone => 'Please enter restaurant phone';

  @override
  String get pleaseEnterValidPhone => 'Please enter a valid phone number';

  @override
  String get restaurantAddress => 'Restaurant Ajouterress';

  @override
  String get restaurantAddressRequired => 'Restaurant address is required';

  @override
  String get pleaseSelectRestaurantAddress =>
      'Please select restaurant address';

  @override
  String get pleaseSelectLocationWithinAlgeria =>
      'Please select a location within Algeria';

  @override
  String get wilaya => 'Wilaya';

  @override
  String get pleaseSelectWilaya => 'Please select a wilaya';

  @override
  String get groceryType => 'Grocery Type';

  @override
  String get pleaseSelectGroceryType => 'Please select a grocery type';

  @override
  String get superMarket => 'Super Market';

  @override
  String get boucherie => 'Butchery';

  @override
  String get patisserie => 'Pastry Shop';

  @override
  String get fruitsVegetables => 'Fruits & Vegetables';

  @override
  String get bakery => 'Bakery';

  @override
  String get seafood => 'Seafood';

  @override
  String get dairy => 'Dairy';

  @override
  String get other => 'Other';

  @override
  String get logoUpload => 'Logo Upload';

  @override
  String get logoUploadedSuccessfully => 'Logo uploaded successfully!';

  @override
  String get failedToUploadLogo => 'Failed to upload logo';

  @override
  String get logoRemoved => 'Logo removed';

  @override
  String get configureWorkingHours => 'Configure Working Hours';

  @override
  String get pleaseConfigureWorkingHours => 'Please configure working hours';

  @override
  String get pleaseFixWorkingHoursConflicts =>
      'Please fix working hours conflicts';

  @override
  String get socialMediaOptional => 'Social Media (optional)';

  @override
  String get facebook => 'Facebook';

  @override
  String get instagram => 'Instagram';

  @override
  String get tiktok => 'TikTok';

  @override
  String get pleaseEnterValidUrl => 'Please enter a valid URL';

  @override
  String get reachThousandsOfFoodLovers => 'Reach thousands of food lovers';

  @override
  String get detailedAnalyticsAndInsights => 'Detailed analytics and insights';

  @override
  String get customerSupport => '24/7 customer support';

  @override
  String get securePaymentProcessing => 'Secure payment processing';

  @override
  String get deliveryPartnerIntegration => 'Livraison partner integration';

  @override
  String get connectionRestored => 'Connection restored';

  @override
  String get pleaseCheckInternetConnection =>
      'Please check internet connection';

  @override
  String get restaurantRequestSubmittedSuccessfully =>
      'Restaurant request submitted successfully!';

  @override
  String get failedToSubmitRequest => 'Failed to submit request';

  @override
  String get formRestoredFromPreviousSession =>
      'Form restored from previous session';

  @override
  String get workingHours => 'Working Hours';

  @override
  String get monday => 'Monday';

  @override
  String get tuesday => 'Tuesday';

  @override
  String get wednesday => 'Wednesday';

  @override
  String get thursday => 'Thursday';

  @override
  String get friday => 'Friday';

  @override
  String get saturday => 'Saturday';

  @override
  String get sunday => 'Sunday';

  @override
  String get adrar => 'Adrar';

  @override
  String get chlef => 'Chlef';

  @override
  String get laghouat => 'Laghouat';

  @override
  String get oumElBouaghi => 'Oum El Bouaghi';

  @override
  String get batna => 'Batna';

  @override
  String get bejaia => 'Béjaïa';

  @override
  String get biskra => 'Biskra';

  @override
  String get bechar => 'Béchar';

  @override
  String get blida => 'Blida';

  @override
  String get bouira => 'Bouïra';

  @override
  String get tamanrasset => 'Tamanrasset';

  @override
  String get tebessa => 'Tébessa';

  @override
  String get tlemcen => 'Tlemcen';

  @override
  String get tiaret => 'Tiaret';

  @override
  String get tiziOuzou => 'Tizi Ouzou';

  @override
  String get algiers => 'Algiers';

  @override
  String get djelfa => 'Djelfa';

  @override
  String get jijel => 'Jijel';

  @override
  String get setif => 'Sétif';

  @override
  String get saida => 'Saïda';

  @override
  String get skikda => 'Skikda';

  @override
  String get sidiBelAbbes => 'Sidi Bel Abbès';

  @override
  String get annaba => 'Annaba';

  @override
  String get guelma => 'Guelma';

  @override
  String get constantine => 'Constantine';

  @override
  String get medea => 'Médéa';

  @override
  String get mostaganem => 'Mostaganem';

  @override
  String get msila => 'M\'Sila';

  @override
  String get mascara => 'Mascara';

  @override
  String get ouargla => 'Ouargla';

  @override
  String get oran => 'Oran';

  @override
  String get elBayadh => 'El Bayadh';

  @override
  String get illizi => 'Illizi';

  @override
  String get bordjBouArreridj => 'Bordj Bou Arréridj';

  @override
  String get boumerdes => 'Boumerdès';

  @override
  String get elTarf => 'El Tarf';

  @override
  String get tindouf => 'Tindouf';

  @override
  String get tissemsilt => 'Tissemsilt';

  @override
  String get elOued => 'El Oued';

  @override
  String get khenchela => 'Khenchela';

  @override
  String get soukAhras => 'Souk Ahras';

  @override
  String get tipaza => 'Tipaza';

  @override
  String get mila => 'Mila';

  @override
  String get ainDefla => 'Aïn Defla';

  @override
  String get naama => 'Naâma';

  @override
  String get ainTemouchent => 'Aïn Témouchent';

  @override
  String get ghardaia => 'Ghardaïa';

  @override
  String get relizane => 'Relizane';

  @override
  String get timimoun => 'Timimoun';

  @override
  String get bordjBadjiMokhtar => 'Bordj Badji Mokhtar';

  @override
  String get ouledDjellal => 'Ouled Djellal';

  @override
  String get beniAbbes => 'Béni Abbès';

  @override
  String get inSalah => 'In Salah';

  @override
  String get inGuezzam => 'In Guezzam';

  @override
  String get touggourt => 'Touggourt';

  @override
  String get djanet => 'Djanet';

  @override
  String get elMghair => 'El M\'Ghair';

  @override
  String get elMenia => 'El Menia';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String get submitting => 'Soumettreting...';

  @override
  String get restaurantLogo => 'Restaurant Logo';

  @override
  String get tapToAddLogo => 'Tap to add logo';

  @override
  String get upload => 'Upload';

  @override
  String get selectYourWilaya => 'Select your wilaya';

  @override
  String get grocery => 'Grocery';

  @override
  String get handyman => 'Handyman';

  @override
  String get homeFood => 'Accueil Food';

  @override
  String get plateNumberRequired => 'Plate Number *';

  @override
  String get enterYourVehiclePlateNumber => 'Enter your vehicle plate number';

  @override
  String get validationPlateNumberRequired => 'Please enter your plate number';

  @override
  String get tapToViewFullSize => 'Tap to view full size';

  @override
  String get onePhoto => '1 Photo';

  @override
  String get manageMenu => 'Manage Menu';

  @override
  String get userNotAuthenticated => 'User not authenticated';

  @override
  String get noRestaurantFound =>
      'Non restaurant found. Please visit the dashboard first.';

  @override
  String get failedToLoadMenuData => 'Failed to load menu data';

  @override
  String get allCuisines => 'All Cuisines';

  @override
  String get allCategories => 'All Catégories';

  @override
  String get name => 'Name';

  @override
  String get date => 'Date';

  @override
  String get allItems => 'All Items';

  @override
  String get noItemsFoundMatchingFilters =>
      'Non items found matching your filters';

  @override
  String get noMenuItemsYet => 'Non menu items yet';

  @override
  String get tapPlusButtonToAddFirstItem =>
      'Tap the + button to add your first item';

  @override
  String get loadingMoreItems => 'Loading more items...';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get addItem => 'Ajouter Item';

  @override
  String get menuItemUpdatedAndRefreshed => 'Menu item updated and refreshed';

  @override
  String successfullyHidItem(String itemName) {
    return 'Succèsfully hid \"$itemName\"';
  }

  @override
  String successfullyShowedItem(String itemName) {
    return 'Succèsfully showed \"$itemName\"';
  }

  @override
  String failedToUpdateAvailability(String itemName) {
    return 'Failed to update availability for \"$itemName\"';
  }

  @override
  String errorUpdatingAvailability(String error) {
    return 'Erreur updating availability: $error';
  }

  @override
  String get deleteMenuItem => 'Supprimer Menu Item';

  @override
  String deleteMenuItemConfirmation(String itemName) {
    return 'Are you sure you want to delete \"$itemName\"? This action cannot be undone.';
  }

  @override
  String deletingItem(String itemName) {
    return 'Deleting \"$itemName\"...';
  }

  @override
  String successfullyDeletedItem(String itemName) {
    return 'Succèsfully deleted \"$itemName\"';
  }

  @override
  String failedToDeleteItem(String itemName) {
    return 'Failed to delete \"$itemName\"';
  }

  @override
  String errorDeletingItem(String error) {
    return 'Erreur deleting item: $error';
  }

  @override
  String get dietaryInfo => 'Dietary Info';

  @override
  String get spicy => 'Spicy';

  @override
  String get vegetarian => 'Vegetarian';

  @override
  String get traditional => 'Traditional';

  @override
  String get glutenFree => 'Gluten Free';

  @override
  String get description => 'Description';

  @override
  String get mainIngredients => 'Main Ingrédients';

  @override
  String get listMainIngredientsIfNoDescription =>
      'List main ingredients if no description provided';

  @override
  String get addIngredient => 'Ajouter ingredient';

  @override
  String get defaultVariant => 'Default';

  @override
  String get pricingAndSizes => 'Pricing & Sizes';

  @override
  String get variantsAndPricing => 'Variants & Pricing';

  @override
  String get addNewVariant => 'Ajouter New Variant';

  @override
  String get createDifferentVersionsOfDish =>
      'Create different versions of your dish (e.g., Classic, Spicy, Vegetarian)';

  @override
  String get variantName => 'Variant name';

  @override
  String get addVariant => 'Ajouter variant';

  @override
  String get eachVariantCanHaveDifferentSizes =>
      'Each variant can have different sizes and prices';

  @override
  String get forSelectedVariant => 'For selected variant';

  @override
  String get standard => 'Standard';

  @override
  String get dishSupplements => 'Dish Supplements';

  @override
  String get addSupplement => 'Ajouter Supplement';

  @override
  String get supplementExamples =>
      'Examples: Chidar +50 DA, Extra Cheese +30 DA, Spicy Sauce +20 DA';

  @override
  String get availableForAllVariants => 'Disponible for all variants';

  @override
  String get availableFor => 'Disponible for';

  @override
  String get addFlavorAndSize => 'Ajouter Flavor & Size';

  @override
  String get availableForSelectedVariant => 'Disponible for selected variant';

  @override
  String get currentlyUnavailable => 'Currently unavailable';

  @override
  String reviewTitle(String title) {
    return 'Avis $title';
  }

  @override
  String get reviewMenuItem => 'Article du menu';

  @override
  String get reviewRestaurant => 'Restaurant';

  @override
  String get reviewOrder => 'Commande n°';

  @override
  String get reviewMenuItemSubtitle => 'Partagez vos pensées sur ce plat';

  @override
  String get reviewRestaurantSubtitle => 'Comment était votre expérience ?';

  @override
  String get reviewOrderSubtitle =>
      'Évaluez votre expérience de commande globale';

  @override
  String get howWouldYouRateIt => 'Comment le noteriez-vous ?';

  @override
  String get ratingPoor => 'Médiocre';

  @override
  String get ratingFair => 'Passable';

  @override
  String get ratingGood => 'Bien';

  @override
  String get ratingVeryGood => 'Très bien';

  @override
  String get ratingExcellent => 'Excellent';

  @override
  String get selectRating => 'Sélectionner une note';

  @override
  String get shareYourExperience => 'Partagez votre expérience';

  @override
  String get shareYourExperienceOptional =>
      'Partagez votre expérience (optionnel)';

  @override
  String get tellOthersAboutExperience =>
      'Parlez de votre expérience aux autres...';

  @override
  String alsoEnjoying(String restaurantName) {
    return 'Vous appréciez aussi $restaurantName ?';
  }

  @override
  String get shareRestaurantExperience =>
      'Partagez votre expérience du restaurant';

  @override
  String get rateOverallService => 'Évaluez le service global';

  @override
  String thankYouForRating(String restaurantName) {
    return 'Merci d\'avoir noté $restaurantName !';
  }

  @override
  String get addPhotos => 'Ajouter des photos';

  @override
  String get addPhotosOptional => 'Ajouter des photos (optionnel)';

  @override
  String get addPhotosButton => 'Ajouter des photos';

  @override
  String get addMorePhotos => 'Ajouter plus de photos';

  @override
  String get submitReview => 'Soumettre l\'avis';

  @override
  String get restaurantReviewSubmittedSuccessfully =>
      'Avis sur le restaurant soumis avec succès !';

  @override
  String get failedToSubmitRestaurantReview =>
      'Échec de la soumission de l\'avis sur le restaurant. Veuillez réessayer.';

  @override
  String get errorOccurredTryAgain =>
      'Une erreur s\'est produite. Veuillez réessayer.';

  @override
  String get pleaseSelectValidRating => 'Veuillez sélectionner une note valide';

  @override
  String get menuItemNotFound => 'Article du menu introuvable';

  @override
  String get restaurantNotFound => 'Restaurant introuvable';

  @override
  String get orderNotFound => 'Commande introuvable';

  @override
  String get reviewSubmittedSuccessfully => 'Avis soumis avec succès !';

  @override
  String get failedToSubmitReview =>
      'Échec de l\'envoi de l\'avis. Veuillez réessayer.';

  @override
  String get addReview => 'Ajouter un avis';

  @override
  String get viewAllReviews => 'Voir tous les avis';

  @override
  String get reviewsScreenTitle => 'Avis';

  @override
  String get noReviewsYet => 'Aucun avis pour le moment';

  @override
  String get beTheFirstToReview => 'Soyez le premier à donner votre avis';

  @override
  String get oops => 'Oups !';

  @override
  String get failedToLoadReviews => 'Échec du chargement des avis';

  @override
  String get allReviews => 'Tous les avis';

  @override
  String get newest => 'Plus récent';

  @override
  String get oldest => 'Plus ancien';

  @override
  String get highestRated => 'Mieux noté';

  @override
  String get lowestRated => 'Moins bien noté';

  @override
  String monthsAgo(int count, String plural) {
    return '$count $plural ago';
  }

  @override
  String get verifiedUser => 'Utilisateur vérifié';

  @override
  String get anonymousUser => 'Utilisateur anonyme';

  @override
  String reviewForMenuItem(String menuItem) {
    return 'Avis pour $menuItem';
  }

  @override
  String get prep => 'Préparation';

  @override
  String get closesAt => 'Fermeture à';

  @override
  String get opensAt => 'Ouverture à';

  @override
  String get viewReviews => 'Voir les avis';

  @override
  String get minOrder => 'Commande min';

  @override
  String get deliveryFeeShort => 'Frais de livraison';

  @override
  String get avgDeliveryTime => 'Temps de livraison moyen';

  @override
  String get limited => 'Limité';

  @override
  String get expired => 'Expiré';

  @override
  String get limitedTimeOffers => 'Offres à durée limitée';

  @override
  String get free => 'GRATUIT';

  @override
  String get removedIngredients => 'Ingrédients retirés';

  @override
  String get itemsLabel => 'Articles';

  @override
  String get noItemsSelected => 'Aucun article sélectionné';

  @override
  String get errorLoadingOrderSummary =>
      'Erreur lors du chargement du résumé de la commande';
}
