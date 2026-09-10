import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import i18n, { DEFAULT_LOCALE, LOCALE_STORAGE_KEY, supportedLocales } from '../i18n'
import { api, ApiError, setApiLocale, setCsrfToken, setLoginRequiredHandler, type AuthResponse } from '../api/client'
import type { PublicSettings, SessionPayload, User } from '../api/types'
import { disconnectCable } from '../lib/cable'

export interface Toast {
  id: number
  kind: 'success' | 'error' | 'info'
  text: string
}

interface SessionState {
  ready: boolean
  bootError: string | null
  user: User | null
  settings: PublicSettings | null
  cartQuantity: number
  unreadMessages: number
  locale: string
  authModalOpen: boolean
  toasts: Toast[]
}

interface SessionContextValue extends SessionState {
  refresh: () => Promise<SessionPayload | null>
  login: (email: string, password: string) => Promise<User>
  register: (params: { email: string; password: string; first_name?: string; last_name?: string }) => Promise<User>
  logout: () => Promise<void>
  /** Opens the auth modal and resolves true once the user is logged in (false if dismissed). */
  requireLogin: () => Promise<boolean>
  closeAuthModal: () => void
  setCartQuantity: (n: number) => void
  setUnreadMessages: (n: number) => void
  setUser: (u: User | null) => void
  setLocale: (locale: string) => Promise<void>
  toast: (text: string, kind?: Toast['kind']) => void
  dismissToast: (id: number) => void
  errorMessage: (e: unknown) => string
}

const SessionContext = createContext<SessionContextValue | null>(null)

function normaliseLocale(l: string | null | undefined) {
  const short = (l || '').slice(0, 2).toLowerCase()
  return supportedLocales().includes(short) ? short : null
}

export function SessionProvider({ children }: { children: ReactNode }) {
  const initialLocale = normaliseLocale(i18n.language) || DEFAULT_LOCALE
  setApiLocale(initialLocale)
  const [state, setState] = useState<SessionState>({
    ready: false,
    bootError: null,
    user: null,
    settings: null,
    cartQuantity: 0,
    unreadMessages: 0,
    locale: initialLocale,
    authModalOpen: false,
    toasts: [],
  })
  const pendingLogin = useRef<((ok: boolean) => void)[]>([])
  const toastId = useRef(0)

  const applyLocale = useCallback(async (locale: string) => {
    setApiLocale(locale)
    document.documentElement.lang = locale
    try {
      localStorage.setItem(LOCALE_STORAGE_KEY, locale)
    } catch {
      /* private mode */
    }
    if (i18n.language !== locale) await i18n.changeLanguage(locale)
    setState((s) => ({ ...s, locale }))
  }, [])

  const refresh = useCallback(async () => {
    try {
      const payload = await api.session()
      setCsrfToken(payload.csrf_token)
      setState((s) => ({
        ...s,
        ready: true,
        bootError: null,
        user: payload.user,
        settings: payload.settings,
        cartQuantity: payload.cart_quantity,
        unreadMessages: payload.unread_messages,
      }))
      // A logged-in user's stored preference wins over the browser guess (spec §19).
      const preferred = normaliseLocale(payload.user?.locale)
      if (preferred && preferred !== i18n.language) await applyLocale(preferred)
      return payload
    } catch (e) {
      setState((s) => ({ ...s, ready: true, bootError: e instanceof Error ? e.message : 'error' }))
      return null
    }
  }, [applyLocale])

  useEffect(() => {
    document.documentElement.lang = initialLocale
    void refresh()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const afterAuth = useCallback(
    async (res: AuthResponse) => {
      setCsrfToken(res.csrf_token)
      setState((s) => ({ ...s, user: res.user, cartQuantity: res.cart_quantity ?? s.cartQuantity, authModalOpen: false }))
      const preferred = normaliseLocale(res.user.locale)
      if (preferred) await applyLocale(preferred)
      else void api.updateProfile({ locale: i18n.language }).catch(() => undefined)
      // The server merged the guest cart into the account; pick up the merged totals.
      void refresh()
      const waiters = pendingLogin.current
      pendingLogin.current = []
      waiters.forEach((w) => w(true))
      return res.user
    },
    [applyLocale, refresh],
  )

  const login = useCallback(async (email: string, password: string) => afterAuth(await api.login(email, password)), [afterAuth])
  const register = useCallback(
    async (params: { email: string; password: string; first_name?: string; last_name?: string }) => afterAuth(await api.register(params)),
    [afterAuth],
  )

  const logout = useCallback(async () => {
    const res = await api.logout()
    setCsrfToken(res.csrf_token)
    disconnectCable()
    setState((s) => ({ ...s, user: null, unreadMessages: 0 }))
    await refresh()
  }, [refresh])

  const requireLogin = useCallback(() => {
    if (state.user) return Promise.resolve(true)
    return new Promise<boolean>((resolve) => {
      pendingLogin.current.push(resolve)
      setState((s) => ({ ...s, authModalOpen: true }))
    })
  }, [state.user])

  const closeAuthModal = useCallback(() => {
    setState((s) => ({ ...s, authModalOpen: false }))
    const waiters = pendingLogin.current
    pendingLogin.current = []
    waiters.forEach((w) => w(false))
  }, [])

  useEffect(() => {
    setLoginRequiredHandler(requireLogin)
    return () => setLoginRequiredHandler(null)
  }, [requireLogin])

  const setLocale = useCallback(
    async (locale: string) => {
      const l = normaliseLocale(locale)
      if (!l) return
      await applyLocale(l)
      if (state.user) {
        try {
          const { user } = await api.updateProfile({ locale: l })
          setState((s) => ({ ...s, user }))
        } catch {
          /* keep the local preference anyway */
        }
      }
    },
    [applyLocale, state.user],
  )

  const dismissToast = useCallback((id: number) => setState((s) => ({ ...s, toasts: s.toasts.filter((t) => t.id !== id) })), [])
  const toast = useCallback(
    (text: string, kind: Toast['kind'] = 'info') => {
      const id = ++toastId.current
      setState((s) => ({ ...s, toasts: [...s.toasts, { id, kind, text }] }))
      window.setTimeout(() => dismissToast(id), 4000)
    },
    [dismissToast],
  )

  const errorMessage = useCallback((e: unknown) => {
    if (e instanceof ApiError) return e.errors.join(' ')
    if (e instanceof TypeError) return i18n.t('common.networkError')
    if (e instanceof Error && e.message) return e.message
    return i18n.t('common.unknownError')
  }, [])

  const value = useMemo<SessionContextValue>(
    () => ({
      ...state,
      refresh,
      login,
      register,
      logout,
      requireLogin,
      closeAuthModal,
      setCartQuantity: (n) => setState((s) => ({ ...s, cartQuantity: n })),
      setUnreadMessages: (n) => setState((s) => ({ ...s, unreadMessages: n })),
      setUser: (u) => setState((s) => ({ ...s, user: u })),
      setLocale,
      toast,
      dismissToast,
      errorMessage,
    }),
    [state, refresh, login, register, logout, requireLogin, closeAuthModal, setLocale, toast, dismissToast, errorMessage],
  )

  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>
}

export function useSession() {
  const ctx = useContext(SessionContext)
  if (!ctx) throw new Error('useSession must be used inside SessionProvider')
  return ctx
}
