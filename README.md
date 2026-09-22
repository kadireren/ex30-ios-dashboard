# EX30 iPhone Dashboard

Volvo EX30 icin iPhone uzerinde calisan, CrowPanel dashboard ile ayni veri
kaynaklarini kullanan native SwiftUI gosterge uygulamasi.

## Veri yolu

```text
EX30 VHAL -> ex30-vhal-bridge -> BLE GATT -> iPhone
EX30 OBD  -> IOS-Vlink BLE ----------------> iPhone
```

- VHAL protokol surumu: `1`
- VHAL servis UUID: `7d2f0001-8d3b-4a6c-9f21-6a9b4e303001`
- OBD servis UUID: `18F0`
- Uygulama acikken ekran uyumaz; arka plana gecince normal iOS davranisi geri gelir.
- Telefonun sistem otomatik parlakligina mudahale edilmez.
- Saga/sola kaydirma: Ana, Performans, Batarya ve Teknik sensor sayfalari.
- Ana tema secenekleri: Minimal, Sport 1 ve Sport 2. ODO her temada alt ortadadir.
- Ayarlardan yan sayfalardaki sensorlerin gorunurlugu degistirilebilir.

## Calistirma

1. `EX30iPhoneDashboard.xcodeproj` dosyasini Xcode ile acin.
2. Signing & Capabilities altinda kendi Apple gelistirici takiminizi secin.
3. Fiziksel iPhone'u hedefleyip Run'a basin.
4. Bluetooth iznini onaylayin.

Simulator arayuzu gosterebilir ancak Bluetooth baglantilarini dogrulamaz.

## Sensor referanslari ve davranis notlari

- OBD ECU/DID, decoder ve canli dogrulama bilgisi icin once komsu
  `../ex30-sensor-lab` reposuna bak: `docs/DISCOVERY_MEMORY.md`,
  `app/src/main/java/com/kadireren/ex30sensorlab/obd/ObdCatalog.kt` ve `ObdDecoders.kt`.
- Electrocrow/CrowPanel referansi `../ex30-crowpanel-dashboard`
  (`kadireren/ex30-crowpanel-dashboard`): `src/model.cpp`, `src/scheduler.cpp`,
  `src/obd_decoder.cpp`. Referans almadan once uzak depoya gore guncelligini kontrol et.
- Gaz pedali: VCFRONT `22E301`, ilk veri byte'i 0–100 PWM. Birakilmis
  pedal yaklasik 7 olabilir; bunu gercek pedal yuzdesi diye sifira normalize etme.
- `Gosterge SOC` VHAL'de batarya seviyesi/kapasitesi oranidir. OBD yedegi
  BECM `224801` ham SOC (`u16/500`) uzerinden `hamSOC × 1.0625 − 3.125`
  formuluyle 0–100 araligina sinirlanir. Sensor Lab ve CrowPanel'de dogrulanan
  gosterge degeri budur; ham BECM SOC ana ekranda dogrudan gosterilmez.
- Ana ekrandaki SOC tam sayiya yuvarlanir. Batarya yan sayfasindaki `BECM ham SOC`
  karti OBD `224801` ham degerini uc ondalikla gosterir; VHAL'den beslenmez.
  Iki gorunum ayni OBD sorgusunu paylasir; kullanilmayan sayfada sorgulanmaz.
- OBD ve VHAL son degerleri kaynak basina ayri saklanir. Bagli ve son 3 saniyede
  veri gondermis VHAL onceliklidir; aksi halde saklanan OBD degeri kullanilir.
  OBD degeri yoksa son VHAL degeri korunur. Baglanti kaybi veya sorgu araligi
  nedeniyle deger `--` olmaz; `--` henuz hic deger alinmadigini belirtir.
  Degerler uygulama belleginde tutulur; yeniden acilista diskten yuklenmez.
- Batarya gucu OBD HV akim × voltaj / 1000; mekanik guc RPM × tork / 9549.3
  × 1.35962 ile hesaplanir. Girdilerin son degerleri sorgular arasinda korunur.
- 2026-09-22: CrowPanel `5231bf8`, `git pull --ff-only` ile guncel dogrulandi.
  iOS sorgu araliklari (basarili yanittan sonraki bekleme):
  100 ms hiz/pedal/HV akim/RPM/tork; 500 ms HV voltaj; 1 s SOC;
  2 s motor sicakligi/sarj ve desarj guc limitleri;
  5 s sogutma/batarya sicakliklari/hucre voltajlari/minimum hucre SOC/valfler;
  10 s SOH/ODO/12 V. Basarisiz sorgu 1 s sonra yeniden siraya girer.
  Tek seri komut kanali ve ECU hazirlik komutlari nedeniyle bunlar garanti Hz degildir.
  Yalnizca secili sayfada ve temada gosterilen, ayarlarda acik sensorler sorgulanir.
  Ana ekranda Minimal hiz/guc/SOC/ODO/menzil; Sport temalari bunlara tork ve
  mekanik guc ekler. Yan sayfalarda sadece o sayfanin sensorleri okunur. Gorunur batarya gucu
  HV akim/voltaj, gorunur mekanik guc RPM/tork sorgularini etkin tutar.
  VHAL abonelik paketi de gorunurluk degisince bridge'e guncellenir.
  Sayfa, tema veya gorunurluk degisince OBD listesi ve VHAL aboneligi yenilenir.
  Halihazirda gonderilmis tek bir OBD sorgusunun yaniti tamamlanabilir; ardindan
  eski sayfa icin yeni sorgu gonderilmez. Onceki sayfanin son degerleri bellekte kalir.
  Siralama: en eski sorgu zamani, esitlikte oncelik, mevcut ECU, daha kisa aralik.

## Dogrulama

Bluetooth gerektirmeyen kaynak gecisi, deger koruma ve pedal decoder regresyonlari:

```sh
swiftc EX30iPhoneDashboard/Telemetry/TelemetryModels.swift \
  EX30iPhoneDashboard/Telemetry/TelemetryResolver.swift \
  EX30iPhoneDashboard/Telemetry/OBDDecoder.swift \
  Tests/TelemetryRegressionTests.swift -o /tmp/ex30-telemetry-tests
/tmp/ex30-telemetry-tests
```

```sh
xcodebuild -project EX30iPhoneDashboard.xcodeproj \
  -scheme EX30iPhoneDashboard \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```
