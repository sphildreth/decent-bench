class SqlSnippet {
  const SqlSnippet({
    required this.id,
    required this.name,
    required this.trigger,
    required this.body,
    this.description = '',
  });

  final String id;
  final String name;
  final String trigger;
  final String description;
  final String body;

  SqlSnippet copyWith({
    String? id,
    String? name,
    String? trigger,
    String? description,
    String? body,
  }) {
    return SqlSnippet(
      id: id ?? this.id,
      name: name ?? this.name,
      trigger: trigger ?? this.trigger,
      description: description ?? this.description,
      body: body ?? this.body,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'trigger': trigger,
      'description': description,
      'body': body,
    };
  }

  factory SqlSnippet.fromJson(Map<String, Object?> map) {
    return SqlSnippet(
      id: map['id']! as String,
      name: map['name']! as String,
      trigger: map['trigger']! as String,
      description: map['description'] as String? ?? '',
      body: map['body']! as String,
    );
  }
}
