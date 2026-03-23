/// Models for swap requests.

enum SwapRequestStatus { pending, accepted, declined, cancelled, completed }

/// Minimal profile info for swap request participants.
class SwapParticipant {
  final String uid;
  final String? displayName;
  final String? photoUrl;
  final String? email;
  final String? skillsToOffer;
  final String? servicesNeeded;

  SwapParticipant({
    required this.uid,
    this.displayName,
    this.photoUrl,
    this.email,
    this.skillsToOffer,
    this.servicesNeeded,
  });

  factory SwapParticipant.fromJson(Map<String, dynamic> json) =>
      SwapParticipant(
        uid: json['uid'] as String? ?? '',
        displayName: json['display_name'] as String?,
        photoUrl: json['photo_url'] as String?,
        email: json['email'] as String?,
        skillsToOffer: json['skills_to_offer'] as String?,
        servicesNeeded: json['services_needed'] as String?,
      );
}

/// A swap request between two users.
class SwapRequest {
  final String id;
  final String requesterUid;
  final String recipientUid;
  final SwapRequestStatus status;
  final String requesterOffer;
  final String requesterNeed;
  final String? message;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? respondedAt;
  final String? conversationId;
  final SwapParticipant? requesterProfile;
  final SwapParticipant? recipientProfile;
  final bool requesterConfirmed;
  final bool recipientConfirmed;
  final String? requesterOfferSkillId;
  final String? requesterNeedSkillId;

  SwapRequest({
    required this.id,
    required this.requesterUid,
    required this.recipientUid,
    required this.status,
    required this.requesterOffer,
    required this.requesterNeed,
    this.message,
    required this.createdAt,
    required this.updatedAt,
    this.respondedAt,
    this.conversationId,
    this.requesterProfile,
    this.recipientProfile,
    this.requesterConfirmed = false,
    this.recipientConfirmed = false,
    this.requesterOfferSkillId,
    this.requesterNeedSkillId,
  });

  factory SwapRequest.fromJson(Map<String, dynamic> json) => SwapRequest(
        id: json['id'] as String? ?? '',
        requesterUid: json['requester_uid'] as String? ?? '',
        recipientUid: json['recipient_uid'] as String? ?? '',
        status: _parseStatus(json['status'] as String?),
        requesterOffer: json['requester_offer'] as String? ?? '',
        requesterNeed: json['requester_need'] as String? ?? '',
        message: json['message'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : DateTime.now(),
        respondedAt: json['responded_at'] != null
            ? DateTime.parse(json['responded_at'] as String)
            : null,
        conversationId: json['conversation_id'] as String?,
        requesterProfile: json['requester_profile'] != null
            ? SwapParticipant.fromJson(
                json['requester_profile'] as Map<String, dynamic>)
            : null,
        recipientProfile: json['recipient_profile'] != null
            ? SwapParticipant.fromJson(
                json['recipient_profile'] as Map<String, dynamic>)
            : null,
        requesterConfirmed: json['requester_confirmed'] as bool? ?? false,
        recipientConfirmed: json['recipient_confirmed'] as bool? ?? false,
        requesterOfferSkillId: json['requester_offer_skill_id'] as String?,
        requesterNeedSkillId: json['requester_need_skill_id'] as String?,
      );

  static SwapRequestStatus _parseStatus(String? status) {
    switch (status) {
      case 'accepted':
        return SwapRequestStatus.accepted;
      case 'declined':
        return SwapRequestStatus.declined;
      case 'cancelled':
        return SwapRequestStatus.cancelled;
      case 'completed':
        return SwapRequestStatus.completed;
      default:
        return SwapRequestStatus.pending;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'requester_uid': requesterUid,
        'recipient_uid': recipientUid,
        'status': status.name,
        'requester_offer': requesterOffer,
        'requester_need': requesterNeed,
        'message': message,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'responded_at': respondedAt?.toIso8601String(),
        'conversation_id': conversationId,
        'requester_confirmed': requesterConfirmed,
        'recipient_confirmed': recipientConfirmed,
        'requester_offer_skill_id': requesterOfferSkillId,
        'requester_need_skill_id': requesterNeedSkillId,
      };

  /// Whether this request is pending and awaiting a response.
  bool get isPending => status == SwapRequestStatus.pending;

  /// Whether this request was accepted.
  bool get isAccepted => status == SwapRequestStatus.accepted;

  /// Whether this request was declined.
  bool get isDeclined => status == SwapRequestStatus.declined;

  /// Whether this request was cancelled.
  bool get isCancelled => status == SwapRequestStatus.cancelled;

  /// Whether this swap is completed.
  bool get isCompleted => status == SwapRequestStatus.completed;
}
