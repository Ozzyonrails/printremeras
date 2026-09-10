import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { api } from '../api/client'
import type { CatalogItem, Review, Template } from '../api/types'
import { useSession } from '../store/session'
import { formatMoney } from '../lib/money'
import { ErrorBox, Money, PageLoading } from '../components/ui'
import { ReviewGrid } from '../components/ReviewGrid'

export function TemplateCard({ template }: { template: Template }) {
  const { t } = useTranslation()
  return (
    <Link to={`/templates/${template.slug}`} className="card overflow-hidden active:bg-ink-100">
      <div className="aspect-[4/5] bg-ink-100">
        {template.image_url && <img src={template.image_url} alt={template.name} loading="lazy" className="h-full w-full object-cover" />}
      </div>
      <div className="p-3">
        <p className="font-semibold leading-tight">{template.name}</p>
        <p className="mt-0.5 flex items-center gap-1.5 text-xs text-ink-500">
          {template.color_hex && <span className="inline-block h-3 w-3 rounded-full ring-1 ring-ink-300" style={{ background: template.color_hex }} />}
          {template.color_name}
        </p>
        <p className="mt-1 text-sm font-semibold tabular-nums">{t('templates.from', { price: formatMoney(template.base_price_cents + template.print_price_one_side_cents) })}</p>
      </div>
    </Link>
  )
}

export function CatalogCard({ item }: { item: CatalogItem }) {
  return (
    <Link to={`/catalog/${item.slug}`} className="card overflow-hidden active:bg-ink-100">
      <div className="aspect-[4/5] bg-ink-100">
        {(item.image_url || item.template.image_url) && <img src={item.image_url || item.template.image_url || ''} alt={item.title} loading="lazy" className="h-full w-full object-cover" />}
      </div>
      <div className="p-3">
        <p className="font-semibold leading-tight">{item.title}</p>
        <p className="mt-0.5 text-xs text-ink-500">{item.template.name}</p>
        <Money cents={item.price_cents} className="mt-1 block text-sm font-semibold" />
      </div>
    </Link>
  )
}

export function HomePage() {
  const { t } = useTranslation()
  const { errorMessage } = useSession()
  const [templates, setTemplates] = useState<Template[] | null>(null)
  const [items, setItems] = useState<CatalogItem[]>([])
  const [reviews, setReviews] = useState<Review[]>([])
  const [error, setError] = useState<string | null>(null)

  const load = () => {
    setError(null)
    api.templates().then((r) => setTemplates(r.templates)).catch((e) => setError(errorMessage(e)))
    api.catalogItems().then((r) => setItems(r.catalog_items.slice(0, 8))).catch(() => undefined)
    api.reviews({ page: 1 }).then((r) => setReviews(r.reviews.slice(0, 8))).catch(() => undefined)
  }
  useEffect(load, [errorMessage])

  return (
    <div>
      <section className="bg-ink-900 text-white">
        <div className="container-page py-12 sm:py-20">
          <h1 className="max-w-xl text-3xl font-extrabold leading-tight sm:text-5xl">{t('home.heroTitle')}</h1>
          <p className="mt-3 max-w-xl text-ink-300 sm:text-lg">{t('home.heroSubtitle')}</p>
          <div className="mt-6 flex flex-col gap-3 sm:flex-row">
            <a href="#templates" className="btn-accent">
              {t('home.cta')}
            </a>
            <Link to="/catalog" className="btn-outline border-white/30 bg-transparent text-white">
              {t('home.ctaCatalog')}
            </Link>
          </div>
          <ol className="mt-8 grid grid-cols-3 gap-2 text-xs text-ink-300 sm:text-sm">
            {[t('home.step1'), t('home.step2'), t('home.step3')].map((s, i) => (
              <li key={i} className="flex items-center gap-2">
                <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-brand-500 font-bold text-ink-900">{i + 1}</span>
                {s}
              </li>
            ))}
          </ol>
        </div>
      </section>

      <section id="templates" className="container-page py-8">
        <h2 className="mb-4 text-xl font-bold">{t('home.templatesTitle')}</h2>
        {error && <ErrorBox message={error} onRetry={load} />}
        {!error && templates === null && <PageLoading />}
        {templates && templates.length === 0 && <p className="text-ink-500">{t('home.empty')}</p>}
        {templates && (
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
            {templates.map((tpl) => (
              <TemplateCard key={tpl.id} template={tpl} />
            ))}
          </div>
        )}
      </section>

      {items.length > 0 && (
        <section className="container-page py-8">
          <div className="mb-4 flex items-center justify-between">
            <h2 className="text-xl font-bold">{t('home.catalogTitle')}</h2>
            <Link to="/catalog" className="min-h-touch inline-flex items-center text-sm font-semibold underline">
              {t('common.seeAll')}
            </Link>
          </div>
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
            {items.map((item) => (
              <CatalogCard key={item.id} item={item} />
            ))}
          </div>
        </section>
      )}

      {reviews.length > 0 && (
        <section className="container-page py-8">
          <div className="mb-4 flex items-center justify-between">
            <div>
              <h2 className="text-xl font-bold">{t('home.reviewsTitle')}</h2>
              <p className="text-sm text-ink-500">{t('home.reviewsSubtitle')}</p>
            </div>
            <Link to="/reviews" className="min-h-touch inline-flex items-center text-sm font-semibold underline">
              {t('common.seeAll')}
            </Link>
          </div>
          <ReviewGrid reviews={reviews} />
        </section>
      )}
    </div>
  )
}

export function TemplatesPage() {
  const { t } = useTranslation()
  const { errorMessage } = useSession()
  const [templates, setTemplates] = useState<Template[] | null>(null)
  const [error, setError] = useState<string | null>(null)
  const load = () => {
    setError(null)
    api.templates().then((r) => setTemplates(r.templates)).catch((e) => setError(errorMessage(e)))
  }
  useEffect(load, [errorMessage])
  return (
    <div className="container-page py-6">
      <h1 className="mb-4 text-2xl font-bold">{t('home.templatesTitle')}</h1>
      {error && <ErrorBox message={error} onRetry={load} />}
      {!error && templates === null && <PageLoading />}
      {templates && templates.length === 0 && <p className="text-ink-500">{t('home.empty')}</p>}
      {templates && (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
          {templates.map((tpl) => (
            <TemplateCard key={tpl.id} template={tpl} />
          ))}
        </div>
      )}
    </div>
  )
}
