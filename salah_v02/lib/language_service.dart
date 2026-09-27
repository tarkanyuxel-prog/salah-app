import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
class AppLanguage extends ChangeNotifier {
 static const supported=<String,String>{'tr':'Türkçe','en':'English','ar':'العربية','de':'Deutsch','fr':'Français','es':'Español','id':'Bahasa Indonesia','ru':'Русский','ur':'اردو','bn':'বাংলা','hi':'हिन्दी','ms':'Bahasa Melayu'};
 String code='tr';
 Future<void> restore()async{final p=await SharedPreferences.getInstance();code=p.getString('app_language')??'tr';if(!supported.containsKey(code))code='tr';notifyListeners();}
 Future<void> setCode(String v)async{if(!supported.containsKey(v))return;code=v;final p=await SharedPreferences.getInstance();await p.setString('app_language',v);notifyListeners();}
}
final appLanguage=AppLanguage();
