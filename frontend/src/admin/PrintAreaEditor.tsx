import { useCallback, useEffect, useRef, useState, type PointerEvent as ReactPointerEvent } from 'react'
import { useTranslation } from 'react-i18next'

export interface PrintAreaEditorProps {
  mockupUrl: string
  area: { x: number; y: number; w: number; h: number; width_mm?: number; height_mm?: number }
  fieldPrefix: string
}

type Rect = { x: number; y: number; w: number; h: number }
type Corner = 'nw' | 'ne' | 'sw' | 'se'
const MIN = 0.02

function clampRect(r: Rect): Rect {
  const w = Math.min(Math.max(r.w, MIN), 1)
  const h = Math.min(Math.max(r.h, MIN), 1)
  const x = Math.min(Math.max(r.x, 0), 1 - w)
  const y = Math.min(Math.max(r.y, 0), 1 - h)
  return { x, y, w, h }
}

/**
 * Admin print-area editor: drag a rectangle over the mockup, resize from the corners
 * (mouse + touch through Pointer Events) and write x/y/w/h fractions into the form.
 */
export function PrintAreaEditor({ mockupUrl, area, fieldPrefix }: PrintAreaEditorProps) {
  const { t } = useTranslation()
  const rootRef = useRef<HTMLDivElement>(null)
  const [rect, setRect] = useState<Rect>(() => clampRect({ x: area.x ?? 0.3, y: area.y ?? 0.25, w: area.w ?? 0.4, h: area.h ?? 0.4 }))
  const [imgSize, setImgSize] = useState<{ w: number; h: number } | null>(null)
  const [mm, setMm] = useState<{ w: number; h: number }>({ w: area.width_mm ?? 0, h: area.height_mm ?? 0 })
  const drag = useRef<{ mode: 'move' | Corner; start: Rect; px: number; py: number } | null>(null)

  const findInput = useCallback(
    (name: string): HTMLInputElement | null => {
      const form = rootRef.current?.closest('form')
      return (form?.querySelector(`[name="${fieldPrefix}[${name}]"]`) as HTMLInputElement | null) ?? null
    },
    [fieldPrefix],
  )

  // Write fractions into the form inputs on every change.
  useEffect(() => {
    for (const k of ['x', 'y', 'w', 'h'] as const) {
      const input = findInput(k)
      if (input) input.value = rect[k].toFixed(6)
    }
  }, [rect, findInput])

  // Read width_mm / height_mm live.
  useEffect(() => {
    const wIn = findInput('width_mm')
    const hIn = findInput('height_mm')
    const read = () => setMm({ w: Number(wIn?.value) || 0, h: Number(hIn?.value) || 0 })
    read()
    wIn?.addEventListener('input', read)
    hIn?.addEventListener('input', read)
    return () => {
      wIn?.removeEventListener('input', read)
      hIn?.removeEventListener('input', read)
    }
  }, [findInput])

  const box = () => rootRef.current!.getBoundingClientRect()

  const onDown = (mode: 'move' | Corner) => (e: ReactPointerEvent<HTMLElement>) => {
    e.preventDefault()
    e.stopPropagation()
    e.currentTarget.setPointerCapture(e.pointerId)
    drag.current = { mode, start: rect, px: e.clientX, py: e.clientY }
  }
  const onMove = (e: ReactPointerEvent<HTMLElement>) => {
    const d = drag.current
    if (!d) return
    const b = box()
    const dx = (e.clientX - d.px) / b.width
    const dy = (e.clientY - d.py) / b.height
    const s = d.start
    let next: Rect
    if (d.mode === 'move') next = { ...s, x: s.x + dx, y: s.y + dy }
    else {
      const left = d.mode === 'nw' || d.mode === 'sw'
      const top = d.mode === 'nw' || d.mode === 'ne'
      let x1 = left ? s.x + dx : s.x
      let y1 = top ? s.y + dy : s.y
      let x2 = left ? s.x + s.w : s.x + s.w + dx
      let y2 = top ? s.y + s.h : s.y + s.h + dy
      x1 = Math.max(0, Math.min(x1, x2 - MIN))
      y1 = Math.max(0, Math.min(y1, y2 - MIN))
      x2 = Math.min(1, Math.max(x2, x1 + MIN))
      y2 = Math.min(1, Math.max(y2, y1 + MIN))
      next = { x: x1, y: y1, w: x2 - x1, h: y2 - y1 }
    }
    setRect(clampRect(next))
  }
  const onUp = (e: ReactPointerEvent<HTMLElement>) => {
    drag.current = null
    if (e.currentTarget.hasPointerCapture(e.pointerId)) e.currentTarget.releasePointerCapture(e.pointerId)
  }

  const pxAspect = imgSize ? (rect.w * imgSize.w) / (rect.h * imgSize.h) : null
  const mmAspect = mm.w > 0 && mm.h > 0 ? mm.w / mm.h : null
  const mismatch = pxAspect !== null && mmAspect !== null && Math.abs(pxAspect / mmAspect - 1) > 0.05

  const corners: { c: Corner; style: React.CSSProperties }[] = [
    { c: 'nw', style: { left: 0, top: 0 } },
    { c: 'ne', style: { left: '100%', top: 0 } },
    { c: 'sw', style: { left: 0, top: '100%' } },
    { c: 'se', style: { left: '100%', top: '100%' } },
  ]

  return (
    <div>
      <div ref={rootRef} className="relative w-full select-none overflow-hidden rounded-lg bg-ink-100" style={{ touchAction: 'none' }}>
        <img src={mockupUrl} alt="" className="w-full" draggable={false} onLoad={(e) => setImgSize({ w: e.currentTarget.naturalWidth, h: e.currentTarget.naturalHeight })} />
        <div
          className="absolute cursor-move border-2 border-brand-500 bg-brand-500/15"
          style={{ left: `${rect.x * 100}%`, top: `${rect.y * 100}%`, width: `${rect.w * 100}%`, height: `${rect.h * 100}%`, touchAction: 'none' }}
          role="slider"
          aria-label={t('admin.move')}
          aria-valuetext={`${(rect.x * 100).toFixed(1)}%, ${(rect.y * 100).toFixed(1)}%`}
          onPointerDown={onDown('move')}
          onPointerMove={onMove}
          onPointerUp={onUp}
          onPointerCancel={onUp}
        >
          {corners.map(({ c, style }) => (
            <button
              key={c}
              type="button"
              aria-label={`${t('admin.resize')} ${c}`}
              className="absolute flex h-11 w-11 -translate-x-1/2 -translate-y-1/2 items-center justify-center"
              style={{ ...style, touchAction: 'none', cursor: c === 'nw' || c === 'se' ? 'nwse-resize' : 'nesw-resize' }}
              onPointerDown={onDown(c)}
              onPointerMove={onMove}
              onPointerUp={onUp}
              onPointerCancel={onUp}
            >
              <span className="block h-4 w-4 rounded-full border-2 border-brand-600 bg-white shadow" />
            </button>
          ))}
        </div>
      </div>
      <p className="mt-2 text-xs text-ink-500">{t('admin.dragHint')}</p>
      <p className="mt-1 text-xs text-ink-500">
        x {rect.x.toFixed(3)} · y {rect.y.toFixed(3)} · w {rect.w.toFixed(3)} · h {rect.h.toFixed(3)}
      </p>
      {mmAspect !== null && pxAspect !== null && (
        <p className={`mt-2 rounded-lg px-3 py-2 text-sm ${mismatch ? 'bg-amber-50 text-amber-900' : 'bg-emerald-50 text-emerald-900'}`} role="status">
          {mismatch ? t('admin.aspectWarning', { px: pxAspect.toFixed(2), mm: mmAspect.toFixed(2) }) : t('admin.aspectOk')}
        </p>
      )}
    </div>
  )
}
