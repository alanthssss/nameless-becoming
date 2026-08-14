import type { Metadata } from "next";
import { Noto_Serif_SC, Geist_Mono } from "next/font/google";
import "./globals.css";

const serif = Noto_Serif_SC({ variable: "--font-serif", subsets: ["latin"], weight: ["400", "600", "700"] });
const mono = Geist_Mono({ variable: "--font-mono", subsets: ["latin"] });

export const metadata: Metadata = {
  title: "归巢之前｜Godot 四季搜打撤",
  description: "与 macOS、Windows 同源的 Godot Web 版：穿越四季，在体力耗尽前采蜜归巢。",
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
