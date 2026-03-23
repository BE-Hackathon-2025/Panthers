/// Models for the swap points & credits system.

enum PointsTransactionType { earned, spent }

enum PointsTransactionReason {
  swapCompleted,
  priorityBoost,
  requestWithoutReciprocity,
  bonus,
}

enum SkillLevel { beginner, intermediate, advanced }

class PointsTransaction {
  final String id;
  final String uid;
  final PointsTransactionType type;
  final PointsTransactionReason reason;
  final int points;
  final int credits;
  final String description;
  final String? swapRequestId;
  final DateTime createdAt;

  PointsTransaction({
    required this.id,
    required this.uid,
    required this.type,
    required this.reason,
    required this.points,
    required this.credits,
    required this.description,
    this.swapRequestId,
    required this.createdAt,
  });

  factory PointsTransaction.fromJson(Map<String, dynamic> j) {
    return PointsTransaction(
      id: j['id'] as String? ?? '',
      uid: j['uid'] as String? ?? '',
      type: j['type'] == 'spent'
          ? PointsTransactionType.spent
          : PointsTransactionType.earned,
      reason: _parseReason(j['reason'] as String? ?? ''),
      points: j['points'] as int? ?? 0,
      credits: j['credits'] as int? ?? 0,
      description: j['description'] as String? ?? '',
      swapRequestId: j['swap_request_id'] as String?,
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static PointsTransactionReason _parseReason(String r) {
    switch (r) {
      case 'swap_completed':
        return PointsTransactionReason.swapCompleted;
      case 'priority_boost':
        return PointsTransactionReason.priorityBoost;
      case 'request_without_reciprocity':
        return PointsTransactionReason.requestWithoutReciprocity;
      case 'bonus':
        return PointsTransactionReason.bonus;
      default:
        return PointsTransactionReason.bonus;
    }
  }
}

class PointsBalance {
  final String uid;
  final int points;
  final int credits;
  final int totalSwapsCompleted;

  PointsBalance({
    required this.uid,
    required this.points,
    required this.credits,
    required this.totalSwapsCompleted,
  });

  factory PointsBalance.fromJson(Map<String, dynamic> j) {
    return PointsBalance(
      uid: j['uid'] as String? ?? '',
      points: j['points'] as int? ?? 0,
      credits: j['credits'] as int? ?? 0,
      totalSwapsCompleted: j['total_swaps_completed'] as int? ?? 0,
    );
  }
}
