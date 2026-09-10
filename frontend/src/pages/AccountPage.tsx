import { useCallback, useEffect, useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { api, ApiError } from '../api/client'
import type { Address, AddressInput } from '../api/types'
import { useSession } from '../store/session'
import { AuthForm } from '../components/AuthForm'
import { AddressForm } from '../components/AddressForm'
import { LanguageSwitcher } from '../components/Layout'
import { ErrorBox, Field, Notice, PageTitle, PasswordInput, Sheet, Spinner } from '../components/ui'

export function AccountPage() {
  const { t } = useTranslation()
  const { user, setUser, logout, errorMessage, toast } = useSession()

  if (!user) {
    return (
      <div className="container-page py-6">
        <PageTitle subtitle={t('account.guestBody')}>{t('account.guestTitle')}</PageTitle>
        <div className="card p-4 sm:max-w-md">
          <AuthForm compact />
        </div>
        <div className="mt-6 flex items-center gap-3 sm:hidden">
          <span className="text-sm text-ink-500">{t('lang.label')}</span>
          <LanguageSwitcher />
        </div>
      </div>
    )
  }

  return (
    <div className="container-page py-6">
      <PageTitle subtitle={user.email}>{t('account.title')}</PageTitle>
      <div className="grid gap-6 lg:grid-cols-2">
        <div className="space-y-6">
          {!user.confirmed && <UnconfirmedNotice />}
          <ProfileForm />
          <PasswordForm />
          <section className="card p-4">
            <div className="flex items-center justify-between">
              <span className="font-semibold">{t('account.language')}</span>
              <LanguageSwitcher />
            </div>
          </section>
          <div className="flex flex-col gap-2 sm:flex-row">
            <Link to="/orders" className="btn-secondary flex-1">
              {t('account.orders')}
            </Link>
            <button
              type="button"
              className="btn-outline flex-1"
              onClick={() =>
                logout()
                  .then(() => setUser(null))
                  .catch((e) => toast(errorMessage(e), 'error'))
              }
            >
              {t('account.logout')}
            </button>
          </div>
        </div>
        <AddressBook />
      </div>
    </div>
  )
}

function UnconfirmedNotice() {
  const { t } = useTranslation()
  const { toast, errorMessage } = useSession()
  const [sent, setSent] = useState(false)
  return (
    <Notice kind="warning">
      {t('account.unconfirmed')}{' '}
      {sent ? (
        <span className="font-medium">{t('account.confirmationSent')}</span>
      ) : (
        <button type="button" className="min-h-touch font-semibold underline" onClick={() => api.resendConfirmation().then(() => setSent(true)).catch((e) => toast(errorMessage(e), 'error'))}>
          {t('account.resendConfirmation')}
        </button>
      )}
    </Notice>
  )
}

function ProfileForm() {
  const { t } = useTranslation()
  const { user, setUser, errorMessage, toast } = useSession()
  const [firstName, setFirstName] = useState(user?.first_name || '')
  const [lastName, setLastName] = useState(user?.last_name || '')
  const [phone, setPhone] = useState(user?.phone || '')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      const { user } = await api.updateProfile({ first_name: firstName, last_name: lastName, phone })
      setUser(user)
      toast(t('account.saved'), 'success')
    } catch (err) {
      setError(errorMessage(err))
    } finally {
      setBusy(false)
    }
  }

  return (
    <form onSubmit={submit} className="card space-y-3 p-4">
      <h2 className="text-lg font-bold">{t('account.profile')}</h2>
      {user?.google && <p className="text-xs text-ink-500">{t('account.googleLinked')}</p>}
      <div className="grid grid-cols-2 gap-3">
        <Field label={t('account.firstName')}>
          <input className="input" value={firstName} onChange={(e) => setFirstName(e.target.value)} autoComplete="given-name" />
        </Field>
        <Field label={t('account.lastName')}>
          <input className="input" value={lastName} onChange={(e) => setLastName(e.target.value)} autoComplete="family-name" />
        </Field>
      </div>
      <Field label={t('account.phone')}>
        <input className="input" type="tel" inputMode="tel" value={phone} onChange={(e) => setPhone(e.target.value)} autoComplete="tel" />
      </Field>
      {error && <ErrorBox message={error} />}
      <button type="submit" className="btn-primary w-full" disabled={busy}>
        {busy ? <Spinner className="border-white/40 border-t-white" /> : t('common.save')}
      </button>
    </form>
  )
}

function PasswordForm() {
  const { t } = useTranslation()
  const { user, setUser, errorMessage, toast } = useSession()
  const [current, setCurrent] = useState('')
  const [password, setPassword] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const hasPassword = !!user?.has_password

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      const { user } = await api.updateProfile({ password, current_password: hasPassword ? current : undefined })
      setUser(user)
      setCurrent('')
      setPassword('')
      toast(t('account.passwordSaved'), 'success')
    } catch (err) {
      setError(err instanceof ApiError ? err.errors.join(' ') : errorMessage(err))
    } finally {
      setBusy(false)
    }
  }

  return (
    <form onSubmit={submit} className="card space-y-3 p-4">
      <h2 className="text-lg font-bold">{hasPassword ? t('account.changePassword') : t('account.setPassword')}</h2>
      {hasPassword && (
        <Field label={t('account.currentPassword')}>
          <PasswordInput required value={current} onChange={setCurrent} autoComplete="current-password" />
        </Field>
      )}
      <Field label={t('account.newPassword')} hint={t('auth.passwordMin')}>
        <PasswordInput required minLength={8} value={password} onChange={setPassword} autoComplete="new-password" />
      </Field>
      {error && <ErrorBox message={error} />}
      <button type="submit" className="btn-secondary w-full" disabled={busy}>
        {busy ? <Spinner /> : t('common.save')}
      </button>
    </form>
  )
}

function AddressBook() {
  const { t } = useTranslation()
  const { errorMessage, toast } = useSession()
  const [addresses, setAddresses] = useState<Address[] | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [editing, setEditing] = useState<Address | 'new' | null>(null)
  const [formError, setFormError] = useState<string | null>(null)

  const load = useCallback(() => {
    api.addresses().then((r) => setAddresses(r.addresses)).catch((e) => setError(errorMessage(e)))
  }, [errorMessage])
  useEffect(load, [load])

  const save = async (input: AddressInput) => {
    setFormError(null)
    try {
      if (editing === 'new') await api.createAddress(input)
      else if (editing) await api.updateAddress(editing.id, input)
      setEditing(null)
      toast(t('address.saved'), 'success')
      load()
    } catch (e) {
      setFormError(e instanceof ApiError ? e.errors.join(' ') : errorMessage(e))
    }
  }

  const remove = async (a: Address) => {
    if (!window.confirm(t('address.confirmDelete'))) return
    try {
      await api.deleteAddress(a.id)
      toast(t('address.deleted'), 'success')
      load()
    } catch (e) {
      toast(errorMessage(e), 'error')
    }
  }

  const makeDefault = async (a: Address) => {
    try {
      await api.updateAddress(a.id, { is_default: true })
      load()
    } catch (e) {
      toast(errorMessage(e), 'error')
    }
  }

  return (
    <section className="card p-4">
      <div className="mb-3 flex items-center justify-between">
        <h2 className="text-lg font-bold">{t('account.addresses')}</h2>
        <button type="button" className="btn-secondary text-sm" onClick={() => { setFormError(null); setEditing('new') }}>
          {t('address.add')}
        </button>
      </div>
      {error && <ErrorBox message={error} onRetry={load} />}
      {addresses && addresses.length === 0 && <p className="text-sm text-ink-500">{t('address.empty')}</p>}
      {addresses && (
        <ul className="space-y-2">
          {addresses.map((a) => (
            <li key={a.id} className="rounded-xl border border-ink-100 p-3 text-sm">
              <p className="flex items-center justify-between font-semibold">
                {a.recipient_name}
                {a.is_default && <span className="chip text-xs">{t('address.default')}</span>}
              </p>
              <p className="text-ink-700">{a.one_line}</p>
              {a.phone && <p className="text-ink-500">{a.phone}</p>}
              <div className="mt-2 flex flex-wrap gap-3">
                <button type="button" className="min-h-touch underline" onClick={() => { setFormError(null); setEditing(a) }}>
                  {t('common.edit')}
                </button>
                {!a.is_default && (
                  <button type="button" className="min-h-touch underline" onClick={() => void makeDefault(a)}>
                    {t('address.setDefault')}
                  </button>
                )}
                <button type="button" className="min-h-touch text-red-700 underline" onClick={() => void remove(a)}>
                  {t('common.delete')}
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}
      <Sheet open={editing !== null} onClose={() => setEditing(null)} title={editing === 'new' ? t('address.add') : t('address.edit')}>
        {editing !== null && (
          <AddressForm key={editing === 'new' ? 'new' : editing.id} initial={editing === 'new' ? null : editing} onSubmit={save} onCancel={() => setEditing(null)} submitLabel={t('common.save')} error={formError} showDefault />
        )}
      </Sheet>
    </section>
  )
}
