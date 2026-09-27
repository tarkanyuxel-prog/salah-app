import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'language_service.dart';
class HadithItem{final String text,reference,grade;const HadithItem(this.text,this.reference,this.grade);}
class GlobalHadithService{
 static const root='https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1';
 static const langs=<String,String>{'tr':'tur','en':'eng','ar':'ara','de':'ger','fr':'fre','es':'spa','id':'ind','ru':'rus','ur':'urd','bn':'ben','hi':'hin'};
 Future<List<HadithItem>> load({String book='bukhari',int limit=40})async{
  final lang=langs[appLanguage.code]??'eng';
  Future<dynamic> get(String l)async{final u=root+'/editions/'+l+'-'+book+'.min.json';final res=await http.get(Uri.parse(u)).timeout(const Duration(seconds:25));if(res.statusCode!=200)throw Exception('Hadis kaynağı '+res.statusCode.toString());return jsonDecode(utf8.decode(res.bodyBytes));}
  dynamic j;try{j=await get(lang);}catch(_){j=await get('eng');}
  final raw=(j is Map?(j['hadiths']??j['data']):j) as List? ?? const[];
  final rows=raw.whereType<Map>().map((x){final m=Map<String,dynamic>.from(x);return HadithItem((m['text']??m['hadith']??'').toString(),(m['reference']??m['hadithnumber']??'').toString(),(m['grades']??m['grade']??'').toString());}).where((x)=>x.text.isNotEmpty).toList();
  rows.shuffle(Random());return rows.take(limit).toList();
 }
}
class DuaItem{final String arabic,translation,source,title;const DuaItem({required this.arabic,required this.translation,required this.source,required this.title});}
class DuaService{
 static const url='https://raw.githubusercontent.com/sehalhussain/Hadith-Dua-assets/main/duas-adhkar-hisnul-muslim.json';
 Future<List<DuaItem>> load()async{
  final res=await http.get(Uri.parse(url)).timeout(const Duration(seconds:25));if(res.statusCode!=200)throw Exception('Dua kaynağı '+res.statusCode.toString());
  final j=jsonDecode(utf8.decode(res.bodyBytes));final out=<DuaItem>[];
  final segments=(j is Map?j['segments']:null) as List? ?? const[];
  for(final s in segments.whereType<Map>()){for(final c in ((s['categories'] as List?)??const[]).whereType<Map>()){for(final t in ((c['titles'] as List?)??const[]).whereType<Map>()){for(final d in ((t['duas'] as List?)??const[]).whereType<Map>()){out.add(DuaItem(arabic:(d['arabic']??'').toString(),translation:(d['translation']??'').toString(),source:(d['source']??'').toString(),title:(t['title_name']??c['category_name']??'Dua').toString()));}}}}
  return out;
 }
}
