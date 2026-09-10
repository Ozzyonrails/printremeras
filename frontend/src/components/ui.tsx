import { useEffect, useState, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { formatMoney } from '../lib/money'

export function Spinner({ className = '' }: { className?: string }) {
  return (
    <span
      className={`inline-block h-5 w-5 animate-spin rounded-full border-2 border-ink-300 border-t-ink-900 ${className}`}
      role="status"
      aria-label="loading"
    />
  )
}

export function PageLoading() {
  const { t } = useTranslation()
  return (
    <div className="flex items-center justify-center gap-3 py-20 text-ink-500">
      <Spinner /> <span>{t('common.loading')}</span>
    </div>
  )
}

export function ErrorBox({ message, onRetry, className = '' }: { message: string; onRetry?: () => void; className?: string }) {
  const { t } = useTranslation()
  return (
    <div className={`rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-800 ${className}`} role="alert">
      <p>{message}</p>
      {onRetry && (
        <button type="button" onClick={onRetry} className="btn-outline mt-3 text-sm">
          {t('common.retry')}
        </button>
      )}
    </div>
  )
}

export function Notice({ kind = 'info', children, className = '' }: { kind?: 'info' | 'success' | 'warning' | 'error'; children: ReactNode; className?: string }) {
  const styles = {
    info: 'border-sky-200 bg-sky-50 text-sky-900',
    success: 'border-emerald-200 bg-emerald-50 text-emerald-900',
    warning: 'border-amber-200 bg-amber-50 text-amber-900',
    error: 'border-red-200 bg-red-50 text-red-900',
  }[kind]
  return <div className={`rounded-xl border p-4 text-sm ${styles} ${className}`}>{children}</div>
}

export function Money({ cents, className = '' }: { cents: number | null | undefined; className?: string }) {
  return <span className={`tabular-nums ${className}`}>{formatMoney(cents)}</span>
}

export function PageTitle({ children, subtitle, action }: { children: ReactNode; subtitle?: ReactNode; action?: ReactNode }) {
  return (
    <div className="mb-5 flex items-start justify-between gap-3">
      <div>
        <h1 className="text-2xl font-bold tracking-tight sm:text-3xl">{children}</h1>
        {subtitle && <p className="mt-1 text-ink-500">{subtitle}</p>}
      </div>
      {action}
    </div>
  )
}

/** Bottom sheet on phones, centred dialog from sm: upwards. */
export function Sheet({ open, onClose, title, children, wide = false }: { open: boolean; onClose: () => void; title?: ReactNode; children: ReactNode; wide?: boolean }) {
  const { t } = useTranslation()
  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose()
    document.addEventListener('keydown', onKey)
    const prev = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => {
      document.removeEventListener('keydown', onKey)
      document.body.style.overflow = prev
    }
  }, [open, onClose])
  if (!open) return null
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center sm:items-center" role="dialog" aria-modal="true">
      <button type="button" className="absolute inset-0 bg-black/40" aria-label={t('common.close')} onClick={onClose} />
      <div
        className={`relative flex max-h-[92vh] w-full flex-col rounded-t-3xl bg-white shadow-xl sm:rounded-3xl ${wide ? 'sm:max-w-2xl' : 'sm:max-w-md'}`}
        style={{ paddingBottom: 'env(safe-area-inset-bottom)' }}
      >
        <div className="flex items-center justify-between px-5 pt-4 pb-2">
          <div className="mx-auto h-1.5 w-10 rounded-full bg-ink-300 sm:hidden absolute left-1/2 top-2 -translate-x-1/2" />
          <h2 className="text-lg font-semibold mt-2">{title}</h2>
          <button type="button" onClick={onClose} className="btn-secondary -mr-2 mt-2 h-11 w-11 rounded-full px-0" aria-label={t('common.close')}>
            ✕
          </button>
        </div>
        <div className="overflow-y-auto px-5 pb-5">{children}</div>
      </div>
    </div>
  )
}

export function Segmented<T extends string>({ value, options, onChange, className = '' }: { value: T; options: { value: T; label: ReactNode }[]; onChange: (v: T) => void; className?: string }) {
  return (
    <div className={`inline-flex rounded-xl bg-ink-100 p-1 ${className}`} role="tablist">
      {options.map((o) => (
        <button
          key={o.value}
          type="button"
          role="tab"
          aria-selected={o.value === value}
          onClick={() => onChange(o.value)}
          className={`min-h-[40px] flex-1 rounded-lg px-4 text-sm font-semibold transition-colors ${o.value === value ? 'bg-white text-ink-900 shadow' : 'text-ink-500'}`}
        >
          {o.label}
        </button>
      ))}
    </div>
  )
}

export function Stepper({ value, min = 1, max = 99, onChange, label }: { value: number; min?: number; max?: number; onChange: (v: number) => void; label?: string }) {
  return (
    <div className="inline-flex items-center rounded-xl border border-ink-300" aria-label={label}>
      <button type="button" className="min-h-touch min-w-touch text-xl" onClick={() => onChange(Math.max(min, value - 1))} disabled={value <= min} aria-label="−">
        −
      </button>
      <span className="w-10 text-center font-semibold tabular-nums">{value}</span>
      <button type="button" className="min-h-touch min-w-touch text-xl" onClick={() => onChange(Math.min(max, value + 1))} disabled={value >= max} aria-label="+">
        +
      </button>
    </div>
  )
}

export function Stars({ value, onChange, size = 'md' }: { value: number; onChange?: (v: number) => void; size?: 'sm' | 'md' | 'lg' }) {
  const { t } = useTranslation()
  const cls = size === 'lg' ? 'text-4xl h-12 w-12' : size === 'sm' ? 'text-sm h-5 w-5' : 'text-xl h-8 w-8'
  return (
    <div className="inline-flex" role={onChange ? 'radiogroup' : undefined} aria-label={t('review.rating')}>
      {[1, 2, 3, 4, 5].map((n) => {
        const filled = n <= value
        const star = (
          <span className={`${cls} inline-flex items-center justify-center ${filled ? 'text-brand-500' : 'text-ink-300'}`} aria-hidden="true">
            ★
          </span>
        )
        return onChange ? (
          <button key={n} type="button" role="radio" aria-checked={n === value} aria-label={t('review.stars', { count: n })} onClick={() => onChange(n)} className="min-h-touch min-w-touch">
            {star}
          </button>
        ) : (
          <span key={n}>{star}</span>
        )
      })}
    </div>
  )
}

export function Field({ label, children, hint, error }: { label: string; children: ReactNode; hint?: string; error?: string }) {
  return (
    <label className="block">
      <span className="label">{label}</span>
      {children}
      {hint && !error && <span className="mt-1 block text-xs text-ink-500">{hint}</span>}
      {error && <span className="mt-1 block text-xs text-red-700">{error}</span>}
    </label>
  )
}

/**
 * Password input with a show/hide toggle. The eye sits inside the field, keeps a 44px
 * touch target, and reports its state to screen readers; the visible/hidden state is
 * announced rather than implied by the icon alone.
 */
export function PasswordInput({
  value,
  onChange,
  autoComplete,
  required = false,
  minLength,
  autoFocus = false,
  id,
}: {
  value: string
  onChange: (value: string) => void
  autoComplete?: string
  required?: boolean
  minLength?: number
  autoFocus?: boolean
  id?: string
}) {
  const { t } = useTranslation()
  const [visible, setVisible] = useState(false)
  return (
    <div className="relative">
      <input
        id={id}
        className="input pr-12"
        type={visible ? 'text' : 'password'}
        required={required}
        minLength={minLength}
        autoFocus={autoFocus}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        autoComplete={autoComplete}
      />
      <button
        type="button"
        onClick={() => setVisible((v) => !v)}
        aria-label={t(visible ? 'auth.hidePassword' : 'auth.showPassword')}
        aria-pressed={visible}
        title={t(visible ? 'auth.hidePassword' : 'auth.showPassword')}
        className="absolute right-0 top-0 flex h-full w-12 items-center justify-center text-ink-500 hover:text-ink-900"
      >
        {visible ? <EyeOffIcon /> : <EyeIcon />}
      </button>
    </div>
  )
}

function EyeIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M1.5 12S5 5.5 12 5.5 22.5 12 22.5 12 19 18.5 12 18.5 1.5 12 1.5 12Z" />
      <circle cx="12" cy="12" r="3.2" />
    </svg>
  )
}

function EyeOffIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M9.9 5.7A9.9 9.9 0 0 1 12 5.5c7 0 10.5 6.5 10.5 6.5a17.6 17.6 0 0 1-3.6 4.4M6.3 7.6A17.4 17.4 0 0 0 1.5 12S5 18.5 12 18.5c1.6 0 3-.3 4.2-.9" />
      <path d="m10 10a2.8 2.8 0 0 0 4 4" />
      <path d="m3 3 18 18" />
    </svg>
  )
}

export function ProgressBar({ value }: { value: number }) {
  return (
    <div className="h-2 w-full overflow-hidden rounded-full bg-ink-100" role="progressbar" aria-valuenow={Math.round(value * 100)} aria-valuemin={0} aria-valuemax={100}>
      <div className="h-full bg-brand-500 transition-[width]" style={{ width: `${Math.round(value * 100)}%` }} />
    </div>
  )
}
