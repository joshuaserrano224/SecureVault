class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String? profilePic;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.profilePic,
  });

  // Convert a Map (from a DB) into a UserModel
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      profilePic: map['profilePic'],
    );
  }

  // Convert UserModel to Map for saving to a DB
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'profilePic': profilePic,
    };
  }
}