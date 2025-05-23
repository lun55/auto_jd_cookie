import 'package:flutter/material.dart';
import 'package:auto_jd_cookie/account_service.dart';

// 账户管理页面
class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _serverUrlController = TextEditingController();
  bool _isEditingServerUrl = false;
  List<Account> _accounts = [];// 用户列表
  bool _isEditing = false;
  int _editingIndex = -1;

 @override
  void initState() {
    super.initState(); // 初始化
    _loadServerUrl();
    Future.delayed(Duration.zero, () => _loadAccounts()); // 延迟初始化
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  // 异步方法
  Future<void> _loadAccounts() async {
    try {
      final accounts = await AccountService.getAccounts(); // 改同步等待暂停当前函数的执行，直到getAccounts()返回的Future<List<Account>>完成
      if (mounted) setState(() => _accounts = accounts);
    } catch (e) {
      if (mounted) setState(() => e.toString());
    }
  }
  // 加载服务器地址
  Future<void> _loadServerUrl() async {
    final url = await ConfigService.getServerUrl();
    setState(() => _serverUrlController.text = url);
  }
  // 修改服务器地址
  Future<void> _saveServerUrl() async {
    await ConfigService.saveServerUrl(_serverUrlController.text);
    setState(() => _isEditingServerUrl = false);
    AccountService.showToast('服务器地址已保存');
  }

  // 保存或者更新账号
  void _addOrUpdateAccount() async  {
    if (_formKey.currentState!.validate()) {
      final newAccount = Account(
        username: _usernameController.text,
        password: _passwordController.text,
      );
      await AccountService.saveAccount(newAccount);
      
      setState(() {
        if (_isEditing) {
          _accounts[_editingIndex] = newAccount;
        } else {
          _accounts.add(newAccount);
        }
        _resetForm();
      });
    }
  }

  // 编辑账号
  void _editAccount(int index) {
    setState(() {
      _isEditing = true;
      _editingIndex = index;
      _usernameController.text = _accounts[index].username;
      _passwordController.text = _accounts[index].password;
    });
  }

  // 删除账号
  void _deleteAccount(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                String username = _accounts[index].username;
                _accounts.removeAt(index);
                AccountService.deleteAccount(username);
                Navigator.pop(ctx);
              });
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _usernameController.clear();
    _passwordController.clear();
    setState(() {
      _isEditing = false;
      _editingIndex = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账号密码管理'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _resetForm,
            ),
        ],

      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 表单区域
            // 新增服务器地址配置卡片
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '服务器配置',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _serverUrlController,
                      decoration: const InputDecoration(
                        labelText: '服务器地址',
                        prefixIcon: Icon(Icons.cloud),
                        border: OutlineInputBorder(),
                      ),
                      enabled: _isEditingServerUrl,
                      validator: (value) => 
                          Uri.tryParse(value ?? '')?.hasAbsolutePath ?? false 
                              ? null 
                              : '请输入有效URL',
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _isEditingServerUrl
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isEditingServerUrl = false;
                                      _serverUrlController.text = '';
                                      _loadServerUrl();
                                    });
                                  },
                                  child: const Text('取消'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _saveServerUrl,
                                  child: const Text('保存'),
                                ),
                              ],
                            )
                          : TextButton(
                              onPressed: () => setState(() => _isEditingServerUrl = true),
                              child: const Text('修改地址'),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: '京东账号(手机号)',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) =>
                            value?.isEmpty ?? true ? '请输入账号' : null,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: '密码',
                          prefixIcon: Icon(Icons.lock),
                        ),
                        obscureText: true,
                        validator: (value) =>
                            value?.isEmpty ?? true ? '请输入密码' : null,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _addOrUpdateAccount,
                          child: Text(_isEditing ? '更新账号' : '添加账号'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // 账号列表
            if (_accounts.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '已保存账号',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _accounts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) => ListTile(
                  leading: const Icon(Icons.account_circle, size: 32),
                  title: Text(_accounts[index].username),
                  subtitle: const Text('********'), // 固定显示8个星号
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _editAccount(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                        onPressed: () => _deleteAccount(index),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
