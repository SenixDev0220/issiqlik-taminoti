import '../services/auth_result.dart';
import 'l10n.dart';

extension AuthMessages on AppL10n {
  String authFailure(AuthFailure failure) => switch (failure) {
    AuthFailure.invalidCredentials => loginWrongError,
    AuthFailure.pendingApproval => loginPendingError,
    AuthFailure.blocked => isCyrl ? 'Ҳисоб блокланган. Администраторга мурожаат қилинг.' : 'Hisob bloklangan. Administratorga murojaat qiling.',
    AuthFailure.reauthenticationRequired => isCyrl ? 'Сеанс бекор қилинган. Блокдан чиқарилгандан кейин ҳам қайта кириш керак.' : 'Seans bekor qilingan. Blokdan chiqarilgandan keyin ham qayta kirish kerak.',
    AuthFailure.missingProfile => isCyrl ? 'Рўйхатдан ўтиш тугалланмаган. Аввалги логин ва парол билан рўйхатдан ўтишни якунланг ёки администраторга мурожаат қилинг.' : 'Ro‘yxatdan o‘tish tugallanmagan. Avvalgi login va parol bilan ro‘yxatdan o‘tishni yakunlang yoki administratorga murojaat qiling.',
    AuthFailure.invalidProfile => isCyrl ? 'Ҳисоб маълумотлари мос эмас. Администратор текшируви керак; янги ҳисоб очманг.' : 'Hisob ma’lumotlari mos emas. Administrator tekshiruvi kerak; yangi hisob ochmang.',
    AuthFailure.permissionDenied => isCyrl ? 'Сервер киришни рад этди. Ҳуқуқлар ва Firebase созламаларини администратор текшириши керак.' : 'Server kirishni rad etdi. Huquqlar va Firebase sozlamalarini administrator tekshirishi kerak.',
    AuthFailure.network => isCyrl ? 'Сервер билан алоқа йўқ ёки вақт тугади. Интернетни текшириб, қайта урининг.' : 'Server bilan aloqa yo‘q yoki vaqt tugadi. Internetni tekshirib, qayta urining.',
    AuthFailure.rateLimited => isCyrl ? 'Сервер вақтинча уринишларни чеклади. Бироз кутинг ва қайта урининг.' : 'Server vaqtincha urinishlarni chekladi. Biroz kuting va qayta urining.',
    AuthFailure.invalidInput => isCyrl ? 'Киритилган маълумотлар формати нотўғри. Майдонларни текширинг.' : 'Kiritilgan ma’lumotlar formati noto‘g‘ri. Maydonlarni tekshiring.',
    AuthFailure.registrationUnavailable => isCyrl ? 'Рўйхатдан ўтиш рад этилди. Логин/телефон ёки рухсатларни администратор текшириши керак.' : 'Ro‘yxatdan o‘tish rad etildi. Login/telefon yoki ruxsatlarni administrator tekshirishi kerak.',
    AuthFailure.internal => isCyrl ? 'Амални тугаллаб бўлмади. Кейинроқ қайта урининг ёки администраторга мурожаат қилинг.' : 'Amalni tugallab bo‘lmadi. Keyinroq qayta urining yoki administratorga murojaat qiling.',
  };

  String get registrationCleanupWarning => isCyrl
      ? 'Ҳисоб сақланди, аммо маҳаллий сеансни ёпиб бўлмади. Қайта рўйхатдан ўтманг; иловани қайта очиб киринг.'
      : 'Hisob saqlandi, ammo mahalliy seansni yopib bo‘lmadi. Qayta ro‘yxatdan o‘tmang; ilovani qayta ochib kiring.';
}
