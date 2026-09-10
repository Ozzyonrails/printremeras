# Decisions, gaps found in the spec, and what was done about them

## Open questions (§21) — defaults implemented
1. **Cancellation rule** — implemented as written in §13: customer can cancel through `in_production`
   (`Order::CUSTOMER_CANCELLABLE`); later only staff. The "more than 2 shirts" note is ignored. Change the constant if the rule changes.
2. **Review reward** — 25 % flat (`Setting.review_reward_percent`), one coupon per approved review, 90-day validity. No variation by order value.
3. **Coupon on catalog items** — allowed. Discount applies to the item subtotal (catalog or custom), never to shipping/rush.
4. **Campaign codes** — model + admin UI exist (Admin → Cupones → Nuevo, source `campaign`, public or personal, max uses, min order). No separate campaign dashboard.
5. **Pickup locations** — one, from settings (`pickup_address`, `pickup_hours`). A second location = a new `Shipping::Provider` adapter.
6. **Guest data retention** — 90 days (`Setting.guest_retention_days`); `Identity::PurgeExpiredGuestSessionsJob` runs daily and removes unused designs of expired guests.
7. **Legal pages** — not written; the SPA has room for static pages but copy must come from the business.

## Gaps in the spec that needed a decision
- **Placement `scale` semantics** were undefined. Defined as artwork width ÷ print-area width (0.05–1.0), with the rotated bounding box checked in millimetres. If the admin's rectangle aspect ratio differs from the physical mm aspect ratio by >5 % the admin sees a warning (the design would look different on screen vs print).
- **QR flow**: MercadoPago's in-store QR API needs a registered POS/store. Implemented QR as the Checkout Pro `init_point` rendered as a QR (scan with the phone camera or the MP app), which needs no extra setup; a true in-store QR can be added inside `MercadoPagoGateway` later.
- **Rendering happens after payment** (as specified), so the moderation queue shows a CSS composite (mockup + artwork with the same percentages) instead of a rendered file.
- **Photos "moved" between buckets**: ActiveStorage cannot move blobs; approved photos are copied to the public bucket (`Review#published_photos`) and served from there. Originals stay private.
- **Direct upload service**: uploads always go to the private bucket via `POST /api/v1/uploads` (type/size checked before the signed URL is issued; real MIME sniffed after upload).
- **Notifications matrix**: the spec lists recipients per event; channels per event are a JSON setting (`notification_channels`), default `{"default": ["email"]}`. Adding WhatsApp = one class + one registry line.
- **Admin roles**: `operator` (orders, moderation, reviews, chat, customers) vs `admin` (plus templates, catalog, coupons, settings, audit, admin users, jobs).
- **Order numbers**: `PR-YYMMDD-XXXX`, exposed instead of ids in URLs.
- **Rate limits** via rack-attack (logins, registrations, resets, review submission, uploads).
- **Rush production**: fully priced and stored but hidden unless `rush_enabled`.
- **Review invitations** are sent N days after delivery (`review_invitation_delay_days`) by a daily job.
- **Refund**: operator action on the order page (`Payments::Refund` → gateway refund → `refunded`).
- **Locale of emails**: `user.locale` (set at registration from the UI language, editable in the account page).

## Artwork quality policy (changed after the first build)

The spec (§7) said enlargement below `min_dpi` should be blocked and uploads under 800 px
refused. That was reversed on request: **a poor image must never stop a sale.**

- `min_dpi` and `min_upload_px` are now *warning thresholds*, not limits. The editor keeps
  showing the effective DPI and warns, but nothing is capped and nothing is refused.
- Low-resolution artwork is marked instead: `Design#enhancement_status`
  (`none|needed|requested|processing|done|failed`) plus a human-readable
  `enhancement_note`, and `Order#low_quality_artwork` so the moderation queue can filter.
- The flag is decided per *placement*, not per file: a 900 px image is fine on a small
  chest print and poor across a full front, so the verdict depends on the printed size.
- Upscaling sits behind `ImageEnhancement::Provider`. `NullProvider` (default) only marks
  the artwork; `LocalUpscaleProvider` is a libvips resize for testing; a paid AI service
  becomes a third adapter with no call-site changes. `Designs::Enhance` stores the result
  in `Design#enhanced_file` and never overwrites the customer's original.
- Once enhanced, `Design#effective_width_px` and `print_ready_file` switch to the improved
  file, so DPI recovers and print files render from it automatically.
- Both limits can be switched back on per shop: `Setting.enforce_min_dpi` and
  `Setting.enforce_min_upload_px`, both false by default. `Setting.auto_request_enhancement`
  asks the provider automatically at order creation.
- Still hard limits, because they are technical rather than aesthetic: 20 MB file size,
  PNG/JPEG/WEBP only, and the artwork bounding box must stay inside the print area.

## Development sign-in shortcuts

Both login screens list the seeded demo accounts and fill the form on tap. The storefront
offers only customers and the admin page only staff, because `AdminUser` and `User` are
separate tables: an admin shortcut on the customer form would always fail to sign in. The passwords
live in one file (`lib/dev_credentials.rb`), which the seeds, the admin view and the
storefront settings payload all read, so the list can never drift from the accounts that
actually exist. `DevCredentials.enabled?` is true in development, and elsewhere only when
`SHOW_DEV_CREDENTIALS=true` is set deliberately — needed because the compose stack runs in
production mode, so without an opt-in the feature would be invisible to anyone who only
runs Docker. When forced that way the panels show a warning, the boot log carries one, and
the API marks the payload `forced: true`. `HIDE_DEV_CREDENTIALS=true` always wins.
Integration tests assert every direction.

## Not included (deliberately)
- WhatsApp/SMS/Telegram channels, additional shipping zones, PDF/TIFF renderers — the adapter seams are in place.
- Kamal config (deployment is docker compose, see README). Add Kamal later if you prefer.
- System (browser) tests; the backend flow is covered by integration tests, the editor by TypeScript types + manual checks.
