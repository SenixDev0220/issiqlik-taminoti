class AppL10n {
  final String lang;
  const AppL10n._(this.lang);
  static AppL10n of(String lang) => AppL10n._(lang);
  bool get isCyrl => lang == 'uz_cyrl';

  String get appName => "Issiqlik Ta'minoti";
  String get companyName => "Issiqlik Ta'minoti";
  String get employeeApp => isCyrl ? 'Ходимлар учун корпоратив илова' : 'Xodimlar uchun korporativ ilova';
  String get startupLoading => isCyrl ? 'Илова юкланмоқда...' : 'Ilova yuklanmoqda...';
  String get startupError => isCyrl ? 'Сеансни юклаб бўлмади. Қайта уриниб кўринг.' : 'Seansni yuklab bo\'lmadi. Qayta urinib ko\'ring.';
  String get retryButton => isCyrl ? 'Қайта уриниш' : 'Qayta urinish';
  String get syncChecking => isCyrl ? 'Синхронизация ҳолати текширилмоқда' : 'Sinxronlash holati tekshirilmoqda';
  String syncOffline(int count) => count > 0
      ? (isCyrl
          ? 'Сервер билан алоқа йўқ — $count та ўзгариш кейин юборилади'
          : 'Server bilan aloqa yo\'q — $count ta o\'zgarish keyin yuboriladi')
      : (isCyrl
          ? 'Сервер билан алоқа тасдиқланмади — кэш маълумотлари кўрсатилмоқда'
          : 'Server bilan aloqa tasdiqlanmadi — kesh ma\'lumotlari ko\'rsatilmoqda');
  String syncPending(int count) => isCyrl
      ? 'Синхронизация кутилмоқда: $count та ўзгариш'
      : 'Sinxronlash kutilmoqda: $count ta o\'zgarish';
  String get syncError => isCyrl
      ? 'Айрим маълумотлар серверга қабул қилинмади. Ҳуқуқни текшириб, қайта сақланг.'
      : 'Ayrim ma\'lumotlar serverga qabul qilinmadi. Ruxsatni tekshirib, qayta saqlang.';

  String get loginTitle => isCyrl ? 'Тизимга кириш' : 'Tizimga kirish';
  String get loginSubtitle => isCyrl ? 'Логин ва паролни киритинг' : 'Login va parolni kiriting';
  String get loginLabel => isCyrl ? 'Логин' : 'Login';
  String get loginHint => isCyrl ? 'Логинингизни киритинг' : 'Loginingizni kiriting';
  String get passwordLabel => isCyrl ? 'Парол' : 'Parol';
  String get passwordHint => isCyrl ? 'Паролингизни киритинг' : 'Parolingizni kiriting';
  String get loginButton => isCyrl ? 'Кириш' : 'Kirish';
  String get loginEmptyError => isCyrl ? 'Логин бўш бўлиши мумкин эмас' : 'Login bo\'sh bo\'lishi mumkin emas';
  String get passwordEmptyError => isCyrl ? 'Парол бўш бўлиши мумкин эмас' : 'Parol bo\'sh bo\'lishi mumkin emas';
  String get loginWrongError => isCyrl ? 'Логин ёки парол нотўғри' : 'Login yoki parol noto\'g\'ri';
  String get loginPendingError => isCyrl ? 'Ҳисобингиз тасдиқланишини кутинг' : 'Hisobingiz tasdiqlanishini kuting';
  String get noAccount => isCyrl ? 'Ҳисобингиз йўқми?' : 'Hisobingiz yo\'qmi?';
  String get registerLink => isCyrl ? 'Рўйхатдан ўтиш' : 'Ro\'yxatdan o\'tish';

  String get forgotPassword => isCyrl ? 'Паролни унутдингизми?' : 'Parolni unutdingizmi?';
  String get resetInstructions => isCyrl ? 'Логинингизни киритинг.' : 'Loginingizni kiriting.';
  String get resetButton => isCyrl ? 'Паролни тиклаш' : 'Parolni tiklash';
  String get resetEmailSent => isCyrl ? 'Хат юборилди!' : 'Xat yuborildi!';
  String get resetEmailHint => isCyrl ? 'Электрон почтангизни текширинг.' : 'Elektron pochtangizni tekshiring.';

  String get registerTitle => isCyrl ? 'Рўйхатдан ўтиш' : 'Ro\'yxatdan o\'tish';
  String get registerSubtitle => isCyrl ? 'Маълумотларингизни киритинг' : 'Ma\'lumotlaringizni kiriting';
  String get firstNameLabel => isCyrl ? 'Исм' : 'Ism';
  String get firstNameHint => isCyrl ? 'Исмингизни киритинг' : 'Ismingizni kiriting';
  String get lastNameLabel => isCyrl ? 'Фамилия' : 'Familiya';
  String get lastNameHint => isCyrl ? 'Фамилиянгизни киритинг' : 'Familiyangizni kiriting';
  String get phoneLabel => isCyrl ? 'Телефон рақами' : 'Telefon raqami';
  String get phoneHint => '+998 XX XXX XX XX';
  String get confirmPasswordLabel => isCyrl ? 'Паролни тасдиқланг' : 'Parolni tasdiqlang';
  String get confirmPasswordHint => isCyrl ? 'Паролни қайта киритинг' : 'Parolni qayta kiriting';
  String get registerButton => isCyrl ? 'Рўйхатдан ўтиш' : 'Ro\'yxatdan o\'tish';
  String get registerSuccess => isCyrl ? 'Сўровингиз юборилди. Администратор тасдиқлашини кутинг.' : 'So\'rovingiz yuborildi. Administrator tasdiqlanishini kuting.';
  String get passwordMismatch => isCyrl ? 'Пароллар мос эмас' : 'Parollar mos emas';
  String get fieldRequired => isCyrl ? 'Бу майдон тўлдирилиши шарт' : 'Bu maydon to\'ldirilishi shart';
  String get loginTaken => isCyrl ? 'Бу логин банд' : 'Bu login band';
  String get phoneTaken => isCyrl ? 'Бу телефон рақами рўйхатдан ўтган' : 'Bu telefon raqami ro\'yxatdan o\'tgan';
  String get alreadyHaveAccount => isCyrl ? 'Ҳисобингиз борми?' : 'Hisobingiz bormi?';
  String get loginLink => isCyrl ? 'Кириш' : 'Kirish';
  String get passwordMinLength => isCyrl ? 'Парол камида 6 та белги бўлиши керак' : 'Parol kamida 6 ta belgi bo\'lishi kerak';
  String get phoneInvalid => isCyrl ? 'Телефон рақами нотўғри' : 'Telefon raqami noto\'g\'ri';

  String get homeTitle => isCyrl ? 'Бош экран' : 'Bosh ekran';
  String get homeWelcome => isCyrl ? 'Хуш келибсиз' : 'Xush kelibsiz';
  String get homeSubtitle => isCyrl ? 'Ишлаш учун бўлимни танланг' : 'Ishlash uchun bo\'limni tanlang';
  String get statEmergency => isCyrl ? 'Авария' : 'Avariya';
  String get statDefects => isCyrl ? 'Камчилик' : 'Kamchilik';
  String get offlineLabel => isCyrl ? 'Интернет йўқ — маълумотлар кэшдан' : 'Internet yo\'q — ma\'lumotlar keshdan';
  String get navHome => isCyrl ? 'Асосий' : 'Asosiy';
  String get navBoilerhouses => isCyrl ? 'Қозонхоналар' : 'Qozonxonalar';
  String get navJournal => isCyrl ? 'Журнал' : 'Jurnal';
  String get navInstructions => isCyrl ? 'Кўрсатмалар' : 'Ko\'rsatmalar';
  String get navDrawings => isCyrl ? 'Чизмалар' : 'Chizmalar';
  String get navNotifications => isCyrl ? 'Билдиришномалар' : 'Bildirishnomalar';
  String get navProfile => isCyrl ? 'Профил' : 'Profil';
  String get navWorkers => isCyrl ? 'Ходимлар' : 'Xodimlar';
  String get workersTitle => isCyrl ? 'Ходимлар рўйхати' : 'Xodimlar ro\'yxati';

  String get boilerhousesTitle => isCyrl ? 'Қозонхоналар' : 'Qozonxonalar';
  String get boilerhouseDetailTitle => isCyrl ? 'Қозонхона маълумоти' : 'Qozonxona ma\'lumoti';
  String get boilerhouseNotFound => isCyrl ? 'Қозонхона топилмади' : 'Qozonxona topilmadi';
  String get fieldAddress => isCyrl ? 'Манзил' : 'Manzil';
  String get fieldYearBuilt => isCyrl ? 'Қурилган йил' : 'Qurilgan yil';
  String get fieldLastRepair => isCyrl ? 'Охирги таъмир' : 'Oxirgi ta\'mir';
  String get fieldServicedObjects => isCyrl ? 'Хизмат кўрсатилаётган объектлар' : 'Xizmat ko\'rsatilayotgan ob\'ektlar';
  String get fieldHeatingArea => isCyrl ? 'Иситиш майдони' : 'Isitish maydoni';
  String get fieldEngineer => isCyrl ? 'Масъул муҳандис' : 'Mas\'ul muhandis';
  String get fieldOperatorPhone => isCyrl ? 'Оператор телефони' : 'Operator telefoni';
  String get fieldLastInspection => isCyrl ? 'Охирги текшируви' : 'Oxirgi tekshiruvi';
  String get fieldNextInspection => isCyrl ? 'Кейинги текшируви' : 'Keyingi tekshiruvi';
  String get fieldNotes => isCyrl ? 'Техник изоҳлар' : 'Texnik izohlar';
  String get noNotes => isCyrl ? 'Изоҳ йўқ' : 'Izoh yo\'q';
  String get fieldStatus => isCyrl ? 'Ҳолат' : 'Holat';
  String get fieldType => isCyrl ? 'Тури' : 'Turi';
  String get fieldCapacity => isCyrl ? 'Қувват' : 'Quvvat';
  String get unitGcal => 'Гкал/соат';
  String get unitGcalShort => 'Гкал/с';
  String get unitM2 => 'м²';

  String get statusOperating => isCyrl ? 'Ишлаяпти' : 'Ishlayapti';
  String get statusMaintenance => isCyrl ? 'Режали таъмир' : 'Rejali ta\'mir';
  String get statusEmergency => isCyrl ? 'Авария тўхтатиш' : 'Avariya to\'xtatish';
  String get statusMothballed => isCyrl ? 'Консервацияда' : 'Konservatsiyada';

  String get typeGas => isCyrl ? 'Газли' : 'Gazli';
  String get typeFuelOil => isCyrl ? 'Мазутли' : 'Mazutli';
  String get typeCoal => isCyrl ? 'Кўмирли' : 'Ko\'mirli';
  String get typeCombined => isCyrl ? 'Комбинацияланган' : 'Kombinatsiyalangan';

  String get equipmentTitle => isCyrl ? 'Жиҳозлар' : 'Jihozlar';
  String get fieldModel => isCyrl ? 'Модел' : 'Model';
  String get fieldManufacturer => isCyrl ? 'Ишлаб чиқарувчи' : 'Ishlab chiqaruvchi';
  String get fieldSerial => isCyrl ? 'Серия рақами' : 'Seriya raqami';
  String get fieldInventory => isCyrl ? 'Инвентар рақами' : 'Inventar raqami';
  String get fieldProductionDate => isCyrl ? 'Ишлаб чиқарилган сана' : 'Ishlab chiqarilgan sana';
  String get fieldInstalledDate => isCyrl ? 'Ўрнатилган сана' : 'O\'rnatilgan sana';
  String get fieldResponsible => isCyrl ? 'Масъул шахс' : 'Mas\'ul shaxs';
  String get fieldLastService => isCyrl ? 'Охирги ТХ' : 'Oxirgi TX';
  String get fieldNextService => isCyrl ? 'Кейинги ТХ' : 'Keyingi TX';
  String get eqStatusOperating => isCyrl ? 'Ишлаяпти' : 'Ishlayapti';
  String get eqStatusStandby => isCyrl ? 'Захира' : 'Zahira';
  String get eqStatusMaintenance => isCyrl ? 'ТХда' : 'TXda';
  String get eqStatusDecommissioned => isCyrl ? 'Ишдан чиқарилган' : 'Ishdan chiqarilgan';
  String get eqTypeBoiler => isCyrl ? 'Қозон' : 'Qozon';
  String get eqTypePump => isCyrl ? 'Насос' : 'Nasos';
  String get eqTypeHeatExchanger => isCyrl ? 'Иссиқлик алмашгич' : 'Issiqlik almashgich';
  String get eqTypeBurner => isCyrl ? 'Горелка' : 'Gorelka';
  String get eqTypeExpansionTank => isCyrl ? 'Кенгайтириш бачкаси' : 'Kengaytirish bachkasi';
  String get eqTypeOther => isCyrl ? 'Бошқа' : 'Boshqa';

  String get journalTitle => isCyrl ? 'Техник журнал' : 'Texnik jurnal';
  String get journalEmpty => isCyrl ? 'Журналда ёзувлар йўқ' : 'Jurnalda yozuvlar yo\'q';
  String get journalCategory => isCyrl ? 'Тоифа' : 'Toifa';
  String get journalImportance => isCyrl ? 'Аҳамияти' : 'Ahamiyati';
  String get journalStatus => isCyrl ? 'Ҳолат' : 'Holat';
  String get journalDescription => isCyrl ? 'Тавсиф' : 'Tavsif';
  String get journalPhotos => isCyrl ? 'Расмлар' : 'Rasmlar';
  String get journalPhotosCount => isCyrl ? 'та расм' : 'ta rasm';
  String get journalAuthor => isCyrl ? 'Муаллиф' : 'Muallif';
  String get journalAddEntry => isCyrl ? 'Ёзув қўшиш' : 'Yozuv qo\'shish';
  String get journalTitleField => isCyrl ? 'Сарлавҳа' : 'Sarlavha';
  String get journalTitleHint => isCyrl ? 'Ёзув сарлавҳасини киритинг' : 'Yozuv sarlavhasini kiriting';
  String get journalDescHint => isCyrl ? 'Тафсилотларни киритинг' : 'Tafsilotlarni kiriting';
  String get journalCategoryHint => isCyrl ? 'Тоифани киритинг' : 'Toifani kiriting';
  String get journalSave => isCyrl ? 'Сақлаш' : 'Saqlash';
  String get journalCancel => isCyrl ? 'Бекор қилиш' : 'Bekor qilish';
  String get journalEdit => isCyrl ? 'Таҳрирлаш' : 'Tahrirlash';
  String get journalDelete => isCyrl ? 'Ўчириш' : 'O\'chirish';
  String get journalDeleteConfirm => isCyrl ? 'Ушбу ёзувни ўчиришни тасдиқлайсизми?' : 'Ushbu yozuvni o\'chirishni tasdiqlaymisiz?';
  String get journalDeleteTitle => isCyrl ? 'Ёзувни ўчириш' : 'Yozuvni o\'chirish';
  String get journalEditTitle => isCyrl ? 'Ёзувни таҳрирлаш' : 'Yozuvni tahrirlash';
  String get importanceNormal => isCyrl ? 'Оддий' : 'Oddiy';
  String get importanceImportant => isCyrl ? 'Муҳим' : 'Muhim';
  String get importanceCritical => isCyrl ? 'Критик' : 'Kritik';
  String get jStatusOpen => isCyrl ? 'Очиқ' : 'Ochiq';
  String get jStatusInProgress => isCyrl ? 'Жараёнда' : 'Jarayonda';
  String get jStatusClosed => isCyrl ? 'Ёпилган' : 'Yopilgan';

  String get instructionsTitle => isCyrl ? 'Кўрсатмалар' : 'Ko\'rsatmalar';
  String get instructionsMandatory => isCyrl ? 'Мажбурий' : 'Majburiy';
  String get instructionsVersion => isCyrl ? 'Версия' : 'Versiya';
  String get instructionsUpdated => isCyrl ? 'Янгиланган' : 'Yangilangan';
  String get instructionsCategory => isCyrl ? 'Тоифа' : 'Toifa';
  String get instructionsFavorite => isCyrl ? 'Севимлиларга қўшилди' : 'Sevimlilariga qo\'shildi';
  String get instructionsCount => isCyrl ? 'та кўрсатма' : 'ta ko\'rsatma';

  String get drawingsTitle => isCyrl ? 'Чизмалар' : 'Chizmalar';
  String get drawingsNumber => isCyrl ? 'Рақам' : 'Raqam';
  String get drawingsCategory => isCyrl ? 'Тоифа' : 'Toifa';
  String get drawingsClose => isCyrl ? 'Ёпиш' : 'Yopish';
  String get drawingsOpen => isCyrl ? 'Очиш' : 'Ochish';
  String get drawingsCount => isCyrl ? 'та чизма' : 'ta chizma';

  String get notificationsTitle => isCyrl ? 'Билдиришномалар' : 'Bildirishnomalar';
  String get notificationsEmpty => isCyrl ? 'Билдиришнома йўқ' : 'Bildirishnoma yo\'q';
  String get notificationsMarkAllRead => isCyrl ? 'Барчасини ўқилган деб белгилаш' : 'Barchasini o\'qilgan deb belgilash';
  String get timeJustNow => isCyrl ? 'ҳозиргина' : 'hozir';
  String timeMinutesAgo(int m) => isCyrl ? '$m дақ. олдин' : '$m daq. oldin';
  String timeHoursAgo(int h) => isCyrl ? '$h соат олдин' : '$h soat oldin';
  String timeDaysAgo(int d) => isCyrl ? '$d кун олдин' : '$d kun oldin';

  String get profileTitle => isCyrl ? 'Фойдаланувчи профили' : 'Foydalanuvchi profili';
  String get profileNotFound => isCyrl ? 'Фойдаланувчи топилмади' : 'Foydalanuvchi topilmadi';
  String get profileInfo => isCyrl ? 'Маълумот' : 'Ma\'lumot';
  String get profileLogin => isCyrl ? 'Логин' : 'Login';
  String get profilePosition => isCyrl ? 'Лавозим' : 'Lavozim';
  String get profilePhone => isCyrl ? 'Телефон' : 'Telefon';
  String get profileLanguage => isCyrl ? 'Интерфейс тили' : 'Interfeys tili';
  String get profileLangCyrl => isCyrl ? 'Ўзбек (кир.)' : 'O\'zbek (kir.)';
  String get profileLangLatin => isCyrl ? 'Ўзбек (лот.)' : 'O\'zbek (lot.)';
  String get profileLangChanged => isCyrl ? 'Тил ўзгартирилди' : 'Til o\'zgartirildi';
  String get profileChangePassword => isCyrl ? 'Паролни ўзгартириш' : 'Parolni o\'zgartirish';
  String get passwordCurrent => isCyrl ? 'Жорий парол' : 'Joriy parol';
  String get passwordNew => isCyrl ? 'Янги парол' : 'Yangi parol';
  String get passwordChanged => isCyrl ? 'Парол ўзгартирилди' : 'Parol o\'zgartirildi';
  String get profileLogout => isCyrl ? 'Чиқиш' : 'Chiqish';
  String get roleAdmin => isCyrl ? 'Администратор' : 'Administrator';
  String get roleCoAdmin => isCyrl ? 'Со-Администратор' : 'Co-Administrator';
  String get roleMember => isCyrl ? 'Ходим' : 'Xodim';

  String get adminTitle => isCyrl ? 'Администратор панели' : 'Administrator paneli';
  String get adminAccessDenied => isCyrl ? 'Фақат администраторлар учун' : 'Faqat administratorlar uchun';
  String get adminManagement => isCyrl ? 'Тизимни бошқариш' : 'Tizimni boshqarish';
  String get adminUsers => isCyrl ? 'Фойдаланувчилар' : 'Foydalanuvchilar';
  String get adminBoilerhouses => isCyrl ? 'Қозонхоналар' : 'Qozonxonalar';
  String get adminEquipment => isCyrl ? 'Жиҳозлар' : 'Jihozlar';
  String get adminInstructions => isCyrl ? 'Кўрсатмалар' : 'Ko\'rsatmalar';
  String get adminSendNotif => isCyrl ? 'Билдиришнома юбориш' : 'Bildirishnoma yuborish';
  String get adminNotifBroadcast => isCyrl ? 'Билдиришнома тарқатиш' : 'Bildirishnoma tarqatish';
  String get adminStats => isCyrl ? 'Статистика' : 'Statistika';
  String get adminActiveBoilerhouses => isCyrl ? 'Фаол қозонхоналар' : 'Faol qozonxonalar';
  String get adminInRepair => isCyrl ? 'Таъмирда' : 'Ta\'mirda';
  String get adminEmergency => isCyrl ? 'Авария тўхтатишда' : 'Avariya to\'xtatishda';
  String get adminEquipmentService => isCyrl ? 'ТХдаги жиҳозлар' : 'TXdagi jihozlar';
  String get adminActiveUsers => isCyrl ? 'Фаол фойдаланувчилар' : 'Faol foydalanuvchilar';
  String get adminPendingUsers => isCyrl ? 'Кутаётган сўровлар' : 'Kutayotgan so\'rovlar';
  String get adminNoPending => isCyrl ? 'Кутаётган сўровлар йўқ' : 'Kutayotgan so\'rovlar yo\'q';
  String get adminApprove => isCyrl ? 'Тасдиқлаш' : 'Tasdiqlash';
  String get adminDecline => isCyrl ? 'Рад этиш' : 'Rad etish';
  String get adminUsersList => isCyrl ? 'Фойдаланувчилар рўйхати' : 'Foydalanuvchilar ro\'yxati';
  String get auditLogTab => isCyrl ? 'Тарих' : 'Tarix';
  String get adminChangeRole => isCyrl ? 'Ролни ўзгартириш' : 'Rolni o\'zgartirish';
  String get adminNotifTitle => isCyrl ? 'Сарлавҳа' : 'Sarlavha';
  String get adminNotifMessage => isCyrl ? 'Хабар матни' : 'Xabar matni';
  String get adminNotifSend => isCyrl ? 'Юбориш' : 'Yuborish';
  String get adminNotifSent => isCyrl ? 'Билдиришнома юборилди' : 'Bildirishnoma yuborildi';
  String get cancel => isCyrl ? 'Бекор қилиш' : 'Bekor qilish';
  String get save => isCyrl ? 'Сақлаш' : 'Saqlash';

  // Boilerhouse detail
  String get sectionMainInfo => isCyrl ? 'Асосий маълумот' : 'Asosiy ma\'lumot';
  String get fieldYearBuiltDetail => isCyrl ? 'Қурилган йили' : 'Qurilgan yili';
  String get fieldModernization => isCyrl ? 'Модернизация' : 'Modernizatsiya';
  String get fieldTotalArea => isCyrl ? 'Умумий майдон' : 'Umumiy maydon';
  String get fieldWorkers => isCyrl ? 'Ишчилар' : 'Ishchilar';
  String get fieldOperators => isCyrl ? 'Операторлар' : 'Operatorlar';
  String get sectionCapacity => isCyrl ? 'Қувват' : 'Quvvat';
  String get fieldInstalledCapacity => isCyrl ? 'Ўрнатилган қуввати' : 'O\'rnatilgan quvvati';
  String get fieldConnectedLoad => isCyrl ? 'Уланган юклама' : 'Ulangan yuklama';
  String get fieldConsumers => isCyrl ? 'Истеъмолчилар' : 'Iste\'molchilar';
  String get sectionPipelines => isCyrl ? 'Иссиқлик тармоқлари' : 'Issiqlik tarmoqlari';
  String get fieldTotalLength => isCyrl ? 'Умумий узунлиги' : 'Umumiy uzunligi';
  String get fieldAboveGround => isCyrl ? 'Ер усти' : 'Yer usti';
  String get fieldBelowGround => isCyrl ? 'Ер ости' : 'Yer osti';
  String get sectionAnnualConsumption => isCyrl ? 'Йиллик истеъмол' : 'Yillik iste\'mol';
  String get fieldElectricity => isCyrl ? 'Электр энергия' : 'Elektr energiya';
  String get fieldColdWater => isCyrl ? 'Совуқ сув' : 'Sovuq suv';
  String get fieldNaturalGas => isCyrl ? 'Табиий газ' : 'Tabiiy gaz';
  String get fieldHeatProduction => isCyrl ? 'Иссиқлик ишлаб чиқариш' : 'Issiqlik ishlab chiqarish';
  String get sectionAdditional => isCyrl ? 'Қўшимча' : 'Qo\'shimcha';
  String get fieldDispatchPhone => isCyrl ? 'Диспетчер телефон' : 'Dispetcher telefon';
  String get fieldDefects => isCyrl ? 'Камчиликлар' : 'Kamchiliklar';
  String get openOnMap => isCyrl ? 'Картада кўриш' : 'Kartada ko\'rish';
  String get changeLogTitle => isCyrl ? 'Ўзгаришлар журнали' : 'O\'zgarishlar jurnali';
  String get changeLogHeading => isCyrl ? 'Сарлавҳа' : 'Sarlavha';
  String get changeLogDescription => isCyrl ? 'Тавсиф' : 'Tavsif';
  String get changeLogSubmit => isCyrl ? 'Юбориш' : 'Yuborish';
  String get changeLogError => isCyrl ? 'Хатолик' : 'Xatolik';
  String get changeLogEmpty => isCyrl ? 'Ҳозирча ўзгаришлар йўқ' : 'Hozircha o\'zgarishlar yo\'q';
  String get comments => isCyrl ? 'Изоҳлар' : 'Izohlar';
  String get reply => isCyrl ? 'Жавоб' : 'Javob';
  String get commentHint => isCyrl ? 'Изоҳ...' : 'Izoh...';
  String get noComments => isCyrl ? 'Изоҳлар йўқ' : 'Izohlar yo\'q';
  String get unitPcs => isCyrl ? 'та' : 'ta';
  String get unitKm => 'км';
  String get unitKw => 'кВт';
  String get unitM3 => 'м³';

  // Admin form labels
  String get formEdit => isCyrl ? 'Таҳрирлаш' : 'Tahrirlash';
  String get formNewBoilerhouse => isCyrl ? 'Янги қозонхона' : 'Yangi qozonxona';
  String get formNewInstruction => isCyrl ? 'Янги кўрсатма' : 'Yangi ko\'rsatma';
  String get formNewDrawing => isCyrl ? 'Янги чизма' : 'Yangi chizma';
  String get formDistrict => isCyrl ? 'Туман/шаҳар' : 'Tuman/shahar';
  String get formName => isCyrl ? 'Номи' : 'Nomi';
  String get formAddress => isCyrl ? 'Манзил' : 'Manzil';
  String get formArea => isCyrl ? 'Майдон (м²)' : 'Maydon (m²)';
  String get formCapacity => isCyrl ? 'Қуввати (Гкал/с)' : 'Quvvati (Gkal/s)';
  String get formLoad => isCyrl ? 'Юклама (Гкал/с)' : 'Yuklama (Gkal/s)';
  String get formPipeline => isCyrl ? 'Қувур (км)' : 'Quvur (km)';
  String get formPhone => isCyrl ? 'Телефон' : 'Telefon';
  String get formElectricity => isCyrl ? 'Электр (кВт/й)' : 'Elektr (kVt/y)';
  String get formGas => isCyrl ? 'Газ (м³/й)' : 'Gaz (m³/y)';
  String get formHeat => isCyrl ? 'Иссиқлик (Гкал/й)' : 'Issiqlik (Gkal/y)';
  String get formLocationUrl => isCyrl ? 'Геолокация ҳаволаси (URL)' : 'Geolokatsiya havolasi (URL)';
  String get formCategory => isCyrl ? 'Категория' : 'Kategoriya';
  String get formText => isCyrl ? 'Матн' : 'Matn';
  String get formNumber => isCyrl ? 'Рақами' : 'Raqami';
  String get deleteConfirm => isCyrl ? 'Ўчириш?' : 'O\'chirish?';
  String get no => isCyrl ? 'Йўқ' : 'Yo\'q';
  String get yes => isCyrl ? 'Ҳа' : 'Ha';

  String get aboutTitle => isCyrl ? 'Илова ҳақида' : 'Ilova haqida';
  String get allDistricts => isCyrl ? 'Барчаси' : 'Barchasi';
  String get deleteAccount => isCyrl ? 'Ҳисобни ўчириш' : 'Hisobni o\'chirish';
  String get deleteAccountConfirm => isCyrl ? 'Ҳисобингиз бутунлай ўчирилади. Бу амални қайтариб бўлмайди.' : 'Hisobingiz butunlay o\'chiriladi. Bu amalni qaytarib bo\'lmaydi.';
  String get resetPassword => isCyrl ? 'Парол тиклаш' : 'Parol tiklash';
  String get newPassword => isCyrl ? 'Янги парол' : 'Yangi parol';
  String get passwordUpdated => isCyrl ? 'Парол янгиланди' : 'Parol yangilandi';
  String get ban => isCyrl ? 'Блоклаш' : 'Bloklash';
  String get unban => isCyrl ? 'Блокдан чиқариш' : 'Blokdan chiqarish';
  String get forgotPasswordHint => isCyrl ? 'Логинингизни киритинг. Админ паролингизни тиклаш учун хабар олади.' : 'Loginingizni kiriting. Admin parolingizni tiklash uchun xabar oladi.';
  String get requestSent => isCyrl
      ? 'Сўров сақланди. Интернет бўлмаса, алоқа тиклангач админга юборилади.'
      : 'So\'rov saqlandi. Internet bo\'lmasa, aloqa tiklangach adminga yuboriladi.';
  String get drawingComingSoon => isCyrl ? 'Чизма расми тез орада қўшилади' : 'Chizma rasmi tez orada qo\'shiladi';
  String get cannotOpenFile => isCyrl ? 'Файлни очиб бўлмади' : 'Faylni ochib bo\'lmadi';

  // About screen
  String get aboutVersion => isCyrl ? 'Версия' : 'Versiya';
  String get aboutCreator => isCyrl ? 'Бу платформанинг яратувчиси' : 'Bu platformaning yaratuvchisi';
  String get aboutFuturePlans => isCyrl ? 'Келажакда яна шундай ва ундан ҳам каттароқ лойиҳалар яратишни режалаштираман!' : 'Kelajakda yana shunday va undan ham kattaroq loyihalar yaratishni rejalashtiraman!';
  String get aboutThanks => isCyrl ? 'Фойдаланганингиз учун раҳмат! 🙏' : 'Foydalanganingiz uchun rahmat! 🙏';

  // Misc
  String lockoutMessage(int seconds) => isCyrl ? '$seconds сония кутинг' : '${seconds}s kutib turing';
  String get photoUploadUnavailable => isCyrl ? 'Расм юклаш ҳозирча мавжуд эмас' : 'Rasm yuklash hozircha mavjud emas';

  // Shifts
  String get shiftsTitle => isCyrl ? 'Навбатчилик жадвали' : 'Navbatchilik jadvali';
  String get shiftDay => isCyrl ? 'Кундузги смена' : 'Kunduzgi smena';
  String get shiftNight => isCyrl ? 'Тунги смена' : 'Tungi smena';
  String get shiftAdd => isCyrl ? 'Навбатчилик қўшиш' : 'Navbatchilik qo\'shish';
  String get shiftOperator => isCyrl ? 'Оператор' : 'Operator';
  String get shiftEmpty => isCyrl ? 'Бу ҳафтага навбатчилик йўқ' : 'Bu haftaga navbatchilik yo\'q';
  String get shiftMineBadge => isCyrl ? 'Меники' : 'Meniki';
  String get shiftNote => isCyrl ? 'Изоҳ' : 'Izoh';
  String get shiftDeleteConfirm => isCyrl ? 'Навбатчиликни ўчирасизми?' : 'Navbatchilikni o\'chirasizmi?';

  // Analytics
  String get analyticsTitle => isCyrl ? 'Таҳлил' : 'Tahlil';
  String get analyticsTotals => isCyrl ? 'Умумий кўрсаткичлар' : 'Umumiy ko\'rsatkichlar';
  String get analyticsByDistrict => isCyrl ? 'Туманлар кесимида' : 'Tumanlar kesimida';
  String get analyticsTop => isCyrl ? 'Энг кўп сарф қилувчилар' : 'Eng ko\'p sarf qiluvchilar';
  String get analyticsHeat => isCyrl ? 'Иссиқлик ишлаб чиқариш' : 'Issiqlik ishlab chiqarish';
  String get analyticsStatuses => isCyrl ? 'Ҳолатлар' : 'Holatlar';
  String get analyticsDefects => isCyrl ? 'Камчиликлар қайд этилган' : 'Kamchiliklar qayd etilgan';
}
