class UserModel {
  final int? id;
  final String fullName;
  final String email;
  final String password;
  final String currency;

  UserModel({
    this.id,
    required this.fullName,
    required this.email,
    required this.password,
    this.currency = 'IDR (Rupiah Indonesia)',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'password': password,
      'currency': currency,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      currency: map['currency'] ?? 'IDR (Rupiah Indonesia)',
    );
  }
}
