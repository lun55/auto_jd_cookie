import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
class Account {
  final String username;
  final String password;

  Account({required this.username, required this.password});

  Map<String, dynamic> toJson() => {
    'username': username,
    'password': password,
  };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    username: json['username'],
    password: json['password'],
  );
}

enum StorageKeys {
  savedAccounts('saved_accounts'),
  selectedAccounts('selected_accounts');

  final String value;
  const StorageKeys(this.value);
}

class AccountService {

  static Future<List<Account>> getAccounts({String? key}) async {
    final _key = key ?? StorageKeys.savedAccounts.value;
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getStringList(_key) ?? [];
    return accountsJson.map((json) => Account.fromJson(jsonDecode(json))).toList();
  }

  /// 保存或更新账号
  static Future<void> saveAccount(Account account,{String? key}) async {
    final _key = key ?? StorageKeys.savedAccounts.value;
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAccounts(key: _key);
    
    // 查找是否已存在相同用户名的账号
    final existingIndex = accounts.indexWhere((a) => a.username == account.username);
    
    if (existingIndex >= 0) {
      // 更新已有账号
      accounts[existingIndex] = account;
    } else {
      // 添加新账号
      accounts.add(account);
    }
    
    // 保存更新后的列表
    final accountsJson = accounts.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(_key, accountsJson);
  }

  /// 保存账号
  static Future<void> saveSelectedAccount(Account? account) async {
    if(account==null){
      showToast('获取当前账户失败',isError: true);
     return;
    }
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAccounts(key: StorageKeys.selectedAccounts.value);
    if(accounts.length==0){
      accounts.add(account);
    }
    else{
      // 直接覆盖
    accounts[0] = account;
    }
    
    // 保存更新后的列表
    final accountsJson = accounts.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(StorageKeys.selectedAccounts.value, accountsJson);
  }

  // Future 用于保存异步操作的结果
  static Future<void> deleteAccount(String username, {String? key}) async {
    final _key = key ?? StorageKeys.savedAccounts.value;
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAccounts();
    accounts.removeWhere((a) => a.username == username);
    final accountsJson = accounts.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(_key, accountsJson);
  }

   static void showToast (String msg, {bool isError = true}) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: isError ? Colors.red[700]! : Colors.green[700]!,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }
}


class ConfigService {
  static const _prefsKey = 'server_config';
  
  static Future<String> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey) ?? '';
  }

  static Future<void> saveServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, url);
  }
}

