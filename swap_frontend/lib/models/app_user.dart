class AppUser {
final String uid;
final String email;
final String? displayName;
final String? photoUrl;
final DateTime createdAt;


AppUser({
required this.uid,
required this.email,
this.displayName,
this.photoUrl,
required this.createdAt,
});


Map<String, dynamic> toMap() => {
'uid': uid,
'email': email,
'displayName': displayName,
'photoUrl': photoUrl,
'createdAt': createdAt.toIso8601String(),
};
}