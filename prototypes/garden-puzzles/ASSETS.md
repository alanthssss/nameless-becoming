# 资产来源与范围

- 数字块、五种花形、界面和图标：本轮项目内原创程序绘制／SVG；没有下载图片或调用图像模型。
- `sound.gd`：逐字复用仓库 `prototypes/swarm-flight/sound.gd` 在基线95eb82f的原创程序合成配乐和音效。合成用第1轨，三消用第2轨；第3轨仍保留在相同生成器内。没有采样外部录音。
- 声音生成器 SHA-256：`560a73b9e3b8246a0a7ae6df2f05aab26a7aadabc79e121fa75086eae8405665`。
- 字体：系统字体回退 PingFang SC、Hiragino Sans GB、Noto Sans CJK SC、Microsoft YaHei、sans-serif；不打包第三方字体文件。macOS 中文已实机检查，其他平台尚无视觉验收。
- 本轮沿用成熟2048式合并与经典相邻三消规则，规则实现自写；没有导入其它游戏源码、品牌、美术或音乐。
