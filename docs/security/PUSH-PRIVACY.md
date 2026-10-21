# Push privacy — Signal/WhatsApp model (option C)

**Status:** implemented 2026-10-20 (audit SEC-031 / SEC-033 / SEC-035a / SEC-054).

## Contract

Push is a wake-up signal, never a content channel:

- The server sends a data-only FCM message (opaque `notification_id`, `type`
  and generic copy keys). APNs carries `content-available` / `mutable-content`
  and no alert body. No message text, sender name, location, wager amount or
  answer is sent to FCM/APNs.
- The in-app `notifications` row keeps the real title/body; the notification
  center loads it after auth.
- There are **no per-user preview preferences** at launch (Q4): the generic
  redaction is the only mode (SEC-035a).

## Client rendering

`firebaseMessagingBackgroundHandler` (`lib/core/services/push_service.dart`):

1. Reads the persisted Supabase session through the SEC-033 secure-storage
   options (`first_unlock_this_device` on iOS, `EncryptedSharedPreferences` on
   Android). Missing/corrupt session ⇒ **no notification** (fail closed).
2. Renders the generic local notification (`pushGenericTitle` /
   `pushGenericBody`) through `flutter_local_notifications`.
3. The tap payload is the fixed route `/main/notifications`; the authenticated
   notification center fetches the content.

Full content is deliberately not fetched in the background isolate: it has no
router or decrypted store, and fetching it would re-open a content path to the
lock screen.

## Token lifecycle (SEC-031)

- `unregister()` never throws, always clears local token state and always calls
  `deleteToken()`.
- A failed unregister RPC is queued in secure storage and retried on the next
  authenticated sync (same uid only).
- On an account switch the FCM token is rotated (`deleteToken` → `getToken`)
  before registering for the new uid, so the previous account's server row can
  no longer deliver to this install.
- Logout also purges every local cache (SEC-033).

## iOS Notification Service Extension — NOT shipped (test-only limitation)

The Signal-style NSE (fetch after decrypt, then mutate the notification) is
not in this build. An NSE is a separate bundle (`…SamayNotificationService`)
with its own App ID, provisioning profile and App Group/keychain-sharing
entitlement. The ad-hoc lane signs only `com.qallariy.samay` with the installed
Ad Hoc profile; adding an unsigned/unprovisioned embedded extension makes the
archive fail to export and would break the local ad-hoc IPA.

Shipped fallback: the generic local notification above. It is fully functional
on iOS when the app process is awakened by a data-only `content-available`
push (the FCM background handler runs on the main isolate on iOS). When content
decryption requires an extension in the future, add the target together with a
portal profile that includes both bundle ids and the App Group
`group.com.qallariy.samay`. No server content is ever sent to APNs, so the
deferred NSE is an optional enrichment, not a privacy gap.
