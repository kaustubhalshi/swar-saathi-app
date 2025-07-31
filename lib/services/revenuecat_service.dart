import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class RevenueCatService {
  // ⭐ REMOVED: No more hardcoded product ID
  // static const String monthlySubscriptionId = 'swar_saathi_monthly_99:premium-monthly-99';

  static const String entitlementId = 'premium';
  static const int freeMinutesLimit = 15;

  // Replace with your actual RevenueCat API keys
  static const String _androidApiKey = 'goog_RMhtdlCcrMIVlrUjdpuNtsEkHXu';
  static const String _iosApiKey = 'appl_YOUR_IOS_API_KEY';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ⭐ NEW: Cache for dynamically fetched product ID
  String? _cachedMonthlyProductId;

  // Initialize RevenueCat
  Future<void> initialize() async {
    try {
      // Configure RevenueCat
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);

      // Configure with your API keys
      PurchasesConfiguration configuration;
      if (defaultTargetPlatform == TargetPlatform.android) {
        configuration = PurchasesConfiguration(_androidApiKey);
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        configuration = PurchasesConfiguration(_iosApiKey);
      } else {
        throw Exception('Unsupported platform');
      }

      await Purchases.configure(configuration);

      // Set user ID if logged in
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await Purchases.logIn(currentUser.uid);
        print('✅ User logged in to RevenueCat: ${currentUser.uid}');
      }

      print('✅ RevenueCat initialized successfully');

      // Test connection and cache product ID
      await _testConnection();
      await _cacheMonthlyProductId();

    } catch (e) {
      print('❌ Error initializing RevenueCat: $e');
      rethrow;
    }
  }

  // ⭐ NEW: Cache the monthly product ID dynamically
  Future<void> _cacheMonthlyProductId() async {
    try {
      final productId = await getMonthlySubscriptionId();
      if (productId != null) {
        _cachedMonthlyProductId = productId;
        print('✅ Cached monthly product ID: $_cachedMonthlyProductId');
      } else {
        print('⚠️ No monthly product ID found to cache');
      }
    } catch (e) {
      print('❌ Error caching product ID: $e');
    }
  }

  // ⭐ NEW: Dynamically get monthly subscription product ID
  Future<String?> getMonthlySubscriptionId() async {
    try {
      print('🔍 [DEBUG] Fetching monthly subscription ID dynamically...');

      final offerings = await Purchases.getOfferings();

      if (offerings.current == null) {
        print('❌ [DEBUG] No current offering found');
        return null;
      }

      print('✅ [DEBUG] Current offering found: ${offerings.current!.identifier}');
      print('📦 [DEBUG] Available packages: ${offerings.current!.availablePackages.length}');

      // Method 1: Try to get monthly package directly
      final monthlyPackage = offerings.current!.monthly;
      if (monthlyPackage != null) {
        print('✅ [DEBUG] Found monthly package: ${monthlyPackage.storeProduct.identifier}');
        return monthlyPackage.storeProduct.identifier;
      }

      // Method 2: Search through available packages
      for (final package in offerings.current!.availablePackages) {
        print('📦 [DEBUG] Checking package: ${package.identifier} -> ${package.storeProduct.identifier}');

        // Look for monthly indicators
        if (package.identifier.contains('monthly') ||
            package.identifier.contains('\$rc_monthly') ||
            package.storeProduct.identifier.contains('monthly')) {
          print('✅ [DEBUG] Found monthly product by search: ${package.storeProduct.identifier}');
          return package.storeProduct.identifier;
        }
      }

      // Method 3: If only one package, assume it's the monthly one
      if (offerings.current!.availablePackages.length == 1) {
        final singlePackage = offerings.current!.availablePackages.first;
        print('✅ [DEBUG] Using single available package: ${singlePackage.storeProduct.identifier}');
        return singlePackage.storeProduct.identifier;
      }

      print('❌ [DEBUG] No monthly subscription product found');
      return null;
    } catch (e) {
      print('❌ [DEBUG] Error fetching monthly subscription ID: $e');
      return null;
    }
  }

  // ⭐ NEW: Get monthly package dynamically
  Future<Package?> getMonthlyPackage() async {
    try {
      final offerings = await getOfferings();
      if (offerings?.current == null) {
        print('❌ No current offering available');
        return null;
      }

      final currentOffering = offerings!.current!;

      // Method 1: Try direct monthly access
      Package? monthlyPackage = currentOffering.monthly;
      if (monthlyPackage != null) {
        print('✅ Found monthly package directly: ${monthlyPackage.storeProduct.identifier}');
        return monthlyPackage;
      }

      // Method 2: Search by identifier patterns
      final searchPatterns = ['\$rc_monthly', 'monthly'];

      for (final pattern in searchPatterns) {
        try {
          monthlyPackage = currentOffering.availablePackages.firstWhere(
                (package) => package.identifier.contains(pattern),
          );
          print('✅ Found monthly package by pattern "$pattern": ${monthlyPackage.storeProduct.identifier}');
          return monthlyPackage;
        } catch (e) {
          // Continue searching
        }
      }

      // Method 3: Use cached product ID if available
      if (_cachedMonthlyProductId != null) {
        try {
          monthlyPackage = currentOffering.availablePackages.firstWhere(
                (package) => package.storeProduct.identifier == _cachedMonthlyProductId,
          );
          print('✅ Found monthly package by cached ID: ${monthlyPackage.storeProduct.identifier}');
          return monthlyPackage;
        } catch (e) {
          // Continue
        }
      }

      // Method 4: If only one package, use it
      if (currentOffering.availablePackages.length == 1) {
        monthlyPackage = currentOffering.availablePackages.first;
        print('✅ Using single available package: ${monthlyPackage.storeProduct.identifier}');
        return monthlyPackage;
      }

      print('❌ No monthly package found');
      return null;
    } catch (e) {
      print('❌ Error getting monthly package: $e');
      return null;
    }
  }

  // Test RevenueCat connection
  Future<void> _testConnection() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      print('✅ RevenueCat connection test successful');
      print('📊 Customer ID: ${customerInfo.originalAppUserId}');
      print('📊 Active entitlements: ${customerInfo.entitlements.active.keys.toList()}');
    } catch (e) {
      print('⚠️ RevenueCat connection test failed: $e');
    }
  }

  // Handle customer info updates (called manually when needed)
  Future<void> _onCustomerInfoUpdate(CustomerInfo customerInfo) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await _updateUserSubscriptionFromCustomerInfo(currentUser.uid, customerInfo);
    } catch (e) {
      print('❌ Error handling customer info update: $e');
    }
  }

  // Login user to RevenueCat
  Future<void> loginUser(String userId) async {
    try {
      final logInResult = await Purchases.logIn(userId);
      print('✅ User logged in to RevenueCat: $userId');

      // Update subscription status immediately after login
      await _onCustomerInfoUpdate(logInResult.customerInfo);

    } catch (e) {
      print('❌ Error logging in user to RevenueCat: $e');
      rethrow;
    }
  }

  // Logout user from RevenueCat
  Future<void> logoutUser() async {
    try {
      await Purchases.logOut();
      print('✅ User logged out from RevenueCat');
    } catch (e) {
      print('❌ Error logging out user from RevenueCat: $e');
    }
  }

  // Get available offerings with better error handling
  Future<Offerings?> getOfferings() async {
    try {
      print('🔍 [DEBUG] Fetching offerings from RevenueCat...');
      final offerings = await Purchases.getOfferings();

      print('🔍 [DEBUG] Raw offerings response: ${offerings.toString()}');
      print('🔍 [DEBUG] Current offering: ${offerings.current?.identifier ?? "NULL"}');

      if (offerings.current == null) {
        print('❌ [DEBUG] No current offering found');
        print('🔍 [DEBUG] All offerings: ${offerings.all.keys.toList()}');
        return null;
      }

      print('✅ [DEBUG] Current offering found: ${offerings.current!.identifier}');
      print('📦 [DEBUG] Available packages count: ${offerings.current!.availablePackages.length}');

      // Log every single package for debugging
      for (int i = 0; i < offerings.current!.availablePackages.length; i++) {
        final package = offerings.current!.availablePackages[i];
        print('📦 [DEBUG] Package $i:');
        print('   - Package ID: ${package.identifier}');
        print('   - Store Product ID: ${package.storeProduct.identifier}');
        print('   - Price: ${package.storeProduct.priceString}');
        print('   - Title: ${package.storeProduct.title}');
        print('   - Description: ${package.storeProduct.description}');
      }

      return offerings;
    } catch (e) {
      print('❌ [DEBUG] RevenueCat offerings error: $e');
      print('❌ [DEBUG] Error type: ${e.runtimeType}');
      return null;
    }
  }

  // ⭐ UPDATED: Purchase subscription with dynamic package finding
  Future<bool> purchaseSubscription() async {
    try {
      print('🛒 [DEBUG] Starting purchase process...');

      // Get monthly package dynamically
      final monthlyPackage = await getMonthlyPackage();

      if (monthlyPackage == null) {
        throw Exception('No monthly subscription package available. Check RevenueCat configuration.');
      }

      print('🛒 [DEBUG] Attempting to purchase: ${monthlyPackage.storeProduct.identifier}');
      print('🛒 [DEBUG] Package price: ${monthlyPackage.storeProduct.priceString}');

      final customerInfo = await Purchases.purchasePackage(monthlyPackage);

      // Update Firestore based on purchase result
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await _onCustomerInfoUpdate(customerInfo);
      }

      // Check for specific entitlement
      final hasActiveSubscription = customerInfo.entitlements.active.containsKey(entitlementId);

      if (hasActiveSubscription) {
        print('✅ Purchase successful with active entitlement!');
        return true;
      } else {
        print('⚠️ Purchase completed but no active entitlement found');
        return false;
      }

    } on PurchasesErrorCode catch (e) {
      print('❌ RevenueCat purchase error: ${e.toString()}');
      _handlePurchaseError(e);
      return false;
    } catch (e) {
      print('❌ Purchase error: $e');
      return false;
    }
  }

  // Handle purchase errors
  void _handlePurchaseError(PurchasesErrorCode error) {
    switch (error) {
      case PurchasesErrorCode.purchaseCancelledError:
        print('🚫 User cancelled purchase');
        break;
      case PurchasesErrorCode.storeProblemError:
        print('❌ Store problem error');
        break;
      case PurchasesErrorCode.purchaseNotAllowedError:
        print('❌ Purchase not allowed');
        break;
      case PurchasesErrorCode.purchaseInvalidError:
        print('❌ Purchase invalid');
        break;
      case PurchasesErrorCode.productNotAvailableForPurchaseError:
        print('❌ Product not available for purchase');
        break;
      case PurchasesErrorCode.productAlreadyPurchasedError:
        print('⚠️ Product already purchased');
        break;
      case PurchasesErrorCode.receiptAlreadyInUseError:
        print('⚠️ Receipt already in use');
        break;
      case PurchasesErrorCode.networkError:
        print('📶 Network error');
        break;
      default:
        print('❌ Unknown purchase error: $error');
    }
  }

  // Restore purchases
  Future<void> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();

      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await _onCustomerInfoUpdate(customerInfo);
      }

      print('✅ Purchases restored successfully');
    } catch (e) {
      print('❌ Error restoring purchases: $e');
      rethrow;
    }
  }

  // Update user subscription with specific entitlement check
  Future<void> _updateUserSubscriptionFromCustomerInfo(String uid, CustomerInfo customerInfo) async {
    try {
      bool isPremium = false;
      SubscriptionStatus status = SubscriptionStatus.none;
      DateTime? subscriptionEndDate;
      DateTime? subscriptionStartDate;
      String? subscriptionId;
      String? productId;
      bool autoRenewing = false;

      // Check for specific entitlement
      final premiumEntitlement = customerInfo.entitlements.all[entitlementId];

      if (premiumEntitlement != null) {
        isPremium = premiumEntitlement.isActive;

        if (isPremium) {
          status = SubscriptionStatus.active;
        } else {
          // Check if expired
          final expirationDate = premiumEntitlement.expirationDate != null
              ? DateTime.tryParse(premiumEntitlement.expirationDate!)
              : null;

          if (expirationDate != null && expirationDate.isBefore(DateTime.now())) {
            status = SubscriptionStatus.expired;
          }
        }

        // Parse dates properly
        subscriptionEndDate = premiumEntitlement.expirationDate != null
            ? DateTime.tryParse(premiumEntitlement.expirationDate!)
            : null;
        subscriptionStartDate = premiumEntitlement.latestPurchaseDate != null
            ? DateTime.tryParse(premiumEntitlement.latestPurchaseDate!)
            : null;
        subscriptionId = premiumEntitlement.identifier;
        productId = premiumEntitlement.productIdentifier;
        autoRenewing = premiumEntitlement.willRenew;
      }

      // Update Firestore
      await _firestore.collection('users').doc(uid).update({
        'subscriptionStatus': status.toString(),
        'isPremium': isPremium,
        'subscriptionId': subscriptionId,
        'subscriptionStartDate': subscriptionStartDate != null ? Timestamp.fromDate(subscriptionStartDate) : null,
        'subscriptionEndDate': subscriptionEndDate != null ? Timestamp.fromDate(subscriptionEndDate) : null,
        'subscriptionProductId': productId,
        'autoRenewing': autoRenewing,
        'lastSubscriptionCheck': Timestamp.fromDate(DateTime.now()),
      });

      print('✅ Subscription updated in Firestore');
      print('💎 Premium: $isPremium, Status: $status, End Date: $subscriptionEndDate');
    } catch (e) {
      print('❌ Error updating subscription in Firestore: $e');
      rethrow;
    }
  }

  // Check subscription status with specific entitlement
  Future<bool> checkSubscriptionStatus(String uid) async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      await _onCustomerInfoUpdate(customerInfo);

      // Check for specific entitlement
      final premiumEntitlement = customerInfo.entitlements.all[entitlementId];
      return premiumEntitlement?.isActive ?? false;

    } catch (e) {
      print('❌ Error checking subscription status: $e');

      // Fallback to Firestore check
      try {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          final subscriptionEndDate = (data['subscriptionEndDate'] as Timestamp?)?.toDate();
          final subscriptionStatus = SubscriptionStatus.fromString(data['subscriptionStatus'] ?? 'none');

          if (subscriptionEndDate != null && subscriptionStatus == SubscriptionStatus.active) {
            return DateTime.now().isBefore(subscriptionEndDate);
          }
        }
      } catch (firestoreError) {
        print('❌ Firestore fallback also failed: $firestoreError');
      }

      return false;
    }
  }

  // Check if user can practice
  Future<bool> canUserPractice(String uid) async {
    try {
      // First check if user has active subscription
      final hasActiveSubscription = await checkSubscriptionStatus(uid);
      if (hasActiveSubscription) return true;

      // Check daily practice reset
      await _checkAndResetDailyPractice(uid);

      // Check free minutes used
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) return false;

      final data = userDoc.data() as Map<String, dynamic>;
      final freePracticeMinutesUsed = data['freePracticeMinutesUsed'] ?? 0;

      return freePracticeMinutesUsed < freeMinutesLimit;
    } catch (e) {
      print('❌ Error checking if user can practice: $e');
      return false;
    }
  }

  // Add practice minutes and check limits
  Future<bool> addPracticeMinutes(String uid, int minutes) async {
    try {
      final hasActiveSubscription = await checkSubscriptionStatus(uid);

      if (hasActiveSubscription) {
        // Premium user - no limits, just add minutes
        await _firestore.collection('users').doc(uid).update({
          'totalPracticeMinutes': FieldValue.increment(minutes),
          'allTimePracticeMinutes': FieldValue.increment(minutes),
        });
        print('✅ Premium user: Added $minutes minutes without limits');
        return true;
      }

      // Free user - check limits
      await _checkAndResetDailyPractice(uid);

      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) return false;

      final data = userDoc.data() as Map<String, dynamic>;
      final freePracticeMinutesUsed = data['freePracticeMinutesUsed'] ?? 0;

      final newTotalUsed = freePracticeMinutesUsed + minutes;

      if (newTotalUsed <= freeMinutesLimit) {
        // Within free limit
        await _firestore.collection('users').doc(uid).update({
          'totalPracticeMinutes': FieldValue.increment(minutes),
          'allTimePracticeMinutes': FieldValue.increment(minutes),
          'freePracticeMinutesUsed': newTotalUsed,
        });
        print('✅ Free user: Added $minutes minutes (${newTotalUsed}/${freeMinutesLimit})');
        return true;
      } else {
        // Exceeded free limit
        final remainingFreeMinutes = freeMinutesLimit - freePracticeMinutesUsed;
        if (remainingFreeMinutes > 0) {
          // Add only the remaining free minutes
          await _firestore.collection('users').doc(uid).update({
            'totalPracticeMinutes': FieldValue.increment(remainingFreeMinutes),
            'allTimePracticeMinutes': FieldValue.increment(remainingFreeMinutes),
            'freePracticeMinutesUsed': freeMinutesLimit,
          });
          print('⚠️ Free limit reached: Added only $remainingFreeMinutes minutes');
        }
        return false; // Indicates limit reached
      }
    } catch (e) {
      print('❌ Error adding practice minutes: $e');
      return false;
    }
  }

  // Check and reset daily practice if new day
  Future<void> _checkAndResetDailyPractice(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) return;

      final data = userDoc.data() as Map<String, dynamic>;
      final lastResetDate = (data['lastPracticeResetDate'] as Timestamp?)?.toDate();

      if (lastResetDate != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final lastResetDay = DateTime(lastResetDate.year, lastResetDate.month, lastResetDate.day);

        if (today.isAfter(lastResetDay)) {
          // New day - reset daily practice minutes and free minutes used
          final weeklyProgress = Map<String, int>.from(data['weeklyProgress'] ?? {});
          final yesterdayKey = _getDayKey(lastResetDay);
          weeklyProgress[yesterdayKey] = data['totalPracticeMinutes'] ?? 0;

          await _firestore.collection('users').doc(uid).update({
            'totalPracticeMinutes': 0,
            'freePracticeMinutesUsed': 0,
            'lastPracticeResetDate': Timestamp.fromDate(now),
            'weeklyProgress': weeklyProgress,
          });
          print('🔄 Daily practice reset completed for new day');
        }
      }
    } catch (e) {
      print('❌ Error checking daily practice reset: $e');
    }
  }

  // Get remaining free minutes for user
  Future<int> getRemainingFreeMinutes(String uid) async {
    try {
      final hasActiveSubscription = await checkSubscriptionStatus(uid);
      if (hasActiveSubscription) return -1; // Unlimited for premium users

      await _checkAndResetDailyPractice(uid);

      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) return freeMinutesLimit;

      final data = userDoc.data() as Map<String, dynamic>;
      final freePracticeMinutesUsed = data['freePracticeMinutesUsed'] ?? 0;

      return (freeMinutesLimit - freePracticeMinutesUsed).clamp(0, freeMinutesLimit).toInt();
    } catch (e) {
      print('❌ Error getting remaining free minutes: $e');
      return 0;
    }
  }

  // Get subscription info with specific entitlement check
  Future<Map<String, dynamic>?> getSubscriptionInfo(String uid) async {
    try {
      // Get fresh info from RevenueCat
      final customerInfo = await Purchases.getCustomerInfo();
      await _onCustomerInfoUpdate(customerInfo);

      // Get updated info from Firestore
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) return null;

      final data = userDoc.data() as Map<String, dynamic>;
      final subscriptionStatus = SubscriptionStatus.fromString(data['subscriptionStatus'] ?? 'none');
      final subscriptionEndDate = (data['subscriptionEndDate'] as Timestamp?)?.toDate();
      final autoRenewing = data['autoRenewing'] ?? false;
      final freePracticeMinutesUsed = data['freePracticeMinutesUsed'] ?? 0;

      // Check specific entitlement
      final premiumEntitlement = customerInfo.entitlements.all[entitlementId];
      final hasActiveSubscription = premiumEntitlement?.isActive ?? false;

      return {
        'status': subscriptionStatus,
        'endDate': subscriptionEndDate,
        'autoRenewing': autoRenewing,
        'hasActiveSubscription': hasActiveSubscription,
        'freePracticeMinutesUsed': freePracticeMinutesUsed,
        'remainingFreeMinutes': await getRemainingFreeMinutes(uid),
      };
    } catch (e) {
      print('❌ Error getting subscription info: $e');
      return null;
    }
  }

  // Check if practice session can start
  Future<Map<String, dynamic>> checkPracticePermission(String uid) async {
    try {
      final hasActiveSubscription = await checkSubscriptionStatus(uid);

      if (hasActiveSubscription) {
        return {
          'canPractice': true,
          'isPremium': true,
          'message': 'Enjoy unlimited practice! 💎',
        };
      }

      await _checkAndResetDailyPractice(uid);

      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        return {
          'canPractice': false,
          'isPremium': false,
          'message': 'User not found',
        };
      }

      final data = userDoc.data() as Map<String, dynamic>;
      final freePracticeMinutesUsed = data['freePracticeMinutesUsed'] ?? 0;
      final remainingMinutes = freeMinutesLimit - freePracticeMinutesUsed;

      if (remainingMinutes > 0) {
        return {
          'canPractice': true,
          'isPremium': false,
          'remainingMinutes': remainingMinutes,
          'message': 'You have $remainingMinutes free minutes left today ⏰',
        };
      } else {
        return {
          'canPractice': false,
          'isPremium': false,
          'remainingMinutes': 0,
          'message': 'Your 15-minute free session is over. Subscribe for unlimited access or try again tomorrow! 🚀',
        };
      }
    } catch (e) {
      print('❌ Error checking practice permission: $e');
      return {
        'canPractice': false,
        'isPremium': false,
        'message': 'Error checking permissions. Please try again.',
      };
    }
  }

  // Helper method to get day key
  String _getDayKey(DateTime date) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  // Dispose the service
  void dispose() {
    print('🧹 RevenueCat service disposed');
  }
}