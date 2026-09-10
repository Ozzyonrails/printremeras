import { useCallback, useEffect, useRef, useState, type ChangeEvent, type FormEvent } from 'react'
import { Link, useLocation } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { api } from '../api/client'
import type { Message, Order } from '../api/types'
import { useSession } from '../store/session'
import { subscribeConversation } from '../lib/cable'
import { formatDateTime } from '../lib/money'
import { uploadImageFile } from '../lib/upload'
import { AuthForm } from '../components/AuthForm'
import { ErrorBox, Money, PageLoading, PageTitle, Sheet, Spinner } from '../components/ui'
import { StatusPill } from './OrdersPage'

function OrderCard({ order }: { order: NonNullable<Message['order']> }) {
  return (
    <Link to={`/orders/${order.number}`} className="mt-2 flex items-center gap-2 rounded-xl border border-ink-100 bg-white p-2 text-ink-900">
      <div className="h-12 w-10 shrink-0 overflow-hidden rounded bg-ink-100">{order.preview_url && <img src={order.preview_url} alt="" loading="lazy" className="h-full w-full object-cover" />}</div>
      <div className="min-w-0 flex-1 text-xs">
        <p className="font-semibold">{order.number}</p>
        <StatusPill status={order.status} />
      </div>
      <Money cents={order.total_cents} className="text-xs font-semibold" />
    </Link>
  )
}

export function MessagesPage() {
  const { t } = useTranslation()
  const location = useLocation()
  const { user, errorMessage, setUnreadMessages, settings, locale } = useSession()
  const [messages, setMessages] = useState<Message[] | null>(null)
  const [orders, setOrders] = useState<Order[]>([])
  const [error, setError] = useState<string | null>(null)
  const [body, setBody] = useState('')
  const [orderId, setOrderId] = useState<number | null>((location.state as { orderId?: number } | null)?.orderId ?? null)
  const [orderSheet, setOrderSheet] = useState(false)
  const [attachments, setAttachments] = useState<{ signedId: string; preview: string }[]>([])
  const [uploading, setUploading] = useState(false)
  const [sending, setSending] = useState(false)
  const [sendError, setSendError] = useState<string | null>(null)
  const listRef = useRef<HTMLDivElement>(null)
  const fileInput = useRef<HTMLInputElement>(null)

  const scrollToEnd = () => window.requestAnimationFrame(() => listRef.current?.scrollTo({ top: listRef.current.scrollHeight }))

  const load = useCallback(() => {
    setError(null)
    api
      .messages()
      .then((r) => {
        setMessages(r.messages)
        setOrders(r.orders)
        setUnreadMessages(0)
        scrollToEnd()
      })
      .catch((e) => setError(errorMessage(e)))
  }, [errorMessage, setUnreadMessages])

  useEffect(() => {
    if (user) load()
  }, [user, load])

  // Realtime via ActionCable ConversationChannel
  useEffect(() => {
    if (!user) return
    const sub = subscribeConversation<{ type: string; message: Message }>((data) => {
      if (data.type !== 'message' || !data.message) return
      setMessages((m) => (m && m.some((x) => x.id === data.message.id) ? m : [...(m || []), data.message]))
      setUnreadMessages(0)
      scrollToEnd()
    })
    return () => {
      sub.unsubscribe()
    }
  }, [user, setUnreadMessages])

  const addAttachment = async (e: ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    e.target.value = ''
    if (!file) return
    setUploading(true)
    setSendError(null)
    try {
      const { signedId } = await uploadImageFile(file, { maxBytes: settings?.max_upload_bytes })
      setAttachments((a) => [...a, { signedId, preview: URL.createObjectURL(file) }])
    } catch (err) {
      setSendError(errorMessage(err))
    } finally {
      setUploading(false)
    }
  }

  const send = async (e: FormEvent) => {
    e.preventDefault()
    const text = body.trim()
    if (!text && attachments.length === 0) return
    setSending(true)
    setSendError(null)
    try {
      const { message } = await api.sendMessage({ body: text, order_id: orderId ?? undefined, attachments: attachments.length ? attachments.map((a) => a.signedId) : undefined })
      setMessages((m) => (m && m.some((x) => x.id === message.id) ? m : [...(m || []), message]))
      setBody('')
      setOrderId(null)
      setAttachments([])
      scrollToEnd()
    } catch (err) {
      setSendError(errorMessage(err))
    } finally {
      setSending(false)
    }
  }

  if (!user) {
    return (
      <div className="container-page py-6">
        <PageTitle subtitle={t('messages.loginBody')}>{t('messages.loginTitle')}</PageTitle>
        <div className="card p-4 sm:max-w-md">
          <AuthForm compact />
        </div>
      </div>
    )
  }
  if (error) return <div className="container-page py-6"><ErrorBox message={error} onRetry={load} /></div>
  if (!messages) return <PageLoading />

  const selectedOrder = orders.find((o) => o.id === orderId)

  return (
    <div className="container-page flex flex-col py-4" style={{ height: 'calc(100vh - 3.5rem - 3.5rem - env(safe-area-inset-bottom))' }}>
      <h1 className="mb-2 text-xl font-bold">{t('messages.title')}</h1>
      <div ref={listRef} className="flex-1 space-y-3 overflow-y-auto rounded-2xl bg-ink-100 p-3">
        {messages.length === 0 && <p className="py-10 text-center text-sm text-ink-500">{t('messages.empty')}</p>}
        {messages.map((m) => (
          <div key={m.id} className={`flex ${m.from_admin ? 'justify-start' : 'justify-end'}`}>
            <div className={`max-w-[85%] rounded-2xl px-3 py-2 text-sm ${m.from_admin ? 'bg-white text-ink-900' : 'bg-ink-900 text-white'}`}>
              <p className={`mb-0.5 text-[11px] ${m.from_admin ? 'text-ink-500' : 'text-ink-300'}`}>
                {m.from_admin ? m.sender_name || t('messages.support') : t('messages.you')} · {formatDateTime(m.created_at, locale)}
              </p>
              {m.body && <p className="whitespace-pre-wrap break-words">{m.body}</p>}
              {m.attachments.map((a) =>
                a.image ? (
                  <a key={a.id} href={a.url} target="_blank" rel="noreferrer" className="mt-2 block">
                    <img src={a.url} alt={a.filename} loading="lazy" className="max-h-60 rounded-lg" />
                  </a>
                ) : (
                  <a key={a.id} href={a.url} target="_blank" rel="noreferrer" className="mt-2 block underline">
                    {a.filename}
                  </a>
                ),
              )}
              {m.order && <OrderCard order={m.order} />}
            </div>
          </div>
        ))}
      </div>

      <form onSubmit={send} className="mt-2">
        {selectedOrder && (
          <div className="mb-2 flex items-center justify-between rounded-xl bg-brand-50 px-3 py-2 text-sm">
            <span>
              {t('messages.aboutOrder', { number: selectedOrder.number })} <StatusPill status={selectedOrder.status} />
            </span>
            <button type="button" className="min-h-touch underline" onClick={() => setOrderId(null)}>
              {t('messages.removeOrder')}
            </button>
          </div>
        )}
        {attachments.length > 0 && (
          <div className="mb-2 flex gap-2">
            {attachments.map((a, i) => (
              <div key={a.signedId} className="relative h-16 w-16 overflow-hidden rounded-lg">
                <img src={a.preview} alt="" className="h-full w-full object-cover" />
                <button type="button" className="absolute right-0 top-0 h-7 w-7 rounded-bl-lg bg-white/90 text-xs" aria-label={t('common.remove')} onClick={() => setAttachments((x) => x.filter((_, j) => j !== i))}>
                  ✕
                </button>
              </div>
            ))}
          </div>
        )}
        <div className="flex items-end gap-2">
          <input ref={fileInput} type="file" accept="image/*" className="hidden" onChange={addAttachment} />
          <button type="button" className="btn-secondary h-11 w-11 shrink-0 px-0" aria-label={t('messages.attach')} disabled={uploading} onClick={() => fileInput.current?.click()}>
            {uploading ? <Spinner className="h-4 w-4" /> : '📎'}
          </button>
          <textarea
            className="input min-h-[44px] flex-1 resize-none py-2.5"
            rows={1}
            placeholder={t('messages.placeholder')}
            value={body}
            onChange={(e) => setBody(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && !e.shiftKey && !('ontouchstart' in window)) {
                e.preventDefault()
                e.currentTarget.form?.requestSubmit()
              }
            }}
          />
          <button type="submit" className="btn-primary h-11 shrink-0" disabled={sending || uploading || (!body.trim() && attachments.length === 0)}>
            {sending ? <Spinner className="border-white/40 border-t-white" /> : t('messages.send')}
          </button>
        </div>
        {sendError && <p className="mt-1 text-xs text-red-700">{sendError}</p>}
        <button type="button" className="mt-1 min-h-touch text-sm text-ink-700 underline" onClick={() => setOrderSheet(true)}>
          {t('messages.askAboutOrder')}
        </button>
      </form>

      <Sheet open={orderSheet} onClose={() => setOrderSheet(false)} title={t('messages.selectOrder')}>
        {orders.length === 0 ? (
          <p className="text-sm text-ink-500">{t('messages.noOrders')}</p>
        ) : (
          <ul className="space-y-2">
            {orders.map((o) => (
              <li key={o.id}>
                <button type="button" className="flex w-full items-center gap-3 rounded-xl border border-ink-100 p-2 text-left active:bg-ink-100" onClick={() => { setOrderId(o.id); setOrderSheet(false) }}>
                  <div className="h-14 w-12 shrink-0 overflow-hidden rounded bg-ink-100">{o.preview_url && <img src={o.preview_url} alt="" loading="lazy" className="h-full w-full object-cover" />}</div>
                  <div className="min-w-0 flex-1 text-sm">
                    <p className="font-semibold">{o.number}</p>
                    <StatusPill status={o.status} />
                  </div>
                  <Money cents={o.total_cents} className="text-sm" />
                </button>
              </li>
            ))}
          </ul>
        )}
      </Sheet>
    </div>
  )
}
