// Second Vite entry: mounts React islands inside the server-rendered admin.
// <div data-react="print-area-editor" data-props='{...}'></div>
// <div data-react="design-editor" data-props='{...}'></div>
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import i18n from './i18n'
import './index.css'
import { PrintAreaEditor, type PrintAreaEditorProps } from './admin/PrintAreaEditor'
import { AdminDesignEditor, type AdminDesignEditorProps } from './admin/AdminDesignEditor'

function readProps<T>(el: HTMLElement): T {
  try {
    return JSON.parse(el.dataset.props || '{}') as T
  } catch (e) {
    console.error('[admin] invalid data-props JSON', el, e)
    return {} as T
  }
}

function mountAll() {
  const lang = document.documentElement.lang?.slice(0, 2)
  if (lang && i18n.language !== lang) void i18n.changeLanguage(lang)

  document.querySelectorAll<HTMLElement>('[data-react]').forEach((el) => {
    if (el.dataset.reactMounted) return
    el.dataset.reactMounted = '1'
    const kind = el.dataset.react
    let node: JSX.Element | null = null
    if (kind === 'print-area-editor') node = <PrintAreaEditor {...readProps<PrintAreaEditorProps>(el)} />
    else if (kind === 'design-editor') node = <AdminDesignEditor {...readProps<AdminDesignEditorProps>(el)} />
    if (node) createRoot(el).render(<StrictMode>{node}</StrictMode>)
  })
}

if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', mountAll)
else mountAll()
