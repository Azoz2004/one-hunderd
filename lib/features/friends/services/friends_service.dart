import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// نموذج بسيط لبيانات المستخدم التي تُعاد من البحث أو قائمة الأصدقاء
class FriendUser {
  final String uid;
  final String fullName;
  final String email;
  final int avatarIndex;

  const FriendUser({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.avatarIndex,
  });

  factory FriendUser.fromFirestore(String uid, Map<String, dynamic> data) {
    final profile = data['user_profile_v1'] as Map<String, dynamic>? ?? {};
    return FriendUser(
      uid: uid,
      fullName: profile['fullName'] as String? ?? 'مستخدم',
      email: profile['contact'] as String? ?? '',
      avatarIndex: (data['avatarIndex'] as num?)?.toInt() ?? 0,
    );
  }
}

/// حالة طلب الصداقة بين المستخدم الحالي وأي مستخدم آخر
enum FriendshipStatus {
  none,      // لا توجد صداقة
  pending,   // طلب مُرسَل في الانتظار
  received,  // طلب مُستقبَل (الآخر أرسل)
  friends,   // أصدقاء بالفعل
  self,      // نفس المستخدم
}

/// خدمة الأصدقاء — كل العمليات تتم في Firestore (server-side)
class FriendsService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get _myUid => _auth.currentUser!.uid;

  // ─── البحث ─────────────────────────────────────────────────────────────────

  /// البحث بالاسم: case-insensitive — يبحث بالحقل fullName_lower وبالحقل fullName بجميع اختلافات حالة الأحرف بالتوازي
  static Future<List<FriendUser>> searchByName(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim();
    final qLower = q.toLowerCase();
    final qUpper = q.toUpperCase();

    // توليد صيغة الحرف الأول كبير والباقي صغير (مثل: Hassan)
    final firstChar = q.isNotEmpty ? q.substring(0, 1) : '';
    final rest = q.length > 1 ? q.substring(1) : '';
    final qCapitalized = firstChar.toUpperCase() + rest.toLowerCase();

    try {
      final List<Future<QuerySnapshot<Map<String, dynamic>>>> futures = [];

      // 1. الاستعلام الأساسي للحسابات المحدثة باستخدام الحقل الموحد fullName_lower
      futures.add(_db
          .collection('users')
          .where('user_profile_v1.fullName_lower', isGreaterThanOrEqualTo: qLower)
          .where('user_profile_v1.fullName_lower', isLessThan: '$qLower\uff9f')
          .limit(15)
          .get());

      // 2. استعلامات متوازية للحسابات القديمة (غير المحدثة) لجميع تنوعات حالات الأحرف المحتملة
      final Set<String> legacyPrefixes = {q, qLower, qUpper, qCapitalized};
      for (final prefix in legacyPrefixes) {
        if (prefix.isNotEmpty) {
          futures.add(_db
              .collection('users')
              .where('user_profile_v1.fullName', isGreaterThanOrEqualTo: prefix)
              .where('user_profile_v1.fullName', isLessThan: '$prefix\uff9f')
              .limit(10)
              .get());
        }
      }

      // تشغيل جميع الاستعلامات بالتوازي لضمان أقصى سرعة
      final results = await Future.wait(futures);
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs = [];
      final seenIds = <String>{};

      for (final snap in results) {
        for (final doc in snap.docs) {
          if (seenIds.add(doc.id)) {
            allDocs.add(doc);
          }
        }
      }

      return allDocs
          .where((d) => d.id != _myUid)
          .map((d) => FriendUser.fromFirestore(d.id, d.data()))
          .toList();
    } catch (e) {
      debugPrint('Error in searchByName: $e');
      return [];
    }
  }

  /// البحث بالإيميل: تطابق تام — case-insensitive مع Fallback
  static Future<List<FriendUser>> searchByEmail(String email) async {
    if (email.trim().isEmpty) return [];
    final e = email.trim().toLowerCase();

    try {
      var snap = await _db
          .collection('users')
          .where('user_profile_v1.contact_lower', isEqualTo: e)
          .limit(5)
          .get();

      if (snap.docs.isEmpty) {
        snap = await _db
            .collection('users')
            .where('user_profile_v1.contact', isEqualTo: email.trim())
            .limit(5)
            .get();
      }

      return snap.docs
          .where((d) => d.id != _myUid)
          .map((d) => FriendUser.fromFirestore(d.id, d.data()))
          .toList();
    } catch (e) {
      debugPrint('Error in searchByEmail: $e');
      return [];
    }
  }

  // ─── الصداقة ────────────────────────────────────────────────────────────────

  /// جلب قائمة الأصدقاء المؤكدين للمستخدم الحالي
  static Future<List<FriendUser>> getFriends() async {
    try {
      final snap = await _db
          .collection('friendships')
          .where('users', arrayContains: _myUid)
          .get();

      final List<String> friendUids = [];
      for (final doc in snap.docs) {
        try {
          final data = doc.data();
          final usersList = data['users'] as List?;
          if (usersList == null) continue;
          final users = List<String>.from(usersList);
          final friendUid = users.firstWhere((u) => u != _myUid, orElse: () => '');
          if (friendUid.isNotEmpty) {
            friendUids.add(friendUid);
          }
        } catch (docErr) {
          debugPrint('Error parsing friendship doc ${doc.id}: $docErr');
        }
      }

      if (friendUids.isEmpty) return [];

      // جلب جميع وثائق الأصدقاء بالتوازي لضمان أقصى سرعة
      final List<Future<DocumentSnapshot<Map<String, dynamic>>>> futures =
          friendUids.map((uid) => _db.collection('users').doc(uid).get()).toList();

      final results = await Future.wait(futures);

      final List<FriendUser> friends = [];
      for (var i = 0; i < results.length; i++) {
        final docSnap = results[i];
        final uid = friendUids[i];
        if (docSnap.exists && docSnap.data() != null) {
          try {
            friends.add(FriendUser.fromFirestore(uid, docSnap.data()!));
          } catch (parseErr) {
            debugPrint('Error parsing user profile for $uid: $parseErr');
          }
        }
      }

      return friends;
    } catch (e) {
      debugPrint('Error in getFriends: $e');
      rethrow;
    }
  }

  /// جلب طلبات الصداقة الواردة مع بيانات المرسل
  static Future<List<Map<String, dynamic>>> getIncomingRequests() async {
    try {
      final snap = await _db
          .collection('friend_requests')
          .where('toUid', isEqualTo: _myUid)
          .where('status', isEqualTo: 'pending')
          .get();

      final List<Map<String, dynamic>> pendingRequests = [];
      for (final doc in snap.docs) {
        try {
          final data = doc.data();
          final fromUid = data['fromUid'];
          if (fromUid == null || fromUid is! String || fromUid.isEmpty) continue;
          pendingRequests.add({
            'requestId': doc.id,
            'createdAt': data['createdAt'],
            'fromUid': fromUid,
          });
        } catch (docErr) {
          debugPrint('Error parsing request doc ${doc.id}: $docErr');
        }
      }

      if (pendingRequests.isEmpty) return [];

      // جلب جميع وثائق مرسلي الطلبات بالتوازي لضمان أقصى سرعة
      final List<Future<DocumentSnapshot<Map<String, dynamic>>>> futures =
          pendingRequests.map((req) => _db.collection('users').doc(req['fromUid'] as String).get()).toList();

      final results = await Future.wait(futures);

      final List<Map<String, dynamic>> result = [];
      for (var i = 0; i < results.length; i++) {
        final docSnap = results[i];
        final req = pendingRequests[i];
        if (docSnap.exists && docSnap.data() != null) {
          try {
            result.add({
              'requestId': req['requestId'],
              'createdAt': req['createdAt'],
              'user': FriendUser.fromFirestore(req['fromUid'] as String, docSnap.data()!),
            });
          } catch (parseErr) {
            debugPrint('Error parsing user profile for incoming request: $parseErr');
          }
        }
      }

      // فرز محلي تنازلياً حسب تاريخ الإرسال
      result.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return result;
    } catch (e) {
      debugPrint('Error in getIncomingRequests: $e');
      rethrow;
    }
  }

  /// التحقق من حالة الصداقة مع مستخدم معين (server-side)
  static Future<FriendshipStatus> getFriendshipStatus(String otherUid) async {
    if (otherUid == _myUid) return FriendshipStatus.self;

    try {
      final fsSnap = await _db
          .collection('friendships')
          .where('users', arrayContains: _myUid)
          .get();

      final isFriend = fsSnap.docs.any((d) {
        try {
          final usersList = d.data()['users'] as List?;
          if (usersList == null) return false;
          return List<String>.from(usersList).contains(otherUid);
        } catch (_) {
          return false;
        }
      });
      if (isFriend) return FriendshipStatus.friends;

      final sentSnap = await _db
          .collection('friend_requests')
          .where('fromUid', isEqualTo: _myUid)
          .where('toUid', isEqualTo: otherUid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (sentSnap.docs.isNotEmpty) return FriendshipStatus.pending;

      final receivedSnap = await _db
          .collection('friend_requests')
          .where('fromUid', isEqualTo: otherUid)
          .where('toUid', isEqualTo: _myUid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (receivedSnap.docs.isNotEmpty) return FriendshipStatus.received;

      return FriendshipStatus.none;
    } catch (e) {
      debugPrint('Error in getFriendshipStatus: $e');
      return FriendshipStatus.none;
    }
  }

  /// إرسال طلب صداقة مع تسجيل اسم المرسل لأغراض الإشعار
  static Future<void> sendFriendRequest(String toUid, {String senderName = ''}) async {
    try {
      // لا نرسل مرتين إذا كان هناك طلب معلق نشط بالفعل
      final existing = await _db
          .collection('friend_requests')
          .where('fromUid', isEqualTo: _myUid)
          .where('toUid', isEqualTo: toUid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) return;

      // جلب اسم المرسل إذا لم يُمرَّر
      String name = senderName;
      if (name.isEmpty) {
        final myDoc = await _db.collection('users').doc(_myUid).get();
        if (myDoc.exists) {
          final profile = myDoc.data()?['user_profile_v1'] as Map<String, dynamic>? ?? {};
          name = profile['fullName'] as String? ?? 'مستخدم';
        }
      }

      // إنشاء طلب الصداقة + حقل notify للـ Cloud Function
      await _db.collection('friend_requests').add({
        'fromUid': _myUid,
        'toUid': toUid,
        'status': 'pending',
        'senderName': name,
        'createdAt': FieldValue.serverTimestamp(),
        'notify': true, // Cloud Function تراقب هذا الحقل لإرسال الإشعار
      });
    } catch (e) {
      debugPrint('Error in sendFriendRequest: $e');
      rethrow;
    }
  }

  /// قبول طلب صداقة واردة
  static Future<void> acceptFriendRequest(String requestId, String fromUid) async {
    try {
      final batch = _db.batch();

      batch.update(
        _db.collection('friend_requests').doc(requestId),
        {'status': 'accepted'},
      );

      final fsRef = _db.collection('friendships').doc();
      batch.set(fsRef, {
        'users': [_myUid, fromUid],
        'userA': _myUid,
        'userB': fromUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      debugPrint('Error in acceptFriendRequest: $e');
      rethrow;
    }
  }

  /// إلغاء طلب صداقة مرسل
  static Future<void> cancelFriendRequest(String toUid) async {
    try {
      final snap = await _db
          .collection('friend_requests')
          .where('fromUid', isEqualTo: _myUid)
          .where('toUid', isEqualTo: toUid)
          .where('status', isEqualTo: 'pending')
          .get();

      if (snap.docs.isEmpty) return;

      try {
        // نحاول أولاً حذف الطلب نهائياً للحفاظ على نظافة قاعدة البيانات
        final batch = _db.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        debugPrint('Successfully deleted friend request docs.');
      } catch (deleteError) {
        debugPrint('Failed to delete friend request docs due to permission limits: $deleteError. Falling back to status update.');
        // إذا فشل الحذف بسبب الصلاحيات، نقوم بتحديث الحالة إلى 'cancelled' كبديل أنيق
        final updateBatch = _db.batch();
        for (final doc in snap.docs) {
          updateBatch.update(doc.reference, {'status': 'cancelled'});
        }
        await updateBatch.commit();
        debugPrint('Successfully marked friend request docs as cancelled.');
      }
    } catch (e) {
      debugPrint('Error in cancelFriendRequest: $e');
      rethrow;
    }
  }

  /// رفض طلب صداقة وارد
  static Future<void> rejectFriendRequest(String requestId) async {
    try {
      await _db.collection('friend_requests').doc(requestId).update({'status': 'rejected'});
    } catch (e) {
      debugPrint('Error in rejectFriendRequest: $e');
      rethrow;
    }
  }

  /// إلغاء الصداقة (حذف الصداقة والطلبات المرتبطة بها)
  static Future<void> unfriend(String friendUid) async {
    try {
      final snap = await _db
          .collection('friendships')
          .where('users', arrayContains: _myUid)
          .get();

      final matches = snap.docs.where((d) {
        try {
          final List users = d.data()['users'] as List;
          return users.contains(friendUid);
        } catch (_) {
          return false;
        }
      }).toList();

      for (final doc in matches) {
        await doc.reference.delete();
      }

      // تنظيف الطلبات السابقة بين الطرفين
      final reqsSnapA = await _db
          .collection('friend_requests')
          .where('fromUid', isEqualTo: _myUid)
          .where('toUid', isEqualTo: friendUid)
          .get();
      
      final reqsSnapB = await _db
          .collection('friend_requests')
          .where('fromUid', isEqualTo: friendUid)
          .where('toUid', isEqualTo: _myUid)
          .get();

      final allReqDocs = [...reqsSnapA.docs, ...reqsSnapB.docs];
      if (allReqDocs.isNotEmpty) {
        try {
          final batch = _db.batch();
          for (final doc in allReqDocs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        } catch (deleteErr) {
          debugPrint('Could not delete friend requests, updating status to cancelled: $deleteErr');
          final batch = _db.batch();
          for (final doc in allReqDocs) {
            batch.update(doc.reference, {'status': 'cancelled'});
          }
          await batch.commit();
        }
      }
    } catch (e) {
      debugPrint('Error in unfriend: $e');
      rethrow;
    }
  }
}
