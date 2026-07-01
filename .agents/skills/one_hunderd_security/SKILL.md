---
name: one-hunderd-security
description: >
  قواعد أمان مخصصة لمشروع One Hundred. تُفعَّل تلقائياً عند العمل على هذا المشروع.
  تشمل حماية اقتصاد التطبيق (Wooden Coins / Lifebuoys)، قواعد Firestore،
  دوال Debug، ومنطق التحقق من بيانات المستخدم.
---

# One Hundred — Security Rules & Skills

أنت تعمل على مشروع Flutter اسمه **One Hundred**. هذا التطبيق يحتوي على اقتصاد رقمي حساس:
- **Wooden Coins** (عملات خشبية): تُكسب من الإيداع اليومي والمكافآت، وتُصرف على شراء Lifebuoys.
- **Lifebuoys** (أطواق نجاة): تحمي الـ Streak من الانقطاع عند نسيان الإيداع.
- **Streak**: عداد الأيام المتتالية، أهم مؤشر تحفيزي في التطبيق.

---

## 🔴 SKILL 1 — Economy_Integrity: حماية الاقتصاد الرقمي

### القاعدة:
**كل تعديل على `woodenCoins` أو `lifebuoys` يجب أن يمر فقط عبر الدوال الرسمية التالية في `SavingsProvider`:**

| الدالة | الغرض | القيمة |
|--------|--------|---------|
| `claimDailyReward()` | المكافأة اليومية | +10 عملة، مرة واحدة يومياً |
| `watchAdReward()` | مشاهدة إعلان | +25 عملة، حد أقصى 4 مرات يومياً |
| `registerShareReward()` | مشاركة التطبيق | +20 عملة، حد أقصى 5 مرات يومياً |
| `addCoins(int amount)` | إضافة عملات (للنظام فقط) | أي مبلغ |
| `deductCoins(int amount)` | خصم عملات | مع التحقق من الرصيد |
| `buyLifebuoy()` | شراء طوق نجاة | -1000 عملة، +1 طوق |

### ⛔ محظور تماماً:
- لا تكتب `_woodenCoins +=` أو `_lifebuoys +=` أو `_lifebuoys--` في أي ملف خارج `SavingsProvider`.
- لا تُنشئ دالة جديدة تعدّل الرصيد دون المرور بالدوال الرسمية أعلاه.
- لا تتجاوز الحدود اليومية للمكافآت بحجة أن الواجهة ستُخفيها — الفحص يجب أن يكون في الكود.

### ✅ النمط الصحيح:
```dart
// ✅ صح: استخدام الدالة الرسمية
await context.read<SavingsProvider>().claimDailyReward();

// ❌ خطأ: تعديل مباشر خارج SavingsProvider
_woodenCoins += 10; // FORBIDDEN
```

---

## 🔴 SKILL 2 — Debug_Code_Safety: تأمين كود التطوير

### المشكلة:
في ملف `savings_provider.dart` توجد دوال Debug **يجب ألا تصل إليها النسخة الإنتاجية**:
- `debugSetDays(int days)` — يضبط الأيام يدوياً
- `debugResetData()` — يمسح كل البيانات
- `debugAddLifebuoy()` — يضيف طوق نجاة مجاناً
- `debugAdd500Coins()` — يضيف 500 عملة مجاناً
- `debugResetDailyLimits()` — يتجاوز الحدود اليومية

### القاعدة الصارمة:
**عند بناء أي واجهة مستخدم (Screen أو Widget) أو عند استدعاء أي دالة، تحقق أن:**

1. **دوال Debug لا تُستدعى من خارج بيئة التطوير.** يجب دائماً تغليفها بـ:
```dart
// ✅ النمط الصحيح لاستدعاء دوال Debug
if (kDebugMode) {
  await provider.debugAdd500Coins();
}
```

2. **لا تُضيف أزرار Debug في الواجهة الإنتاجية** (أي شاشة يراها المستخدم الفعلي).

3. **عند إضافة دالة Debug جديدة** في المستقبل، ضعها دائماً تحت قسم `// ── Debug Helpers ──` في آخر `SavingsProvider` مع تسميتها بـ `debug` بشكل صريح.

---

## 🔴 SKILL 3 — Firestore_Auth_Validation: التحقق من الهوية قبل كل عملية

### القاعدة:
**في كل دالة `static` داخل `ChallengeService` أو `FriendsService` تتعامل مع Firestore:**

1. تحقق دائماً أن `_myUid` لا يتطابق مع المستخدم المستهدف (لمنع التلاعب بالنفس):
```dart
// ✅ مثال: التحقق في ChallengeService
if (toUid == _myUid) throw Exception('لا يمكنك إرسال دعوة لنفسك!');
```

2. تحقق من أن `_auth.currentUser` ليس `null` قبل أي عملية كتابة في Firestore:
```dart
// ✅ النمط الصحيح
final user = _auth.currentUser;
if (user == null) throw Exception('المستخدم غير مسجل الدخول');
```

3. **لا تعتمد على الـ UID الممرر من الـ UI.** استخدم دائماً `_myUid` الذي يُجلب من `FirebaseAuth.instance.currentUser!.uid`:
```dart
// ❌ خطأ: UID من الـ UI غير موثوق
Future<void> updateData(String userId, ...) // خطر: يمكن تمرير uid آخر

// ✅ صح: UID من Firebase Auth مباشرة
static String get _myUid => _auth.currentUser!.uid;
```

---

## 🔴 SKILL 4 — Data_Type_Safety: الحماية من بيانات Firestore المشوهة

### المشكلة:
عند قراءة البيانات من Firestore، قد يكون الحقل غير موجود، أو من نوع خاطئ (مثلاً: `String` بدل `int`)، مما يؤدي إلى crash للتطبيق عند مستخدمين بعينهم.

### القاعدة الصارمة:
**عند قراءة أي حقل رقمي من Firestore، استخدم دائماً `as num?` ثم `.toInt()` أو `.toDouble()` وليس `as int?` مباشرة:**

```dart
// ❌ خطأ: سيُسبب Crash إذا كانت القيمة double في Firestore
_woodenCoins = data['wooden_coins_v1'] as int? ?? 0;

// ✅ صح: آمن مع كل أنواع الأرقام
_woodenCoins = (data['wooden_coins_v1'] as num?)?.toInt() ?? 0;
_lifebuoys = (data['lifebuoys_v1'] as num?)?.toInt() ?? 0;
_currentStreak = (data['current_streak_v1'] as num?)?.toInt() ?? 0;
```

**هذا القانون يُطبق على جميع الحقول الرقمية في:**
- `savings_provider.dart`
- `challenge_service.dart`
- أي ملف يقرأ بيانات من Firestore مستقبلاً.

---

## 🔴 SKILL 5 — Firestore_Rules_Consistency: تطابق قواعد Security مع الكود

### القاعدة:
**عند إضافة أي كولكشن (Collection) جديد في Firestore، يجب إضافة قواعد حمايتها في ملف `firestore.rules` في جذر المشروع قبل رفع التغييرات.**

الكولكشنز الحالية المحمية:
- `users` ✅
- `friendships` ✅
- `friend_requests` ✅
- `challenge_invitations` ✅
- `cooperative_sessions` ✅
- `competitive_sessions` ✅

**القاعدة الافتراضية لأي كولكشن جديد:**
```javascript
match /new_collection/{docId} {
  allow read, write: if false; // مغلق حتى تُضاف القواعد الصحيحة
}
```

**لا تترك أي كولكشن بدون قواعد — الوصول الافتراضي في Firebase هو الحظر الكامل، ولكن يجب توثيق الاستثناءات في الملف.**

---

## ملخص الأولويات الأمنية

| # | المخاطرة | الحماية |
|---|----------|---------|
| 1 | التلاعب بالعملات/الأطواق | SKILL 1: Economy_Integrity |
| 2 | دوال Debug في الإنتاج | SKILL 2: Debug_Code_Safety |
| 3 | انتحال هوية مستخدم آخر | SKILL 3: Firestore_Auth_Validation |
| 5 | كولكشنز غير محمية | SKILL 5: Firestore_Rules_Consistency |
| 6 | تضارب البيانات (Race Conditions) | SKILL 6: Race_Condition_Prevention |
| 7 | تلف البيانات الحساسة | SKILL 7: Firestore_Transaction_Integrity |

---

## 🔴 SKILL 6 — Race_Condition_Prevention: منع تضارب البيانات

### المشكلة:
في الاقتصاد الرقمي (مثل Wooden Coins)، إذا حاول المستخدم الضغط على زر "شراء طوق نجاة" بسرعة مرتين متتاليتين، قد يتم تنفيذ العمليتين قبل أن يتحدث الرصيد، مما يؤدي إلى رصيد بالسالب أو شراء طوق إضافي مجاني.

### القاعدة:
**استخدم دائماً متغيرات الحالة (State flags) لمنع الاستدعاءات المتعددة المتزامنة:**
```dart
// ✅ صح: استخدام قفل (Lock) لمنع التنفيذ المتكرر
bool _isBuying = false;

Future<void> buyLifebuoy() async {
  if (_isBuying) return; // منع التكرار
  _isBuying = true;
  notifyListeners();
  
  try {
    // منطق الشراء هنا
  } finally {
    _isBuying = false;
    notifyListeners();
  }
}
```

---

## 🔴 SKILL 7 — Firestore_Transaction_Integrity: استخدام الـ Transactions للبيانات الحساسة

### القاعدة الصارمة:
**أي عملية تتطلب خصم أو إضافة تعتمد على القيمة القديمة في Firestore من أكثر من عميل، يجب أن تستخدم `FirebaseFirestore.instance.runTransaction` وليس التحديث المباشر:**

```dart
// ✅ صح: استخدام Transaction للعملات
await FirebaseFirestore.instance.runTransaction((transaction) async {
  final snapshot = await transaction.get(userDocRef);
  final currentCoins = (snapshot.data()?['wooden_coins_v1'] as num?)?.toInt() ?? 0;
  
  if (currentCoins < price) throw Exception("رصيد غير كافٍ");
  
  transaction.update(userDocRef, {
    'wooden_coins_v1': currentCoins - price,
    'lifebuoys_v1': FieldValue.increment(1),
  });
});
```
