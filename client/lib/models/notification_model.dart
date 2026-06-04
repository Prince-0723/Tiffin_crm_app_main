class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    this.read = false,
    this.type,
  });

  final String id;
  final String title;
  final String body;
  final DateTime time;
  final bool read;
  final String? type;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? '';
    final title = json['title']?.toString() ?? '';
    final message = json['message']?.toString() ?? '';
    final sentAt = json['sentAt'] ?? json['createdAt'];
    DateTime time = DateTime.now();
    if (sentAt != null) {
      if (sentAt is String) time = DateTime.tryParse(sentAt) ?? time;
      if (sentAt is Map && sentAt['\$date'] != null) {
        time = DateTime.tryParse(sentAt['\$date'].toString()) ?? time;
      }
    }
    return NotificationModel(
      id: id,
      title: title,
      body: message,
      time: time,
      read: json['isRead'] == true,
      type: json['type']?.toString(),
    );
  }
}
