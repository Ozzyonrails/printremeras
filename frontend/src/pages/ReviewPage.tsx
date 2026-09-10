import { useEffect, useRef, useState, type ChangeEvent } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { api } from '../api/client'
import type { OrderFull } from '../api/types'
import { useSession } from '../store/session'
import { uploadImageFile, UploadError } from '../lib/upload'
import { ErrorBox, Notice, PageLoading, ProgressBar, Stars } from '../components/ui'

interface Photo {
  id: number
  preview: string
  signedId: string | null
  progress: number
  error: string | null
}

export function ReviewPage() {
  const { number = '' } = useParams()
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { settings, errorMessage, requireLogin, user } = useSession()
  const [order, setOrder] = useState<OrderFull | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [rating, setRating] = useState(0)
  const [body, setBody] = useState('')
  const [photos, setPhotos] = useState<Photo[]>([])
  const [submitting, setSubmitting] = useState(false)
  const [submitError, setSubmitError] = useState<string | null>(null)
  const [done, setDone] = useState(false)
  const cameraInput = useRef<HTMLInputElement>(null)
  const fileInput = useRef<HTMLInputElement>(null)
  const nextId = useRef(0)
  const maxPhotos = settings?.review_max_photos ?? 5

  useEffect(() => {
    if (!user) {
      void requireLogin().then((ok) => ok || navigate('/orders'))
      return
    }
    api.order(number).then((r) => setOrder(r.order)).catch((e) => setError(errorMessage(e)))
  }, [number, user, requireLogin, navigate, errorMessage])

  const addFiles = (e: ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files || [])
    e.target.value = ''
    for (const file of files.slice(0, maxPhotos - photos.length)) {
      const id = ++nextId.current
      const preview = URL.createObjectURL(file)
      setPhotos((p) => [...p, { id, preview, signedId: null, progress: 0, error: null }])
      uploadImageFile(file, { maxBytes: settings?.max_upload_bytes, onProgress: (f) => setPhotos((p) => p.map((x) => (x.id === id ? { ...x, progress: f } : x))) })
        .then(({ signedId }) => setPhotos((p) => p.map((x) => (x.id === id ? { ...x, signedId, progress: 1 } : x))))
        .catch((err) => {
          const msg =
            err instanceof UploadError
              ? err.code === 'type'
                ? t('editor.fileType')
                : err.code === 'size'
                  ? t('editor.fileTooLarge', { mb: Math.round((settings?.max_upload_bytes ?? 20971520) / 1048576) })
                  : t('editor.uploadFailed')
              : errorMessage(err)
          setPhotos((p) => p.map((x) => (x.id === id ? { ...x, error: msg } : x)))
        })
    }
  }

  const removePhoto = (id: number) => setPhotos((p) => p.filter((x) => x.id !== id))

  const uploaded = photos.filter((p) => p.signedId)
  const pending = photos.some((p) => !p.signedId && !p.error)
  const canSubmit = rating > 0 && uploaded.length > 0 && !pending && !submitting

  const submit = async () => {
    if (rating === 0) return setSubmitError(t('review.ratingRequired'))
    if (uploaded.length === 0) return setSubmitError(t('review.photoRequired'))
    setSubmitting(true)
    setSubmitError(null)
    try {
      await api.submitReview(number, { rating, body: body.trim() || undefined, photos: uploaded.map((p) => p.signedId!) })
      setDone(true)
    } catch (e) {
      setSubmitError(errorMessage(e))
    } finally {
      setSubmitting(false)
    }
  }

  if (error) return <div className="container-page py-6"><ErrorBox message={error} /></div>
  if (!order) return <PageLoading />

  if (done) {
    return (
      <div className="container-page py-10 text-center">
        <p className="text-5xl">🎉</p>
        <h1 className="mt-3 text-2xl font-bold">{t('review.success')}</h1>
        <p className="mt-2 text-ink-500">{t('review.successBody')}</p>
        <Link to={`/orders/${number}`} className="btn-primary mt-6">
          {t('review.backToOrder')}
        </Link>
      </div>
    )
  }

  const allowed = order.can_review || (order.review?.status === 'rejected' && order.review.can_resubmit)

  return (
    <div className="container-page py-6 pb-32">
      <Link to={`/orders/${number}`} className="mb-3 inline-flex min-h-touch items-center text-sm text-ink-700 underline">
        ← {t('review.backToOrder')}
      </Link>
      <h1 className="text-2xl font-bold">{t('review.title')}</h1>
      <p className="mt-1 text-ink-500">{t('review.subtitle', { percent: settings?.review_reward_percent ?? 25 })}</p>
      {!allowed && <Notice kind="warning" className="mt-4">{t('review.notAllowed')}</Notice>}

      <section className="mt-6">
        <p className="mb-2 font-semibold">{t('review.photos', { count: photos.length, max: maxPhotos })}</p>
        <input ref={cameraInput} type="file" accept="image/*" capture="environment" className="hidden" onChange={addFiles} />
        <input ref={fileInput} type="file" accept="image/*" multiple className="hidden" onChange={addFiles} />
        <div className="grid grid-cols-3 gap-2">
          {photos.map((p) => (
            <div key={p.id} className="relative aspect-[3/4] overflow-hidden rounded-xl bg-ink-100">
              <img src={p.preview} alt="" className="h-full w-full object-cover" />
              {!p.signedId && !p.error && (
                <div className="absolute inset-x-2 bottom-2">
                  <ProgressBar value={p.progress} />
                </div>
              )}
              {p.error && <p className="absolute inset-x-0 bottom-0 bg-red-600/90 p-1 text-[10px] text-white">{p.error}</p>}
              <button type="button" className="absolute right-1 top-1 flex h-9 w-9 items-center justify-center rounded-full bg-white/90 text-sm shadow" aria-label={t('review.removePhoto')} onClick={() => removePhoto(p.id)}>
                ✕
              </button>
            </div>
          ))}
          {photos.length < maxPhotos && (
            <>
              <button type="button" className="flex aspect-[3/4] flex-col items-center justify-center gap-1 rounded-xl border-2 border-dashed border-ink-300 text-sm font-semibold" onClick={() => cameraInput.current?.click()}>
                <span className="text-2xl" aria-hidden="true">📷</span>
                {t('review.takePhoto')}
              </button>
              <button type="button" className="flex aspect-[3/4] flex-col items-center justify-center gap-1 rounded-xl border-2 border-dashed border-ink-300 text-sm font-semibold" onClick={() => fileInput.current?.click()}>
                <span className="text-2xl" aria-hidden="true">🖼️</span>
                {t('review.addPhoto')}
              </button>
            </>
          )}
        </div>
      </section>

      <section className="mt-6">
        <p className="mb-2 font-semibold">{t('review.rating')}</p>
        <Stars value={rating} onChange={setRating} size="lg" />
      </section>

      <section className="mt-6">
        <label className="block">
          <span className="mb-2 block font-semibold">
            {t('review.body')} <span className="text-sm font-normal text-ink-500">({t('common.optional')})</span>
          </span>
          <textarea className="input py-2" rows={4} placeholder={t('review.bodyPlaceholder')} value={body} onChange={(e) => setBody(e.target.value)} />
        </label>
      </section>

      {submitError && <ErrorBox message={submitError} className="mt-4" />}

      <div className="sticky-action border-t border-ink-100 bg-white/95 px-4 py-2 backdrop-blur sm:static sm:mt-6 sm:border-0 sm:bg-transparent sm:px-0">
        <button type="button" className="btn-primary w-full" disabled={!canSubmit || !allowed} onClick={submit}>
          {submitting ? t('review.submitting') : pending ? t('review.uploading') : t('review.submit')}
        </button>
      </div>
    </div>
  )
}
