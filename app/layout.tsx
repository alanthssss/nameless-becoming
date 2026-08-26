import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "一会儿巢里见｜Godot 春季往返纵切",
  description: "与 macOS、Windows 同源的 Godot Web 版：去花田搭把翅膀，办完事回巢见。",
  metadataBase: new URL("https://hivebound-seasons-game.pages.dev"),
  openGraph: {
    title: "一会儿巢里见｜春季往返纵切",
    description: "花田有事，搭把翅膀。飞一圈，巢里见。",
  },
  twitter: {
    card: "summary_large_image",
    title: "一会儿巢里见｜春季往返纵切",
    description: "花田有事，搭把翅膀。飞一圈，巢里见。",
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="zh-CN"><body>{children}</body></html>;
}
