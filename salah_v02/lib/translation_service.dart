import 'dart:convert';
import 'package:http/http.dart' as http;
class TranslationService{
 static final Map<String,String> _cache={};
 static Future<String> translate(String text,{required String from,required String to})async{
  if(text.trim().isEmpty||from==to)return text;final key=from+'>'+to+':'+text;if(_cache.containsKey(key))return _cache[key]!;
  try{final uri=Uri.https('api.mymemory.translated.net','/get',{'q':text,'langpair':from+'|'+to});final r=await http.get(uri).timeout(const Duration(seconds:15));if(r.statusCode==200){final j=jsonDecode(utf8.decode(r.bodyBytes));final x=(j['responseData']?['translatedText']??'').toString();if(x.isNotEmpty){_cache[key]=x;return x;}}}catch(_){}
  return text;
 }
}
