class DistributorOutlet {
  final int id;
  final String code;
  final String ownerName;
  final String location;
  final bool isActive;
  final bool isDeleted;

  DistributorOutlet({
    required this.id,
    required this.code,
    required this.ownerName,
    required this.location,
    required this.isActive,
    this.isDeleted = false,
  });

  String get display => '$code — $ownerName — $location';

  factory DistributorOutlet.fromJson(Map<String, dynamic> j) => DistributorOutlet(
        id: j['id'] as int,
        code: j['code'] as String? ?? '',
        ownerName: j['owner_name'] as String? ?? '',
        location: j['location'] as String? ?? '',
        isActive: j['is_active'] as bool? ?? true,
        isDeleted: j['is_deleted'] as bool? ?? false,
      );

  Map<String, dynamic> toCreateJson() => {
        'code': code.trim().toUpperCase(),
        'owner_name': ownerName,
        'location': location,
        'is_active': isActive,
      };

  Map<String, dynamic> toUpdateJson() => {
        'code': code.trim().toUpperCase(),
        'owner_name': ownerName,
        'location': location,
      };
}
