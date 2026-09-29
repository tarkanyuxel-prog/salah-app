import 'dart:ui' as ui;
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'update_service.dart';
import 'islamic_quiz.dart';
import 'language_service.dart';
import 'islamic_content_service.dart';
import 'translation_service.dart';

const brand = Color(0xFF496E64);
const gold = Color(0xFFC6A66A);
const softSurface = Color(0xFFF5F7F5);
const softNav = Color(0xFFEAF0ED);
final notifications = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await initializeDateFormatting('tr_TR');
  await appLanguage.restore();
  await notifications.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  ));
  runApp(const SalahApp());
}

class SalahApp extends StatefulWidget { const SalahApp({super.key}); @override State<SalahApp> createState()=>_SalahAppState(); }
class _SalahAppState extends State<SalahApp> {
  ThemeMode mode=ThemeMode.system;
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:appLanguage,builder:(context,_)=>MaterialApp(
    debugShowCheckedModeBanner:false,title:'Salah',themeMode:mode,
    theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:brand,brightness:Brightness.light),scaffoldBackgroundColor:softSurface,navigationBarTheme:const NavigationBarThemeData(backgroundColor:softNav,indicatorColor:Color(0xFFD6E4DE),elevation:0),cardTheme:CardThemeData(color:const Color(0xFFFBFCFB),elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)))),
    darkTheme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:brand,brightness:Brightness.dark),scaffoldBackgroundColor:const Color(0xFF101A18),navigationBarTheme:const NavigationBarThemeData(backgroundColor:Color(0xFF172521),indicatorColor:Color(0xFF294039),elevation:0),cardTheme:CardThemeData(color:const Color(0xFF172521),elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)))),
    home:AppShell(onTheme:(v)=>setState(()=>mode=v)),
  ));
}

class PrayerData extends ChangeNotifier {
  Map<String,String> timings={}; String hijri='', timezone='', city='', status='Konum bekleniyor...'; bool loading=false; int method=13; Position? position;
  Map<String,bool> alerts={'İmsak':true,'Öğle':true,'İkindi':true,'Akşam':true,'Yatsı':true};
  final methods={13:'Diyanet',3:'Muslim World League',2:'ISNA',4:'Umm Al-Qura'};
  String clean(dynamic v)=>v.toString().split(' ').first;
  Future<Position> getPosition() async { if(!await Geolocator.isLocationServiceEnabled()) throw Exception('Konum servisini açın.'); var p=await Geolocator.checkPermission(); if(p==LocationPermission.denied)p=await Geolocator.requestPermission(); if(p==LocationPermission.denied||p==LocationPermission.deniedForever)throw Exception('Konum izni gerekli.'); return Geolocator.getCurrentPosition(); }
  Future<void> restore() async {final p=await SharedPreferences.getInstance();method=p.getInt('method')??13;for(final k in alerts.keys.toList()){alerts[k]=p.getBool('alert_$k')??true;}notifyListeners();}
  Future<void> load() async {loading=true;status='Vakitler alınıyor...';notifyListeners();try{position=await getPosition();try{final ps=await placemarkFromCoordinates(position!.latitude,position!.longitude);if(ps.isNotEmpty)city=[ps.first.locality,ps.first.administrativeArea,ps.first.country].whereType<String>().where((e)=>e.isNotEmpty).toSet().join(', ');}catch(_){}final ts=DateTime.now().millisecondsSinceEpoch~/1000;final uri=Uri.https('api.aladhan.com','/v1/timings/$ts',{'latitude':'${position!.latitude}','longitude':'${position!.longitude}','method':'$method'});final r=await http.get(uri).timeout(const Duration(seconds:15));if(r.statusCode!=200)throw Exception('Sunucu hatası (${r.statusCode})');final j=jsonDecode(r.body),d=j['data'],t=d['timings'];timings={'İmsak':clean(t['Fajr']),'Güneş':clean(t['Sunrise']),'Öğle':clean(t['Dhuhr']),'İkindi':clean(t['Asr']),'Akşam':clean(t['Maghrib']),'Yatsı':clean(t['Isha'])};hijri='${d['date']['hijri']['day']} ${d['date']['hijri']['month']['en']} ${d['date']['hijri']['year']}';timezone=d['meta']['timezone']??'';status='Güncel';await _save();await scheduleAlerts();await updateHomeWidget();}catch(e){status=e.toString().replaceFirst('Exception: ','');}loading=false;notifyListeners();}
  Future<List<Map<String,dynamic>>> ramadanCalendar() async {if(position==null)await load();if(position==null)return[];final now=DateTime.now();final uri=Uri.https('api.aladhan.com','/v1/calendar/${now.year}/${now.month}',{'latitude':'${position!.latitude}','longitude':'${position!.longitude}','method':'$method'});final r=await http.get(uri).timeout(const Duration(seconds:15));if(r.statusCode!=200)throw Exception('Ramazan takvimi alınamadı');final List raw=jsonDecode(r.body)['data'];return raw.map<Map<String,dynamic>>((x)=>{'date':x['date']['gregorian']['date'],'hijriDay':x['date']['hijri']['day'],'hijriMonth':x['date']['hijri']['month']['en'],'fajr':clean(x['timings']['Fajr']),'maghrib':clean(x['timings']['Maghrib'])}).toList();}
  Future<void> updateHomeWidget() async {
    if (timings.isEmpty) return;
    final now=DateTime.now();
    MapEntry<String,String>? next;
    for(final e in timings.entries){
      if(e.key=='Güneş') continue;
      final p=e.value.split(':');
      final t=DateTime(now.year,now.month,now.day,int.parse(p[0]),int.parse(p[1]));
      if(t.isAfter(now)){next=e;break;}
    }
    next ??= MapEntry('İmsak',timings['İmsak']??'--:--');
    final compact=timings.entries.map((e)=>'${e.key} ${e.value}').join('  •  ');
    try{
      const channel=MethodChannel('com.salah.app/prayer_widget');
      await channel.invokeMethod('updatePrayerWidget',{
        'city':city.isEmpty?'Salah':city,
        'nextName':next.key,
        'nextTime':next.value,
        'times':compact,
      });
    }catch(_){}
  }
  Future<void> _save()async{final p=await SharedPreferences.getInstance();await p.setInt('method',method);for(final e in alerts.entries){await p.setBool('alert_${e.key}',e.value);}}
  Future<void> setAlert(String k,bool v)async{alerts[k]=v;await _save();await scheduleAlerts();notifyListeners();}
  Future<void> scheduleAlerts()async{await notifications.cancelAll();if(timings.isEmpty)return;final android=notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();await android?.requestNotificationsPermission();var id=10;for(final e in timings.entries){if(e.key=='Güneş'||alerts[e.key]!=true)continue;final x=e.value.split(':');var when=DateTime.now();when=DateTime(when.year,when.month,when.day,int.parse(x[0]),int.parse(x[1]));if(!when.isAfter(DateTime.now()))continue;await notifications.zonedSchedule(id++,'${e.key} vakti','${e.key} vakti geldi.',tz.TZDateTime.from(when,tz.local),const NotificationDetails(android:AndroidNotificationDetails('prayer_times','Namaz Vakitleri',importance:Importance.high,priority:Priority.high),iOS:DarwinNotificationDetails()),androidScheduleMode:AndroidScheduleMode.inexactAllowWhileIdle,uiLocalNotificationDateInterpretation:UILocalNotificationDateInterpretation.absoluteTime);}}
  double? get qibla {if(position==null)return null;const kaLat=21.4225,kaLon=39.8262;final lat=position!.latitude*math.pi/180,dLon=(kaLon-position!.longitude)*math.pi/180,k=kaLat*math.pi/180;return(math.atan2(math.sin(dLon),math.cos(lat)*math.tan(k)-math.sin(lat)*math.cos(dLon))*180/math.pi+360)%360;}
}

class AppShell extends StatefulWidget {final ValueChanged<ThemeMode> onTheme;const AppShell({super.key,required this.onTheme});@override State<AppShell> createState()=>_AppShellState();}
class _AppShellState extends State<AppShell>{int index=0;final data=PrayerData();@override void initState(){super.initState();data.restore().then((_)=>data.load());WidgetsBinding.instance.addPostFrameCallback((_) {if(mounted) AppUpdater.check(context);});}@override void dispose(){data.dispose();super.dispose();}
 @override Widget build(BuildContext context){final pages=[HomeScreen(onOpen:(i)=>setState(()=>index=i),d:data),TimesScreen(d:data),QuranScreen(),DiscoverScreen(d:data),SettingsScreen(d:data,onTheme:widget.onTheme)];return Scaffold(body:SafeArea(child:IndexedStack(index:index,children:pages)),bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(v)=>setState(()=>index=v),destinations:[NavigationDestination(icon:const Icon(Icons.home_outlined),selectedIcon:const Icon(Icons.home),label:tr('Ana Sayfa')),NavigationDestination(icon:Icon(Icons.schedule_outlined),label:tr('Vakitler')),NavigationDestination(icon:Icon(Icons.menu_book_outlined),label:tr('Kur’an')),NavigationDestination(icon:Icon(Icons.grid_view_rounded),label:tr('Keşfet')),NavigationDestination(icon:Icon(Icons.settings_outlined),label:tr('Ayarlar'))]));}}

class HomeScreen extends StatefulWidget {
  final PrayerData d;
  final ValueChanged<int> onOpen;

  const HomeScreen({
    super.key,
    required this.d,
    required this.onOpen,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? timer;
  DateTime now = DateTime.now();

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  MapEntry<String, String>? get next {
    for (final e in widget.d.timings.entries) {
      if (e.key == 'Güneş') continue;

      final parts = e.value.split(':');
      final prayerTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );

      if (prayerTime.isAfter(now)) {
        return e;
      }
    }

    if (widget.d.timings.isEmpty) return null;

    return MapEntry(
      'İmsak',
      widget.d.timings['İmsak']!,
    );
  }

  String get left {
    final e = next;
    if (e == null) return '--:--:--';

    final parts = e.value.split(':');

    var target = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );

    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }

    final diff = target.difference(now);

    return '${diff.inHours.toString().padLeft(2, '0')}:'
        '${(diff.inMinutes % 60).toString().padLeft(2, '0')}:'
        '${(diff.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.d,
      builder: (context, _) {
        return RefreshIndicator(
          onRefresh: widget.d.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            children: [
              const SalahBrandHeader(),
              const SizedBox(height: 14),

              Row(
                children: [
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: brand,
                    child: Icon(
                      Icons.mosque,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selamün Aleyküm',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          widget.d.city.isEmpty
                              ? 'Konum alınıyor…'
                              : widget.d.city,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.d.load,
                    icon: const Icon(Icons.my_location),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              PrayerHero(
                title: next?.key ?? 'Sonraki Namaz',
                time: next?.value ?? '--:--',
                left: left,
                hijri: widget.d.hijri,
              ),

              const SizedBox(height: 16),

              SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: widget.d.timings.entries.map((e) {
                    return Container(
                      width: 92,
                      margin: const EdgeInsets.only(right: 9),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            e.key == 'Güneş'
                                ? Icons.wb_sunny_outlined
                                : Icons.access_time_rounded,
                            color: e.key == next?.key ? gold : null,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            e.key,
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            e.value,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 22),
              SectionTitle(tr('Hızlı Erişim')),
              const SizedBox(height: 10),

              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  Quick(
                    icon: Icons.explore,
                    label: 'Kıble',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QiblaScreen(d: widget.d),
                      ),
                    ),
                  ),
                  Quick(
                    icon: Icons.menu_book,
                    label: 'Kur’an',
                    onTap: () => widget.onOpen(2),
                  ),
                  Quick(
                    icon: Icons.auto_stories,
                    label: 'Hadis',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HadithScreen(),
                      ),
                    ),
                  ),
                  Quick(
                    icon: Icons.radio_button_checked,
                    label: 'Zikir',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TasbihScreen(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RamadanScreen(d: widget.d),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF112E29),
                        Color(0xFF0B6B5C),
                      ],
                    ),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white12,
                        child: Icon(
                          Icons.nights_stay,
                          color: gold,
                        ),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ramazan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'İmsak • İftar • 30 günlük takvim',
                              style: TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),
              const SectionTitle('Günün Ayeti'),
              const SizedBox(height: 10),

              const InfoCard(
                icon: Icons.format_quote,
                title: 'Bakara 2:286',
                body:
                    'Allah hiç kimseye gücünün yeteceğinden fazlasını yüklemez.',
              ),

              const SizedBox(height: 12),
              const SectionTitle('Günün Hadisi'),
              const SizedBox(height: 10),

              const InfoCard(
                icon: Icons.auto_stories,
                title: 'Niyet',
                body:
                    'Ameller niyetlere göredir. Kaynak bilgisi hadis ekranında gösterilir.',
              ),
            ],
          ),
        );
      },
    );
  }
}

class PrayerHero extends StatelessWidget{final String title,time,left,hijri;const PrayerHero({super.key,required this.title,required this.time,required this.left,required this.hijri});@override Widget build(BuildContext c)=>Container(height:230,padding:const EdgeInsets.all(24),decoration:BoxDecoration(borderRadius:BorderRadius.circular(30),gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF0A3B34),Color(0xFF0B6B5C),Color(0xFF15977F)])),child:Stack(children:[Positioned(right:-8,bottom:-14,child:Icon(Icons.mosque,size:150,color:Colors.white.withOpacity(.10))),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(DateFormat('dd MMMM yyyy','tr').format(DateTime.now()),style:const TextStyle(color:Colors.white70)),if(hijri.isNotEmpty)Text(hijri,style:const TextStyle(color:Colors.white70)),const Spacer(),Text('$title • $time',style:const TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w800)),Text(left,style:const TextStyle(color:Colors.white,fontSize:42,fontWeight:FontWeight.w300)),const Text('kaldı',style:TextStyle(color:Colors.white70))])])) ;}
class SectionTitle extends StatelessWidget{final String t;const SectionTitle(this.t,{super.key});@override Widget build(BuildContext c)=>Text(t,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800));}
class Quick extends StatelessWidget{final IconData icon;final String label;final VoidCallback onTap;const Quick({super.key,required this.icon,required this.label,required this.onTap});@override Widget build(BuildContext c)=>InkWell(borderRadius:BorderRadius.circular(20),onTap:onTap,child:Container(decoration:BoxDecoration(color:Theme.of(c).cardColor,borderRadius:BorderRadius.circular(20)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,color:brand),const SizedBox(height:8),Text(label,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700))])));}
class InfoCard extends StatelessWidget{final IconData icon;final String title,body;const InfoCard({super.key,required this.icon,required this.title,required this.body});@override Widget build(BuildContext c)=>Card(child:Padding(padding:const EdgeInsets.all(18),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[CircleAvatar(backgroundColor:brand.withOpacity(.12),child:Icon(icon,color:brand)),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:6),Text(body)]))])));}

class TimesScreen extends StatelessWidget{final PrayerData d;const TimesScreen({super.key,required this.d});@override Widget build(BuildContext c)=>AnimatedBuilder(animation:d,builder:(c,_)=>(ListView(padding:const EdgeInsets.all(20),children:[const SalahBrandHeader(),const SizedBox(height:14),Text(tr('Namaz Vakitleri'),style:TextStyle(fontSize:28,fontWeight:FontWeight.w800)),Text(d.city.isEmpty?'Konuma göre':d.city),const SizedBox(height:18),...d.timings.entries.map((e)=>Card(child:ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:18,vertical:8),leading:CircleAvatar(backgroundColor:brand.withOpacity(.1),child:Icon(e.key=='Güneş'?Icons.wb_sunny_outlined:Icons.schedule,color:brand)),title:Text(e.key,style:const TextStyle(fontWeight:FontWeight.w700)),trailing:Text(e.value,style:const TextStyle(fontSize:23,fontWeight:FontWeight.w800))))),const SizedBox(height:12),FilledButton.icon(onPressed:d.load,icon:const Icon(Icons.my_location),label:const Text('Konumu ve vakitleri yenile'))])));}

class RamadanScreen extends StatefulWidget{final PrayerData d;const RamadanScreen({super.key,required this.d});@override State<RamadanScreen> createState()=>_RamadanScreenState();}
class _RamadanScreenState extends State<RamadanScreen>{late Future<List<Map<String,dynamic>>> future;@override void initState(){super.initState();future=widget.d.ramadanCalendar();}@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Ramazan')),body:FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(c,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(s.hasError)return Center(child:Text('${s.error}'));final rows=s.data??[];return ListView(padding:const EdgeInsets.all(18),children:[Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(borderRadius:BorderRadius.circular(28),gradient:const LinearGradient(colors:[Color(0xFF0A3B34),brand])),child:Column(children:[const Icon(Icons.nights_stay,color:gold,size:38),const SizedBox(height:8),Text(widget.d.city,style:const TextStyle(color:Colors.white70)),const Text('İmsak & İftar Takvimi',style:TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w800))])),const SizedBox(height:14),...rows.map((x)=>Card(child:ListTile(title:Text('${x['date']}  •  ${x['hijriDay']} ${x['hijriMonth']}'),subtitle:Text('İmsak  ${x['fajr']}'),trailing:Text('İftar  ${x['maghrib']}',style:const TextStyle(fontWeight:FontWeight.w800)))))]);})) ;}

class QiblaScreen extends StatelessWidget{final PrayerData d;const QiblaScreen({super.key,required this.d});@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Kıble')),body:AnimatedBuilder(animation:d,builder:(c,_)=>(Padding(padding:const EdgeInsets.all(20),child:Column(children:[Text(d.city,style:const TextStyle(fontSize:16)),const Spacer(),StreamBuilder<CompassEvent>(stream:FlutterCompass.events,builder:(c,s){final heading=s.data?.heading,q=d.qibla;if(heading==null||q==null)return const Text('Pusula sensörü bekleniyor…');final turn=(q-heading)*math.pi/180;return Column(children:[Container(width:270,height:270,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:brand,width:3)),child:Stack(alignment:Alignment.center,children:[const Positioned(top:14,child:Text('KÂBE',style:TextStyle(fontWeight:FontWeight.w900,color:gold))),Transform.rotate(angle:turn,child:const Icon(Icons.navigation,size:130,color:brand))])),const SizedBox(height:22),Text('Kıble ${q.toStringAsFixed(1)}°',style:const TextStyle(fontSize:24,fontWeight:FontWeight.w800)),Text('Telefon yönü ${heading.toStringAsFixed(0)}°')]);}),const Spacer(),const Text('Telefonu düz tutun. Gerekirse cihazı sekiz çizerek kalibre edin.',textAlign:TextAlign.center)])))));}

class QuranScreen extends StatefulWidget{const QuranScreen({super.key});@override State<QuranScreen> createState()=>_QuranScreenState();}
class _QuranScreenState extends State<QuranScreen>{final api=AlQuranCloudService();List<dynamic> chapters=[];List<dynamic> filtered=[];bool loading=true;String? error;@override void initState(){super.initState();_load();}Future<void> _load()async{try{chapters=await api.surahs();filtered=chapters;}catch(e){error='$e';}if(mounted)setState(()=>loading=false);}void _search(String q){final x=q.toLowerCase().trim();setState(()=>filtered=x.isEmpty?chapters:chapters.where((s)=>'${s['englishName']} ${s['name']} ${s['englishNameTranslation']}'.toLowerCase().contains(x)).toList());}
 @override Widget build(BuildContext c)=>Scaffold(body:ListView(padding:const EdgeInsets.all(20),children:[const SalahBrandHeader(),const SizedBox(height:14),const Text('Kur’an-ı Kerim',style:TextStyle(fontSize:28,fontWeight:FontWeight.w800)),const Text('Arapça • Türkçe meal • Sesli dinleme'),const SizedBox(height:16),TextField(onChanged:_search,decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:'Sure ara',filled:true,fillColor:Theme.of(c).cardColor,border:OutlineInputBorder(borderRadius:BorderRadius.circular(18),borderSide:BorderSide.none))),const SizedBox(height:16),if(loading)const Center(child:Padding(padding:EdgeInsets.all(30),child:CircularProgressIndicator()))else if(error!=null)QuranErrorCard(error:error!,retry:(){setState((){loading=true;error=null;});_load();})else...filtered.map((x)=>Card(child:ListTile(leading:CircleAvatar(backgroundColor:brand.withOpacity(.1),child:Text('${x['number']}',style:const TextStyle(color:brand))),title:Text(x['englishName']??''),subtitle:Text('${x['numberOfAyahs']??''} ayet • ${x['revelationType']??''}'),trailing:Text(x['name']??'',style:const TextStyle(fontSize:20)),onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>SurahScreen(api:api,chapter:x))))))]));}
class QuranErrorCard extends StatelessWidget{final String error;final VoidCallback retry;const QuranErrorCard({super.key,required this.error,required this.retry});@override Widget build(BuildContext c)=>Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(children:[const Icon(Icons.wifi_off,size:42,color:gold),const SizedBox(height:10),const Text('Kur’an servisine ulaşılamadı',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),const SizedBox(height:8),const Text('Al Quran Cloud bağlantısı için internet erişimini kontrol edin.',textAlign:TextAlign.center),const SizedBox(height:8),Text(error,textAlign:TextAlign.center,style:Theme.of(c).textTheme.bodySmall),const SizedBox(height:12),FilledButton.icon(onPressed:retry,icon:const Icon(Icons.refresh),label:const Text('Tekrar dene'))])));}
class SurahScreen extends StatefulWidget{final AlQuranCloudService api;final dynamic chapter;const SurahScreen({super.key,required this.api,required this.chapter});@override State<SurahScreen> createState()=>_SurahScreenState();}
class _SurahScreenState extends State<SurahScreen>{
 final player=AudioPlayer();late Future<List<Map<String,dynamic>>> future;final scroll=ScrollController();List<Map<String,dynamic>> verses=const[];List<GlobalKey> verseKeys=const[];String reciter='ar.alafasy';int bitrate=128;int? playingAyah;int activeWord=-1;bool playingSurah=false;
 final reciters=const{'ar.alafasy':'Mishary Alafasy','ar.husary':'Mahmoud Al-Husary','ar.minshawi':'Al-Minshawi','ar.sudais':'Abdul Rahman Al-Sudais','ar.shuraim':'Saud Al-Shuraim','ar.abdulbasit':'Abdul Basit'};
 @override void initState(){super.initState();future=widget.api.verses(widget.chapter['number']).then((v){verses=v;verseKeys=List.generate(v.length,(_)=>GlobalKey());return v;});player.currentIndexStream.listen((i){if(!playingSurah||i==null||i>=verses.length)return;final n=verses[i]['globalNumber'] as int;if(mounted)setState(()=>playingAyah=n);WidgetsBinding.instance.addPostFrameCallback((_){final ctx=verseKeys[i].currentContext;if(ctx!=null)Scrollable.ensureVisible(ctx,duration:const Duration(milliseconds:450),curve:Curves.easeOut,alignment:.18);});});player.playerStateStream.listen((s){if(s.processingState==ProcessingState.completed&&mounted)setState((){playingAyah=null;activeWord=-1;playingSurah=false;});});}
 @override void dispose(){scroll.dispose();player.dispose();super.dispose();}
 Future<void> _playAyah(Map<String,dynamic> v)async{final n=v['globalNumber'] as int;if(playingAyah==n&&player.playing){await player.pause();if(mounted)setState((){});return;}if(playingAyah==n&&!player.playing&&player.duration!=null){await player.play();if(mounted)setState((){});return;}playingSurah=false;await player.setUrl(widget.api.ayahAudio(n,reciter,bitrate));if(mounted)setState((){playingAyah=n;activeWord=-1;});await player.play();}
 Future<void> _playSurah()async{if(playingSurah&&player.playing){await player.pause();if(mounted)setState((){});return;}if(playingSurah&&!player.playing&&player.duration!=null){await player.play();if(mounted)setState((){});return;}final data=await future;if(data.isEmpty)return;final sources=data.map((v)=>AudioSource.uri(Uri.parse(widget.api.ayahAudio(v['globalNumber'] as int,reciter,bitrate)))).toList();await player.setAudioSource(ConcatenatingAudioSource(children:sources));playingSurah=true;if(mounted)setState(()=>playingAyah=data.first['globalNumber'] as int);await player.play();}
 Widget _syncedArabic(Map<String,dynamic> v,bool active){final text=(v['arabic']??'').toString();final words=text.split(RegExp(r'\\s+')).where((e)=>e.isNotEmpty).toList();if(!active||words.isEmpty)return Text(text,textDirection:ui.TextDirection.rtl,textAlign:TextAlign.right,style:const TextStyle(fontSize:27,height:1.8));return StreamBuilder<Duration>(stream:player.positionStream,builder:(c,p){final d=player.duration?.inMilliseconds??0;final pos=(p.data??Duration.zero).inMilliseconds;final wi=d<=0?0:((pos/d)*words.length).floor().clamp(0,words.length-1);return Text.rich(TextSpan(children:List.generate(words.length,(i)=>TextSpan(text:(i==0?'':' ')+words[i],style:TextStyle(color:i==wi?gold:null,fontWeight:i==wi?FontWeight.w900:FontWeight.normal)))),textDirection:ui.TextDirection.rtl,textAlign:TextAlign.right,style:const TextStyle(fontSize:27,height:1.8));});}
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:Text(widget.chapter['englishName']??'Sure')),body:Column(children:[Padding(padding:const EdgeInsets.fromLTRB(16,8,16,8),child:Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[Row(children:[Expanded(child:DropdownButtonFormField<String>(value:reciter,isExpanded:true,decoration:const InputDecoration(labelText:'Kâri',border:OutlineInputBorder()),items:reciters.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value,overflow:TextOverflow.ellipsis))).toList(),onChanged:(v){if(v!=null)setState(()=>reciter=v);})),const SizedBox(width:10),StreamBuilder<PlayerState>(stream:player.playerStateStream,builder:(c,s){final active=playingSurah&&player.playing;return FilledButton.icon(onPressed:_playSurah,icon:Icon(active?Icons.pause:Icons.play_arrow),label:Text(active?'Duraklat':'Sureyi dinle'));})]),const SizedBox(height:8),StreamBuilder<Duration>(stream:player.positionStream,builder:(c,s)=>LinearProgressIndicator(value:player.duration==null||player.duration!.inMilliseconds==0?0:((s.data??Duration.zero).inMilliseconds/player.duration!.inMilliseconds).clamp(0.0,1.0)))])))),Expanded(child:FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(c,s){if(!s.hasData){if(s.hasError)return Center(child:Text('${s.error}'));return const Center(child:CircularProgressIndicator());}return ListView.builder(controller:scroll,padding:const EdgeInsets.fromLTRB(16,4,16,20),itemCount:s.data!.length,itemBuilder:(c,i){final v=s.data![i],active=playingAyah==v['globalNumber'];return Card(key:verseKeys[i],child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Row(children:[CircleAvatar(radius:17,child:Text('${v['numberInSurah']}')),const Spacer(),IconButton(onPressed:()=>_playAyah(v),icon:Icon(active&&player.playing?Icons.pause_circle_filled:Icons.play_circle_fill,color:brand,size:36))]),_syncedArabic(v,active),const Divider(),Text(v['translation']??'',style:const TextStyle(height:1.5))])));});}))]));}
class AlQuranCloudService{static const api='https://api.alquran.cloud/v1';static const cdn='https://cdn.islamic.network';Future<dynamic> _get(String url)async{final r=await http.get(Uri.parse(url)).timeout(const Duration(seconds:20));if(r.statusCode!=200)throw Exception('Al Quran Cloud ${r.statusCode}');final j=jsonDecode(r.body);if(j['code']!=200)throw Exception(j['status']??'Kur’an servisi hatası');return j['data'];}Future<List<dynamic>> surahs()async=>List<dynamic>.from(await _get('$api/surah'));Future<List<Map<String,dynamic>>> verses(dynamic id)async{final a=await _get('$api/surah/$id/quran-uthmani');dynamic t;try{t=await _get('$api/surah/$id/tr.diyanet');}catch(_){t=await _get('$api/surah/$id/tr.yazir');}final aa=List<dynamic>.from(a['ayahs']),tt=List<dynamic>.from(t['ayahs']);return List.generate(aa.length,(i)=>{'globalNumber':aa[i]['number'],'numberInSurah':aa[i]['numberInSurah'],'arabic':aa[i]['text'],'translation':i<tt.length?tt[i]['text']:''});}String ayahAudio(int global,String edition,int bitrate)=>'$cdn/quran/audio/$bitrate/$edition/$global.mp3';String surahAudio(dynamic surah,String edition,int bitrate)=>'$cdn/quran/audio-surah/$bitrate/$edition/$surah.mp3';}

class SalahBrandHeader extends StatelessWidget{const SalahBrandHeader({super.key});@override Widget build(BuildContext c)=>Row(children:[Container(width:38,height:38,decoration:BoxDecoration(color:brand,borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.mosque,color:Colors.white,size:22)),const SizedBox(width:10),const Text('Salah',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,letterSpacing:-.6)),const Spacer(),Text('Prayer • Quran',style:Theme.of(c).textTheme.labelMedium)]);}

class HadithScreen extends StatefulWidget{const HadithScreen({super.key});@override State<HadithScreen> createState()=>_HadithScreenState();}
class _HadithScreenState extends State<HadithScreen>{late Future<List<HadithItem>> future;@override void initState(){super.initState();future=GlobalHadithService().load();}@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:Text('Hadis • '+AppLanguage.supported[appLanguage.code]!)),body:FutureBuilder<List<HadithItem>>(future:future,builder:(c,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(s.hasError)return Center(child:Text(s.error.toString()));return ListView.builder(padding:const EdgeInsets.all(18),itemCount:s.data!.length,itemBuilder:(c,i){final h=s.data![i];return Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(h.text,style:const TextStyle(fontSize:17,height:1.55)),if(h.reference.isNotEmpty)...[const SizedBox(height:8),Text('Kaynak: '+h.reference,style:Theme.of(c).textTheme.bodySmall)],if(h.grade.isNotEmpty)Text('Derece: '+h.grade,style:Theme.of(c).textTheme.bodySmall)])));});}));}
class TasbihScreen extends StatefulWidget{const TasbihScreen({super.key});@override State<TasbihScreen> createState()=>_TasbihScreenState();}class _TasbihScreenState extends State<TasbihScreen>{int n=0,target=33;@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Zikirmatik')),body:Padding(padding:const EdgeInsets.all(20),child:Column(children:[const SizedBox(height:30),Text('$n / $target',style:const TextStyle(fontSize:54,fontWeight:FontWeight.w300)),const SizedBox(height:12),LinearProgressIndicator(value:(n/target).clamp(0.0,1.0).toDouble()),const Spacer(),SizedBox(width:190,height:190,child:FilledButton(onPressed:()=>setState(()=>n++),style:FilledButton.styleFrom(shape:const CircleBorder()),child:const Icon(Icons.touch_app,size:62))),TextButton(onPressed:()=>setState(()=>n=0),child:const Text('Sıfırla')),const Spacer()]))) ;}
class DiscoverScreen extends StatelessWidget{final PrayerData d;const DiscoverScreen({super.key,required this.d});@override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(20),children:[const SalahBrandHeader(),const SizedBox(height:14),Text(tr('Keşfet'),style:TextStyle(fontSize:28,fontWeight:FontWeight.w800)),const SizedBox(height:16),_tile(c,Icons.nights_stay,'Ramazan','İmsak ve iftar takvimi',()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>RamadanScreen(d:d)))),_tile(c,Icons.explore,'Kıble','Kâbe yönünü bul',()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>QiblaScreen(d:d)))),_tile(c,Icons.auto_stories,'Hadis','Seçili sahih hadisler',()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>const HadithScreen()))),_tile(c,Icons.radio_button_checked,'Zikirmatik','Günlük zikir sayacı',()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>const TasbihScreen()))),_tile(c,Icons.volunteer_activism,'Dualar','Günlük dua koleksiyonu',()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>const DuaScreen()))),_tile(c,Icons.emoji_events_outlined,tr('İslami Bilgi Yarışması'),'5.820 soru • 10 soruluk turlar',()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>const IslamicQuizScreen())))]);Widget _tile(BuildContext c,IconData i,String t,String s,VoidCallback f)=>Card(child:ListTile(contentPadding:const EdgeInsets.all(14),leading:CircleAvatar(backgroundColor:brand.withOpacity(.12),child:Icon(i,color:brand)),title:Text(t,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(s),trailing:const Icon(Icons.chevron_right),onTap:f));}
class DuaScreen extends StatefulWidget{const DuaScreen({super.key});@override State<DuaScreen> createState()=>_DuaScreenState();}
class _DuaScreenState extends State<DuaScreen>{
 late Future<List<DuaItem>> future;final tts=FlutterTts();final scroll=ScrollController();List<GlobalKey> keys=const[];int? speaking;int hiStart=-1,hiEnd=-1;
 @override void initState(){super.initState();future=DuaService().load().then((v){keys=List.generate(v.length,(_)=>GlobalKey());return v;});tts.setLanguage('ar-SA');tts.setSpeechRate(.42);tts.setProgressHandler((text,start,end,word){if(mounted)setState((){hiStart=start;hiEnd=end;});});tts.setCompletionHandler((){if(mounted)setState((){speaking=null;hiStart=-1;hiEnd=-1;});});tts.setCancelHandler((){if(mounted)setState((){speaking=null;hiStart=-1;hiEnd=-1;});});}
 @override void dispose(){tts.stop();scroll.dispose();super.dispose();}
 Future<void> _speak(DuaItem d,int i)async{if(speaking==i){await tts.stop();setState((){speaking=null;hiStart=-1;hiEnd=-1;});return;}await tts.stop();setState((){speaking=i;hiStart=-1;hiEnd=-1;});WidgetsBinding.instance.addPostFrameCallback((_){final ctx=keys[i].currentContext;if(ctx!=null)Scrollable.ensureVisible(ctx,duration:const Duration(milliseconds:400),alignment:.15);});await tts.speak(d.arabic);}
 Widget _duaText(DuaItem d,int i){if(speaking!=i||hiStart<0||hiEnd<=hiStart||hiEnd>d.arabic.length)return Text(d.arabic,textDirection:ui.TextDirection.rtl,textAlign:TextAlign.right,style:const TextStyle(fontSize:22,height:1.7));return Text.rich(TextSpan(children:[TextSpan(text:d.arabic.substring(0,hiStart)),TextSpan(text:d.arabic.substring(hiStart,hiEnd),style:const TextStyle(color:gold,fontWeight:FontWeight.w900)),TextSpan(text:d.arabic.substring(hiEnd))]),textDirection:ui.TextDirection.rtl,textAlign:TextAlign.right,style:const TextStyle(fontSize:22,height:1.7));}
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Dualar • Hisnul Muslim')),body:FutureBuilder<List<DuaItem>>(future:future,builder:(c,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(s.hasError)return Center(child:Padding(padding:const EdgeInsets.all(20),child:Text(s.error.toString())));return ListView.builder(controller:scroll,padding:const EdgeInsets.all(18),itemCount:s.data!.length,itemBuilder:(c,i){final d=s.data![i];return Card(key:keys[i],child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Row(children:[Expanded(child:Text(d.title,style:const TextStyle(fontWeight:FontWeight.w800))),IconButton(onPressed:()=>_speak(d,i),icon:Icon(speaking==i?Icons.stop_circle:Icons.volume_up,color:brand))]),const SizedBox(height:10),_duaText(d,i),if(d.translation.isNotEmpty)...[const Divider(),FutureBuilder<String>(future:TranslationService.translate(d.translation,from:'en',to:appLanguage.code),builder:(c,t)=>Text(t.data??d.translation,style:const TextStyle(height:1.5)))],if(d.source.isNotEmpty)...[const SizedBox(height:8),Text(d.source,style:Theme.of(c).textTheme.bodySmall)]])));});}));}
class DailyContentSettings extends StatefulWidget{const DailyContentSettings({super.key});@override State<DailyContentSettings> createState()=>_DailyContentSettingsState();}
class _DailyContentSettingsState extends State<DailyContentSettings>{
 bool consent=false,verse=true,hadith=true,dua=true;bool loading=true;
 @override void initState(){super.initState();_restore();}
 Future<void> _restore()async{final p=await SharedPreferences.getInstance();if(!mounted)return;setState((){consent=p.getBool('daily_content_consent')??false;verse=p.getBool('daily_content_verse')??true;hadith=p.getBool('daily_content_hadith')??true;dua=p.getBool('daily_content_dua')??true;loading=false;});}
 Future<void> _save()async{final p=await SharedPreferences.getInstance();await p.setBool('daily_content_consent',consent);await p.setBool('daily_content_verse',verse);await p.setBool('daily_content_hadith',hadith);await p.setBool('daily_content_dua',dua);if(consent)await _schedule();else await _cancel();}
 Future<void> _cancel()async{for(final id in [7001,7002,7003]){await notifications.cancel(id);}}
 Future<void> _schedule()async{
  await _cancel();
  final android=notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();await android?.requestNotificationsPermission();
  final now=tz.TZDateTime.now(tz.local);
  Future<void> plan(int id,int hour,String title,String body)async{var at=tz.TZDateTime(tz.local,now.year,now.month,now.day,hour);if(!at.isAfter(now))at=at.add(const Duration(days:1));await notifications.zonedSchedule(id,title,body,at,const NotificationDetails(android:AndroidNotificationDetails('daily_content','Günlük İçerik',channelDescription:'Kullanıcının onayladığı günlük ayet, hadis ve dua içerikleri',importance:Importance.defaultImportance,priority:Priority.defaultPriority,visibility:NotificationVisibility.public),iOS:DarwinNotificationDetails()),androidScheduleMode:AndroidScheduleMode.inexactAllowWhileIdle,uiLocalNotificationDateInterpretation:UILocalNotificationDateInterpretation.absoluteTime,matchDateTimeComponents:DateTimeComponents.time);}
  if(verse)await plan(7001,8,'Günün Ayeti','Allah hiç kimseye gücünün yeteceğinden fazlasını yüklemez. • Bakara 2:286');
  if(hadith)await plan(7002,13,'Günün Hadisi','Ameller niyetlere göredir. • Kaynak ayrıntısı Salah içinde');
  if(dua)await plan(7003,20,'Günün Duası','Günün duasını okumak için Salah’a dokunun.');
 }
 Future<void> _consent(bool v)async{if(v){final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Günlük içerik izni'),content:const Text('Ayet, hadis ve dua bildirimlerinin kilit ekranında görünebilmesi için izin veriyorsunuz. İstediğiniz zaman buradan kapatabilirsiniz.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Onaylıyorum'))]))??false;if(!ok)return;}setState(()=>consent=v);await _save();}
 @override Widget build(BuildContext c){if(loading)return const Center(child:CircularProgressIndicator());return Scaffold(appBar:AppBar(title:const Text('Günlük İçerik')),body:ListView(padding:const EdgeInsets.all(18),children:[Card(child:SwitchListTile(value:consent,onChanged:_consent,title:const Text('Kilit ekranında günlük içerik'),subtitle:const Text('Yalnızca açık onayınızla bildirim gösterilir.'))),const SizedBox(height:12),SectionTitle('Gösterilecek içerikler'),CheckboxListTile(value:verse,onChanged:consent?(v){setState(()=>verse=v??false);_save();}:null,title:const Text('Günün Ayeti')),CheckboxListTile(value:hadith,onChanged:consent?(v){setState(()=>hadith=v??false);_save();}:null,title:const Text('Günün Hadisi')),CheckboxListTile(value:dua,onChanged:consent?(v){setState(()=>dua=v??false);_save();}:null,title:const Text('Günün Duası')),const SizedBox(height:12),const Text('Bildirimler varsayılan olarak kapalıdır. İçerik seçimi ve kilit ekranı gösterimi cihazın bildirim ayarlarına da bağlıdır.') ]));}
}
class SettingsScreen extends StatefulWidget{final PrayerData d;final ValueChanged<ThemeMode> onTheme;const SettingsScreen({super.key,required this.d,required this.onTheme});@override State<SettingsScreen> createState()=>_SettingsScreenState();}
class _SettingsScreenState extends State<SettingsScreen>{ThemeMode selected=ThemeMode.system;@override Widget build(BuildContext c)=>AnimatedBuilder(animation:widget.d,builder:(c,_)=>(ListView(padding:const EdgeInsets.all(20),children:[const SalahBrandHeader(),const SizedBox(height:14),Text(tr('Ayarlar'),style:TextStyle(fontSize:28,fontWeight:FontWeight.w800)),const SizedBox(height:18),DropdownButtonFormField<int>(value:widget.d.method,decoration:const InputDecoration(labelText:'Hesaplama yöntemi',border:OutlineInputBorder()),items:widget.d.methods.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v){if(v!=null){widget.d.method=v;widget.d.load();}}),const SizedBox(height:14),Card(child:ListTile(leading:const Icon(Icons.location_on_outlined),title:Text(widget.d.city.isEmpty?'Konum':widget.d.city),subtitle:Text(widget.d.timezone),trailing:IconButton(onPressed:widget.d.load,icon:const Icon(Icons.refresh)))),const SizedBox(height:12),SectionTitle(tr('Bildirimler')),...widget.d.alerts.entries.map((e)=>SwitchListTile(title:Text(e.key),subtitle:const Text('Vakit geldiğinde bildir'),value:e.value,onChanged:(v)=>widget.d.setAlert(e.key,v))),const SizedBox(height:12),Card(child:ListTile(leading:const Icon(Icons.lock_clock_outlined),title:const Text('Günlük İçerik'),subtitle:const Text('Kilit ekranı • Ayet, hadis ve dua • Kullanıcı onaylı'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>const DailyContentSettings())))),const SizedBox(height:12),SectionTitle(tr('Görünüm')),const SizedBox(height:8),SegmentedButton<ThemeMode>(segments:[ButtonSegment(value:ThemeMode.light,label:Text(tr('Açık')),icon:const Icon(Icons.light_mode)),ButtonSegment(value:ThemeMode.system,label:Text(tr('Sistem')),icon:const Icon(Icons.settings_brightness)),ButtonSegment(value:ThemeMode.dark,label:Text(tr('Koyu')),icon:const Icon(Icons.dark_mode))],selected:{selected},onSelectionChanged:(v){setState(()=>selected=v.first);widget.onTheme(v.first);}),const SizedBox(height:16),AnimatedBuilder(animation:appLanguage,builder:(c,_)=>(DropdownButtonFormField<String>(value:appLanguage.code,decoration:InputDecoration(labelText:tr('Dil • 12 seçenek'),border:const OutlineInputBorder(),prefixIcon:const Icon(Icons.language)),items:AppLanguage.supported.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v){if(v!=null)appLanguage.setCode(v);}))) ])));}
