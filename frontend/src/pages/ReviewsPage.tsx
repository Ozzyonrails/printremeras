import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { api } from '../api/client'
import type { Review } from '../api/types'
import { useSession } from '../store/session'
import { ErrorBox, PageLoading, PageTitle, Spinner } from '../components/ui'
import { ReviewGrid } from '../components/ReviewGrid'

export function ReviewsPage() {
  const { t } = useTranslation()
  const { errorMessage } = useSession()
  const [reviews, setReviews] = useState<Review[] | null>(null)
  const [page, setPage] = useState(1)
  const [hasMore, setHasMore] = useState(true)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    setLoading(true)
    api
      .reviews({ page })
      .then((r) => {
        setReviews((cur) => (page === 1 ? r.reviews : [...(cur || []), ...r.reviews]))
        setHasMore(r.reviews.length === 24)
      })
      .catch((e) => setError(errorMessage(e)))
      .finally(() => setLoading(false))
  }, [page, errorMessage])

  return (
    <div className="container-page py-6">
      <PageTitle subtitle={t('reviews.subtitle')}>{t('reviews.title')}</PageTitle>
      {error && <ErrorBox message={error} onRetry={() => setPage(1)} />}
      {!error && reviews === null && <PageLoading />}
      {reviews && <ReviewGrid reviews={reviews} emptyText={t('reviews.empty')} />}
      {reviews && hasMore && (
        <div className="mt-6 text-center">
          <button type="button" className="btn-secondary" disabled={loading} onClick={() => setPage((p) => p + 1)}>
            {loading ? <Spinner /> : t('reviews.loadMore')}
          </button>
        </div>
      )}
    </div>
  )
}
