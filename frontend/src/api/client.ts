import type {
  Address,
  AddressInput,
  ApiErrorBody,
  Cart,
  CartItem,
  CatalogItem,
  CatalogItemFull,
  Coupon,
  Design,
  DirectUploadInfo,
  Message,
  Order,
  OrderFull,
  OwnedReview,
  Payment,
  PlacementInput,
  PlacementValidation,
  PublicSettings,
  Quote,
  Review,
  SessionPayload,
  ShippingMethod,
  Template,
  TemplateFull,
  User,
} from './types'

export class ApiError extends Error {
  status: number
  code: string | undefined
  errors: string[]

  constructor(status: number, body: ApiErrorBody | null, fallback: string) {
    super(body?.error || fallback)
    this.name = 'ApiError'
    this.status = status
    this.code = body?.code
    this.errors = body?.errors && body.errors.length > 0 ? body.errors : [this.message]
  }

  get loginRequired() {
    return this.status === 401 && this.code === 'login_required'
  }
}

type LoginRequiredHandler = () => Promise<boolean>

let csrfToken = ''
let currentLocale = 'es'
let loginRequiredHandler: LoginRequiredHandler | null = null

export function setCsrfToken(token: string | null | undefined) {
  if (token) csrfToken = token
}
export function getCsrfToken() {
  return csrfToken
}
export function setApiLocale(locale: string) {
  currentLocale = locale
}
export function setLoginRequiredHandler(handler: LoginRequiredHandler | null) {
  loginRequiredHandler = handler
}

type Method = 'GET' | 'POST' | 'PATCH' | 'PUT' | 'DELETE'

interface RequestOptions {
  method?: Method
  body?: unknown
  query?: Record<string, string | number | boolean | undefined | null>
  /** When true (default) a 401 login_required opens the auth modal and retries once after login. */
  retryOnLogin?: boolean
  signal?: AbortSignal
}

function buildUrl(path: string, query?: RequestOptions['query']) {
  const url = new URL(path, window.location.origin)
  if (query) {
    for (const [k, v] of Object.entries(query)) {
      if (v !== undefined && v !== null && v !== '') url.searchParams.set(k, String(v))
    }
  }
  return url.toString()
}

async function parseBody(res: Response): Promise<unknown> {
  if (res.status === 204) return null
  const text = await res.text()
  if (!text) return null
  try {
    return JSON.parse(text)
  } catch {
    return null
  }
}

export async function request<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const method = options.method || 'GET'
  const headers: Record<string, string> = {
    Accept: 'application/json',
    'Accept-Language': currentLocale,
    'X-Requested-With': 'XMLHttpRequest',
  }
  if (method !== 'GET') headers['X-CSRF-Token'] = csrfToken
  if (options.body !== undefined) headers['Content-Type'] = 'application/json'

  const res = await fetch(buildUrl(path, options.query), {
    method,
    headers,
    credentials: 'same-origin',
    body: options.body !== undefined ? JSON.stringify(options.body) : undefined,
    signal: options.signal,
  })
  setCsrfToken(res.headers.get('X-CSRF-Token'))
  const data = await parseBody(res)

  if (!res.ok) {
    const err = new ApiError(res.status, (data as ApiErrorBody) || null, res.statusText || 'Request failed')
    if (err.loginRequired && options.retryOnLogin !== false && loginRequiredHandler) {
      const loggedIn = await loginRequiredHandler()
      if (loggedIn) return request<T>(path, { ...options, retryOnLogin: false })
    }
    throw err
  }
  return data as T
}

const get = <T,>(path: string, query?: RequestOptions['query'], opts?: RequestOptions) => request<T>(path, { ...opts, query })
const post = <T,>(path: string, body?: unknown, opts?: RequestOptions) => request<T>(path, { ...opts, method: 'POST', body })
const patch = <T,>(path: string, body?: unknown, opts?: RequestOptions) => request<T>(path, { ...opts, method: 'PATCH', body })
const del = <T,>(path: string, opts?: RequestOptions) => request<T>(path, { ...opts, method: 'DELETE' })

export interface AuthResponse {
  user: User
  csrf_token: string
  cart_quantity?: number
}

export const api = {
  // ---- session / identity ----
  session: () => get<SessionPayload>('/api/v1/session'),
  login: (email: string, password: string) => post<AuthResponse>('/api/v1/session', { email, password }, { retryOnLogin: false }),
  register: (params: { email: string; password: string; first_name?: string; last_name?: string }) =>
    post<AuthResponse>('/api/v1/registration', params, { retryOnLogin: false }),
  logout: () => del<{ ok: boolean; csrf_token: string }>('/api/v1/session'),
  requestPasswordReset: (email: string) => post<{ ok: boolean }>('/api/v1/password_resets', { email }),
  resetPassword: (token: string, password: string) => patch<AuthResponse>(`/api/v1/password_resets/${encodeURIComponent(token)}`, { password }),
  confirmEmail: (token: string) => patch<{ user: User }>(`/api/v1/confirmations/${encodeURIComponent(token)}`),
  resendConfirmation: () => post<{ ok: boolean }>('/api/v1/confirmations'),
  updateProfile: (params: { first_name?: string; last_name?: string; phone?: string; locale?: string; password?: string; current_password?: string }) =>
    patch<{ user: User }>('/api/v1/profile', params),
  settings: () => get<{ settings: PublicSettings }>('/api/v1/settings'),

  // ---- catalog ----
  templates: () => get<{ templates: Template[] }>('/api/v1/templates'),
  template: (slug: string) => get<{ template: TemplateFull; reviews: Review[] }>(`/api/v1/templates/${encodeURIComponent(slug)}`),
  catalogItems: (tag?: string) => get<{ catalog_items: CatalogItem[]; tags: string[] }>('/api/v1/catalog_items', { tag }),
  catalogItem: (slug: string) => get<{ catalog_item: CatalogItemFull; reviews: Review[] }>(`/api/v1/catalog_items/${encodeURIComponent(slug)}`),
  customizeCatalogItem: (slug: string, template_size_id?: number) =>
    post<{ cart_item: CartItem }>(`/api/v1/catalog_items/${encodeURIComponent(slug)}/customize`, { template_size_id }),
  reviews: (params: { template_id?: number; catalog_item_id?: number; page?: number }) => get<{ reviews: Review[]; page: number }>('/api/v1/reviews', params),

  // ---- uploads / designs ----
  createUpload: (blob: { filename: string; byte_size: number; checksum: string; content_type: string }) =>
    post<DirectUploadInfo>('/api/v1/uploads', { blob }),
  designs: () => get<{ designs: Design[] }>('/api/v1/designs'),
  createDesign: (signed_id: string) => post<{ design: Design }>('/api/v1/designs', { signed_id }),
  deleteDesign: (id: number) => del<null>(`/api/v1/designs/${id}`),
  validatePlacement: (template_id: number, placements: PlacementInput[]) =>
    post<PlacementValidation>('/api/v1/designs/validate_placement', { template_id, placements }),

  // ---- cart ----
  cart: () => get<{ cart: Cart }>('/api/v1/cart'),
  addCartItem: (params: { template_id: number; template_size_id: number; quantity: number; catalog_item_id?: number; placements: PlacementInput[] }) =>
    post<{ cart: Cart }>('/api/v1/cart/items', params),
  updateCartItem: (id: number, params: { quantity?: number; template_size_id?: number; placements?: PlacementInput[] }) =>
    patch<{ cart: Cart }>(`/api/v1/cart/items/${id}`, params),
  removeCartItem: (id: number) => del<{ cart: Cart }>(`/api/v1/cart/items/${id}`),
  quote: (params: { shipping_method: ShippingMethod; address_id?: number; coupon_code?: string; rush?: boolean }) =>
    post<{ quote: Quote }>('/api/v1/cart/quote', params),

  // ---- addresses / coupons ----
  addresses: () => get<{ addresses: Address[] }>('/api/v1/addresses'),
  createAddress: (address: AddressInput) => post<{ address: Address }>('/api/v1/addresses', { address }),
  updateAddress: (id: number, address: Partial<AddressInput>) => patch<{ address: Address }>(`/api/v1/addresses/${id}`, { address }),
  deleteAddress: (id: number) => del<null>(`/api/v1/addresses/${id}`),
  validateCoupon: (code: string) => post<{ coupon: Coupon; discount_cents: number }>('/api/v1/coupons/validate', { code }),
  myCoupons: () => get<{ coupons: Coupon[] }>('/api/v1/coupons/mine'),

  // ---- orders / payments / reviews ----
  orders: () => get<{ orders: Order[] }>('/api/v1/orders'),
  order: (number: string) => get<{ order: OrderFull }>(`/api/v1/orders/${encodeURIComponent(number)}`),
  createOrder: (params: {
    shipping_method: ShippingMethod
    address_id?: number
    address?: AddressInput
    coupon_code?: string
    rush?: boolean
    customer_notes?: string
  }) => post<{ order: OrderFull }>('/api/v1/orders', params),
  cancelOrder: (number: string, reason?: string) => post<{ order: OrderFull }>(`/api/v1/orders/${encodeURIComponent(number)}/cancel`, { reason }),
  startPayment: (number: string, flow: 'redirect' | 'qr') => post<{ payment: Payment }>(`/api/v1/orders/${encodeURIComponent(number)}/payments`, { flow }),
  paymentStatus: (number: string) =>
    get<{ order_status: Order['status']; payment_status: Payment['status'] | null }>(`/api/v1/orders/${encodeURIComponent(number)}/payments/status`),
  submitReview: (number: string, params: { rating: number; body?: string; photos: string[] }) =>
    post<{ review: OwnedReview }>(`/api/v1/orders/${encodeURIComponent(number)}/review`, params),

  // ---- messages ----
  messages: () => get<{ conversation_id: number; messages: Message[]; orders: Order[] }>('/api/v1/messages'),
  sendMessage: (params: { body: string; order_id?: number; attachments?: string[] }) => post<{ message: Message }>('/api/v1/messages', params),
}

export type Api = typeof api
