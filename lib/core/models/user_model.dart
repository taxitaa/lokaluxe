class UserModel {
  final int? id;
  final String fullName;
  final String email;
  final String passwordHash;
  final String salt;
  final String currency;
  final String? createdAt;
  final bool biometricEnabled;
  final bool fingerprintEnabled;
  final bool faceIdEnabled;
  final String? securityPin;

  UserModel({
    this.id,
    required this.fullName,
    required this.email,
    required this.passwordHash,
    required this.salt,
    this.currency = 'IDR (Rupiah Indonesia)',
    this.createdAt,
    this.biometricEnabled = false,
    this.fingerprintEnabled = false,
    this.faceIdEnabled = false,
    this.securityPin,
  });

  Map<String, dynamic> toMap() {
    final isAnyBio = biometricEnabled || fingerprintEnabled || faceIdEnabled;
    return {
      if (id != null) 'id': id,
      'fullName': fullName,
      'email': email,
      'passwordHash': passwordHash,
      'salt': salt,
      'currency': currency,
      'createdAt': createdAt ?? DateTime.now().toIso8601String(),
      'biometricEnabled': isAnyBio ? 1 : 0,
      'fingerprintEnabled': fingerprintEnabled ? 1 : 0,
      'faceIdEnabled': faceIdEnabled ? 1 : 0,
      if (securityPin != null) 'securityPin': securityPin,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final bio = (map['biometricEnabled'] as int? ?? 0) == 1;
    final fp = (map['fingerprintEnabled'] as int? ?? (bio ? 1 : 0)) == 1;
    final face = (map['faceIdEnabled'] as int? ?? (bio ? 1 : 0)) == 1;
    return UserModel(
      id: map['id'] as int?,
      fullName: (map['fullName'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      passwordHash: (map['passwordHash'] ?? map['password'] ?? '') as String,
      salt: (map['salt'] ?? '') as String,
      currency: (map['currency'] ?? 'IDR (Rupiah Indonesia)') as String,
      createdAt: map['createdAt'] as String?,
      biometricEnabled: bio || fp || face,
      fingerprintEnabled: fp,
      faceIdEnabled: face,
      securityPin: map['securityPin'] as String?,
    );
  }
}
