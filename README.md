# Almamoura Film Festival

Flutter application for the Almamoura Film Festival. Paid vote bundles use
Ziina's hosted checkout through Supabase Edge Functions; the Ziina access token
and webhook secret must never be added to the Flutter app.

## Supabase app configuration

The app is configured for the current Supabase project in
`lib/services/supabase_service.dart`. The URL and publishable key are
client-safe; never put a service-role/secret key in the Flutter app. To
override the project for a run or release build, pass:

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

Use `--dart-define` with the same two names when building a release.

## Web release

The private repository includes a `Dockerfile` and `nginx.conf` for deploying
the Flutter web app with Coolify. In Coolify, create an application from this
GitHub repository, select Dockerfile deployment, and use `/` as the health
check path. Coolify should provide HTTPS and route traffic to the container's
port 80. The container builds the Flutter web release and serves it with
single-page-app route fallback.

For sign-in, password resets, and OAuth on the deployed web app, add the
Coolify app URL to Supabase Authentication's allowed redirect URLs. The app
automatically returns web authentication flows to the current web URL while
retaining the native callback on iOS and Android.

## Festival submissions

The FilmFreeway export is stored in `public.festival_submissions`. The import
contains film/project metadata and submission status, date, deadline, and
category fields. Submitter contact details, personal information, submission
passwords/links, letters, bios, judging notes, and ratings were excluded.

Row-level security is enabled. Only authenticated users with the trusted
`app_metadata.role` claim set to `festival_admin` can read these records; do not
set this claim from client-side code. The submission content may be confidential
even after personal contact fields are removed.

## Paid film voting

The app reads its film catalogue from the safe
`public.public_voting_films` table; no film CSV is bundled in the Flutter app.
The catalogue currently contains all 2,634 FilmFreeway submissions, including
Incomplete and Withdrawn records, as requested. The public table exposes
selected film metadata and vote totals, not submitter contact data. Library and
voting screens fetch 30 films per request, with filtering and ordering handled
by Supabase. Each purchase is for one film and one of the fixed AED 5, AED 25,
or AED 50 vote bundles. Only a Ziina-confirmed completed payment contributes
votes.

The project migrations for `festival_submissions`, `vote_bundles`,
`film_vote_payments`, and `public_voting_films` are in
`supabase/migrations/`. They have already been applied to the configured
Supabase project.

The app invokes `ziina-create-film-vote-payment` (JWT required) to create the
server-priced Ziina intent. `ziina-film-vote-webhook` (JWT disabled) verifies
Ziina's HMAC signature and updates a payment; the public totals view counts
only completed payments.

## Backend scale notes

The public catalogue is separated from private submissions, uses paginated
queries in library and voting screens, and keeps paid vote totals denormalized
on each catalogue row. Keep mobile queries restricted to the public catalogue
and never read the private poster mapping table from the client.

## Film posters

Film poster images are stored in the public-read Supabase Storage bucket
`posters`. Uploads remain restricted; do not add a public upload policy or put
service-role keys in the app. The bucket objects should be named under
`almamoura posters/` using the FilmFreeway tracking number and original file
extension, for example `almamoura posters/1001.jpg`.

The migrations `20261009140000_sync_film_posters.sql` and
`20261011120000_sync_uploaded_posters.sql` create a private mapping from every
film's FilmFreeway tracking number to its poster path. Matching posters already
in Storage are linked immediately; future uploads or renames under
`almamoura posters/` are linked automatically when their numeric filename
matches a film's tracking number. Keep filenames as
`almamoura posters/<tracking-number>.<jpg|jpeg|png|webp>`. The mapping remains
private; never import submitter contact or other personal columns. The app
renders public poster URLs across film cards, voting, and detail screens, with
the existing gradient retained as a loading/error fallback.

The payment function requires `ZIINA_TEST_MODE` to be explicitly set to the
exact string `true` or `false`; each Ziina request sends that boolean as its
`test` field. There is no implicit mode default. Test mode uses
`ZIINA_TEST_ACCESS_TOKEN` (or the legacy `ZIINA_ACCESS_TOKEN`); live mode
requires `ZIINA_LIVE_ACCESS_TOKEN`, so a test credential cannot be used
accidentally for production payments.

To enable live payments:

1. Complete Ziina merchant onboarding and confirm live payments are enabled.
   In Supabase **Edge Functions → Secrets**, add a fresh production API token
   as `ZIINA_LIVE_ACCESS_TOKEN`. It needs `write_payment_intents` permission.
2. Generate a long random webhook secret and store it as
   `ZIINA_WEBHOOK_SECRET` in Supabase Edge Function secrets. Never include
   either secret in Flutter or commit them to source control.
3. Register the webhook URL in Ziina using the production API token and the
   same webhook secret. The production token must also have `write_webhooks`
   permission:

   ```sh
   curl -X POST https://api-v2.ziina.com/api/webhook \
     -H "Authorization: Bearer <ziina-access-token>" \
     -H "Content-Type: application/json" \
     -d '{"url":"https://cbksbxmzeqefbdqzbprn.supabase.co/functions/v1/ziina-film-vote-webhook","secret":"<same-webhook-secret>"}'
   ```

4. For web checkout, set `ZIINA_WEB_CALLBACK_ORIGINS` in Supabase Edge
   Function secrets to a comma-separated list of approved HTTPS origins. For
   the current Almamoura web apps, use:

   ```text
   https://voting.almamourafestival.com,https://vote.almamourafestival.com,https://web.almamourafestival.com,https://app.almamourafestival.com
   ```

   The payment function rejects browser requests from origins outside this
   list and returns each web checkout to the same app origin. Add a new origin
   here before using it for live checkout. Native apps use the registered
   `io.supabase.almamoura://payment-callback/` callback instead.

5. Once the production token, live webhook, and web callback origins are
   configured, set `ZIINA_TEST_MODE` to the exact value `false`. Every payment
   request contains the server-calculated amount in fils,
   `currency_code: "AED"`, platform-appropriate callbacks, and `test: false`.
   The Flutter web app returns to a payment-status screen; this screen checks
   Supabase for the signed webhook result rather than trusting the redirect.
   Other clients can share the payment function by using the same allowlisted
   origin and checking the payment status in Supabase after redirect.
   Only a signed, amount-matched Ziina webhook marks a payment completed and
   adds votes. Do not test with a real card unless you intend to charge it.
