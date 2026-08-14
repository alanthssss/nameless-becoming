import type { Metadata } from "next";
import { Noto_Serif_SC, Geist_Mono } from "next/font/google";
import "./globals.css";

const serif = Noto_Serif_SC({ variable: "--font-serif", subsets: ["latin"], weight: ["400", "600", "700"] });
const mono = Geist_Mono({ variable: "--font-mono", subsets: ["latin"] });

export const metadata: Metadata = {
  title: "归巢之前｜四季搜打撤",
  description: "在冬季到来前采蜜、归巢，守住一整个蜂群。",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="zh-CN"><body className={`${serif.variable} ${mono.variable}`}>{children}</body></html>;
}
