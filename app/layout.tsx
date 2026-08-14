import type { Metadata } from "next";
import { Noto_Serif_SC, Geist_Mono } from "next/font/google";
import "./globals.css";

const serif = Noto_Serif_SC({ variable: "--font-serif", subsets: ["latin"], weight: ["400", "600", "700"] });
const mono = Geist_Mono({ variable: "--font-mono", subsets: ["latin"] });

export const metadata: Metadata = {
  title: "归巢之前｜四季搜打撤",
  description: "控制蜜蜂飞行、采蜜、击退蚊虫，在体力耗尽前亲自归巢。",
  metadataBase: new URL("https://hivebound-seasons.alanthssss.chatgpt.site"),
  openGraph: {
    title: "归巢之前｜四季搜打撤",
    description: "再采一朵，还是现在归巢？",
    images: ["/og.jpg"],
  },
  twitter: {
    card: "summary_large_image",
    title: "归巢之前｜四季搜打撤",
    description: "再采一朵，还是现在归巢？",
    images: ["/og.jpg"],
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="zh-CN"><body className={`${serif.variable} ${mono.variable}`}>{children}</body></html>;
}
