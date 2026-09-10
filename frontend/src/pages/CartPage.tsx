import { useCallback, useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { api } from '../api/client'
import type { Cart, CartItem } from '../api/types'
import { useSession } from '../store/session'
import { formatMoney } from '../lib/money'
import { ErrorBox, Money, PageLoading, PageTitle, Stepper } from '../components/ui'
import { EmptyState } from '../components/EmptyState'

export function cartItemThumb(item: CartItem): string | null {
  if (item.catalog_item?.image_url) return item.catalog_item.image_url
  const front = item.template.print_areas.find((a) => a.side === 'front') || item.template.print_areas[0]
  return front?.mockup_card_url || item.template.image_url
}

export function CartPage() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { errorMessage, setCartQuantity, toast } = useSession()
  const [cart, setCart] = useState<Cart | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [busyId, setBusyId] = useState<number | null>(null)

  const apply = useCallback(
    (c: Cart) => {
      setCart(c)
      setCartQuantity(c.total_quantity)
    },
    [setCartQuantity],
  )

  const load = useCallback(() => {
    setError(null)
    api.cart().then((r) => apply(r.cart)).catch((e) => setError(errorMessage(e)))
  }, [apply, errorMessage])
  useEffect(load, [load])

  const setQuantity = async (item: CartItem, quantity: number) => {
    setBusyId(item.id)
    try {
      const { cart } = await api.updateCartItem(item.id, { quantity })
      apply(cart)
    } catch (e) {
      toast(errorMessage(e), 'error')
    } finally {
      setBusyId(null)
    }
  }

  const remove = async (item: CartItem) => {
    if (!window.confirm(t('cart.removeConfirm'))) return
    setBusyId(item.id)
    try {
      const { cart } = await api.removeCartItem(item.id)
      apply(cart)
    } catch (e) {
      toast(errorMessage(e), 'error')
    } finally {
      setBusyId(null)
    }
  }

  if (error) return <div className="container-page py-6"><ErrorBox message={error} onRetry={load} /></div>
  if (!cart) return <PageLoading />

  return (
    <div className="container-page py-6 pb-32 lg:pb-8">
      <PageTitle>{t('cart.title')}</PageTitle>
      {cart.items.length === 0 ? (
        <EmptyState title={t('cart.empty')} cta={t('cart.browse')} to="/" />
      ) : (
        <div className="lg:grid lg:grid-cols-[1fr_340px] lg:gap-8">
          <ul className="space-y-3">
            {cart.items.map((item) => {
              const thumb = cartItemThumb(item)
              return (
                <li key={item.id} className={`card flex gap-3 p-3 ${busyId === item.id ? 'opacity-60' : ''}`}>
                  <div className="h-24 w-20 shrink-0 overflow-hidden rounded-lg bg-ink-100">{thumb && <img src={thumb} alt="" loading="lazy" className="h-full w-full object-cover" />}</div>
                  <div className="min-w-0 flex-1">
                    <p className="font-semibold leading-tight">{item.catalog_item ? item.catalog_item.title : item.template.name}</p>
                    <p className="text-xs text-ink-500">
                      {item.catalog_item ? t('cart.catalogItem') : t('cart.custom')} · {t('cart.size', { size: item.size.label })} · {t('cart.sides', { count: item.sides_count })}
                    </p>
                    {item.placements.length > 0 && (
                      <div className="mt-1 flex gap-1">
                        {item.placements.map((p) => (
                          <img key={p.id} src={p.design.thumb_url || p.design.url || ''} alt="" loading="lazy" className="h-8 w-8 rounded border border-ink-100 object-contain" />
                        ))}
                      </div>
                    )}
                    <p className="mt-1 text-sm text-ink-700 tabular-nums">{t('cart.unit', { price: formatMoney(item.unit_price_cents) })}</p>
                    <div className="mt-2 flex flex-wrap items-center justify-between gap-2">
                      <Stepper value={item.quantity} onChange={(q) => void setQuantity(item, q)} label={t('cart.quantity')} />
                      <Money cents={item.line_total_cents} className="font-bold" />
                    </div>
                    <div className="mt-2 flex gap-3 text-sm">
                      {item.custom && (
                        <Link to={`/cart/items/${item.id}/edit`} className="min-h-touch inline-flex items-center font-semibold underline">
                          {t('cart.edit')}
                        </Link>
                      )}
                      <button type="button" onClick={() => void remove(item)} className="min-h-touch inline-flex items-center text-red-700 underline">
                        {t('common.remove')}
                      </button>
                    </div>
                  </div>
                </li>
              )
            })}
          </ul>
          <aside className="mt-6 lg:mt-0">
            <div className="card p-4">
              <div className="flex items-center justify-between text-lg font-bold">
                <span>{t('cart.subtotal')}</span>
                <Money cents={cart.subtotal_cents} />
              </div>
              <p className="mt-1 text-xs text-ink-500">{t('cart.items', { count: cart.total_quantity })} · {t('cart.shippingNote')}</p>
              <button type="button" className="btn-primary mt-4 hidden w-full lg:flex" onClick={() => navigate('/checkout')}>
                {t('cart.checkout')}
              </button>
              <Link to="/catalog" className="btn-secondary mt-2 hidden w-full lg:flex">
                {t('cart.continueShopping')}
              </Link>
            </div>
          </aside>
          <div className="sticky-action border-t border-ink-100 bg-white/95 px-4 py-2 backdrop-blur lg:hidden">
            <div className="flex items-center gap-3">
              <div className="flex-1 leading-tight">
                <p className="text-lg font-bold"><Money cents={cart.subtotal_cents} /></p>
                <p className="text-xs text-ink-500">{t('cart.items', { count: cart.total_quantity })}</p>
              </div>
              <button type="button" className="btn-primary flex-1" onClick={() => navigate('/checkout')}>
                {t('cart.checkout')}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
