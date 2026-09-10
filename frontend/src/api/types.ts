// Response shapes mirror app/serializers/serializers.rb and Messaging::MessageSerializer.

export interface User {
  id: number
  email: string
  first_name: string | null
  last_name: string | null
  phone: string | null
  locale: string | null
  confirmed: boolean
  has_password: boolean
  google: boolean
}

export type Side = 'front' | 'back'

export interface PrintArea {
  id: number
  side: Side
  x: number
  y: number
  w: number
  h: number
  width_mm: number
  height_mm: number
  min_dpi: number
  mockup_url: string | null
  mockup_card_url: string | null
  mockup_thumb_url: string | null
  mockup_width_px: number | null
  mockup_height_px: number | null
}

export interface TemplateSize {
  id: number
  label: string
  stock: number
  available: boolean
  restock_at: string | null
}

export interface Template {
  id: number
  slug: string
  kind: string
  name: string
  description: string | null
  color_name: string | null
  color_hex: string | null
  base_price_cents: number
  print_price_one_side_cents: number
  print_price_two_sides_cents: number
  image_url: string | null
  sizes: TemplateSize[]
}

export interface TemplateFull extends Template {
  print_areas: PrintArea[]
}

/** Low-resolution artwork is accepted; the shop upscales it before printing. */
export type EnhancementStatus = 'none' | 'needed' | 'requested' | 'processing' | 'done' | 'failed'

export interface Design {
  id: number
  /** Effective pixel size: the upscaled file when one exists, otherwise the upload. */
  width_px: number
  height_px: number
  /** Pixel size of the file the customer actually uploaded. */
  uploaded_width_px: number
  uploaded_height_px: number
  content_type: string
  source: 'user' | 'catalog'
  url: string | null
  thumb_url: string | null
  license_note: string | null
  enhancement_status: EnhancementStatus
  enhanced: boolean
  needs_enhancement: boolean
  enhancement_note: string | null
}

export interface PlacementInput {
  design_id: number
  print_area_id: number
  x: number
  y: number
  scale: number
  rotation: number
}

export interface Placement extends PlacementInput {
  id: number
  side: Side
  effective_dpi: number
  low_quality: boolean
  min_dpi: number
  design: Design
}

export interface CatalogItem {
  id: number
  slug: string
  title: string
  description: string | null
  price_cents: number
  tags: string[]
  image_url: string | null
  large_image_url: string | null
  template: Template
  sides_count: number
}

export interface CatalogItemFull extends Omit<CatalogItem, 'template'> {
  template: TemplateFull
  placements: Placement[]
}

export interface CartItem {
  id: number
  quantity: number
  template: TemplateFull
  size: TemplateSize
  catalog_item: CatalogItem | null
  custom: boolean
  placements: Placement[]
  sides_count: number
  unit_price_cents: number
  line_total_cents: number
}

export interface Cart {
  id: number
  items: CartItem[]
  subtotal_cents: number
  total_quantity: number
}

export type ShippingMethod = 'pickup' | 'courier'

export interface Quote {
  valid: boolean
  errors: string[]
  subtotal_cents: number
  discount_cents: number
  coupon_code: string | null
  coupon_error: string | null
  rush: boolean
  rush_fee_cents: number
  shipping_fee_cents: number
  shipping_method: ShippingMethod
  total_cents: number
  requires_moderation: boolean
}

export interface Address {
  id: number
  recipient_name: string
  phone: string | null
  street: string
  number: string | null
  apartment: string | null
  floor: string | null
  neighborhood: string | null
  postal_code: string
  city: string
  notes: string | null
  is_default: boolean
  one_line: string
}

export type AddressInput = Omit<Address, 'id' | 'one_line' | 'is_default'> & { is_default?: boolean }

export type OrderStatus =
  | 'draft'
  | 'pending_approval'
  | 'awaiting_payment'
  | 'paid'
  | 'preparing'
  | 'in_production'
  | 'awaiting_courier'
  | 'ready_for_pickup'
  | 'in_transit'
  | 'delivered'
  | 'rejected'
  | 'cancelled'
  | 'problem'
  | 'refunded'

export interface OrderItemSnapshot {
  template_name?: string
  template_slug?: string
  color_name?: string
  color_hex?: string
  size_label?: string
  title?: string
  catalog_slug?: string | null
  base_price_cents?: number
  print_price_cents?: number | null
  sides?: Side[]
}

export interface OrderItem {
  id: number
  quantity: number
  unit_price_cents: number
  line_total_cents: number
  sides_count: number
  custom: boolean
  snapshot: OrderItemSnapshot
  title: string
  size_label: string | null
  preview_url: string | null
  placements: Placement[]
}

export interface Payment {
  id: number
  provider: string
  flow: 'redirect' | 'qr'
  status: 'pending' | 'approved' | 'rejected' | 'refunded'
  amount_cents: number
  checkout_url: string | null
  qr_data: string | null
  qr_svg: string | null
}

export interface Coupon {
  code: string
  discount_type: 'percentage' | 'fixed_amount'
  discount_value: number
  valid_until: string | null
  used: boolean
  valid: boolean
  min_order_cents: number | null
}

export interface ReviewPhoto {
  thumb_url: string | null
  url: string | null
}

export interface Review {
  id: number
  rating: number
  body: string | null
  first_name: string
  date: string
  photos: ReviewPhoto[]
  product: string | null
}

export interface OwnedReview extends Review {
  status: 'pending' | 'approved' | 'rejected'
  rejection_reason: string | null
  can_resubmit: boolean
  coupon: Coupon | null
}

export interface OrderHistoryEntry {
  from: string | null
  to: OrderStatus
  at: string
  reason: string | null
}

export interface Order {
  id: number
  number: string
  status: OrderStatus
  status_label: string
  total_cents: number
  subtotal_cents: number
  discount_cents: number
  rush_fee_cents: number
  shipping_fee_cents: number
  shipping_method: ShippingMethod
  placed_at: string | null
  paid_at: string | null
  delivered_at: string | null
  item_count: number
  preview_url: string | null
  can_cancel: boolean
  can_pay: boolean
  can_review: boolean
  review_status: 'pending' | 'approved' | 'rejected' | null
  rejection_reason: string | null
  /** At least one placement is below its print area's minimum DPI: the shop upscales it. */
  low_quality_artwork: boolean
}

export interface OrderFull extends Order {
  items: OrderItem[]
  shipping_address: Partial<Address> & Record<string, unknown>
  coupon_code: string | null
  customer_notes: string | null
  problem_note: string | null
  history: OrderHistoryEntry[]
  payment: Payment | null
  review: OwnedReview | null
}

export interface ShippingMethodInfo {
  code: ShippingMethod
  label: string
  description: string | null
  requires_address: boolean
  fee_cents: number
  available: boolean
}

export interface PublicSettings {
  store_name: string
  currency: string
  locales: string[]
  default_locale: string
  shipping_methods: ShippingMethodInfo[]
  rush_enabled: boolean
  rush_fee_cents: number
  max_upload_bytes: number
  min_upload_px: number
  min_dpi: number
  /** Escape hatch: when on, the editor blocks placements below min_dpi again. Default false. */
  enforce_min_dpi: boolean
  /** Escape hatch: when on, uploads under min_upload_px are rejected again. Default false. */
  enforce_min_upload_px: boolean
  review_reward_percent: number
  review_window_days: number
  review_max_photos: number
  pickup_address: string | null
  pickup_hours: string | null
  google_login: boolean
  payment_provider: string
  /** Development only. Seeded demo accounts offered as click-to-fill shortcuts; null in production. */
  dev_credentials: DevCredentials | null
}

export interface DevCredentialAccount {
  email: string
  password: string
  label: string
}

export interface DevCredentials {
  customers: DevCredentialAccount[]
  staff: DevCredentialAccount[]
  /** True when the shortcuts were switched on outside development, which deserves a warning. */
  forced: boolean
}

export interface SessionPayload {
  user: User | null
  locale: string
  cart_quantity: number
  csrf_token: string
  settings: PublicSettings
  unread_messages: number
}

export interface MessageAttachment {
  id: number
  filename: string
  url: string
  image: boolean
}

export interface MessageOrderRef {
  number: string
  status: OrderStatus
  total_cents: number
  preview_url: string | null
}

export interface Message {
  id: number
  body: string | null
  from_admin: boolean
  sender_name: string
  created_at: string
  read_at: string | null
  order: MessageOrderRef | null
  attachments: MessageAttachment[]
}

export interface ApiErrorBody {
  error: string
  errors?: string[]
  code?: string
}

export interface DirectUploadInfo {
  signed_id: string
  direct_upload: { url: string; headers: Record<string, string> }
}

export interface PlacementQuality {
  print_area_id: number
  effective_dpi: number
  low_quality: boolean
  min_dpi: number
  required_width_px: number
  required_height_px: number
}

/**
 * POST /api/v1/designs/validate_placement.
 * Low DPI is no longer a rejection: it comes back under `warnings` with `valid: true`.
 * A 422 (real geometry/lookup error) is thrown as an ApiError instead of reaching here.
 */
export interface PlacementValidation {
  valid: boolean
  placements?: PlacementQuality[]
  warnings?: PlacementQuality[]
  error?: string
  errors?: string[]
  code?: string
}
