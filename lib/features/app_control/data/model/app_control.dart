import 'package:equatable/equatable.dart';

class AppControl extends Equatable {
  const AppControl({
    required this.isBlocked,
    required this.messageAr,
    required this.messageEn,
    this.updatedAt,
  });

  factory AppControl.fromJson(final Map<String, dynamic> json) {
    return AppControl(
      isBlocked: json['is_blocked'] == true,
      messageAr: json['message_ar'] as String? ?? 'التطبيق متوقف مؤقتًا.',
      messageEn: json['message_en'] as String? ??
          'The app is temporarily unavailable.',
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }

  static const open = AppControl(
    isBlocked: false,
    messageAr: 'التطبيق متاح.',
    messageEn: 'The app is available.',
  );

  final bool isBlocked;
  final String messageAr;
  final String messageEn;
  final DateTime? updatedAt;

  String messageFor(final String languageCode) =>
      languageCode == 'ar' ? messageAr : messageEn;

  @override
  List<Object?> get props =>
      <Object?>[isBlocked, messageAr, messageEn, updatedAt];
}
