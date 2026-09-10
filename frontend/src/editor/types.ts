import type { Design, PlacementInput, PrintArea, Side } from '../api/types'

export interface EditorPlacement {
  design: Design
  x: number
  y: number
  scale: number
  rotation: number
}

/** print_area_id → placement (each side holds at most one design). */
export type PlacementMap = Record<number, EditorPlacement | undefined>

export function toPlacementInputs(map: PlacementMap): PlacementInput[] {
  return Object.entries(map)
    .filter(([, p]) => p)
    .map(([areaId, p]) => ({
      print_area_id: Number(areaId),
      design_id: p!.design.id,
      x: round(p!.x),
      y: round(p!.y),
      scale: round(p!.scale),
      rotation: Math.round(p!.rotation * 100) / 100,
    }))
}

export function fromServerPlacements(placements: { print_area_id: number; design: Design; x: number; y: number; scale: number; rotation: number }[]): PlacementMap {
  const map: PlacementMap = {}
  for (const p of placements) map[p.print_area_id] = { design: p.design, x: p.x, y: p.y, scale: p.scale, rotation: p.rotation }
  return map
}

export function sidesWithDesign(map: PlacementMap, areas: PrintArea[]): Side[] {
  return areas.filter((a) => map[a.id]).map((a) => a.side)
}

function round(n: number) {
  return Math.round(n * 1e6) / 1e6
}
