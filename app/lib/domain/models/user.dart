/// The signed-in account (`User` in `API.md`).
class User {
  /// Creates an immutable user.
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.currentRole,
    this.lookingFor,
    this.location,
    this.avatarUrl,
    this.emailVerified = false,
  });

  /// Parses an API user.
  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    email: json['email'] as String,
    fullName: json['fullName'] as String,
    phone: json['phone'] as String?,
    currentRole: json['currentRole'] as String?,
    lookingFor: json['lookingFor'] as String?,
    location: json['location'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    emailVerified: json['emailVerified'] as bool? ?? false,
  );

  final int id;
  final String email;
  final String fullName;
  final String? phone;
  final String? currentRole;
  final String? lookingFor;
  final String? location;
  final String? avatarUrl;
  final bool emailVerified;

  /// First word of the name, for greetings.
  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  /// Up to two initials for the avatar.
  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final last = parts.length > 1 ? parts.last[0] : '';
    return (parts.first[0] + last).toUpperCase();
  }

  /// Returns a copy with the given fields replaced.
  User copyWith({
    String? fullName,
    String? phone,
    String? currentRole,
    String? lookingFor,
    String? location,
    String? avatarUrl,
    bool? emailVerified,
  }) {
    return User(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      currentRole: currentRole ?? this.currentRole,
      lookingFor: lookingFor ?? this.lookingFor,
      location: location ?? this.location,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }

  /// JSON mirror of the API representation.
  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'fullName': fullName,
    'phone': phone,
    'currentRole': currentRole,
    'lookingFor': lookingFor,
    'location': location,
    'avatarUrl': avatarUrl,
    'emailVerified': emailVerified,
  };
}
