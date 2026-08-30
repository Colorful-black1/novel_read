# 应用图标（Logo）生成与接入指南

目标：黑白配色、圆滑、细线条、留白适中的无文字图标，替换 Android / Windows 应用图标与托盘图标。

## 第 1 步：生成图片

### 1.1 先确认可用的图片模型

中转站只接受它认识的图片模型名，先查你的 key 能用哪些模型：

```bash
curl https://chain888.vip/v1/models \
  -H "Authorization: Bearer 你的APIKey"
```

返回 JSON 中 `data[].id` 就是可用模型名。优先找带 `image` / `dall-e` / `flux`
字样的，依次尝试：`gpt-image-1` → `gpt-image-1-mini` → `dall-e-3`。
若报 `images endpoint requires an image model` 说明模型名不对，换下一个。

### 1.2 调用生图接口

把 `<图片模型名>` 替换为上一步确认的名字，`你的APIKey` 换成中转站的 key：

```bash
curl -X POST https://chain888.vip/v1/images/generations \
  -H "Authorization: Bearer 你的APIKey" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "<图片模型名>",
    "prompt": "Flat modern app icon for a xianxia fantasy novel reading app: an open book with a graceful Chinese flying sword (jian) rising diagonally from its pages, a flowing ribbon swirling around and turning into auspicious clouds, rounded plump shapes, smooth thick curves, compact centered composition filling the frame, soft gradient colors of azure blue and gold with a touch of jade green, clean vector style with bold outlines, glossy app icon look, no text, no letters, no Chinese characters, no watermark, no signature, solid plain white background",
    "size": "1024x1024",
    "n": 1
  }'
```

返回 JSON 中 `data[0].url` 是图片下载地址（或 `b64_json` 为 base64 内容）。
若返回 url，直接浏览器打开下载；若返回 b64_json，可用下面命令还原：

```bash
# Linux/macOS/Git Bash：把 <b64内容> 替换为返回值
echo "<b64内容>" | base64 -d > assets/icon.png
```

### 提示词说明（可自行微调）

| 要求 | 提示词对应 |
| ---- | ---- |
| 动画/卡通风格 | Flat cartoon, anime-style, kawaii style |
| 卡通人物 | a cute chibi anime-style character with big round glasses |
| 场景（人物+书） | sitting on a stack of books, reading an open book |
| 黑白配色 | pure black and white monochrome |
| 线条清晰（小尺寸不糊） | clean bold cartoon line art |
| 不出现中文 | no text, no letters, no Chinese characters |

不满意可调整：人物特征换 `a little fox` / `a cat with headphones` 等；
姿势换 `lying on a bean bag reading` / `flying with a book` 等；
觉得线条还是太粗/太细就调 `bold` / `thin`。注意：线条过细在任务栏、
桌面等小图标尺寸会看不清，`bold cartoon line art` 是比较稳的选择。

生成后请人工检查：背景必须是纯白/纯色（不要透明通道异常），主体居中、边缘干净。
不满意就把 prompt 里的主题词换掉重试，例如 `an open book` 换成
`a book and a cup of tea`、`a bookmark ribbon` 等。

## 第 2 步：一键生成全平台图标

把生成的 1024x1024 图片放到 `assets/icon.png`，然后执行：

```bash
export PATH="/e/Codeing/sdks/flutter/bin:$PATH"
flutter pub get
dart run flutter_launcher_icons
```

会自动生成：
- `android/app/src/main/res/mipmap-*/ic_launcher.png`（全密度 + 自适应图标）
- `windows/runner/resources/app_icon.ico`（Windows 窗口/任务栏图标）

## 第 3 步：同步托盘图标并重新构建

```bash
cp windows/runner/resources/app_icon.ico assets/tray_icon.ico
flutter build windows --release
flutter build apk --release
```

托盘图标（`assets/tray_icon.ico`）与 exe 内嵌图标即一并更新。
