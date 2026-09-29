import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'language_service.dart';
import 'translation_service.dart';

const quizBrand = Color(0xFF0B6B5C);

class QuizQuestion {
  final int id, level;
  final String question, source;
  final List<Map<String,dynamic>> answers;
  const QuizQuestion({required this.id,required this.question,required this.level,required this.source,required this.answers});
  factory QuizQuestion.fromJson(Map<String,dynamic> j)=>QuizQuestion(
    id:(j['id'] as num?)?.toInt()??0,
    question:(j['q']??'').toString(),
    level:(j['level'] as num?)?.toInt()??1,
    source:(j['link']??'').toString(),
    answers:List<Map<String,dynamic>>.from((j['answers'] as List? ?? const[]).map((e)=>Map<String,dynamic>.from(e as Map))),
  );
}
class IslamicQuizService {
  static const database='https://raw.githubusercontent.com/rn0x/IslamicQuizAPI/main/database/database.json';
  Future<List<QuizQuestion>> loadAll()async{
    final r=await http.get(Uri.parse(database)).timeout(const Duration(seconds:30));
    if(r.statusCode!=200)throw Exception('Soru bankası alınamadı');
    final d=jsonDecode(utf8.decode(r.bodyBytes));
    final raw=<Map<String,dynamic>>[];
    void collect(dynamic node){
      if(node is Map){
        final m=Map<String,dynamic>.from(node);
        if(m['q']!=null && m['answers'] is List){raw.add(m);return;}
        for(final v in m.values){collect(v);}
      }else if(node is List){for(final v in node){collect(v);}}
    }
    collect(d);
    if(raw.isEmpty)throw Exception('Soru bankası boş döndü');
    final rows=raw.map(QuizQuestion.fromJson).where((q)=>q.question.isNotEmpty&&q.answers.length>=2).toList();
    rows.sort((a,b){final x=a.level.compareTo(b.level);return x!=0?x:a.id.compareTo(b.id);});
    return rows;
  }
  List<QuizQuestion> round(List<QuizQuestion> all,int roundNo){
    if(all.isEmpty)return const[];
    final level=roundNo<4?1:(roundNo<8?2:3);
    var pool=all.where((q)=>q.level==level).toList();
    if(pool.length<10)pool=all;
    pool.shuffle(Random());
    return pool.take(10).toList();
  }
}
class IslamicQuizScreen extends StatefulWidget{const IslamicQuizScreen({super.key});@override State<IslamicQuizScreen> createState()=>_IslamicQuizScreenState();}
class _IslamicQuizScreenState extends State<IslamicQuizScreen>{
  final service=IslamicQuizService();List<QuizQuestion> all=const[],questions=const[];bool loading=true,answered=false;String? error;int roundNo=1,index=0,score=0;int? selected;String translatedQuestion='';List<String> translatedAnswers=const[];
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{try{all=await service.loadAll();_startRound();await _translateCurrent();}catch(e){if(mounted)setState((){error=e.toString();loading=false;});}}
  void _startRound(){questions=service.round(all,roundNo);index=0;score=0;selected=null;answered=false;if(mounted)setState(()=>loading=false);}
  Future<void> _translateCurrent()async{if(questions.isEmpty)return;final q=questions[index];final tq=await TranslationService.translate(q.question,from:'ar',to:appLanguage.code);final ta=<String>[];for(final a in q.answers){ta.add(await TranslationService.translate((a['answer']??'').toString(),from:'ar',to:appLanguage.code));}if(mounted)setState((){translatedQuestion=tq;translatedAnswers=ta;});}
  void _answer(int i){if(answered)return;final ok=questions[index].answers[i]['t']==1;setState((){selected=i;answered=true;if(ok)score++;});}
  void _next(){if(index+1>=questions.length){_result();return;}setState((){index++;selected=null;answered=false;translatedQuestion='';translatedAnswers=const[];});_translateCurrent();}
  Future<void> _result()async{final next=await showDialog<bool>(context:context,barrierDismissible:false,builder:(c)=>AlertDialog(title:const Text('Tur tamamlandı'),content:Text('10 soruda '+score.toString()+' doğru.\\n\\nSonraki turda zorluk kademeli olarak artar.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Çık')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Sonraki tur'))]));if(!mounted)return;if(next==true){roundNo++;_startRound();}else{Navigator.pop(context);}}
  @override Widget build(BuildContext context){
    if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    if(error!=null||questions.isEmpty)return Scaffold(appBar:AppBar(title:Text(tr('İslami Bilgi Yarışması')+' • '+AppLanguage.supported[appLanguage.code]!)),body:Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.cloud_off,size:48),const SizedBox(height:12),Text(error??tr('Soru bulunamadı'),textAlign:TextAlign.center),const SizedBox(height:12),FilledButton(onPressed:(){setState((){loading=true;error=null;});_load();},child:Text(tr('Tekrar dene')))]))));
    final q=questions[index];
    return Scaffold(appBar:AppBar(title:Text('İslami Bilgi Yarışması • '+AppLanguage.supported[appLanguage.code]!)),body:ListView(padding:const EdgeInsets.all(20),children:[
      Row(children:[Text('Tur '+roundNo.toString(),style:const TextStyle(fontWeight:FontWeight.w800)),const Spacer(),Text((index+1).toString()+'/10 • '+score.toString()+' puan')]),
      const SizedBox(height:10),LinearProgressIndicator(value:(index+1)/10),const SizedBox(height:24),
      Text('Seviye '+q.level.toString(),style:const TextStyle(color:quizBrand,fontWeight:FontWeight.w700)),const SizedBox(height:8),
      Text(q.question,textDirection:TextDirection.rtl,textAlign:TextAlign.right,style:const TextStyle(fontSize:23,height:1.5,fontWeight:FontWeight.w700)),if(translatedQuestion.isNotEmpty&&translatedQuestion!=q.question)...[const SizedBox(height:10),Text(translatedQuestion,style:const TextStyle(fontSize:17,height:1.45))],const SizedBox(height:20),
      ...List.generate(q.answers.length,(i){final a=q.answers[i],correct=a['t']==1;Color? bg;if(answered&&correct)bg=Colors.green.withOpacity(.15);if(answered&&selected==i&&!correct)bg=Colors.red.withOpacity(.15);return Card(color:bg,child:ListTile(onTap:()=>_answer(i),title:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text((a['answer']??'').toString(),textDirection:TextDirection.rtl,textAlign:TextAlign.right),if(i<translatedAnswers.length&&translatedAnswers[i]!=(a['answer']??'').toString())Text(translatedAnswers[i],style:const TextStyle(fontSize:13))]),trailing:answered&&correct?const Icon(Icons.check_circle,color:Colors.green):null));}),
      if(answered)...[const SizedBox(height:14),FilledButton(onPressed:_next,child:Text(index==9?'Turu bitir':'Sonraki soru'))],
      const SizedBox(height:18),Text('Sorular kaynak dilinde gösterilir • Uygulama dili: '+AppLanguage.supported[appLanguage.code]!+' • 5.820 soruluk IslamicQuizAPI • Dorar',style:Theme.of(context).textTheme.bodySmall,textAlign:TextAlign.center),
    ]));
  }
}
