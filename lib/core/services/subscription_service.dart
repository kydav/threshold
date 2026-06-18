import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:threshold/core/config/revenue_cat_config.dart';
import 'package:threshold/features/auth/data/auth_service.dart';

/// Call once at app startup before runApp.
Future<void> configureRevenueCat() async {
  final apiKey = Platform.isIOS ? kRevenueCatIosKey : kRevenueCatAndroidKey;
  await Purchases.configure(PurchasesConfiguration(apiKey));
}

class SubscriptionNotifier extends AsyncNotifier<CustomerInfo?> {
  @override
  Future<CustomerInfo?> build() async {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) {
      try {
        await Purchases.logOut();
      } catch (_) {}
      return null;
    }
    final result = await Purchases.logIn(user.uid);
    return result.customerInfo;
  }

  bool get isProActive {
    final info = state.valueOrNull;
    if (info == null) return false;
    return info.entitlements.active.containsKey(kEntitlementId);
  }

  /// Fetches the default offering and purchases the first available package.
  /// Returns true on success.
  Future<bool> purchase() async {
    try {
      final offerings = await Purchases.getOfferings();
      final package = offerings.current?.availablePackages.firstOrNull;
      if (package == null) return false;
      final result = await Purchases.purchase(PurchaseParams.package(package));
      state = AsyncData(result.customerInfo);
      return result.customerInfo.entitlements.active.containsKey(
        kEntitlementId,
      );
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) return false;
      rethrow;
    }
  }

  Future<void> restore() async {
    final info = await Purchases.restorePurchases();
    state = AsyncData(info);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final info = await Purchases.getCustomerInfo();
      return info;
    });
  }
}

final subscriptionProvider =
    AsyncNotifierProvider<SubscriptionNotifier, CustomerInfo?>(
      SubscriptionNotifier.new,
    );
