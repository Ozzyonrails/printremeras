import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import type { Review } from '../api/types'
import { useSession } from '../store/session'
import { formatDate } from '../lib/money'
import { Sheet, Stars } from './ui'

export function ReviewCard({ review, onOpen }: { review: Review; onOpen?: (r: Review) => void }) {
  const { locale } = useSession()
  const photo = review.photos[0]
  return (
    <article className="card overflow-hidden">
      {photo?.thumb_url && (
        <button type="button" className="block w-full" onClick={() => onOpen?.(review)}>
          <img src={photo.thumb_url} alt="" loading="lazy" className="aspect-[3/4] w-full object-cover" />
        </button>
      )}
      <div className="p-3">
        <div className="flex items-center justify-between gap-2">
          <Stars value={review.rating} size="sm" />
          <span className="text-xs text-ink-500">{formatDate(review.date, locale)}</span>
        </div>
        <p className="mt-1 text-sm font-semibold">{review.first_name}</p>
        {review.body && <p className="mt-1 line-clamp-3 text-sm text-ink-700">{review.body}</p>}
        {review.product && <p className="mt-1 text-xs text-ink-500">{review.product}</p>}
      </div>
    </article>
  )
}

export function ReviewGrid({ reviews, emptyText }: { reviews: Review[]; emptyText?: string }) {
  const { t } = useTranslation()
  const { locale } = useSession()
  const [open, setOpen] = useState<Review | null>(null)
  if (reviews.length === 0) return emptyText ? <p className="text-ink-500">{emptyText}</p> : null
  return (
    <>
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
        {reviews.map((r) => (
          <ReviewCard key={r.id} review={r} onOpen={setOpen} />
        ))}
      </div>
      <Sheet open={open !== null} onClose={() => setOpen(null)} title={open?.first_name} wide>
        {open && (
          <div className="space-y-3">
            <div className="flex items-center gap-3">
              <Stars value={open.rating} />
              <span className="text-sm text-ink-500">{formatDate(open.date, locale)}</span>
            </div>
            {open.body && <p className="text-ink-700">{open.body}</p>}
            {open.product && <p className="text-sm text-ink-500">{t('reviews.product', { product: open.product })}</p>}
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              {open.photos.map((p, i) =>
                p.url ? <img key={i} src={p.url} alt="" className="w-full rounded-xl object-cover" loading="lazy" /> : null,
              )}
            </div>
          </div>
        )}
      </Sheet>
    </>
  )
}
