import { useCallback, useEffect, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { api, ApiError } from '../api/client'
import type { PlacementInput, Review, TemplateFull } from '../api/types'
import { useSession } from '../store/session'
import { DesignEditor } from '../editor/DesignEditor'
import { useDesignLibrary } from '../editor/useDesignLibrary'
import { ErrorBox, PageLoading, Sheet } from '../components/ui'
import { ReviewGrid } from '../components/ReviewGrid'

export function TemplatePage() {
  const { slug = '' } = useParams()
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { settings, errorMessage, setCartQuantity, locale } = useSession()
  const library = useDesignLibrary()
  const [template, setTemplate] = useState<TemplateFull | null>(null)
  const [reviews, setReviews] = useState<Review[]>([])
  const [error, setError] = useState<string | null>(null)
  const [sizeId, setSizeId] = useState<number | null>(null)
  const [quantity, setQuantity] = useState(1)
  const [submitting, setSubmitting] = useState(false)
  const [submitError, setSubmitError] = useState<string | null>(null)
  const [added, setAdded] = useState(false)

  const load = useCallback(() => {
    setError(null)
    api
      .template(slug)
      .then((r) => {
        setTemplate(r.template)
        setReviews(r.reviews)
        const first = r.template.sizes.find((s) => s.available)
        setSizeId((cur) => cur ?? first?.id ?? null)
      })
      .catch((e) => setError(errorMessage(e)))
  }, [slug, errorMessage])
  useEffect(load, [load])

  const submit = async (placements: PlacementInput[]) => {
    if (!template || !sizeId) return
    setSubmitting(true)
    setSubmitError(null)
    try {
      // Low DPI now comes back as `warnings` with valid:true — the editor already shows the
      // amber notice, so nothing here blocks. Real errors arrive as a 422 (ApiError below).
      const check = await api.validatePlacement(template.id, placements)
      if (!check.valid) {
        setSubmitError((check.errors ?? (check.error ? [check.error] : [])).join(' ') || t('common.unknownError'))
        return
      }
      const { cart } = await api.addCartItem({ template_id: template.id, template_size_id: sizeId, quantity, placements })
      setCartQuantity(cart.total_quantity)
      setAdded(true)
    } catch (e) {
      setSubmitError(e instanceof ApiError ? e.errors.join(' ') : errorMessage(e))
    } finally {
      setSubmitting(false)
    }
  }

  if (error) return <div className="container-page py-6"><ErrorBox message={error} onRetry={load} /></div>
  if (!template) return <PageLoading />

  return (
    <div className="container-page py-4">
      <div className="mb-3">
        <h1 className="text-xl font-bold sm:text-2xl">{template.name}</h1>
        <p className="flex items-center gap-1.5 text-sm text-ink-500">
          {template.color_hex && <span className="inline-block h-3 w-3 rounded-full ring-1 ring-ink-300" style={{ background: template.color_hex }} />}
          {template.color_name}
          {template.description && <span> · {template.description}</span>}
        </p>
      </div>
      <DesignEditor
        template={template}
        mode="customer"
        designs={library.designs}
        onUpload={library.upload}
        onDeleteDesign={library.remove}
        maxUploadBytes={settings?.max_upload_bytes}
        minUploadPx={settings?.min_upload_px}
        enforceMinDpi={settings?.enforce_min_dpi ?? false}
        enforceMinUploadPx={settings?.enforce_min_upload_px ?? false}
        errorMessage={errorMessage}
        locale={locale}
        sizeId={sizeId}
        onSizeChange={setSizeId}
        quantity={quantity}
        onQuantityChange={setQuantity}
        submitLabel={t('editor.addToCart')}
        submitting={submitting}
        submitError={submitError}
        onSubmit={submit}
      />
      <section className="mt-10">
        <h2 className="mb-3 text-lg font-bold">{t('templates.reviewsTitle')}</h2>
        <ReviewGrid reviews={reviews} emptyText={t('templates.noReviews')} />
      </section>
      <Sheet open={added} onClose={() => setAdded(false)} title={t('editor.added')}>
        <div className="flex flex-col gap-3">
          <button type="button" className="btn-primary w-full" onClick={() => navigate('/cart')}>
            {t('editor.viewCart')}
          </button>
          <Link to="/catalog" className="btn-secondary w-full" onClick={() => setAdded(false)}>
            {t('editor.continueShopping')}
          </Link>
        </div>
      </Sheet>
    </div>
  )
}
