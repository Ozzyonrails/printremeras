import { useCallback, useEffect, useRef, useState } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { api } from '../api/client'
import type { OrderFull, Payment } from '../api/types'
import { useSession } from '../store/session'
import { formatDate, formatDateTime, formatMoney } from '../lib/money'
import { PIPELINE_COURIER, PIPELINE_PICKUP, isExceptionStatus } from '../lib/statuses'
import { ErrorBox, Money, Notice, PageLoading, Sheet, Spinner } from '../components/ui'
import { StatusPill } from './OrdersPage'

export function OrderPage() {
  const { number = '' } = useParams()
  const { t } = useTranslation()
  const navigate = useNavigate()
  const [params, setParams] = useSearchParams()
  const { user, errorMessage, locale, settings, toast, requireLogin } = useSession()
  const [order, setOrder] = useState<OrderFull | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [paying, setPaying] = useState<'redirect' | 'qr' | null>(null)
  const [qr, setQr] = useState<Payment | null>(null)
  const [payError, setPayError] = useState<string | null>(null)
  const [cancelling, setCancelling] = useState(false)
  const paymentParam = params.get('payment')
  const pollRef = useRef<number | null>(null)

  const load = useCallback(() => {
    setError(null)
    return api
      .order(number)
      .then((r) => setOrder(r.order))
      .catch((e) => setError(errorMessage(e)))
  }, [number, errorMessage])

  useEffect(() => {
    if (user) void load()
    else void requireLogin().then((ok) => ok || navigate('/orders'))
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user, load])

  // Poll while the QR sheet is open (every 3 s)
  useEffect(() => {
    if (!qr) return
    const tick = async () => {
      try {
        const s = await api.paymentStatus(number)
        if (s.order_status !== 'awaiting_payment' || s.payment_status === 'approved') {
          setQr(null)
          toast(t('order.paymentSuccess'), 'success')
          void load()
        } else if (s.payment_status === 'rejected') {
          setQr(null)
          setPayError(t('order.paymentFailure'))
        }
      } catch {
        /* keep polling */
      }
    }
    pollRef.current = window.setInterval(tick, 3000)
    return () => {
      if (pollRef.current) window.clearInterval(pollRef.current)
    }
  }, [qr, number, load, toast, t])

  const startPayment = async (flow: 'redirect' | 'qr') => {
    setPaying(flow)
    setPayError(null)
    try {
      const { payment } = await api.startPayment(number, flow)
      if (flow === 'redirect') {
        if (payment.checkout_url) {
          window.location.assign(payment.checkout_url)
          return
        }
        setPayError(t('common.unknownError'))
      } else {
        setQr(payment)
      }
    } catch (e) {
      setPayError(errorMessage(e))
    } finally {
      setPaying(null)
    }
  }

  const cancel = async () => {
    if (!window.confirm(t('order.cancelConfirm'))) return
    setCancelling(true)
    try {
      const { order } = await api.cancelOrder(number)
      setOrder(order)
      toast(t('order.cancelled'), 'success')
    } catch (e) {
      toast(errorMessage(e), 'error')
    } finally {
      setCancelling(false)
    }
  }

  if (error) return <div className="container-page py-6"><ErrorBox message={error} onRetry={() => void load()} /></div>
  if (!order) return <PageLoading />

  const pipeline = order.shipping_method === 'courier' ? PIPELINE_COURIER : PIPELINE_PICKUP
  const reached = new Set(order.history.map((h) => h.to))
  reached.add(order.status)
  const exception = isExceptionStatus(order.status)
  const currentIdx = pipeline.indexOf(order.status)
  const addr = order.shipping_address

  return (
    <div className="container-page py-6">
      <Link to="/orders" className="mb-3 inline-flex min-h-touch items-center text-sm text-ink-700 underline">
        ← {t('order.backToOrders')}
      </Link>
      <div className="mb-4 flex items-start justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">{t('order.title', { number: order.number })}</h1>
          <p className="text-sm text-ink-500">{t('orders.placedAt', { date: formatDateTime(order.placed_at, locale) })}</p>
        </div>
        <StatusPill status={order.status} />
      </div>

      {paymentParam === 'success' && <Notice kind="success" className="mb-4">{t('order.paymentSuccess')}</Notice>}
      {paymentParam === 'failure' && <Notice kind="error" className="mb-4">{t('order.paymentFailure')}</Notice>}
      {paymentParam === 'pending' && <Notice kind="warning" className="mb-4">{t('order.paymentPending')}</Notice>}
      {paymentParam && (
        <button type="button" className="mb-4 -mt-2 text-xs text-ink-500 underline" onClick={() => setParams({})}>
          {t('common.close')}
        </button>
      )}

      {order.status === 'pending_approval' && <Notice className="mb-4">{t('order.awaitingApproval')}</Notice>}
      {/* Low-resolution artwork is never a problem for the customer: we say what we do about it. */}
      {order.low_quality_artwork && !exception && currentIdx >= 0 && (
        <Notice kind="warning" className="mb-4">
          {t('order.lowQualityArtwork')}
        </Notice>
      )}
      {order.status === 'rejected' && (
        <Notice kind="error" className="mb-4">
          {t('order.rejectedNote')} {order.rejection_reason && t('order.reason', { reason: order.rejection_reason })}
        </Notice>
      )}
      {order.status === 'problem' && order.problem_note && <Notice kind="warning" className="mb-4">{t('order.problemNote', { note: order.problem_note })}</Notice>}

      <div className="lg:grid lg:grid-cols-[1fr_360px] lg:gap-8">
        <div className="space-y-6">
          {/* Payment */}
          {order.can_pay && (
            <section className="card border-amber-300 bg-amber-50 p-4">
              <h2 className="text-lg font-bold">{t('order.payTitle')}</h2>
              <p className="mb-3 text-sm text-ink-700">
                {t('order.total')}: <Money cents={order.total_cents} className="font-bold" />
              </p>
              <div className="flex flex-col gap-2 sm:flex-row">
                <button type="button" className="btn-primary flex-1" disabled={paying !== null} onClick={() => startPayment('redirect')}>
                  {paying === 'redirect' ? <Spinner className="border-white/40 border-t-white" /> : t('order.payRedirect')}
                </button>
                <button type="button" className="btn-outline flex-1" disabled={paying !== null} onClick={() => startPayment('qr')}>
                  {paying === 'qr' ? <Spinner /> : t('order.payQr')}
                </button>
              </div>
              {payError && <ErrorBox message={payError} className="mt-3" />}
            </section>
          )}
          {order.payment && !order.can_pay && (
            <section className="card p-4 text-sm">
              <h2 className="mb-1 text-lg font-bold">{t('order.payment')}</h2>
              {order.paid_at ? <p>{t('order.paymentApproved', { date: formatDateTime(order.paid_at, locale) })}</p> : <p>{t('order.paymentStatus', { status: t(`order.paymentStatuses.${order.payment.status}`) })}</p>}
            </section>
          )}

          {/* Review */}
          {order.can_review && !order.review && (
            <section className="card border-emerald-300 bg-emerald-50 p-4">
              <h2 className="text-lg font-bold">{t('order.writeReview', { percent: settings?.review_reward_percent ?? 25 })}</h2>
              <Link to={`/orders/${order.number}/review`} className="btn-primary mt-3 w-full sm:w-auto">
                {t('order.writeReviewCta')}
              </Link>
            </section>
          )}
          {order.review && (
            <section className="card p-4">
              <h2 className="mb-2 text-lg font-bold">{t('order.review')}</h2>
              {order.review.status === 'pending' && <Notice kind="info">{t('order.reviewPending')}</Notice>}
              {order.review.status === 'approved' && <Notice kind="success">{t('order.reviewApproved')}</Notice>}
              {order.review.status === 'rejected' && (
                <Notice kind="warning">
                  {t('order.reviewRejected')} {order.review.rejection_reason && t('order.reason', { reason: order.review.rejection_reason })}
                  {order.review.can_resubmit && (
                    <Link to={`/orders/${order.number}/review`} className="btn-outline mt-3 w-full">
                      {t('order.resubmit')}
                    </Link>
                  )}
                </Notice>
              )}
              {order.review.coupon && (
                <div className="mt-3 rounded-xl border border-dashed border-brand-500 bg-brand-50 p-4 text-center">
                  <p className="text-sm font-semibold">{t('order.coupon')}</p>
                  <p className="my-1 font-mono text-2xl font-bold tracking-wider">{order.review.coupon.code}</p>
                  <p className="text-sm text-ink-700">
                    {order.review.coupon.discount_type === 'percentage' ? `${order.review.coupon.discount_value}%` : formatMoney(order.review.coupon.discount_value)}
                    {order.review.coupon.valid_until && ` · ${t('checkout.couponUntil', { date: formatDate(order.review.coupon.valid_until, locale) })}`}
                  </p>
                  <p className="text-xs text-ink-500">{t('order.couponHint')}</p>
                </div>
              )}
              {order.review.photos.length > 0 && (
                <div className="mt-3 flex gap-2 overflow-x-auto">
                  {order.review.photos.map((p, i) => p.thumb_url && <img key={i} src={p.thumb_url} alt="" loading="lazy" className="h-20 w-16 rounded-lg object-cover" />)}
                </div>
              )}
            </section>
          )}

          {/* Timeline */}
          <section className="card p-4">
            <h2 className="mb-3 text-lg font-bold">{t('order.timeline')}</h2>
            <ol className="relative space-y-3 border-l-2 border-ink-100 pl-5">
              {pipeline.map((s, i) => {
                const done = reached.has(s) && (currentIdx < 0 || i <= currentIdx)
                const current = s === order.status
                const entry = order.history.find((h) => h.to === s)
                return (
                  <li key={s} className="relative">
                    <span className={`absolute -left-[27px] top-0.5 h-4 w-4 rounded-full border-2 ${current ? 'border-brand-500 bg-brand-500' : done ? 'border-ink-900 bg-ink-900' : 'border-ink-300 bg-white'}`} />
                    <p className={`text-sm ${current ? 'font-bold' : done ? 'font-medium' : 'text-ink-500'}`}>{t(`statuses.${s}`)}</p>
                    {entry && <p className="text-xs text-ink-500">{formatDateTime(entry.at, locale)}</p>}
                  </li>
                )
              })}
              {exception && (
                <li className="relative">
                  <span className="absolute -left-[27px] top-0.5 h-4 w-4 rounded-full border-2 border-red-600 bg-red-600" />
                  <p className="text-sm font-bold text-red-700">{t(`statuses.${order.status}`)}</p>
                  {(() => {
                    const entry = [...order.history].reverse().find((h) => h.to === order.status)
                    return entry ? (
                      <p className="text-xs text-ink-500">
                        {formatDateTime(entry.at, locale)}
                        {entry.reason && ` · ${entry.reason}`}
                      </p>
                    ) : null
                  })()}
                </li>
              )}
            </ol>
          </section>

          {/* Items */}
          <section className="card p-4">
            <h2 className="mb-3 text-lg font-bold">{t('order.items')}</h2>
            <ul className="space-y-3">
              {order.items.map((item) => (
                <li key={item.id} className="flex gap-3">
                  <div className="h-20 w-16 shrink-0 overflow-hidden rounded-lg bg-ink-100">{item.preview_url && <img src={item.preview_url} alt="" loading="lazy" className="h-full w-full object-cover" />}</div>
                  <div className="min-w-0 flex-1 text-sm">
                    <p className="font-semibold">{item.title}</p>
                    <p className="text-ink-500">
                      {item.snapshot.color_name && `${item.snapshot.color_name} · `}
                      {item.size_label && t('order.size', { size: item.size_label })} {t('order.quantity', { count: item.quantity })}
                    </p>
                    {item.placements.length > 0 && (
                      <div className="mt-1 flex gap-1">
                        {item.placements.map((p) => (
                          <img key={p.id} src={p.design.thumb_url || p.design.url || ''} alt="" loading="lazy" className="h-8 w-8 rounded border border-ink-100 object-contain" />
                        ))}
                      </div>
                    )}
                  </div>
                  <Money cents={item.line_total_cents} className="text-sm font-semibold" />
                </li>
              ))}
            </ul>
          </section>
        </div>

        <aside className="mt-6 space-y-4 lg:mt-0">
          <section className="card p-4 text-sm">
            <h2 className="mb-2 text-lg font-bold">{t('order.summary')}</h2>
            <dl className="space-y-1">
              <div className="flex justify-between"><dt>{t('order.subtotal')}</dt><dd><Money cents={order.subtotal_cents} /></dd></div>
              {order.discount_cents > 0 && <div className="flex justify-between"><dt>{t('order.discount')} {order.coupon_code && `(${order.coupon_code})`}</dt><dd>−<Money cents={order.discount_cents} /></dd></div>}
              {order.rush_fee_cents > 0 && <div className="flex justify-between"><dt>{t('order.rush')}</dt><dd><Money cents={order.rush_fee_cents} /></dd></div>}
              <div className="flex justify-between"><dt>{t('order.shipping')}</dt><dd>{order.shipping_fee_cents === 0 ? t('common.free') : <Money cents={order.shipping_fee_cents} />}</dd></div>
              <div className="flex justify-between border-t border-ink-100 pt-2 text-base font-bold"><dt>{t('order.total')}</dt><dd><Money cents={order.total_cents} /></dd></div>
            </dl>
          </section>
          <section className="card p-4 text-sm">
            <h2 className="mb-1 font-bold">{order.shipping_method === 'courier' ? t('order.shippingTo') : t('order.pickupAt')}</h2>
            {order.shipping_method === 'courier' && addr ? (
              <p className="text-ink-700">
                {addr.recipient_name && <span className="block font-medium">{String(addr.recipient_name)}</span>}
                {[addr.street, addr.number].filter(Boolean).join(' ')}
                {addr.floor || addr.apartment ? `, ${[addr.floor, addr.apartment].filter(Boolean).join(' ')}` : ''}
                {addr.neighborhood ? `, ${addr.neighborhood}` : ''} {addr.postal_code ? `(${addr.postal_code})` : ''} {addr.city ? String(addr.city) : ''}
                {addr.phone && <span className="block">{String(addr.phone)}</span>}
              </p>
            ) : (
              <p className="text-ink-700">
                {settings?.pickup_address}
                {settings?.pickup_hours && <span className="block text-ink-500">{settings.pickup_hours}</span>}
              </p>
            )}
            {order.customer_notes && (
              <p className="mt-2 text-ink-500">
                <span className="font-medium">{t('order.customerNotes')}:</span> {order.customer_notes}
              </p>
            )}
          </section>
          <Link to="/messages" state={{ orderId: order.id }} className="btn-secondary w-full">
            {t('order.helpCta')}
          </Link>
          {order.can_cancel && (
            <button type="button" className="btn-outline w-full text-red-700" disabled={cancelling} onClick={cancel}>
              {cancelling ? <Spinner /> : t('order.cancel')}
            </button>
          )}
        </aside>
      </div>

      <Sheet open={qr !== null} onClose={() => setQr(null)} title={t('order.qrTitle')}>
        {qr && (
          <div className="flex flex-col items-center gap-3 text-center">
            {qr.qr_svg ? (
              <div className="w-64 max-w-full [&>svg]:h-auto [&>svg]:w-full" dangerouslySetInnerHTML={{ __html: qr.qr_svg }} />
            ) : (
              <p className="text-ink-500">{t('common.unknownError')}</p>
            )}
            <p className="flex items-center gap-2 text-sm text-ink-500">
              <Spinner className="h-4 w-4" /> {t('order.qrWaiting')}
            </p>
            <Money cents={qr.amount_cents} className="text-lg font-bold" />
            {qr.checkout_url && (
              <a href={qr.checkout_url} className="btn-primary w-full">
                {t('order.qrOpenApp')}
              </a>
            )}
            {qr.qr_data && (
              <button
                type="button"
                className="btn-secondary w-full"
                onClick={() => navigator.clipboard?.writeText(qr.qr_data || '').then(() => toast(t('order.qrCopied'), 'success'))}
              >
                {t('order.qrCopy')}
              </button>
            )}
          </div>
        )}
      </Sheet>
    </div>
  )
}
