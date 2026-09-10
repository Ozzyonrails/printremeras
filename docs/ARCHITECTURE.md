# Architecture

## Domains
Code is grouped by domain inside `app/services/<domain>` (plus matching jobs/mailers). Models are
shared ActiveRecord classes; cross-domain work goes through public service objects or domain events.

| Domain | Owns | Entry points |
|---|---|---|
| Identity | users, admin users, guest sessions, addresses, merge | `Identity::Register/Authenticate/GoogleSignIn/MergeGuest/…` |
| Catalog | templates, print areas, sizes, designs, placements, catalog items, artwork quality | `Catalog::CreateDesign`, `Catalog::BuildPlacements`, `Catalog::SaveCatalogItem`, `Catalog::CustomizeFromCatalog`, `Designs::FlagQuality/RequestEnhancement/Enhance` |
| Ordering | carts, quotes, orders, state machine, inventory | `Orders::AddToCart/UpdateCartItem/Quote/Create/Transition/Cancel/Approve/Reject`, `Inventory::Adjust` |
| Coupons | coupons, redemptions | `Coupons::Validate`, `Coupons::Redeem`, `Coupons::Restore`, `Coupons::Issue` |
| Payments | payments, payment events | `Payments::StartCheckout`, `Payments::HandleWebhook`, `Payments::ProcessEvent`, `Payments::Refund` |
| Shipping | delivery methods | `Shipping::Provider` adapters |
| Fulfilment / Rendering | previews, print files, artwork export | `Rendering::RenderOrderItem`, `Rendering::ExportArtwork` |
| Reviews | photo reviews, rewards | `Reviews::Submit/Approve/Reject`, `Reviews::IssueReward`, `Reviews::PublishPhotos` |
| Messaging | conversations, messages, realtime | `Messaging::SendMessage`, `Messaging::MarkRead`, `Messaging::Broadcast` |
| Notifications | channels, event → recipient matrix | `Notifications::Deliver`, `Notifications::Notify` |

## Ports and adapters
Interfaces (`Payments::Gateway`, `Notifications::Channel`, `Shipping::Provider`, `Rendering::Renderer`)
are resolved through `Adapters` (lib/adapters.rb) from `config.x.*` in `config/application.rb`:

```ruby
config.x.payments.gateway = ENV.fetch("PAYMENTS_GATEWAY", "Payments::MercadoPagoGateway")
config.x.notifications.channels = { email: "Notifications::EmailChannel" }          # add whatsapp: "Notifications::WhatsappChannel"
config.x.shipping.providers = { pickup: "Shipping::PickupProvider", courier: "Shipping::CabaCourierProvider" }
config.x.rendering.print_file_renderer = "Rendering::PrintFileRenderer"
config.x.image_enhancement.provider    = ENV.fetch("IMAGE_ENHANCEMENT_PROVIDER", "ImageEnhancement::NullProvider")
```
No vendor name appears outside its adapter file (`grep MercadoPago app lib` → only `app/services/payments/`).
Object storage is abstracted by ActiveStorage services `*_public` / `*_private` selected via `STORAGE_BACKEND`.

## Domain events
`DomainEvents.publish(:order_paid, order_id: …)` (lib/domain_events.rb). Subscriptions are declared in
`config/initializers/domain_events.rb`; each subscriber runs in its own `DomainEvents::DispatchJob`
after the surrounding transaction commits (`ActiveRecord.after_all_transactions_commit`), with retries;
exhausted retries land in Solid Queue's failed set (Admin → Jobs) — the dead-letter queue.

Catalogue: `order_created order_approved order_rejected order_paid order_status_changed order_cancelled
order_refunded order_problem payment_failed review_submitted review_approved review_rejected coupon_issued
message_created design_uploaded`.

## Order state machine
`Orders::Transition::TRANSITIONS` is the only source of truth; `Order#status` is never written directly.
Custom orders start in `pending_approval` (artwork moderation before payment); catalog-only orders in
`awaiting_payment`. Stock is decremented on `order_paid` under `SELECT … FOR UPDATE`; cancellation /
refund from a stock-holding state restores it and the coupon.

## Payments
`StartCheckout` creates a `Payment` and asks the gateway for a checkout (redirect URL; the same URL is
rendered as a QR). Webhooks: controller stores a `PaymentEvent` (unique per provider event id) and
returns 200; `ProcessEventJob` fetches the authoritative status from the provider, checks amount and
external reference, and transitions the order. Duplicates are ignored by the unique index.

## Placement geometry
`x, y` = artwork centre as fractions of the print area; `scale` = artwork width / print-area width;
`rotation` in degrees. The rotated bounding box is validated in millimetres (`Placement#within_area?`)
and `effective_dpi = design.width_px / (scale * width_mm / 25.4)` must reach `PrintArea#min_dpi`.
The React editor performs the same maths client-side; the server re-validates on every save
(422 only for artwork escaping the print area). Falling short of `min_dpi` is a warning: the
placement saves, `Design#enhancement_status` becomes `needed`, and `Order#low_quality_artwork`
is set, so the artwork can be upscaled through `ImageEnhancement::Provider` before printing.
`Placement#required_width_px/height_px` say how many pixels the provider must produce.
Print files are rendered at 300 DPI on a canvas of `width_mm × height_mm`; previews composite the
artwork on the mockup at the area's pixel rectangle.

## Frontend ↔ backend
Same-origin cookie session (guest token cookie for anonymous users, `session[:user_id]` after login),
CSRF token exposed on `/api/v1/session` and in the `X-CSRF-Token` response header. In development
Vite proxies API paths to Rails; in production Rails serves `public/app/index.html` for storefront
routes (`SpaController`). The admin embeds the React editors via `vite_admin_tags` (Vite manifest).
