class Player {
  final int id;
  final String email;
  final String displayName;
  final bool isGuest;

  const Player({
    required this.id,
    required this.email,
    required this.displayName,
    this.isGuest = false,
  });

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as int,
        email: json['email'] as String,
        displayName: json['display_name'] as String,
        isGuest: json['is_guest'] as bool? ?? false,
      );
}
