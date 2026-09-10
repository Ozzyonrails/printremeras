import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { api } from '../api/client'
import type { Order, OrderStatus } from '../api/types'
import { useSession } from '../store/session'
import { formatDate } from '../lib/money'
import { isExceptionStatus } from '../lib/statuses'
import { ErrorBox, Money, PageLoading, PageTitle } from '../components/ui'
import { EmptyState } from '../components/EmptyState'

export function StatusPill({ status }: { status: OrderStatus }) {
  const { t } = useTranslation()
  const tone = isExceptionStatus(status)
    ? 'bg-red-100 text-red-800'
    : status === 'delivered'
      ? 'bg-emerald-100 text-emerald-800'
      : status === 'awaiting_payment'
        ? 'bg-amber-100 text-amber-800'
        : 'bg-ink-100 text-ink-700'
  return <span className={`inline-block rounded-full px-2.5 py-1 text-xs font-semibold ${tone}`}>{t(`statuses.${status}`)}</span>
}

export function OrdersPage() {
  const { t } = useTranslation()
  const { user, errorMessage, locale, requireLogin } = useSession()
  const [orders, setOrders] = useState<Order[] | null>(null)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(() => {
    setError(null)
    api.orders().then((r) => setOrders(r.orders)).catch((e) => setError(errorMessage(e)))
  }, [errorMessage])
  useEffect(() => {
    if (user) load()
  }, [user, load])

  if (!user) {
    return (
      <div className="container-page py-6">
        <PageTitle>{t('orders.title')}</PageTitle>
        <div className="card p-6 text-center">
          <p className="text-ink-500">{t('auth.loginRequired')}</p>
          <button type="button" className="btn-primary mt-4" onClick={() => void requireLogin()}>
            {t('auth.login')}
          </button>
        </div>
      </div>
    )
  }
  if (error) return <div className="container-page py-6"><ErrorBox message={error} onRetry={load} /></div>
  if (!orders) return <PageLoading />

  return (
    <div className="container-page py-6">
      <PageTitle>{t('orders.title')}</PageTitle>
      {orders.length === 0 ? (
        <EmptyState title={t('orders.empty')} cta={t('cart.browse')} to="/" />
      ) : (
        <ul className="space-y-3">
          {orders.map((o) => (
            <li key={o.id}>
              <Link to={`/orders/${o.number}`} className="card flex items-center gap-3 p-3 active:bg-ink-100">
                <div className="h-16 w-14 shrink-0 overflow-hidden rounded-lg bg-ink-100">{o.preview_url && <img src={o.preview_url} alt="" loading="lazy" className="h-full w-full object-cover" />}</div>
                <div className="min-w-0 flex-1">
                  <p className="flex items-center justify-between gap-2">
                    <span className="font-semibold">{o.number}</span>
                    <StatusPill status={o.status} />
                  </p>
                  <p className="text-xs text-ink-500">
                    {t('orders.placedAt', { date: formatDate(o.placed_at, locale) })} · {t('orders.items', { count: o.item_count })}
                  </p>
                  <p className="mt-1 flex items-center justify-between text-sm">
                    <Money cents={o.total_cents} className="font-bold" />
                    {o.can_pay && <span className="font-semibold text-amber-700">{t('orders.payNow')} →</span>}
                    {o.can_review && !o.review_status && <span className="font-semibold text-emerald-700">{t('orders.reviewNow')} →</span>}
                  </p>
                </div>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
