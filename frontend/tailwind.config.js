/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    screens: { sm: '640px', lg: '1024px', xl: '1280px' },
    extend: {
      colors: {
        brand: { 50: '#fff7ed', 100: '#ffedd5', 500: '#f59e0b', 600: '#d97706', 700: '#b45309' },
        ink: { 900: '#111827', 700: '#374151', 500: '#6b7280', 300: '#d1d5db', 100: '#f3f4f6' },
      },
      minHeight: { touch: '44px' },
      minWidth: { touch: '44px' },
      spacing: { safe: 'env(safe-area-inset-bottom)' },
    },
  },
  plugins: [],
}
