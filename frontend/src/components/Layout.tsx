import { useEffect } from 'react'
import { Link, NavLink, Outlet, useLocation } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { useSession } from '../store/session'
import { LOCALES } from '../i18n'
import { AuthForm } from './AuthForm'
import { Sheet } from './ui'

function Badge({ n }: { n: number }) {
  if (n <= 0) return null
  return (
    <span className="absolute -right-1 -top-1 min-w-[18px] rounded-full bg-brand-500 px-1 text-center text-[11px] font-bold leading-[18px] text-ink-900">
      {n > 99 ? '99+' : n}
    </span>
  )
}

const Icon = {
  home: <path d="M3 11.5 12 4l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1v-8.5z" />,
  catalog: <path d="M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z" />,
  cart: <path d="M3 4h2l2.4 11h11.2L21 7H7M9 20a1 1 0 1 0 0-2 1 1 0 0 0 0 2zm9 0a1 1 0 1 0 0-2 1 1 0 0 0 0 2z" />,
  messages: <path d="M4 5h16v11H8l-4 4V5z" />,
  account: <path d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zm-8 9a8 8 0 0 1 16 0" />,
}

function SvgIcon({ name }: { name: keyof typeof Icon }) {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      {Icon[name]}
    </svg>
  )
}

export function LanguageSwitcher({ className = '' }: { className?: string }) {
  const { t } = useTranslation()
  const { locale, setLocale } = useSession()
  return (
    <label className={`inline-flex items-center gap-2 ${className}`}>
      <span className="sr-only">{t('lang.label')}</span>
      <select className="input min-h-[40px] w-auto py-0 pr-8 text-sm" value={locale} onChange={(e) => void setLocale(e.target.value)} aria-label={t('lang.label')}>
        {Object.entries(LOCALES).map(([code, { label }]) => (
          <option key={code} value={code}>
            {label}
          </option>
        ))}
      </select>
    </label>
  )
}

function TopBar() {
  const { t } = useTranslation()
  const { user, cartQuantity, unreadMessages, settings } = useSession()
  const linkCls = ({ isActive }: { isActive: boolean }) => `relative inline-flex min-h-touch min-w-touch items-center justify-center rounded-xl px-2 ${isActive ? 'text-ink-900' : 'text-ink-500'}`
  return (
    <header className="sticky top-0 z-40 border-b border-ink-100 bg-white/95 backdrop-blur">
      <div className="container-page flex h-14 items-center justify-between gap-2">
        <Link to="/" className="flex min-h-touch items-center gap-2 text-lg font-extrabold tracking-tight">
          <span className="inline-block h-7 w-7 rounded-lg bg-ink-900 text-center text-sm leading-7 text-brand-500">P</span>
          {settings?.store_name || t('common.appName')}
        </Link>
        <nav className="hidden items-center gap-1 sm:flex" aria-label="main">
          <NavLink to="/templates" className={linkCls}>{t('nav.templates')}</NavLink>
          <NavLink to="/catalog" className={linkCls}>{t('nav.catalog')}</NavLink>
          <NavLink to="/reviews" className={linkCls}>{t('nav.reviews')}</NavLink>
          {user && <NavLink to="/orders" className={linkCls}>{t('nav.orders')}</NavLink>}
        </nav>
        <div className="flex items-center gap-1">
          <LanguageSwitcher className="hidden sm:inline-flex" />
          <NavLink to="/messages" className={linkCls} aria-label={t('nav.messages')}>
            <SvgIcon name="messages" />
            <Badge n={unreadMessages} />
          </NavLink>
          <NavLink to="/cart" className={linkCls} aria-label={t('nav.cart')}>
            <SvgIcon name="cart" />
            <Badge n={cartQuantity} />
          </NavLink>
          <NavLink to="/account" className={linkCls} aria-label={t('nav.account')}>
            <SvgIcon name="account" />
          </NavLink>
        </div>
      </div>
    </header>
  )
}

function BottomTabs() {
  const { t } = useTranslation()
  const { cartQuantity, unreadMessages } = useSession()
  const tabs: { to: string; icon: keyof typeof Icon; label: string; badge?: number }[] = [
    { to: '/', icon: 'home', label: t('nav.home') },
    { to: '/catalog', icon: 'catalog', label: t('nav.catalog') },
    { to: '/cart', icon: 'cart', label: t('nav.cart'), badge: cartQuantity },
    { to: '/messages', icon: 'messages', label: t('nav.messages'), badge: unreadMessages },
    { to: '/account', icon: 'account', label: t('nav.account') },
  ]
  return (
    <nav className="fixed inset-x-0 bottom-0 z-40 border-t border-ink-100 bg-white sm:hidden" style={{ paddingBottom: 'env(safe-area-inset-bottom)' }} aria-label="tabs">
      <ul className="grid grid-cols-5">
        {tabs.map((tab) => (
          <li key={tab.to}>
            <NavLink
              to={tab.to}
              end={tab.to === '/'}
              className={({ isActive }) => `flex min-h-[56px] flex-col items-center justify-center gap-0.5 text-[11px] font-medium ${isActive ? 'text-ink-900' : 'text-ink-500'}`}
            >
              <span className="relative">
                <SvgIcon name={tab.icon} />
                <Badge n={tab.badge ?? 0} />
              </span>
              {tab.label}
            </NavLink>
          </li>
        ))}
      </ul>
    </nav>
  )
}

function AuthModal() {
  const { t } = useTranslation()
  const { authModalOpen, closeAuthModal } = useSession()
  return (
    <Sheet open={authModalOpen} onClose={closeAuthModal} title={t('auth.loginTitle')}>
      <p className="mb-3 text-sm text-ink-500">{t('auth.loginRequired')}</p>
      <AuthForm compact />
    </Sheet>
  )
}

function Toasts() {
  const { toasts, dismissToast } = useSession()
  if (toasts.length === 0) return null
  return (
    <div className="pointer-events-none fixed inset-x-0 top-16 z-50 flex flex-col items-center gap-2 px-4">
      {toasts.map((toast) => (
        <button
          key={toast.id}
          type="button"
          onClick={() => dismissToast(toast.id)}
          className={`pointer-events-auto max-w-md rounded-xl px-4 py-3 text-sm font-medium shadow-lg ${
            toast.kind === 'error' ? 'bg-red-600 text-white' : toast.kind === 'success' ? 'bg-emerald-600 text-white' : 'bg-ink-900 text-white'
          }`}
        >
          {toast.text}
        </button>
      ))}
    </div>
  )
}

export function Layout() {
  const location = useLocation()
  useEffect(() => {
    window.scrollTo({ top: 0 })
  }, [location.pathname])
  return (
    <div className="flex min-h-screen flex-col">
      <TopBar />
      <main className="flex-1 page-bottom-pad sm:pb-10">
        <Outlet />
      </main>
      <footer className="hidden border-t border-ink-100 py-6 text-center text-xs text-ink-500 sm:block">© Printremeras · CABA</footer>
      <BottomTabs />
      <AuthModal />
      <Toasts />
    </div>
  )
}
