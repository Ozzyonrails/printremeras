import { useCallback, useEffect, useMemo, useRef, useState, type ChangeEvent, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import type { Design, PlacementInput, PrintArea, Side, TemplateFull, TemplateSize } from '../api/types'
import { MIN_SCALE, clampPlacement, effectiveDpi, initialPlacement, maxScaleForDpi, scaleCap, type ClampOptions, type PlacementGeometry } from '../lib/geometry'
import { formatMoney } from '../lib/money'
import { UploadError } from '../lib/upload'
import { ProgressBar, Segmented, Sheet, Stepper } from '../components/ui'
import { EditorCanvas } from './EditorCanvas'
import { toPlacementInputs, type EditorPlacement, type PlacementMap } from './types'

export interface DesignEditorProps {
  template: TemplateFull
  mode: 'customer' | 'admin'
  initialPlacements?: PlacementMap
  /** Reusable designs: the customer's uploads or the catalog library. */
  designs: Design[]
  onUpload: (file: File, onProgress: (fraction: number) => void) => Promise<Design>
  onDeleteDesign?: (design: Design) => Promise<void>
  maxUploadBytes?: number
  minUploadPx?: number
  /**
   * settings.enforce_min_dpi. Off by default: low DPI is a calm notice, never a block —
   * the shop upscales the artwork before printing. On, the old blocking behaviour returns.
   */
  enforceMinDpi?: boolean
  /** settings.enforce_min_upload_px — only changes the wording of the upload hint here. */
  enforceMinUploadPx?: boolean
  /** Rendered above the upload button (e.g. the admin's licence note). */
  uploadExtra?: ReactNode
  errorMessage?: (e: unknown) => string
  locale?: string
  // customer-only
  sizeId?: number | null
  onSizeChange?: (id: number) => void
  quantity?: number
  onQuantityChange?: (q: number) => void
  // submit
  submitLabel: string
  submitting?: boolean
  submitError?: string | null
  onSubmit: (placements: PlacementInput[]) => void | Promise<void>
  onPlacementsChange?: (map: PlacementMap) => void
}

export function DesignEditor(props: DesignEditorProps) {
  const { template, mode, designs, onUpload, onDeleteDesign, uploadExtra, submitLabel, submitting, submitError, onSubmit, onPlacementsChange } = props
  const { t } = useTranslation()
  const areas = template.print_areas
  const [side, setSide] = useState<Side>(areas.find((a) => a.side === 'front')?.side || areas[0]?.side || 'front')
  const [placements, setPlacements] = useState<PlacementMap>(() => props.initialPlacements ?? {})
  const [controlsOpen, setControlsOpen] = useState(false)
  const [uploading, setUploading] = useState(false)
  const [progress, setProgress] = useState(0)
  const [uploadErr, setUploadErr] = useState<string | null>(null)
  const [uploadNotice, setUploadNotice] = useState<string | null>(null)
  const fileInput = useRef<HTMLInputElement>(null)

  const enforceDpi = props.enforceMinDpi === true
  const clampOpts: ClampOptions = useMemo(() => ({ enforceDpi }), [enforceDpi])

  const area: PrintArea | undefined = areas.find((a) => a.side === side) || areas[0]
  const placement = area ? placements[area.id] : undefined

  useEffect(() => {
    onPlacementsChange?.(placements)
  }, [placements, onPlacementsChange])

  const updatePlacement = useCallback(
    (areaId: number, next: EditorPlacement | undefined) => setPlacements((m) => ({ ...m, [areaId]: next })),
    [],
  )

  const onGeometry = useCallback(
    (g: PlacementGeometry) => {
      if (!area || !placement) return
      updatePlacement(area.id, { ...placement, ...g })
    },
    [area, placement, updatePlacement],
  )

  const useDesign = (design: Design) => {
    if (!area) return
    const geom = placement ? clampPlacement(area, design, placement, clampOpts) : initialPlacement(area, design, clampOpts)
    updatePlacement(area.id, { design, ...geom })
  }

  const describeError = (e: unknown) => {
    if (e instanceof UploadError) {
      const mb = Math.round((props.maxUploadBytes ?? 20 * 1024 * 1024) / (1024 * 1024))
      if (e.code === 'type') return t('editor.fileType')
      if (e.code === 'size') return t('editor.fileTooLarge', { mb })
      if (e.code === 'too_small') return t('editor.fileTooSmall', { px: props.minUploadPx ?? 800 })
      // code 'failed' wraps whatever the server said; showing it beats a blanket retry message.
      return e.message && e.message !== 'upload failed' ? `${t('editor.uploadFailed')} ${e.message}` : t('editor.uploadFailed')
    }
    if (props.errorMessage) return props.errorMessage(e)
    const maybe = e as { errors?: string[]; message?: string }
    if (Array.isArray(maybe?.errors) && maybe.errors.length) return maybe.errors.join(' ')
    return maybe?.message || t('editor.uploadFailed')
  }

  const onFile = async (e: ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    e.target.value = ''
    if (!file) return
    setUploading(true)
    setProgress(0)
    setUploadErr(null)
    setUploadNotice(null)
    try {
      const design = await onUpload(file, setProgress)
      useDesign(design)
      // Low-resolution uploads are accepted; the server marks them so they can be upscaled.
      if (design.needs_enhancement) setUploadNotice(t('editor.uploadWillBeEnhanced'))
    } catch (err) {
      setUploadErr(describeError(err))
    } finally {
      setUploading(false)
    }
  }

  // ---- derived -------------------------------------------------------------
  const dpi = area && placement ? Math.round(effectiveDpi(area, placement.design, placement.scale)) : null
  const lowQuality = area && placement ? dpi !== null && dpi < area.min_dpi : false
  // Geometric cap only — the artwork box must stay inside the print area. The DPI cap is
  // applied solely when the shop opted into enforce_min_dpi.
  const scaleMax = area && placement ? scaleCap(area, placement.design, placement.rotation, enforceDpi) : 1
  const atDpiCap = enforceDpi && area && placement ? placement.scale >= Math.max(MIN_SCALE, maxScaleForDpi(area, placement.design)) - 1e-6 : false
  const filledAreas = areas.filter((a) => placements[a.id])
  const sidesCount = filledAreas.length
  const anyLowQuality = areas.some((a) => {
    const p = placements[a.id]
    return p && effectiveDpi(a, p.design, p.scale) < a.min_dpi
  })

  const printPrice = sidesCount >= 2 ? template.print_price_two_sides_cents : sidesCount === 1 ? template.print_price_one_side_cents : 0
  const unitPrice = template.base_price_cents + printPrice
  const quantity = props.quantity ?? 1
  const size: TemplateSize | undefined = template.sizes.find((s) => s.id === props.sizeId)

  const canSubmit = useMemo(() => {
    if (submitting || uploading) return false
    if (mode === 'customer') {
      if (sidesCount === 0) return false
      if (!size || !size.available) return false
    }
    // Low quality never blocks: the design is accepted and improved before printing.
    return !(enforceDpi && anyLowQuality)
  }, [submitting, uploading, mode, sidesCount, size, anyLowQuality, enforceDpi])

  const submitHint = mode === 'customer' ? (sidesCount === 0 ? t('editor.addDesignFirst') : !size ? t('editor.chooseSizeFirst') : !size.available ? t('editor.outOfStockSize') : null) : null

  const submit = () => void onSubmit(toPlacementInputs(placements))

  if (!area) return <p className="p-4 text-ink-500">{t('editor.noDesign')}</p>

  const sideOptions = areas.map((a) => ({
    value: a.side,
    label: (
      <span className="inline-flex items-center gap-1.5">
        {t(a.side === 'front' ? 'editor.front' : 'editor.back')}
        {placements[a.id] && <span className="h-2 w-2 rounded-full bg-brand-500" aria-hidden="true" />}
      </span>
    ),
  }))

  const controls = (
    <div className="space-y-4">
      {placement ? (
        <>
          <div className="flex items-center justify-between text-sm">
            <span className={`font-semibold ${lowQuality ? (enforceDpi ? 'text-red-700' : 'text-amber-700') : 'text-emerald-700'}`}>{t('editor.dpi', { dpi })}</span>
            <span className="text-ink-500">{t('editor.dpiMin', { dpi: area.min_dpi })}</span>
          </div>
          <QualityNotice lowQuality={lowQuality} atDpiCap={atDpiCap} enforceDpi={enforceDpi} />
          <DesignBadge design={placement.design} detailed />
          <label className="block">
            <span className="label flex justify-between">
              {t('editor.scale')}
              <span className="text-ink-500">{Math.round(placement.scale * area.width_mm)} mm</span>
            </span>
            <input
              type="range"
              min={MIN_SCALE}
              max={Math.max(MIN_SCALE, scaleMax)}
              step={0.001}
              value={Math.min(placement.scale, scaleMax)}
              onChange={(e) => onGeometry(clampPlacement(area, placement.design, { ...placement, scale: Number(e.target.value) }, clampOpts))}
            />
          </label>
          <label className="block">
            <span className="label flex justify-between">
              {t('editor.rotation')}
              <span className="text-ink-500">{Math.round(placement.rotation)}°</span>
            </span>
            <input
              type="range"
              min={-180}
              max={180}
              step={1}
              value={Math.round(placement.rotation)}
              onChange={(e) => onGeometry(clampPlacement(area, placement.design, { ...placement, rotation: Number(e.target.value) }, clampOpts))}
            />
          </label>
          <div className="flex flex-wrap gap-2">
            <button type="button" className="btn-secondary text-sm" onClick={() => onGeometry(clampPlacement(area, placement.design, { ...placement, x: 0.5, y: 0.5, rotation: 0 }, clampOpts))}>
              {t('editor.reset')}
            </button>
            <button type="button" className="btn-secondary text-sm" onClick={() => onGeometry(clampPlacement(area, placement.design, { ...placement, scale: 1 }, clampOpts))}>
              {t('editor.fit')}
            </button>
            <button type="button" className="btn-outline text-sm text-red-700" onClick={() => updatePlacement(area.id, undefined)}>
              {t('editor.removeDesign')}
            </button>
          </div>
        </>
      ) : (
        <p className="text-sm text-ink-500">{t('editor.noDesign')}</p>
      )}
      <p className="text-xs text-ink-500">
        {t('editor.printArea')}: {t('editor.sizeMm', { w: Math.round(area.width_mm), h: Math.round(area.height_mm) })}
      </p>
    </div>
  )

  const library = (
    <div className="space-y-3">
      {uploadExtra}
      <input ref={fileInput} type="file" accept="image/*" className="hidden" onChange={onFile} />
      <button type="button" className="btn-accent w-full" disabled={uploading} onClick={() => fileInput.current?.click()}>
        {uploading ? t('editor.uploading', { percent: Math.round(progress * 100) }) : mode === 'admin' ? t('editor.uploadToLibrary') : placement ? t('editor.replaceDesign') : t('editor.upload')}
      </button>
      {uploading && <ProgressBar value={progress} />}
      {uploadErr && (
        <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-800" role="alert">
          {uploadErr}
        </p>
      )}
      {uploadNotice && (
        <p className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-800" role="status">
          {uploadNotice}
        </p>
      )}
      <p className="text-xs text-ink-500">
        {props.enforceMinUploadPx
          ? t('editor.uploadHint', { mb: Math.round((props.maxUploadBytes ?? 20 * 1024 * 1024) / (1024 * 1024)), px: props.minUploadPx ?? 800 })
          : t('editor.uploadHintOpen', { mb: Math.round((props.maxUploadBytes ?? 20 * 1024 * 1024) / (1024 * 1024)), px: props.minUploadPx ?? 800 })}
      </p>
      <div>
        <p className="mb-2 text-sm font-semibold">{mode === 'admin' ? t('editor.library') : t('editor.myUploads')}</p>
        {designs.length === 0 ? (
          <p className="text-sm text-ink-500">{t('editor.noUploads')}</p>
        ) : (
          <ul className="no-scrollbar -mx-4 flex gap-2 overflow-x-auto px-4 lg:mx-0 lg:grid lg:grid-cols-4 lg:px-0">
            {designs.map((d) => {
              const active = placement?.design.id === d.id
              return (
                <li key={d.id} className="relative shrink-0">
                  <button
                    type="button"
                    onClick={() => useDesign(d)}
                    className={`relative block h-20 w-20 overflow-hidden rounded-xl border-2 bg-white ${active ? 'border-brand-500' : 'border-ink-100'}`}
                    aria-label={t('editor.useDesign')}
                    aria-pressed={active}
                  >
                    {d.thumb_url || d.url ? <img src={d.thumb_url || d.url || ''} alt="" loading="lazy" className="h-full w-full object-contain" /> : null}
                    <EnhancementDot design={d} />
                  </button>
                  {onDeleteDesign && (
                    <button
                      type="button"
                      className="absolute -right-1 -top-1 flex h-7 w-7 items-center justify-center rounded-full bg-white text-xs text-ink-700 shadow ring-1 ring-ink-300"
                      aria-label={t('editor.deleteUpload')}
                      onClick={() => {
                        if (window.confirm(t('editor.deleteUploadConfirm'))) void onDeleteDesign(d).catch((e) => setUploadErr(describeError(e)))
                      }}
                    >
                      ✕
                    </button>
                  )}
                </li>
              )
            })}
          </ul>
        )}
      </div>
    </div>
  )

  const sizePicker = mode === 'customer' && (
    <div>
      <p className="mb-2 text-sm font-semibold">{t('sizes.label')}</p>
      <div className="flex flex-wrap gap-2">
        {template.sizes.map((s) => {
          const selected = s.id === props.sizeId
          const title = s.available ? s.label : s.restock_at ? t('sizes.backOn', { date: formatRestock(s.restock_at, props.locale) }) : t('sizes.outOfStock')
          return (
            <button
              key={s.id}
              type="button"
              disabled={!s.available}
              title={title}
              aria-label={title}
              aria-pressed={selected}
              onClick={() => props.onSizeChange?.(s.id)}
              className={`chip min-h-touch min-w-touch justify-center ${selected ? 'chip-active' : ''} ${!s.available ? 'line-through opacity-50' : ''}`}
            >
              {s.label}
            </button>
          )
        })}
      </div>
      {size && !size.available && (
        <p className="mt-2 text-xs text-ink-500">{size.restock_at ? t('sizes.backOn', { date: formatRestock(size.restock_at, props.locale) }) : t('sizes.outOfStock')}</p>
      )}
      {template.sizes.some((s) => !s.available) && !size && (
        <ul className="mt-2 space-y-0.5 text-xs text-ink-500">
          {template.sizes
            .filter((s) => !s.available)
            .map((s) => (
              <li key={s.id}>
                {s.label}: {s.restock_at ? t('sizes.backOn', { date: formatRestock(s.restock_at, props.locale) }) : t('sizes.outOfStock')}
              </li>
            ))}
        </ul>
      )}
    </div>
  )

  const priceBox = mode === 'customer' && (
    <div className="rounded-xl bg-ink-100 p-3 text-sm">
      <div className="flex justify-between">
        <span>{t('templates.basePrice')}</span>
        <span className="tabular-nums">{formatMoney(template.base_price_cents)}</span>
      </div>
      <div className="flex justify-between">
        <span>{sidesCount >= 2 ? t('templates.printTwo') : t('templates.printOne')}</span>
        <span className="tabular-nums">{formatMoney(sidesCount >= 2 ? template.print_price_two_sides_cents : template.print_price_one_side_cents)}</span>
      </div>
      <div className="mt-1 flex justify-between border-t border-ink-300 pt-1 font-semibold">
        <span>
          {t('editor.unitPrice')} · {sidesCount >= 2 ? t('editor.sidesTwo') : t('editor.sidesOne')}
        </span>
        <span className="tabular-nums">{formatMoney(unitPrice)}</span>
      </div>
    </div>
  )

  return (
    <div className="lg:grid lg:grid-cols-[minmax(0,1fr)_380px] lg:gap-8">
      {/* Canvas column: full-bleed on phones */}
      <div className="-mx-4 sm:mx-0">
        <EditorCanvas area={area} placement={placement} onChange={onGeometry} onTapEmpty={() => fileInput.current?.click()} enforceDpi={enforceDpi} className="sm:rounded-2xl" />
        <div className="flex items-center justify-between gap-3 px-4 py-3 sm:px-0">
          <Segmented value={side} options={sideOptions} onChange={setSide} />
          <button type="button" className="btn-secondary text-sm lg:hidden" onClick={() => setControlsOpen(true)}>
            {t('editor.controls')}
            {dpi !== null && <span className={`text-xs ${lowQuality ? (enforceDpi ? 'text-red-700' : 'text-amber-700') : 'text-ink-500'}`}>{t('editor.dpi', { dpi })}</span>}
          </button>
        </div>
        <p className="px-4 pb-3 text-xs text-ink-500 sm:px-0">{t('editor.dragHint')}</p>
        <QualityNotice lowQuality={lowQuality} atDpiCap={atDpiCap} enforceDpi={enforceDpi} className="mx-4 mb-3 sm:mx-0 lg:hidden" />
      </div>

      {/* Sidebar (desktop) / stacked panels (phone) */}
      <div className="space-y-6 pb-28 lg:pb-0">
        <section className="card p-4">{library}</section>
        <section className="card hidden p-4 lg:block">{controls}</section>
        {mode === 'customer' && (
          <section className="card space-y-4 p-4">
            {sizePicker}
            <div className="flex items-center justify-between">
              <span className="text-sm font-semibold">{t('editor.quantity')}</span>
              <Stepper value={quantity} onChange={(q) => props.onQuantityChange?.(q)} label={t('editor.quantity')} />
            </div>
            {priceBox}
          </section>
        )}
        {submitError && (
          <p className="rounded-xl border border-red-200 bg-red-50 p-3 text-sm text-red-800" role="alert">
            {submitError}
          </p>
        )}
        {/* Desktop submit */}
        <div className="hidden lg:block">
          {submitHint && <p className="mb-2 text-sm text-ink-500">{submitHint}</p>}
          <button type="button" className="btn-primary w-full" disabled={!canSubmit} onClick={submit}>
            {submitting ? t('editor.validating') : submitLabel}
            {mode === 'customer' && <span className="ml-auto tabular-nums">{formatMoney(unitPrice * quantity)}</span>}
          </button>
        </div>
      </div>

      {/* Sticky bottom bar on phones: primary action in the lower third */}
      <div className="sticky-action border-t border-ink-100 bg-white/95 px-4 py-2 backdrop-blur lg:hidden">
        {submitHint && <p className="mb-1 text-xs text-ink-500">{submitHint}</p>}
        <div className="flex items-center gap-3">
          {mode === 'customer' && (
            <div className="min-w-0 flex-1 leading-tight">
              <p className="text-lg font-bold tabular-nums">{formatMoney(unitPrice * quantity)}</p>
              <p className="truncate text-xs text-ink-500">
                {size ? `${t('sizes.label')} ${size.label}` : t('sizes.choose')} · {quantity} {t('common.units')}
              </p>
            </div>
          )}
          <button type="button" className={`btn-primary ${mode === 'admin' ? 'w-full' : 'flex-1'}`} disabled={!canSubmit} onClick={submit}>
            {submitting ? t('editor.validating') : submitLabel}
          </button>
        </div>
      </div>

      <Sheet open={controlsOpen} onClose={() => setControlsOpen(false)} title={t('editor.controls')}>
        {controls}
      </Sheet>
    </div>
  )
}

/**
 * Low DPI is informative, not an error: the artwork is accepted and upscaled before printing.
 * Only when the shop turns enforce_min_dpi on does it read (and behave) as a blocker.
 */
function QualityNotice({ lowQuality, atDpiCap, enforceDpi, className = '' }: { lowQuality: boolean; atDpiCap: boolean; enforceDpi: boolean; className?: string }) {
  const { t } = useTranslation()
  if (enforceDpi) {
    if (!lowQuality && !atDpiCap) return null
    return (
      <p className={`rounded-lg px-3 py-2 text-sm ${lowQuality ? 'bg-red-50 text-red-800' : 'bg-amber-50 text-amber-800'} ${className}`} role="status">
        {t('editor.lowQuality')}
      </p>
    )
  }
  if (!lowQuality) return null
  return (
    <p className={`rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-800 ${className}`} role="status">
      {t('editor.lowQualityAccepted')}
    </p>
  )
}

type EnhancementTone = 'pending' | 'done' | null

function enhancementTone(design: Design): EnhancementTone {
  if (design.enhanced || design.enhancement_status === 'done') return 'done'
  if (design.needs_enhancement || ['needed', 'requested', 'processing', 'failed'].includes(design.enhancement_status)) return 'pending'
  return null
}

/** Corner marker on an 80px thumbnail in the uploads strip. */
function EnhancementDot({ design }: { design: Design }) {
  const { t } = useTranslation()
  const tone = enhancementTone(design)
  if (!tone) return null
  const label = tone === 'done' ? t('editor.enhancementDoneChip') : t('editor.enhancementPendingChip')
  return (
    <span
      className={`absolute inset-x-0 bottom-0 truncate px-1 py-0.5 text-[10px] font-semibold leading-tight ${
        tone === 'done' ? 'bg-emerald-100 text-emerald-800' : 'bg-amber-100 text-amber-800'
      }`}
      title={label}
    >
      {label}
    </span>
  )
}

/** Chip + one line of detail for the design currently on this side. */
function DesignBadge({ design, detailed = false }: { design: Design; detailed?: boolean }) {
  const { t } = useTranslation()
  const tone = enhancementTone(design)
  if (!tone) return null
  const done = tone === 'done'
  return (
    <div className={`rounded-lg px-3 py-2 text-sm ${done ? 'bg-emerald-50 text-emerald-800' : 'bg-amber-50 text-amber-800'}`} role="status">
      <span className="font-semibold">{done ? t('editor.enhancementDoneChip') : t('editor.enhancementPendingChip')}</span>
      {detailed && (
        <span className="ml-1">
          {done
            ? t('editor.enhancementDoneDetail', { w: design.width_px, h: design.height_px })
            : t('editor.enhancementPendingDetail', { w: design.uploaded_width_px, h: design.uploaded_height_px })}
        </span>
      )}
    </div>
  )
}

function formatRestock(iso: string, locale?: string) {
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return iso
  return new Intl.DateTimeFormat(locale === 'ru' ? 'ru-RU' : 'es-AR', { day: 'numeric', month: 'long' }).format(d)
}
