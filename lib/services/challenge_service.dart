import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/challenge_invitation.dart';
import '../models/deposit.dart';

/// خدمة إدارة دعوات التحدي (التعاوني / التنافسي)
///
/// تتعامل مع مجموعة `challenge_invitations` في Firestore.
/// مصممة لتكون الأساس الذي تُبنى عليه المراحل القادمة
/// (إنشاء الجلسة المشتركة، الدمج، إلخ).
class ChallengeService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static const _collection = 'challenge_invitations';

  static String get _myUid => _auth.currentUser!.uid;

  // ═══════════════════════════════════════════════════════════════════════════
  // إرسال الدعوات
  // ═══════════════════════════════════════════════════════════════════════════

  /// إرسال دعوة تحدي لمستخدم آخر.
  ///
  /// التحققات:
  /// 1. لا يمكن إرسال دعوة لنفسك
  /// 2. لا يمكن إرسال دعوة إذا كنت مرتبطاً بتحدي نشط
  /// 3. لا يمكن إرسال دعوة إذا كان الطرف الآخر مرتبطاً بتحدي نشط
  /// 4. لا يمكن إرسال دعوة مكررة (معلقة) لنفس الشخص
  static Future<void> sendInvitation({
    required String toUid,
    required ChallengeType type,
    String senderName = '',
    int senderAvatarIndex = 0,
  }) async {
    if (toUid == _myUid) {
      throw Exception('لا يمكنك إرسال دعوة لنفسك!');
    }

    // التحقق: هل أنا مرتبط بتحدي نشط؟
    final myActive = await getMyActiveChallenge();
    if (myActive != null) {
      throw Exception(
        'أنت مرتبط بتحدي نشط بالفعل! لا يمكنك إرسال دعوات جديدة.',
      );
    }

    // التحقق: هل الشخص الآخر مرتبط بتحدي نشط؟
    final otherActive = await _hasActiveChallenge(toUid);
    if (otherActive) {
      throw Exception('هذا الشخص مرتبط بتحدي نشط بالفعل!');
    }

    // التحقق: هل هناك دعوة معلقة بالفعل؟
    final existing = await _db
        .collection(_collection)
        .where('fromUid', isEqualTo: _myUid)
        .where('toUid', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception('لديك دعوة معلقة لهذا الشخص بالفعل!');
    }

    // جلب اسم المرسل إذا لم يُمرَّر
    String name = senderName;
    int avatarIdx = senderAvatarIndex;
    if (name.isEmpty) {
      final myDoc = await _db.collection('users').doc(_myUid).get();
      if (myDoc.exists) {
        final data = myDoc.data() ?? {};
        final profile = data['user_profile_v1'] as Map<String, dynamic>? ?? {};
        name = profile['fullName'] as String? ?? 'مستخدم';
        avatarIdx = (data['avatarIndex'] as num?)?.toInt() ?? 0;
      }
    }

    // إنشاء الدعوة
    final invitation = ChallengeInvitation(
      id: '', // سيتم تعيينه من Firestore
      fromUid: _myUid,
      toUid: toUid,
      type: type,
      status: InvitationStatus.pending,
      senderName: name,
      senderAvatarIndex: avatarIdx,
    );

    await _db.collection(_collection).add(invitation.toFirestore());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // قبول / رفض / إلغاء الدعوات
  // ═══════════════════════════════════════════════════════════════════════════

  /// قبول دعوة واردة.
  ///
  /// عند القبول:
  /// 1. يتم تحديث حالة الدعوة إلى `accepted`
  /// 2. يتم إلغاء جميع الدعوات المعلقة الأخرى لكلا الطرفين
  ///    (لأن المستخدم يقدر يكون في نظام واحد فقط)
  ///
  /// ملاحظة: في المرحلة الثانية، سيتم إنشاء `cooperative_session`
  /// هنا بعد القبول مباشرة.
  static Future<void> acceptInvitation(String invitationId) async {
    final docRef = _db.collection(_collection).doc(invitationId);
    final docSnap = await docRef.get();

    if (!docSnap.exists) {
      throw Exception('الدعوة غير موجودة!');
    }

    final invitation = ChallengeInvitation.fromFirestore(docSnap);

    // التحقق: هل الدعوة موجهة لي؟
    if (invitation.toUid != _myUid) {
      throw Exception('هذه الدعوة ليست لك!');
    }

    // التحقق: هل الدعوة لا تزال معلقة؟
    if (invitation.status != InvitationStatus.pending) {
      throw Exception('هذه الدعوة لم تعد معلقة!');
    }

    // التحقق: هل أنا مرتبط بتحدي نشط بالفعل؟
    final myActive = await getMyActiveChallenge();
    if (myActive != null) {
      throw Exception('أنت مرتبط بتحدي نشط بالفعل!');
    }

    // ─── المرحلة الثانية: تحميل سجلات الطرفين ودمجها ───
    final docA = await _db.collection('users').doc(invitation.fromUid).get();
    final docB = await _db.collection('users').doc(invitation.toUid).get();

    if (!docA.exists || !docB.exists) {
      throw Exception('أحد الحسابات المرتبطة بالدعوة غير موجود!');
    }

    final rawDepsA = docA.data()?['deposits_v1'] as List<dynamic>? ?? [];
    final depositsA = rawDepsA
        .map((raw) => Deposit.fromJson(raw as Map<String, dynamic>))
        .toList();

    final rawDepsB = docB.data()?['deposits_v1'] as List<dynamic>? ?? [];
    final depositsB = rawDepsB
        .map((raw) => Deposit.fromJson(raw as Map<String, dynamic>))
        .toList();

    // خوارزمية الدمج والضغط للأيام
    final Map<DateTime, List<Deposit>> depositsByDateA = {};
    for (var dep in depositsA) {
      depositsByDateA.putIfAbsent(dep.dateOnly, () => []).add(dep);
    }
    final uniqueDatesA = depositsByDateA.keys.toList()..sort();

    final Map<DateTime, List<Deposit>> depositsByDateB = {};
    for (var dep in depositsB) {
      depositsByDateB.putIfAbsent(dep.dateOnly, () => []).add(dep);
    }
    final uniqueDatesB = depositsByDateB.keys.toList()..sort();

    final int nA = uniqueDatesA.length;
    final int nB = uniqueDatesB.length;

    final List<Deposit> mergedDeposits = [];

    // إضافة إيداعات المرسل (A) مع تحديد المساهمة
    for (var dep in depositsA) {
      mergedDeposits.add(
        Deposit(
          id: dep.id,
          amount: dep.amount,
          date: dep.date,
          notes: dep.notes,
          depositedBy: invitation.fromUid,
        ),
      );
    }

    // رسم ومطابقة أيام المستقبل (B) وضغط الفائض
    for (int j = 0; j < nB; j++) {
      final bDate = uniqueDatesB[j];
      final bDeps = depositsByDateB[bDate] ?? [];

      DateTime targetDate;
      if (j < nA) {
        targetDate = uniqueDatesA[j];
      } else {
        if (nA > 0) {
          targetDate = uniqueDatesA[nA - 1];
        } else {
          targetDate = bDate;
        }
      }

      for (var dep in bDeps) {
        mergedDeposits.add(
          Deposit(
            id: dep.id,
            amount: dep.amount,
            date: DateTime(
              targetDate.year,
              targetDate.month,
              targetDate.day,
              dep.date.hour,
              dep.date.minute,
              dep.date.second,
            ),
            notes: dep.notes,
            depositedBy: invitation.toUid,
          ),
        );
      }
    }

    // حساب العملات والستريك وأطواق النجاة المدمجة
    final coinsA = docA.data()?['wooden_coins_v1'] as int? ?? 0;
    final coinsB = docB.data()?['wooden_coins_v1'] as int? ?? 0;
    final mergedCoins = coinsA + coinsB;

    final lifebuoysA = docA.data()?['lifebuoys_v1'] as int? ?? 0;
    final lifebuoysB = docB.data()?['lifebuoys_v1'] as int? ?? 0;
    final mergedLifebuoys = lifebuoysA + lifebuoysB;

    final streakA = docA.data()?['current_streak_v1'] as int? ?? 0;
    final lastDepositDateA = docA.data()?['last_deposit_date_v1'] as String?;
    final completedAtA = docA.data()?['completedAt'] as Timestamp?;

    final batch = _db.batch();

    // 1. قبول الدعوة
    batch.update(docRef, {'status': 'accepted'});

    // 2. إلغاء جميع الدعوات المعلقة الأخرى المرسلة مني أو إلي (للمستقبل)
    await _cancelAllPendingInvitations(excludeId: invitationId, batch: batch);

    // 3. إنشاء مستند الجلسة المشتركة
    final nameA =
        (docA.data()?['user_profile_v1'] as Map<String, dynamic>?)?['fullName']
            as String? ??
        'المرسل';
    final nameB =
        (docB.data()?['user_profile_v1'] as Map<String, dynamic>?)?['fullName']
            as String? ??
        'المستقبل';
    final avatarA = docA.data()?['avatarIndex'] as int? ?? 0;
    final avatarB = docB.data()?['avatarIndex'] as int? ?? 0;

    // الهدف المالي المشترك يكون هدف المرسل (A)
    final financialGoalA =
        ((docA.data()?['user_profile_v1']
                    as Map<String, dynamic>?)?['financialGoal']
                as num?)
            ?.toDouble() ??
        5050.0;

    final sessionRef = _db.collection('cooperative_sessions').doc(invitationId);
    final sessionData = <String, dynamic>{
      'id': invitationId,
      'users': [invitation.fromUid, invitation.toUid],
      'inviterUid': invitation.fromUid,
      'inviteeUid': invitation.toUid,
      'userNames': {invitation.fromUid: nameA, invitation.toUid: nameB},
      'userAvatars': {invitation.fromUid: avatarA, invitation.toUid: avatarB},
      'financialGoal': financialGoalA,
      'createdAt': FieldValue.serverTimestamp(),
      'deposits': mergedDeposits.map((d) => d.toJson()).toList(),
      'currentStreak': streakA,
      'lifebuoys': mergedLifebuoys,
      'woodenCoins': mergedCoins,
      'lastDepositDate': lastDepositDateA,
      'completedAt': completedAtA,
      'status': 'active',
    };
    batch.set(sessionRef, sessionData);

    // 4. تحديث مستند المستقبل (B) الشخصي — الوحيد الذي يملك صلاحية الكتابة عليه
    //    الجهاز الخاص بالمرسل (A) سيُحدِّث مستنده بنفسه عندما يستقبل حدث الجلسة الجديدة.
    final userBRef = _db.collection('users').doc(invitation.toUid);
    batch.set(userBRef, {
      'user_profile_v1': {
        'challengeType': 'تعاوني',
        'financialGoal': financialGoalA,
      },
      'activeSessionId': invitationId,
      'cooperativePartnerUid': invitation.fromUid,
      'cooperativePartnerName': nameA,
      'cooperativePartnerAvatarIndex': avatarA,
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// رفض دعوة واردة
  static Future<void> rejectInvitation(String invitationId) async {
    try {
      await _db.collection(_collection).doc(invitationId).update({
        'status': 'rejected',
      });
    } catch (e) {
      debugPrint('Error in rejectInvitation: $e');
      rethrow;
    }
  }

  /// إلغاء دعوة مرسلة (من المرسل نفسه)
  static Future<void> cancelInvitation(String invitationId) async {
    try {
      final docSnap = await _db.collection(_collection).doc(invitationId).get();
      if (!docSnap.exists) return;

      final data = docSnap.data() ?? {};
      if (data['fromUid'] != _myUid) {
        throw Exception('لا يمكنك إلغاء دعوة لم ترسلها!');
      }

      await _db.collection(_collection).doc(invitationId).update({
        'status': 'cancelled',
      });
    } catch (e) {
      debugPrint('Error in cancelInvitation: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // الاستعلامات
  // ═══════════════════════════════════════════════════════════════════════════

  /// جلب الدعوات الواردة المعلقة مع بيانات المرسل
  static Future<List<ChallengeInvitation>> getIncomingInvitations() async {
    try {
      final snap = await _db
          .collection(_collection)
          .where('toUid', isEqualTo: _myUid)
          .where('status', isEqualTo: 'pending')
          .get();

      return snap.docs
          .map((doc) => ChallengeInvitation.fromFirestore(doc))
          .toList()
        ..sort((a, b) {
          final aTime = a.createdAt;
          final bTime = b.createdAt;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });
    } catch (e) {
      debugPrint('Error in getIncomingInvitations: $e');
      return [];
    }
  }

  /// جلب الدعوات المرسلة المعلقة
  static Future<List<ChallengeInvitation>> getSentPendingInvitations() async {
    try {
      final snap = await _db
          .collection(_collection)
          .where('fromUid', isEqualTo: _myUid)
          .where('status', isEqualTo: 'pending')
          .get();

      return snap.docs
          .map((doc) => ChallengeInvitation.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error in getSentPendingInvitations: $e');
      return [];
    }
  }

  /// التحقق: هل لدى المستخدم الحالي تحدي نشط (دعوة مقبولة)؟
  /// يُرجع الدعوة المقبولة إذا وُجدت، أو null.
  static Future<ChallengeInvitation?> getMyActiveChallenge() async {
    try {
      // التحقق كمرسل
      final sentSnap = await _db
          .collection(_collection)
          .where('fromUid', isEqualTo: _myUid)
          .where('status', isEqualTo: 'accepted')
          .limit(1)
          .get();

      if (sentSnap.docs.isNotEmpty) {
        return ChallengeInvitation.fromFirestore(sentSnap.docs.first);
      }

      // التحقق كمستقبل
      final recvSnap = await _db
          .collection(_collection)
          .where('toUid', isEqualTo: _myUid)
          .where('status', isEqualTo: 'accepted')
          .limit(1)
          .get();

      if (recvSnap.docs.isNotEmpty) {
        return ChallengeInvitation.fromFirestore(recvSnap.docs.first);
      }

      return null;
    } catch (e) {
      debugPrint('Error in getMyActiveChallenge: $e');
      return null;
    }
  }

  /// التحقق: هل مستخدم معين لديه تحدي نشط؟
  static Future<bool> _hasActiveChallenge(String uid) async {
    try {
      final sentSnap = await _db
          .collection(_collection)
          .where('fromUid', isEqualTo: uid)
          .where('status', isEqualTo: 'accepted')
          .limit(1)
          .get();

      if (sentSnap.docs.isNotEmpty) return true;

      final recvSnap = await _db
          .collection(_collection)
          .where('toUid', isEqualTo: uid)
          .where('status', isEqualTo: 'accepted')
          .limit(1)
          .get();

      return recvSnap.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error in _hasActiveChallenge: $e');
      return false;
    }
  }

  /// ينهي جميع الدعوات المقبولة بين مستخدمين (عند الانفصال)
  static Future<void> dissolveChallengeInvitations(
    String myUid,
    String partnerUid,
  ) async {
    try {
      final batch = _db.batch();

      final snap1 = await _db
          .collection(_collection)
          .where('fromUid', isEqualTo: myUid)
          .where('toUid', isEqualTo: partnerUid)
          .where('status', isEqualTo: 'accepted')
          .get();
      for (final doc in snap1.docs) {
        batch.update(doc.reference, {'status': 'dissolved'});
      }

      final snap2 = await _db
          .collection(_collection)
          .where('fromUid', isEqualTo: partnerUid)
          .where('toUid', isEqualTo: myUid)
          .where('status', isEqualTo: 'accepted')
          .get();
      for (final doc in snap2.docs) {
        batch.update(doc.reference, {'status': 'dissolved'});
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error dissolving invitations: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Streams — للاستماع المباشر (النقطة الحمراء والإشعارات)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Stream يُرجع عدد الدعوات الواردة المعلقة (للنقطة الحمراء في الـ Drawer)
  static Stream<int> incomingInvitationsCountStream() {
    return _db
        .collection(_collection)
        .where('toUid', isEqualTo: _myUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Stream يُرجع قائمة الدعوات الواردة المعلقة (لشاشة الطلبات)
  static Stream<List<ChallengeInvitation>> incomingInvitationsStream() {
    return _db
        .collection(_collection)
        .where('toUid', isEqualTo: _myUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
          final list =
              snap.docs
                  .map((doc) => ChallengeInvitation.fromFirestore(doc))
                  .toList()
                ..sort((a, b) {
                  final aTime = a.createdAt;
                  final bTime = b.createdAt;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });
          return list;
        });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // مساعدات داخلية
  // ═══════════════════════════════════════════════════════════════════════════

  /// إلغاء جميع الدعوات المعلقة للمستخدم الحالي (مرسلة ومستقبلة)
  static Future<void> _cancelAllPendingInvitations({
    required String excludeId,
    required WriteBatch batch,
  }) async {
    // الدعوات المرسلة مني
    final sentSnap = await _db
        .collection(_collection)
        .where('fromUid', isEqualTo: _myUid)
        .where('status', isEqualTo: 'pending')
        .get();

    for (final doc in sentSnap.docs) {
      if (doc.id != excludeId) {
        batch.update(doc.reference, {'status': 'cancelled'});
      }
    }

    // الدعوات الواردة إلي
    final recvSnap = await _db
        .collection(_collection)
        .where('toUid', isEqualTo: _myUid)
        .where('status', isEqualTo: 'pending')
        .get();

    for (final doc in recvSnap.docs) {
      if (doc.id != excludeId) {
        batch.update(doc.reference, {'status': 'cancelled'});
      }
    }
  }

  /// Stream to listen to real-time updates of the active cooperative session
  static Stream<DocumentSnapshot<Map<String, dynamic>>> activeSessionStream(
    String sessionId,
  ) {
    return _db.collection('cooperative_sessions').doc(sessionId).snapshots();
  }

  /// Queries Firestore to find if the user has an active cooperative session
  static Future<DocumentSnapshot<Map<String, dynamic>>?> getActiveSession(
    String myUid,
  ) async {
    try {
      final snap = await _db
          .collection('cooperative_sessions')
          .where('users', arrayContains: myUid)
          .limit(5)
          .get();
      // Find the first non-dissolved session
      for (final doc in snap.docs) {
        final status = doc.data()['status'] as String?;
        if (status != 'dissolved') {
          return doc;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting active session: $e');
      return null;
    }
  }
}
