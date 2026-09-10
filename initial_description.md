# Custom Apparel Printing Platform — Development Specification

Version 2.0 · Handoff document for implementation

---

## 1. Overview

A web platform where customers upload their own artwork, position it on a garment mockup within an allowed print area, and place an order. In parallel, a shop section sells ready-made designs assembled by staff using the same editor.

After receiving an order, customers can submit a photo review wearing the garment. Once approved by an admin, they receive a discount coupon for their next purchase.

### Stack

| Layer | Choice |
|---|---|
| Backend | Ruby on Rails 8 (API mode + server-rendered admin) |
| Database | PostgreSQL |
| Background jobs / cache / websockets | Solid Queue, Solid Cache, Solid Cable |
| File storage | ActiveStorage → S3-compatible object storage |
| Image processing | libvips via `image_processing` |
| Frontend | React + Vite + TypeScript |
| Payments | MercadoPago |
| Locales | Spanish (default), Russian |
| Currency | ARS, stored as integer cents |

### Roles

- **Guest** — unauthenticated, state persisted via session token
- **Customer** — registered buyer
- **Operator** — orders, chat, status transitions, review moderation
- **Admin** — everything above plus templates, pricing, inventory, catalog, settings

---

## 2. Architecture Principles

> **This section is a hard requirement, not a suggestion.** The system must accept new payment providers, notification channels, shipping carriers and storage backends without rewriting call sites.

### 2.1 Ports and adapters

Every external dependency sits behind an explicit interface. Business logic depends on the interface, never on a vendor SDK.

```
app/services/
  payments/
    gateway.rb              # abstract interface
    mercado_pago_gateway.rb
    fake_gateway.rb         # dev + test
  notifications/
    channel.rb              # abstract interface
    email_channel.rb
    whatsapp_channel.rb     # future
    sms_channel.rb          # future
  shipping/
    provider.rb
    caba_courier_provider.rb
    pickup_provider.rb
  rendering/
    print_file_renderer.rb
    preview_renderer.rb
```

Adapters are resolved through a registry configured in an initializer, so swapping an implementation is a one-line config change:

```ruby
Rails.application.config.x.payments.gateway = "Payments::MercadoPagoGateway"
```

**Rule:** no vendor SDK may be referenced outside its own adapter file. A grep for `MercadoPago` outside `app/services/payments/` should return zero results.

### 2.2 Domain events

State changes publish events to an internal bus. New behaviour is added by subscribing, not by editing existing code.

```ruby
DomainEvents.publish(:order_paid, order_id: order.id)
```

Subscribers are registered declaratively and each runs in its own background job, so a failing subscriber cannot break the transaction or block the others.

```ruby
# config/initializers/domain_events.rb
DomainEvents.subscribe :order_paid, to: Orders::DecrementInventory
DomainEvents.subscribe :order_paid, to: Rendering::GeneratePrintFiles
DomainEvents.subscribe :order_paid, to: Notifications::OrderPaidNotice
```

Core event catalogue: `order_created`, `order_approved`, `order_rejected`, `order_paid`, `order_status_changed`, `order_cancelled`, `review_submitted`, `review_approved`, `coupon_issued`, `message_created`, `design_uploaded`.

### 2.3 Business logic in service objects

Controllers parse input and render output. Models hold validations and associations. All workflows live in single-purpose service objects returning a result object.

```ruby
result = Orders::Create.call(cart:, address:, shipping_method:, coupon_code:)
result.success? ? render_order(result.order) : render_errors(result.errors)
```

No business logic in controllers, callbacks, or views. ActiveRecord callbacks are limited to normalisation — never to side effects such as sending mail or charging cards.

### 2.4 Module boundaries

Code is grouped by domain, not by technical layer, and each domain is structured so it could be extracted into a Rails engine later.

```
Catalog · Ordering · Payments · Fulfilment · Reviews · Messaging · Identity · Rendering
```

Cross-domain communication goes through public service objects or domain events. Reaching into another domain's models directly is not allowed.

### 2.5 Configuration over hardcoding

Anything a business person might want to change — discount percentage, delivery fee, minimum DPI, coupon validity period, rush surcharge — lives in a `Setting` record editable in the admin, with a sane default in code. No magic numbers in the codebase.

---

## 3. Object Storage

Images are numerous and large; local disk is not an option.

**Recommended: Cloudflare R2.** S3-compatible API works with the stock ActiveStorage `aws-s3` adapter, zero egress fees, CDN included. Alternative: AWS S3 `sa-east-1` (São Paulo).

Two buckets:

- **public** — garment mockups, catalog previews, approved review photos. Served through CDN with long cache headers.
- **private** — original customer uploads, generated print files, pending review photos. Signed URLs only, short TTL.

Uploads go **direct to bucket** from the browser, bypassing Rails. All derivatives are produced by background workers.

---

## 4. Authentication and Guest Sessions

### Sign-in methods

- Email + password (email confirmation, password reset)
- Google OAuth

### Guest sessions

On first visit the server issues a `guest_token` (httpOnly cookie, 90-day lifetime). Designs, placements and carts are owned by the guest session rather than a user.

### Merging guests into accounts

One mechanism covers all three cases — new registration, login to an existing account, Google sign-in:

```
after successful authentication:
  find all Design / Placement / Cart owned by current guest_token
  → reassign owner to the user
  → merge guest cart into user cart (sum quantities of identical items)
  → clear guest_token
```

Merging happens on **every** authentication, not only at checkout. Otherwise a customer who logs in mid-session loses their work.

Login is requested at the moment the customer taps "Place order" — never earlier.

---

## 5. Templates

A `Template` is a specific garment in a specific colour with defined mockups and print areas.

### Fields

- `kind` — t-shirt, hoodie, sweatshirt, …
- `name`, `slug`, `description` (translatable)
- `color_name`, `color_hex`
- `base_price_cents` — the garment itself
- `print_price_one_side_cents`
- `print_price_two_sides_cents`
- `active`, `position`

Print pricing is defined **per template**: printing a hoodie costs more than printing a t-shirt.

### Print areas

`PrintArea` — one per side, `belongs_to :template`.

- `side` — `front` / `back`
- `mockup` — garment photo (ActiveStorage)
- `x`, `y`, `w`, `h` — rectangle expressed as **fractions of the mockup dimensions** (0.0–1.0)
- `width_mm`, `height_mm` — real physical size of the printable region
- `min_dpi` — default 150

Normalised coordinates mean the mockup image can be replaced with a different resolution without recalculating anything, and the frontend renders the area correctly at any container width.

`width_mm` is entered manually and is **not** derived from pixels — the area on a photograph and the area on real fabric are different things.

### Admin area editor

Admin uploads a mockup, drags a rectangle over it, enters real millimetres, saves. Repeated per side. The editor must work with a mouse and with touch.

---

## 6. Sizes and Inventory

`TemplateSize` — `belongs_to :template`.

- `label` — S, M, L, XL, XXL, …
- `stock` (integer)
- `restock_at` (nullable date)
- `position`

### Out-of-stock behaviour

The size stays visible but disabled:

- with `restock_at` → "Out of stock — back on March 15"
- without → "Out of stock"

### Reservation

Stock is decremented when **payment is confirmed**, not when an item enters the cart. Cancellation or refund restores it. Decrements run inside a transaction with a row lock so concurrent orders cannot drive stock negative.

---

## 7. Design Editor

A single React component serves both customers and admins; only the save action differs.

### Structure

```
container (position: relative)
 └─ <img> garment mockup
     └─ print area (position: absolute, % from PrintArea, overflow: hidden)
         └─ user artwork (transform: translate() scale() rotate())
```

The print area is positioned in percentages taken straight from `x/y/w/h`, so layout is fluid and survives any viewport change. Plain DOM with CSS transforms — no canvas needed for the editor itself.

### Interaction

Implemented with **Pointer Events**, giving mouse and touch support from one code path.

- **Drag** — `pointerdown` / `pointermove` / `pointerup`
- **Scale** — pinch gesture on touch, slider and scroll wheel on desktop
- **Rotate** — optional corner handle
- **Clamp** — on every change the artwork bounding box is constrained inside the print area; escaping the boundary is impossible

Touch targets are at least 44 × 44 px. `touch-action: none` on the canvas prevents page scroll while dragging. Gestures must not trigger browser zoom or pull-to-refresh.

### Upload requirements

- Formats: PNG, JPEG, WEBP — PNG with transparency preferred
- Max file size: 20 MB
- Minimum 800 px on the shorter side
- Real file type verified server-side, never trusting the extension

### Quality control

```
effective_dpi = design_px_width / (placement_width_mm / 25.4)
```

Below `min_dpi`, further enlargement is blocked and a warning appears: "Print quality will be low."

### Models

**`Design`**

- `file` (ActiveStorage), `width_px`, `height_px`
- `source` — `user` / `catalog`
- `owner` — polymorphic: User or GuestSession
- `moderation_status` — `pending` / `approved` / `rejected`
- `license_note` — for catalog artwork: origin and usage rights

**`Placement`**

- `design_id`, `print_area_id`
- `x`, `y` — artwork centre as fractions of the print area
- `scale`, `rotation`
- `placeable` — polymorphic: CartItem, OrderItem or CatalogItem

### Server-side validation

The frontend is not trusted. On save the backend re-verifies that the bounding box is inside the area, that scale is within limits, and that DPI meets the minimum. Violations return 422.

---

## 8. Catalog

Staff open the same editor, place artwork, and save the result as a purchasable product instead of adding it to a cart.

**`CatalogItem`**

- `template_id`
- `title`, `description`, `slug` (translatable)
- `price_cents` — flat price, typically below garment + custom print
- `tags`, `published`, `position`
- `has_many :placements`

### Customise from catalog

Product pages carry a "Customise this design" button. It copies the catalog placements into the customer's cart and opens the editor. From that point it is an ordinary custom order and is priced as one.

### Artwork rights

Every catalog `Design` must have `license_note` filled in — where the file came from and on what basis it is used.

---

## 9. Cart, Pricing and Orders

**`Cart`** — owned by a User or a GuestSession.

**`CartItem`**

- `template_id`, `template_size_id`
- `catalog_item_id` (nullable — set for ready-made products)
- `quantity` (integer ≥ 1)
- `has_many :placements`

### Line pricing

```
if catalog item:
    unit_price = catalog_item.price_cents
else:
    sides      = number of sides carrying artwork (1 or 2)
    print_cost = sides == 2 ? print_price_two_sides : print_price_one_side
    unit_price = template.base_price + print_cost

line_total = unit_price * quantity
```

### Order total

```
subtotal        = Σ line_total
− discount      (coupon, see §10)
+ rush_fee      (if express production selected)
+ shipping_fee  (0 for pickup)
= total
```

Prices are **frozen at order creation** — every amount is copied into `OrderItem`. Later price-list changes never affect existing orders.

### Express 24-hour production

`rush` and `rush_fee_cents` exist in the model and in the calculation, but the option is gated behind `Setting.rush_enabled`, disabled at launch and hidden in the UI.

---

## 10. Coupons and Discounts

A general-purpose discount mechanism; the review reward (§11) is its first consumer, not a special case.

**`Coupon`**

- `code` — unique, human-readable, uppercase
- `discount_type` — `percentage` / `fixed_amount`
- `discount_value` — 25 for 25 %, or cents for fixed
- `owner_id` — nullable; personal coupons bind to one customer, public campaign codes leave it null
- `source` — `review_reward` / `manual` / `campaign`
- `max_uses`, `used_count`
- `min_order_cents` — nullable minimum order value
- `valid_from`, `valid_until`
- `active`

### Application rules

- Applied at checkout by code, or auto-suggested when the customer owns an unused valid coupon
- One coupon per order — no stacking
- Discount applies to the item subtotal only, never to shipping or the rush fee
- Redemption is recorded against the order; cancelling an order restores the coupon
- Personal coupons are rejected for any other account

`Coupons::Validate` and `Coupons::Redeem` are the only entry points; the checkout flow never touches coupon state directly.

---

## 11. Photo Reviews and Rewards

The retention loop: customer receives the order → photographs themselves wearing it → submits a review → admin approves → a discount coupon is issued for the next purchase.

**`Review`**

- `order_id`, `user_id`
- `rating` — 1–5
- `body` — text, optional
- `photos` — ActiveStorage, 1–5 images, **at least one required**
- `status` — `pending` / `approved` / `rejected`
- `rejection_reason`
- `reviewed_by_id`, `reviewed_at`
- `published` — approved reviews may still be hidden from the storefront
- `coupon_id` — the reward issued, nullable

### Rules

- A review can be submitted only for an order in `delivered` status
- **One review per order.** A repeat purchase earns a new reward; the same order does not
- Photos are stored in the private bucket while pending and moved to public on approval
- Submission window: within 60 days of delivery (`Setting.review_window_days`)

### Reward flow

```
review_submitted   → notify operator
review_approved    → Reviews::IssueReward
                     ├─ create Coupon(
                     │    discount_type: percentage,
                     │    discount_value: Setting.review_reward_percent,   # default 25
                     │    owner: review.user,
                     │    source: :review_reward,
                     │    max_uses: 1,
                     │    valid_until: now + Setting.review_coupon_days   # default 90
                     │  )
                     ├─ link coupon to review
                     └─ email the customer with the code
review_rejected    → email with the reason, resubmission allowed once
```

The reward percentage, validity period and photo requirement are all settings, so the offer can be tuned without a deploy.

### Storefront display

Approved and published reviews appear on the template and catalog item pages: photo, rating, first name, date. A grid of real customer photos is the strongest asset this business has — the layout must show them well on a phone.

### Moderation queue

Operators see pending reviews with full-size photos, approve or reject with a reason. Approval issues the coupon automatically — no manual coupon creation.

### Abuse considerations

- Rate-limited submission per account
- Photos must be reviewed by a human before going public — no automatic publication
- Rejected reviews issue no coupon

---

## 12. Shipping

Two methods:

**Pickup** — from a location configured in settings (address, opening hours). Fee 0.

**Courier delivery — CABA only.** Addresses outside CABA are rejected at entry with: "We currently deliver within CABA only; pickup is available."

**`Address`** — `belongs_to :user`

- `street`, `number`, `apartment`, `floor`
- `neighborhood` (barrio), `postal_code`
- `recipient_name`, `phone`
- `notes` — courier instructions
- `is_default`

The shipping fee is a flat amount from settings. Both methods are implemented as `Shipping::Provider` adapters so additional zones or carriers can be added later without touching checkout.

### Taxes

Prices are all-inclusive. No separate tax line is calculated or displayed.

---

## 13. Order Lifecycle

```
draft
  ↓  customer places order
pending_approval          ← admin reviews the uploaded artwork
  ↓  approved                      ↘ rejected → rejected
awaiting_payment
  ↓  MercadoPago webhook confirms
paid
  ↓
preparing                 ← print files generated
  ↓
in_production
  ↓
awaiting_courier    ─── or ───  ready_for_pickup
  ↓                                  ↓
in_transit                           ↓
  ↓                                  ↓
delivered  ←─────────────────────────┘
  ↓
(review window opens)
```

**Terminal and exception states:** `rejected`, `cancelled`, `problem`, `refunded`.

### Artwork moderation

`pending_approval` is mandatory for **custom** orders. Orders containing only catalog items skip it automatically.

The admin sees the original artwork and the mockup preview, then approves or rejects with a reason. The customer is emailed either way.

Moderation sits **before** payment deliberately — rejecting artwork after a charge means processing a refund.

### Cancellation and refunds

- **Cancellation** — available to the customer through `in_production`. After that, operator only.
- **Refund** — accepted only for defects. The customer opens a chat thread, the operator resolves it manually and moves the order to `refunded`.

### Transitions

All transitions except customer cancellation are performed by an operator or admin. Only edges defined in the state machine are permitted — implement explicitly, never via a bare `update(status:)`.

---

## 14. Payments

**MercadoPago**, two flows behind one interface:

1. **Redirect** — Checkout Pro, returning to `success` / `failure` / `pending` URLs
2. **QR** — code rendered in-page, paid from the MercadoPago app

On mobile the QR is less useful than a deep link into the app — offer both and default to redirect on small screens.

### Webhook handling

```
1. Accept the notification, respond 200 immediately
2. Enqueue a background job
3. In the job: fetch payment status from the MercadoPago API by payment_id
   — never trust the webhook body
4. Verify amount and external_reference against the order
5. If approved → transition to paid, publish order_paid
```

**Idempotency is mandatory** — MercadoPago sends duplicates. A `payment_events` table with a unique index on `provider_event_id` guards against double processing.

**`Payment`**

- `order_id`, `provider`, `provider_payment_id`
- `amount_cents`, `currency`
- `status` — `pending` / `approved` / `rejected` / `refunded`
- `raw_payload` (jsonb) — full provider response for incident forensics

`FakeGateway` implements the same interface for development and tests, with buttons to simulate approval, rejection and delayed confirmation.

---

## 15. Notifications

`Notifications::Channel` defines the interface. Email ships at launch; WhatsApp, SMS and Telegram are added as new adapter classes with no changes to calling code.

```ruby
Notifications::Deliver.call(:order_paid, order:, channels: [:email])
```

Channel selection per event type is a setting, so enabling WhatsApp for shipping updates is a config change rather than a deploy.

All delivery runs through **Solid Queue** with retries and a dead-letter queue.

### Event matrix

| Event | Recipient |
|---|---|
| Order created | operator |
| Order approved / rejected | customer |
| Payment received | customer + operator |
| Production status changed | customer |
| Shipped / ready for pickup | customer |
| Delivered | customer (+ review invitation after N days) |
| Review approved — coupon issued | customer |
| Review rejected | customer |
| New chat message | counterpart |
| Order problem | customer |

Templates exist in both locales; the language is chosen from `user.locale`.

---

## 16. Messaging

Threads are attached **to the user**, not to individual orders — one continuous conversation.

**`Conversation`** — `belongs_to :user`, with `last_message_at`, `unread_for_admin`, `unread_for_user`.

**`Message`**

- `conversation_id`
- `sender` — polymorphic: User or AdminUser
- `body`
- `order_id` — nullable reference to the order under discussion
- `attachments` (ActiveStorage)
- `read_at`

### Order references

Below the composer sits a small **"Ask about an order"** link. Tapping it opens a sheet listing the customer's orders. Selecting one attaches it to the message: the chat then shows a compact card with order number, preview thumbnail and status, tapping through to the order page.

Operators have the equivalent control.

### Realtime

Solid Cable. Admins see a conversation list with unread counts sorted by `last_message_at`.

---

## 17. Rendering Pipeline

Background jobs on libvips, triggered by `order_paid`.

**Storefront preview** — mockup composited with artwork at the placement coordinates, JPEG around 1200 px.

**Print file** — transparent PNG:

```
canvas = (width_mm × 300 / 25.4) × (height_mm × 300 / 25.4) px
artwork placed from the normalised placement coordinates
```

One file per printed side, written to the private bucket, reachable from the order page via signed URL. "Download all artwork" returns a zip.

Renderers implement a common interface so a different output format — PDF, TIFF, a specific RIP layout — can be added as another adapter.

---

## 18. Admin Interface

- **Orders** — filterable list; order page with items, previews, print files, status, history, chat
- **Moderation** — queue of orders in `pending_approval`
- **Reviews** — pending queue with photos, approve/reject, published-review management
- **Coupons** — list, manual issuance, usage stats
- **Templates** — CRUD, mockup upload, print-area editor, pricing
- **Inventory** — stock per size, restock dates
- **Catalog** — build products in the editor, publish
- **Customers** — profile, orders, conversation
- **Conversations** — all threads
- **Settings** — shipping fee, pickup address, rush toggle, review reward percentage, coupon validity, minimum DPI, MercadoPago credentials

### Audit log

`AuditLog`: `admin_user`, `action`, `subject` (polymorphic), `changes` (jsonb), `created_at`.

Recorded for: order status changes, price edits, stock adjustments, artwork moderation, review moderation, coupon issuance, refunds, settings changes. Append-only — no edits, no deletes.

---

## 19. Internationalisation

- Locales: **es** (default), **ru**; adding a third must require no code changes
- UI strings via Rails i18n on the backend and i18next on the frontend
- Translatable content (template names, product titles, descriptions) via `mobility` or jsonb columns
- Resolution order: URL parameter → user preference → `Accept-Language` → es
- Emails are sent in the recipient's locale

---

## 20. Responsive and Mobile Requirements

> Mobile is not a degraded desktop view. Most customers will design and buy on a phone.

### Baseline

- **Mobile-first CSS.** Build for a 375 px viewport, enhance upward. Breakpoints at 640 / 1024 / 1280.
- Every flow — browse, upload, edit, checkout, review submission, chat — must be completable on a phone with no horizontal scrolling.
- Touch targets minimum 44 × 44 px; primary actions reachable in the lower third of the screen.
- Test matrix: iOS Safari, Android Chrome, desktop Chrome/Firefox/Safari.

### Editor specifics

- Pointer Events give one implementation for mouse and touch
- Pinch-to-zoom scales the artwork; `touch-action: none` on the canvas stops the page from scrolling or zooming underneath
- On narrow screens the editor is full-bleed with controls in a bottom sheet rather than a sidebar
- Side switching (front/back) is a segmented control, not a hover interaction
- Nothing depends on hover — every hover affordance has a tap equivalent

### Uploads

- Native file picker with camera access on mobile (`accept="image/*"`)
- Client-side downscale before upload when a photo exceeds the useful resolution — phone cameras produce files that waste bandwidth on a mobile connection
- Visible upload progress; uploads survive a backgrounded tab

### Review submission

Designed for a phone first: open camera, take photo, pick a rating, submit. This is the flow customers will use standing in front of a mirror.

### Performance targets

- Largest Contentful Paint under 2.5 s on a 4G connection
- Responsive images via ActiveStorage variants and `srcset`; never ship a 3000 px mockup to a phone
- Lazy-load below-the-fold catalog and review images

### Admin on mobile

The admin does not need to be beautiful on a phone, but the order list, status transitions, review moderation and chat must be usable — those are the things staff do away from a desk.

---

## 21. Open Questions

1. **Cancellation rule.** An earlier note read "cancellation and refund always allowed if the order is more than 2 shirts" — the intent is unclear. This document currently specifies: cancellation until production begins, refunds for defects only. Needs a decision.
2. **Review reward percentage** — 25 % is the placeholder default. Confirm, and decide whether it should vary by order value.
3. **Coupon on discounted orders** — may a review coupon be used on a catalog item that is already cheaper than custom?
4. **Promo codes / campaigns** — the `Coupon` model supports them; is a campaign UI needed at launch?
5. **Pickup locations** — one or several?
6. **Guest data retention** — after how long are abandoned guest carts and designs purged?
7. **Legal pages** — terms of sale, privacy policy, artwork upload rules: who writes the copy?

---

## 22. Delivery Plan

**Phase 1 — Foundations**
Domain module skeleton, event bus, adapter registry, models, authentication, guest sessions and merging, ActiveStorage with bucket, i18n scaffolding.

**Phase 2 — Templates**
Template admin, print-area editor, sizes and inventory.

**Phase 3 — Design editor**
React component, pointer-event drag and pinch, clamping, DPI checks, server-side validation. Mobile verified from day one, not retrofitted.

**Phase 4 — Catalog**
Product assembly, storefront, customise-from-catalog.

**Phase 5 — Ordering**
Cart, shipping, coupon engine, order state machine, artwork moderation, `FakeGateway` end to end.

**Phase 6 — Payments**
MercadoPago adapter, webhooks, idempotency, reconciliation.

**Phase 7 — Communications**
Notification channels, chat, realtime.

**Phase 8 — Reviews and rewards**
Review submission, moderation queue, coupon issuance, storefront display.

**Phase 9 — Production**
Print file rendering, artwork export, audit log, admin polish.