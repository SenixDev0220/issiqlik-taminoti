import '../domain/models/app_user.dart';

/// UI/query guards are convenience only: Firestore rules remain authoritative.
abstract final class SecurityPolicy {
  static bool isActive(AppUser? user) => user?.status == UserStatus.active;
  static bool isManager(AppUser? user) => isActive(user) && user!.role != UserRole.member;
  static bool canAccess(AppUser? user, String house) =>
      isActive(user) && (isManager(user) || user!.boilerhouseIds.contains(house));

  static const bundledDrawings = <String>{
    'assets/schemas/bogot.jpg', 'assets/schemas/gurlan.jpg',
    'assets/schemas/khazarasp.jpg', 'assets/schemas/khiva.jpg',
    'assets/schemas/kushkupir.jpg', 'assets/schemas/shovot.jpg',
    'assets/schemas/tuprokkala.jpg', 'assets/schemas/urgench_shahar.jpg',
    'assets/schemas/urgench_tuman.jpg', 'assets/schemas/yangiariq.jpg',
    'assets/schemas/yangibozor.jpg',
  };
  static bool isBundledDrawing(String path) => bundledDrawings.contains(path);
  static String normalizeLogin(String login) => login.trim().toLowerCase();
  static String normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[\s()-]'), '');
    if (RegExp(r'^[0-9]{9}$').hasMatch(digits)) return '+998$digits';
    if (RegExp(r'^998[0-9]{9}$').hasMatch(digits)) return '+$digits';
    return digits;
  }
  static bool validLogin(String login) => RegExp(r'^[a-z0-9._-]{3,40}$').hasMatch(login);
  static bool validPhone(String phone) => RegExp(r'^\+[1-9][0-9]{8,14}$').hasMatch(phone);
}
