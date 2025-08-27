import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/revenuecat_service.dart';
import '../models/user_model.dart';

class SubscriptionScreen extends StatefulWidget {
  final UserModel? currentUser;
  final bool showUpgradeDialog;

  const SubscriptionScreen({
    Key? key,
    this.currentUser,
    this.showUpgradeDialog = false,
  }) : super(key: key);

  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final RevenueCatService _revenueCatService = RevenueCatService();
  bool _isLoading = false;
  Offerings? _offerings;
  Map<String, dynamic>? _subscriptionInfo;
  Package? _monthlyPackage; 

  @override
  void initState() {
    super.initState();
    _initializeSubscription();
    if (widget.showUpgradeDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showUpgradeDialog();
      });
    }
  }

  Future<void> _initializeSubscription() async {
    setState(() => _isLoading = true);

    try {
      await _revenueCatService.initialize();

      // Login user to RevenueCat
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _revenueCatService.loginUser(user.uid);

        final offerings = await _revenueCatService.getOfferings();
        final subscriptionInfo = await _revenueCatService.getSubscriptionInfo(user.uid);

        final monthlyPackage = await _revenueCatService.getMonthlyPackage();

        setState(() {
          _offerings = offerings;
          _subscriptionInfo = subscriptionInfo;
          _monthlyPackage = monthlyPackage;
        });
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('Failed to load subscription information: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F3E9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFFFF6B35)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Subscription',
          style: TextStyle(
            color: Color(0xFFFF6B35),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading ? _buildLoadingView() : _buildSubscriptionView(),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
          ),
          SizedBox(height: 16),
          Text(
            'Loading subscription details...',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionView() {
    final hasActiveSubscription = _subscriptionInfo?['hasActiveSubscription'] ?? false;

    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCurrentStatusCard(),
          SizedBox(height: 24),
          if (!hasActiveSubscription) ...[
            _buildFreeUsageCard(),
            SizedBox(height: 24),
            _buildSubscriptionPlan(),
            SizedBox(height: 24),
            _buildBenefitsSection(),
          ] else ...[
            _buildManageSubscriptionSection(),
          ],
          SizedBox(height: 24),
          _buildFAQSection(),
        ],
      ),
    );
  }

  Widget _buildCurrentStatusCard() {
    final hasActiveSubscription = _subscriptionInfo?['hasActiveSubscription'] ?? false;
    final status = _subscriptionInfo?['status'] ?? SubscriptionStatus.none;
    final endDate = _subscriptionInfo?['endDate'] as DateTime?;
    final autoRenewing = _subscriptionInfo?['autoRenewing'] ?? false;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasActiveSubscription
              ? [Color(0xFF4CAF50), Color(0xFF66BB6A)]
              : [Color(0xFFFF6B35), Color(0xFFFF8A50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: hasActiveSubscription
                ? Color(0xFF4CAF50).withOpacity(0.3)
                : Color(0xFFFF6B35).withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasActiveSubscription ? Icons.diamond : Icons.music_note,
                color: Colors.white,
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                hasActiveSubscription ? 'Premium Active' : 'Free Plan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (hasActiveSubscription && endDate != null) ...[
            Text(
              autoRenewing ? 'Renews on' : 'Expires on',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            Text(
              '${endDate.day}/${endDate.month}/${endDate.year}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (autoRenewing) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Auto-renewing',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ] else ...[
            Text(
              'Enjoy unlimited practice with Premium',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFreeUsageCard() {
    final remainingMinutes = _subscriptionInfo?['remainingFreeMinutes'] ?? 15;
    final usedMinutes = _subscriptionInfo?['freePracticeMinutesUsed'] ?? 0;
    final totalFreeMinutes = 15;
    final progress = usedMinutes / totalFreeMinutes;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: Color(0xFFFF6B35)),
              SizedBox(width: 8),
              Text(
                'Daily Free Usage',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$remainingMinutes minutes left today',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              Text(
                '$usedMinutes / $totalFreeMinutes min',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              remainingMinutes > 5 ? Color(0xFF4CAF50) :
              remainingMinutes > 0 ? Colors.orange : Colors.red,
            ),
          ),
          SizedBox(height: 12),
          Text(
            remainingMinutes > 0
                ? 'Practice time resets every day at midnight'
                : 'Free time used up! Subscribe for unlimited access or try tomorrow.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionPlan() {
    if (_monthlyPackage == null) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.grey, size: 48),
            SizedBox(height: 16),
            Text(
              'No subscription plans available',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Please check your connection and try again.',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    final package = _monthlyPackage!;

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFFF6B35), width: 2),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFF6B35).withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Color(0xFFFF6B35),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'RECOMMENDED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 16),
          Icon(
            Icons.diamond,
            color: Color(0xFFFF6B35),
            size: 48,
          ),
          SizedBox(height: 12),
          Text(
            'Premium Monthly',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            package.storeProduct.priceString,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF6B35),
            ),
          ),
          Text(
            'per month',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          if (package.storeProduct.description.isNotEmpty) ...[
            Text(
              package.storeProduct.description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
          ],
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _purchaseSubscription,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFF6B35),
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              )
                  : Text(
                'Subscribe Now',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Cancel anytime from Play Store',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
          if (package.storeProduct.identifier.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              'Product: ${package.storeProduct.identifier}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[400],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBenefitsSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Premium Benefits',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          _buildBenefitItem(
            Icons.all_inclusive,
            'Unlimited Practice',
            'Practice as much as you want, no daily limits',
          ),
          _buildBenefitItem(
            Icons.music_note,
            'All Lessons',
            'Access to all current and future lessons',
          ),
          _buildBenefitItem(
            Icons.analytics,
            'Advanced Analytics',
            'Detailed progress tracking and insights',
          ),
          _buildBenefitItem(
            Icons.support_agent,
            'Priority Support',
            'Get faster help when you need it',
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String description) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFFFF6B35).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Color(0xFFFF6B35), size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManageSubscriptionSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manage Subscription',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          ListTile(
            leading: Icon(Icons.refresh, color: Color(0xFFFF6B35)),
            title: Text('Restore Purchases'),
            subtitle: Text('Restore previous purchases'),
            onTap: _restorePurchases,
          ),
          ListTile(
            leading: Icon(Icons.store, color: Color(0xFFFF6B35)),
            title: Text('Manage in Play Store'),
            subtitle: Text('Cancel or modify subscription'),
            onTap: _openPlayStore,
          ),
        ],
      ),
    );
  }

  Widget _buildFAQSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Frequently Asked Questions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          _buildFAQItem(
            'How does the free plan work?',
            'You get 15 minutes of practice time daily. This resets every day at midnight.',
          ),
          _buildFAQItem(
            'Can I cancel anytime?',
            'Yes! You can cancel your subscription anytime from the Google Play Store.',
          ),
          _buildFAQItem(
            'What happens after cancellation?',
            'You\'ll continue to have premium access until the end of your billing period, then return to the free plan.',
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return ExpansionTile(
      title: Text(
        question,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            answer,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.timer, color: Color(0xFFFF6B35)),
            SizedBox(width: 8),
            Text('Practice Time Up!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your 15-minute free session is over for today.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Subscribe to Premium for unlimited practice or try again tomorrow!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Try Tomorrow'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _purchaseSubscription();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFF6B35)),
            child: Text('Subscribe', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _purchaseSubscription() async {
    setState(() => _isLoading = true);

    try {
      print('🛒 [DEBUG] Starting purchase from SubscriptionScreen...');
      final success = await _revenueCatService.purchaseSubscription();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subscription activated successfully!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        // Refresh subscription info
        await _initializeSubscription();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase failed or was cancelled'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ [DEBUG] Purchase error in SubscriptionScreen: $e');
      _showErrorDialog('Purchase failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);

    try {
      await _revenueCatService.restorePurchases();
      await _initializeSubscription(); // Refresh data
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchases restored successfully'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      _showErrorDialog('Failed to restore purchases: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _openPlayStore() async {
    const url = 'https://play.google.com/store/account/subscriptions';

    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please visit: Open Google Play Store > Account > Subscriptions'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error opening Google Play Store: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open privacy policy. Please visit: Open Google Play Store > Account > Subscriptions'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Error'),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFF6B35)),
            child: Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _revenueCatService.dispose();
    super.dispose();
  }
}
