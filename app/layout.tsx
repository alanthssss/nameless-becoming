import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "一会儿巢里见｜See You at the Hive",
  description: "一款四季邻里动作冒险：去花田搭把翅膀，办完事回巢见。",
  openGraph: {
    title: "一会儿巢里见｜See You at the Hive",
    description: "花田有事，搭把翅膀。飞一圈，巢里见。",
  },
  twitter: {
    card: "summary_large_image",
    title: "一会儿巢里见｜See You at the Hive",
    description: "花田有事，搭把翅膀。飞一圈，巢里见。",
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="zh-CN"><body>{children}</body></html>;
}
