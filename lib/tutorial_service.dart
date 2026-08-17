import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  static const String _completedKey = 'tutorial_completed_';
  static const String _onboardingKey = 'onboarding_completed';
  static const String _tutorialVersionKey = 'tutorial_version';
  static const String currentVersion = '2.0';

  /// Check if first-time user (onboarding not completed)
  static Future<bool> isFirstTimeUser() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getBool(_onboardingKey) ?? false) == false;
  }

  /// Mark onboarding as completed
  static Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
  }

  /// Mark a specific tutorial as completed
  static Future<void> completeTutorial(String tutorialId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_completedKey$tutorialId', true);
  }

  /// Check if tutorial is completed
  static Future<bool> isTutorialCompleted(String tutorialId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_completedKey$tutorialId') ?? false;
  }

  /// Reset all tutorials
  static Future<void> resetAllTutorials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, false);
    
    // Clear all tutorial flags
    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith(_completedKey)) {
        await prefs.remove(key);
      }
    }
  }

  /// Get all available onboarding steps
  static List<OnboardingStep> getOnboardingSteps() {
    return [
      OnboardingStep(
        id: 'welcome',
        title: 'Welcome to Retail Mind',
        description: 'Your AI-powered retail management assistant',
        icon: '👋',
        details: [
          'Track sales in real-time',
          'Get AI-powered insights',
          'Accept digital payments',
          'Analyze performance metrics',
        ],
      ),
      OnboardingStep(
        id: 'dashboard',
        title: 'Dashboard Overview',
        description: 'See your shop\'s daily performance at a glance',
        icon: '📊',
        details: [
          '• Today\'s Sales - Real-time revenue tracking',
          '• Growth Metrics - Compare with previous days',
          '• Best Performing Hour - Peak business time',
          '• Top Products - Most sold items',
          '• Performance Rating - Your shop\'s score',
        ],
      ),
      OnboardingStep(
        id: 'sales_entry',
        title: 'Manual Sales Entry',
        description: 'Record sales quickly with our intuitive entry system',
        icon: '💳',
        details: [
          '1. Enter product name and quantity',
          '2. Set price per unit',
          '3. Select payment method (Cash/UPI)',
          '4. Generate bill',
          '5. Save to database',
        ],
      ),
      OnboardingStep(
        id: 'payment_detection',
        title: 'Smart Payment Detection',
        description: 'Automatic payment capture from multiple channels',
        icon: '💰',
        details: [
          '✓ Google Pay, PhonePe, Paytm',
          '✓ Bank SMSes',
          '✓ QR code scanning',
          '✓ Real-time updates',
          '✓ Confidence scoring',
        ],
      ),
      OnboardingStep(
        id: 'analytics',
        title: 'Advanced Analytics',
        description: 'Deep insights into your shop\'s performance',
        icon: '📈',
        details: [
          '• Sales trends and forecasts',
          '• Product performance analysis',
          '• Revenue distribution charts',
          '• Customer patterns',
          '• Monthly/yearly comparisons',
        ],
      ),
      OnboardingStep(
        id: 'settings',
        title: 'Customization',
        description: 'Personalize your experience',
        icon: '⚙️',
        details: [
          '• Language preferences',
          '• Payment sound alerts',
          '• Notification settings',
          '• Shop profile customization',
          '• Data backup options',
        ],
      ),
    ];
  }

  /// Get tutorial for a specific feature
  static Tutorial? getTutorialForFeature(String feature) {
    final tutorials = getAllTutorials();
    return tutorials.firstWhere(
      (t) => t.id == feature,
      orElse: () => Tutorial(
        id: '',
        title: '',
        description: '',
        steps: [],
      ),
    );
  }

  /// Get all feature tutorials
  static List<Tutorial> getAllTutorials() {
    return [
      Tutorial(
        id: 'csv_export',
        title: 'Exporting Sales to CSV',
        description: 'Save your sales data in CSV format for spreadsheet analysis',
        steps: [
          TutorialStep(
            'Navigate to Dashboard',
            'Open the main dashboard view to see all your sales',
          ),
          TutorialStep(
            'Click Export Menu',
            'Look for the "Export" button in the top menu',
          ),
          TutorialStep(
            'Select CSV Format',
            'Choose "CSV" from the export options',
          ),
          TutorialStep(
            'Choose Date Range',
            'Select the period of sales you want to export',
          ),
          TutorialStep(
            'Download',
            'Click "Download" and the file will be saved to your device',
          ),
        ],
      ),
      Tutorial(
        id: 'pdf_export',
        title: 'Generating PDF Reports',
        description: 'Create professional PDF reports of your sales data',
        steps: [
          TutorialStep(
            'Go to Reports Section',
            'Tap on "Reports" in the navigation menu',
          ),
          TutorialStep(
            'Select Report Type',
            'Choose between Daily, Weekly, or Monthly reports',
          ),
          TutorialStep(
            'Customize Report',
            'Add shop details, date range, and additional notes',
          ),
          TutorialStep(
            'Generate PDF',
            'Click "Generate PDF" to create the report',
          ),
          TutorialStep(
            'Share or Save',
            'Share directly or save to your device',
          ),
        ],
      ),
      Tutorial(
        id: 'backup_restore',
        title: 'Backup & Restore Your Data',
        description: 'Protect your data with automatic backups',
        steps: [
          TutorialStep(
            'Open Settings',
            'Navigate to Settings > Data Management',
          ),
          TutorialStep(
            'Create Backup',
            'Tap "Create Backup Now" to save all your data',
          ),
          TutorialStep(
            'View Backups',
            'See all available backups with creation dates and sizes',
          ),
          TutorialStep(
            'Restore Data',
            'Select a backup and tap "Restore" to recover your data',
          ),
          TutorialStep(
            'Export Backup',
            'Download backup to your computer for extra safety',
          ),
        ],
      ),
      Tutorial(
        id: 'voice_notes',
        title: 'Recording Voice Notes',
        description: 'Quick voice memos for personal reminders (up to 1 minute)',
        steps: [
          TutorialStep(
            'Open Voice Notes',
            'Tap the microphone icon in the sales entry screen',
          ),
          TutorialStep(
            'Start Recording',
            'Press the red record button to begin',
          ),
          TutorialStep(
            'Speak Your Note',
            'Note: Limited to 1 minute per recording',
          ),
          TutorialStep(
            'Stop Recording',
            'Tap the stop button when done',
          ),
          TutorialStep(
            'Save Note',
            'Save or discard your voice note',
          ),
        ],
      ),
      Tutorial(
        id: 'payment_setup',
        title: 'Setting Up Payment Detection',
        description: 'Enable automatic payment detection',
        steps: [
          TutorialStep(
            'Go to Settings',
            'Open Settings > Privacy & Notifications',
          ),
          TutorialStep(
            'Enable Permissions',
            'Grant notification access to detect payments',
          ),
          TutorialStep(
            'Select Payment Apps',
            'Choose which UPI apps to monitor',
          ),
          TutorialStep(
            'Configure Alerts',
            'Set up voice and sound preferences',
          ),
          TutorialStep(
            'Test Connection',
            'Make a test payment to verify detection',
          ),
        ],
      ),
      Tutorial(
        id: 'inventory_management',
        title: 'Managing Inventory',
        description: 'Track your products and stock levels',
        steps: [
          TutorialStep(
            'Open Inventory',
            'Navigate to the Inventory section',
          ),
          TutorialStep(
            'Add Products',
            'Click "Add Product" to create new items',
          ),
          TutorialStep(
            'Upload CSV',
            'Or upload a CSV file with multiple products',
          ),
          TutorialStep(
            'Track Quantity',
            'Monitor stock levels automatically',
          ),
          TutorialStep(
            'Set Alerts',
            'Get notifications when stock is low',
          ),
        ],
      ),
    ];
  }

  /// Get contextual tips for a screen
  static List<String> getContextualTips(String screen) {
    const tips = {
      'dashboard': [
        'Swipe left/right to view different time periods',
        'Tap on any chart to see detailed analysis',
        'Pull down to refresh data from server',
        'Long-press on a product to see detailed analytics',
      ],
      'sales_entry': [
        'Press Enter to quickly add multiple products',
        'Use voice input for faster product names',
        'Swipe to delete added products',
        'Double-tap to edit last entry',
      ],
      'analytics': [
        'Tap on data points for detailed information',
        'Pinch to zoom in/out of charts',
        'Swipe to compare different periods',
        'Export data for external analysis',
      ],
      'payment': [
        'Keep UPI apps in foreground to detect payments',
        'Volume must be on for sound alerts',
        'Check permissions if payments aren\'t detected',
        'Enable both notification and SMS monitoring',
      ],
    };
    return tips[screen] ?? [];
  }
}

class OnboardingStep {
  final String id;
  final String title;
  final String description;
  final String icon;
  final List<String> details;

  OnboardingStep({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.details,
  });
}

class Tutorial {
  final String id;
  final String title;
  final String description;
  final List<TutorialStep> steps;

  Tutorial({
    required this.id,
    required this.title,
    required this.description,
    required this.steps,
  });
}

class TutorialStep {
  final String title;
  final String description;

  TutorialStep(this.title, this.description);
}
