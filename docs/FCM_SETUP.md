# Push notifications (FCM)

LiveTix stores notifications for signed-in accounts in Supabase. Guest mode
does not show the notification feed or register an FCM token.

## 1. Configure Firebase apps

1. Create a Firebase project and enable the Firebase Cloud Messaging API.
2. Register the Android app using the same application ID as
   `android/app/build.gradle.kts` (`com.example.livetix` in this checkout).
3. Use `android/app/google-services.json.example` as a reference, fill it with
   the values from Firebase Console, and save the completed file as
   `android/app/google-services.json`. The Google Services Gradle plugin is
   applied only when the completed file exists. The real file is ignored by Git.
4. Rebuild the Android app. At sign-in, the app requests notification permission and
   stores the Firebase messaging registration ID in `public.user_fcm_tokens`.

Do not commit Firebase service-account JSON/private keys. The Android client
config contains app/project identifiers and an API key; it is not a substitute
for the service-account key, which must remain a server secret.

## 2. Apply the Supabase migration

Apply `supabase/migrations/20261119_notifications_and_fcm.sql` to the Supabase
project. It creates the notification feed and token tables, restricts feed
access to the signed-in user, and inserts notifications for account status,
concert approval/cancellation, paid or failed orders, and Gate Crew assignments.
Customer Service messages, concert reminders, and unscanned ticket expiry are
also recorded there. The notification rows are the source for the in-app feed.

## 3. Configure the FCM sender

Create a Firebase service account with permission to send FCM messages. Set
these secrets in the Supabase project (never in Flutter or a committed file):

- `FIREBASE_SERVICE_ACCOUNT`: the full service-account JSON.
- `NOTIFICATION_WEBHOOK_SECRET`: a long random value used by the database webhook.

Deploy the Edge Function:

```powershell
supabase functions deploy send-notification-fcm --no-verify-jwt
supabase secrets set FIREBASE_SERVICE_ACCOUNT='<service-account-json>'
supabase secrets set NOTIFICATION_WEBHOOK_SECRET='<long-random-value>'
```

In Supabase Dashboard, create a Database Webhook for `public.notifications`,
event **INSERT**, method **POST**, with URL:

```text
https://<project-ref>.supabase.co/functions/v1/send-notification-fcm
```

Add this request header, using the exact same secret as above:

```text
x-notification-webhook-secret: <long-random-value>
```

The function reads the notification recipient's tokens using the Supabase
service role and sends FCM HTTP v1 messages. The service-account key and
service-role key remain server-side.

## 4. Test

1. Install a development build on a physical Android device and sign in.
2. Allow notifications and confirm a row appears in `user_fcm_tokens`.
3. Trigger a database event, for example mark an order paid through the normal
   payment webhook, and confirm a row appears in `notifications`.
4. Verify the Database Webhook and Edge Function logs, then test with the app
   foregrounded and backgrounded. Foreground pushes are shown as local
   notifications; background notification payloads are displayed by the OS.

An FCM push is sent only after Firebase platform files, the Edge Function
secrets, and the Supabase Database Webhook are configured.

The migration schedules reminders every five minutes with `pg_cron`. If the
project cannot enable `pg_cron`, enable it from Supabase Dashboard and schedule
`SELECT public.process_scheduled_notifications()` to run every five minutes.
