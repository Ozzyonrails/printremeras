import { useState, type FormEvent } from 'react'
import { useTranslation } from 'react-i18next'
import type { Address, AddressInput } from '../api/types'
import { ErrorBox, Field, Spinner } from './ui'

const EMPTY: AddressInput = { recipient_name: '', phone: '', street: '', number: '', apartment: '', floor: '', neighborhood: '', postal_code: '', city: 'CABA', notes: '' }

export function AddressForm({
  initial,
  onSubmit,
  onCancel,
  submitLabel,
  error,
  showDefault = false,
}: {
  initial?: Address | null
  onSubmit: (a: AddressInput) => Promise<void>
  onCancel?: () => void
  submitLabel: string
  error?: string | null
  showDefault?: boolean
}) {
  const { t } = useTranslation()
  const [form, setForm] = useState<AddressInput>(() => (initial ? { ...EMPTY, ...stripAddress(initial) } : EMPTY))
  const [busy, setBusy] = useState(false)
  const set = (k: keyof AddressInput) => (e: { target: { value: string } }) => setForm((f) => ({ ...f, [k]: e.target.value }))

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    setBusy(true)
    try {
      await onSubmit(form)
    } finally {
      setBusy(false)
    }
  }

  return (
    <form onSubmit={submit} className="space-y-3">
      <Field label={t('address.recipient')}>
        <input className="input" required value={form.recipient_name} onChange={set('recipient_name')} autoComplete="name" />
      </Field>
      <Field label={t('address.phone')}>
        <input className="input" type="tel" inputMode="tel" value={form.phone ?? ''} onChange={set('phone')} autoComplete="tel" />
      </Field>
      <div className="grid grid-cols-[1fr_100px] gap-3">
        <Field label={t('address.street')}>
          <input className="input" required value={form.street} onChange={set('street')} autoComplete="address-line1" />
        </Field>
        <Field label={t('address.number')}>
          <input className="input" inputMode="numeric" value={form.number ?? ''} onChange={set('number')} />
        </Field>
      </div>
      <div className="grid grid-cols-2 gap-3">
        <Field label={`${t('address.floor')} (${t('common.optional')})`}>
          <input className="input" value={form.floor ?? ''} onChange={set('floor')} />
        </Field>
        <Field label={`${t('address.apartment')} (${t('common.optional')})`}>
          <input className="input" value={form.apartment ?? ''} onChange={set('apartment')} />
        </Field>
      </div>
      <Field label={t('address.neighborhood')}>
        <input className="input" value={form.neighborhood ?? ''} onChange={set('neighborhood')} autoComplete="address-level3" />
      </Field>
      <div className="grid grid-cols-2 gap-3">
        <Field label={t('address.postalCode')} hint={t('address.cabaHint')}>
          <input className="input" required inputMode="numeric" value={form.postal_code} onChange={set('postal_code')} autoComplete="postal-code" />
        </Field>
        <Field label={t('address.city')}>
          <input className="input" required value={form.city} onChange={set('city')} autoComplete="address-level2" />
        </Field>
      </div>
      <Field label={`${t('address.notes')} (${t('common.optional')})`}>
        <textarea className="input py-2" rows={2} value={form.notes ?? ''} onChange={set('notes')} />
      </Field>
      {showDefault && (
        <label className="flex min-h-touch items-center gap-2 text-sm">
          <input type="checkbox" className="h-5 w-5" checked={!!form.is_default} onChange={(e) => setForm((f) => ({ ...f, is_default: e.target.checked }))} />
          {t('address.setDefault')}
        </label>
      )}
      {error && <ErrorBox message={error} />}
      <div className="flex gap-2">
        {onCancel && (
          <button type="button" className="btn-secondary" onClick={onCancel}>
            {t('common.cancel')}
          </button>
        )}
        <button type="submit" className="btn-primary flex-1" disabled={busy}>
          {busy ? <Spinner className="border-white/40 border-t-white" /> : submitLabel}
        </button>
      </div>
    </form>
  )
}

function stripAddress(a: Address): AddressInput {
  const { id: _id, one_line: _ol, ...rest } = a
  return rest
}
