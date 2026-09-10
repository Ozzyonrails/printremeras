import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import type { Design, PlacementInput, TemplateFull } from '../api/types'
import { DesignEditor } from '../editor/DesignEditor'
import { fromServerPlacements } from '../editor/types'
import { directUpload, prepareImage } from '../lib/upload'
import { Field } from '../components/ui'

export interface AdminDesignEditorProps {
  template: TemplateFull
  placements: { print_area_id: number; design: Design; x: number; y: number; scale: number; rotation: number }[]
  designs: Design[]
  saveUrl: string
  csrfToken: string
  uploadUrl?: string
  designCreateUrl?: string
}

async function postJson<T>(url: string, method: string, body: unknown, csrfToken: string): Promise<T> {
  const res = await fetch(url, {
    method,
    headers: { 'Content-Type': 'application/json', Accept: 'application/json', 'X-CSRF-Token': csrfToken },
    credentials: 'same-origin',
    body: JSON.stringify(body),
  })
  const text = await res.text()
  let data: unknown = null
  try {
    data = text ? JSON.parse(text) : null
  } catch {
    /* non-JSON error page */
  }
  if (!res.ok) {
    const err = data as { error?: string; errors?: string[] } | null
    throw Object.assign(new Error(err?.error || res.statusText), { errors: err?.errors || [err?.error || res.statusText] })
  }
  return data as T
}

/**
 * The CSRF token is baked into the page at render time, so it goes stale whenever the
 * session rotates (signing in on the storefront in another tab, for instance). Ask the
 * server for the current one right before a write instead of trusting the rendered value.
 */
async function currentCsrfToken(fallback: string): Promise<string> {
  try {
    const res = await fetch('/api/v1/session', { headers: { Accept: 'application/json' }, credentials: 'same-origin' })
    const header = res.headers.get('X-CSRF-Token')
    if (header) return header
    const data = (await res.json()) as { csrf_token?: string }
    return data.csrf_token || fallback
  } catch {
    return fallback
  }
}

/** DesignEditor in admin mode: catalog design library with licence notes, Save PATCHes placements. */
export function AdminDesignEditor(props: AdminDesignEditorProps) {
  const { t } = useTranslation()
  const uploadUrl = props.uploadUrl || '/api/v1/uploads'
  const designCreateUrl = props.designCreateUrl || '/admin/designs'
  const [designs, setDesigns] = useState<Design[]>(props.designs || [])
  const [licenseNote, setLicenseNote] = useState('')
  const [saving, setSaving] = useState(false)
  const [saveError, setSaveError] = useState<string | null>(null)
  const initial = useMemo(() => fromServerPlacements(props.placements || []), [props.placements])

  const onUpload = async (file: File, onProgress: (f: number) => void) => {
    // The licence note is a record for the shop, not a gate: an empty one is fine.
    const note = licenseNote.trim()
    const prepared = await prepareImage(file)
    const token = await currentCsrfToken(props.csrfToken)
    const signedId = await directUpload(prepared, onProgress, uploadUrl, token)
    const { design } = await postJson<{ design: Design }>(designCreateUrl, 'POST', { signed_id: signedId, license_note: note || null }, token)
    setDesigns((d) => [design, ...d])
    setLicenseNote('')
    return design
  }

  const onSubmit = async (placements: PlacementInput[]) => {
    setSaving(true)
    setSaveError(null)
    try {
      await postJson(props.saveUrl, 'PATCH', { placements }, await currentCsrfToken(props.csrfToken))
      window.location.reload()
    } catch (e) {
      const err = e as { errors?: string[]; message?: string }
      setSaveError(err.errors?.join(' ') || err.message || t('admin.saveFailed'))
      setSaving(false)
    }
  }

  return (
    <DesignEditor
      template={props.template}
      mode="admin"
      initialPlacements={initial}
      designs={designs}
      onUpload={onUpload}
      uploadExtra={
        <Field label={t('editor.licenseNote')} hint={t('editor.licenseOptional')}>
          <input className="input" value={licenseNote} onChange={(e) => setLicenseNote(e.target.value)} placeholder={t('editor.licensePlaceholder')} />
        </Field>
      }
      submitLabel={saving ? t('editor.saving') : t('editor.saveTemplate')}
      submitting={saving}
      submitError={saveError}
      onSubmit={onSubmit}
    />
  )
}
