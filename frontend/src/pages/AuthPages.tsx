import { useEffect, useState, type FormEvent } from 'react'
import { Link, Navigate, useNavigate, useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { api, setCsrfToken } from '../api/client'
import { useSession } from '../store/session'
import { AuthForm } from '../components/AuthForm'
import { ErrorBox, Field, Notice, PageLoading, PageTitle, PasswordInput, Spinner } from '../components/ui'

function AuthShell({ title, subtitle, children }: { title: string; subtitle?: string; children: React.ReactNode }) {
  return (
    <div className="container-page py-6">
      <div className="mx-auto max-w-md">
        <PageTitle subtitle={subtitle}>{title}</PageTitle>
        <div className="card p-4">{children}</div>
      </div>
    </div>
  )
}

export function LoginPage() {
  const { t } = useTranslation()
  const { user } = useSession()
  const navigate = useNavigate()
  if (user) return <Navigate to="/account" replace />
  return (
    <AuthShell title={t('auth.loginTitle')} subtitle={t('auth.loginSubtitle')}>
      <AuthForm initialMode="login" compact onSuccess={() => navigate('/account')} />
    </AuthShell>
  )
}

export function RegisterPage() {
  const { t } = useTranslation()
  const { user } = useSession()
  const navigate = useNavigate()
  if (user) return <Navigate to="/account" replace />
  return (
    <AuthShell title={t('auth.registerTitle')} subtitle={t('auth.loginSubtitle')}>
      <AuthForm initialMode="register" compact onSuccess={() => navigate('/account')} />
    </AuthShell>
  )
}

export function ForgotPasswordPage() {
  const { t } = useTranslation()
  const { errorMessage } = useSession()
  const [email, setEmail] = useState('')
  const [busy, setBusy] = useState(false)
  const [sent, setSent] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const submit = async (e: FormEvent) => {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      await api.requestPasswordReset(email)
      setSent(true)
    } catch (err) {
      setError(errorMessage(err))
    } finally {
      setBusy(false)
    }
  }
  return (
    <AuthShell title={t('auth.forgotTitle')} subtitle={t('auth.forgotSubtitle')}>
      {sent ? (
        <Notice kind="success">{t('auth.forgotSent')}</Notice>
      ) : (
        <form onSubmit={submit} className="space-y-3">
          <Field label={t('auth.email')}>
            <input className="input" type="email" required value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="email" />
          </Field>
          {error && <ErrorBox message={error} />}
          <button type="submit" className="btn-primary w-full" disabled={busy}>
            {busy ? <Spinner className="border-white/40 border-t-white" /> : t('common.send')}
          </button>
        </form>
      )}
      <Link to="/login" className="mt-3 inline-flex min-h-touch items-center text-sm underline">
        ← {t('auth.login')}
      </Link>
    </AuthShell>
  )
}

export function ResetPasswordPage() {
  const { token = '' } = useParams()
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { errorMessage, setUser, refresh } = useSession()
  const [password, setPassword] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const submit = async (e: FormEvent) => {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      const res = await api.resetPassword(token, password)
      setCsrfToken(res.csrf_token)
      setUser(res.user)
      await refresh()
      navigate('/account', { replace: true })
    } catch (err) {
      setError(errorMessage(err))
    } finally {
      setBusy(false)
    }
  }
  return (
    <AuthShell title={t('auth.resetTitle')}>
      <form onSubmit={submit} className="space-y-3">
        <Field label={t('account.newPassword')} hint={t('auth.passwordMin')}>
          <PasswordInput required minLength={8} value={password} onChange={setPassword} autoComplete="new-password" />
        </Field>
        {error && <ErrorBox message={error} />}
        <button type="submit" className="btn-primary w-full" disabled={busy}>
          {busy ? <Spinner className="border-white/40 border-t-white" /> : t('auth.resetSubmit')}
        </button>
      </form>
    </AuthShell>
  )
}

export function ConfirmPage() {
  const { token = '' } = useParams()
  const { t } = useTranslation()
  const { errorMessage, refresh } = useSession()
  const [state, setState] = useState<'loading' | 'ok' | 'error'>('loading')
  const [error, setError] = useState<string | null>(null)
  useEffect(() => {
    api
      .confirmEmail(token)
      .then(() => {
        setState('ok')
        void refresh()
      })
      .catch((e) => {
        setError(errorMessage(e))
        setState('error')
      })
  }, [token, errorMessage, refresh])
  return (
    <AuthShell title={t('auth.confirmTitle')}>
      {state === 'loading' && <PageLoading />}
      {state === 'ok' && <Notice kind="success">{t('auth.confirmed')}</Notice>}
      {state === 'error' && <Notice kind="error">{error || t('auth.confirmFailed')}</Notice>}
      <Link to="/account" className="btn-primary mt-4 w-full">
        {t('nav.account')}
      </Link>
    </AuthShell>
  )
}

export function NotFoundPage() {
  const { t } = useTranslation()
  return (
    <div className="container-page py-16 text-center">
      <h1 className="text-2xl font-bold">{t('common.notFound')}</h1>
      <p className="mt-2 text-ink-500">{t('common.notFoundBody')}</p>
      <Link to="/" className="btn-primary mt-6">
        {t('common.goHome')}
      </Link>
    </div>
  )
}
