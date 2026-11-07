# Issiqlik Ta'minoti

[Русский](README.md) · [O'zbekcha](README_UZ.md) · [English](README_EN.md)

Qozonxona xodimlari uchun Flutter ilovasi: uskunalar, hodisalar jurnali, yo‘riqnomalar, smenalar va shaxsiy ilova bildirishnomalari. O‘zbek kirill/lotin interfeysi, saqlanadigan til va yorug‘/qorong‘i mavzu, moslashuvchan Liquid Glass navigatsiyasi.

## Hozirgi holat (1.2.1)

- Firebase Auth va Firestore Rules asosidagi Spark rejimi. Asosiy matnli amallar uchun Blaze yoki Cloud Functions shart emas.
- **Har bir yangi hisob member/pending bo‘ladi.** Birinchi administratorni vakolatli operator aniq tekshirilgan Auth UID bo‘yicha tayinlaydi. Birinchi ro‘yxatdan o‘tgan foydalanuvchi avtomatik admin bo‘lmaydi.
- Ruxsatlar `access/{uid}` orqali server qoidalarida tekshiriladi. Shaxsiy profil va xodimlar katalogi ajratilgan.
- Jurnal o‘zgarishlari o‘zgarmas tarix bilan saqlanadi. Ma’lumotnomalar va smenalarni faqat admin arxivlaydi; ilovadan jismoniy o‘chirish taqiqlangan. Oldingi hujjat arxiv tarixida qoladi.
- Bildirishnoma faqat aniq oluvchiga ko‘rinadi. Fon push, maxfiy fayl yuklash va ilovadan boshqa foydalanuvchi parolini tiklash bu Spark versiyasida yo‘q.
- Til va mavzu SharedPreferences’da saqlanadi, parol va vakolatlar saqlanmaydi. Maxfiy Firestore ma’lumotlarining doimiy disk keshi o‘chirilgan.
- Noto‘g‘ri hujjat butun ro‘yxatni buzmaydi: ogohlantirish bilan tashlab ketiladi. Noto‘g‘ri vakolatlar esa doimo rad etiladi.

## Ishga tushirish va tekshirish

Flutter 3.47.6 / Dart 3.13+, Android SDK, Node 24.12+ va emulyatorlar uchun Java 21 kerak.

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test
npm ci --ignore-scripts
npm run test:security
npm run test:operator
flutter build apk --release --obfuscate --split-debug-info=build/symbols/1.2.1
```

Windows’da desktop symlink huquqi bo‘lmasa Git Bash Flutter buyruqlariga `FLUTTER_WINDOWS=false FLUTTER_LINUX=false` qo‘shing. `pub get` xatosidan keyin `--no-pub` bilan davom etmang: Android plagin registratori yaratilishi shart.

Release uchun maxfiy tashqi keystore va Git’dan chiqarilgan `android/key.properties` kerak. Release debug kalitga avtomatik qaytmaydi. CI faqat aniq belgilangan debug/test APK yig‘adi; haqiqiy imzo kaliti CI’ga berilmaydi. CI’da majburiy Gitleaks tarix/manba skani ham bor.

## Firebase va operator

Egasi ilgari o‘zi tanlagan admin hisobini tasdiqlagan; uning UID/email’i kodga yozilmagan. Yangi muhit yoki qayta tayyorlash uchun ADC asosidagi [operator qo‘llanmasi](security/OPERATOR.md) va `tools/operator.cjs` dan foydalaning: avval dry-run, so‘ng aniq loyiha/UID/profil/vakolat tasdig‘i va maxfiy backup.

Eski ma’lumotlarni tekshirmasdan Rules almashtirmang. `allow read, write: if true` ochmang. Blokdan chiqarilgan foydalanuvchi qayta kirishi kerak; session cutoff orqaga surilmaydi. Eski bildirishnomalar uchun oluvchilarni taxmin qilmaydigan alohida migratsiya rejasi mavjud.

Eski seed ma’lumotlari va sxemalar maxfiy nusxaga saqlanib, joriy Git daraxtidan olib tashlangan. Bu eski Git history yoki tarqalgan APK nusxalarini yo‘q qilmaydi.

[Cheklovlar va xavfsizlik](security/README.md) · [Ma’lumotlar shartnomasi](security/contract.md)

Android asosiy sozlangan platforma. Boshqa platformalar alohida Firebase sozlash va qurilmada tekshirishni talab qiladi. App Check enforcement, API-key cheklovlari, kvotalar va native kutubxonalar xavfsizligi build muvaffaqiyatining o‘zi bilan kafolatlanmaydi.

Litsenziya: [MIT](LICENSE).
