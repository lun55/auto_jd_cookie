import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:clipboard/clipboard.dart';
import 'package:auto_jd_cookie/pages/setting_page.dart';
import 'package:auto_jd_cookie/account_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:logger/logger.dart';

// 京东登录页面
class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});
  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late InAppWebViewController _controller;
  String _cookie = '';
  List<String> logMessages = [];
  bool _isLoading = true;
  final logger = Logger();
  // 京东标签页
  final webUri = WebUri('https://plogin.m.jd.com/login/login');
  List<Account> _accounts = [];// 用户列表
  Account? _selectedAccount; // 当前选中的账号
  String _error = "";
 @override
  void initState() {
    super.initState(); // 初始化
   _loadAccounts(); // 延迟初始化
  }
  // 异步方法
  Future<void> _loadAccounts() async {
    try {
      final accounts = await AccountService.getAccounts();
      if (mounted) {
        setState(() {
          _accounts = accounts;
          if (_accounts.isNotEmpty) {
            _selectedAccount = _accounts.first; // 默认选中第一个账号
            AccountService.saveSelectedAccount(_selectedAccount); // 保存当前账户
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  // 填充账号密码
  // 填充账号密码（完整Flutter实现）
  Future<void> _autoFillLoginForm() async {
    // 检查状态有效性
    if (_selectedAccount == null || !mounted) return;

    try {
      // 安全转义特殊字符（防止XSS和JS语法错误）
      String escapeJsString(String input) {
        if (input.isEmpty) return '';
        return input
            .replaceAll(r'\', r'\\')
            .replaceAll("'", r"\'")
            .replaceAll('"', r'\"')
            .replaceAll('\n', r'\n')
            .replaceAll('\r', r'\r');
      }

      // 等待页面稳定（增加DOM加载检查）
      bool isDomReady = false;
      for (int i = 0; i < 3 && !isDomReady; i++) {
        isDomReady = await _controller.evaluateJavascript(source: """
          !!(
            document.querySelector('input.acc-input.mobile.J_ping') || 
            document.getElementById('username')
          )
        """) == true;
        
        if (!isDomReady) await Future.delayed(const Duration(milliseconds: 500));
      }

      if (!isDomReady) {
        debugPrint('登录表单元素未加载完成');
        return;
      }

      final escapedUsername = escapeJsString(_selectedAccount!.username);
      final escapedPassword = escapeJsString(_selectedAccount!.password);

      final jsCode = """
      (function() {
        try {
          const phone = '$escapedUsername';
          const password = '$escapedPassword';

          // 1. 手机号输入框优先
          const phoneInput = document.querySelector('input.acc-input.mobile.J_ping');
          if (phoneInput) {
            phoneInput.value = phone;
            phoneInput.dispatchEvent(new Event('input', { bubbles: true }));
          }

          // 2. 如果是账号登录页，填充账号名
          const usernameInput = document.querySelector('#username');
          if (usernameInput) {
            usernameInput.value = phone;
            usernameInput.dispatchEvent(new Event('input', { bubbles: true }));
          }

          // 3. 填充密码字段
          const pwdFields = [
            document.getElementById('pwd'),
            document.getElementById('password'),
            document.querySelector('input[name="nloginpwd"]')
          ].filter(f => f !== null);

          pwdFields.forEach(field => {
            field.value = password;
            field.dispatchEvent(new Event('input', { bubbles: true }));
          });

          // 4. 勾选协议（如果存在）
          const agreement = document.querySelector('.policy_tip-checkbox, .protocol-checkbox');
          if (agreement && !agreement.checked) {
            agreement.click();
          }

          // // 5. 自动点击登录按钮（如果存在）
          // const loginBtn = document.querySelector('#app > div > a, .btn-login');
          // if (loginBtn) {
          //   setTimeout(() => loginBtn.click(), 300);
          // }

          return true;
        } catch (e) {
          console.error('自动填充失败:', e);
          return false;
        }
      })()
      """;

      // 执行JavaScript并验证结果
      final result = await _controller.evaluateJavascript(source: jsCode);
      if (result != true) {
        debugPrint('自动填充执行异常');
      }

    } catch (e) {
      debugPrint('自动填充异常: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('自动填充失败'),
            action: SnackBarAction(
              label: '重试',
              onPressed: _autoFillLoginForm,
            ),
          ),
        );
      }
    }
  }

  Future<void> _clickAccountLogin() async {
    await Future.delayed(const Duration(seconds: 1));

    // 执行JavaScript代码点击元素
    try{
          await _controller.evaluateJavascript(source: """
      // 通过class选择器定位元素
      const btn = document.querySelector('.J_ping.planBLogin');
      if (btn) {
        btn.click();
        console.log('账号密码登录按钮已触发');
      } else {
        console.error('未找到登录按钮元素');
      }
    """); 
    }
    catch(e){
        logger.e("点击账号登录失败: $e");
    }

  }
  @override
  Widget build(BuildContext context) {
    if (_error.isNotEmpty) {
      return Text('Error: $_error');
    } 
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Expanded(
              child: Text(
                '京东Cookie助手',
                overflow: TextOverflow.ellipsis, // 如果空间不足就显示省略号
              ),
            ),
          ],
        ),
        iconTheme: IconThemeData(color: Colors.black), // 强制图标为黑色
        
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              logger.i('刷新');
              _controller.reload();
              setState(() {
                _cookie = '';
                _isLoading = true;
              });
            },
          ),
          PopupMenuButton<Account>(
            icon: const Icon(Icons.account_circle),
            itemBuilder: (context) => _accounts.map((account) {
              return PopupMenuItem<Account>(
                value: account,
                child: Text(account.username),
              );
            }).toList(),
            onSelected: (account) async {
              await _loadAccounts(); // 重新加载账号列表（例如从数据库/远程接口）
              setState(() {
                _selectedAccount = account;
                AccountService.saveAccount(account);
              });
              _autoFillLoginForm(); // 重新填充表单
            },
          ),
          IconButton(
            icon: const Icon(Icons.cookie),
            onPressed: _showCookieDialog,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const SettingPage(),
                  ),
          ),
        ],
      ),
      body:Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                  InAppWebView(
                    initialUrlRequest:
                        URLRequest(url: webUri),
                    onWebViewCreated: (controller) {
                      _controller = controller;
                      logger.i('开始加载controller');
                    },
                    onLoadStart: (controller, url) {
                      logger.i('开始加载: $url');
                      setState(() {
                        _isLoading = true;
                      });
                    },
                    onLoadStop: (controller, url) async {
                      logger.i('加载完成: $url');
                      try {
                            if (url != null && url.toString().contains('home.m.jd.com')) {
                              logger.i('进入主页，提取Cookie');
                              await _fetchCookies(url); // 登录成功，提取 Cookie
                            } else {
                              logger.i('尚未登录，自动填充');
                              await _clickAccountLogin(); // 自动跳转账号登录页面
                              await _autoFillLoginForm(); // 自动填充账号密码
                            }
                      } catch (e) {
                        logger.e("页面加载失败: $e");
                      } finally {
                        setState(() => _isLoading = false); // 确保一定执行
                      }
                    },
                    shouldOverrideUrlLoading: (controller, navigationAction) async {
                      final url = navigationAction.request.url.toString();
                      if (url.contains('home.m.jd.com')) {
                        final uri = navigationAction.request.url;
                        if (uri != null) {
                          await _fetchCookies(uri);
                        }
                        return NavigationActionPolicy.CANCEL;
                      }
                      return NavigationActionPolicy.ALLOW;
                    },
                  ),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ), 
            // // 新增的日志显示区域
            // _buildLogPanel(),
          ]
        ),
        // 发送按钮
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.red,
          child: Transform.rotate(
            angle: -1.5708, // -90度，单位是弧度（π/2 ≈ 1.5708）
            child: const Icon(Icons.send),
          ),  
          onPressed: () async {
            final currentUrl = await _controller.getUrl(); // 获取当前页面 URL
            if (currentUrl != null) {
              await _fetchCookies(currentUrl); // 手动提取 Cookie
              if (_cookie.isNotEmpty) {
                await FlutterClipboard.copy(_cookie);
                final selectedAccounts = await AccountService.getAccounts(key: StorageKeys.selectedAccounts.value);
                await sendCookieToServer(
                  username: selectedAccounts.first.username,
                  cookie: _cookie,
                );
              }
            } else {
              AccountService.showToast('无法获取当前页面URL',isError: true);
            }
          },
        )

    );
  }
  // // 新增的日志面板构建方法
  // Widget _buildLogPanel() {
  //   return Container(
  //     height: 150, // 固定高度，可滚动
  //     color: Colors.grey[200],
  //     child: Column(
  //       children: [
  //         ListTile(
  //           title: Text('调试日志'),
  //           trailing: IconButton(
  //             icon: Icon(Icons.clear_all),
  //             onPressed: () => setState(() => logMessages.clear()),
  //           ),
  //         ),
  //         Expanded(
  //           child: ListView.builder(
  //             reverse: true, // 最新日志显示在最上面
  //             itemCount: logMessages.length,
  //             itemBuilder: (context, index) {
  //               return Padding(
  //                 padding: const EdgeInsets.symmetric(horizontal: 8.0),
  //                 child: Text(
  //                   logMessages[index],
  //                   style: TextStyle(fontFamily: 'monospace', fontSize: 12),
  //                 ),
  //               );
  //             },
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // void _addLogMessage(String message) {
  //   final timestamp = DateTime.now().toString().substring(11, 19);
  //   setState(() {
  //     logMessages.add('[$timestamp] $message');
  //     // 限制日志数量，避免内存问题
  //     if (logMessages.length > 100) {
  //       logMessages.removeAt(0);
  //     }
  //   });
  // }

  Future<void> _fetchCookies(WebUri url) async {
    try {
      final cookieManager = CookieManager.instance();
      final cookies = await cookieManager.getCookies(url: url);
      final cookieString =
          cookies.map((c) => '${c.name}=${c.value}').join('; ');
      // 验证并更新状态
      if (cookieString.contains('pt_key') && cookieString.contains('pt_pin')) {
        if (mounted) {
          setState(() {
            _cookie = extractPtKeyAndPtPin(cookieString);
          });
        }
      } else {
        if (mounted) {
          setState(() => _cookie = '');
          AccountService.showToast('未获取到完整Cookie，请重新登录',isError: true);
        }
      }
    } catch (e) {
      AccountService.showToast('获取Cookie失败: $e',isError: true);
      debugPrint('获取Cookie失败: $e');
    }
  }
  String  extractPtKeyAndPtPin(String cookieString) {
    final ptKeyRegex = RegExp(r'pt_key=([^;]+)');
    final ptPinRegex = RegExp(r'pt_pin=([^;]+)');

    final ptKeyMatch = ptKeyRegex.firstMatch(cookieString);
    final ptPinMatch = ptPinRegex.firstMatch(cookieString);

    if (ptKeyMatch != null && ptPinMatch != null) {
      final ptKey = ptKeyMatch.group(1);
      final ptPin = ptPinMatch.group(1);
      return 'pt_key=$ptKey;pt_pin=$ptPin;';
    }
    return "";
  }
  void _showCookieDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('获取的Cookie'),
        content: SingleChildScrollView(
          child: SelectableText(
            _cookie.isNotEmpty ? _cookie : '暂未获取到Cookie',
            style: const TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
          if (_cookie.isNotEmpty)
            TextButton(
              onPressed: () {
                FlutterClipboard.copy(_cookie);
                AccountService.showToast('Cookie已复制到剪贴板');
                Navigator.pop(ctx);
              },
              child: const Text('复制'),
            ),
        ],
      ),
    );
  }

  Future<void> sendCookieToServer({
    required String username,
    required String cookie,
  }) async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceName = 'Unknown';

      // 获取设备名（支持 Android 和 iOS）
      if (await deviceInfo.deviceInfo is AndroidDeviceInfo) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (await deviceInfo.deviceInfo is IosDeviceInfo) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = '${iosInfo.name} ${iosInfo.model}';
      }

      final timestamp = DateTime.now().toIso8601String();

      final body = jsonEncode({
        'userName': username,
        'device': deviceName,
        'timestamp': timestamp,
        'cookie': cookie,
      });
      logger.i(body);
      // 读取服务器地址
      final serverUrl = await ConfigService.getServerUrl();
      if(serverUrl.isEmpty){
        AccountService.showToast('请先填写服务器地址', isError: true);
      }
      final response = await http.post(
        Uri.parse(serverUrl),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

    if (response.statusCode != 200) {
        AccountService.showToast('发送失败，状态码: ${response.statusCode}', isError: true);
      // throw Exception('服务器返回异常状态码');
    }
    AccountService.showToast('Cookie发送成功');

    } catch (e) {
        AccountService.showToast('发送Cookie到服务器失败: $e', isError: true);
    }
  }

}
