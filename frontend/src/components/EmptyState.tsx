import { Link } from 'react-router-dom'

export function EmptyState({ title, body, cta, to }: { title: string; body?: string; cta?: string; to?: string }) {
  return (
    <div className="card p-8 text-center">
      <p className="text-lg font-semibold">{title}</p>
      {body && <p className="mt-1 text-ink-500">{body}</p>}
      {cta && to && (
        <Link to={to} className="btn-primary mt-5">
          {cta}
        </Link>
      )}
    </div>
  )
}
