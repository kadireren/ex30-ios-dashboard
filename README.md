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

## Dogrulama

```sh
xcodebuild -project EX30iPhoneDashboard.xcodeproj \
  -scheme EX30iPhoneDashboard \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```
