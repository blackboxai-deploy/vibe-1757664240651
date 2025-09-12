import './globals.css'
import { Inter } from 'next/font/google'
import type { Metadata } from 'next'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'Gaia-X Command Center',
  description: 'Temporary interface for Gaia-X scaling and progress demonstration',
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}> ) {
  return (
    <html lang="en">
      <body className={`${inter.className} antialiased bg-gray-50 dark:bg-gray-900 text-gray-900 dark:text-gray-100`}>{children}</body>
    </html>
  )
}