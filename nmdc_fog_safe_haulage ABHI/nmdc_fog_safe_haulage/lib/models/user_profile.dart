class UserProfile {
  final String uid;
  final String fullName;
  final String email;
  final String employeeId;
  final String role; // 'Driver', 'Safety Officer', 'Admin', 'Operator'
  final String status; // 'pending', 'approved', 'rejected'
  final bool approved;
  final DateTime? createdAt;

  UserProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.employeeId,
    required this.role,
    required this.status,
    required this.approved,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'employeeId': employeeId,
      'role': role,
      'status': status,
      'approved': approved,
      'createdAt': createdAt,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map, String documentId) {
    return UserProfile(
      uid: documentId,
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      employeeId: map['employeeId'] ?? '',
      role: map['role'] ?? 'Driver',
      status: map['status'] ?? 'pending',
      approved: map['approved'] ?? false,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is DateTime 
              ? map['createdAt'] 
              : map['createdAt'].toDate())
          : null,
    );
  }
}
