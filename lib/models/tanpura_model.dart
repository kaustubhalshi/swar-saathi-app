class TanpuraModel {
  final String name;
  final String filePath;
  final int order;

  TanpuraModel({
    required this.name,
    required this.filePath,
    required this.order,
  });

  factory TanpuraModel.fromFirestore(Map<String, dynamic> data) {
    return TanpuraModel(
      name: data['name'] ?? '',
      filePath: data['filePath'] ?? '',
      order: data['order'] ?? 0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TanpuraModel &&
        other.name == name &&
        other.filePath == filePath &&
        other.order == order;
  }

  @override
  int get hashCode => name.hashCode ^ filePath.hashCode ^ order.hashCode;
}
