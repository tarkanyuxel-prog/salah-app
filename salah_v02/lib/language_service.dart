import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguage extends ChangeNotifier {
  static const supported=<String,String>{
    'tr':'Türkçe','en':'English','ar':'العربية','de':'Deutsch','fr':'Français','es':'Español',
    'id':'Bahasa Indonesia','ru':'Русский','ur':'اردو','bn':'বাংলা','hi':'हिन्दी','ms':'Bahasa Melayu'
  };
  String code='tr';

  static const _ui=<String,Map<String,String>>{
    'Ana Sayfa':{'en':'Home','ar':'الرئيسية','de':'Start','fr':'Accueil','es':'Inicio','id':'Beranda','ru':'Главная','ur':'ہوم','bn':'হোম','hi':'होम','ms':'Utama'},
    'Vakitler':{'en':'Prayer Times','ar':'المواقيت','de':'Gebetszeiten','fr':'Horaires','es':'Horarios','id':'Waktu Salat','ru':'Время молитв','ur':'اوقات','bn':'নামাজের সময়','hi':'नमाज़ समय','ms':'Waktu Solat'},
    'Kur’an':{'en':'Quran','ar':'القرآن','de':'Koran','fr':'Coran','es':'Corán','id':'Al-Quran','ru':'Коран','ur':'قرآن','bn':'কুরআন','hi':'कुरआन','ms':'Al-Quran'},
    'Keşfet':{'en':'Explore','ar':'استكشف','de':'Entdecken','fr':'Explorer','es':'Explorar','id':'Jelajahi','ru':'Обзор','ur':'دریافت','bn':'অন্বেষণ','hi':'खोजें','ms':'Teroka'},
    'Ayarlar':{'en':'Settings','ar':'الإعدادات','de':'Einstellungen','fr':'Paramètres','es':'Ajustes','id':'Pengaturan','ru':'Настройки','ur':'ترتیبات','bn':'সেটিংস','hi':'सेटिंग्स','ms':'Tetapan'},
    'Bildirimler':{'en':'Notifications','ar':'الإشعارات','de':'Benachrichtigungen','fr':'Notifications','es':'Notificaciones','id':'Notifikasi','ru':'Уведомления','ur':'اطلاعات','bn':'বিজ্ঞপ্তি','hi':'सूचनाएँ','ms':'Pemberitahuan'},
    'Görünüm':{'en':'Appearance','ar':'المظهر','de':'Darstellung','fr':'Apparence','es':'Apariencia','id':'Tampilan','ru':'Внешний вид','ur':'ظاہری شکل','bn':'চেহারা','hi':'दिखावट','ms':'Paparan'},
    'Açık':{'en':'Light','ar':'فاتح','de':'Hell','fr':'Clair','es':'Claro','id':'Terang','ru':'Светлая','ur':'روشن','bn':'হালকা','hi':'लाइट','ms':'Cerah'},
    'Sistem':{'en':'System','ar':'النظام','de':'System','fr':'Système','es':'Sistema','id':'Sistem','ru':'Система','ur':'سسٹم','bn':'সিস্টেম','hi':'सिस्टम','ms':'Sistem'},
    'Koyu':{'en':'Dark','ar':'داكن','de':'Dunkel','fr':'Sombre','es':'Oscuro','id':'Gelap','ru':'Тёмная','ur':'گہرا','bn':'গাঢ়','hi':'डार्क','ms':'Gelap'},
    'Dil • 12 seçenek':{'en':'Language • 12 options','ar':'اللغة • 12 خيارًا','de':'Sprache • 12 Optionen','fr':'Langue • 12 options','es':'Idioma • 12 opciones','id':'Bahasa • 12 pilihan','ru':'Язык • 12 вариантов','ur':'زبان • 12 اختیارات','bn':'ভাষা • ১২ বিকল্প','hi':'भाषा • 12 विकल्प','ms':'Bahasa • 12 pilihan'},
    'Namaz Vakitleri':{'en':'Prayer Times','ar':'مواقيت الصلاة','de':'Gebetszeiten','fr':'Horaires de prière','es':'Horarios de oración','id':'Waktu Salat','ru':'Время молитв','ur':'نماز کے اوقات','bn':'নামাজের সময়','hi':'नमाज़ का समय','ms':'Waktu Solat'},
    'Hızlı Erişim':{'en':'Quick Access','ar':'وصول سريع','de':'Schnellzugriff','fr':'Accès rapide','es':'Acceso rápido','id':'Akses Cepat','ru':'Быстрый доступ','ur':'فوری رسائی','bn':'দ্রুত প্রবেশ','hi':'त्वरित पहुँच','ms':'Akses Pantas'},
    'İslami Bilgi Yarışması':{'en':'Islamic Knowledge Quiz','ar':'مسابقة المعرفة الإسلامية','de':'Islamisches Wissensquiz','fr':'Quiz de connaissances islamiques','es':'Concurso de conocimiento islámico','id':'Kuis Pengetahuan Islam','ru':'Исламская викторина','ur':'اسلامی معلوماتی مقابلہ','bn':'ইসলামিক জ্ঞান কুইজ','hi':'इस्लामी ज्ञान प्रश्नोत्तरी','ms':'Kuiz Pengetahuan Islam'},
    'Tekrar dene':{'en':'Try again','ar':'حاول مجددًا','de':'Erneut versuchen','fr':'Réessayer','es':'Reintentar','id':'Coba lagi','ru':'Повторить','ur':'دوبارہ کوشش','bn':'আবার চেষ্টা করুন','hi':'फिर कोशिश करें','ms':'Cuba lagi'},
    'Soru bulunamadı':{'en':'No questions found','ar':'لم يتم العثور على أسئلة','de':'Keine Fragen gefunden','fr':'Aucune question trouvée','es':'No se encontraron preguntas','id':'Pertanyaan tidak ditemukan','ru':'Вопросы не найдены','ur':'سوال نہیں ملے','bn':'প্রশ্ন পাওয়া যায়নি','hi':'प्रश्न नहीं मिले','ms':'Soalan tidak ditemui'},
  };

  String text(String key)=>code=='tr'?key:(_ui[key]?[code]??key);
  Future<void> restore()async{final p=await SharedPreferences.getInstance();code=p.getString('app_language')??'tr';if(!supported.containsKey(code))code='tr';notifyListeners();}
  Future<void> setCode(String v)async{if(!supported.containsKey(v))return;code=v;final p=await SharedPreferences.getInstance();await p.setString('app_language',v);notifyListeners();}
}
final appLanguage=AppLanguage();
String tr(String key)=>appLanguage.text(key);
