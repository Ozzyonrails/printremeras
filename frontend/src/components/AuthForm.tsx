import { useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { useSession } from '../store/session'
import type { DevCredentialAccount } from '../api/types'
import { getCsrfToken } from '../api/client'
import { ErrorBox, Field, PasswordInput, Spinner } from './ui'

export type AuthMode = 'login' | 'register'

export function GoogleButton() {
  const { t } = useTranslation()
  const { settings } = useSession()
  if (!settings?.google_login) return null
  return (
    <form method="post" action="/auth/google_oauth2" className="w-full">
      <input type="hidden" name="authenticity_token" value={getCsrfToken()} />
      <button type="submit" className="btn-outline w-full">
        <svg width="18" height="18" viewBox="0 0 48 48" aria-hidden="true">
          <path fill="#EA4335" d="M24 9.5c3.5 0 6.6 1.2 9.1 3.5l6.8-6.8C35.8 2.5 30.3 0 24 0 14.6 0 6.5 5.4 2.6 13.3l7.9 6.1C12.4 13.6 17.7 9.5 24 9.5z" />
          <path fill="#4285F4" d="M46.5 24.5c0-1.6-.1-3.1-.4-4.5H24v8.5h12.7c-.6 3-2.3 5.5-4.8 7.2l7.7 6c4.5-4.2 6.9-10.3 6.9-17.2z" />
          <path fill="#FBBC05" d="M10.5 28.6A14.5 14.5 0 0 1 9.5 24c0-1.6.3-3.2.8-4.6l-7.9-6.1A24 24 0 0 0 0 24c0 3.9.9 7.5 2.6 10.7l7.9-6.1z" />
          <path fill="#34A853" d="M24 48c6.3 0 11.7-2.1 15.6-5.7l-7.7-6c-2.1 1.4-4.8 2.3-7.9 2.3-6.3 0-11.6-4.1-13.5-9.9l-7.9 6.1C6.5 42.6 14.6 48 24 48z" />
        </svg>
        {t('auth.google')}
      </button>
    </form>
  )
}

/** Login / register panel, shared by the auth modal, the auth pages and the checkout gate. */
export function AuthForm({ initialMode = 'login', onSuccess, compact = false }: { initialMode?: AuthMode; onSuccess?: () => void; compact?: boolean }) {
  const { t } = useTranslation()
  const { login, register, errorMessage } = useSession()
  const [mode, setMode] = useState<AuthMode>(initialMode)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [firstName, setFirstName] = useState('')
  const [lastName, setLastName] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit(e: FormEvent) {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      if (mode === 'login') await login(email, password)
      else await register({ email, password, first_name: firstName, last_name: lastName })
      onSuccess?.()
    } catch (err) {
      setError(errorMessage(err))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div>
      <div className="mb-4 inline-flex w-full rounded-xl bg-ink-100 p-1" role="tablist">
        {(['login', 'register'] as AuthMode[]).map((m) => (
          <button
            key={m}
            type="button"
            role="tab"
            aria-selected={mode === m}
            onClick={() => setMode(m)}
            className={`min-h-[40px] flex-1 rounded-lg text-sm font-semibold ${mode === m ? 'bg-white shadow' : 'text-ink-500'}`}
          >
            {t(m === 'login' ? 'auth.login' : 'auth.register')}
          </button>
        ))}
      </div>
      {!compact && <p className="mb-4 text-sm text-ink-500">{t('auth.loginSubtitle')}</p>}
      <form onSubmit={submit} className="space-y-3">
        {mode === 'register' && (
          <div className="grid grid-cols-2 gap-3">
            <Field label={t('auth.firstName')}>
              <input className="input" value={firstName} onChange={(e) => setFirstName(e.target.value)} autoComplete="given-name" />
            </Field>
            <Field label={t('auth.lastName')}>
              <input className="input" value={lastName} onChange={(e) => setLastName(e.target.value)} autoComplete="family-name" />
            </Field>
          </div>
        )}
        <Field label={t('auth.email')}>
          <input className="input" type="email" inputMode="email" required value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="email" />
        </Field>
        <Field label={t('auth.password')} hint={mode === 'register' ? t('auth.passwordMin') : undefined}>
          <PasswordInput
            required
            minLength={mode === 'register' ? 8 : undefined}
            value={password}
            onChange={setPassword}
            autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
          />
        </Field>
        {error && <ErrorBox message={error} />}
        <DevCredentialShortcuts
          onPick={(account) => {
            setMode('login')
            setEmail(account.email)
            setPassword(account.password)
            setError(null)
          }}
        />
        <button type="submit" className="btn-primary w-full" disabled={busy}>
          {busy ? <Spinner className="border-white/40 border-t-white" /> : t(mode === 'login' ? 'auth.login' : 'auth.register')}
        </button>
      </form>
      <div className="mt-3 flex items-center justify-between text-sm">
        {mode === 'login' ? (
          <Link to="/forgot-password" className="min-h-touch inline-flex items-center text-ink-700 underline">
            {t('auth.forgot')}
          </Link>
        ) : (
          <span />
        )}
        <button type="button" className="min-h-touch text-ink-700 underline" onClick={() => setMode(mode === 'login' ? 'register' : 'login')}>
          {mode === 'login' ? t('auth.noAccount') : t('auth.haveAccount')}
        </button>
      </div>
      <GoogleSection />
    </div>
  )
}

/**
 * Development-only sign-in shortcuts. The server sends `dev_credentials` for the seeded
 * demo accounts and omits the field entirely outside development, so nothing to hide here.
 */
function DevCredentialShortcuts({ onPick }: { onPick: (account: DevCredentialAccount) => void }) {
  const { t } = useTranslation()
  const { settings } = useSession()
  const dev = settings?.dev_credentials
  if (!dev) return null
  // Staff are AdminUser records and can only sign in at /admin, so listing them here
  // would offer a shortcut that always fails. Link to the admin panel instead.
  const accounts = dev.customers
  if (accounts.length === 0 && dev.staff.length === 0) return null
  return (
    <div className="rounded-xl border border-dashed border-ink-200 bg-ink-50 p-3">
      <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-ink-500">{t('auth.devAccounts')}</p>
      <div className="space-y-1.5">
        {accounts.map((account) => (
          <button
            key={account.email}
            type="button"
            onClick={() => onPick(account)}
            className="flex min-h-touch w-full flex-col items-start rounded-lg border border-ink-200 bg-white px-3 py-2 text-left hover:border-ink-900"
          >
            <span className="text-sm font-medium">
              {account.label} · {account.email}
            </span>
            <span className="font-mono text-xs text-ink-500">{account.password}</span>
          </button>
        ))}
      </div>
      {accounts.length > 0 && <p className="mt-2 text-xs text-ink-500">{t('auth.devAccountsHint')}</p>}
      {dev.staff.length > 0 && (
        <p className="mt-2 text-xs text-ink-500">
          {t('auth.devStaffHint')}{' '}
          <a href="/admin" className="font-medium underline">
            /admin
          </a>
        </p>
      )}
      {dev.forced && <p className="mt-2 rounded-md bg-amber-100 px-2 py-1 text-xs text-amber-900">{t('auth.devAccountsForced')}</p>}
    </div>
  )
}

function GoogleSection() {
  const { t } = useTranslation()
  const { settings } = useSession()
  if (!settings?.google_login) return null
  return (
    <div className="mt-4">
      <div className="mb-3 flex items-center gap-3 text-xs uppercase text-ink-500">
        <span className="h-px flex-1 bg-ink-100" />
        {t('auth.or')}
        <span className="h-px flex-1 bg-ink-100" />
      </div>
      <GoogleButton />
    </div>
  )
}
