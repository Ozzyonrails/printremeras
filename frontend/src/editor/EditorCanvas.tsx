import { useCallback, useEffect, useRef, useState, type PointerEvent as ReactPointerEvent } from 'react'
import { useTranslation } from 'react-i18next'
import type { PrintArea } from '../api/types'
import { clampPlacement, type PlacementGeometry } from '../lib/geometry'
import type { EditorPlacement } from './types'

interface Props {
  area: PrintArea
  placement: EditorPlacement | undefined
  onChange: (p: PlacementGeometry) => void
  onTapEmpty?: () => void
  /** settings.enforce_min_dpi. Off by default: pinch/wheel are limited by geometry only. */
  enforceDpi?: boolean
  className?: string
}

interface PointerState {
  id: number
  x: number
  y: number
}

interface GestureStart {
  placement: PlacementGeometry
  dist: number
  angle: number
  cx: number
  cy: number
}

function dist(a: PointerState, b: PointerState) {
  return Math.hypot(a.x - b.x, a.y - b.y)
}
function angle(a: PointerState, b: PointerState) {
  return (Math.atan2(b.y - a.y, b.x - a.x) * 180) / Math.PI
}

/**
 * Mockup + print area + artwork. Pointer Events give one code path for mouse and touch:
 * one pointer drags, two pointers pinch (scale) and twist (rotate); wheel scales on desktop.
 */
export function EditorCanvas({ area, placement, onChange, onTapEmpty, enforceDpi = false, className = '' }: Props) {
  const { t } = useTranslation()
  const areaRef = useRef<HTMLDivElement>(null)
  const pointers = useRef<Map<number, PointerState>>(new Map())
  const gesture = useRef<GestureStart | null>(null)
  const rotating = useRef<{ startAngle: number; startRotation: number } | null>(null)
  const [dragging, setDragging] = useState(false)
  const [areaBox, setAreaBox] = useState({ w: 1, h: 1 })

  useEffect(() => {
    const el = areaRef.current
    if (!el) return
    const update = () => setAreaBox({ w: el.clientWidth || 1, h: el.clientHeight || 1 })
    update()
    const ro = new ResizeObserver(update)
    ro.observe(el)
    return () => ro.disconnect()
  }, [])

  const commit = useCallback(
    (p: PlacementGeometry) => {
      if (!placement) return
      onChange(clampPlacement(area, placement.design, p, { enforceDpi }))
    },
    [area, placement, onChange, enforceDpi],
  )

  const centreOf = (pts: PointerState[]) => ({
    cx: pts.reduce((s, p) => s + p.x, 0) / pts.length,
    cy: pts.reduce((s, p) => s + p.y, 0) / pts.length,
  })

  const beginGesture = () => {
    if (!placement) return
    const pts = [...pointers.current.values()]
    const { cx, cy } = centreOf(pts)
    gesture.current = {
      placement: { x: placement.x, y: placement.y, scale: placement.scale, rotation: placement.rotation },
      dist: pts.length >= 2 ? dist(pts[0], pts[1]) : 0,
      angle: pts.length >= 2 ? angle(pts[0], pts[1]) : 0,
      cx,
      cy,
    }
  }

  const onPointerDown = (e: ReactPointerEvent<HTMLDivElement>) => {
    if (!placement) {
      onTapEmpty?.()
      return
    }
    e.preventDefault()
    e.currentTarget.setPointerCapture(e.pointerId)
    pointers.current.set(e.pointerId, { id: e.pointerId, x: e.clientX, y: e.clientY })
    beginGesture()
    setDragging(true)
  }

  const onPointerMove = (e: ReactPointerEvent<HTMLDivElement>) => {
    if (!pointers.current.has(e.pointerId) || !gesture.current || !placement) return
    pointers.current.set(e.pointerId, { id: e.pointerId, x: e.clientX, y: e.clientY })
    const pts = [...pointers.current.values()]
    const start = gesture.current
    const { cx, cy } = centreOf(pts)
    const dx = (cx - start.cx) / areaBox.w
    const dy = (cy - start.cy) / areaBox.h
    let scale = start.placement.scale
    let rotation = start.placement.rotation
    if (pts.length >= 2 && start.dist > 0) {
      scale = start.placement.scale * (dist(pts[0], pts[1]) / start.dist)
      rotation = start.placement.rotation + (angle(pts[0], pts[1]) - start.angle)
    }
    commit({ x: start.placement.x + dx, y: start.placement.y + dy, scale, rotation })
  }

  const onPointerUp = (e: ReactPointerEvent<HTMLDivElement>) => {
    pointers.current.delete(e.pointerId)
    if (e.currentTarget.hasPointerCapture(e.pointerId)) e.currentTarget.releasePointerCapture(e.pointerId)
    if (pointers.current.size === 0) {
      gesture.current = null
      setDragging(false)
    } else {
      beginGesture()
    }
  }

  // React registers wheel listeners as passive, so attach a native non-passive one to be able to
  // preventDefault (otherwise the page scrolls while the user zooms the artwork).
  const wheelState = useRef({ placement, commit })
  wheelState.current = { placement, commit }
  useEffect(() => {
    const el = areaRef.current
    if (!el) return
    const onWheel = (e: WheelEvent) => {
      const { placement, commit } = wheelState.current
      if (!placement) return
      e.preventDefault()
      const factor = Math.exp(-e.deltaY * 0.0015)
      commit({ ...placement, scale: placement.scale * factor })
    }
    el.addEventListener('wheel', onWheel, { passive: false })
    return () => el.removeEventListener('wheel', onWheel)
  }, [])

  // ---- rotate handle -------------------------------------------------------
  const onRotateDown = (e: ReactPointerEvent<HTMLButtonElement>) => {
    if (!placement) return
    e.preventDefault()
    e.stopPropagation()
    e.currentTarget.setPointerCapture(e.pointerId)
    const rect = areaRef.current!.getBoundingClientRect()
    const cx = rect.left + placement.x * rect.width
    const cy = rect.top + placement.y * rect.height
    rotating.current = { startAngle: (Math.atan2(e.clientY - cy, e.clientX - cx) * 180) / Math.PI, startRotation: placement.rotation }
  }
  const onRotateMove = (e: ReactPointerEvent<HTMLButtonElement>) => {
    if (!rotating.current || !placement) return
    const rect = areaRef.current!.getBoundingClientRect()
    const cx = rect.left + placement.x * rect.width
    const cy = rect.top + placement.y * rect.height
    const a = (Math.atan2(e.clientY - cy, e.clientX - cx) * 180) / Math.PI
    commit({ ...placement, rotation: rotating.current.startRotation + (a - rotating.current.startAngle) })
  }
  const onRotateUp = (e: ReactPointerEvent<HTMLButtonElement>) => {
    rotating.current = null
    if (e.currentTarget.hasPointerCapture(e.pointerId)) e.currentTarget.releasePointerCapture(e.pointerId)
  }

  // Artwork rendered height in px = rendered width * (design.height_px / design.width_px)
  const artWidthPx = placement ? placement.scale * areaBox.w : 0
  const artHeightPx = placement ? artWidthPx * (placement.design.height_px / placement.design.width_px) : 0
  const handleOffset = artHeightPx / 2 + 28

  return (
    <div className={`relative w-full select-none overflow-hidden bg-ink-100 ${className}`}>
      {area.mockup_url ? (
        <img
          src={area.mockup_url}
          alt=""
          className="w-full"
          draggable={false}
          style={area.mockup_width_px && area.mockup_height_px ? { aspectRatio: `${area.mockup_width_px} / ${area.mockup_height_px}` } : undefined}
        />
      ) : (
        <div className="aspect-[4/5] w-full" />
      )}
      {/* Print area: percentages straight from x/y/w/h */}
      <div
        ref={areaRef}
        className={`absolute touch-none overflow-hidden ${placement ? 'cursor-move' : 'cursor-pointer'} ${dragging ? 'outline outline-2 outline-brand-500' : 'outline-dashed outline-1 outline-ink-500/70'}`}
        style={{ left: `${area.x * 100}%`, top: `${area.y * 100}%`, width: `${area.w * 100}%`, height: `${area.h * 100}%` }}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerUp}
        role="application"
        aria-label={t('editor.printArea')}
      >
        {placement ? (
          <img
            src={placement.design.url || placement.design.thumb_url || ''}
            alt=""
            draggable={false}
            className="pointer-events-none absolute max-w-none"
            style={{
              left: `${placement.x * 100}%`,
              top: `${placement.y * 100}%`,
              width: `${placement.scale * 100}%`,
              height: 'auto',
              transform: `translate(-50%, -50%) rotate(${placement.rotation}deg)`,
              transformOrigin: 'center center',
            }}
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center p-2 text-center text-xs font-medium text-ink-500">{t('editor.noDesign')}</div>
        )}
      </div>
      {/* Overlay (not clipped) for the rotate handle */}
      {placement && (
        <div className="pointer-events-none absolute" style={{ left: `${area.x * 100}%`, top: `${area.y * 100}%`, width: `${area.w * 100}%`, height: `${area.h * 100}%` }}>
          <button
            type="button"
            aria-label={t('editor.rotation')}
            className="pointer-events-auto absolute flex h-11 w-11 -translate-x-1/2 -translate-y-1/2 touch-none items-center justify-center rounded-full bg-white text-ink-900 shadow-md ring-1 ring-ink-300"
            style={{
              left: `${placement.x * 100}%`,
              top: `${placement.y * 100}%`,
              transform: `translate(-50%, -50%) rotate(${placement.rotation}deg) translateY(${handleOffset}px) rotate(${-placement.rotation}deg)`,
            }}
            onPointerDown={onRotateDown}
            onPointerMove={onRotateMove}
            onPointerUp={onRotateUp}
            onPointerCancel={onRotateUp}
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
              <path d="M21 12a9 9 0 1 1-3-6.7" />
              <path d="M21 3v6h-6" />
            </svg>
          </button>
        </div>
      )}
    </div>
  )
}
