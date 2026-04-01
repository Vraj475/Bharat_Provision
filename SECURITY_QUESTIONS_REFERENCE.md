# Security Questions Reference - All Roles

## Default Security Questions (Automatically Set)

### 1. SUPERADMIN Role
**English**: What was the name of your first pet?
**Gujarati**: તમારા પહેલા પાલતુ પ્રાણીનું નામ શું હતું?
**Location**: Used during PIN recovery for superadmin users

### 2. ADMIN Role  
**English**: What city were you born in?
**Gujarati**: તમે કયા શહેરમાં જન્મ્યા હતા?
**Location**: Used during PIN recovery for admin users

### 3. EMPLOYEE Role
**English**: What is your mother's maiden name?
**Gujarati**: તમારી માતાનું પહેલાનું નામ શું છે?
**Location**: Used during PIN recovery for employee users

---

## Implementation Details

**Storage Location**: `flutter_secure_storage` (encrypted)
**Hashing**: SHA-256 (answers hashed before storage)
**Key Format**: `security_questions_{role}` (e.g., `security_questions_superadmin`)

**Configuration File**: 
- Main Service: `lib/features/settings/services/security_questions_service.dart`
- Method: `initializeDefaultQuestions()` (lines 95-175)
- Provider: `lib/features/settings/providers/security_questions_provider.dart`
- Initialization: `lib/features/settings/widgets/auth_gate.dart` (called during app startup)

---

## To Customize Security Questions

Edit the `initializeDefaultQuestions()` method in:
`lib/features/settings/services/security_questions_service.dart`

Example - Change superadmin question:
```dart
SecurityQuestion(
  id: '1',
  question: 'Your new question here?',
  answerHash: '',
  plainAnswer: '',
),
```

Then rebuild the app.

---

## PIN Recovery User Journey

```
User on Login Screen (Wrong PIN entered 3 times)
         ↓
"Locked for 30 seconds" message shows
         ↓
After 30 seconds, user clicks "Forgot PIN?" button
         ↓
System loads security question for user's role:
   - Superadmin → "What was the name of your first pet?"
   - Admin → "What city were you born in?"
   - Employee → "What is your mother's maiden name?"
         ↓
User enters answer (case-insensitive, trimmed)
         ↓
System verifies answer (compares hashes)
         ↓
If Correct:
   - PIN Reset Screen appears
   - User enters new PIN
   - Returns to Login Screen
   - Success! User logs in with new PIN
         ↓
If Incorrect:
   - "Wrong answer, try again" message
   - User can retry or go back
```

---

## Security Features

✅ **Answers are hashed**: Never stored as plain text
✅ **Case-insensitive**: "John", "JOHN", "john" all work
✅ **Trim whitespace**: "  John  " loads as "john"
✅ **Role-based**: Different question per role
✅ **Secure storage**: flutter_secure_storage (OS-level encryption)
✅ **Automatic init**: Set up automatically on first app launch
✅ **Safe reuse**: Only initializes if questions don't already exist

---

**Date**: April 1, 2026
**Status**: ✅ Complete and Verified
