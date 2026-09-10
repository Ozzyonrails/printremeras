import { DirectUpload } from '@rails/activestorage'
import { getCsrfToken } from '../api/client'

export const ALLOWED_TYPES = ['image/png', 'image/jpeg', 'image/webp']
export const DEFAULT_MAX_BYTES = 20 * 1024 * 1024
const MAX_SHORT_SIDE = 3000

export type UploadProgress = (fraction: number) => void

export class UploadError extends Error {
  code: 'type' | 'size' | 'failed' | 'too_small'
  constructor(code: UploadError['code'], message: string) {
    super(message)
    this.code = code
  }
}

function loadImage(file: Blob): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file)
    const img = new Image()
    img.onload = () => {
      URL.revokeObjectURL(url)
      resolve(img)
    }
    img.onerror = () => {
      URL.revokeObjectURL(url)
      reject(new Error('unreadable'))
    }
    img.src = url
  })
}

export interface PreparedFile {
  blob: Blob
  filename: string
  contentType: string
  width: number
  height: number
}

export interface PrepareOptions {
  maxBytes?: number
  /** Recommended shorter side. Informational unless `enforceMinShortSide` is set. */
  minShortSide?: number
  /** Escape hatch mirroring settings.enforce_min_upload_px; off by default. */
  enforceMinShortSide?: boolean
}

/**
 * Hard limits only: MIME type and byte size. Small artwork is ACCEPTED — the server flags it
 * so it can be upscaled before printing — unless the shop turned `enforce_min_upload_px` on.
 * Images whose shorter side exceeds 3000px are downsized; smaller ones are passed through
 * untouched, so nothing is ever re-encoded below the resolution it arrived with.
 * PNG output keeps transparency; JPEG/WEBP are re-encoded as JPEG.
 */
export async function prepareImage(file: File, opts: PrepareOptions = {}): Promise<PreparedFile> {
  const type = file.type || 'application/octet-stream'
  if (!ALLOWED_TYPES.includes(type)) throw new UploadError('type', 'unsupported')
  const maxBytes = opts.maxBytes ?? DEFAULT_MAX_BYTES
  if (file.size > maxBytes) throw new UploadError('size', 'too_large')

  const img = await loadImage(file)
  const { naturalWidth: w, naturalHeight: h } = img
  const short = Math.min(w, h)
  if (opts.enforceMinShortSide && opts.minShortSide && short < opts.minShortSide) throw new UploadError('too_small', 'too_small')
  // Never downscale below MAX_SHORT_SIDE: anything at or under it goes up as-is.
  if (short <= MAX_SHORT_SIDE) return { blob: file, filename: file.name, contentType: type, width: w, height: h }

  const ratio = MAX_SHORT_SIDE / short
  const tw = Math.round(w * ratio)
  const th = Math.round(h * ratio)
  const canvas = document.createElement('canvas')
  canvas.width = tw
  canvas.height = th
  const ctx = canvas.getContext('2d')
  if (!ctx) return { blob: file, filename: file.name, contentType: type, width: w, height: h }
  ctx.drawImage(img, 0, 0, tw, th)
  const outType = type === 'image/png' ? 'image/png' : 'image/jpeg'
  const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, outType, 0.92))
  if (!blob) return { blob: file, filename: file.name, contentType: type, width: w, height: h }
  const ext = outType === 'image/png' ? 'png' : 'jpg'
  const filename = file.name.replace(/\.[^.]+$/, '') + '.' + ext
  if (blob.size > maxBytes) throw new UploadError('size', 'too_large')
  return { blob, filename, contentType: outType, width: tw, height: th }
}

/**
 * Direct-to-bucket upload through POST /api/v1/uploads (Rails DirectUpload protocol).
 * Resolves with the blob signed_id to hand to /designs, /orders/:n/review or /messages.
 */
export function directUpload(prepared: PreparedFile, onProgress?: UploadProgress, uploadUrl = '/api/v1/uploads', csrfToken?: string): Promise<string> {
  const file = new File([prepared.blob], prepared.filename, { type: prepared.contentType })
  const token = csrfToken || getCsrfToken()

  // @rails/activestorage sets X-CSRF-Token itself from <meta name="csrf-token"> while it
  // builds the request, before this delegate runs. XMLHttpRequest APPENDS on a repeated
  // setRequestHeader, so setting it again would send "tokenA, tokenB" and fail
  // verification — which is what broke uploads on the Rails-rendered admin pages, while
  // the SPA (no meta tag) was unaffected. Point the meta tag at the token we want and let
  // Active Storage send it; only add the header ourselves when the page has no meta tag.
  const meta = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')
  if (meta && token) meta.setAttribute('content', token)

  return new Promise((resolve, reject) => {
    const upload = new DirectUpload(file, uploadUrl, {
      directUploadWillCreateBlobWithXHR(xhr) {
        if (!meta) xhr.setRequestHeader('X-CSRF-Token', token)
        xhr.setRequestHeader('Accept', 'application/json')
        xhr.withCredentials = true
      },
      directUploadWillStoreFileWithXHR(xhr) {
        xhr.upload.addEventListener('progress', (e) => {
          if (e.lengthComputable && onProgress) onProgress(e.loaded / e.total)
        })
      },
    })
    upload.create((error, blob) => {
      if (error || !blob) reject(new UploadError('failed', String(error || 'upload failed')))
      else resolve(blob.signed_id)
    })
  })
}

/** Prepare + upload in one go, returning the signed_id and the original file dimensions. */
export async function uploadImageFile(file: File, opts: PrepareOptions & { onProgress?: UploadProgress } = {}) {
  const prepared = await prepareImage(file, opts)
  const signedId = await directUpload(prepared, opts.onProgress)
  return { signedId, prepared }
}
