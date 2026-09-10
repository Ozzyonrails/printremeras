import { useEffect, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { api } from '../api/client'
import type { CatalogItem } from '../api/types'
import { useSession } from '../store/session'
import { ErrorBox, PageLoading, PageTitle } from '../components/ui'
import { CatalogCard } from './HomePage'

export function CatalogPage() {
  const { t } = useTranslation()
  const { errorMessage } = useSession()
  const [params, setParams] = useSearchParams()
  const tag = params.get('tag') || ''
  const [items, setItems] = useState<CatalogItem[] | null>(null)
  const [tags, setTags] = useState<string[]>([])
  const [error, setError] = useState<string | null>(null)

  const load = () => {
    setError(null)
    api
      .catalogItems(tag || undefined)
      .then((r) => {
        setItems(r.catalog_items)
        setTags(r.tags)
      })
      .catch((e) => setError(errorMessage(e)))
  }
  useEffect(load, [tag, errorMessage])

  return (
    <div className="container-page py-6">
      <PageTitle subtitle={t('catalog.subtitle')}>{t('catalog.title')}</PageTitle>
      {tags.length > 0 && (
        <div className="no-scrollbar -mx-4 mb-4 flex gap-2 overflow-x-auto px-4 sm:mx-0 sm:flex-wrap sm:px-0" role="group" aria-label={t('catalog.filter')}>
          <button type="button" className={`chip shrink-0 ${!tag ? 'chip-active' : ''}`} onClick={() => setParams({})} aria-pressed={!tag}>
            {t('catalog.allTags')}
          </button>
          {tags.map((tg) => (
            <button key={tg} type="button" className={`chip shrink-0 ${tag === tg ? 'chip-active' : ''}`} onClick={() => setParams({ tag: tg })} aria-pressed={tag === tg}>
              {tg}
            </button>
          ))}
        </div>
      )}
      {error && <ErrorBox message={error} onRetry={load} />}
      {!error && items === null && <PageLoading />}
      {items && items.length === 0 && <p className="text-ink-500">{t('catalog.empty')}</p>}
      {items && (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
          {items.map((item) => (
            <CatalogCard key={item.id} item={item} />
          ))}
        </div>
      )}
    </div>
  )
}
