/** All money values are integer ARS cents. Renders "$ 12.345,00" (es-AR style). */
export function formatMoney(cents: number | null | undefined): string {
  const value = (cents ?? 0) / 100
  const negative = value < 0
  const abs = Math.abs(value)
  const [intPart, decPart] = abs.toFixed(2).split('.')
  const grouped = intPart.replace(/\B(?=(\d{3})+(?!\d))/g, '.')
  return `${negative ? '-' : ''}$ ${grouped},${decPart}`
}

export function formatDate(iso: string | null | undefined, locale: string, opts?: Intl.DateTimeFormatOptions): string {
  if (!iso) return ''
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return iso
  return new Intl.DateTimeFormat(locale === 'ru' ? 'ru-RU' : 'es-AR', opts || { day: 'numeric', month: 'short', year: 'numeric' }).format(d)
}

export function formatDateTime(iso: string | null | undefined, locale: string): string {
  return formatDate(iso, locale, { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })
}
