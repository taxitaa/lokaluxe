class UserModel {
  final int? id;
  final String fullName;
  final String email;
  final String passwordHash;
  final String salt;
  final String currency;
  final String? createdAt;

  UserModel({
    this.id,
    required this.fullName,
    required this.email,
    required this.passwordHash,
    required this.salt,
    this.currency = 'IDR (Rupiah Indonesia)',
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'fullName': fullName,
      'email': email,
      'passwordHash': passwordHash,
      'salt': salt,
      'currency': currency,
      'createdAt': createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      fullName: (map['fullName'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      passwordHash: (map['passwordHash'] ?? map['password'] ?? '') as String,
      salt: (map['salt'] ?? '') as String,
      currency: (map['currency'] ?? 'IDR (Rupiah Indonesia)') as String,
      createdAt: map['createdAt'] as String?,
    );
  }
}
