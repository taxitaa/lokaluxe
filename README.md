# LokaLuxe

Flutter application for travel planning.

## Supabase authentication

The app supports Supabase Auth for account login across devices. The Supabase
project URL and publishable key are provided at build/run time; never use a
`service_role` key in the client app.

1. In the Supabase SQL Editor, run [`supabase/schema.sql`](supabase/schema.sql).
2. In Supabase Authentication settings, choose the email confirmation policy
   appropriate for the app. If confirmation is enabled, users must confirm the
   message before they can sign in on another device.
3. Run the app with these Dart defines, replacing the values with the project's
   URL and publishable key:

   ```powershell
   flutter run `
     --dart-define=SUPABASE_URL=https://your-project.supabase.co `
     --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key
   ```

   Add the same defines to the build command used to distribute the app.
4. To migrate an account that exists only in the old local database, sign in on
   the original device once with its existing email and password while the app
   is configured for Supabase. If email confirmation is required, confirm it
   before signing in on another device.

Without both defines, authentication retains the existing local-only behavior.
Only authentication and basic profile information are stored in Supabase;
trips, expenses, and other app data remain local to each device.
