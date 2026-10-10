import '../domain/models/app_user.dart';
import '../domain/models/drawing.dart';
import '../domain/models/equipment.dart';
import '../domain/models/instruction.dart';
import '../domain/models/journal_entry.dart';
import '../domain/models/notification_model.dart';

// в”Ђв”Ђ Seed users в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
final seedUsers = <AppUser>[
  const AppUser(
    id: 'user-admin',
    login: 'admin',
    firstName: 'Alisher',
    lastName: 'Karimov',
    phone: '+998 90 000 00 01',
    role: UserRole.admin,
    status: UserStatus.active,
    boilerhouseIds: ['bh-001', 'bh-002', 'bh-003'],
  ),
  const AppUser(
    id: 'user-coadmin',
    login: 'coadmin',
    firstName: 'Bobur',
    lastName: 'Yusupov',
    phone: '+998 90 000 00 02',
    role: UserRole.coAdmin,
    status: UserStatus.active,
    boilerhouseIds: ['bh-001', 'bh-002'],
  ),
  const AppUser(
    id: 'user-member',
    login: 'member',
    firstName: 'Dilnoza',
    lastName: 'Rahimova',
    phone: '+998 90 000 00 03',
    role: UserRole.member,
    status: UserStatus.active,
    boilerhouseIds: ['bh-001'],
  ),
  const AppUser(
    id: 'user-test',
    login: 'test1',
    firstName: 'Test',
    lastName: 'Foydalanuvchi',
    phone: '+998 90 000 00 04',
    role: UserRole.admin,
    status: UserStatus.active,
    boilerhouseIds: ['bh-001', 'bh-002', 'bh-003'],
  ),
];
// в”Ђв”Ђ Equipment в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
final sampleEquipment = <Equipment>[
  Equipment(
    id: 'eq-001',
    boilerHouseId: 'bh-001',
    type: EquipmentType.boiler,
    name: 'Gaz qozoni DKVr-6.5/13',
    model: 'DKVr-6.5/13',
    manufacturer: 'Oktyabr inqilobi zavodi',
    serialNumber: 'OK-2018-001',
    inventoryNumber: 'QOZ-001',
    productionDate: DateTime.utc(2018, 3, 15),
    installedDate: DateTime.utc(2018, 6, 1),
    status: EquipmentStatus.operating,
    lastServiceDate: DateTime.utc(2026, 1, 20),
    nextServiceDate: DateTime.utc(2026, 6, 20),
    responsiblePersonId: 'Alisher Karimov',
    notes: 'Qozon normal rejimda ishlayapti.',
  ),
  Equipment(
    id: 'eq-002',
    boilerHouseId: 'bh-001',
    type: EquipmentType.pump,
    name: 'Sirkulyatsion nasos',
    model: 'UPS 32-80',
    manufacturer: 'Grundfos',
    serialNumber: 'GR-2019-456',
    inventoryNumber: 'NAS-001',
    productionDate: DateTime.utc(2019, 5, 10),
    installedDate: DateTime.utc(2019, 7, 15),
    status: EquipmentStatus.operating,
    lastServiceDate: DateTime.utc(2025, 12, 10),
    nextServiceDate: DateTime.utc(2026, 6, 10),
    responsiblePersonId: 'Alisher Karimov',
    notes: '',
  ),
  Equipment(
    id: 'eq-003',
    boilerHouseId: 'bh-002',
    type: EquipmentType.heatExchanger,
    name: 'Issiqlik almashtiruvchi',
    model: 'HE-200',
    manufacturer: 'Alfa Laval',
    serialNumber: 'AL-2020-789',
    inventoryNumber: 'ISS-001',
    productionDate: DateTime.utc(2020, 2, 20),
    installedDate: DateTime.utc(2020, 4, 10),
    status: EquipmentStatus.maintenance,
    lastServiceDate: DateTime.utc(2026, 4, 1),
    nextServiceDate: DateTime.utc(2026, 10, 1),
    responsiblePersonId: 'Bobur Yusupov',
    notes: 'Rejalashtirilgan texnik xizmat ko\'rsatish.',
  ),
];
// в”Ђв”Ђ Journal entries в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
final sampleJournalEntries = <JournalEntry>[
  JournalEntry(
    id: 'je-001',
    boilerHouseId: 'bh-001',
    equipmentId: 'eq-001',
    eventDateTime: DateTime.utc(2026, 5, 12, 10, 30),
    category: 'Rejalashtirilgan aylanib chiqish',
    title: 'Shimoliy qozonxonaning ertalabki ko\'rigi',
    description:
        'Uskunalarning rejalashtirilgan ko\'rigi o\'tkazildi. Tizim bosimi me\'yorda. Issiqlik tashuvchi harorati 75°C.',
    importance: JournalEntryImportance.normal,
    status: JournalEntryStatus.closed,
    authorId: 'user-admin',
    authorName: 'Alisher Karimov',
    createdAt: DateTime.utc(2026, 5, 12, 10, 30),
    updatedAt: DateTime.utc(2026, 5, 12, 10, 30),
  ),
  JournalEntry(
    id: 'je-002',
    boilerHouseId: 'bh-001',
    eventDateTime: DateTime.utc(2026, 5, 11, 16, 0),
    category: 'Texnik xizmat ko\'rsatish',
    title: 'Isitish tizimiga texnik xizmat ko\'rsatish',
    description:
        'Rejalashtirilgan TX bajarildi. Ulanishlarning germetikligi tekshirildi, filtrlar tozalandi.',
    importance: JournalEntryImportance.normal,
    status: JournalEntryStatus.closed,
    authorId: 'user-coadmin',
    authorName: 'Bobur Yusupov',
    createdAt: DateTime.utc(2026, 5, 11, 16, 0),
    updatedAt: DateTime.utc(2026, 5, 11, 16, 0),
  ),
  JournalEntry(
    id: 'je-003',
    boilerHouseId: 'bh-002',
    equipmentId: 'eq-003',
    eventDateTime: DateTime.utc(2026, 5, 10, 9, 0),
    category: 'Nosozlik',
    title: 'Issiqlik almashtiruvchida bosim tushishi',
    description:
        'Issiqlik almashtiruvchida bosim me\'yordan past. Texnik xizmat ko\'rsatish boshlandi.',
    importance: JournalEntryImportance.important,
    status: JournalEntryStatus.inProgress,
    authorId: 'user-member',
    authorName: 'Dilnoza Rahimova',
    createdAt: DateTime.utc(2026, 5, 10, 9, 0),
    updatedAt: DateTime.utc(2026, 5, 10, 9, 0),
  ),
];

// в”Ђв”Ђ Instructions в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
final sampleInstructions = <Instruction>[
  Instruction(
    id: 'instr-001',
    title: 'DKVr seriyali qozonlarni ishlatish qoidalari',
    category: 'Qozonlarni ishlatish qoidalari',
    body: 'DKVr seriyali qozonlar turar-joy va jamoat binolarini issiqlik bilan ta\'minlash uchun mo\'ljallangan.\n\n'
        'Qozonni ishga tushirishdan oldin:\n'
        '1. Barcha ulanishlarning germetikligini tekshiring\n'
        '2. Kengaytirish bachkasidagi suv darajasini tekshiring\n'
        '3. Gaz bosimining mavjudligiga ishonch hosil qiling\n\n'
        'Ish parametrlari:\n'
        '- Issiqlik tashuvchi bosimi: 2.5—3.5 bar\n'
        '- Issiqlik tashuvchi harorati: 60—90°C\n'
        '- Gaz bosimi: 10—25 mbar',
    version: '1.0',
    createdAt: DateTime(2025, 6, 1),
    updatedAt: DateTime(2026, 1, 15),
    authorId: 'user-admin',
    urgency: InstructionUrgency.mandatory,
  ),
  Instruction(
    id: 'instr-002',
    title: 'Favqulodda vaziyatlarda harakat qilish tartibi',
    category: 'Favqulodda vaziyatlarda harakat qilish',
    body: 'Favqulodda vaziyat belgilarini aniqlashda:\n\n'
        '1. Qozonxonani darhol o\'chiring\n'
        '2. Gaz ta\'minotini to\'sing\n'
        '3. Favqulodda xizmatga qo\'ng\'iroq qiling\n'
        '4. Odamlarni xonadan evakuatsiya qiling\n'
        '5. Xonani shamollatib turing\n\n'
        'Xavf belgilari:\n'
        '- Gaz hidi\n'
        '- Qozondan g\'alati tovushlar\n'
        '- Suv oqishi\n'
        '- Kritik darajada yuqori bosim',
    version: '2.1',
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2026, 3, 10),
    authorId: 'user-admin',
    urgency: InstructionUrgency.mandatory,
  ),
  Instruction(
    id: 'instr-003',
    title: 'Nasoslarni texnik xizmat ko\'rsatish',
    category: 'Texnik xizmat ko\'rsatish',
    body: 'Sirkulyatsion nasoslarni texnik xizmat ko\'rsatish:\n\n'
        '1. Nasosni o\'chiring va elektr ta\'minotini uzing\n'
        '2. Bosimni tushiring\n'
        '3. Filtrni tozalang\n'
        '4. Muhrlarni tekshiring\n'
        '5. Yog\'lash materialini almashtiring\n\n'
        'TX oralig\'i: har 6 oyda bir marta.',
    version: '1.2',
    createdAt: DateTime(2025, 3, 1),
    updatedAt: DateTime(2025, 11, 20),
    authorId: 'user-admin',
    urgency: InstructionUrgency.normal,
  ),
];

// в”Ђв”Ђ Drawings в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
final sampleDrawings = <Drawing>[
  Drawing(id: 'draw-001', title: 'Урганч шаҳар чизмалари', number: 'СХ-001', category: 'Схемалар 2025', description: 'Урганч шаҳар қозонхоналари схемалари', boilerHouseId: '', filePath: 'assets/schemas/urgench_shahar.xlsx', authorId: 'user-admin', addedAt: DateTime(2025, 11, 12)),
  Drawing(id: 'draw-002', title: 'Шовот туман чизмалари', number: 'СХ-002', category: 'Схемалар 2025', description: 'Шовот туман қозонхоналари схемалари', boilerHouseId: '', filePath: 'assets/schemas/shovot.xlsx', authorId: 'user-admin', addedAt: DateTime(2025, 10, 21)),
  Drawing(id: 'draw-003', title: 'Янгиариқ туман чизмалари', number: 'СХ-003', category: 'Схемалар 2025', description: 'Янгиариқ туман қозонхоналари схемалари', boilerHouseId: '', filePath: 'assets/schemas/yangiariq.xlsx', authorId: 'user-admin', addedAt: DateTime(2025, 10, 22)),
  Drawing(id: 'draw-004', title: 'Янгибозор чизмалари', number: 'СХ-004', category: 'Схемалар 2025', description: 'Янгибозор туман қозонхоналари схемалари', boilerHouseId: '', filePath: 'assets/schemas/yangibozor.xlsx', authorId: 'user-admin', addedAt: DateTime(2025, 10, 17)),
  Drawing(id: 'draw-005', title: 'Урганч туман чизмалари', number: 'СХ-005', category: 'Схемалар 2025', description: 'Урганч туман қозонхоналари схемалари', boilerHouseId: '', filePath: 'assets/schemas/urgench_tuman.xlsx', authorId: 'user-admin', addedAt: DateTime(2025, 11, 12)),
  Drawing(id: 'draw-006', title: 'Хонка чизмалари', number: 'СХ-006', category: 'Схемалар 2025', description: 'Хонка туман қозонхоналари схемалари', boilerHouseId: '', filePath: 'assets/schemas/khonka.xlsx', authorId: 'user-admin', addedAt: DateTime(2025, 10, 28)),
  Drawing(id: 'draw-007', title: 'Хива чизмалари', number: 'СХ-007', category: 'Схемалар 2025', description: 'Хива туман қозонхоналари схемалари', boilerHouseId: '', filePath: 'assets/schemas/khiva.xlsx', authorId: 'user-admin', addedAt: DateTime(2025, 10, 17)),
  Drawing(id: 'draw-008', title: 'Қўшкўпир чизмалари', number: 'СХ-008', category: 'Схемалар 2025', description: 'Қўшкўпир туман қозонхоналари схемалари', boilerHouseId: '', filePath: 'assets/schemas/kushkupir.xlsx', authorId: 'user-admin', addedAt: DateTime(2025, 10, 27)),
  Drawing(id: 'draw-009', title: 'Тупроккала чизмалари', number: 'СХ-009', category: 'Схемалар 2025', description: 'Тупроккала туман қозонхоналари схемалари', boilerHouseId: '', filePath: 'assets/schemas/tuprokkala.xlsx', authorId: 'user-admin', addedAt: DateTime(2025, 10, 29)),
  Drawing(id: 'draw-010', title: 'Гурлан чизмалари', number: 'СХ-010', category: 'Схемалар 2025', description: 'Гурлан туман қозонхоналари схемалари', boilerHouseId: '', filePath: 'assets/schemas/gurlan.xlsx', authorId: 'user-admin', addedAt: DateTime(2025, 10, 22)),
  Drawing(id: 'draw-011', title: 'Боғот чизмалари', number: 'СХ-011', category: 'Схемалар 2025', description: 'Боғот туман қозонхоналари схемалари', boilerHouseId: '', filePath: 'assets/schemas/bogot.xlsx', authorId: 'user-admin', addedAt: DateTime(2025, 10, 30)),
  Drawing(id: 'draw-012', title: 'Хазорасп чизмалари', number: 'СХ-012', category: 'Схемалар 2025', description: 'Хазорасп туман қозонхоналари схемалари', boilerHouseId: '', filePath: 'assets/schemas/khazarasp.xlsx', authorId: 'user-admin', addedAt: DateTime(2025, 10, 28)),
];

// в”Ђв”Ђ Notifications в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
final sampleNotifications = <AppNotification>[
  AppNotification(
    id: 'notif-001',
    type: AppNotificationType.important,
    title: 'Rejalashtirilgan texnik xizmat',
    message: 'Ertaga soat 10:00 da Shimoliy qozonxona uskunalariga rejalashtirilgan TX boshlanadi',
    isRead: false,
    createdAt: DateTime.utc(2026, 5, 11, 16, 30),
    sentAt: DateTime.utc(2026, 5, 11, 16, 30),
  ),
  AppNotification(
    id: 'notif-002',
    type: AppNotificationType.informational,
    title: 'Ko\'rsatma yangilandi',
    message: 'Favqulodda vaziyatlarda harakat qilish bo\'yicha ko\'rsatma yangilandi',
    isRead: true,
    createdAt: DateTime.utc(2026, 5, 10, 9, 0),
    sentAt: DateTime.utc(2026, 5, 10, 9, 0),
  ),
  AppNotification(
    id: 'notif-003',
    type: AppNotificationType.emergency,
    title: 'Avariya to\'xtatish',
    message: 'Markaziy qozonxona avariya to\'xtatish rejimiga o\'tdi!',
    isRead: true,
    createdAt: DateTime.utc(2026, 5, 9, 14, 15),
    sentAt: DateTime.utc(2026, 5, 9, 14, 15),
  ),
];
