import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  // Language map
  static final Map<String, Map<String, String>> translations = {
    'en': {
      'appTitle': 'RETAIL MIND',
      'tagline': 'Smart Analytics & Billing Platform',
      'email': 'Email',
      'password': 'Password',
      'login': 'LOGIN',
      'register': 'REGISTER',
      'signIn': 'SIGN IN',
      'createAccount': 'CREATE NEW ACCOUNT',
      'signUp': 'SIGN UP',
      'enterEmail': 'Enter your email',
      'enterPassword': 'Enter your password',
      'confirmPassword': 'Confirm password',
      'userName': 'User Name',
      'shopName': 'Shop Name',
      'location': 'Location',
      'invalidCredentials': 'Invalid credentials',
      'connectionError': 'Connection error',
      'welcome': 'Welcome Back',
      'enterCredentials': 'Enter your credentials to continue',
      'dashboard': 'Dashboard',
      'sales': 'Sales',
      'query': 'Query',
      'giftCard': 'Gift Card',
      'bills': 'Bills',
      'insights': 'Insights',
      'settings': 'Settings',
      'logout': 'Logout',
      'language': 'Language',
      'selectLanguage': 'Select Language',
      'darkMode': 'Dark Mode',
      'notification': 'Notifications',
      'about': 'About',
      'share': 'Share',
      'help': 'Help',
      'profile': 'Profile',
      'forgotPassword': 'Forgot Password?',
      'welcomeBack': 'Welcome back,',
      'salesByMonth': 'Sales by Month',
      'salesByWeek': 'Sales by Week',
      'salesByYear': 'Sales by Year',
      'searchQuery': 'Search Query',
      'dataUpload': 'Data Upload',
      'addSale': 'Add Sale',
      'totalAmount': 'TOTAL AMOUNT',
      'recordedSuccess': 'Recorded successfully!',
      'recordedLocally': 'Saved locally!',
      'askMeAnything': 'Ask me anything...',
      'aiAssistant': 'AI Assistant',
      'alwaysHere': 'Always here to help',
      'performanceOverview': 'Performance Overview',
      'transactions': 'Transactions',
      'avgOrder': 'Avg. Order',
      'products': 'Products',
      'quickActions': 'Quick Actions',
      'getInsights': 'Get Insights',
      'today': 'Today',
      'week': 'Week',
      'month': 'Month',
      'year': 'Year',
      'showing': 'Showing',
      'phone': 'Phone',
      'owner': 'Owner',
      'website': 'Website',
      'shopkeeper': 'SHOPKEEPER',
      'shareCard': 'Share Card',
      'viewBack': 'View Back',
      'viewFront': 'View Front',
      'goToDashboard': 'Go to Dashboard',
      'tapToFlip': 'Tap to flip for QR code',
      'tapToSeeFront': 'Tap to see front',
      'scanToConnect': 'SCAN TO CONNECT',
      'orScan': 'OR SCAN',
      'allContactIncluded': 'All contact information included',
      'personalInfo': 'Personal Info',
      'shopDetails': 'Shop Details',
      'security': 'Security',
      'fullName': 'Full Name',
      'emailAddress': 'Email Address',
      'phoneNumber': 'Phone Number',
      'shopType': 'Shop Type',
      'taglineOptional': 'Tagline (optional)',
      'websiteOptional': 'Website (optional)',
      'alreadyHaveAccount': 'Already have an account?',
      'joinCommunity': 'Join our community',
      'uploadData': 'Upload Data',
      'analytics': 'Analytics',
      'inventory': 'Inventory',
      'reports': 'Reports',
      'last7Days': 'Last 7 Days',
      'last30Days': 'Last 30 Days',
      'thisYear': 'This Year',
      'noInsights': 'No insights available',
      'goodMorning': 'Good morning! ☀️',
      'synced': 'SYNCED',
      'performanceMessage': "Here's how your shop is performing today",
      'salesTrend': 'Sales Trend',
      'revenueDistribution': 'Revenue Distribution',
      'quantityDistribution': 'Quantity Distribution',
      'revenueLeaders': 'Revenue Leaders',
      'whatChartShows': 'What does this chart show?',
      'askSimpleLanguage': 'Ask in simple language',
      'askQuestionHint': 'Ask a question (e.g. "show sales last week")',
      'askButton': 'Ask',
      'queryTip': 'Tip: Leave file empty to query your database',
      'responseHint': 'Response will appear here',
      'enterProductDetails': 'Enter product details below',
      'addProduct': 'Add Product',
      'generateBill': 'Generate Bill',
      'saveSales': 'Save Sales',
      'paymentMethod': 'Payment Method',
      'cashOffline': 'Cash / Offline',
      'onlineUPI': 'Online / UPI',
      'confirmPayment': 'Confirm Payment Received',
      'paymentConfirmed': 'Payment Confirmed',
      'noSalesData': 'No sales data available',
      'uploadInventory': 'Upload Inventory',
      'selectFile': 'Select File',
      'upload': 'Upload',
      'analyticsOverview': 'Analytics Overview',
      'askToScan': 'Ask customer to scan & pay',
      'scannedBillTitle': 'Scanned Bill',
      'askYourQuestion': 'Ask Your Question',
      'analysisResults': 'Analysis Results',
      'analysisSummary': 'Analysis Summary',
      'detailedData': 'Detailed Data',
      'total': 'Total',
      'revenueShare': 'Revenue Share',
      'topProductsByRevenue': 'Top Products by Revenue',
      'volumeAnalysis': 'Volume Analysis',
      'unitMovementRadar': 'Unit Movement Radar',
      'upwardTrend': 'Upward trend',
      'downwardTrend': 'Downward trend',
      'avgChange': 'avg change',
      'noProductData': 'No product data',
      'volumeByProduct': 'Volume by Product',
      'revenueLeadersDesc': 'This bar chart highlights the top products by revenue within the selected time frame.',
      'salesTrendDesc': "The line chart displays total sales over recent days, giving you an idea of your store's momentum.",
      'revenueDistributionDesc': 'The pie (donut) chart shows how much each product contributes to overall revenue.',
      'quantityDistributionDesc': 'The radar chart compares units sold per product, helping you spot high-volume items.',
      'monthlySalesDesc': 'Track your total sales amount for each month. Identify trends and peak sales periods throughout the year.',
      'weeklySalesDesc': 'View your sales performance over the last 12 weeks. Spot weekly patterns and week-over-week growth.',
      'yearlySalesDesc': 'Compare total sales across different years. Perfect for tracking long-term business growth and performance trends.',
      'howToUseTitle': 'How to Use AI Shop Pro',
      'step1Title': '1. Add Sales',
      'step1Desc': 'Log every sale using the Add Sale icon.',
      'step2Title': '2. Manage Inventory',
      'step2Desc': 'Keep track of products by using the Inventory screen.',
      'step3Title': '3. View Reports',
      'step3Desc': 'Check the Reports section for deep analytics.',
      'step4Title': '4. Share Gift Card',
      'step4Desc': 'Send your digital gift card to customers.',
      'step5Title': '5. Accept Payments',
      'step5Desc': 'Show your custom QR to receive payments easily.',
      'gotIt': 'Got it!',
      'dailyPerformanceRating': 'DAILY PERFORMANCE RATING',
      'salesIncreasedBy': "Today's sales increased by",
      'salesDecreasedBy': "Today's sales decreased by",
      'bestHour': 'Best Hour',
      'yesterdayBestProduct': "Yesterday's best product:",
      'noSales': 'No sales',
      'notAvailable': 'N/A',
      'todaySales': 'Today Sales',
      'yesterdaySales': 'Yesterday Sales',
      'analysisAmazing': "Amazing! Today you've earned ₹{0}, which is ₹{1} more than yesterday!",
      'analysisProgressing': "Progressing! Today's sales are ₹{0}. You're just ₹{1} away from beating yesterday!",
      'analysisWaiting': "Waiting for today's first sale. Let's make it a great one!",
      'analysisMatch': "Today matches yesterday's performance exactly at ₹{0}! Continuous consistency.",
      'goodMorningName': 'Good morning, {0}! ☀️',
      'goodAfternoonName': 'Good afternoon, {0}! 🌤️',
      'goodEveningName': 'Good evening, {0}! 🌙',
      'tapToUploadQr': 'Tap to upload QR',
      'qrUploadFormat': 'PNG / JPG from gallery',
      'tripleChannelActive': 'TRIPLE-CHANNEL DETECTION ACTIVE',
      'listeningForPayments': 'Listening for UPI, SMS & Screen...',
      'selectDueDate': 'Select Payment Deadline',
      'deadline': 'Deadline',
      'overdue': 'Overdue',
      'pendingPayment': 'Pending Payment',
      'setDeadline': 'Set Deadline',
      'attendance': 'Attendance',
      'customers': 'Customers',
      'addCustomer': 'Add Customer',
      'customerName': 'Customer Name',
      'invoices': 'Invoices',
      'newInvoice': 'New Invoice',
      'noInvoicesFound': 'No Invoices Found',
      'noCustomersYet': 'No Customers Yet',
      'noProductsYet': 'No Products Yet',
      'checkIn': 'Check In',
      'checkOut': 'Check Out',
      'todayStatus': "Today's Status",
      'history': 'History',
      'viewAll': 'View All',
      'mrp': 'Mrp',
      'rate': 'Rate',
      'qty': 'Qty',
      'amt': 'Amt',
      'description': 'Description',
      'billNo': 'Bill No',
      'date': 'Date',
      'time': 'Time',
      'cashier': 'Cashier',
      'counter': 'Counter',
      'cashBill': 'CASH BILL',
      'youHaveSaved': 'You have Saved',
      'thankYouVisitAgain': 'Thank You - Visit Again',
      'items': 'Items',
      'total': 'Total',
      'cash': 'Cash',
      'serve': 'Serve',
      'discount': 'Discount',
      'expenses': 'Expenses',
      'workers': 'Workers',
      'backup': 'Backup & Restore',
    },
    'te': {
      'appTitle': 'రిటైల్ మైండ్',
      'tagline': 'స్మార్ట్ అనలిటిక్స్ & బిల్లింగ్ ప్లాట్‌ఫారమ్',
      'email': 'ఈమెయిల్',
      'password': 'పాస్‌వర్డ్',
      'login': 'లాగిన్',
      'register': 'నమోదు',
      'signIn': 'సైన్ ఇన్',
      'createAccount': 'కొత్త ఖాతాను సృష్టించండి',
      'signUp': 'సైన్ అప్',
      'enterEmail': 'మీ ఈమెయిల్ నమోదు చేయండి',
      'enterPassword': 'మీ పాస్‌వర్డ్ నమోదు చేయండి',
      'confirmPassword': 'పాస్‌వర్డ్ నిర్ధారించండి',
      'userName': 'యూజర్ పేరు',
      'shopName': 'దుకాణం పేరు',
      'location': 'స్థలం',
      'invalidCredentials': 'చెల్లని ఆధారాలు',
      'connectionError': 'కనెక్షన్ లోపం',
      'welcome': 'స్వాగతం తిరిగి',
      'enterCredentials': 'కొనసాగించడానికి మీ ఆధారాలను నమోదు చేయండి',
      'dashboard': 'డాష్‌బోర్డ్',
      'sales': 'అమ్మకాలు',
      'query': 'ప్రశ్న',
      'giftCard': 'గిఫ్ట్ కార్డ్',
      'bills': 'బిల్లులు',
      'insights': 'అంతర్దృష్టి',
      'settings': 'సెట్టింగ్‌లు',
      'logout': 'లాగ్ అవుట్',
      'language': 'భాష',
      'selectLanguage': 'భాష ఎంచుకోండి',
      'darkMode': 'డార్క్ మోడ్',
      'notification': 'నోటిఫికేషన్‌లు',
      'about': 'గురించి',
      'share': 'షేర్ చేయండి',
      'help': 'సహాయం',
      'profile': 'ప్రొఫైల్',
      'forgotPassword': 'పాస్‌వర్డ్ మర్చిపోయారా?',
      'welcomeBack': 'మళ్ళీ స్వాగతం,',
      'salesByMonth': 'నెలవారీ అమ్మకాలు',
      'salesByWeek': 'వారపు అమ్మకాలు',
      'salesByYear': 'సంవత్సరపు అమ్మకాలు',
      'searchQuery': 'శోధన ప్రశ్న',
      'dataUpload': 'డేటా అప్‌లోడ్',
      'addSale': 'అమ్మకాన్ని జోడించండి',
      'totalAmount': 'మొత్తం వెల',
      'recordedSuccess': 'విజయవంతంగా నమోదైంది!',
      'recordedLocally': 'స్థానికంగా సేవ్ చేయబడింది!',
      'askMeAnything': 'నన్ను ఏదైనా అడగండి...',
      'aiAssistant': 'AI అసిస్టెంట్',
      'alwaysHere': 'ఎల్లప్పుడూ సహాయం చేయడానికి సిద్ధంగా ఉంది',
      'performanceOverview': 'పనితీరు అవలోకనం',
      'transactions': 'లావాదేవీలు',
      'avgOrder': 'సగటు ఆర్డర్',
      'products': 'ఉత్పత్తులు',
      'quickActions': 'త్వరిత చర్యలు',
      'getInsights': 'అంతర్దృష్టులను పొందండి',
      'today': 'ఈ రోజు',
      'week': 'వారం',
      'month': 'నెల',
      'year': 'సంవత్సరం',
      'showing': 'చూపిస్తున్నారు',
      'phone': 'ఫోన్',
      'owner': 'యజమాని',
      'website': 'వెబ్‌సైట్',
      'shopkeeper': 'దుకాణదారుడు',
      'shareCard': 'కార్డును షేర్ చేయండి',
      'viewBack': 'వెనుక వైపు చూడండి',
      'viewFront': 'ముందు వైపు చూడండి',
      'goToDashboard': 'డాష్‌బోర్డ్‌కు వెళ్ళండి',
      'tapToFlip': 'QR కోడ్ కోసం నొక్కండి',
      'tapToSeeFront': 'ముందు వైపు చూడటానికి నొక్కండి',
      'scanToConnect': 'కనెక్ట్ చేయడానికి స్కాన్ చేయండి',
      'orScan': 'లేదా స్కాన్ చేయండి',
      'allContactIncluded': 'అన్ని సంప్రదింపు సమాచారం చేర్చబడింది',
      'personalInfo': 'వ్యక్తిగత సమాచారం',
      'shopDetails': 'దుకాణ వివరాలు',
      'security': 'భద్రత',
      'fullName': 'పూర్తి పేరు',
      'emailAddress': 'ఈమెయిల్ చిరునామా',
      'phoneNumber': 'ఫోన్ నంబర్',
      'shopType': 'దుకాణ రకం',
      'taglineOptional': 'ట్యాగ్‌లైన్ (ఐచ్ఛికం)',
      'websiteOptional': 'వెబ్‌సైట్ (ఐచ్ఛికం)',
      'alreadyHaveAccount': 'ఇప్పటికే ఒక ఖాతా ఉందా?',
      'joinCommunity': 'మా సంఘంలో చేరండి',
      'uploadData': 'డేటా అప్‌లోడ్',
      'analytics': 'విశ్లేషణలు',
      'inventory': 'ఇన్వెంటరీ',
      'reports': 'నివేదికలు',
      'last7Days': 'గత 7 రోజులు',
      'last30Days': 'గత 30 రోజులు',
      'thisYear': 'ఈ సంవత్సరం',
      'noInsights': 'అంతర్దృష్టులు అందుబాటులో లేవు',
      'goodMorning': 'శుభోదయం! ☀️',
      'synced': 'సమకాలీకరించబడింది',
      'performanceMessage': 'ఈరోజు మీ దుకాణం పనితీరు ఇలా ఉంది',
      'refresh': 'తాజా చేయండి',
      'salesTrend': 'విక్రయాల ధోరణి',
      'revenueDistribution': 'ఆదాయ పంపిణీ',
      'quantityDistribution': 'పరిమాణం పంపిణీ',
      'revenueLeaders': 'ఆదాయ నాయకులు',
      'whatChartShows': 'ఈ చార్ట్ ఏమి చూపుతుంది?',
      'askSimpleLanguage': 'సరళమైన భాషలో అడగండి',
      'askQuestionHint': 'ఒక ప్రశ్న అడగండి (ఉదా. "గత వారం అమ్మకాలను చూపించు")',
      'askButton': 'అడగండి',
      'queryTip': 'చిట్కా: మీ డేటాబేస్‌ను ప్రశ్నించడానికి ఫైల్‌ను ఖాళీగా ఉంచండి',
      'responseHint': 'సమాధానం ఇక్కడ కనిపిస్తుంది',
      'enterProductDetails': 'క్రింద ఉత్పత్తి వివరాలను నమోదు చేయండి',
      'addProduct': 'ఉత్పత్తిని జోడించండి',
      'generateBill': 'బిల్లును రూపొందించండి',
      'saveSales': 'విక్రయాలను సేవ్ చేయండి',
      'paymentMethod': 'చెల్లింపు పద్ధతి',
      'cashOffline': 'నగదు / ఆఫ్ లైన్',
      'onlineUPI': 'ఆన్ లైన్ / UPI',
      'confirmPayment': 'చెల్లింపు అందినట్లు ధృవీకరించండి',
      'paymentConfirmed': 'చెల్లింపు ధృవీకరించబడింది',
      'noSalesData': 'విక్రయాల డేటా అందుబాటులో లేదు',
      'uploadInventory': 'ఇన్వెంటరీని అప్‌లోడ్ చేయండి',
      'selectFile': 'ఫైల్‌ను ఎంచుకోండి',
      'upload': 'అప్‌లోడ్ చేయండి',
      'analyticsOverview': 'విశ్లేషణల అవలోకనం',
      'askToScan': 'స్కాన్ చేసి చెల్లించమని కస్టమర్‌ను కోరండి',
      'scannedBillTitle': 'స్కాన్ చేసిన బిల్లు',
      'askYourQuestion': 'మీ ప్రశ్న అడగండి',
      'analysisResults': 'విశ్లేషణ ఫలితాలు',
      'analysisSummary': 'విశ్లేషణ సారాంశం',
      'detailedData': 'వివరణాత్మక డేటా',
      'total': 'మొత్తం',
      'revenueShare': 'ఆదాయ వాటా',
      'topProductsByRevenue': 'ఆదాయం పరంగా అగ్ర ఉత్పత్తులు',
      'volumeAnalysis': 'పరిమాణం విశ్లేషణ',
      'unitMovementRadar': 'యూనిట్ కదలిక రాడార్',
      'upwardTrend': 'ఎగువ ధోరణి',
      'downwardTrend': 'దిగువ ధోరణి',
      'avgChange': 'సగటు మార్పు',
      'noProductData': 'ఉత్పత్తి డేటా లేదు',
      'volumeByProduct': 'ఉత్పత్తి ద్వారా వాల్యూమ్',
      'revenueLeadersDesc': 'ఈ బార్ చార్ట్ ఎంచుకున్న సమయ వ్యవధిలో ఆదాయం పరంగా అగ్ర ఉత్పత్తులను హైలైట్ చేస్తుంది.',
      'salesTrendDesc': 'లైన్ చార్ట్ ఇటీవలి రోజుల్లో మొత్తం అమ్మకాలను ప్రదర్శిస్తుంది, ఇది మీ దుకాణం యొక్క ఊపును తెలియజేస్తుంది.',
      'revenueDistributionDesc': 'పై (డోనట్) చార్ట్ ప్రతి ఉత్పత్తి మొత్తం ఆదాయానికి ఎంత దోహదం చేస్తుందో చూపుతుంది.',
      'quantityDistributionDesc': 'రాడార్ చార్ట్ ఉత్పత్తికి విక్రయించిన యూనిట్లను పోల్చి చూస్తుంది, ఇది అధిక-పరిమాణ వస్తువులను గుర్తించడంలో మీకు సహాయపడుతుంది.',
      'monthlySalesDesc': 'ప్రతి నెల మీ మొత్తం అమ్మకాల మొత్తాన్ని ట్రాక్ చేయండి. ఏడాది పొడవునా ధోరణులు మరియు గరిష్ట విక్రయాల కాలాలను గుర్తించండి.',
      'weeklySalesDesc': 'గత 12 వారాలలో మీ విక్రయాల పనితీరును చూడండి. వారపు నమూనాలు మరియు వారం వారం వృద్ధిని గుర్తించండి.',
      'yearlySalesDesc': 'విభిన్న సంవత్సరాల్లో మొత్తం అమ్మకాలను పోల్చండి. దీర్ఘకాలిక వ్యాపార వృద్ధి మరియు పనితీరు ధోరణులను ట్రాక్ చేయడానికి పర్ఫెక్ట్.',
      'howToUseTitle': 'AI షాప్ ప్రో ఉపయోగించడం ఎలా',
      'step1Title': '1. అమ్మకాలను జోడించండి',
      'step1Desc': 'అమ్మకం చిహ్నాన్ని ఉపయోగించి ప్రతి అమ్మకాన్ని నమోదు చేయండి.',
      'step2Title': '2. ఇన్వెంటరీని నిర్వహించండి',
      'step2Desc': 'ఇన్వెంటరీ స్క్రీన్‌ను ఉపయోగించి ఉత్పత్తులను ట్రాక్ చేయండి.',
      'step3Title': '3. నివేదికలను చూడండి',
      'step3Desc': 'లోతైన విశ్లేషణల కోసం నివేదికల విభాగాన్ని తనిఖీ చేయండి.',
      'step4Title': '4. గిఫ్ట్ కార్డ్ షేర్ చేయండి',
      'step4Desc': 'మీ డిజిటల్ గిఫ్ట్ కార్డును వినియోగదారులకు పంపండి.',
      'step5Title': '5. చెల్లింపులను స్వీకరించండి',
      'step5Desc': 'చెల్లింపులను సులభంగా స్వీకరించడానికి మీ అనుకూల QR ని చూపండి.',
      'gotIt': 'అర్థమైంది!',
      'dailyPerformanceRating': 'రోజువారీ పనితీరు రేటింగ్',
      'salesIncreasedBy': 'నేటి అమ్మకాలు పెరిగాయి',
      'salesDecreasedBy': 'నేటి అమ్మకాలు తగ్గాయి',
      'bestHour': 'ఉత్తమ గంట',
      'yesterdayBestProduct': 'నిన్నటి ఉత్తమ ఉత్పత్తి:',
      'noSales': 'అమ్మకాలు లేవు',
      'notAvailable': 'అందుబాటులో లేదు',
      'todaySales': 'నేటి అమ్మకాలు',
      'yesterdaySales': 'నిన్నటి అమ్మకాలు',
      'analysisAmazing': 'అద్భుతం! నేడు మీరు ₹{0} సంపాదించారు, ఇది నిన్నటి కంటే ₹{1} ఎక్కువ!',
      'analysisProgressing': 'పురోగమిస్తోంది! నేటి అమ్మకాలు ₹{0}. నిన్నటిని అధిగమించడానికి మీరు కేవలం ₹{1} దూరంలో ఉన్నారు!',
      'analysisWaiting': 'నేటి మొదటి అమ్మకం కోసం వేచి చూస్తున్నాము. దీనిని గొప్పగా చేద్దాం!',
      'analysisMatch': 'నేటి పనితీరు నిన్నటితో సరిగ్గా ₹{0} వద్ద సరిపోయింది! నిరంతర స్థిరత్వం.',
      'goodMorningName': 'శుభోదయం, {0}! ☀️',
      'goodAfternoonName': 'శుభ మధ్యాహ్నం, {0}! 🌤️',
      'goodEveningName': 'శుభ సాయంత్రం, {0}! 🌙',
      'tapToUploadQr': 'QR అప్‌లోడ్ చేయడానికి నొక్కండి',
      'qrUploadFormat': 'PNG / JPG గ్యాలరీ నుండి',
      'tripleChannelActive': 'ట్రిపుల్ ఛానల్ డిటెక్షన్ యాక్టివ్‌గా ఉంది',
      'listeningForPayments': 'UPI, SMS & స్క్రీన్ కోసం వేచి ఉంది...',
      'listeningForPayments': 'UPI, SMS & స్క్రీన్ కోసం వేచి ఉంది...',
      'selectDueDate': 'చెల్లింపు గడువును ఎంచుకోండి',
      'deadline': 'గడువు',
      'overdue': 'గడువు ముగిసింది',
      'pendingPayment': 'పెండింగ్ చెల్లింపు',
      'setDeadline': 'గడువును నిర్ణయించండి',
      'attendance': 'హాజరు',
      'customers': 'వినియోగదారులు',
      'addCustomer': 'వినియోగదారుని జోడించండి',
      'customerName': 'వినియోగదారు పేరు',
      'invoices': 'ఇన్‌వాయిస్‌లు',
      'newInvoice': 'కొత్త ఇన్‌వాయిస్',
      'noInvoicesFound': 'ఇన్‌వాయిస్‌లు కనుగొనబడలేదు',
      'noCustomersYet': 'ఇంకా వినియోగదారులు లేరు',
      'noProductsYet': 'ఇంకా ఉత్పత్తులు లేవు',
      'checkIn': 'చెక్ ఇన్',
      'checkOut': 'చెక్ అవుట్',
      'todayStatus': "నేటి స్థితి",
      'history': 'చరిత్ర',
      'viewAll': 'అన్నీ చూడండి',
      'mrp': 'Mrp',
      'rate': 'రేటు',
      'qty': 'పరిమాణం',
      'amt': 'వెల',
      'description': 'వివరణ',
      'billNo': 'బిల్లు నెం',
      'date': 'తేదీ',
      'time': 'సమయం',
      'cashier': 'క్యాషియర్',
      'counter': 'కౌంటర్',
      'cashBill': 'నగదు బిల్లు',
      'youHaveSaved': 'మీరు పొదుపు చేసారు',
      'thankYouVisitAgain': 'ధన్యవాదాలు - మళ్ళీ రండి',
      'items': 'వస్తువులు',
      'total': 'మొత్తం వెల',
      'cash': 'నగదు',
      'serve': 'సేవ',
      'discount': 'తగ్గింపు',
      'expenses': 'ఖర్చులు',
      'workers': 'పనివారు',
      'backup': 'బ్యాకప్ & రీస్టోర్',
    },
    'hi': {
      'appTitle': 'रिटेल माइंड',
      'tagline': 'स्मार्ट एनालिटिक्स और बिलिंग प्लेटफॉर्म',
      'email': 'ईमेल',
      'password': 'पासवर्ड',
      'login': 'लॉगिन',
      'register': 'पंजीकरण',
      'signIn': 'साइन इन',
      'createAccount': 'नया खाता बनाएं',
      'signUp': 'साइन अप',
      'enterEmail': 'अपना ईमेल दर्ज करें',
      'enterPassword': 'अपना पासवर्ड दर्ज करें',
      'confirmPassword': 'पासवर्ड की पुष्टि करें',
      'userName': 'उपयोगकर्ता का नाम',
      'shopName': 'दुकान का नाम',
      'location': 'स्थान',
      'invalidCredentials': 'अमान्य साक्षर',
      'connectionError': 'कनेक्शन त्रुटि',
      'welcome': 'वापस स्वागत है',
      'enterCredentials': 'जारी रखने के लिए अपनी साक्षर दर्ज करें',
      'dashboard': 'डैशबोर्ड',
      'sales': 'विक्रय',
      'query': 'प्रश्न',
      'giftCard': 'गिफ्ट कार्ड',
      'bills': 'बिल',
      'insights': 'अंतर्दृष्टि',
      'settings': 'सेटिंग्स',
      'logout': 'लॉग आउट',
      'language': 'भाषा',
      'selectLanguage': 'भाषा चुनें',
      'darkMode': 'डार्क मोड',
      'notification': 'सूचनाएं',
      'about': 'बारे में',
      'share': 'शेयर करें',
      'help': 'मदद',
      'profile': 'प्रोफ़ाइल',
      'forgotPassword': 'पासवर्ड भूल गए?',
      'welcomeBack': 'आपका स्वागत है,',
      'salesByMonth': 'महीने के अनुसार बिक्री',
      'salesByWeek': 'सप्ताह के अनुसार बिक्री',
      'salesByYear': 'वर्ष के अनुसार बिक्री',
      'searchQuery': 'खोज प्रश्न',
      'dataUpload': 'डेटा अपलोड',
      'addSale': 'बिक्री जोड़ें',
      'totalAmount': 'कुल राशि',
      'recordedSuccess': 'सफलतापूर्वक दर्ज किया गया!',
      'recordedLocally': 'स्थानीय रूप से सहेजा गया!',
      'askMeAnything': 'मुझसे कुछ भी पूछें...',
      'aiAssistant': 'AI सहायक',
      'alwaysHere': 'हमेशा मदद के लिए यहाँ है',
      'performanceOverview': 'प्रदर्शन अवलोकन',
      'transactions': 'लेन-देन',
      'avgOrder': 'औसत ऑर्डर',
      'products': 'उत्पादों',
      'quickActions': 'त्वरित कार्रवाई',
      'getInsights': 'इनसाइट्स प्राप्त करें',
      'today': 'आज',
      'week': 'सप्ताह',
      'month': 'महीना',
      'year': 'साल',
      'showing': 'दिखा रहा है',
      'phone': 'फ़ोन',
      'owner': 'मालिक',
      'website': 'वेबसाइट',
      'shopkeeper': 'दुकानदार',
      'shareCard': 'कार्ड साझा करें',
      'viewBack': 'पीछे का भाग देखें',
      'viewFront': 'सामने का भाग देखें',
      'goToDashboard': 'डैशबोर्ड पर जाएं',
      'tapToFlip': 'QR कोड के लिए टैप करें',
      'tapToSeeFront': 'सामने देखने के लिए टैप करें',
      'scanToConnect': 'कनेक्ट करने के लिए स्कैन करें',
      'orScan': 'या स्कैन करें',
      'allContactIncluded': 'सभी संपर्क जानकारी शामिल है',
      'personalInfo': 'व्यक्तिगत जानकारी',
      'shopDetails': 'दुकान का विवरण',
      'security': 'सुरक्षा',
      'fullName': 'पूरा नाम',
      'emailAddress': 'ईमेल पता',
      'phoneNumber': 'फ़ोन नंबर',
      'shopType': 'दुकान का प्रकार',
      'taglineOptional': 'टैगलाइन (वैकल्पिक)',
      'websiteOptional': 'वेबसाइट (वैकल्पिक)',
      'alreadyHaveAccount': 'क्या आपके पास पहले से एक खाता है?',
      'joinCommunity': 'हमारे समुदाय में शामिल हों',
      'uploadData': 'डेटा अपलोड करें',
      'analytics': 'विश्लेषण',
      'inventory': 'इन्वेंटरी',
      'reports': 'रिपोर्ट',
      'last7Days': 'पिछले 7 दिन',
      'last30Days': 'पिछले 30 दिन',
      'thisYear': 'इस साल',
      'noInsights': 'कोई अंतर्दृष्टि उपलब्ध नहीं है',
      'goodMorning': 'शुभ प्रभात! ☀️',
      'synced': 'सिंक्रोनाइज़्ड',
      'performanceMessage': 'यहाँ बताया गया है कि आपकी दुकान आज कैसा प्रदर्शन कर रही है',
      'refresh': 'रिफ्रेश करें',
      'salesTrend': 'बिक्री का रुझान',
      'revenueDistribution': 'राजस्व वितरण',
      'quantityDistribution': 'मात्रा वितरण',
      'revenueLeaders': 'राजस्व नेता',
      'whatChartShows': 'यह चार्ट क्या दिखाता है?',
      'askSimpleLanguage': 'सरल भाषा में पूछें',
      'askQuestionHint': 'एक प्रश्न पूछें (जैसे "पिछले सप्ताह की बिक्री दिखाएं")',
      'askButton': 'पूछें',
      'queryTip': 'टिप: अपने डेटाबेस से पूछने के लिए फ़ाइल को खाली छोड़ दें',
      'responseHint': 'जवाब यहाँ दिखाई देगा',
      'enterProductDetails': 'नीचे उत्पाद विवरण दर्ज करें',
      'addProduct': 'उत्पाद जोड़ें',
      'generateBill': 'बिल जनरेट करें',
      'saveSales': 'बिक्री सहेजें',
      'paymentMethod': 'भुगतान विधि',
      'cashOffline': 'नकद / ऑफलाइन',
      'onlineUPI': 'ऑनलाइन / UPI',
      'confirmPayment': 'भुगतान प्राप्त होने की पुष्टि करें',
      'paymentConfirmed': 'भुगतान की पुष्टि हो गई',
      'noSalesData': 'कोई बिक्री डेटा उपलब्ध नहीं है',
      'uploadInventory': 'माल सूची अपलोड करें',
      'selectFile': 'फ़ाइल चुनें',
      'upload': 'अपलोड करें',
      'analyticsOverview': 'विश्लेषण अवलोकन',
      'askToScan': 'ग्राहक को स्कैन और भुगतान करने के लिए कहें',
      'scannedBillTitle': 'स्कैन किया गया बिल',
      'askYourQuestion': 'अपना प्रश्न पूछें',
      'analysisResults': 'विश्लेषण परिणाम',
      'analysisSummary': 'विश्लेषण सारांश',
      'detailedData': 'विस्तृत डेटा',
      'total': 'कुल',
      'revenueShare': 'राजस्व हिस्सेदारी',
      'topProductsByRevenue': 'राजस्व के आधार पर शीर्ष उत्पाद',
      'volumeAnalysis': 'मात्रा विश्लेषण',
      'unitMovementRadar': 'यूनिट मूवमेंट रडार',
      'upwardTrend': 'ऊर्ध्वगामी रुझान',
      'downwardTrend': 'नीचे की ओर रुझान',
      'avgChange': 'औसत परिवर्तन',
      'noProductData': 'कोई उत्पाद डेटा नहीं',
      'volumeByProduct': 'उत्पाद द्वारा वॉल्यूम',
      'revenueLeadersDesc': 'यह बार चार्ट चयनित समय सीमा के भीतर राजस्व के आधार पर शीर्ष उत्पादों को उजागर करता है।',
      'salesTrendDesc': 'लाइन चार्ट पिछले कुछ दिनों में कुल बिक्री को प्रदर्शित करता है, जिससे आपको अपने स्टोर की गति का अंदाज़ा मिलता है।',
      'revenueDistributionDesc': 'पाई (डोनट) चार्ट दिखाता है कि प्रत्येक उत्पाद कुल राजस्व में कितना योगदान देता है।',
      'quantityDistributionDesc': 'रडार चार्ट प्रति उत्पाद बेची गई इकाइयों की तुलना करता है, जिससे आपको उच्च-मात्रा वाली वस्तुओं को खोजने में मदद मिलती है।',
      'monthlySalesDesc': 'प्रत्येक महीने के लिए अपनी कुल बिक्री राशि को ट्रैक करें। पूरे वर्ष रुझानों और चरम बिक्री अवधियों की पहचान करें।',
      'weeklySalesDesc': 'पिछले 12 हफ्तों में अपनी बिक्री के प्रदर्शन को देखें। साप्ताहिक पैटर्न और सप्ताह-दर-सप्ताह वृद्धि का पता लगाएं।',
      'yearlySalesDesc': 'विभिन्न वर्षों में कुल बिक्री की तुलना करें। दीर्घकालिक व्यावसायिक विकास और प्रदर्शन रुझानों पर नज़र रखने के लिए बिल्कुल सही।',
      'howToUseTitle': 'AI शॉप प्रो का उपयोग कैसे करें',
      'step1Title': '1. बिक्री जोड़ें',
      'step1Desc': 'ऐड सेल आइकन का उपयोग करके हर बिक्री दर्ज करें।',
      'step2Title': '2. इन्वेंट्री प्रबंधित करें',
      'step2Desc': 'इन्वेंट्री स्क्रीन का उपयोग करके उत्पादों पर नज़र रखें।',
      'step3Title': '3. रिपोर्ट देखें',
      'step3Desc': 'गहन विश्लेषण के लिए रिपोर्ट अनुभाग देखें।',
      'step4Title': '4. गिफ्ट कार्ड साझा करें',
      'step4Desc': 'अपने डिजिटल गिफ्ट कार्ड को ग्राहकों को भेजें।',
      'step5Title': '5. भुगतान स्वीकार करें',
      'step5Desc': 'आसानी से भुगतान प्राप्त करने के लिए अपना कस्टम QR दिखाएं।',
      'gotIt': 'समझ गया!',
      'dailyPerformanceRating': 'दैनिक प्रदर्शन रेटिंग',
      'salesIncreasedBy': 'आज की बिक्री में वृद्धि हुई',
      'salesDecreasedBy': 'आज की बिक्री में कमी आई',
      'bestHour': 'सबसे अच्छा घंटा',
      'yesterdayBestProduct': 'कल का सबसे अच्छा उत्पाद:',
      'noSales': 'कोई बिक्री नहीं',
      'notAvailable': 'उपलब्ध नहीं',
      'todaySales': 'आज की बिक्री',
      'yesterdaySales': 'कल की बिक्री',
      'analysisAmazing': 'अद्भुत! आज आपने ₹{0} कमाए हैं, जो कल से ₹{1} अधिक है!',
      'analysisProgressing': 'प्रगति पर है! आज की बिक्री ₹{0} है। आप कल से आगे निकलने के लिए केवल ₹{1} दूर हैं!',
      'analysisWaiting': 'आज की पहली बिक्री का इंतज़ार है। इसे शानदार बनाएं!',
      'analysisMatch': 'आज का प्रदर्शन कल के ₹{0} के बिल्कुल बराबर है! निरंतर स्थिरता।',
      'goodMorningName': 'शुभ प्रभात, {0}! ☀️',
      'goodAfternoonName': 'शुभ दोपहर, {0}! 🌤️',
      'goodEveningName': 'शुभ संध्या, {0}! 🌙',
      'tapToUploadQr': 'QR अपलोड करने के लिए टैप करें',
      'qrUploadFormat': 'गैलरी से PNG / JPG',
      'tripleChannelActive': 'ट्रिपल-चैनल डिटेक्शन सक्रिय',
      'listeningForPayments': 'UPI, SMS और स्क्रीन की निगरानी...',
      'listeningForPayments': 'UPI, SMS और स्क्रीन के लिए सुन रहा है...',
      'selectDueDate': 'भुगतान की समय सीमा चुनें',
      'deadline': 'समय सीमा',
      'overdue': 'विलंबित',
      'pendingPayment': 'लंबित भुगतान',
      'setDeadline': 'समय सीमा निर्धारित करें',
      'attendance': 'उपस्थिति',
      'customers': 'ग्राहक',
      'addCustomer': 'ग्राहक जोड़ें',
      'customerName': 'ग्राहक का नाम',
      'invoices': 'चालान',
      'newInvoice': 'नया चालान',
      'noInvoicesFound': 'कोई चालान नहीं मिला',
      'noCustomersYet': 'अभी तक कोई ग्राहक नहीं है',
      'noProductsYet': 'अभी तक कोई उत्पाद नहीं है',
      'checkIn': 'चेक इन',
      'checkOut': 'चेक आउट',
      'todayStatus': "आज की स्थिति",
      'history': 'इतिहास',
      'viewAll': 'सभी देखें',
      'mrp': 'Mrp',
      'rate': 'रेट',
      'qty': 'मात्रा',
      'amt': 'राशि',
      'description': 'विवरण',
      'billNo': 'बिल नंबर',
      'date': 'दिनांक',
      'time': 'समय',
      'cashier': 'कैशियर',
      'counter': 'काउंटर',
      'cashBill': 'नकद बिल',
      'youHaveSaved': 'आपने बचाए',
      'thankYouVisitAgain': 'धन्यवाद - फिर आएं',
      'items': 'वस्तुएं',
      'total': 'कुल',
      'cash': 'नकद',
      'serve': 'सर्फ',
      'discount': 'छूट',
    },
    'ta': {
      'appTitle': 'சில்லறை மனம்',
      'tagline': 'ஸ்மார்ட் பகுப்பாய்வு மற்றும் பிலிங் பலேடாம்',
      'email': 'மின்னஞ்சல்',
      'password': 'கடவுச்சொல்',
      'login': 'உள்நுழைக',
      'register': 'பதிவு',
      'signIn': 'உள்நுழைக',
      'createAccount': 'புதிய கணக்கை உருவாக்கு',
      'signUp': 'பதிவு செய்',
      'enterEmail': 'உங்கள் மின்னஞ்சலை உள்ளிடவும்',
      'enterPassword': 'உங்கள் கடவுச்சொல்லை உள்ளிடவும்',
      'confirmPassword': 'கடவுச்சொல்லை உறுதிப்படுத்தவும்',
      'userName': 'பயனர் பெயர்',
      'shopName': 'கடை பெயர்',
      'location': 'இருப்பிடம்',
      'invalidCredentials': 'தவறான நற்சான்றுகள்',
      'connectionError': 'இணைப்பு பிழை',
      'welcome': 'திரும்பி வரவேற்கிறோம்',
      'enterCredentials': 'தொடர உங்கள் நற்சான்றுகளை உள்ளிடவும்',
      'dashboard': 'டாஷ்போர்டு',
      'sales': 'விற்பனை',
      'query': 'வினவு',
      'giftCard': 'பரிசு அட்டை',
      'bills': 'ஆவணை',
      'insights': 'நுண்ணறிவு',
      'settings': 'அமைப்புகள்',
      'logout': 'வெளியேறு',
      'language': 'மொழி',
      'selectLanguage': 'மொழியைத் தேர்ந்தெடுக்கவும்',
      'darkMode': 'இருண்ட பயன்முறை',
      'notification': 'அறிவிப்புகள்',
      'about': 'பற்றி',
      'share': 'பகிரவும்',
      'help': 'உதவி',
      'profile': 'சுயவிவரம்',
      'forgotPassword': 'கடவுச்சொல்லை மறந்துவிட்டீர்களா?',
      'welcomeBack': 'மீண்டும் வருக,',
      'salesByMonth': 'மாதாந்திர விற்பனை',
      'salesByWeek': 'வாராந்திர விற்பனை',
      'salesByYear': 'வருடாந்திர விற்பனை',
      'searchQuery': 'தேடல் வினவல்',
      'dataUpload': 'தரவு பதிவேற்றம்',
      'addSale': 'விற்பனையைச் சேர்க்கவும்',
      'totalAmount': 'மொத்த தொகை',
      'recordedSuccess': 'வெற்றிகரமாக பதிவு செய்யப்பட்டது!',
      'recordedLocally': 'உள்ளூர் சேமிக்கப்பட்டது!',
      'askMeAnything': 'என்னிடம் எதையும் கேளுங்கள்...',
      'aiAssistant': 'AI உதவியாளர்',
      'alwaysHere': 'எப்போதும் உதவ இங்கே உள்ளது',
      'performanceOverview': 'செயல்திறன் மேலோட்டம்',
      'transactions': 'பரிவர்த்தனைகள்',
      'avgOrder': 'சராசரி ஆர்டர்',
      'products': 'தயாரிப்புகள்',
      'quickActions': 'விரைவான செயல்கள்',
      'getInsights': 'நுண்ணறிவுகளைப் பெறுங்கள்',
      'today': 'இன்று',
      'week': 'வாரம்',
      'month': 'மாதம்',
      'year': 'ஆண்டு',
      'showing': 'காட்டுகிறது',
      'phone': 'தொலைபேசி',
      'owner': 'உரிமையாளர்',
      'website': 'இணையதளம்',
      'shopkeeper': 'கடைக்காரர்',
      'shareCard': 'அட்டையைப் பகிரவும்',
      'viewBack': 'பின்புறத்தைப் பார்க்கவும்',
      'viewFront': 'முன்புறத்தைப் பார்க்கவும்',
      'goToDashboard': 'டாஷ்போர்டிற்குச் செல்லவும்',
      'tapToFlip': 'QR குறியீட்டிற்குத் தட்டவும்',
      'tapToSeeFront': 'முன்புறத்தைப் பார்க்கத் தட்டவும்',
      'scanToConnect': 'இணைக்க ஸ்கேன் செய்யவும்',
      'orScan': 'அல்லது ஸ்கேன் செய்யவும்',
      'allContactIncluded': 'அனைத்து தொடர்பு தகவல்களும் சேர்க்கப்பட்டுள்ளன',
      'personalInfo': 'தனிப்பட்ட தகவல்',
      'shopDetails': 'கடை விவரங்கள்',
      'security': 'பாதுகாப்பு',
      'fullName': 'முழு பெயர்',
      'emailAddress': 'மின்னஞ்சல் முகவரி',
      'phoneNumber': 'தொலைபேசி எண்',
      'shopType': 'கடை வகை',
      'taglineOptional': 'டேக்லைன் (விருப்பத்தேர்வு)',
      'websiteOptional': 'இணையதளம் (விருப்பத்தேர்வு)',
      'alreadyHaveAccount': 'ஏற்கனவே கணக்கு உள்ளதா?',
      'joinCommunity': 'எங்கள் சமூகத்தில் இணையுங்கள்',
      'uploadData': 'தரவைப் பதிவேற்றவும்',
      'analytics': 'பகுப்பாய்வு',
      'inventory': 'சரக்கு',
      'reports': 'அறிக்கைகள்',
      'last7Days': 'கடந்த 7 நாட்கள்',
      'last30Days': 'கடந்த 30 நாட்கள்',
      'thisYear': 'இந்த ஆண்டு',
      'noInsights': 'நுண்ணறிவுகள் எதுவும் இல்லை',
      'goodMorning': 'காலை வணக்கம்! ☀️',
      'synced': 'ஒத்திசைக்கப்பட்டது',
      'performanceMessage': 'உங்கள் கடை இன்று எப்படி செயல்படுகிறது என்பது இங்கே',
      'refresh': 'புதுப்பிப்பதற்கான',
      'salesTrend': 'விற்பனை போக்கு',
      'revenueDistribution': 'வருவாய் விநியோகம்',
      'quantityDistribution': 'அளவு விநியோகம்',
      'revenueLeaders': 'வருவாய் தலைவர்கள்',
      'whatChartShows': 'இந்த விளக்கப்படம் என்ன காட்டுகிறது?',
      'askSimpleLanguage': 'எளிய மொழியில் கேளுங்கள்',
      'askQuestionHint': 'உதாரணமாக "கடந்த வார விற்பனையைக் காட்டு" போன்ற ஒரு கேள்வியைக் கேளுங்கள்',
      'askButton': 'கேளுங்கள்',
      'queryTip': 'குறிப்பு: உங்கள் தரவுத்தளத்தை வினவ கோப்பை காலியாக விடவும்',
      'responseHint': 'பதில் இங்கே தோன்றும்',
      'enterProductDetails': 'தயாரிப்பு விவரங்களை கீழே உள்ளிடவும்',
      'addProduct': 'தயாரிப்பைச் சேர்க்கவும்',
      'generateBill': 'பில் உருவாக்கவும்',
      'saveSales': 'விற்பனையைச் சேமிக்கவும்',
      'paymentMethod': 'கட்டண முறை',
      'cashOffline': 'ரொக்கம் / ஆஃப்லைன்',
      'onlineUPI': 'ஆன்லைன் / UPI',
      'confirmPayment': 'கட்டணம் பெறப்பட்டதை உறுதிப்படுத்தவும்',
      'paymentConfirmed': 'கட்டணம் உறுதிப்படுத்தப்பட்டது',
      'noSalesData': 'விற்பனை தரவு எதுவும் இல்லை',
      'uploadInventory': 'சரக்குப்பட்டியலைப் பதிவேற்றவும்',
      'selectFile': 'கோப்பைத் தேர்ந்தெடுக்கவும்',
      'upload': 'பதிவேற்றவும்',
      'analyticsOverview': 'பகுப்பாய்வு கண்ணோட்டம்',
      'askToScan': 'ஸ்கேன் செய்து பணத்தைச் செலுத்துமாறு வாடிக்கையாளரைக் கேட்கவும்',
      'scannedBillTitle': 'ஸ்கேன் செய்யப்பட்ட பில்',
      'askYourQuestion': 'உங்கள் கேள்வியைக் கேளுங்கள்',
      'analysisResults': 'பகுப்பாய்வு முடிவுகள்',
      'analysisSummary': 'பகுப்பாய்வு சுருக்கம்',
      'detailedData': 'விரிவான தரவு',
      'total': 'மொத்தம்',
      'revenueShare': 'வருவாய் பங்கு',
      'topProductsByRevenue': 'வருவாய் அடிப்படையில் சிறந்த தயாரிப்புகள்',
      'volumeAnalysis': 'அளவு பகுப்பாய்வு',
      'unitMovementRadar': 'யூனிட் இயக்கம் ராடார்',
      'upwardTrend': 'வளர்ச்சி போக்கு',
      'downwardTrend': 'வீழ்ச்சி போக்கு',
      'avgChange': 'சராசரி மாற்றம்',
      'noProductData': 'தயாரிப்பு தரவு இல்லை',
      'volumeByProduct': 'பொருளின் அடிப்படையில் அளவு',
      'revenueLeadersDesc': 'இந்த பார் சார்ட் தேர்ந்தெடுக்கப்பட்ட காலக்கெடுவுக்குள் வருவாய் அடிப்படையில் சிறந்த தயாரிப்புகளை எடுத்துக்காட்டுகிறது.',
      'salesTrendDesc': 'லைன் சார்ட் சமீபத்திய நாட்களில் மொத்த விற்பனையைக் காட்டுகிறது, இது உங்கள் கடையின் வேகத்தைப் பற்றிய கருத்தை வழங்குகிறது.',
      'revenueDistributionDesc': 'பை (டோனட்) சார்ட் ஒவ்வொரு தயாரிப்பும் ஒட்டுமொத்த வருவாய்க்கு எவ்வளவு பங்களிக்கிறது என்பதைக் காட்டுகிறது.',
      'quantityDistributionDesc': 'ராடார் சார்ட் தயாரிப்பிற்கு விற்கப்பட்ட யூனிட்டுகளை ஒப்பிட்டுப் பார்க்கிறது, இது அதிக-விற்பனையாகும் பொருட்களைக் கண்டறிய உதவுகிறது.',
      'monthlySalesDesc': 'ஒவ்வொரு மாதமும் உங்கள் மொத்த விற்பனைத் தொகையைக் கண்காணிக்கவும். ஆண்டு முழுவதும் போக்குகள் மற்றும் அதிக விற்பனை காலங்களை அடையாளம் காணவும்.',
      'weeklySalesDesc': 'கடந்த 12 வாரங்களில் உங்கள் விற்பனைச் செயல்திறனைப் பார்க்கவும். வாராந்திர வடிவங்கள் மற்றும் வாரம்-வார வளர்ச்சியை அடையாளம் காணவும்.',
      'yearlySalesDesc': 'வெவ்வேறு ஆண்டுகளில் மொத்த விற்பனையை ஒப்பிட்டுப் பாருங்கள். நீண்ட கால வணிக வளர்ச்சி மற்றும் செயல்திறன் போக்குகளைக் கண்காணிக்க சரியானதல்ல.',
      'howToUseTitle': 'AI ஷாப் புரோவை எவ்வாறு பயன்படுத்துவது',
      'step1Title': '1. விற்பனையைச் சேர்க்கவும்',
      'step1Desc': 'விற்பனைச் சேர்க்கும் ஐகானைப் பயன்படுத்தி ஒவ்வொரு விற்பனையையும் பதிவு செய்யுங்கள்.',
      'step2Title': '2. சரக்கு மேலாண்மை',
      'step2Desc': 'சரக்குத் திரையைப் பயன்படுத்தித் தயாரிப்புகளைக் கண்காணியுங்கள்.',
      'step3Title': '3. அறிக்கைகளைப் பார்க்கவும்',
      'step3Desc': 'ஆழ்ந்த பகுப்பாய்விற்கு அறிக்கைகள் பகுதியைச் சரிபார்க்கவும்.',
      'step4Title': '4. பரிசு அட்டையைப் பகிரவும்',
      'step4Desc': 'உங்கள் டிஜிட்டல் பரிசு அட்டையை வாடிக்கையாளர்களுக்கு அனுப்புங்கள்.',
      'step5Title': '5. கொடுப்பனவுகளை ஏற்கவும்',
      'step5Desc': 'கொடுப்பனவுகளை எளிதாகப் பெற உங்கள் தனிப்பயன் QR ஐக் காட்டுங்கள்.',
      'gotIt': 'புரிந்தது!',
      'dailyPerformanceRating': 'தினசரி செயல்திறன் மதிப்பீடு',
      'salesIncreasedBy': 'இன்றைய விற்பனை அதிகரித்துள்ளது',
      'salesDecreasedBy': 'இன்றைய விற்பனை குறைந்துள்ளது',
      'bestHour': 'சிறந்த நேரம்',
      'yesterdayBestProduct': 'நேற்றைய சிறந்த தயாரிப்பு:',
      'noSales': 'விற்பனை இல்லை',
      'notAvailable': 'கிடைக்கவில்லை',
      'todaySales': 'இன்றைய விற்பனை',
      'yesterdaySales': 'நேற்றைய விற்பனை',
      'analysisAmazing': 'அற்புதம்! இன்று நீங்கள் ₹{0} சம்பாதித்துள்ளீர்கள், இது நேற்றை விட ₹{1} அதிகம்!',
      'analysisProgressing': 'முன்னேறுகிறது! இன்றைய விற்பனை ₹{0}. நேற்றைய விற்பனையை விட நீங்கள் வெறும் ₹{1} குறைவாக உள்ளீர்கள்!',
      'analysisWaiting': 'இன்றைய முதல் விற்பனைக்காகக் காத்திருக்கிறோம். இதைச் சிறந்ததாக மாற்றுவோம்!',
      'analysisMatch': 'இன்றைய செயல்திறன் நேற்றைய ₹{0} விற்பனையுடன் சரியாக ஒத்துப்போகிறது! தொடர்ச்சியான நிலைத்தன்மை.',
      'goodMorningName': 'காலை வணக்கம், {0}! ☀️',
      'goodAfternoonName': 'மதிய வணக்கம், {0}! 🌤️',
      'goodEveningName': 'இனிய மாலை, {0}! 🌙',
      'tapToUploadQr': 'QR ஐப் பதிவேற்ற தட்டவும்',
      'qrUploadFormat': 'கேலரியில் இருந்து PNG / JPG',
      'tripleChannelActive': 'மூன்று வழி கண்டறிதல் செயலில் உள்ளது',
      'listeningForPayments': 'UPI, SMS மற்றும் திரையை கவனிக்கிறது...',
      'listeningForPayments': 'UPI, SMS மற்றும் திரைக்காக காத்திருக்கிறது...',
      'selectDueDate': 'பணம் செலுத்தும் காலக்கெடுவைத் தேர்ந்தெடுக்கவும்',
      'deadline': 'காலக்கெடு',
      'overdue': 'தாமதமானது',
      'pendingPayment': 'நிலுவையில் உள்ள தொகை',
      'setDeadline': 'காலக்கெடுவை நிர்ணயிக்கவும்',
      'attendance': 'வருகை',
      'customers': 'வாடிக்கையாளர்கள்',
      'addCustomer': 'வாடிக்கையாளரைச் சேர்க்கவும்',
      'customerName': 'வாடிக்கையாளர் பெயர்',
      'invoices': 'இன்வாய்ஸ்கள்',
      'newInvoice': 'புதிய இன்வாய்ஸ்',
      'noInvoicesFound': 'இன்வாய்ஸ்கள் எதுவும் இல்லை',
      'noCustomersYet': 'இன்னும் வாடிக்கையாளர்கள் இல்லை',
      'noProductsYet': 'இன்னும் தயாரிப்புகள் இல்லை',
      'checkIn': 'உள்நுழைக',
      'checkOut': 'வெளியேறு',
      'todayStatus': "இன்றைய நிலை",
      'history': 'வரலாறு',
      'viewAll': 'அனைத்தையும் பார்க்கவும்',
      'mrp': 'Mrp',
      'rate': 'விகிதம்',
      'qty': 'அளவு',
      'amt': 'தொகை',
      'description': 'விளக்கம்',
      'billNo': 'பில் எண்',
      'date': 'தேதி',
      'time': 'நேரம்',
      'cashier': 'காசாளர்',
      'counter': 'கவுண்டர்',
      'cashBill': 'ரொக்கப் பில்',
      'youHaveSaved': 'நீங்கள் சேமித்தவை',
      'thankYouVisitAgain': 'நன்றி - மீண்டும் வருக',
      'items': 'பொருட்கள்',
      'total': 'மொத்தம்',
      'cash': 'ரொக்கம்',
      'serve': 'சேவை',
      'discount': 'தள்ளுபடி',
    },
  };

  String translate(String key) {
    return translations[locale.languageCode]?[key] ?? key;
  }

  String get appTitle => translations[locale.languageCode]?['appTitle'] ?? 'RETAIL MIND';
  String get tagline => translations[locale.languageCode]?['tagline'] ?? 'Smart Analytics & Billing Platform';
  String get email => translations[locale.languageCode]?['email'] ?? 'Email';
  String get password => translations[locale.languageCode]?['password'] ?? 'Password';
  String get login => translations[locale.languageCode]?['login'] ?? 'LOGIN';
  String get register => translations[locale.languageCode]?['register'] ?? 'REGISTER';
  String get signIn => translations[locale.languageCode]?['signIn'] ?? 'SIGN IN';
  String get createAccount => translations[locale.languageCode]?['createAccount'] ?? 'CREATE NEW ACCOUNT';
  String get signUp => translations[locale.languageCode]?['signUp'] ?? 'SIGN UP';
  String get enterEmail => translations[locale.languageCode]?['enterEmail'] ?? 'Enter your email';
  String get enterPassword => translations[locale.languageCode]?['enterPassword'] ?? 'Enter your password';
  String get confirmPassword => translations[locale.languageCode]?['confirmPassword'] ?? 'Confirm password';
  String get userName => translations[locale.languageCode]?['userName'] ?? 'User Name';
  String get shopName => translations[locale.languageCode]?['shopName'] ?? 'Shop Name';
  String get location => translations[locale.languageCode]?['location'] ?? 'Location';
  String get invalidCredentials => translations[locale.languageCode]?['invalidCredentials'] ?? 'Invalid credentials';
  String get connectionError => translations[locale.languageCode]?['connectionError'] ?? 'Connection error';
  String get welcome => translations[locale.languageCode]?['welcome'] ?? 'Welcome Back';
  String get enterCredentials => translations[locale.languageCode]?['enterCredentials'] ?? 'Enter your credentials to continue';
  String get dashboard => translations[locale.languageCode]?['dashboard'] ?? 'Dashboard';
  String get sales => translations[locale.languageCode]?['sales'] ?? 'Sales';
  String get query => translations[locale.languageCode]?['query'] ?? 'Query';
  String get giftCard => translations[locale.languageCode]?['giftCard'] ?? 'Gift Card';
  String get bills => translations[locale.languageCode]?['bills'] ?? 'Bills';
  String get insights => translations[locale.languageCode]?['insights'] ?? 'Insights';
  String get settings => translations[locale.languageCode]?['settings'] ?? 'Settings';
  String get logout => translations[locale.languageCode]?['logout'] ?? 'Logout';
  String get language => translations[locale.languageCode]?['language'] ?? 'Language';
  String get selectLanguage => translations[locale.languageCode]?['selectLanguage'] ?? 'Select Language';
  String get darkMode => translations[locale.languageCode]?['darkMode'] ?? 'Dark Mode';
  String get notification => translations[locale.languageCode]?['notification'] ?? 'Notifications';
  String get about => translations[locale.languageCode]?['about'] ?? 'About';
  String get share => translations[locale.languageCode]?['share'] ?? 'Share';
  String get help => translations[locale.languageCode]?['help'] ?? 'Help';
  String get profile => translations[locale.languageCode]?['profile'] ?? 'Profile';
  String get forgotPassword => translations[locale.languageCode]?['forgotPassword'] ?? 'Forgot Password?';
  
  String get welcomeBack => translations[locale.languageCode]?['welcomeBack'] ?? 'Welcome back,';
  String get salesByMonth => translations[locale.languageCode]?['salesByMonth'] ?? 'Sales by Month';
  String get salesByWeek => translations[locale.languageCode]?['salesByWeek'] ?? 'Sales by Week';
  String get salesByYear => translations[locale.languageCode]?['salesByYear'] ?? 'Sales by Year';
  String get searchQuery => translations[locale.languageCode]?['searchQuery'] ?? 'Search Query';
  String get dataUpload => translations[locale.languageCode]?['dataUpload'] ?? 'Data Upload';
  String get addSale => translations[locale.languageCode]?['addSale'] ?? 'Add Sale';
  String get totalAmount => translations[locale.languageCode]?['totalAmount'] ?? 'TOTAL AMOUNT';
  String get recordedSuccess => translations[locale.languageCode]?['recordedSuccess'] ?? 'Recorded successfully!';
  String get recordedLocally => translations[locale.languageCode]?['recordedLocally'] ?? 'Saved locally!';
  String get askMeAnything => translations[locale.languageCode]?['askMeAnything'] ?? 'Ask me anything...';
  String get aiAssistant => translations[locale.languageCode]?['aiAssistant'] ?? 'AI Assistant';
  String get alwaysHere => translations[locale.languageCode]?['alwaysHere'] ?? 'Always here to help';
  String get performanceOverview => translations[locale.languageCode]?['performanceOverview'] ?? 'Performance Overview';
  String get transactions => translations[locale.languageCode]?['transactions'] ?? 'Transactions';
  String get avgOrder => translations[locale.languageCode]?['avgOrder'] ?? 'Avg. Order';
  String get products => translations[locale.languageCode]?['products'] ?? 'Products';
  String get quickActions => translations[locale.languageCode]?['quickActions'] ?? 'Quick Actions';
  String get getInsights => translations[locale.languageCode]?['getInsights'] ?? 'Get Insights';
  String get today => translations[locale.languageCode]?['today'] ?? 'Today';
  String get week => translations[locale.languageCode]?['week'] ?? 'Week';
  String get month => translations[locale.languageCode]?['month'] ?? 'Month';
  String get year => translations[locale.languageCode]?['year'] ?? 'Year';
  String get showing => translations[locale.languageCode]?['showing'] ?? 'Showing';
  String get phone => translations[locale.languageCode]?['phone'] ?? 'Phone';
  String get owner => translations[locale.languageCode]?['owner'] ?? 'Owner';
  String get website => translations[locale.languageCode]?['website'] ?? 'Website';
  String get shopkeeper => translations[locale.languageCode]?['shopkeeper'] ?? 'SHOPKEEPER';
  String get shareCard => translations[locale.languageCode]?['shareCard'] ?? 'Share Card';
  String get viewBack => translations[locale.languageCode]?['viewBack'] ?? 'View Back';
  String get viewFront => translations[locale.languageCode]?['viewFront'] ?? 'View Front';
  String get goToDashboard => translations[locale.languageCode]?['goToDashboard'] ?? 'Go to Dashboard';
  String get tapToFlip => translations[locale.languageCode]?['tapToFlip'] ?? 'Tap to flip for QR code';
  String get tapToSeeFront => translations[locale.languageCode]?['tapToSeeFront'] ?? 'Tap to see front';
  String get scanToConnect => translations[locale.languageCode]?['scanToConnect'] ?? 'SCAN TO CONNECT';
  String get orScan => translations[locale.languageCode]?['orScan'] ?? 'OR SCAN';
  String get allContactIncluded => translations[locale.languageCode]?['allContactIncluded'] ?? 'All contact information included';
  String get personalInfo => translations[locale.languageCode]?['personalInfo'] ?? 'Personal Info';
  String get shopDetails => translations[locale.languageCode]?['shopDetails'] ?? 'Shop Details';
  String get security => translations[locale.languageCode]?['security'] ?? 'Security';
  String get fullName => translations[locale.languageCode]?['fullName'] ?? 'Full Name';
  String get emailAddress => translations[locale.languageCode]?['emailAddress'] ?? 'Email Address';
  String get phoneNumber => translations[locale.languageCode]?['phoneNumber'] ?? 'Phone Number';
  String get shopType => translations[locale.languageCode]?['shopType'] ?? 'Shop Type';
  String get taglineOptional => translations[locale.languageCode]?['taglineOptional'] ?? 'Tagline (optional)';
  String get websiteOptional => translations[locale.languageCode]?['websiteOptional'] ?? 'Website (optional)';
  String get alreadyHaveAccount => translations[locale.languageCode]?['alreadyHaveAccount'] ?? 'Already have an account?';
  String get joinCommunity => translations[locale.languageCode]?['joinCommunity'] ?? 'Join our community';
  String get uploadData => translations[locale.languageCode]?['uploadData'] ?? 'Upload Data';
  String get analytics => translations[locale.languageCode]?['analytics'] ?? 'Analytics';
  String get inventory => translations[locale.languageCode]?['inventory'] ?? 'Inventory';
  String get reports => translations[locale.languageCode]?['reports'] ?? 'Reports';
  String get last7Days => translations[locale.languageCode]?['last7Days'] ?? 'Last 7 Days';
  String get last30Days => translations[locale.languageCode]?['last30Days'] ?? 'Last 30 Days';
  String get thisYear => translations[locale.languageCode]?['thisYear'] ?? 'This Year';
  String get tapToUploadQr => translations[locale.languageCode]?['tapToUploadQr'] ?? 'Tap to upload QR';
  String get qrUploadFormat => translations[locale.languageCode]?['qrUploadFormat'] ?? 'PNG / JPG from gallery';
  String get tripleChannelActive => translations[locale.languageCode]?['tripleChannelActive'] ?? 'TRIPLE-CHANNEL DETECTION ACTIVE';
  String get listeningForPayments => translations[locale.languageCode]?['listeningForPayments'] ?? 'Listening for UPI, SMS & Screen...';
  String get goodMorning => translations[locale.languageCode]?['goodMorning'] ?? 'Good morning! â˜€ï¸';
  String get synced => translations[locale.languageCode]?['synced'] ?? 'SYNCED';
  String get performanceMessage => translations[locale.languageCode]?['performanceMessage'] ?? 'Here\'s how your shop is performing today';
  String get refresh => translations[locale.languageCode]?['refresh'] ?? 'Refresh';
  String get salesTrend => translations[locale.languageCode]?['salesTrend'] ?? 'Sales Trend';
  String get revenueDistribution => translations[locale.languageCode]?['revenueDistribution'] ?? 'Revenue Distribution';
  String get quantityDistribution => translations[locale.languageCode]?['quantityDistribution'] ?? 'Quantity Distribution';
  String get revenueLeaders => translations[locale.languageCode]?['revenueLeaders'] ?? 'Revenue Leaders';
  String get whatChartShows => translations[locale.languageCode]?['whatChartShows'] ?? 'What does this chart show?';
  String get askSimpleLanguage => translations[locale.languageCode]?['askSimpleLanguage'] ?? 'Ask in simple language';
  String get askQuestionHint => translations[locale.languageCode]?['askQuestionHint'] ?? 'Ask a question (e.g. "show sales last week")';
  String get askButton => translations[locale.languageCode]?['askButton'] ?? 'Ask';
  String get queryTip => translations[locale.languageCode]?['queryTip'] ?? 'Tip: Leave file empty to query your database';
  String get responseHint => translations[locale.languageCode]?['responseHint'] ?? 'Response will appear here';
  String get enterProductDetails => translations[locale.languageCode]?['enterProductDetails'] ?? 'Enter product details below';
  String get addProduct => translations[locale.languageCode]?['addProduct'] ?? 'Add Product';
  String get generateBill => translations[locale.languageCode]?['generateBill'] ?? 'Generate Bill';
  String get saveSales => translations[locale.languageCode]?['saveSales'] ?? 'Save Sales';
  String get paymentMethod => translations[locale.languageCode]?['paymentMethod'] ?? 'Payment Method';
  String get cashOffline => translations[locale.languageCode]?['cashOffline'] ?? 'Cash / Offline';
  String get onlineUPI => translations[locale.languageCode]?['onlineUPI'] ?? 'Online / UPI';
  String get confirmPayment => translations[locale.languageCode]?['confirmPayment'] ?? 'Confirm Payment Received';
  String get paymentConfirmed => translations[locale.languageCode]?['paymentConfirmed'] ?? 'Payment Confirmed';
  String get noSalesData => translations[locale.languageCode]?['noSalesData'] ?? 'No sales data available';
  String get uploadInventory => translations[locale.languageCode]?['uploadInventory'] ?? 'Upload Inventory';
  String get selectFile => translations[locale.languageCode]?['selectFile'] ?? 'Select File';
  String get upload => translations[locale.languageCode]?['upload'] ?? 'Upload';
  String get analyticsOverview => translations[locale.languageCode]?['analyticsOverview'] ?? 'Analytics Overview';
  String get askToScan => translations[locale.languageCode]?['askToScan'] ?? 'Ask customer to scan & pay';
  String get scannedBillTitle => translations[locale.languageCode]?['scannedBillTitle'] ?? 'Scanned Bill';
  String get askYourQuestion => translations[locale.languageCode]?['askYourQuestion'] ?? 'Ask Your Question';
  String get analysisResults => translations[locale.languageCode]?['analysisResults'] ?? 'Analysis Results';
  String get analysisSummary => translations[locale.languageCode]?['analysisSummary'] ?? 'Analysis Summary';
  String get detailedData => translations[locale.languageCode]?['detailedData'] ?? 'Detailed Data';
  String get total => translations[locale.languageCode]?['total'] ?? 'Total';
  String get revenueShare => translations[locale.languageCode]?['revenueShare'] ?? 'Revenue Share';
  String get topProductsByRevenue => translations[locale.languageCode]?['topProductsByRevenue'] ?? 'Top Products by Revenue';
  String get volumeAnalysis => translations[locale.languageCode]?['volumeAnalysis'] ?? 'Volume Analysis';
  String get unitMovementRadar => translations[locale.languageCode]?['unitMovementRadar'] ?? 'Unit Movement Radar';
  String get upwardTrend => translations[locale.languageCode]?['upwardTrend'] ?? 'Upward trend';
  String get downwardTrend => translations[locale.languageCode]?['downwardTrend'] ?? 'Downward trend';
  String get avgChange => translations[locale.languageCode]?['avgChange'] ?? 'avg change';
  String get noProductData => translations[locale.languageCode]?['noProductData'] ?? 'No product data';
  String get volumeByProduct => translations[locale.languageCode]?['volumeByProduct'] ?? 'Volume by Product';
  String get revenueLeadersDesc => translations[locale.languageCode]?['revenueLeadersDesc'] ?? 'This bar chart highlights the top products by revenue within the selected time frame.';
  String get salesTrendDesc => translations[locale.languageCode]?['salesTrendDesc'] ?? "The line chart displays total sales over recent days, giving you an idea of your store's momentum.";
  String get revenueDistributionDesc => translations[locale.languageCode]?['revenueDistributionDesc'] ?? 'The pie (donut) chart shows how much each product contributes to overall revenue.';
  String get quantityDistributionDesc => translations[locale.languageCode]?['quantityDistributionDesc'] ?? 'The radar chart compares units sold per product, helping you spot high-volume items.';
  String get monthlySalesDesc => translations[locale.languageCode]?['monthlySalesDesc'] ?? 'Track your total sales amount for each month. Identify trends and peak sales periods throughout the year.';
  String get weeklySalesDesc => translations[locale.languageCode]?['weeklySalesDesc'] ?? 'View your sales performance over the last 12 weeks. Spot weekly patterns and week-over-week growth.';
  String get yearlySalesDesc => translations[locale.languageCode]?['yearlySalesDesc'] ?? 'Compare total sales across different years. Perfect for tracking long-term business growth and performance trends.';

  String get howToUseTitle => translations[locale.languageCode]?['howToUseTitle'] ?? 'How to Use';
  String get step1Title => translations[locale.languageCode]?['step1Title'] ?? '';
  String get step1Desc => translations[locale.languageCode]?['step1Desc'] ?? '';
  String get step2Title => translations[locale.languageCode]?['step2Title'] ?? '';
  String get step2Desc => translations[locale.languageCode]?['step2Desc'] ?? '';
  String get step3Title => translations[locale.languageCode]?['step3Title'] ?? '';
  String get step3Desc => translations[locale.languageCode]?['step3Desc'] ?? '';
  String get step4Title => translations[locale.languageCode]?['step4Title'] ?? '';
  String get step4Desc => translations[locale.languageCode]?['step4Desc'] ?? '';
  String get step5Title => translations[locale.languageCode]?['step5Title'] ?? '';
  String get step5Desc => translations[locale.languageCode]?['step5Desc'] ?? '';
  String get gotIt => translations[locale.languageCode]?['gotIt'] ?? 'Got it!';

  String get dailyPerformanceRating => translations[locale.languageCode]?['dailyPerformanceRating'] ?? 'DAILY PERFORMANCE RATING';
  String get salesIncreasedBy => translations[locale.languageCode]?['salesIncreasedBy'] ?? "Today's sales increased by";
  String get salesDecreasedBy => translations[locale.languageCode]?['salesDecreasedBy'] ?? "Today's sales decreased by";
  String get bestHour => translations[locale.languageCode]?['bestHour'] ?? 'Best Hour';
  String get yesterdayBestProductLabel => translations[locale.languageCode]?['yesterdayBestProduct'] ?? "Yesterday's best product:";
  String get noSales => translations[locale.languageCode]?['noSales'] ?? 'No sales';
  String get notAvailable => translations[locale.languageCode]?['notAvailable'] ?? 'N/A';
  String get todaySales => translations[locale.languageCode]?['todaySales'] ?? 'Today Sales';
  String get yesterdaySales => translations[locale.languageCode]?['yesterdaySales'] ?? 'Yesterday Sales';
  String get analysisAmazing => translations[locale.languageCode]?['analysisAmazing'] ?? '';
  String get analysisProgressing => translations[locale.languageCode]?['analysisProgressing'] ?? '';
  String get analysisWaiting => translations[locale.languageCode]?['analysisWaiting'] ?? '';
  String get analysisMatch => translations[locale.languageCode]?['analysisMatch'] ?? '';
  String get goodMorningName => translations[locale.languageCode]?['goodMorningName'] ?? 'Good morning, {0}! ☀️';
  String get goodAfternoonName => translations[locale.languageCode]?['goodAfternoonName'] ?? 'Good afternoon, {0}! 🌤️';
  String get goodEveningName => translations[locale.languageCode]?['goodEveningName'] ?? 'Good evening, {0}! 🌙';
  String get noInsights => translations[locale.languageCode]?['noInsights'] ?? 'No insights available';
  String get selectDueDate => translations[locale.languageCode]?['selectDueDate'] ?? 'Select Due Date';
  String get deadline => translations[locale.languageCode]?['deadline'] ?? 'Deadline';
  String get overdue => translations[locale.languageCode]?['overdue'] ?? 'Overdue';
  String get pendingPayment => translations[locale.languageCode]?['pendingPayment'] ?? 'Pending Payment';
  String get setDeadline => translations[locale.languageCode]?['setDeadline'] ?? 'Set Deadline';
  String get attendance => translations[locale.languageCode]?['attendance'] ?? 'Attendance';
  String get customers => translations[locale.languageCode]?['customers'] ?? 'Customers';
  String get addCustomer => translations[locale.languageCode]?['addCustomer'] ?? 'Add Customer';
  String get customerName => translations[locale.languageCode]?['customerName'] ?? 'Customer Name';
  String get invoices => translations[locale.languageCode]?['invoices'] ?? 'Invoices';
  String get newInvoice => translations[locale.languageCode]?['newInvoice'] ?? 'New Invoice';
  String get noInvoicesFound => translations[locale.languageCode]?['noInvoicesFound'] ?? 'No Invoices Found';
  String get noCustomersYet => translations[locale.languageCode]?['noCustomersYet'] ?? 'No Customers Yet';
  String get noProductsYet => translations[locale.languageCode]?['noProductsYet'] ?? 'No Products Yet';
  String get checkIn => translations[locale.languageCode]?['checkIn'] ?? 'Check In';
  String get checkOut => translations[locale.languageCode]?['checkOut'] ?? 'Check Out';
  String get todayStatus => translations[locale.languageCode]?['todayStatus'] ?? "Today's Status";
  String get history => translations[locale.languageCode]?['history'] ?? 'History';
  String get viewAll => translations[locale.languageCode]?['viewAll'] ?? 'View All';
  String get expenses => translations[locale.languageCode]?['expenses'] ?? 'Expenses';
  String get workers => translations[locale.languageCode]?['workers'] ?? 'Workers';
  String get backup => translations[locale.languageCode]?['backup'] ?? 'Backup & Restore';

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('te'),
    Locale('hi'),
    Locale('ta'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'te', 'hi', 'ta'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
