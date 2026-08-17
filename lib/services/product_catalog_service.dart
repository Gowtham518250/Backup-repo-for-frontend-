import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// 🔧 FLIPKART-LEVEL: Product Catalog Service
/// Manages product categories, subcategories, and catalog organization
class ProductCatalogService {
  // 🔧 FLIPKART-LEVEL: Category structure with hierarchical organization
  static const List<Map<String, dynamic>> _defaultCategories = [
    {
      'id': 'electronics',
      'name': 'Electronics',
      'icon': 'devices',
      'subcategories': [
        {'id': 'mobiles', 'name': 'Mobiles', 'icon': 'smartphone'},
        {'id': 'laptops', 'name': 'Laptops', 'icon': 'laptop'},
        {'id': 'appliances', 'name': 'Home Appliances', 'icon': 'kitchen'},
        {'id': 'accessories', 'name': 'Accessories', 'icon': 'headphones'},
      ],
    },
    {
      'id': 'fashion',
      'name': 'Fashion',
      'icon': 'checkroom',
      'subcategories': [
        {'id': 'men', 'name': "Men's Wear", 'icon': 'man'},
        {'id': 'women', 'name': "Women's Wear", 'icon': 'woman'},
        {'id': 'kids', 'name': "Kids' Wear", 'icon': 'child_care'},
        {'id': 'footwear', 'name': 'Footwear', 'icon': 'shoes'},
      ],
    },
    {
      'id': 'grocery',
      'name': 'Grocery',
      'icon': 'shopping_basket',
      'subcategories': [
        {'id': 'staples', 'name': 'Staples', 'icon': 'grain'},
        {'id': 'dairy', 'name': 'Dairy', 'icon': 'local_drink'},
        {'id': 'snacks', 'name': 'Snacks', 'icon': 'cookie'},
        {'id': 'beverages', 'name': 'Beverages', 'icon': 'emoji_food_beverage'},
      ],
    },
    {
      'id': 'home',
      'name': 'Home & Living',
      'icon': 'home',
      'subcategories': [
        {'id': 'furniture', 'name': 'Furniture', 'icon': 'chair'},
        {'id': 'decor', 'name': 'Home Decor', 'icon': 'palette'},
        {'id': 'kitchen', 'name': 'Kitchen', 'icon': 'soup_kitchen'},
        {'id': 'bathroom', 'name': 'Bathroom', 'icon': 'bathtub'},
      ],
    },
    {
      'id': 'beauty',
      'name': 'Beauty & Personal Care',
      'icon': 'face',
      'subcategories': [
        {'id': 'skincare', 'name': 'Skin Care', 'icon': 'spa'},
        {'id': 'haircare', 'name': 'Hair Care', 'icon': 'content_cut'},
        {'id': 'makeup', 'name': 'Makeup', 'icon': 'brush'},
        {'id': 'fragrance', 'name': 'Fragrance', 'icon': 'perfume'},
      ],
    },
    {
      'id': 'sports',
      'name': 'Sports & Fitness',
      'icon': 'sports_soccer',
      'subcategories': [
        {'id': 'equipment', 'name': 'Sports Equipment', 'icon': 'sports'},
        {'id': 'fitness', 'name': 'Fitness', 'icon': 'fitness_center'},
        {'id': 'clothing', 'name': 'Sports Clothing', 'icon': 'sports_martial_arts'},
        {'id': 'accessories', 'name': 'Sports Accessories', 'icon': 'watch'},
      ],
    },
  ];

  /// 🔧 FLIPKART-LEVEL: Get all categories
  static Future<List<Map<String, dynamic>>> getCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final categoriesJson = prefs.getString('product_categories');
    
    if (categoriesJson != null) {
      try {
        final List<dynamic> decoded = json.decode(categoriesJson);
        return decoded.cast<Map<String, dynamic>>();
      } catch (e) {
        if (kDebugMode) debugPrint('Error loading categories: $e');
      }
    }
    
    // Return default categories if none saved
    return _defaultCategories;
  }

  /// 🔧 FLIPKART-LEVEL: Save categories
  static Future<void> saveCategories(List<Map<String, dynamic>> categories) async {
    final prefs = await SharedPreferences.getInstance();
    final categoriesJson = json.encode(categories);
    await prefs.setString('product_categories', categoriesJson);
  }

  /// 🔧 FLIPKART-LEVEL: Get category by ID
  static Future<Map<String, dynamic>?> getCategoryById(String categoryId) async {
    final categories = await getCategories();
    for (var category in categories) {
      if (category['id'] == categoryId) {
        return category;
      }
    }
    return null;
  }

  /// 🔧 FLIPKART-LEVEL: Get subcategory by ID
  static Future<Map<String, dynamic>?> getSubcategoryById(String subcategoryId) async {
    final categories = await getCategories();
    for (var category in categories) {
      final subcategories = category['subcategories'] as List<dynamic>?;
      if (subcategories != null) {
        for (var subcategory in subcategories) {
          if (subcategory['id'] == subcategoryId) {
            return subcategory;
          }
        }
      }
    }
    return null;
  }

  /// 🔧 FLIPKART-LEVEL: Add custom category
  static Future<void> addCategory(Map<String, dynamic> category) async {
    final categories = await getCategories();
    categories.add(category);
    await saveCategories(categories);
  }

  /// 🔧 FLIPKART-LEVEL: Add subcategory to a category
  static Future<void> addSubcategory(String categoryId, Map<String, dynamic> subcategory) async {
    final categories = await getCategories();
    for (var category in categories) {
      if (category['id'] == categoryId) {
        final subcategories = category['subcategories'] as List<dynamic>? ?? [];
        subcategories.add(subcategory);
        category['subcategories'] = subcategories;
        break;
      }
    }
    await saveCategories(categories);
  }

  /// 🔧 FLIPKART-LEVEL: Delete category
  static Future<void> deleteCategory(String categoryId) async {
    final categories = await getCategories();
    categories.removeWhere((cat) => cat['id'] == categoryId);
    await saveCategories(categories);
  }

  /// 🔧 FLIPKART-LEVEL: Delete subcategory
  static Future<void> deleteSubcategory(String categoryId, String subcategoryId) async {
    final categories = await getCategories();
    for (var category in categories) {
      if (category['id'] == categoryId) {
        final subcategories = category['subcategories'] as List<dynamic>?;
        if (subcategories != null) {
          subcategories.removeWhere((sub) => sub['id'] == subcategoryId);
          category['subcategories'] = subcategories;
        }
        break;
      }
    }
    await saveCategories(categories);
  }

  /// 🔧 FLIPKART-LEVEL: Assign product to category
  static Future<void> assignProductToCategory(String productId, String categoryId, String subcategoryId) async {
    final prefs = await SharedPreferences.getInstance();
    final assignmentsJson = prefs.getString('product_category_assignments');
    
    Map<String, dynamic> assignments = {};
    if (assignmentsJson != null) {
      try {
        assignments = json.decode(assignmentsJson) as Map<String, dynamic>;
      } catch (e) {
        if (kDebugMode) debugPrint('Error loading assignments: $e');
      }
    }

    assignments[productId] = {
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'assigned_at': DateTime.now().toIso8601String(),
    };

    await prefs.setString('product_category_assignments', json.encode(assignments));
  }

  /// 🔧 FLIPKART-LEVEL: Get products by category
  static Future<List<String>> getProductsByCategory(String categoryId, {String? subcategoryId}) async {
    final prefs = await SharedPreferences.getInstance();
    final assignmentsJson = prefs.getString('product_category_assignments');
    
    if (assignmentsJson == null) return [];

    try {
      final assignments = json.decode(assignmentsJson) as Map<String, dynamic>;
      List<String> productIds = [];

      for (var entry in assignments.entries) {
        final assignment = entry.value as Map<String, dynamic>;
        if (assignment['category_id'] == categoryId) {
          if (subcategoryId == null || assignment['subcategory_id'] == subcategoryId) {
            productIds.add(entry.key);
          }
        }
      }

      return productIds;
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting products by category: $e');
      return [];
    }
  }

  /// 🔧 FLIPKART-LEVEL: Get category for a product
  static Future<Map<String, dynamic>?> getProductCategory(String productId) async {
    final prefs = await SharedPreferences.getInstance();
    final assignmentsJson = prefs.getString('product_category_assignments');
    
    if (assignmentsJson == null) return null;

    try {
      final assignments = json.decode(assignmentsJson) as Map<String, dynamic>;
      final assignment = assignments[productId] as Map<String, dynamic>?;
      
      if (assignment != null) {
        final categoryId = assignment['category_id'] as String?;
        if (categoryId != null) {
          return await getCategoryById(categoryId);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting product category: $e');
    }

    return null;
  }

  /// 🔧 FLIPKART-LEVEL: Search categories by name
  static Future<List<Map<String, dynamic>>> searchCategories(String query) async {
    final categories = await getCategories();
    final lowerQuery = query.toLowerCase();
    
    return categories.where((category) {
      final name = (category['name'] as String).toLowerCase();
      return name.contains(lowerQuery);
    }).toList();
  }

  /// 🔧 FLIPKART-LEVEL: Reset to default categories
  static Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('product_categories');
    await prefs.remove('product_category_assignments');
  }
}
