import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:one_hunderd/features/challenges/models/challenge_invitation.dart';
import 'package:one_hunderd/features/challenges/models/deposit.dart';

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
  /// 5. الحد الأقصى 3 دعوات معلقة في وقت واحد
  static Future<void> sendInvitation({
    required String toUid,
    required ChallengeType type,
    String senderName = '',
    int senderAvatarIndex = 0,
  }) async {
    if (toUid == _myUid) {
      throw Exception('لا يمكنك إرسال دعوة لنفسك!');
    }

    // ── 1. التحقق من حالتي أنا: هل أنا في تحدي نشط؟ ──
    final myActive = await getMyActiveChallenge();
    if (myActive != null) {
      throw Exception('أنت مرتبط بتحدي نشط بالفعل! لا يمكنك إرسال دعوات جديدة.');
    }

    // ── 2. التحقق من حالة الطرف الآخر: هل هو في تحدي نشط؟ ──
    final otherActive = await _hasActiveChallenge(toUid);
    if (otherActive) {
      throw Exception('هذا الشخص في تحدي نشط حالياً ولا يمكن دعوته!');
    }

    // ── 3. فحص الدعوات المعلقة المرسلة: التنظيف + منع التكرار + تطبيق الحد الأقصى ──
    final pendingSent = await _db
        .collection(_collection)
        .where('fromUid', isEqualTo: _myUid)
        .where('status', isEqualTo: 'pending')
        .get();

    int activePendingCount = 0;
    final now = DateTime.now();
    final batch = _db.batch();
    bool batchHasDeletes = false;

    for (final doc in pendingSent.docs) {
      final data = doc.data();
      final to = data['toUid'] as String?;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

      if (createdAt != null && now.difference(createdAt).inDays >= 7) {
        // انتهت الصلاحية → حذف من قاعدة البيانات
        batch.delete(doc.reference);
        batchHasDeletes = true;
        continue;
      }

      if (to == toUid) {
        throw Exception('لديك دعوة معلقة لهذا الشخص بالفعل!');
      }

      activePendingCount++;
    }

    // تطبيق حذف الدعوات المنتهية أولاً
    if (batchHasDeletes) await batch.commit();

    if (activePendingCount >= 3) {
      throw Exception(
        'وصلت للحد الأقصى (3 دعوات معلقة). انتظر حتى يُرد عليها أو تنتهي صلاحيتها.',
      );
    }

    // ── 4. جلب بيانات المرسل إذا لم تُمرَّر ──
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

    // ── 5. إنشاء الدعوة ──
    final invitation = ChallengeInvitation(
      id: '',
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

    final List<Deposit> mergedDeposits = [];
    int mergedCoins = 0;
    int mergedLifebuoys = 0;
    int streakA = 0;
    String? lastDepositDateA;
    Timestamp? completedAtA;

    if (invitation.type == ChallengeType.cooperative) {
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
      mergedCoins = coinsA + coinsB;

      final lifebuoysA = docA.data()?['lifebuoys_v1'] as int? ?? 0;
      final lifebuoysB = docB.data()?['lifebuoys_v1'] as int? ?? 0;
      mergedLifebuoys = lifebuoysA + lifebuoysB;

      streakA = docA.data()?['current_streak_v1'] as int? ?? 0;
      lastDepositDateA = docA.data()?['last_deposit_date_v1'] as String?;
      completedAtA = docA.data()?['completedAt'] as Timestamp?;
    }

    final batch = _db.batch();

    // 1. قبول الدعوة
    batch.update(docRef, {'status': 'accepted'});

    // 2. حذف جميع الدعوات المعلقة الأخرى لكلا الطرفين (ليس تغيير حالة، بل حذف كلي)
    await _cancelAllPendingInvitations(
      excludeId: invitationId,
      batch: batch,
    );

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

    final String collectionName = invitation.type == ChallengeType.competitive 
        ? 'competitive_sessions' 
        : 'cooperative_sessions';

    // ── 3. إنشاء مستند الجلسة التعاونية أو التنافسية بمعرف الدعوة ──
    // استخدام invitation.id كمعرف للجلسة يمنع التكرار (Idempotency)
    final sessionRef = _db.collection(collectionName).doc(invitationId);
    final sessionData = <String, dynamic>{
      'id': invitationId,
      'users': [invitation.fromUid, invitation.toUid],
      'inviterUid': invitation.fromUid,
      'inviteeUid': invitation.toUid,
      'userNames': {invitation.fromUid: nameA, invitation.toUid: nameB},
      'userAvatars': {invitation.fromUid: avatarA, invitation.toUid: avatarB},
      'financialGoal': financialGoalA,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'active',
      if (invitation.type == ChallengeType.cooperative) ...{
        'deposits': mergedDeposits.map((d) => d.toJson()).toList(),
        'currentStreak': streakA,
        'lifebuoys': mergedLifebuoys,
        'woodenCoins': mergedCoins,
        'lastDepositDate': lastDepositDateA,
        'completedAt': completedAtA,
      } else ...{
        'deposits': <dynamic>[],
        'currentStreak': 0,
        'lifebuoys': 0,
        'woodenCoins': 0,
        'lastDepositDate': null,
        'completedAt': null,
      }
    };
    batch.set(sessionRef, sessionData);

    // 4. تحديث مستند المستقبل (B)
    final userBRef = _db.collection('users').doc(invitation.toUid);
    batch.set(userBRef, {
      'user_profile_v1': {
        'challengeType': invitation.type == ChallengeType.competitive ? 'تنافسي' : 'تعاوني',
        'financialGoal': financialGoalA,
      },
      'activeSessionId': invitationId,
      'cooperativePartnerUid': invitation.fromUid,
      'cooperativePartnerName': nameA,
      'cooperativePartnerAvatarIndex': avatarA,
    }, SetOptions(merge: true));

    // 5. [إصلاح حرج] تحديث مستند المرسل (A) فوراً بدلاً من انتظار فتح التطبيق.
    //    هذا يضمن أن أي شخص يريد إرسال دعوة لـ A يجد حسابه 'تعاوني' فوراً.
    final userARef = _db.collection('users').doc(invitation.fromUid);
    batch.set(userARef, {
      'user_profile_v1': {
        'challengeType': invitation.type == ChallengeType.competitive ? 'تنافسي' : 'تعاوني',
        'financialGoal': financialGoalA,
      },
      'activeSessionId': invitationId,
      'cooperativePartnerUid': invitation.toUid,
      'cooperativePartnerName': nameB,
      'cooperativePartnerAvatarIndex': avatarB,
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

  /// إلغاء وحذف دعوة مرسلة لشخص معين كلياً (كأنها لم تُرسل)
  static Future<void> cancelInvitationByUid(String toUid) async {
    try {
      final snap = await _db
          .collection(_collection)
          .where('fromUid', isEqualTo: _myUid)
          .where('toUid', isEqualTo: toUid)
          .where('status', isEqualTo: 'pending')
          .get();

      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference); // مسحها كلياً من القاعدة
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error in cancelInvitationByUid: $e');
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

  /// جلب الدعوات الواردة المعلقة — مع تصفية وحذف المنتهية
  static Future<List<ChallengeInvitation>> getIncomingInvitations() async {
    try {
      final snap = await _db
          .collection(_collection)
          .where('toUid', isEqualTo: _myUid)
          .where('status', isEqualTo: 'pending')
          .get();

      final now = DateTime.now();
      final validInvitations = <ChallengeInvitation>[];
      final deleteBatch = _db.batch();
      bool hasExpired = false;

      for (final doc in snap.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null && now.difference(createdAt).inDays >= 7) {
          // انتهت الصلاحية → حذف صامت من قاعدة البيانات
          deleteBatch.delete(doc.reference);
          hasExpired = true;
        } else {
          validInvitations.add(ChallengeInvitation.fromFirestore(doc));
        }
      }

      if (hasExpired) deleteBatch.commit().catchError((_) {});

      validInvitations.sort((a, b) {
        final aTime = a.createdAt;
        final bTime = b.createdAt;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return validInvitations;
    } catch (e) {
      debugPrint('Error in getIncomingInvitations: $e');
      return [];
    }
  }

  /// جلب الدعوات المرسلة المعلقة — مع تصفية وحذف المنتهية
  static Future<List<ChallengeInvitation>> getSentPendingInvitations() async {
    try {
      final snap = await _db
          .collection(_collection)
          .where('fromUid', isEqualTo: _myUid)
          .where('status', isEqualTo: 'pending')
          .get();

      final now = DateTime.now();
      final validInvitations = <ChallengeInvitation>[];
      final deleteBatch = _db.batch();
      bool hasExpired = false;

      for (final doc in snap.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null && now.difference(createdAt).inDays >= 7) {
          deleteBatch.delete(doc.reference);
          hasExpired = true;
        } else {
          validInvitations.add(ChallengeInvitation.fromFirestore(doc));
        }
      }

      if (hasExpired) deleteBatch.commit().catchError((_) {});

      return validInvitations;
    } catch (e) {
      debugPrint('Error in getSentPendingInvitations: $e');
      return [];
    }
  }

  /// التحقق: هل لدى المستخدم الحالي تحدي نشط (دعوة مقبولة)؟
  ///
  /// يعتمد على مصدرين للتحقق:
  /// 1. مستند المستخدم (challengeType) — السريع
  /// 2. مجموعة cooperative_sessions — للتأكيد
  static Future<ChallengeInvitation?> getMyActiveChallenge() async {
    try {
      // ── المصدر الأول: مستند المستخدم ──
      final userDoc = await _db.collection('users').doc(_myUid).get();
      final profile = (userDoc.data()?['user_profile_v1'] as Map<String, dynamic>?) ?? {};
      final challengeType = profile['challengeType'] as String?;

      if (challengeType == 'فردي' || challengeType == null) {
        // الحساب فردي → نظّف أي دعوات accepted عالقة بصمت
        _cleanupOrphanedAcceptedInvitations(_myUid).catchError((_) {});
        return null;
      }

      final isComp = challengeType == 'تنافسي';
      final collectionName = isComp ? 'competitive_sessions' : 'cooperative_sessions';

      // تحقق من وجود جلسة حقيقية نشطة
      final sessionSnap = await _db
          .collection(collectionName)
          .where('users', arrayContains: _myUid)
          .get();

      final hasRealSession = sessionSnap.docs.any(
        (doc) => (doc.data()['status'] as String?) == 'active',
      );

      if (!hasRealSession) {
        // نوع الحساب يقول تعاوني لكن لا توجد جلسة حقيقية نشطة
        // → ينظّف الدعوات العالقة ويُعيد null
        _cleanupOrphanedAcceptedInvitations(_myUid).catchError((_) {});
        return null;
      }

      // ── المصدر الثاني: مجموعة الدعوات ──
      final sentSnap = await _db
          .collection(_collection)
          .where('fromUid', isEqualTo: _myUid)
          .where('status', isEqualTo: 'accepted')
          .limit(1)
          .get();
      if (sentSnap.docs.isNotEmpty) {
        return ChallengeInvitation.fromFirestore(sentSnap.docs.first);
      }

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
  ///
  /// يعتمد على مصدرين للتأكيد:
  /// 1. challengeType في مستند المستخدم
  /// 2. cooperative_sessions للتحقق من وجود جلسة حقيقية (فقط إذا كان المستعلم هو نفس المستخدم uid == _myUid)
  static Future<bool> _hasActiveChallenge(String uid) async {
    try {
      // ── المصدر الأول: مستند المستخدم ──
      final userDoc = await _db.collection('users').doc(uid).get();
      final profile = (userDoc.data()?['user_profile_v1'] as Map<String, dynamic>?) ?? {};
      final challengeType = profile['challengeType'] as String?;

      if (challengeType == 'فردي' || challengeType == null) {
        // الحساب فردي قطعاً → نظّف أي invitations عالقة بصمت
        if (uid == _myUid) {
          _cleanupOrphanedAcceptedInvitations(uid).catchError((_) {});
        }
        return false;
      }

      // challengeType == 'تعاوني'
      
      // لا نملك صلاحية قراءة جلسات الطرف الآخر (سيحدث خطأ Permission Denied)، 
      // لذلك نثق ببيانات الملف الشخصي للطرف الآخر لمنع إرسال الدعوات إليه.
      if (uid != _myUid) {
        return true; 
      }

      // إذا كان الحساب هو حسابي،
      // 1. فحص التحدي التعاوني
      final sessionSnapCoop = await _db
          .collection('cooperative_sessions')
          .where('users', arrayContains: uid)
          .get();

      // 2. فحص التحدي التنافسي
      final sessionSnapComp = await _db
          .collection('competitive_sessions')
          .where('users', arrayContains: uid)
          .get();

      final hasRealSession = sessionSnapCoop.docs.any(
        (doc) => (doc.data()['status'] as String?) == 'active',
      ) || sessionSnapComp.docs.any(
        (doc) => (doc.data()['status'] as String?) == 'active',
      );

      if (!hasRealSession) {
        // challengeType يقول تعاوني أو تنافسي لكن لا جلسة نشطة → حالة orphaned
        _cleanupOrphanedAcceptedInvitations(uid).catchError((_) {});
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error in _hasActiveChallenge: $e');
      // في حالة حدوث أي خطأ، نعيد true لمنع إرسال دعوة بالخطأ كإجراء احترازي
      return true; 
    }
  }

  /// تنظيف أي دعوات مقبولة عالقة إذا كان الحساب فردياً
  static Future<void> _cleanupOrphanedAcceptedInvitations(String uid) async {
    try {
      final batch = _db.batch();
      final sentSnap = await _db.collection(_collection).where('fromUid', isEqualTo: uid).where('status', isEqualTo: 'accepted').get();
      for (final doc in sentSnap.docs) {
        batch.update(doc.reference, {'status': 'dissolved'});
      }
      final recvSnap = await _db.collection(_collection).where('toUid', isEqualTo: uid).where('status', isEqualTo: 'accepted').get();
      for (final doc in recvSnap.docs) {
        batch.update(doc.reference, {'status': 'dissolved'});
      }
      await batch.commit();
    } catch (_) {}
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
        .map((snap) {
          final now = DateTime.now();
          int count = 0;
          for (final doc in snap.docs) {
            final data = doc.data();
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            if (createdAt != null && now.difference(createdAt).inDays >= 7) {
              // منتهية → احذفها في الخلفية بصمت
              doc.reference.delete().catchError((_) {});
            } else {
              count++;
            }
          }
          return count;
        });
  }

  /// Stream يُرجع قائمة الدعوات الواردة المعلقة (لشاشة الطلبات)
  static Stream<List<ChallengeInvitation>> incomingInvitationsStream() {
    return _db
        .collection(_collection)
        .where('toUid', isEqualTo: _myUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
          final list = <ChallengeInvitation>[];
          for (final doc in snap.docs) {
            final inv = ChallengeInvitation.fromFirestore(doc);
            if (inv.isExpired) {
              // منتهية → احذفها في الخلفية ولا تعرضها
              doc.reference.delete().catchError((_) {});
            } else {
              list.add(inv);
            }
          }
          list.sort((a, b) {
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

  static Future<void> _cancelAllPendingInvitations({
    required String excludeId,
    required WriteBatch batch,
  }) async {
    // لا يمكننا الاستعلام عن دعوات الطرف الآخر أو حذفها بسبب قواعد الأمان
    // لذلك نقوم فقط بتنظيف الدعوات الخاصة بالمستخدم الحالي (الذي يقبل الدعوة)
    
    // الدعوات المرسلة من المستخدم الحالي
    final sentSnap = await _db
        .collection(_collection)
        .where('fromUid', isEqualTo: _myUid)
        .where('status', isEqualTo: 'pending')
        .get();

    for (final doc in sentSnap.docs) {
      if (doc.id != excludeId) {
        batch.delete(doc.reference);
      }
    }

    // الدعوات الواردة للمستخدم الحالي
    final recvSnap = await _db
        .collection(_collection)
        .where('toUid', isEqualTo: _myUid)
        .where('status', isEqualTo: 'pending')
        .get();

    for (final doc in recvSnap.docs) {
      if (doc.id != excludeId) {
        batch.delete(doc.reference);
      }
    }
  }

  /// Stream to listen to real-time updates of the active session
  static Stream<DocumentSnapshot<Map<String, dynamic>>> activeSessionStream(
    String sessionId, {
    bool isCompetitive = false,
  }) {
    return _db.collection(isCompetitive ? 'competitive_sessions' : 'cooperative_sessions').doc(sessionId).snapshots();
  }

  /// Queries Firestore to find if the user has an active cooperative session
  static Future<DocumentSnapshot<Map<String, dynamic>>?> getActiveSession(
      String uid) async {
    try {
      var snap = await _db
          .collection('cooperative_sessions')
          .where('users', arrayContains: uid)
          .get();

      for (var doc in snap.docs) {
        if (doc.data()['status'] == 'active') {
          return doc;
        }
      }

      snap = await _db
          .collection('competitive_sessions')
          .where('users', arrayContains: uid)
          .get();

      for (var doc in snap.docs) {
        if (doc.data()['status'] == 'active') {
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
