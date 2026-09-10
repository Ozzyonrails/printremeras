import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { api, ApiError } from '../api/client'
import type { Address, AddressInput, Cart, Coupon, Quote, ShippingMethod } from '../api/types'
import { useSession } from '../store/session'
import { formatDate, formatMoney } from '../lib/money'
import { AuthForm } from '../components/AuthForm'
import { AddressForm } from '../components/AddressForm'
import { ErrorBox, Money, Notice, PageLoading, PageTitle, Spinner } from '../components/ui'
import { EmptyState } from '../components/EmptyState'
import { cartItemThumb } from './CartPage'

export function CheckoutPage() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { user, settings, errorMessage, setCartQuantity, locale, toast } = useSession()
  const [cart, setCart] = useState<Cart | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [method, setMethod] = useState<ShippingMethod>('pickup')
  const [addresses, setAddresses] = useState<Address[]>([])
  const [addressId, setAddressId] = useState<number | null>(null)
  const [addressFormOpen, setAddressFormOpen] = useState(false)
  const [addressError, setAddressError] = useState<string | null>(null)
  const [couponInput, setCouponInput] = useState('')
  const [couponCode, setCouponCode] = useState('')
  const [couponError, setCouponError] = useState<string | null>(null)
  const [myCoupons, setMyCoupons] = useState<Coupon[]>([])
  const [rush, setRush] = useState(false)
  const [notes, setNotes] = useState('')
  const [quote, setQuote] = useState<Quote | null>(null)
  const [quoting, setQuoting] = useState(false)
  const [placing, setPlacing] = useState(false)
  const [placeError, setPlaceError] = useState<string | null>(null)
  const quoteSeq = useRef(0)

  const methods = useMemo(() => settings?.shipping_methods.filter((m) => m.available) ?? [], [settings])
  const courierInfo = methods.find((m) => m.code === 'courier')
  const pickupInfo = methods.find((m) => m.code === 'pickup')

  const loadCart = useCallback(() => {
    setError(null)
    api
      .cart()
      .then(({ cart }) => {
        setCart(cart)
        setCartQuantity(cart.total_quantity)
      })
      .catch((e) => setError(errorMessage(e)))
  }, [errorMessage, setCartQuantity])

  useEffect(loadCart, [loadCart])

  // After login the server has merged the guest cart: re-fetch cart, addresses and personal coupons.
  useEffect(() => {
    if (!user) {
      setAddresses([])
      setMyCoupons([])
      return
    }
    loadCart()
    api
      .addresses()
      .then(({ addresses }) => {
        setAddresses(addresses)
        setAddressId((cur) => cur ?? addresses.find((a) => a.is_default)?.id ?? addresses[0]?.id ?? null)
      })
      .catch(() => undefined)
    api.myCoupons().then(({ coupons }) => setMyCoupons(coupons.filter((c) => c.valid && !c.used))).catch(() => undefined)
  }, [user, loadCart])

  // Live quote
  useEffect(() => {
    if (!cart || cart.items.length === 0) return
    const seq = ++quoteSeq.current
    setQuoting(true)
    api
      .quote({ shipping_method: method, address_id: method === 'courier' && addressId ? addressId : undefined, coupon_code: couponCode || undefined, rush })
      .then(({ quote }) => {
        if (seq !== quoteSeq.current) return
        setQuote(quote)
        setCouponError(quote.coupon_error)
      })
      .catch((e) => {
        if (seq !== quoteSeq.current) return
        setQuote(null)
        setPlaceError(errorMessage(e))
      })
      .finally(() => seq === quoteSeq.current && setQuoting(false))
  }, [cart, method, addressId, couponCode, rush, errorMessage])

  const applyCoupon = async () => {
    const code = couponInput.trim().toUpperCase()
    if (!code) return
    setCouponError(null)
    try {
      await api.validateCoupon(code)
      setCouponCode(code)
    } catch (e) {
      setCouponError(e instanceof ApiError ? e.errors.join(' ') : errorMessage(e))
    }
  }

  const saveAddress = async (input: AddressInput) => {
    setAddressError(null)
    try {
      const { address } = await api.createAddress(input)
      setAddresses((a) => [...a, address])
      setAddressId(address.id)
      setAddressFormOpen(false)
      toast(t('address.saved'), 'success')
    } catch (e) {
      setAddressError(e instanceof ApiError ? e.errors.join(' ') : errorMessage(e))
    }
  }

  const placeOrder = async () => {
    if (!cart) return
    setPlacing(true)
    setPlaceError(null)
    try {
      const { order } = await api.createOrder({
        shipping_method: method,
        address_id: method === 'courier' && addressId ? addressId : undefined,
        coupon_code: couponCode || undefined,
        rush: settings?.rush_enabled ? rush : undefined,
        customer_notes: notes.trim() || undefined,
      })
      setCartQuantity(0)
      toast(t('checkout.orderPlaced'), 'success')
      navigate(`/orders/${order.number}`, { replace: true })
    } catch (e) {
      setPlaceError(e instanceof ApiError ? e.errors.join(' ') : errorMessage(e))
      setPlacing(false)
    }
  }

  if (error) return <div className="container-page py-6"><ErrorBox message={error} onRetry={loadCart} /></div>
  if (!cart || !settings) return <PageLoading />
  if (cart.items.length === 0) {
    return (
      <div className="container-page py-6">
        <PageTitle>{t('checkout.title')}</PageTitle>
        <EmptyState title={t('checkout.empty')} cta={t('cart.browse')} to="/" />
      </div>
    )
  }

  const needsAddress = method === 'courier'
  const addressMissing = needsAddress && !addressId
  const canPlace = !!user && !placing && !quoting && !!quote && quote.valid && !addressMissing
  const selectedAddress = addresses.find((a) => a.id === addressId)
  const shippingErrors = quote?.errors.filter((e) => e !== quote.coupon_error) ?? []

  return (
    <div className="container-page py-6 pb-36 lg:pb-8">
      <PageTitle>{t('checkout.title')}</PageTitle>
      <div className="lg:grid lg:grid-cols-[1fr_360px] lg:gap-8">
        <div className="space-y-6">
          {/* Auth gate: login is requested here, never earlier (spec §4) */}
          {!user && (
            <section className="card p-4">
              <h2 className="text-lg font-bold">{t('checkout.loginTitle')}</h2>
              <p className="mb-3 text-sm text-ink-500">{t('checkout.loginSubtitle')}</p>
              <AuthForm compact />
            </section>
          )}

          <section className="card p-4">
            <h2 className="mb-3 text-lg font-bold">{t('checkout.shipping')}</h2>
            <div className="space-y-2" role="radiogroup">
              {pickupInfo && (
                <label className={`flex min-h-touch cursor-pointer items-start gap-3 rounded-xl border p-3 ${method === 'pickup' ? 'border-ink-900 bg-ink-100' : 'border-ink-300'}`}>
                  <input type="radio" name="shipping" className="mt-1 h-5 w-5" checked={method === 'pickup'} onChange={() => setMethod('pickup')} />
                  <span className="flex-1">
                    <span className="flex justify-between font-semibold">
                      {t('checkout.pickup')} <span>{t('common.free')}</span>
                    </span>
                    <span className="block text-sm text-ink-500">{settings.pickup_address}</span>
                    {settings.pickup_hours && <span className="block text-sm text-ink-500">{t('checkout.hours', { hours: settings.pickup_hours })}</span>}
                  </span>
                </label>
              )}
              {courierInfo && (
                <label className={`flex min-h-touch cursor-pointer items-start gap-3 rounded-xl border p-3 ${method === 'courier' ? 'border-ink-900 bg-ink-100' : 'border-ink-300'}`}>
                  <input type="radio" name="shipping" className="mt-1 h-5 w-5" checked={method === 'courier'} onChange={() => setMethod('courier')} />
                  <span className="flex-1">
                    <span className="flex justify-between font-semibold">
                      {t('checkout.courier')} <Money cents={courierInfo.fee_cents} />
                    </span>
                    <span className="block text-sm text-ink-500">{courierInfo.description || t('checkout.courierNote')}</span>
                  </span>
                </label>
              )}
            </div>

            {needsAddress && (
              <div className="mt-4">
                <h3 className="mb-2 font-semibold">{t('checkout.address')}</h3>
                {!user && <p className="text-sm text-ink-500">{t('checkout.loginToContinue')}</p>}
                {user && addresses.length > 0 && !addressFormOpen && (
                  <div className="space-y-2">
                    {addresses.map((a) => (
                      <label key={a.id} className={`flex min-h-touch cursor-pointer items-start gap-3 rounded-xl border p-3 ${addressId === a.id ? 'border-ink-900 bg-ink-100' : 'border-ink-300'}`}>
                        <input type="radio" name="address" className="mt-1 h-5 w-5" checked={addressId === a.id} onChange={() => setAddressId(a.id)} />
                        <span className="text-sm">
                          <span className="block font-semibold">{a.recipient_name}</span>
                          {a.one_line}
                        </span>
                      </label>
                    ))}
                  </div>
                )}
                {user && !addressFormOpen && (
                  <button type="button" className="btn-secondary mt-2 w-full" onClick={() => setAddressFormOpen(true)}>
                    {t('checkout.newAddress')}
                  </button>
                )}
                {user && addressFormOpen && (
                  <AddressForm onSubmit={saveAddress} onCancel={addresses.length ? () => setAddressFormOpen(false) : undefined} submitLabel={t('checkout.saveAddress')} error={addressError} />
                )}
                {user && addresses.length === 0 && !addressFormOpen && <p className="mt-2 text-sm text-ink-500">{t('checkout.addressRequired')}</p>}
                {shippingErrors.length > 0 && (
                  <Notice kind="warning" className="mt-3">
                    {shippingErrors.join(' ')} {pickupInfo && t('checkout.suggestPickup')}
                  </Notice>
                )}
              </div>
            )}
          </section>

          <section className="card p-4">
            <h2 className="mb-3 text-lg font-bold">{t('checkout.coupon')}</h2>
            {couponCode ? (
              <div className="flex items-center justify-between rounded-xl bg-emerald-50 p-3 text-sm text-emerald-900">
                <span className="font-semibold">{t('checkout.couponApplied', { code: couponCode })}</span>
                <button type="button" className="min-h-touch underline" onClick={() => { setCouponCode(''); setCouponInput(''); setCouponError(null) }}>
                  {t('checkout.couponRemove')}
                </button>
              </div>
            ) : (
              <div className="flex gap-2">
                <input className="input uppercase" placeholder={t('checkout.couponPlaceholder')} value={couponInput} onChange={(e) => setCouponInput(e.target.value)} autoCapitalize="characters" />
                <button type="button" className="btn-secondary" onClick={applyCoupon} disabled={!couponInput.trim()}>
                  {t('checkout.apply')}
                </button>
              </div>
            )}
            {couponError && <p className="mt-2 text-sm text-red-700">{couponError}</p>}
            {myCoupons.length > 0 && !couponCode && (
              <div className="mt-3">
                <p className="mb-2 text-sm font-semibold">{t('checkout.suggestedCoupons')}</p>
                <ul className="space-y-2">
                  {myCoupons.map((c) => (
                    <li key={c.code} className="flex items-center justify-between rounded-xl border border-dashed border-brand-500 bg-brand-50 p-3 text-sm">
                      <span>
                        <span className="block font-mono font-bold">{c.code}</span>
                        <span className="text-ink-700">
                          {t('checkout.couponValue', { value: c.discount_type === 'percentage' ? `${c.discount_value}%` : formatMoney(c.discount_value) })}
                          {c.valid_until && ` · ${t('checkout.couponUntil', { date: formatDate(c.valid_until, locale) })}`}
                        </span>
                      </span>
                      <button type="button" className="btn-accent text-sm" onClick={() => { setCouponInput(c.code); setCouponCode(c.code) }}>
                        {t('checkout.useCoupon')}
                      </button>
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </section>

          {settings.rush_enabled && (
            <section className="card p-4">
              <label className="flex min-h-touch items-center justify-between gap-3">
                <span>
                  <span className="block font-semibold">{t('checkout.rush')}</span>
                  <span className="block text-sm text-ink-500">{t('checkout.rushNote', { fee: formatMoney(settings.rush_fee_cents) })}</span>
                </span>
                <input type="checkbox" className="h-6 w-6" checked={rush} onChange={(e) => setRush(e.target.checked)} />
              </label>
            </section>
          )}

          <section className="card p-4">
            <label className="block">
              <span className="mb-2 block text-lg font-bold">{t('checkout.notes')} <span className="text-sm font-normal text-ink-500">({t('common.optional')})</span></span>
              <textarea className="input py-2" rows={3} placeholder={t('checkout.notesPlaceholder')} value={notes} onChange={(e) => setNotes(e.target.value)} />
            </label>
          </section>
        </div>

        <aside className="mt-6 space-y-4 lg:mt-0">
          <section className="card p-4">
            <h2 className="mb-3 text-lg font-bold">{t('checkout.summary')}</h2>
            <ul className="mb-3 space-y-2">
              {cart.items.map((item) => {
                const thumb = cartItemThumb(item)
                return (
                  <li key={item.id} className="flex items-center gap-2 text-sm">
                    <div className="h-12 w-10 shrink-0 overflow-hidden rounded bg-ink-100">{thumb && <img src={thumb} alt="" loading="lazy" className="h-full w-full object-cover" />}</div>
                    <span className="min-w-0 flex-1 truncate">
                      {item.quantity} × {item.catalog_item ? item.catalog_item.title : item.template.name} ({item.size.label})
                    </span>
                    <Money cents={item.line_total_cents} />
                  </li>
                )
              })}
            </ul>
            <Link to="/cart" className="mb-3 inline-flex min-h-touch items-center text-sm underline">
              {t('common.edit')}
            </Link>
            <dl className="space-y-1 text-sm">
              <Row label={t('checkout.subtotal')} value={quote?.subtotal_cents ?? cart.subtotal_cents} />
              {quote && quote.discount_cents > 0 && <Row label={t('checkout.discount')} value={-quote.discount_cents} />}
              {quote && quote.rush && <Row label={t('checkout.rushFee')} value={quote.rush_fee_cents} />}
              <Row label={t('checkout.shippingFee')} value={quote?.shipping_fee_cents ?? 0} free />
              <div className="flex justify-between border-t border-ink-100 pt-2 text-base font-bold">
                <dt>{t('checkout.total')}</dt>
                <dd className="flex items-center gap-2">
                  {quoting && <Spinner className="h-4 w-4" />}
                  <Money cents={quote?.total_cents ?? cart.subtotal_cents} />
                </dd>
              </div>
            </dl>
            <p className="mt-3 text-xs text-ink-500">{quote?.requires_moderation ? t('checkout.moderationNote') : t('checkout.paymentNote')}</p>
            {method === 'pickup' && settings.pickup_address && <p className="mt-2 text-xs text-ink-500">{t('checkout.pickupAt', { address: settings.pickup_address })}</p>}
            {method === 'courier' && selectedAddress && <p className="mt-2 text-xs text-ink-500">{selectedAddress.one_line}</p>}
            {placeError && <ErrorBox message={placeError} className="mt-3" />}
            <button type="button" className="btn-primary mt-4 hidden w-full lg:flex" disabled={!canPlace} onClick={placeOrder}>
              {placing ? t('checkout.placing') : t('checkout.placeOrder')}
            </button>
          </section>
        </aside>
      </div>

      <div className="sticky-action border-t border-ink-100 bg-white/95 px-4 py-2 backdrop-blur lg:hidden">
        <div className="flex items-center gap-3">
          <div className="flex-1 leading-tight">
            <p className="text-lg font-bold"><Money cents={quote?.total_cents ?? cart.subtotal_cents} /></p>
            <p className="text-xs text-ink-500">{t('checkout.total')}</p>
          </div>
          <button type="button" className="btn-primary flex-1" disabled={!canPlace} onClick={placeOrder}>
            {placing ? t('checkout.placing') : !user ? t('checkout.loginToContinue') : t('checkout.placeOrder')}
          </button>
        </div>
      </div>
    </div>
  )
}

function Row({ label, value, free }: { label: string; value: number; free?: boolean }) {
  const { t } = useTranslation()
  return (
    <div className="flex justify-between">
      <dt className="text-ink-700">{label}</dt>
      <dd>{free && value === 0 ? t('common.free') : <Money cents={value} />}</dd>
    </div>
  )
}
