import { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { api, ApiError } from '../api/client'
import type { CartItem, PlacementInput } from '../api/types'
import { useSession } from '../store/session'
import { DesignEditor } from '../editor/DesignEditor'
import { fromServerPlacements } from '../editor/types'
import { useDesignLibrary } from '../editor/useDesignLibrary'
import { ErrorBox, PageLoading } from '../components/ui'

export function CartItemEditPage() {
  const { id = '' } = useParams()
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { settings, errorMessage, setCartQuantity, locale, toast } = useSession()
  const library = useDesignLibrary()
  const [item, setItem] = useState<CartItem | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [sizeId, setSizeId] = useState<number | null>(null)
  const [quantity, setQuantity] = useState(1)
  const [submitting, setSubmitting] = useState(false)
  const [submitError, setSubmitError] = useState<string | null>(null)

  const load = useCallback(() => {
    setError(null)
    api
      .cart()
      .then(({ cart }) => {
        const found = cart.items.find((i) => String(i.id) === id)
        if (!found) {
          setError(t('common.notFound'))
          return
        }
        setItem(found)
        setSizeId(found.size.id)
        setQuantity(found.quantity)
      })
      .catch((e) => setError(errorMessage(e)))
  }, [id, errorMessage, t])
  useEffect(load, [load])

  // Catalog designs used by a customised catalog item are reusable in this item's editor.
  const designs = useMemo(() => {
    if (!item) return library.designs
    const fromItem = item.placements.map((p) => p.design).filter((d) => !library.designs.some((x) => x.id === d.id))
    return [...library.designs, ...fromItem]
  }, [item, library.designs])

  const initial = useMemo(() => (item ? fromServerPlacements(item.placements) : {}), [item])

  const submit = async (placements: PlacementInput[]) => {
    if (!item || !sizeId) return
    setSubmitting(true)
    setSubmitError(null)
    try {
      // Low DPI is a warning, not a rejection; only real geometry errors come back invalid.
      const check = await api.validatePlacement(item.template.id, placements)
      if (!check.valid) {
        setSubmitError((check.errors ?? (check.error ? [check.error] : [])).join(' ') || t('common.unknownError'))
        return
      }
      const { cart } = await api.updateCartItem(item.id, { quantity, template_size_id: sizeId, placements })
      setCartQuantity(cart.total_quantity)
      toast(t('editor.saved'), 'success')
      navigate('/cart')
    } catch (e) {
      setSubmitError(e instanceof ApiError ? e.errors.join(' ') : errorMessage(e))
    } finally {
      setSubmitting(false)
    }
  }

  if (error) return <div className="container-page py-6"><ErrorBox message={error} onRetry={load} /></div>
  if (!item) return <PageLoading />

  return (
    <div className="container-page py-4">
      <h1 className="mb-3 text-xl font-bold sm:text-2xl">
        {t('cart.editTitle')} · {item.template.name}
      </h1>
      <DesignEditor
        key={item.id}
        template={item.template}
        mode="customer"
        initialPlacements={initial}
        designs={designs}
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
        submitLabel={t('editor.saveChanges')}
        submitting={submitting}
        submitError={submitError}
        onSubmit={submit}
      />
    </div>
  )
}
