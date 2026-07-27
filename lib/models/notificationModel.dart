class NotificationModel {
  final int id;
  final String titre;
  final String message;
  final String? imageUrl;
  final DateTime createdAt;
  final bool isRead; // Conservé par défaut pour l'interface graphique (billes bleues)

  NotificationModel({
    required this.id,
    required this.titre,
    required this.message,
    this.imageUrl,
    required this.createdAt,
    this.isRead = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? 0,
      titre: json['titre'] ?? 'Sans titre',
      message: json['message'] ?? '',
      imageUrl: json['image_url'],
      createdAt: json['created_at'] != null 
          ? (json['created_at'] is String 
              ? DateTime.parse(json['created_at']) 
              : DateTime.parse(json['created_at']['date']))
          : DateTime.now(),
      isRead: json['is_read'] ?? false,
    );
  }
}