import '../../core/utils/json_helpers.dart';

/// A historical manager-assignment row for a branch.
///
/// One row per assignment in `branch_managers` (backend 2.2). Active
/// rows have `unassignedAt == null`; past rows carry timestamps + actor
/// for both ends of the assignment.
class BranchManagerAssignment {
  final int id;
  final int userId;
  final String userName;
  final String userEmail;
  final DateTime? assignedAt;
  final int? assignedById;
  final String? assignedByName;
  final DateTime? unassignedAt;
  final int? unassignedById;
  final String? unassignedByName;
  final bool isActive;

  const BranchManagerAssignment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.isActive,
    this.assignedAt,
    this.assignedById,
    this.assignedByName,
    this.unassignedAt,
    this.unassignedById,
    this.unassignedByName,
  });

  factory BranchManagerAssignment.fromJson(Map<String, dynamic> json) {
    final user = asMap(json['user']) ?? const {};
    final assignedBy = asMap(json['assigned_by']);
    final unassignedBy = asMap(json['unassigned_by']);

    return BranchManagerAssignment(
      id: asInt(json['id'] ?? 0),
      userId: asInt(user['id'] ?? 0),
      userName: (user['name'] as String?) ?? 'Unknown',
      userEmail: (user['email'] as String?) ?? '',
      assignedAt: parseDate(json['assigned_at']),
      assignedById:
          assignedBy == null ? null : asInt(assignedBy['id'] ?? 0),
      assignedByName: assignedBy?['name'] as String?,
      unassignedAt: parseDate(json['unassigned_at']),
      unassignedById:
          unassignedBy == null ? null : asInt(unassignedBy['id'] ?? 0),
      unassignedByName: unassignedBy?['name'] as String?,
      isActive: asBool(json['is_active'] ?? false),
    );
  }
}