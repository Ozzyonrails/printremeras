import { useCallback, useEffect, useState } from 'react'
import { api } from '../api/client'
import type { Design } from '../api/types'
import { useSession } from '../store/session'
import { uploadImageFile } from '../lib/upload'

/** The customer's reusable uploads (GET /api/v1/designs) plus the upload → design flow. */
export function useDesignLibrary() {
  const { settings } = useSession()
  const [designs, setDesigns] = useState<Design[]>([])

  const reload = useCallback(async () => {
    try {
      const { designs } = await api.designs()
      setDesigns(designs)
    } catch {
      /* guests without a cookie yet simply see an empty strip */
    }
  }, [])

  useEffect(() => {
    void reload()
  }, [reload])

  const upload = useCallback(
    async (file: File, onProgress: (f: number) => void) => {
      // Small artwork is uploaded anyway; the API flags it for enhancement. The size check
      // only rejects when the shop opted into enforce_min_upload_px.
      const { signedId } = await uploadImageFile(file, {
        maxBytes: settings?.max_upload_bytes,
        minShortSide: settings?.min_upload_px,
        enforceMinShortSide: settings?.enforce_min_upload_px ?? false,
        onProgress,
      })
      const { design } = await api.createDesign(signedId)
      setDesigns((d) => [design, ...d])
      return design
    },
    [settings],
  )

  const remove = useCallback(async (design: Design) => {
    await api.deleteDesign(design.id)
    setDesigns((d) => d.filter((x) => x.id !== design.id))
  }, [])

  return { designs, upload, remove, reload }
}
