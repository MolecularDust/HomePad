<!-- languages:start -->
<div align="center">

<details>
<summary><b>🌐 Language · Idioma · Langue · Sprache · Язык · 语言 · 言語 · 언어 · भाषा · لغة</b></summary>
<br>

<table>
  <tr>
    <td align="center"><a href="../../README.md">English</a></td>
    <td align="center"><a href="README.ar.md">العربية</a></td>
    <td align="center"><a href="README.bn.md">বাংলা</a></td>
    <td align="center"><a href="README.zh-Hans.md">简体中文</a></td>
    <td align="center"><a href="README.fil.md">Filipino</a></td>
  </tr>
  <tr>
    <td align="center"><a href="README.fr.md">Français</a></td>
    <td align="center"><a href="README.de.md">Deutsch</a></td>
    <td align="center"><a href="README.hi.md">हिन्दी</a></td>
    <td align="center"><a href="README.id.md">Bahasa Indonesia</a></td>
    <td align="center"><a href="README.it.md">Italiano</a></td>
  </tr>
  <tr>
    <td align="center"><a href="README.ja.md">日本語</a></td>
    <td align="center"><a href="README.ko.md">한국어</a></td>
    <td align="center"><a href="README.fa.md">فارسی</a></td>
    <td align="center"><a href="README.pt-BR.md">Português (Brasil)</a></td>
    <td align="center"><a href="README.ru.md">Русский</a></td>
  </tr>
  <tr>
    <td align="center"><a href="README.es.md">Español</a></td>
    <td align="center"><a href="README.te.md">తెలుగు</a></td>
    <td align="center"><a href="README.th.md">ไทย</a></td>
    <td align="center"><b>Türkçe</b></td>
    <td align="center"><a href="README.vi.md">Tiếng Việt</a></td>
  </tr>
</table>

</details>

</div>
<!-- languages:end -->

# HomePad for macOS

> Bu çeviri bir yapay zekâ tarafından yazıldı ve ana dili konuşanlar tarafından gözden geçirilmedi. HomePad bu dilde de kullanılabilir; düğme ve menü adları uygulamanın gösterdiği gibi verilmiştir (dili Ayarlar → Genel → Dil bölümünden değiştirebilirsiniz). Esas olan [İngilizce README](../../README.md) dosyasıdır.

**Kullandığınız her şey, tek tuş uzağınızda.** HomePad, Mac’inizin eksik olan başlatıcısıdır: uygulamalarınızı kategorilere ayırın, klasörlerde toplayın, favorilerinizi sabitleyin, her şeyi anında arayın ve çalışan uygulamaları gözünüzün önünde tutun; isterseniz Windows tarzı bir görev çubuğuyla.

Windows tarzı bir başlatıcı: bir kısayola basarsınız, ekranın ortasında bir panel belirir; üstte bir arama çubuğu (Spotlight’ın kullandığı dizini arar), altında sabitlenmiş uygulamaların ızgarası bulunur.

HomePad üç modda çalışır. Size uyanı Ayarlar → Mod bölümünden seçin.

**Görev çubuğu.** Windows’un görev çubuğunu ve Başlat menüsünü taklit eder. macOS’ta Windows deneyimini özlüyorsanız kendinizi evinizde hissedeceksiniz.

![Görev çubuğu modu: Başlat düğmesi, çalışan uygulamalar ve bir tepsi içeren Windows tarzı bir görev çubuğu, üstünde HomePad paneli](../images/mode-taskbar.webp)

**Dock + HomePad.** macOS’taki “Dock”u korumak isteyen ama Başlat menüsü tarzı bir başlatıcıya ihtiyaç duyanlar için. macOS’un Uygulamalar başlatıcısı var ama pek etkileyici değil: uygulamalarınızı sizin seçemeyeceğiniz kategorilere kendiliğinden ayırıyor; uygulamaları klasörlerde gruplayamıyor, favorileri sabitleyemiyor ya da istediğiniz gibi düzenleyemiyorsunuz. HomePad bunların hepsini çözer.

![Dock + HomePad modu: macOS Dock’u ve simgesinin üstünde açılan HomePad paneli](../images/mode-dock.webp)

**Bağımsız.** Ekran alanını en çok isteyen, “Dock” ve görev çubuğu istemeyen minimalistler için. HomePad’i bir kısayol tuşuyla, çift dokunmayla ya da fareyi etkin bir köşeye savurarak istediğiniz an çağırırsınız. Ortada belirir; favori uygulamalarınız, dosyalarınız ve klasörleriniz, arama ve pencereleriyle birlikte çalışan uygulamalar tamamen sizin denetiminizdedir. Ne “Dock”a ne de Spotlight’a ihtiyacınız kalır: Mac’inizi tek bir yerden yönetirsiniz. İlk başta tuhaf gelebilir ama alıştığınızda inanılmaz güçlü olur.

![Bağımsız mod: “Dock” ve görev çubuğu yok, ekranın ortasında HomePad paneli](../images/mode-standalone.webp)

## Kurulum

HomePad ücretsizdir ve Apple tarafından imzalanmamıştır; bu yüzden macOS onu bir kez engeller ve sorun olmadığını onaylamanızı ister. Bu yaklaşık beş dakika sürer ve yalnızca bir kez yapılır. macOS 13 (Ventura) veya üstü gerekir; hem Apple silicon hem Intel Mac’ler çalışır. ([INSTALL.md](../../INSTALL.md) aynı adımları sözcüklerle anlatır; zip ve sade disk görüntüsü için de.)

**1. Yükleyici disk görüntüsünü açın.** `HomePad-Installer.dmg` dosyasına çift tıklayın (HomePad’i sizinle paylaşan kişiden ya da kendiniz derleyin: `tools/make_installer_dmg.sh`, bkz. [Build and run](../../README.md#build-and-run)). Penceresi adımları sıralar.

<p align="center"><img src="../images/install/01-disk-image.webp" width="520" alt="Dört numaralı adımı gösteren yükleyici disk görüntüsü penceresi"></p>

**2. Install HomePad.pkg dosyasına çift tıklayın.** Mac, dosyanın açılamadığını söyler. **Bitti**’yi tıklayın, Çöp Sepeti’ne Taşı’yı değil.

<p align="center"><img src="../images/install/02-not-opened.webp" width="340" alt="macOS “Install HomePad.pkg” dosyasının açılmadığını söylüyor"></p>

**3. Gizlilik ve Güvenlik’te izin verin.** Disk görüntüsü penceresindeki mavi **Gizlilik ve Güvenlik’i Aç** karosuna çift tıklayın (ya da Sistem Ayarları → Gizlilik ve Güvenlik’i kendiniz açın), **Güvenlik** bölümüne kaydırın ve yükleyiciyle ilgili mesajın yanındaki **Yine de Aç**’ı tıklayın.

<p align="center"><img src="../images/install/03-privacy-security.webp" width="480" alt="Sistem Ayarları, Gizlilik ve Güvenlik: “Install HomePad.pkg” engellendi, Yine de Aç düğmesiyle"></p>

**4. Onaylayın.** Sonraki mesajda **Yine de Aç**’ı tıklayın, ardından Touch ID’yi kullanın ya da Mac parolanızı yazın.

<table align="center"><tr>
<td align="center"><img src="../images/install/04-open-anyway.webp" width="300" alt="macOS “Install HomePad.pkg” dosyasının açılıp açılmayacağını soruyor: Yine de Aç"></td>
<td align="center"><img src="../images/install/05-password.webp" width="300" alt="macOS Touch ID veya bir yöneticinin parolasını istiyor"></td>
</tr></table>

> macOS 13 Ventura ve 14 Sonoma’da bir kestirme var: yükleyiciye sağ tıklayın, **Aç**’ı seçin, sonra yine **Aç**’ı tıklayın.

**5. Yükleyiciyi izleyin.** Giriş, Neler beklemeli ve hedef (bu bilgisayarın tüm kullanıcıları için) ekranlarında **Devam**’ı, ardından **Yükle**’yi tıklayın. Mac parolanızı bir kez sorar. Yükleyici HomePad’in Uygulamalar klasörünüzde olduğunu söylediğinde **Kapat**’ı tıklayın.

<table align="center">
<tr>
<td align="center"><img src="../images/install/06-installer-welcome.webp" width="380" alt="Yükleyici: HomePad’e Hoş Geldiniz"></td>
<td align="center"><img src="../images/install/07-installer-what-to-expect.webp" width="380" alt="Yükleyici: Neler beklemeli, HomePad’in isteyeceği izinler"></td>
</tr>
<tr>
<td align="center"><img src="../images/install/08-installer-destination.webp" width="380" alt="Yükleyici: Hedef seçin, bu bilgisayarın tüm kullanıcıları için yükleyin"></td>
<td align="center"><img src="../images/install/09-installer-install.webp" width="380" alt="Yükleyici: Standart yükleme, Yükle düğmesiyle"></td>
</tr>
<tr>
<td align="center" colspan="2"><img src="../images/install/10-installer-summary.webp" width="380" alt="Yükleyici: HomePad yüklendi"></td>
</tr>
</table>

**6. Kurulum Kılavuzu.** HomePad bir karşılama penceresiyle kendiliğinden açılır. Üç izne izin verin, HomePad’i nasıl açmak istediğinizi seçin (bir klavye kısayolu, çift dokunma, etkin köşeler) ve **Başla**’yı tıklayın. Her izin isteğe bağlıdır ama HomePad üçüyle en iyi çalışır.

<p align="center"><img src="../images/install/11-setup-guide.webp" width="440" alt="HomePad’in karşılama penceresi: izin verilecek üç izin ve HomePad’in nasıl açılacağı"></p>

**7. İzinler.** Yukarıdan aşağıya her birinin yanındaki **İzin Ver…**’i tıklayın.

- **Ekran Kaydı** (çalışan bir uygulamanın pencere önizlemeleri). Kilitli bir mesaj belirir: **Sistem Ayarları’nı Aç**’ı tıklayın, **HomePad**’in yanındaki anahtarı açın ve **Çık ve Yeniden Aç**’ı tıklayın. HomePad kendiliğinden yeniden başlar ve karşılama penceresi geri gelir. macOS, HomePad’in ekranınıza doğrudan erişip erişemeyeceğini bir kez daha sorabilir: **İzin Ver**’i tıklayın.

<table align="center">
<tr>
<td align="center" valign="top"><img src="../images/install/12-screen-recording-prompt.webp" width="400" alt="macOS: “HomePad” bu bilgisayarın ekranını ve sesini kaydetmek istiyor, Sistem Ayarları’nı Aç ile"></td>
<td align="center" valign="top"><img src="../images/install/12a-screen-recording-off.webp" width="400" alt="Sistem Ayarları, Screen & System Audio Recording: HomePad’in yanındaki anahtar, hâlâ kapalı"></td>
</tr>
<tr>
<td align="center" valign="top"><img src="../images/install/13-screen-recording-settings.webp" width="390" alt="Sistem Ayarları, Screen & System Audio Recording, Çık ve Yeniden Aç mesajıyla"></td>
<td align="center" valign="top"><img src="../images/install/16-window-picker-prompt.webp" width="340" alt="macOS: HomePad sistemin özel pencere seçicisini atlayıp ekranınıza ve sesinize doğrudan erişmek istiyor"></td>
</tr>
</table>

- **Erişilebilirlik** (seçtiğiniz pencereye atlama ve çift dokunma kısayolu). **İzin Ver…**’i tıklayın, ardından mesajda **Sistem Ayarları’nı Aç**’ı tıklayın ve **HomePad**’in yanındaki anahtarı açın (istenirse parolanızı yazın). Daha yeni macOS’larda bu sayfanın adı, İngilizce arayüzde, **Device Control and Data Access**’tir.

<p align="center"><img src="../images/install/14-accessibility-settings.webp" width="480" alt="Sistem Ayarları, Device Control and Data Access: HomePad’in yanındaki anahtar"></p>

- **Tam Disk Erişimi** (Belgeler, Masaüstü ve İndirilenler’deki dosyaları bulma). **İzin Ver…**’i tıklayın; Sistem Ayarları, yanında küçük bir HomePad penceresiyle açılır. **HomePad**’in yanındaki anahtarı açın. Listede yoksa simgesini küçük pencereden listeye sürükleyin.

<p align="center"><img src="../images/install/15-full-disk-access-settings.webp" width="480" alt="Sistem Ayarları, Full Disk Access: HomePad’in yanındaki anahtar"></p>

**8. Kullanın.** **Option-Boşluk**’a (ya da seçtiğiniz kısayola) basın. Yukarıdaki üç mod dahil geri kalan her şey Ayarlar’dadır: menü çubuğundaki ızgara simgesine sağ tıklayın, ardından **Ayarlar…**’ı tıklayın.

## Nasıl kullanılır

- **Option-Boşluk** paneli açar ve kapatır (Ayarlar’dan değiştirilebilir) ya da Control, Option veya Command’a iki kez dokunun (Ayarlar → Açılış; Erişilebilirlik izni gerekir).
- **Etkin köşeler**: Ayarlar → Açılış → etkin köşeler. Küçük resimdeki dört köşeden herhangi birini tıklayın (bir tane, birkaç tane ya da hepsi). İşaretçiyi seçili bir köşede bir an bekletin, panel o köşede açılır; kapatmak için aynısını yapın. Köşeye hızlıca sürtmek ya da fare düğmesi basılıyken sürüklemek hiçbir şey yapmaz. Kısayol ve çift dokunma yine ortada açar. Kurulum Kılavuzu’nun ikinci adımında da vardır. macOS aynı köşeyi kendi eylemi için kullanıyorsa HomePad sizi uyarır; **macOS “Etkin Köşeler”i Aç…** düğmesi Sistem Ayarları → Masaüstü ve Dock’u Etkin Köşeler sayfası zaten görünür olarak açar (bu düğmeye basmak için Erişilebilirlik gerekir; yoksa yalnızca sayfa açılır).
- **Kategoriler**: uygulamalar adlandırılmış kategorilerde durur. **Temel** ilk sıradadır ve ilk açılışta Dock’unuzdan doldurulur; ayrıca Dock’un sağ ucu gibi Çöp Sepeti ve İndirilenler’i içeren bir **Dosyalar** kategorisi gelir (yalnızca ilk seferde; silerseniz silinmiş kalır). Kendinizinkileri (Tarayıcılar, Yazı…) **Kategori Ekle** ile ya da boş alana sağ tıklayarak ekleyin. Yeni bir kategori gri bir “Uygulamanızı buraya ekleyin” karosu gösterir. Yeniden adlandırmak ya da silmek için bir kategorinin içine sağ tıklayın (içindeki her şeyin de sabitlemesi kalkar; uygulamalara ve dosyalara dokunulmaz).
- **Dosya ve klasör ekleme**: **Dosya veya Klasör Ekle** (başlıktaki bağlantı, sağ tık menüsü ya da Ayarlar), bunları Finder’dan sürükleyin ya da bir arama sonucuna sağ tıklayın → Sabitle. Tıklayınca açılırlar; klasörler Finder’da açılır. Seçici, kenar çubuğu (Ev, Masaüstü, Belgeler, İndirilenler, ..., diskler) olan bir gezinme penceresidir ve Çöp Sepeti’nizi sabitleyen bir **Çöp Sepeti** girişi vardır. Kenar çubuğunda bir yere (Belgeler, İndirilenler, Çöp Sepeti ...) tıklamak orayı açar ve klasörün kendisini seçer, böylece **Ekle** hazır olur. Bu pencereler paneli engellemez: birini kenara çekin ve karolarından birini panele sürükleyin. Çöp Sepeti karosuna sağ tıklayıp **“Çöp Sepeti”ni boşalt…** seçin (önce sorar; HomePad, Dock gibi Finder’dan boşaltmasını ister, bu yüzden ilk seferde macOS HomePad’in Finder’ı denetleyip denetleyemeyeceğini sorar).
- **Kategori sırası**: bir kategorinin adı işaret edilince yeşile döner. Basın; satırın tamamı seçilir (yeşil dolgu ve çerçeve); sürükleyin, satırın kendisi sizinle birlikte hareket ederken diğerleri yer açmak için kayar (panel olduğu yerde kalır). Bırakın, orada kalır. Ya da bir kategorinin içine sağ tıklayıp **Yukarı Taşı** / **Aşağı Taşı**’yı seçin. Bir şey sürüklenirken üzerine gelme efektleri ve pencere önizlemeleri kapalıdır. “Temel” de taşınabilir; yeni öğeler için varsayılan yer olarak kalır ve silinemez. İnce gri çizgiler kategorileri ayırır.
- **Sağ tıkla ekle**: bir kategorinin içindeki boş alana (başlığa ya da karoların arasındaki ve sonrasındaki boşluklara) sağ tıklayın; menü *o* kategoriye ekler: “Dosyalar’a Uygulama Ekle…”, “Dosyalar’a Dosya veya Klasör Ekle…”, ayrıca onun için Kategori Ekle, Yeniden Adlandır ve Sil ile **Alfabetik Sırala** (kategorinin karolarını gösterdikleri adlara göre alfabetik dizer; zaten öyleyse grileşir; klasörlerinin içindeki karolar sırasını korur). Son bölümün altındaki boş alan o bölüme aittir.
- **Uygulama ekleme**: Uygulama Ekle düğmesi (seçicide bir uygulamaya çift tıklamak onu ekler ve seçiciyi kapatır), boş alana sağ tık, Finder’dan uygulama sürükleme (sürüklerken kısayola basın) ya da bir arama sonucuna sağ tık → Uygulamayı Sabitle.
- **Klasörler** (Windows’un Başlat menüsü gibi): bir karoyu başka bir karonun simgesinin ortasına sürükleyin, o simge yanana kadar yarım saniye orada tutun ve bırakın: ikisi o yerde “Klasör” adlı bir klasör olur; karosu ilk dört öğeyi gösterir. Eklemek için klasörün üstüne daha fazla karo bırakın. Klasörü tıklayarak panelin üstünde açın: yeniden adlandırmak için adı tıklayın, açmak için bir öğeyi tıklayın, sıralarını değiştirmek ya da klasörden çıkarmak için öğeleri sürükleyin (klasör kapanır, böylece öğeyi diğer karoların arasına bırakabilirsiniz). Esc ya da dışarıya tıklamak kapatır. Tek öğesi kalan klasör yine o öğe olur. Bir klasöre sağ tıklayıp “Klasörü Yeniden Adlandır…”, “Şuraya Taşı” ve “Grubu Çöz”ü seçin; açık bir klasördeki öğeye sağ tıklayıp “Klasörden Çıkar”ı seçin. Bir karonun kenarlarına (ortasına değil) sürüklemek yine yalnızca sırayı değiştirir.
- **Kaldırma / yeniden sıralama**: bir karoya sağ tık → Uygulamanın Sabitlemesini Kaldır / Şuraya Taşı ya da karoları sürükleyin; kategoriler arasında da.
- **Çalışan uygulamalar**: bir simgenin hemen altındaki (adın üstündeki) kırmızı çubuk uygulamanın çalıştığı anlamına gelir. Her pencerenin küçük resmini görmek için çalışan bir uygulamayı işaret edin (küçültülmüş olanın kapatma X’inin yanında bir eksi işareti vardır); tüm masaüstlerinde (Spaces), Mission Control sırasıyla ve bir uygulamanın birden fazlasında penceresi varsa “Space N” başlığıyla listelenir. Doğrudan oraya gitmek için birini tıklayın (gerekirse masaüstü değiştirilir) ya da yalnızca o pencereyi kapatmak için köşesindeki X’i tıklayın (diğer masaüstlerindeki pencerelerde de çalışır) (Ekran Kaydı ve Erişilebilirlik gerekir; Ekran Kaydı olmadan düz bir liste alırsınız). Çalışan bir uygulamayı tıklamak geçerli masaüstünü öne alır: orada görünen bir pencere uygulamayı öne getirir; oradaki tüm pencereleri küçültülmüşse en sonuncusu geri gelir; yalnızca orada hiç pencere yoksa sizi pencereleri olan başka bir masaüstüne götürür. **Çalışanlar** bölümü çalışan her uygulamayı listeler (sabitlenmiş olsun olmasın, Dock’un açık göstergeleri gibi); ona hiçbir şey eklenemez ya da çıkarılamaz, ama karoları **sıralarını değiştirmek için içinde sürüklenebilir** (siz birini taşıyana kadar alfabetik; sıra hatırlanır, çıkıp yeniden açılan uygulama için de; bir karo başka hiçbir yere bırakılamaz, Esc ya da başka bir yere bırakmak onu geri getirir; Çalışanlar’a sağ tık → **Alfabetik Sırala** sıranızı unutur) ve bölümün kendisi yeniden adlandırılamaz ama başlığından sürüklenerek (ya da sağ tık menüsündeki **Yukarı Taşı** / **Aşağı Taşı** ile) kategoriler arasında herhangi bir yere taşınabilir ve gizlenebilir (üzerine sağ tık → Çalışanlar’ı Gizle; geri getirmek için Ayarlar → Panel → Çalışanlar bölümünü göster). Her çalışan uygulamanın **küçültülmüş pencereleri** orada onun karosunu izleyip kendi karoları olarak görünebilir: köşesinde uygulama simgesi ve pencere başlığı olan pencerenin resmi (Dock’un gösterdiği gibi). O pencereyi geri getirmek için birini tıklayın; sağ tıkla Geri Yükle ya da Pencereyi Kapat. Varsayılan olarak kapalıdır: Ayarlar → Panel → Küçültülmüş pencereleri Çalışanlar’da göster’i açın ya da Çalışanlar’a sağ tık → Küçültülmüş Pencereleri Göster. Panel her açıldığında toplanırlar (Erişilebilirlik gerekir; resimler için Ekran Kaydı gerekir).
- **Çalışan uygulama menüsü**: Dock’takine benzer bir menü için çalışan bir uygulamaya sağ tıklayın: pencereleri (öndeki işaretli; öne getirmek için birini seçin), Dosya menüsündeki “Yeni …” komutları (bir tarayıcıda Yeni Sekme, Yeni Pencere, Yeni Gizli Pencere), ardından **Pencereleri Kapat** (yalnızca açık bir pencere varsa), **Gizle** ve **Çık** (zorla çıkmak için Option’a basılı tutun; Çık’tan birkaç saniye sonra hâlâ çalışan bir uygulamada bunun yerine **Zorla Çık** çıkar; Dock’ta olduğu gibi Finder’da Çık yoktur, çünkü çıkması masaüstü simgelerini kaldırır). Pencereler ve komutlar, işaretçi karoya ulaştığında Erişilebilirlik ile okunur.
- **Dosya bulma**: Belgeler, Masaüstü ve İndirilenler’deki dosyalar, HomePad’in **Tam Disk Erişimi** olduğunda (Sistem Ayarları → Gizlilik ve Güvenlik) aramada görünür. O zamana kadar sonuçlar, anahtara bağlantı veren bir uyarı gösterir.
- **Hesap makinesi**: `7+3`, `(2+3)*4`, `2^10` ya da `15%` gibi bir işlem yazın, yanıt en başta görünür. ↩ ya da kopyala düğmesi onu kopyalar.
- **Pencere**: yeniden boyutlandırmak için panelin herhangi bir kenarını ya da köşesini sürükleyin (kenarların tutması kolay geniş şeritleri vardır ve yeniden boyutlandırma imleçleri gösterir) ya da taşımak için herhangi bir boş yeri sürükleyin (karo ızgarasının kendisini değil; orada sürüklemek karoları yeniden düzenler). Arama alanı panel her açıldığında odaktadır, böylece hemen yazabilirsiniz; başka bir yere tıkladıktan sonra basacağınız sonraki tuş ona geri döner. Ayarlar → Panel’de **Pencere boyutunu hatırla** (varsayılan olarak açık) ve **Pencere konumunu hatırla** (varsayılan olarak kapalı) vardır. Ayarlar dişlisinin yanındaki ↺ düğmesi paneli varsayılan boyuta, ortalanmış olarak geri getirir. Uygulama Ekle ve Dosya veya Klasör Ekle pencereleri de yeniden boyutlandırılabilir (her zaman varsayılan boyutta açılırlar).
- Panelin sol alt köşesindeki **adınız**, Sistem Ayarları’nı Apple Hesabınızda açar.
- **Arama**: yazmaya başlamanız yeter. Önce uygulamalar, sonra belgeler ve klasörler, sonra bir web araması gelir. Seçmek için ↑ ↓, açmak için ↩, Finder’da göstermek için ⌘↩, temizlemek ve sonra kapatmak için Esc. ‹ düğmesi ya da boş alana tıklamak da sizi uygulamalarınıza geri götürür.

## İlk açılış

Bir karşılama penceresi Ekran Kaydı, Erişilebilirlik ve Tam Disk Erişimi’ne izin vermenizi ve HomePad’i nasıl açacağınızı seçmenizi ister (bkz. Kurulum). İstediğiniz zaman menü çubuğu simgesi → Kurulum Kılavuzu… ile yeniden açın.

## Ayarlar

Ayarlar’ın araç çubuğunda altı sekmesi vardır: **Mod**, **Genel** (dil, menü çubuğu simgesi, oturum açılışında başlatma, Varsayılanlara Sıfırla, Baştan Başla), **Görev çubuğu**, **Açılış** (kısayol, çift dokunma, etkin köşeler), **Panel** (yerleşim, pencere, öğeler) ve **İzinler**. En son kullandığınız sekmede yeniden açılırlar.

- **Kısayol**: düğmeyi tıklayın ve yeni bir tuş birleşimine basın. ⌘Boşluk’u kullanmak için önce Sistem Ayarları → Klavye → Klavye Kestirmeleri → Spotlight’tan Spotlight kısayolunu kapatın.
- **Kısayol**: birini kaydedin, yalnızca çift dokunma istiyorsanız **Yok**’u seçin ya da ⌥Boşluk’a dönmek için **Sıfırla**’yı seçin.
- **Menü çubuğu simgesi**: Ayarlar → Genel onu gizleyebilir. Uygulamayı yeniden açmak paneli açar.
- **Varsayılanlara Sıfırla**: kısayolu, çift dokunmayı, yerleşimi, Dock’u gizlemeyi ve oturum açılışında başlatmayı geri yükler (uygulamalar ve kategoriler korunur).
- **Çift dokunma**: Control, Option veya Command’a iki kez dokunarak açın.
- **Satır başına simge** (varsayılan 8, 4–10), **satır yüksekliği** (simge satırları arasındaki uzaklık, varsayılan 101 pt, 85–125) ve **simge aralığı** (simgeler arasındaki yatay boşluk, varsayılan 10 pt, 0–40; panel boşluk için çok dar olduğunda önce boşluk, sonra simgeler küçülür): bir sayı yazın ya da − / + tıklayın, **çalışan uygulamaları göster**, **Dock’tan yeniden içe aktar**.
- **Mod** (ilk sekme):
  - **Bağımsız** (varsayılan): kısayol, çift dokunma, etkin köşeler ya da menü çubuğu simgesiyle açılan yüzen panel. Buna geçmek Dock’u gizler; aşağıdaki **“Dock”u gizle** onu geri getirir.
  - **HomePad + “Dock”**: Dock’un görev çubuğu olduğu, Windows’un Başlat menüsü gibi bir akış. Bunu seçmek Dock’u her zaman gösterir (otomatik gizlemeyi, HomePad’inkini ya da Sistem Ayarları’nınkini kapatır) ve yoksa HomePad’i ona ekler (Dock bir kez yeniden başlar); Dock koyduğunuz yerde kalır. Panel, simgeyi tıklasanız da kısayolu ya da çift dokunmayı kullansanız da HomePad simgesinin hemen yanında açılır (alttaki bir Dock için üstünde, yandaki bir Dock için yanında, ekranın içinde); simgeyi yeniden tıklamak onu kapatır. Etkin köşeler yine kendi köşelerinde açar. HomePad Dock’ta olmadığında, Dock gizliyken ya da Erişilebilirlik izni eksikken panelin neden ortada açıldığını Ayarlar söyler.
  - **Görev çubuğu**: ana ekranın alt kenarı boyunca Windows tarzı bir görev çubuğu: bir Başlat düğmesi (HomePad simgesi), ardından üstüne sabitlediğiniz öğeler ve çalışan uygulamalar, ortalanmış olarak. Çalışan uygulamalar bu durumda panelden ayrılır. Uygulamaları, dosyaları ve klasörleri çubuğun boş alanına (**Uygulama Ekle…**, **Dosya veya Klasör Ekle…**) ya da bir karoya (**Görev çubuğuna sabitle**; HomePad panelinde de) sağ tıklayarak sabitleyin. Bir görev çubuğu simgesinin menüsünde HomePad’in kendi kategorileri için **HomePad’e sabitle** (ya da HomePad’den kaldır) de vardır. Ya da uygulamaları, dosyaları ve klasörleri Finder’dan ya da HomePad panelinden çubuğa sürükleyin: bıraktığınız simgenin önüne ya da boş alana bırakırsanız sona sabitlenirler (zaten sabitlenmiş olan oraya taşınır; panel kendininkileri tutar). Görev çubuğunun sabitlenmiş öğeleri, HomePad kategorilerinden ayrı, kendi listesidir. Sıralarını değiştirmek için simgeleri çubuk boyunca sürükleyin. **Uygulama simgeleri** **Orta**da ya da **Sol**dadır; ortadayken **HomePad simgesi** onlarla birlikte ortada ya da solda olabilir (uygulama simgeleri soldayken her zaman soldadır, bu yüzden seçenek grileşir). Arapça ve Farsça’da sol, sağdır; Windows’taki gibi yansıtılmış. HomePad simgesi soldayken paneli, görev çubuğunun üstünde sol kenarda açılır. Sağda **ağ**, **ses**, **pil** ve **saat** vardır; her birinin bir anahtarı bulunur: ağ ve pil Sistem Ayarları’nda kendi sayfalarını açar (macOS’un kendi durum menüleri yeni macOS’larda dışarıdan açılamaz), ses bir kaydırıcı açar (sesi değiştirmek için üzerinde kaydırın), saat bir takvim açar. Bir öğeyi açmak ya da öne getirmek (zaten öndeyse gizlemek) için tıklayın; pencerelerini görmek için çalışan bir uygulamayı işaret edin; menüsü için sağ tıklayın. Ayarlar → Görev çubuğu → **Çalışan uygulamalar** (başta kapalı) çalışan her uygulamayı bir **Görev çubuğunda göster** anahtarıyla listeler; kapatılan bir uygulama çalıştığı sürece çubuğun dışında kalır (menüsünde **Görev çubuğundan gizle** de vardır). Sabitlenmiş öğeler her zaman gösterilir. Bir uygulamayı gizlemek (Cmd-H) çubuğu değiştirmez. Panel, görev çubuğunun üstünde ortalanarak açılır. Dock bu arada gizlidir. macOS yalnızca Dock’un pencereleri ekranın bir bölümünün dışında tutmasına izin verir; bu yüzden Erişilebilirlik ile HomePad, bir pencere açıldığında, yeniden boyutlandırıldığında, büyütüldüğünde ya da döşendiğinde görev çubuğunun altına uzanıyorsa onu kısaltır (çok kısa kalacaksa onun yerine yukarı taşır). Oraya yalnızca sürüklenen bir pencereye dokunulmaz, Windows’taki gibi. (Gerçek Dock’u çubuğun altında tutmak işe yaramadı: işaretçi simgelerinin üzerinden geçtiği her yerde ad etiketlerini gösteriyor.) **Görev çubuğunu otomatik gizle**, işaretçi alt kenarda **Gösterilmeden önceki gecikme** kadar (0–1000 ms, varsayılan 300; kenara hızlıca sürtmek onu göstermesin diye) bekleyene kadar çubuğu ekranın altına kaydırır; HomePad paneli, bir açılır pencere, bir pencere önizlemesi ya da bir menü açıkken görünür kalır ve pencereler o zaman ekranın tamamını kullanır. **HomePad’i yalnızca Başlat düğmesiyle aç**, kısayolu, çift dokunmayı ve etkin köşeleri kapatır (menü çubuğu simgesi çalışmaya devam eder).
- **“Dock”u gizle** (yalnızca Bağımsız modda): Dock’un otomatik gizlemesini 1000 saniyelik gecikmeyle açar, böylece hiç görünmez. Kapatmak normal Dock’u geri yükler.
- **Oturum açılışında başlat**.
- **Dil** (Ayarlar → Genel ya da menü çubuğu simgesine sağ tık → Dil): Mac ile aynı ya da 20 dilden biri (Almanca, Arapça, Bengalce, Çince (Basitleştirilmiş), Endonezce, Farsça, Filipince, Fransızca, Hintçe, İngilizce, İspanyolca, İtalyanca, Japonca, Korece, Portekizce (Brezilya), Rusça, Tayca, Teluguca, Türkçe, Vietnamca), geçerli dilde alfabetik olarak listelenir. HomePad yeni dilde yeniden başlar; Arapça ve Farsça sağdan sola düzenlenir. Uygulama, klasör ve Sistem Ayarları bölümü adları Mac’in gösterdiği gibi kalır.

## İzinleri ayarlama

Bir izin verdiğinizde (Kurulum Kılavuzu’nda, Ayarlar’da ya da bir pencere önizlemesinde), HomePad onu Sistem Ayarları’nda açıp açmadığınıza bakar ve açar açmaz öne geri gelir. Ekran Kaydı ve Tam Disk Erişimi genellikle yeniden başlatma gerektirir: Sistem Ayarları **Çık ve Yeniden Aç**’ı sunduğunda HomePad çıkar, kendiliğinden yeniden başlar ve bulunduğunuz pencereyi yeniden açar.

Kurulum Kılavuzu ilk açılışta yalnızca bir izin eksikse görünür. Baştan yeniden geçmek için **Ayarlar → Genel → Baştan Başla…** kullanın: macOS HomePad’in izinlerini geri alır, kılavuz yeniden görünür ve HomePad yeniden başlar (yeni bir kurulum gibi kategorilerinizi ve ayarlarınızı da unutmak için kutuyu işaretleyin).


## Geliştirme

Derleme talimatları, çevirilerin nasıl çalıştığı, dosya listesi ve uygulama simgesi yalnızca [İngilizce README](../../README.md#development) dosyasında yer alır.

## Lisans

[MIT](../../LICENSE).
