import 'package:cloud_firestore/cloud_firestore.dart';

/// نوع التحدي
enum ChallengeType {
  cooperative, // تعاوني
  competitive, // تنافسي
}

/// حالة الدعوة
enum InvitationStatus {
  pending,   // معلّقة
  accepted,  // مقبولة
  rejected,  // مرفوضة
  cancelled, // ملغاة
}

/// نموذج دعوة التحدي — يمثل دعوة مرسلة من مستخدم لآخر
/// للانضمام إلى نظام تحدي (تعاوني أو تنافسي).
class ChallengeInvitation {
  final String id;
  final String fromUid;
  final String toUid;
  final ChallengeType type;
  final InvitationStatus status;
  final String senderName;
  final int senderAvatarIndex;
  final DateTime? createdAt;

  const ChallengeInvitation({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.type,
    required this.status,
    required this.senderName,
    required this.senderAvatarIndex,
    this.createdAt,
  });

  /// إنشاء النموذج من وثيقة Firestore
  factory ChallengeInvitation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChallengeInvitation(
      id: doc.id,
      fromUid: data['fromUid'] as String? ?? '',
      toUid: data['toUid'] as String? ?? '',
      type: _parseType(data['type'] as String?),
      status: _parseStatus(data['status'] as String?),
      senderName: data['senderName'] as String? ?? 'مستخدم',
      senderAvatarIndex: (data['senderAvatarIndex'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// تحويل النموذج إلى Map لحفظه في Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'fromUid': fromUid,
      'toUid': toUid,
      'type': type.name,
      'status': status.name,
      'senderName': senderName,
      'senderAvatarIndex': senderAvatarIndex,
      'createdAt': FieldValue.serverTimestamp(),
      'notify': true,
    };
  }

  /// نسخة معدّلة من النموذج
  ChallengeInvitation copyWith({InvitationStatus? status}) {
    return ChallengeInvitation(
      id: id,
      fromUid: fromUid,
      toUid: toUid,
      type: type,
      status: status ?? this.status,
      senderName: senderName,
      senderAvatarIndex: senderAvatarIndex,
      createdAt: createdAt,
    );
  }

  // ── تحويل النصوص إلى Enum ──────────────────────────────────────────────────

  static ChallengeType _parseType(String? value) {
    switch (value) {
      case 'cooperative':
        return ChallengeType.cooperative;
      case 'competitive':
        return ChallengeType.competitive;
      default:
        return ChallengeType.cooperative;
    }
  }

  static InvitationStatus _parseStatus(String? value) {
    switch (value) {
      case 'pending':
        return InvitationStatus.pending;
      case 'accepted':
        return InvitationStatus.accepted;
      case 'rejected':
        return InvitationStatus.rejected;
      case 'cancelled':
        return InvitationStatus.cancelled;
      default:
        return InvitationStatus.pending;
    }
  }
}
