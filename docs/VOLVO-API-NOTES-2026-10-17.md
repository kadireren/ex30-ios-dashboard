# Volvo API — çalışma notları (17 Ekim 2026)

## Amaç ve mevcut karar

iOS dashboard'a otomatik yolculuk mesafesi, aracın hesapladığı ortalama tüketim ve mümkünse brüt tüketim, geri kazanım ve net enerji eklemek araştırılıyor. Eski Android ex30dashboard projesinde güçten hesaplanan trip ortalaması araçla eşleştirilememiş; durma ve trip sıfırlama davranışları sorun olmuştu. Öncelik, mümkün olan alanlarda aracın kendi değerlerini kullanmak.

Bu aşamada yalnızca araştırma ve salt okunur API testi yapıldı. iOS uygulamasına Volvo API entegrasyonu eklenmedi. Kullanıcı çalışmayı burada durdurup sonra devam etmek istedi.

## Gerçek EX30 testi — doğrulanan sonuç

Kullanıcının hazırladığı VCC API anahtarı, Connected Vehicle test access token'ı ve VIN ile aşağıdaki iki GET isteği HTTP 200 döndü:

- `https://api.volvocars.com/connected-vehicle/v2/vehicles/{vin}/statistics`
- `https://api.volvocars.com/connected-vehicle/v2/vehicles/{vin}/odometer`

Dönen değerler:

- `averageEnergyConsumptionAutomatic`: 18.200000762939453 kWh/100km (gösterim: 18,2).
- `tripMeterAutomatic`: 2,9 km.
- `averageSpeedAutomatic`: 22 km/h.
- `tripMeterManual`: 2703,6 km.
- `distanceToEmptyBattery`: 259 km.
- `odometer`: 5572 km.
- `averageEnergyConsumption`, `averageEnergyConsumptionSinceCharge` ve `averageSpeed`: null. Null alanlar sıfır olarak yorumlanmamalı.

### Zaman damgaları hakkında kullanıcı düzeltmesi

Otomatik ortalama tüketim zamanı: `2026-10-17T13:21:19.038277112Z` (Türkiye 16:21:19).
Trip mesafesi, ortalama hız ve kilometre zamanı: `2026-10-17T08:38:40.724949Z` (Türkiye 11:38:40).

Kullanıcı, bunun son yaptığı yolculuk olduğunu ve aracın o saatten beri otoparkta bulunduğunu açıkladı. Bu nedenle mesafenin son sürüş saatinde kalması normaldir. Farklı alan zaman damgaları tek başına hata veya farklı yolculuk kanıtı sayılmamalı. Önceki “bu değerler birlikte kullanılamaz” yorumu fazla kesindi ve düzeltildi. Yine de API'nin alan zaman damgası, sorgu zamanı ve yolculuk sınırı birbirine karıştırılmamalı.

`18,2 × 2,9 / 100 ≈ 0,528 kWh` yalnızca ortalama ve mesafeden türetilen yaklaşık enerjidir; API'den doğrudan alınmış net/brüt enerji toplamı olarak sunulmamalı.

## Belgeler ve kapsam

- Energy API v2: https://developer.volvocars.com/apis/energy/v2/overview/
- Connected Vehicle API v2: https://developer.volvocars.com/apis/connected-vehicle/v2/overview/
- Trip istatistikleri: https://developer.volvocars.com/apis/connected-vehicle/v2/endpoints/statistics/
- Energy capabilities: https://developer.volvocars.com/apis/energy/v2/endpoints/capabilities/
- Energy state: https://developer.volvocars.com/apis/energy/v2/endpoints/energy-state/
- Test token oluşturma: https://developer.volvocars.com/apis/docs/test-access-tokens/#my-volvo-car
- Yetkilendirme: https://developer.volvocars.com/apis/docs/authorisation/

Web metin aracı bu belgeleri oturum hatasıyla getirdi, ancak tarayıcıda oturum açmadan belge içerikleri okunabildi. Aynı erişim hatası yeniden olursa belgelerin mutlaka giriş gerektirdiği sonucuna varma.

Connected Vehicle `/statistics`, araç tarafından hesaplanan otomatik ortalama tüketimi, otomatik/manüel trip sayaçlarını ve diğer istatistikleri sunuyor. İzin: `conve:trip_statistics`. Bunlar son istatistik değerleridir; incelenen uçta geçmiş yolculuk listesi, yolculuk kimliği veya başlangıç/bitiş kaydı yok.

Energy API v2, son enerji/şarj durumunu verir. EX30 desteklenen modeller arasında. `/capabilities` için `energy:capability:read`, `/state` için `energy:state:read` gerekir. Şarj gücü `chargingPower`, sürüş sırasındaki batarya gücü değildir. Alan desteği capabilities ve gerçek yanıtla kontrol edilmeli; dokümanda `chargingCurrentLimit` EX30 için desteklenmiyor.

Kullanıcının sağladığı `/Users/kadireren/Downloads/energy-api-specification.json` incelendi: OpenAPI 3.0.1, Energy API v2, yalnızca `/vehicles/{vin}/capabilities` ve `/vehicles/{vin}/state` GET uçları var. SOC, menzil, şarj durumu vb. modeller içeriyor; trip mesafesi, ortalama sürüş tüketimi, brüt enerji veya rejenerasyon toplamı içermiyor. OAuth adresleri/yenileme akışı ve gerçek kullanıcı kimlik bilgileri bu dosyada yok.

## Aximote incelemesinden çıkarımlar

Kullanıcı Aximote'ta Volvo ID ile giriş yaptığını belirtti. Aximote'un resmi açıklamaları hem araç içi Android Automotive telemetrisi hem üretici hesabı bağlantısı kullandığını gösteriyor. Volvo ID bağlantısı, tüm ayrıntılı sürüş verilerinin Volvo bulut API'sinden hazır geldiğini kanıtlamıyor; kullanılan Volvo uçları doğrulanmadı.

Kullanıcının `/Users/kadireren/Downloads/IMG_8840.MOV` videosunda: 16,9 km, 31 dakika, 5,4 kWh brüt tüketim, 2,5 kWh geri kazanım, 2,9 kWh net tüketim ve 17,2 kWh/100 km ortalama görüldü. Canlı güç/ivme, rota ve hız/enerji grafikleri de var. Menüde bir alanın bulunması EX30 üzerinde gerçekten okunabildiğini kanıtlamaz.

Resmi kaynaklar:

- https://aximote.com/en/compare/volvo-cars-app-alternative
- https://aximote.com/en/app-privacy-policy (üretici hesabı bağlantısı: bölüm 4.5)
- https://api.aximote.com/v3/api-docs/public-v1

## Devam ederken yapılacaklar

1. Connected Vehicle v2 OpenAPI dosyasını incele; mevcut gerçek yanıtla modelleri karşılaştır.
2. Yeni bir sürüş öncesinde ve sonrasında `/statistics` ile `/odometer` değerlerini karşılaştır. Otomatik trip sayacı hangi koşulda sıfırlanıyor, ne zaman buluta güncelleniyor, araç ekranındaki hangi sayaçla eşleşiyor doğrula.
3. Araç durunca, P'ye geçince veya Bluetooth kopunca uygulama tripini otomatik sıfırlama yaklaşımını tekrarlama. Yolculuk sınırı ve kalıcı kayıt davranışını doğrulanmış araç davranışına göre tasarla.
4. İlk entegrasyon adayı: “Volvo otomatik trip mesafesi / ortalama tüketimi”. API kaynağını, alan güncelleme zamanını ve son sorgu zamanını sakla; desteklenmeyen alanları boş göster.
5. İncelenen iki API'de brüt tüketim ve geri kazanım toplamı bulunmadı. Başka resmi kaynak olup olmadığını araştır; bulunamazsa OBD/VHAL hesabını ayrı ölçüm olarak sun, Volvo'dan alınmış gibi etiketleme.
6. Güçten enerji hesabı yapılırsa ham güç kullanılmalı; SMOOTH ve ±99,9 tüketim gösterim sınırı enerji entegrasyonuna uygulanmamalı.
7. Sürekli kullanım için OAuth giriş/yenileme akışını araştır. Mevcut test token'ının kalıcı veya hâlâ geçerli olduğunu varsayma. VCC API key ve VIN de gerekli; bunları repoya veya günlüklere ekleme.

## Yerel test araçları ve gizlilik

Bu oturumda geçici pencere `/tmp/ex30_volvo_readonly_test.py` ile açıldı. Anahtar/token yalnızca bellekte kullanıldı; diske kaydedilmedi. Maskelenmiş test sonucu `/tmp/ex30-volvo-api-test.json` dosyasına yazıldı. Bu geçici dosyaların gelecekte varlığını varsayma. Repoya token, API anahtarı, VIN veya ham sürüş kaydı eklenmedi.

## Bağımsız mevcut değişiklik

Bu konuşmada daha önce iOS anlık tüketimine Android SMOOTH profili eklendi; değişiklikler çalışma ağacında. Telemetri regresyon testleri ve tüm uygulamanın doğrudan Swift tip kontrolü geçti. Xcode hedef seçimi hatası nedeniyle tam Xcode derlemesi ve fiziksel araç/telefon çalışması doğrulanmadı. Telefon kayıtlarında iOS 27.0; harici diskte cihaz desteği mevcut. Yeni kurulum yapılmadı. Bu Volvo API notu bu kod değişikliklerini değiştirmez.
