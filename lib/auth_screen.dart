import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLogin = true; 
  bool _isLoading = false;
  bool _rememberMe = true; 
  bool _isAgreementAccepted = false; // Kesinlikle false (boş) gelmeli

  @override
  void initState() {
    super.initState();
    _checkRememberedUser();
  }

  Future<void> _checkRememberedUser() async {
    final prefs = await SharedPreferences.getInstance();
    bool remembered = prefs.getBool('remember_me') ?? false;
    
    if (remembered) {
      String? savedEmail = prefs.getString('saved_email');
      String? savedPass = prefs.getString('saved_password');
      bool agreementSaved = prefs.getBool('agreement_accepted') ?? false;

      // Eğer beni hatırla aktifse VE daha önceden sözleşmeyi onayladıysa direkt HomeScreen'e atla
      if (savedEmail != null && savedPass != null && agreementSaved) {
        _emailController.text = savedEmail;
        _passwordController.text = savedPass;
        
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        return;
      }
    }
  }

  void _showAgreementModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Kullanıcı Sözleşmesi ve Gizlilik Politikası',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: const Text(
                        'BAMBOO KULLANICI SÖZLEŞMESİ\n'
                        'Son Güncelleme Tarihi: Eylül 2026\n\n'
                        'Bu Kullanıcı Sözleşmesi (“Sözleşme”), Bamboo uygulamasının (“Uygulama”) sahibi ve geliştiricisi (“Geliştirici”) ile Uygulamayı indiren, kullanan veya Uygulamaya üye olan gerçek kişi (“Kullanıcı”) arasında, Kullanıcının elektronik ortamda onay vermesi ve/veya Uygulamayı kullanmaya başlaması ile yürürlüğe girer.\n'
                        'Kullanıcı, Uygulamayı kullanmaya başlamadan önce bu Sözleşmeyi okuduğunu, içeriğini anladığını ve hükümlerini kabul ettiğini beyan eder. Sözleşmeyi kabul etmeyen Kullanıcının Uygulamayı kullanmaması ve cihazından kaldırması gerekir.\n\n'
                        '1. SÖZLEŞMENİN KONUSU VE HİZMETİN KAPSAMI\n'
                        '1.1. Bamboo; YKS (Yükseköğretim Kurumları Sınavı) hazırlık sürecindeki öğrencilerin çalışma süreçlerini planlamalarına, çalışma sürelerini takip etmelerine, motivasyonlarını artırmalarına ve Uygulama içerisinde sunulan sosyal özelliklerden yararlanmalarına yardımcı olmak amacıyla geliştirilmiş dijital bir araçtır.\n'
                        '1.2. Uygulama kapsamında; çalışma süresi takibi, Pomodoro ve benzeri zamanlayıcı özellikleri, çalışma istatistikleri, notlar, kullanıcı profili, arkadaşlık özellikleri, mesajlaşma, liderlik tabloları, sanal puan/coin sistemleri, Bamboo ilerleme sistemi, reklamlar ve gelecekte eklenecek benzer özellikler sunulabilir.\n'
                        '1.3. Geliştirici, Uygulamanın özelliklerini, içeriğini, tasarımını, teknik altyapısını ve sunulan hizmetleri dilediği zaman değiştirme, geliştirme, sınırlandırma, geçici olarak durdurma veya tamamen sonlandırma hakkını saklı tutar.\n'
                        '1.4. Uygulamada sunulan özelliklerin tamamının her Kullanıcıya, her cihazda veya her zaman sunulacağı garanti edilmez.\n\n'
                        '2. HESAP OLUŞTURMA VE KULLANICI SORUMLULUKLARI\n'
                        '2.1. Kullanıcı, üyelik sırasında verdiği bilgilerin doğru, güncel ve kendisine ait olduğunu kabul eder.\n'
                        '2.2. Kullanıcı, hesabının güvenliğinden ve hesap üzerinden gerçekleştirilen işlemlerden sorumludur.\n'
                        '2.3. Kullanıcı, hesap bilgilerini üçüncü kişilerle paylaşmamalı ve hesabının başkaları tarafından kullanılmasına izin vermemelidir.\n'
                        '2.4. Hesabın yetkisiz kişiler tarafından kullanıldığının veya hesap güvenliğinin tehlikeye girdiğinin düşünülmesi halinde Kullanıcı, durumu mümkün olan en kısa sürede Geliştiriciye bildirmelidir.\n'
                        '2.5. Geliştirici, güvenlik, kötüye kullanım, dolandırıcılık, hile, teknik risk veya Sözleşmeye aykırılık şüphesi bulunan hesaplar hakkında gerekli güvenlik önlemlerini alma hakkına sahiptir.\n\n'
                        '3. KULLANIM KURALLARI\n'
                        'Kullanıcı aşağıdaki faaliyetlerde bulunamaz:\n'
                        '- Başka kişileri taklit etmek veya başkasına ait bilgilerle hesap oluşturmak,\n'
                        '- Başka Kullanıcıların hesaplarına izinsiz erişmeye çalışmak,\n'
                        '- Uygulamanın güvenliğini veya çalışmasını bozacak işlemler gerçekleştirmek,\n'
                        '- Uygulamanın açıklarından yararlanarak haksız avantaj elde etmek,\n'
                        '- Otomasyon, bot, script, exploit veya benzeri yöntemlerle çalışma sürelerini, puanları, coinleri, Bamboo ilerlemesini veya liderlik tablosu verilerini yapay şekilde değiştirmek,\n'
                        '- Uygulamaya veya sunucularına olağandışı veya kötü niyetli trafik göndermek,\n'
                        '- Uygulamanın kaynak kodunu, API\'lerini veya teknik altyapısını yetkisiz şekilde incelemek, değiştirmek veya müdahale etmek,\n'
                        '- Virüs, zararlı yazılım veya Uygulamanın çalışmasını etkileyebilecek başka kodlar kullanmak,\n'
                        '- Uygulama üzerinden spam, reklam veya istenmeyen içerik yaymak,\n'
                        '- Hakaret, tehdit, taciz, nefret söylemi, müstehcenlik veya hukuka aykırı içerik paylaşmak,\n'
                        '- Üçüncü kişilerin kişilik haklarını, telif haklarını, marka haklarını, özel hayatını veya diğer yasal haklarını ihlal etmek,\n'
                        '- Uygulamayı yürürlükteki mevzuata aykırı amaçlarla kullanmak.\n\n'
                        '4. SOSYAL ÖZELLİKLER, ARKADAŞLIK VE MESAJLAŞMA\n'
                        '4.1. Uygulamada Kullanıcı adı, profil bilgileri, arkadaşlık, mesajlaşma, liderlik tablosu veya benzeri sosyal özellikler bulunabilir.\n'
                        '4.2. Kullanıcı tarafından Uygulamaya girilen veya oluşturulan içeriklerin hukuka uygun olmasından Kullanıcı sorumludur.\n'
                        '4.3. Kullanıcı, Uygulamaya yüklediği veya oluşturduğu içerikler üzerinde gerekli haklara sahip olduğunu ve bu içeriklerin üçüncü kişilerin haklarını ihlal etmediğini kabul eder.\n'
                        '4.4. Arkadaşlık ve mesajlaşma özellikleri Uygulamanın belirlediği kurallar dahilinde kullanılabilir. Arkadaş olmayan Kullanıcılar birbirlerine doğrudan mesaj gönderemez.\n'
                        '4.5. Kullanıcılar, istemedikleri Kullanıcıları engelleyebilir. Engelleme işlemi sonrasında taraflar arasındaki iletişim ve Uygulamanın ilgili sosyal özellikleri sınırlandırılabilir veya engellenebilir.\n'
                        '4.6. İki Kullanıcı arasındaki mesajlaşma geçmişi en fazla 500 mesaj ile sınırlıdır. Bu sınıra ulaşıldığında, yeni mesajlara yer açmak amacıyla en eski mesajlar sistem tarafından otomatik olarak silinebilir.\n'
                        '4.7. Kullanıcının bir kişiyi arkadaşlıktan çıkarması veya engellemesi halinde, taraflar arasındaki mevcut mesajlaşma geçmişi sistem tarafından otomatik olarak silinebilir.\n'
                        '4.8. Mesajların silinmesi, Kullanıcının hesabını veya mesajlaşma özelliğini kullanmaya devam etmesine engel değildir; ancak silinen mesajların yeniden oluşturulacağı veya geri getirileceği garanti edilmez.\n'
                        '4.9. Geliştirici, hukuka aykırı, Sözleşmeye aykırı, diğer Kullanıcıların güvenliğini veya deneyimini olumsuz etkileyen ya da Uygulamanın işleyişini tehdit eden içerikleri kaldırma, görünürlüğünü sınırlandırma veya ilgili hesabı askıya alma hakkına sahiptir.\n'
                        '4.10. Geliştirici, Uygulama içerisinde meydana gelen Kullanıcılar arası iletişim ve anlaşmazlıklarda, yürürlükteki mevzuattan doğan yükümlülükleri saklı kalmak kaydıyla, taraflardan biri olarak kabul edilmez.\n'
                        '4.11. Kullanıcılar arasındaki hakaret, tehdit, taciz, dolandırıcılık, kişisel anlaşmazlık veya benzeri fiillerden bunları gerçekleştiren Kullanıcı sorumludur.\n\n'
                        '5. LİDERLİK TABLOSU VE ÇALIŞMA İSTATİSTİKLERİ\n'
                        '5.1. Liderlik tablolarında Kullanıcıların çalışma süresi, puan, coin, Bamboo uzunluğu veya benzeri oyunlaştırma ve ilerleme verileri gösterilebilir.\n'
                        '5.2. Liderlik tablosunda Kullanıcının profilinin ve ilgili istatistiklerinin görünürlüğü, Uygulamada sunulan gizlilik ve görünürlük tercihleri kapsamında sınırlandırılabilir veya gizlenebilir.\n'
                        '5.3. Kullanıcı, liderlik tablosunda görünür olmayı tercih ettiği durumda çalışma süresi, coin, Bamboo uzunluğu veya benzeri belirli istatistiklerinin diğer Kullanıcılara gösterilebileceğini kabul eder.\n'
                        '5.4. Liderlik tablosundaki sıralamalar yalnızca Uygulama tarafından hesaplanan verilere dayanır ve akademik başarı göstergesi olarak değerlendirilmemelidir.\n'
                        '5.5. Teknik hatalar, senkronizasyon problemleri, bağlantı sorunları, sunucu problemleri veya kötüye kullanım nedeniyle istatistiklerde veya sıralamalarda hatalar meydana gelebilir.\n\n'
                        '6. SANAL COIN, PUAN VE DİJİTAL DEĞERLER\n'
                        '6.1. Uygulama içerisinde “coin”, puan veya benzeri sanal değerler bulunabilir.\n'
                        '6.2. Bu değerler, aksi açıkça belirtilmedikçe gerçek para, elektronik para, yatırım aracı, finansal varlık veya parasal alacak niteliğinde değildir.\n'
                        '6.3. Sanal değerler Kullanıcıya herhangi bir mülkiyet, nakit olarak geri alma veya gerçek para karşılığı talep etme hakkı vermez.\n'
                        '6.4. Geliştirici, teknik zorunluluklar, hile, kötüye kullanım, ekonomik denge veya Uygulamanın geliştirilmesi amacıyla sanal değerlerin kazanılma yöntemlerini, miktarlarını veya kullanım alanlarını değiştirebilir.\n'
                        '6.5. Hesabın Sözleşmeye aykırılık nedeniyle kapatılması halinde Kullanıcının hesabında bulunan sanal değerler bakımından herhangi bir tazminat veya ödeme talebi ileri sürülemez; ancak emredici tüketici ve diğer ilgili mevzuat hükümleri saklıdır.\n\n'
                        '7. REKLAMLAR VE ÜÇÜNCÜ TARAF HİZMETLERİ\n'
                        '7.1. Uygulamanın sürdürülebilirliğini sağlamak amacıyla Google AdMob ve benzeri üçüncü taraf reklam hizmetleri kullanılabilir.\n'
                        '7.2. Reklamların gösterimi, kişiselleştirilmesi ve ölçümlenmesi kapsamında üçüncü taraf hizmet sağlayıcıları kendi politika ve teknik altyapıları doğrultusunda belirli cihaz, reklam, kullanım veya teknik verileri işleyebilir.\n'
                        '7.3. Üçüncü taraf reklamların içeriği, doğruluğu, reklamverenlerin faaliyetleri veya reklamların yönlendirdiği internet siteleri Geliştiricinin kontrolünde değildir.\n'
                        '7.4. Kullanıcı, üçüncü taraf hizmetlerinin kendi kullanım koşullarına ve gizlilik politikalarına tabi olabileceğini kabul eder.\n'
                        '7.5. Kişisel verilerin işlenmesine ilişkin ayrıntılar ayrıca Bamboo KVKK Aydınlatma Metni ve ilgili gizlilik belgelerinde açıklanır.\n\n'
                        '8. KİŞİSEL VERİLER VE GİZLİLİK\n'
                        '8.1. Uygulamanın çalışması kapsamında Kullanıcıya ait kişisel veriler işlenebilir.\n'
                        '8.2. İşlenebilecek verilere; üyelik ve hesap bilgileri, kullanıcı adı, e-posta adresi, uygulama kullanım ve çalışma istatistikleri, teknik bilgiler ve Kullanıcının Uygulama içerisinde oluşturduğu veriler dahil olabilir.\n'
                        '8.3. Hangi kişisel verilerin hangi amaçlarla, hangi hukuki sebeplerle ve kimlere aktarılabileceğine ilişkin ayrıntılar Bamboo KVKK Aydınlatma Metninde açıklanır.\n'
                        '8.4. KVKK kapsamında gerekli olması halinde Kullanıcıya ayrıca açık rıza alınması gereken işlemler için ayrı bir açık rıza mekanizması sunulur.\n'
                        '8.5. Kullanıcının Sözleşmeyi kabul etmesi tek başına, hukuken ayrıca açık rıza gerektiren tüm veri işleme faaliyetlerine açık rıza verdiği anlamına gelmez.\n'
                        '8.6. Geliştirici, kişisel verilerin güvenliğini sağlamak amacıyla yürürlükteki mevzuat kapsamında gerekli teknik ve idari tedbirleri almaya çalışır.\n\n'
                        '9. FIREBASE VE BULUT ALTYAPISI\n'
                        '9.1. Uygulama; kimlik doğrulama, veri saklama, veritabanı, bildirim, analiz veya benzeri teknik hizmetler için Google Firebase ve/vage benzeri üçüncü taraf altyapı hizmetlerinden yararlanabilir.\n'
                        '9.2. Üçüncü taraf hizmet sağlayıcıların teknik arızaları, bakım çalışmaları, internet altyapısı problemleri, siber saldırılar, hizmet kesintileri veya Geliştiricinin makul kontrolü dışındaki teknik olaylar nedeniyle Uygulamanın bazı özelliklerine geçici olarak erişilemeyebilir.\n'
                        '9.3. Geliştirici, üçüncü taraf hizmet sağlayıcıların kendi altyapılarındaki her türlü olayın doğrudan faili veya sorumlusu değildir. Bununla birlikte Geliştiricinin yürürlükteki mevzuattan kaynaklanan kendi yükümlülükleri saklıdır.\n\n'
                        '10. VERİ KAYBI VE YEDEKLEME\n'
                        '10.1. Geliştirici, Kullanıcı verilerinin teknik altyapı içerisinde korunması için makul güvenlik ve yedekleme yöntemlerini kullanabilir.\n'
                        '10.2. Buna rağmen donanım arızası, yazılım hatası, veri tabanı bozulması, siber saldırı, yanlış kullanım, üçüncü taraf hizmet kesintisi, internet bağlantısı problemi veya öngörülemeyen teknik olaylar nedeniyle veri kaybı meydana gelebilir.\n'
                        '10.3. Kullanıcı, önemli verilerin yalnızca Uygulama içerisinde tutulmaması ve gerekli olması halinde ayrıca yedeklenmesi gerektiğini kabul eder.\n\n'
                        '11. AKADEMİK BAŞARI VE SINAV SONUÇLARI\n'
                        '11.1. Bamboo bir eğitim kurumu, özel ders hizmeti veya resmi sınav danışmanlığı hizmeti değildir.\n'
                        '11.2. Uygulamada yer alan çalışma süreleri, istatistikler, motivasyon araçları veya diğer özellikler herhangi bir akademik başarı, belirli bir YKS puanı, sıralama, üniversiteye yerleşme veya sınav başarısı garantisi vermez.\n'
                        '11.3. Uygulamanın kullanımından elde edilen sonuçlar Kullanıcının bireysel çalışma düzeni, performansı, sınav koşulları ve diğer birçok faktöre bağlıdır.\n'
                        '11.4. Uygulamadaki bilgi veya yönlendirmelerin tek başına akademik, hukuki, mali, tıbbi veya profesyonel danışmanlık olarak değerlendirilmemesi gerekir.\n\n'
                        '12. HİZMETİN KESİNTİYE UĞRAMASI VE TEKNİK SORUNLAR\n'
                        '12.1. Geliştirici, Uygulamanın her zaman kesintisiz, tamamen güvenli, hatasız veya tüm cihazlarda aynı şekilde çalışacağını garanti etmez.\n'
                        '12.2. Bakım, güncelleme, teknik arıza, sunucu problemi, internet kesintisi, işletim sistemi değişiklikleri, üçüncü taraf hizmet kesintileri veya diğer teknik nedenlerle Uygulamanın tamamına veya bir bölümüne erişim geçici olarak kesilebilir.\n'
                        '12.3. Geliştirici, teknik problemlerin giderilmesi için makul çabayı gösterebilir; ancak her hatanın belirli bir süre içerisinde giderileceği garanti edilmez.\n\n'
                        '13. SORUMLULUK SINIRLAMASI\n'
                        '13.1. Uygulama, yürürlükteki mevzuatın izin verdiği ölçüde “mevcut haliyle” ve mevcut teknik imkanlar kapsamında sunulmaktadır.\n'
                        '13.2. Geliştirici; Kullanıcının Uygulamayı kullanımından, kullanamamasından, teknik kesintilerden, üçüncü taraf hizmetlerden, internet bağlantısı problemlerinden, cihaz arızalarından, Kullanıcı hatalarından veya Kullanıcının kendi eylemlerinden kaynaklanan zararlardan, yürürlükteki emredici mevzuat hükümleri saklı kalmak kaydıyla sorumlu tutulamaz.\n'
                        '13.3. Geliştiricinin kasıt veya ağır kusurundan doğan ve kanunen sınırlandırılması mümkün olmayan sorumlulukları bu madde kapsamında ortadan kaldırılmaz.\n'
                        '13.4. Hiçbir hüküm, tüketicinin yürürlükteki mevzuattan doğan ve sözleşmeyle ortadan kaldırılamayan haklarını sınırlamak amacıyla yorumlanamaz.\n\n'
                        '14. ÜÇÜNCÜ TARAF BAĞLANTILARI VE HİZMETLER\n'
                        '14.1. Uygulama içerisinde üçüncü taraf internet sitelerine, uygulamalara veya hizmetlere yönlendiren bağlantılar bulunabilir.\n'
                        '14.2. Bu bağlantılar yalnızca kolaylık amacıyla sunulabilir ve Geliştiricinin ilgili üçüncü tarafı onayladığı veya garanti ettiği anlamına gelmez.\n'
                        '14.3. Kullanıcı, üçüncü taraf hizmetleri kendi sorumluluğunda kullanır ve ilgili hizmetlerin kendi kullanım koşullarına tabi olduğunu kabul eder.\n\n'
                        '15. FİKRİ MÜLKİYET HAKLARI\n'
                        '15.1. Bamboo adı, logosu, tasarımı, arayüzü, yazılım kodları, grafik unsurları, metinleri, görselleri, sesleri, veritabanı yapısı ve Uygulamaya ilişkin diğer unsurlar üzerindeki fikri ve sınai mülkiyet hakları, ilgili hak sahiplerine aittir.\n'
                        '15.2. Kullanıcı, Geliştiricinin açık yazılı izni olmaksızın Uygulamanın tamamını veya herhangi bir bölümünü kopyalayamaz, çoğaltamaz, dağıtamaz, satamaz, kiralayamaz, değiştiremez veya ticari amaçla kullanamaz.\n'
                        '15.3. Uygulamanın teknik olarak çalışması için gerekli olan ve Kullanıcıya tanınan kullanım hakkı, herhangi bir fikri mülkiyet hakkının Kullanıcıya devredildiği anlamına gelmez.\n\n'
                        '16. HESABIN ASKIYA ALINMASI VE KAPATILMASI\n'
                        '16.1. Geliştirici; Kullanıcının bu Sözleşmeyi, topluluk kurallarını veya yürürlükteki mevzuatı ihlal etmesi halinde hesabı geçici olarak askıya alma, bazı özellikleri sınırlandırma veya hesabı kalıcı olarak kapatma hakkına sahiptir.\n'
                        '16.2. Güvenlik riski, hile, kötüye kullanım veya Uygulamanın bütünlüğünü tehdit eden durumlarda önceden bildirim yapılmaksızın gerekli önlemler alınabilir.\n'
                        '16.3. Kullanıcı, hesabını dilediği zaman kapatma ve yürürlükteki mevzuat kapsamında sahip olduğu veri haklarını kullanma talebinde bulunabilir.\n'
                        '16.4. Hesabın kapatılması, hesabın kapatılmasından önce doğmuş olan ve niteliği gereği devam etmesi gereken yükümlülükleri ortadan kaldırmaz.\n\n'
                        '17. KULLANICI TARAFINDAN HESAP SİLME\n'
                        '17.1. Kullanıcı, hesabının ve kendisiyle ilişkilendirilen verilerin silinmesi için Uygulama içerisinde sunulan hesap silme özelliğini veya Geliştirici tarafından belirtilen iletişim yöntemini kullanabilir.\n'
                        '17.2. Yasal olarak saklanması zorunlu olan kayıtlar, muhasebe kayıtları, hukuki uyuşmazlıklara ilişkin kayıtlar veya mevzuat gereği tutulması gereken diğer veriler ilgili mevzuatta öngörülen süre boyunca saklanabilir.\n'
                        '17.3. Veri silme işlemlerinin teknik altyapı ve üçüncü taraf sağlayıcılardaki yansıması belirli bir süre alabilir.\n\n'
                        '18. SÖZLEŞMEDE DEĞİŞİKLİK\n'
                        '18.1. Geliştirici, Uygulamanın gelişen yapısı, teknik gereksinimleri veya mevzuat değişiklikleri nedeniyle bu Sözleşmeyi güncelleyebilir.\n'
                        '18.2. Önemli değişiklikler, uygun olduğu ölçüde Uygulama içerisinde Kullanıcıların dikkatine sunulabilir.\n'
                        '18.3. Güncellenen Sözleşmenin yürürlüğe girmesinden sonra Uygulamanın kullanılmaya devam edilmesi, güncel hükümler kapsamında kullanımın devamı anlamına gelir.\n'
                        '18.4. Kullanıcı güncellenen hükümleri kabul etmiyorsa Uygulamayı kullanmayı bırakabilir ve hesabının kapatılmasını talep edebilir.\n\n'
                        '19. SÖZLEŞMENİN BÜTÜNLÜĞÜ\n'
                        '19.1. Bu Sözleşme ile birlikte Bamboo\'nun KVKK Aydınlatma Metni, Gizlilik Politikası ve varsa Topluluk Kuralları, Uygulamanın kullanımına ilişkin tamamlayıcı belgeler olarak uygulanır.\n'
                        '19.2. Bu belgelerden herhangi bir hükmün yetkili makam veya mahkeme tarafından geçersiz veya uygulanamaz olduğuna karar verilmesi, diğer hükümlerin geçerliliğini etkilemez.\n'
                        '19.3. İşbu Sözleşmenin herhangi bir hükmünün yürürlükteki emredici mevzuata aykırı olması halinde ilgili hüküm, mevzuata uygun olduğu ölçüde uygulanır.\n\n'
                        '20. UYGULANACAK HUKUK VE UYUŞMAZLIKLAR\n'
                        '20.1. Bu Sözleşmeye Türk Hukuku uygulanır.\n'
                        '20.2. Tüketici işlemlerinden doğabilecek uyuşmazlıklarda, yürürlükteki tüketici mevzuatında öngörülen başvuru yolları, zorunlu arabuluculuk hükümleri, tüketici hakem heyetlerinin görev ve yetkileri ile tüketici mahkemelerinin görev ve yetkilerine ilişkin emredici hükümler saklıdır.\n'
                        '20.3. Tüketici mevzuatının uygulanmadığı uyuşmazlıklarda, yürürlükteki usul ve yetki kuralları uygulanır.\n\n'
                        '21. İLETİŞİM\n'
                        'Kullanıcı; hesap, veri, teknik sorun, güvenlik, içerik veya diğer taleplerini Geliştirici tarafından Uygulama içerisinde belirtilen iletişim kanallarından iletebilir.\n'
                        'Geliştiricinin güncel iletişim bilgileri Uygulama içerisinde veya ilgili resmi internet sayfasında yayınlanır.\n\n'
                        '22. YÜRÜRLÜK\n'
                        '22.1. Bu Sözleşme, Kullanıcının elektronik ortamda kabul etmesi veya Uygulamayı kullanmaya başlaması ile yürürlüğe girer.\n'
                        '22.2. Kullanıcı, Uygulamayı kullanmaya devam ettiği sürece yürürlükteki Sözleşme hükümlerine uymakla yükümlüdür.\n'
                        'Son Güncelleme: Eylül 2026',
                        style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitAuth() async {
    // Sözleşme onaylanmadıysa kesinlikle içeri alma!
    if (!_isAgreementAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Devam etmek için Kullanıcı Sözleşmesi\'ni onaylamalısın! 📜'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential;

      if (_isLogin) {
        userCredential = await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }

      final user = userCredential.user;
      if (user != null && user.email != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user_email', user.email!);
        await prefs.setBool('is_logged_in', true);
        await prefs.setBool('agreement_accepted', true); // Onay hafızaya kazınıyor

        if (_rememberMe) {
          await prefs.setBool('remember_me', true);
          await prefs.setString('saved_email', _emailController.text.trim());
          await prefs.setString('saved_password', _passwordController.text.trim());
        } else {
          await prefs.remove('remember_me');
          await prefs.remove('saved_email');
          await prefs.remove('saved_password');
        }

        // YENİ: E-postayı Firestore'daki kullanıcı belgesine de yazıyoruz.
        // Önceden bu bilgi sadece cihazın kendi hafızasında (SharedPreferences)
        // tutuluyordu; admin panelinin okuduğu Firestore'da hiç yoktu, bu yüzden
        // "Bilinmeyen E-posta" görünüyordu. `merge: true` sayesinde diğer profil
        // alanlarına (username, field, targetRank vb.) dokunmuyoruz.
        // Her girişte tekrar yazılması, eski hesaplardaki eksik e-postayı da
        // otomatik olarak "onarır" (backfill).
        try {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'email': user.email,
          }, SetOptions(merge: true));
        } catch (_) {
          // Firestore yazımı başarısız olsa bile giriş akışını kesmiyoruz.
        }
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Bir hata oluştu'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.7), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pinkAccent.withValues(alpha: 0.25),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isLogin ? Icons.lock_rounded : Icons.person_add_rounded,
                    size: 50,
                    color: Colors.pinkAccent,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _isLogin ? 'Hoş Geldin' : 'Hesap Oluştur',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin ? 'Bamboo ile hedeflerine odaklan' : 'YKS serüvenine hemen başla',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-posta',
                        labelStyle: TextStyle(color: Colors.white54),
                        prefixIcon: Icon(Icons.email_outlined, color: Colors.pinkAccent),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.pinkAccent)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      style: const TextStyle(color: Colors.white),
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Şifre',
                        labelStyle: TextStyle(color: Colors.white54),
                        prefixIcon: Icon(Icons.vpn_key_outlined, color: Colors.pinkAccent),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.pinkAccent)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Beni Hatırla
                    Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _rememberMe,
                            activeColor: Colors.pinkAccent,
                            checkColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            onChanged: (val) {
                              setState(() => _rememberMe = val ?? true);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Beni Hatırla',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Kullanıcı Sözleşmesi (Önceden tikli DEĞİL)
                    Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _isAgreementAccepted,
                            activeColor: Colors.pinkAccent,
                            checkColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            onChanged: (val) {
                              setState(() => _isAgreementAccepted = val ?? false);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showAgreementModal(context),
                            child: const Text(
                              'Kullanıcı Sözleşmesini okudum ve onaylıyorum.',
                              style: TextStyle(
                                color: Colors.pinkAccent,
                                fontSize: 12,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
                  : ElevatedButton(
                      onPressed: _submitAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        shadowColor: Colors.pinkAccent.withValues(alpha: 0.4),
                      ),
                      child: Text(
                        _isLogin ? 'Giriş Yap' : 'Kayıt Ol',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                  });
                },
                child: Text(
                  _isLogin
                      ? 'Hesabın yok mu? Hemen Kayıt Ol'
                      : 'Zaten bir hesabın var mı? Giriş Yap',
                  style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}