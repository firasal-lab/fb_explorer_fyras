// ===================================================================
// 📱 ملف كود Flutter الرئيسي - "Fb Explorer Fyras"
// ===================================================================
//
// 🎯 الإصدار: 1.0.0 (المُحسّن - مع تصحيحات كاملة)
// 📅 التاريخ: 16 ديسمبر 2025
// 🔧 المطور: فريق Fb Explorer Fyras
// ===================================================================

// 📦 استيراد المكتبات
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// ===================================================================
// 🏗️ نماذج البيانات
// ===================================================================

/// 🏷️ نموذج المنشور المجموع من فيسبوك
class ScrapedPost {
  final String originalText;
  final String originalAuthor;
  final String authorProfileUrl;
  final String contactInfo;
  final String originalPostUrl;
  final String? sharedFromUrl;
  final String scrapedAt;
  final int mediaCount;

  ScrapedPost({
    required this.originalText,
    required this.originalAuthor,
    required this.authorProfileUrl,
    required this.contactInfo,
    required this.originalPostUrl,
    this.sharedFromUrl,
    required this.scrapedAt,
    required this.mediaCount,
  });

  Map<String, dynamic> toJson() => {
    'original_text': originalText,
    'original_author': originalAuthor,
    'author_profile_url': authorProfileUrl,
    'contact_info': contactInfo,
    'original_post_url': originalPostUrl,
    'shared_from_url': sharedFromUrl,
    'scraped_at': scrapedAt,
    'media_count': mediaCount,
  };
}

/// 👤 نموذج حساب فيسبوك المحفوظ
class Account {
  final String id;
  final String displayName;
  final String username;
  final String encryptedPassword;
  final DateTime createdAt;
  DateTime lastUsed;

  Account({
    required this.id,
    required this.displayName,
    required this.username,
    required this.encryptedPassword,
  }) : createdAt = DateTime.now(), lastUsed = DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'username': username,
    'encryptedPassword': encryptedPassword,
    'createdAt': createdAt.toIso8601String(),
    'lastUsed': lastUsed.toIso8601String(),
  };

  factory Account.fromJson(Map<String, dynamic> json) {
    final account = Account(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      displayName: json['displayName'] ?? 'حساب بدون اسم',
      username: json['username'] ?? '',
      encryptedPassword: json['encryptedPassword'] ?? '',
    );
    if (json['lastUsed'] != null) {
      account.lastUsed = DateTime.parse(json['lastUsed']);
    }
    return account;
  }
}
// ===================================================================
// ⚙️ الخدمات (المُحسّنة)
// ===================================================================

/// 🎯 خدمة جمع البيانات (مع تصحيحات كاملة)
class ScraperService {
  List<ScrapedPost> _temporaryPosts = [];
  String? _firstSourceName;
  
  int get postCount => _temporaryPosts.length;
  String? get firstSourceName => _firstSourceName;
  List<ScrapedPost> get posts => List.unmodifiable(_temporaryPosts);
  
  /// ➕ إضافة منشور جديد (مع تحسين تسمية المصدر)
  void addPost(ScrapedPost post) {
    _temporaryPosts.add(post);
    
    if (_firstSourceName == null) {
      _extractSourceName(post.originalPostUrl);
    }
    
    print('✅ تمت إضافة منشور: ${post.originalAuthor}');
  }
  
  /// 🗑️ إزالة منشور
  void removePost(String postUrl) {
    final initialCount = _temporaryPosts.length;
    _temporaryPosts.removeWhere((post) => post.originalPostUrl == postUrl);
    
    if (initialCount != _temporaryPosts.length) {
      print('🗑️ تمت إزالة منشور');
    }
  }
  
  /// 🔤 استخراج اسم المصدر (محسّن)
  void _extractSourceName(String url) {
    try {
      String sourceName = 'مصدر_عام';
      
      if (url.contains('/groups/')) {
        final parts = url.split('/groups/');
        if (parts.length > 1) {
          final groupName = parts[1].split('/')[0];
          if (groupName.isNotEmpty) sourceName = 'مجموعة_${groupName}';
        }
      } else if (url.contains('/pages/')) {
        final parts = url.split('/pages/');
        if (parts.length > 1) {
          final pageName = parts[1].split('/')[0];
          if (pageName.isNotEmpty) sourceName = 'صفحة_${pageName}';
        }
      } else if (url.contains('facebook.com/')) {
        final username = url.split('facebook.com/')[1].split('/')[0];
        if (username.isNotEmpty && !username.contains('?')) {
          sourceName = username;
        }
      }
      
      // 🔧 تنظيف الاسم مع تحسين للاسم الافتراضي
      _firstSourceName = _sanitizeFilename(sourceName);
      
      // إذا بقي الاسم افتراضيًا، نضيف معرفًا فريدًا
      if (_firstSourceName == 'مصدر_عام') {
        final uniqueId = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
        _firstSourceName = 'جلسة_${uniqueId}';
      }
      
    } catch (e) {
      final uniqueId = DateTime.now().millisecondsSinceEpoch.toString().substring(6);
      _firstSourceName = 'جلسة_${uniqueId}';
    }
  }
  
  /// 🔤 تنظيف اسم الملف
  String _sanitizeFilename(String filename) {
    return filename.replaceAll(RegExp(r'[\\/*?:"<>|]'), '_');
  }
  
  /// 🔢 حساب الكلمات (محسّن للعربية)
  int calculateTotalWords({String? headerText}) {
    int totalWords = 0;
    
    for (final post in _temporaryPosts) {
      final text = post.originalText.trim();
      if (text.isNotEmpty) {
        totalWords += text.split(RegExp(r'\s+')).length;
      }
    }
    
    if (headerText != null && headerText.isNotEmpty) {
      totalWords += headerText.trim().split(RegExp(r'\s+')).length;
    }
    
    return totalWords;
  }
  
  /// 📄 قراءة الموجه من الملف (المُصحّح - لا يوجد افتراضي في الكود)
  Future<String> loadAIPrompt() async {
    try {
      final directory = await getExternalStorageDirectory();
      final appDir = Directory('${directory!.path}/منصّة الإعلانات');
      final promptFile = File('${appDir.path}/ai_prompt.txt');
      
      // التأكد من وجود المجلد
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
        print('📁 تم إنشاء مجلد التطبيق');
      }
      
      // محاولة قراءة من التخزين
      if (await promptFile.exists()) {
        final content = await promptFile.readAsString(encoding: utf8);
        if (content.trim().isNotEmpty) {
          return content;
        }
      }
      
      // إذا الملف غير موجود أو فارغ، ننسخ من assets
      print('📄 جاري نسخ الموجه الافتراضي من assets...');
      final defaultPrompt = await _loadDefaultPromptFromAssets();
      await promptFile.writeAsString(defaultPrompt, encoding: utf8);
      return defaultPrompt;
      
    } catch (e) {
      print('❌ خطأ في تحميل الموجه: $e');
      
      // كمحاولة أخيرة، نعود لـ assets مباشرة
      return await _loadDefaultPromptFromAssets();
    }
  }
  
  /// 📦 تحميل الموجه الافتراضي من assets فقط
  Future<String> _loadDefaultPromptFromAssets() async {
    try {
      return await rootBundle.loadString('assets/ai_prompt.txt');
    } catch (e) {
      print('❌ خطأ في تحميل الموجه من assets: $e');
      // ❌ لا نعود لنص افتراضي في الكود - نرفع استثناء
      throw Exception('تعذر تحميل ملف الموجه. تأكد من وجود assets/ai_prompt.txt');
    }
  }
  
  /// 📝 توليد الرأس التوجيهي
  Future<String> generateFileHeader() async {
    try {
      final aiPrompt = await loadAIPrompt(); // ✅ مصدر واحد فقط
      
      final postCount = _temporaryPosts.length;
      final wordCount = calculateTotalWords();
      
      final uniqueSources = <String>{};
      for (final post in _temporaryPosts) {
        uniqueSources.add(post.originalPostUrl);
        if (post.sharedFromUrl != null) {
          uniqueSources.add(post.sharedFromUrl!);
        }
      }
      
      final sourcesList = uniqueSources.map((source) => '- $source').join('\n');
      
      return '''
$aiPrompt

الإحصائيات:
- عدد المنشورات: $postCount
- إجمالي الكلمات: $wordCount

المصادر المستخرجة منها:
$sourcesList

المنشورات الخام:
==========
''';
      
    } catch (e) {
      print('❌ خطأ في توليد الرأس: $e');
      rethrow; // ✅ نرفع الخطأ بدلاً من إرجاع نص بديل
    }
  }
  
  /// 💾 حفظ البيانات إلى ملفات (محسّن)
  Future<String> saveToFiles() async {
    if (_temporaryPosts.isEmpty) {
      throw Exception('لا توجد منشورات لحفظها');
    }
    
    try {
      final directory = await getExternalStorageDirectory();
      final appDir = Directory('${directory!.path}/منصّة الإعلانات');
      
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }
      
      // 🏷️ توليد اسم ملف فريد (محسّن)
      final now = DateTime.now();
      final datePart = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final timePart = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      
      final random = Random();
      const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final randomPart = String.fromCharCodes(
        Iterable.generate(4, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
      );
      
      // ✅ استخدام اسم المصدر المحسّن
      final sourceName = _firstSourceName ?? 'جلسة_${now.millisecondsSinceEpoch.toString().substring(9)}';
      final baseName = '${sourceName}_${datePart}_${timePart}_$randomPart';
      final rawFileName = '${baseName}_خام.json';
      final cleanFileName = '${baseName}_منقح.json';
      
      print('💾 حفظ الملفات: $rawFileName');
      
      // توليد المحتوى
      final header = await generateFileHeader();
      final jsonContent = jsonEncode(_temporaryPosts.map((post) => post.toJson()).toList());
      final rawFileContent = '$header\n$jsonContent';
      
      // حفظ الملف الخام
      final rawFile = File('${appDir.path}/$rawFileName');
      await rawFile.writeAsString(rawFileContent, encoding: utf8);
      
      // إنشاء ملف منقّح فارغ
      final cleanFile = File('${appDir.path}/$cleanFileName');
      await cleanFile.writeAsString('', encoding: utf8);
      
      return rawFileName;
      
    } catch (e) {
      print('❌ خطأ في حفظ الملفات: $e');
      rethrow;
    }
  }
  
  /// 🧹 مسح الجلسة
  void clearSession() {
    _temporaryPosts.clear();
    _firstSourceName = null;
  }
}

/// 👤 خدمة إدارة الحسابات
class AccountService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  Future<void> saveAccount(Account account) async {
    try {
      final accountKey = 'account_${account.id}';
      await _secureStorage.write(key: accountKey, value: jsonEncode(account.toJson()));
    } catch (e) {
      print('❌ خطأ في حفظ الحساب: $e');
      rethrow;
    }
  }
  
  Future<List<Account>> loadAccounts() async {
    try {
      final allData = await _secureStorage.readAll();
      final accounts = <Account>[];
      
      for (final entry in allData.entries) {
        if (entry.key.startsWith('account_')) {
          try {
            final accountData = jsonDecode(entry.value!) as Map<String, dynamic>;
            accounts.add(Account.fromJson(accountData));
          } catch (e) {
            print('⚠️ تجاهل حساب تالف: ${entry.key}');
          }
        }
      }
      
      accounts.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
      return accounts;
    } catch (e) {
      print('❌ خطأ في تحميل الحسابات: $e');
      return [];
    }
  }
  
  Future<void> deleteAccount(String accountId) async {
    try {
      await _secureStorage.delete(key: 'account_$accountId');
    } catch (e) {
      print('❌ خطأ في حذف الحساب: $e');
      rethrow;
    }
  }
}// ===================================================================
// 🖼️ الواجهات والمكونات (المُحسّنة)
// ===================================================================

/// 👤 قائمة الحسابات الجانبية
class AccountDrawer extends StatefulWidget {
  final VoidCallback? onAccountSelected;
  final VoidCallback? onAddAccount;
  
  const AccountDrawer({super.key, this.onAccountSelected, this.onAddAccount});
  
  @override
  State<AccountDrawer> createState() => _AccountDrawerState();
}

class _AccountDrawerState extends State<AccountDrawer> {
  List<Account> _accounts = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }
  
  Future<void> _loadAccounts() async {
    try {
      final loadedAccounts = await AccountService().loadAccounts();
      if (mounted) {
        setState(() {
          _accounts = loadedAccounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ خطأ في تحميل الحسابات: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 300,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF1877F2)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('حساباتي', style: TextStyle(color: Colors.white, fontSize: 24)),
                const SizedBox(height: 8),
                Text('${_accounts.length} حساب(ات)', style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          
          if (!_isLoading && _accounts.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text('الحسابات المحفوظة:', style: TextStyle(color: Colors.grey)),
            ),
            
            ..._accounts.map((account) => ListTile(
              leading: const Icon(Icons.person, color: Color(0xFF1877F2)),
              title: Text(account.displayName),
              subtitle: Text(account.username, style: const TextStyle(fontSize: 12)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => _showDeleteDialog(account),
              ),
              onTap: () {
                Navigator.pop(context);
                widget.onAccountSelected?.call();
                _updateLastUsed(account);
              },
            )),
            
            const Divider(),
          ],
          
          if (!_isLoading && _accounts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('لا توجد حسابات محفوظة بعد.', textAlign: TextAlign.center),
            ),
          
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: Colors.green),
            title: const Text('إضافة حساب جديد'),
            onTap: () {
              Navigator.pop(context);
              widget.onAddAccount?.call();
            },
          ),
        ],
      ),
    );
  }
  
  void _showDeleteDialog(Account account) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('حذف حساب "${account.displayName}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await AccountService().deleteAccount(account.id);
                Navigator.pop(context);
                await _loadAccounts();
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('خطأ في الحذف: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  void _updateLastUsed(Account account) async {
    try {
      account.lastUsed = DateTime.now();
      await AccountService().saveAccount(account);
    } catch (e) {
      print('⚠️ خطأ في تحديث وقت الاستخدام: $e');
    }
  }
}

/// 🧹 شاشة التنقية
class RefinementScreen extends StatefulWidget {
  final String rawFilename;
  
  const RefinementScreen({super.key, required this.rawFilename});
  
  @override
  State<RefinementScreen> createState() => _RefinementScreenState();
}

class _RefinementScreenState extends State<RefinementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _rawContent = '';
  String _cleanContent = '';
  int _rawWordCount = 0;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRawFile();
  }
  
  Future<void> _loadRawFile() async {
    try {
      final dir = await getExternalStorageDirectory();
      final file = File('${dir!.path}/منصّة الإعلانات/${widget.rawFilename}');
      
      if (!await file.exists()) {
        throw Exception('الملف غير موجود: ${widget.rawFilename}');
      }
      
      final content = await file.readAsString(encoding: utf8);
      final wordCount = content.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
      
      if (mounted) {
        setState(() {
          _rawContent = content;
          _rawWordCount = wordCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ خطأ في تحميل الملف الخام: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التحميل: $e'), backgroundColor: Colors.red),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    }
  }
  
  Future<void> _saveCleanFile() async {
    if (_cleanContent.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الملف المنقّح فارغ!'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    try {
      final baseName = widget.rawFilename.replaceAll('_خام.json', '');
      final cleanFilename = '${baseName}_منقح.json';
      
      final dir = await getExternalStorageDirectory();
      final file = File('${dir!.path}/منصّة الإعلانات/$cleanFilename');
      
      await file.writeAsString(_cleanContent, encoding: utf8);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حفظ: $cleanFilename'), backgroundColor: Colors.green),
      );
      
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
      
    } catch (e) {
      print('❌ خطأ في حفظ الملف المنقّح: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في الحفظ: $e'), backgroundColor: Colors.red),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('شاشة التنقية'),
        backgroundColor: const Color(0xFF1877F2),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.raw_on), text: 'الملف الخام'),
            Tab(icon: Icon(Icons.cleaning_services), text: 'الملف المنقّح'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildRawFileTab(), _buildCleanFileTab()],
            ),
    );
  }
  
  Widget _buildRawFileTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Chip(label: Text('$_rawWordCount كلمة')),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.copy, size: 20),
                label: const Text('نسخ الملف الخام'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _rawContent));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم النسخ'), backgroundColor: Colors.green),
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(_rawContent, style: const TextStyle(fontFamily: 'monospace')),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildCleanFileTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.paste, size: 20),
                label: const Text('لصق النتيجة'),
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null && mounted) {
                    setState(() => _cleanContent = data!.text!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم اللصق'), backgroundColor: Colors.green),
                    );
                  }
                },
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.save, size: 20),
                label: const Text('حفظ الملف المنقّح'),
                onPressed: _saveCleanFile,
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: TextEditingController(text: _cleanContent),
              onChanged: (value) => setState(() => _cleanContent = value),
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
                hintText: 'الصق نتيجة الذكاء الاصطناعي هنا...',
              ),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ),
      ],
    );
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}


/// 🏠 الشاشة الرئيسية (المُحسّنة مع فحص الإنترنت)
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScraperService _scraper = ScraperService();
  final TextEditingController _urlController = TextEditingController(text: 'https://www.facebook.com');
  late WebViewController _webViewController;
  bool _isLoading = false;
  final AccountService _accountService = AccountService();
  
  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      WebView.platform = AndroidWebView();
    }
    _ensurePromptFileExists();
  }
  
  Future<void> _ensurePromptFileExists() async {
    try {
      await _scraper.loadAIPrompt();
    } catch (e) {
      print('⚠️ خطأ في التحقق من ملف الموجه: $e');
    }
  }
  
  Future<void> _injectJavaScript() async {
    try {
      final jsCode = await rootBundle.loadString('facebook_scraper.js');
      await _webViewController.runJavaScript(jsCode);
    } catch (e) {
      print('⚠️ خطأ في حقن JavaScript: $e');
    }
  }
  
  /// 🌐 فحص اتصال الإنترنت قبل التحميل
  Future<bool> _checkInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      print('⚠️ خطأ في فحص الاتصال: $e');
      return true; // نستمر على افتراض وجود اتصال
    }
  }
  
  Future<void> _showAddAccountDialog() async {
    final nameController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة حساب جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(hintText: 'اسم الحساب')),
            TextField(controller: usernameController, decoration: const InputDecoration(hintText: 'البريد أو الهاتف')),
            TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(hintText: 'كلمة المرور')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || usernameController.text.isEmpty || passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى تعبئة جميع الحقول'), backgroundColor: Colors.orange),
                );
                return;
              }
              
              try {
                final newAccount = Account(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  displayName: nameController.text,
                  username: usernameController.text,
                  encryptedPassword: passwordController.text,
                );
                await _accountService.saveAccount(newAccount);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم حفظ الحساب: ${newAccount.displayName}'), backgroundColor: Colors.green),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('خطأ في حفظ الحساب: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _saveRawFileAndOpenRefinement() async {
    if (_scraper.postCount == 0) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('لا توجد منشورات'),
          content: const Text('لم تحفظ أي منشورات بعد.\nاذهب لمجموعة فيسبوك واضغط "💾 حفظ" على الإعلانات.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسنًا'))],
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final rawFilename = await _scraper.saveToFiles();
      _scraper.clearSession();
      
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => RefinementScreen(rawFilename: rawFilename)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحفظ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fb Explorer Fyras', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1877F2),
        actions: [
          IconButton(icon: const Icon(Icons.person), onPressed: () => Scaffold.of(context).openEndDrawer()),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('تأكيد الإغلاق'),
                content: const Text('هل تريد إغلاق التطبيق؟'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () {
                      Navigator.pop(context);
                      SystemNavigator.pop();
                    },
                    child: const Text('إغلاق', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      endDrawer: AccountDrawer(
        onAccountSelected: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اختر رابط مجموعة أو صفحة لبدء الجمع'), duration: Duration(seconds: 3)),
        ),
        onAddAccount: _showAddAccountDialog,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(hintText: 'الصق رابط فيسبوك هنا...', border: OutlineInputBorder()),
                    onSubmitted: _loadUrl,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.open_in_browser, size: 20),
                  label: const Text('فتح'),
                  onPressed: () => _loadUrl(_urlController.text),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Chip(avatar: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.check, size: 14)), label: Text('${_scraper.postCount}')),
                const SizedBox(width: 12),
                Chip(avatar: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.text_fields, size: 14)), label: Text('${_scraper.calculateTotalWords()} كلمة')),
                const Spacer(),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save_alt, size: 20),
                  label: const Text('حفظ الملف الخام'),
                  onPressed: _saveRawFileAndOpenRefinement,
                ),
              ],
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(
            child: WebView(
              initialUrl: _urlController.text,
              javascriptMode: JavascriptMode.unrestricted,
              navigationDelegate: (NavigationRequest request) {
                // 🛡️ تقييد النطاقات للأمان (تم إزالة localhost)
                if (request.url.startsWith('https://www.facebook.com') ||
                    request.url.startsWith('https://m.facebook.com') ||
                    request.url.startsWith('https://facebook.com')) {
                  return NavigationDecision.navigate;
                }
                return NavigationDecision.prevent;
              },
              onWebViewCreated: (WebViewController controller) {
                _webViewController = controller;
                controller.addJavaScriptChannel(
                  'FlutterApp',
                  onMessageReceived: (JavaScriptMessage message) {
                    _handleJavaScriptMessage(message.message);
                  },
                );
              },
              onPageFinished: (String url) {
                if (_urlController.text != url) _urlController.text = url;
                _injectJavaScript();
                if (_isLoading) setState(() => _isLoading = false);
              },
              onPageStarted: (String url) => setState(() => _isLoading = true),
              onWebResourceError: (WebResourceError error) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('خطأ في التحميل: ${error.description}'), backgroundColor: Colors.red),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _loadUrl(String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال رابط'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    // 🔍 فحص اتصال الإنترنت أولاً
    final hasConnection = await _checkInternetConnection();
    if (!hasConnection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد اتصال بالإنترنت. يرجى التحقق من اتصالك.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    String formattedUrl = url;
    if (!formattedUrl.startsWith('http')) {
      formattedUrl = 'https://$formattedUrl';
    }
    
    setState(() {
      _isLoading = true;
      _urlController.text = formattedUrl;
    });
    
    try {
      await _webViewController.loadUrl(formattedUrl);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل الرابط: $e'), backgroundColor: Colors.red),
      );
    }
  }
  
  void _handleJavaScriptMessage(String message) {
    try {
      if (message.startsWith('REMOVE:')) {
        final postUrl = message.substring(7);
        _scraper.removePost(postUrl);
        if (mounted) setState(() {});
      } else if (message == 'LOGIN_SUCCESS') {
        print('✅ تسجيل دخول ناجح');
      } else {
        final data = jsonDecode(message) as Map<String, dynamic>;
        if (data.containsKey('original_text') && data.containsKey('original_post_url')) {
          final post = ScrapedPost(
            originalText: data['original_text'] as String,
            originalAuthor: data['original_author'] as String? ?? 'ناشر مجهول',
            authorProfileUrl: data['author_profile_url'] as String? ?? '',
            contactInfo: data['contact_info'] as String? ?? '',
            originalPostUrl: data['original_post_url'] as String,
            sharedFromUrl: data['shared_from_url'] as String?,
            scrapedAt: data['scraped_at'] as String? ?? DateTime.now().toIso8601String(),
            mediaCount: (data['media_count'] as num?)?.toInt() ?? 0,
          );
          _scraper.addPost(post);
          if (mounted) setState(() {});
        }
      }
    } catch (e) {
      print('❌ خطأ في معالجة رسالة JavaScript: $e');
    }
  }
}

// ===================================================================
// 🚀 نقطة الدخول الرئيسية
// ===================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🚀 بدء تشغيل Fb Explorer Fyras...');
  
  try {
    final directory = await getExternalStorageDirectory();
    final appDir = Directory('${directory!.path}/منصّة الإعلانات');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
      print('📁 تم إنشاء مجلد التطبيق');
    }
    
    // التحقق من وجود ملف الموجه
    final promptFile = File('${appDir.path}/ai_prompt.txt');
    if (!await promptFile.exists()) {
      final scraper = ScraperService();
      await scraper.loadAIPrompt(); // سينسخ الملف من assets
    }
  } catch (e) {
    print('⚠️ خطأ في تهيئة التطبيق: $e');
  }
  
  runApp(const MyApp());
}

/// 🎨 التطبيق الرئيسي
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fb Explorer Fyras',
      theme: ThemeData(
        primaryColor: const Color(0xFF1877F2),
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          color: Color(0xFF1877F2),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1877F2),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
    );
  }
}

// ===================================================================
// 🏁 نهاية ملف main.dart
// ===================================================================


