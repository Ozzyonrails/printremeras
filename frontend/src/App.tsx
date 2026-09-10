import { Route, Routes } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { useSession } from './store/session'
import { Layout } from './components/Layout'
import { ErrorBox, PageLoading } from './components/ui'
import { HomePage, TemplatesPage } from './pages/HomePage'
import { TemplatePage } from './pages/TemplatePage'
import { CatalogPage } from './pages/CatalogPage'
import { CatalogItemPage } from './pages/CatalogItemPage'
import { CartPage } from './pages/CartPage'
import { CartItemEditPage } from './pages/CartItemEditPage'
import { CheckoutPage } from './pages/CheckoutPage'
import { OrdersPage } from './pages/OrdersPage'
import { OrderPage } from './pages/OrderPage'
import { ReviewPage } from './pages/ReviewPage'
import { ReviewsPage } from './pages/ReviewsPage'
import { AccountPage } from './pages/AccountPage'
import { MessagesPage } from './pages/MessagesPage'
import { ConfirmPage, ForgotPasswordPage, LoginPage, NotFoundPage, RegisterPage, ResetPasswordPage } from './pages/AuthPages'

export default function App() {
  const { ready, bootError, refresh } = useSession()
  const { t } = useTranslation()
  if (!ready) return <PageLoading />
  if (bootError) {
    return (
      <div className="container-page py-10">
        <ErrorBox message={t('common.networkError')} onRetry={() => void refresh()} />
      </div>
    )
  }
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route index element={<HomePage />} />
        <Route path="templates" element={<TemplatesPage />} />
        <Route path="templates/:slug" element={<TemplatePage />} />
        <Route path="catalog" element={<CatalogPage />} />
        <Route path="catalog/:slug" element={<CatalogItemPage />} />
        <Route path="cart" element={<CartPage />} />
        <Route path="cart/items/:id/edit" element={<CartItemEditPage />} />
        <Route path="checkout" element={<CheckoutPage />} />
        <Route path="orders" element={<OrdersPage />} />
        <Route path="orders/:number" element={<OrderPage />} />
        <Route path="orders/:number/review" element={<ReviewPage />} />
        <Route path="reviews" element={<ReviewsPage />} />
        <Route path="account" element={<AccountPage />} />
        <Route path="messages" element={<MessagesPage />} />
        <Route path="login" element={<LoginPage />} />
        <Route path="register" element={<RegisterPage />} />
        <Route path="forgot-password" element={<ForgotPasswordPage />} />
        <Route path="reset-password/:token" element={<ResetPasswordPage />} />
        <Route path="confirm/:token" element={<ConfirmPage />} />
        <Route path="*" element={<NotFoundPage />} />
      </Route>
    </Routes>
  )
}
