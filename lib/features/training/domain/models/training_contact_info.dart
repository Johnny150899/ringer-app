class TrainingContactInfo {
  const TrainingContactInfo({
    required this.clubName,
    required this.address,
    required this.contactName,
    required this.phone,
    required this.email,
  });

  final String clubName;
  final String address;
  final String contactName;
  final String phone;
  final String email;

  static const defaults = TrainingContactInfo(
    clubName: 'KSC Olympia Graben-Neudorf',
    address: 'Friedrichstaler Str. 25\n76676 Graben-Neudorf',
    contactName: 'Reinhold Kessel',
    phone: '07255 5960',
    email: 'KSCOlympiaGN@gmail.com',
  );

  factory TrainingContactInfo.fromJson(Map<String, dynamic> json) {
    return TrainingContactInfo(
      clubName: json['club_name'] as String? ?? defaults.clubName,
      address: json['training_address'] as String? ?? defaults.address,
      contactName: json['contact_name'] as String? ?? defaults.contactName,
      phone: json['phone'] as String? ?? defaults.phone,
      email: json['email'] as String? ?? defaults.email,
    );
  }

  Map<String, dynamic> toJson() => {
    'club_name': clubName,
    'training_address': address,
    'contact_name': contactName,
    'phone': phone,
    'email': email,
  };
}
