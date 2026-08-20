import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "无名：成蜂｜Godot 四季搜打撤",
  description: "与 macOS、Windows 同源的 Godot Web 版：穿越四季，在体力耗尽前采蜜归巢。",
  metadataBase: new URL("https://hivebound-seasons-game.pages.dev"),
  openGraph: {
    title: "无名：成蜂｜四季搜打撤",
    description: "再采一朵，还是现在归巢？",
    images: ["/og.jpg"],
  },
  twitter: {
    card: "summary_large_image",
    title: "无名：成蜂｜四季搜打撤",
    description: "再采一朵，还是现在归巢？",
    images: ["/og.jpg"],
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="zh-CN"><body>{children}</body></html>;
}
