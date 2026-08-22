class Player {
  final int id;
  final String email;
  final String displayName;

  const Player({required this.id, required this.email, required this.displayName});

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as int,
        email: json['email'] as String,
        displayName: json['display_name'] as String,
      );
}
