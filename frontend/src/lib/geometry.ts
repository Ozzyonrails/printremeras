// Placement geometry, mirrored from app/models/placement.rb so the editor clamps exactly
// like the server validates. All checks run in physical (mm) space.

export const MIN_SCALE = 0.05
export const MAX_SCALE = 1.0

export interface AreaGeometry {
  width_mm: number
  height_mm: number
  min_dpi: number
}

export interface DesignGeometry {
  width_px: number
  height_px: number
}

export interface PlacementGeometry {
  x: number
  y: number
  scale: number
  rotation: number
}

export function artworkWidthMm(area: AreaGeometry, scale: number) {
  return scale * area.width_mm
}

export function artworkHeightMm(area: AreaGeometry, design: DesignGeometry, scale: number) {
  return artworkWidthMm(area, scale) * (design.height_px / design.width_px)
}

/** Half extents of the rotated bounding box, in mm. */
export function boundingHalfExtents(area: AreaGeometry, design: DesignGeometry, scale: number, rotation: number) {
  const rad = (rotation * Math.PI) / 180
  const w = artworkWidthMm(area, scale)
  const h = artworkHeightMm(area, design, scale)
  const bw = Math.abs(w * Math.cos(rad)) + Math.abs(h * Math.sin(rad))
  const bh = Math.abs(w * Math.sin(rad)) + Math.abs(h * Math.cos(rad))
  return { halfW: bw / 2, halfH: bh / 2 }
}

export function effectiveDpi(area: AreaGeometry, design: DesignGeometry, scale: number) {
  const wmm = artworkWidthMm(area, scale)
  if (!design.width_px || wmm <= 0) return 0
  return design.width_px / (wmm / 25.4)
}

/** Largest scale (<= MAX_SCALE) at which the rotated box still fits inside the area. */
export function maxScaleFor(area: AreaGeometry, design: DesignGeometry, rotation: number) {
  const { halfW, halfH } = boundingHalfExtents(area, design, 1, rotation)
  const fitW = area.width_mm / (halfW * 2)
  const fitH = area.height_mm / (halfH * 2)
  return Math.max(MIN_SCALE, Math.min(MAX_SCALE, fitW, fitH))
}

/**
 * Scale at which effective DPI equals min_dpi. This is NOT a cap any more: low-resolution
 * artwork is accepted and upscaled before printing. It is only applied when the shop turns
 * `settings.enforce_min_dpi` on (mirroring Placement#meets_min_dpi, which is likewise
 * conditional on Setting.enforce_min_dpi).
 */
export function maxScaleForDpi(area: AreaGeometry, design: DesignGeometry) {
  if (!design.width_px || !area.min_dpi) return MAX_SCALE
  const maxWidthMm = (design.width_px / area.min_dpi) * 25.4
  return maxWidthMm / area.width_mm
}

/** Geometric cap only, unless the shop opted into DPI enforcement. */
export function scaleCap(area: AreaGeometry, design: DesignGeometry, rotation: number, enforceDpi = false) {
  const capFit = maxScaleFor(area, design, rotation)
  if (!enforceDpi) return capFit
  return Math.min(capFit, Math.max(MIN_SCALE, maxScaleForDpi(area, design)))
}

export interface ClampOptions {
  /** Off by default: DPI never limits the size the customer can choose. */
  enforceDpi?: boolean
}

export function clampPlacement(area: AreaGeometry, design: DesignGeometry, p: PlacementGeometry, opts: ClampOptions = {}): PlacementGeometry {
  let rotation = ((p.rotation + 180) % 360 + 360) % 360 - 180
  if (rotation === -180) rotation = 180
  // The bounding box must stay inside the print area — a physical constraint, kept exactly.
  const cap = scaleCap(area, design, rotation, opts.enforceDpi === true)
  const scale = Math.min(Math.max(MIN_SCALE, p.scale), cap)
  const { halfW, halfH } = boundingHalfExtents(area, design, scale, rotation)
  const minX = halfW / area.width_mm
  const maxX = 1 - minX
  const minY = halfH / area.height_mm
  const maxY = 1 - minY
  const x = minX > maxX ? 0.5 : Math.min(Math.max(p.x, minX), maxX)
  const y = minY > maxY ? 0.5 : Math.min(Math.max(p.y, minY), maxY)
  return { x, y, scale, rotation }
}

export function initialPlacement(area: AreaGeometry, design: DesignGeometry, opts: ClampOptions = {}): PlacementGeometry {
  const scale = Math.min(scaleCap(area, design, 0, opts.enforceDpi === true), 0.8)
  return clampPlacement(area, design, { x: 0.5, y: 0.5, scale, rotation: 0 }, opts)
}
