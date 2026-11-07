# NOVA IPTV Licensing Architecture

## Product rules

- The free trial lasts 7 days and starts on the first successful server-side trial activation.
- A lifetime license is a one-time purchase and does not automatically promise lifetime support or updates.
- A license is bound to one device by default. Device transfer/deactivation is an administrative policy, not a client-side decision.
- The customer supplies their own IPTV subscription. NOVA licensing must never collect or transmit Xtream/M3U credentials to the licensing backend.
- New activations fail closed when the licensing service is unavailable. Existing activations may use a short, server-issued offline lease (target: 48 hours) once signed leases are implemented.
- Never put service-role keys, signing private keys, payment secrets, or admin credentials in the Flutter application.

## Selected backend

Use Supabase (Postgres + Edge Functions) for the first release. It provides a managed database and server-side functions without requiring a custom server to be maintained.

The Flutter app may contain only the Supabase project URL and public/anonymous key. These are public client configuration values, not secrets. All privileged database access and signing happen inside Edge Functions using server-side environment secrets.

## Client integration point

The app currently starts directly in `NovaApp` with `HomeScreen` as its home widget. Add a startup licensing gate before exposing `HomeScreen`:

1. Read or create a random installation ID and store it in Windows secure storage.
2. Ask the licensing Edge Function to validate the current installation.
3. Show a first-run screen offering **Start 7-day trial** or **Enter lifetime license key** when no entitlement exists.
4. Show the main player only after a valid entitlement is confirmed.
5. Keep IPTV account credentials separate from licensing data. Never send IPTV server, username, or password to Supabase.

## Server-side data model

### licenses

- `id`: UUID primary key
- `key_hash`: unique hash of the human-readable license key; never store the raw key
- `status`: active, revoked, expired
- `license_type`: lifetime
- `max_devices`: integer, default 1
- `created_at`, `activated_at`
- `customer_reference`: optional internal order/customer reference

### license_devices

- `id`: UUID primary key
- `license_id`: foreign key to licenses
- `device_hash`: hash of the installation ID
- `activated_at`, `last_seen_at`, `deactivated_at`
- Unique active binding for a license/device pair

### trial_devices

- `id`: UUID primary key
- `device_hash`: unique hash of the installation ID
- `started_at`: server timestamp
- `expires_at`: server timestamp (started_at + 7 days)
- `last_seen_at`
- `status`: active, expired, blocked

Apply Row Level Security to all tables. The Flutter client must not have direct table permissions. Only Edge Functions using server-side credentials may read or write licensing records.

## Edge Function contract

All functions validate input, rate-limit activation attempts, and use server time.

- `start-trial`: accepts installation ID; creates one trial record if none exists; repeated calls return the original expiry, never restart the trial.
- `activate-license`: accepts license key and installation ID; hashes the key server-side, checks status/device limit, binds the device, and returns entitlement.
- `validate-entitlement`: accepts installation ID and current activation reference; checks trial/license status, revocation and device binding; returns server time and entitlement status.
- `deactivate-device`: authorized device deactivation flow; administrative device transfers must also be possible from the future admin dashboard.

Do not trust a client-supplied trial start date, expiry date, license status, device count, or local clock.

## Signed offline lease

After online validation, the server should issue a short-lived signed lease containing at minimum:

- product identifier
- installation/device hash
- entitlement type (trial or lifetime)
- issued-at and not-after timestamps
- unique lease identifier

Sign leases on the server with an asymmetric private key held only in Supabase secrets. Embed only the matching public verification key in the Flutter app. Never use a shared HMAC secret embedded in the app.

## Release sequence

1. Create Supabase project and configure server-side secrets.
2. Add SQL migration and Edge Functions.
3. Add Flutter licensing service, secure installation ID storage, and startup gate.
4. Test trial start, repeated start, expiry, key activation, duplicate-device rejection, revocation, clock changes, and temporary network loss.
5. Add a protected admin workflow for issuing/revoking keys and transferring devices.
6. Only then enable licensing enforcement in the production release.

## Current status

This document records the architecture only. Licensing enforcement is not enabled yet. The app remains unchanged until the backend is provisioned and its public project configuration is available.
