import { useCallback, useEffect, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { api } from '../api/client'
import type { CatalogItemFull, Review } from '../api/types'
import { useSession } from '../store/session'
import { formatDate } from '../lib/money'
import { ErrorBox, Money, PageLoading, Sheet, Stepper } from '../components/ui'
import { ReviewGrid } from '../components/ReviewGrid'

export function CatalogItemPage() {
  const { slug = '' } = useParams()
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { errorMessage, setCartQuantity, locale, toast } = useSession()
  const [item, setItem] = useState<CatalogItemFull | null>(null)
  const [reviews, setReviews] = useState<Review[]>([])
  const [error, setError] = useState<string | null>(null)
  const [sizeId, setSizeId] = useState<number | null>(null)
  const [quantity, setQuantity] = useState(1)
  const [busy, setBusy] = useState<'add' | 'customise' | null>(null)
  const [actionError, setActionError] = useState<string | null>(null)
  const [added, setAdded] = useState(false)
  const [photo, setPhoto] = useState(0)

  const load = useCallback(() => {
    setError(null)
    api
      .catalogItem(slug)
      .then((r) => {
        setItem(r.catalog_item)
        setReviews(r.reviews)
        setSizeId((cur) => cur ?? r.catalog_item.template.sizes.find((s) => s.available)?.id ?? null)
      })
      .catch((e) => setError(errorMessage(e)))
  }, [slug, errorMessage])
  useEffect(load, [load])

  const addToCart = async () => {
    if (!item || !sizeId) return
    setBusy('add')
    setActionError(null)
    try {
      const { cart } = await api.addCartItem({
        template_id: item.template.id,
        template_size_id: sizeId,
        quantity,
        catalog_item_id: item.id,
        placements: item.placements.map((p) => ({ design_id: p.design_id, print_area_id: p.print_area_id, x: p.x, y: p.y, scale: p.scale, rotation: p.rotation })),
      })
      setCartQuantity(cart.total_quantity)
      setAdded(true)
    } catch (e) {
      setActionError(errorMessage(e))
    } finally {
      setBusy(null)
    }
  }

  const customise = async () => {
    if (!item) return
    setBusy('customise')
    setActionError(null)
    try {
      const { cart_item } = await api.customizeCatalogItem(item.slug, sizeId ?? undefined)
      const { cart } = await api.cart()
      setCartQuantity(cart.total_quantity)
      toast(t('catalog.customising'))
      navigate(`/cart/items/${cart_item.id}/edit`)
    } catch (e) {
      setActionError(errorMessage(e))
      setBusy(null)
    }
  }

  if (error) return <div className="container-page py-6"><ErrorBox message={error} onRetry={load} /></div>
  if (!item) return <PageLoading />

  const photos = [item.large_image_url || item.image_url, ...item.template.print_areas.map((a) => a.mockup_card_url)].filter((u): u is string => !!u)
  const size = item.template.sizes.find((s) => s.id === sizeId)

  return (
    <div className="container-page py-4 pb-32 lg:pb-8">
      <div className="lg:grid lg:grid-cols-2 lg:gap-8">
        <div>
          <div className="-mx-4 aspect-[4/5] bg-ink-100 sm:mx-0 sm:rounded-2xl sm:overflow-hidden">
            {photos[photo] && <img src={photos[photo]} alt={item.title} className="h-full w-full object-cover" />}
          </div>
          {photos.length > 1 && (
            <div className="no-scrollbar mt-2 flex gap-2 overflow-x-auto">
              {photos.map((p, i) => (
                <button key={i} type="button" onClick={() => setPhoto(i)} className={`h-16 w-16 shrink-0 overflow-hidden rounded-lg border-2 ${i === photo ? 'border-ink-900' : 'border-transparent'}`}>
                  <img src={p} alt="" loading="lazy" className="h-full w-full object-cover" />
                </button>
              ))}
            </div>
          )}
        </div>
        <div className="mt-4 lg:mt-0">
          <h1 className="text-2xl font-bold">{item.title}</h1>
          <p className="mt-1 text-sm text-ink-500">
            {t('catalog.garment')}: {item.template.name} · {item.template.color_name} · {t('catalog.sidesPrinted', { count: item.sides_count })}
          </p>
          <p className="mt-3 text-2xl font-bold">
            <Money cents={item.price_cents} /> <span className="text-sm font-normal text-ink-500">{t('catalog.priceNote')}</span>
          </p>
          {item.description && <p className="mt-3 whitespace-pre-line text-ink-700">{item.description}</p>}
          {item.tags.length > 0 && (
            <div className="mt-3 flex flex-wrap gap-2">
              {item.tags.map((tg) => (
                <Link key={tg} to={`/catalog?tag=${encodeURIComponent(tg)}`} className="chip">
                  #{tg}
                </Link>
              ))}
            </div>
          )}

          <div className="mt-6">
            <p className="mb-2 text-sm font-semibold">{t('sizes.label')}</p>
            <div className="flex flex-wrap gap-2">
              {item.template.sizes.map((s) => {
                const title = s.available ? s.label : s.restock_at ? t('sizes.backOn', { date: formatDate(s.restock_at, locale, { day: 'numeric', month: 'long' }) }) : t('sizes.outOfStock')
                return (
                  <button
                    key={s.id}
                    type="button"
                    disabled={!s.available}
                    title={title}
                    aria-label={title}
                    aria-pressed={s.id === sizeId}
                    onClick={() => setSizeId(s.id)}
                    className={`chip min-h-touch min-w-touch justify-center ${s.id === sizeId ? 'chip-active' : ''} ${!s.available ? 'line-through opacity-50' : ''}`}
                  >
                    {s.label}
                  </button>
                )
              })}
            </div>
            {item.template.sizes.some((s) => !s.available) && (
              <ul className="mt-2 space-y-0.5 text-xs text-ink-500">
                {item.template.sizes
                  .filter((s) => !s.available)
                  .map((s) => (
                    <li key={s.id}>
                      {s.label}: {s.restock_at ? t('sizes.backOn', { date: formatDate(s.restock_at, locale, { day: 'numeric', month: 'long' }) }) : t('sizes.outOfStock')}
                    </li>
                  ))}
              </ul>
            )}
          </div>
          <div className="mt-4 flex items-center justify-between">
            <span className="text-sm font-semibold">{t('editor.quantity')}</span>
            <Stepper value={quantity} onChange={setQuantity} label={t('editor.quantity')} />
          </div>
          {actionError && <ErrorBox message={actionError} className="mt-4" />}
          <div className="mt-6 hidden gap-3 lg:flex">
            <button type="button" className="btn-primary flex-1" disabled={!size?.available || busy !== null} onClick={addToCart}>
              {t('catalog.addToCart')}
            </button>
            <button type="button" className="btn-outline flex-1" disabled={busy !== null} onClick={customise}>
              {t('catalog.customise')}
            </button>
          </div>
        </div>
      </div>

      <section className="mt-10">
        <h2 className="mb-3 text-lg font-bold">{t('catalog.reviewsTitle')}</h2>
        <ReviewGrid reviews={reviews} emptyText={t('catalog.noReviews')} />
      </section>

      <div className="sticky-action border-t border-ink-100 bg-white/95 px-4 py-2 backdrop-blur lg:hidden">
        <div className="flex items-center gap-2">
          <div className="min-w-0 flex-1 leading-tight">
            <p className="text-lg font-bold tabular-nums"><Money cents={item.price_cents * quantity} /></p>
            <p className="truncate text-xs text-ink-500">{size ? `${t('sizes.label')} ${size.label}` : t('sizes.choose')} · {quantity}</p>
          </div>
          <button type="button" className="btn-outline px-3 text-sm" disabled={busy !== null} onClick={customise}>
            {t('catalog.customise')}
          </button>
          <button type="button" className="btn-primary px-3" disabled={!size?.available || busy !== null} onClick={addToCart}>
            {t('catalog.addToCart')}
          </button>
        </div>
      </div>

      <Sheet open={added} onClose={() => setAdded(false)} title={t('catalog.added')}>
        <div className="flex flex-col gap-3">
          <button type="button" className="btn-primary w-full" onClick={() => navigate('/cart')}>
            {t('editor.viewCart')}
          </button>
          <button type="button" className="btn-secondary w-full" onClick={() => setAdded(false)}>
            {t('editor.continueShopping')}
          </button>
        </div>
      </Sheet>
    </div>
  )
}
