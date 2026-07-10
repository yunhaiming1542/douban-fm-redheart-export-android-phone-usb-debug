# 豆瓣FM 红心歌单导出（ADB · 安卓手机 · USB 调试）

> Export your Douban FM "红心 / 我喜欢" (red-heart) playlist to a local CSV — using ADB UI scraping on an Android phone with USB debugging enabled.

**本仓库用来把豆瓣 FM（`com.douban.radio`，现由酷我运营）的「红心 / 我喜欢」歌单，导出成一份本地 CSV 备份。**

⚠️ 豆瓣 FM **没有任何官方导出功能**。本方案是目前唯一验证可行的路径：借助 **ADB（Android Debug Bridge）** 驱动一台已开启「开发者选项 + USB 调试」的安卓手机，自动滚屏抓取红心列表界面上显示的歌名 / 歌手，再清洗去重，输出干净的 CSV。

> **同一天拿到了自己豆瓣电影 + 豆瓣 FM 的数字资产。** 🎬🎵
> 电影部分用的是另一套工具（见文末「推荐：豆瓣电影导出」），FM 红心部分就是本仓库。两份个人数据，都在同一天本地化落地。

---

## 📋 前置条件（必备）

| 条件 | 说明 |
|---|---|
| 一台**安卓手机**（或安卓模拟器） | 能登录豆瓣 FM，且**红心列表里确实有歌**（登录后先肉眼确认非空；2023 年停运换酷我运营，部分老账号历史红心可能未迁移而丢失） |
| 一台电脑（Win / macOS / Linux） | 已安装 `platform-tools`（含 `adb`）；本仓库脚本在 **Windows PowerShell** 下验证 |
| **USB 数据线**（非纯充电线） | 真机路径必需；模拟器可走本地 adb |
| **开发者选项 + USB 调试** | `adb devices` 能看到设备且状态为 `device`（非 `unauthorized` / 空） |
| **MIUI / 部分定制系统：额外开启「USB 调试（安全设置）」** | 否则 `adb shell input swipe` 会被系统拦截、界面不滚动（报 `INJECT_EVENTS` 错误） |
| **Python 3** | 用于清洗去重脚本 |

### 必备硬件
- 安卓设备 1 台（真机推荐屏幕大的，如平板；或 Windows 上的雷电 / MuMu / BlueStacks 模拟器）
- 电脑 1 台
- USB 数据线 1 根（真机必需）
- 稳定电量 / 常亮屏（抓取约 3000 首约 15–25 分钟，全程需亮屏不锁屏）

---

## 🔒 隐私与操作风险（必读）

**隐私：** 本方案**不索取账号密码、不索取登录 token**，只读取「设备当前已登录界面上显示的文字」，隐私风险低。产出的 CSV 含你的音乐偏好，属个人信息，分享前请自行确认。

**操作风险速查：**
- **MIUI 拦截注入事件**：报 `SecurityException: Injecting to another application requires INJECT_EVENTS permission` → 设置 → 更多设置 → 开发者选项 → 开启「USB 调试（安全设置）」。
- **设备中途掉线** `no devices/emulators found` → 重插 USB / 换线 / 通知栏 USB 用途改「传输文件 (MTP)」/ 撤销重授权。
- **中文乱码**：务必用 `adb pull` 落地 + UTF-8 读取，不要用 `adb exec-out cat` + 正则（GBK 会毁中文）。
- **数量差额非漏抓**：App 顶部 `N首`（如 3035）通常是「歌曲 / 专辑 / 歌单 / 视频」四标签合计，实际「歌曲」红心往往少于该数（实测约 2700）。
- **外文 / 日韩歌**：App 把「歌名 歌手」压进同一节点，无法 100% 可靠切分 → 这类歌整串存歌名、歌手留空，绝不乱切（原始串另存备份可回溯）。

---

## 🚀 快速开始

```bash
# 1. 安装 adb（Windows）
winget install Google.PlatformTools
adb devices   # 必须看到一行 "<序列号>  device"
```

1. 手机：开发者选项开 **USB 调试** + **「USB 调试（安全设置）」**，连电脑，弹窗点「一律允许」。
2. 打开豆瓣 FM → 我的 → 红心 → **手动滑到列表最顶** → 保持亮屏、关自动锁屏。
3. 先验证：把 `scripts/capture_redheart.ps1` 里 `$maxSwipes` 改成 `3` 跑一次，确认无 `UI hierchary` 且每屏有新增。
4. 全量：`$maxSwipes` 改回 `1000`，在电脑上运行脚本（PowerShell）：
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts/capture_redheart.ps1
   ```
   产出 `douban_fm_redheart.csv` + `douban_fm_redheart_raw.txt`（原始串备份）。
5. 清洗去重：
   ```bash
   python3 scripts/clean_dedup.py douban_fm_redheart_raw.txt douban_fm_redheart_dedup.csv
   ```
   产出 `douban_fm_redheart_dedup.csv`（歌名,歌手，UTF-8-sig，Excel 直开不乱码）。

---

## 📁 文件说明
- `scripts/capture_redheart.ps1` — ADB 自动滚屏抓取脚本（Windows PowerShell）
- `scripts/clean_dedup.py` — 清洗 + 去重（剥离零宽空格、按「歌名 + 歌手」去重，保留不同版本）
- `SKILL.md` — 给 AI Agent 用的技能说明（含完整前置 / 风险 / 流程）

---

## 🎬 推荐：豆瓣电影导出工具

> 上面这套是**音乐（豆瓣 FM）**。如果你也想把**自己的豆瓣电影评分 + 短评**下载到本地，「获取电影的插件」推荐这几个（非本项目，但同一天用上的好搭档）：

- **豆伴 / Tofu**（开源浏览器扩展，`github.com/doufen-org/tofu`，Edge 商店搜「豆伴」）：登录豆瓣网页 → 扩展里选「电影评分」→ 一键备份 → 导出 **Excel**。非技术向首选，覆盖电影 / 读书 / 音乐 / 游戏等全量账号数据。
- **douban-movie-exporter**（2025.12 更新）：字段可自定义（标题 / 评分 / 日期 / 标签 / 评语），导出 **Excel 或 JSON**，带防风控机制，适合直接喂数据库。
- **UlyC/DouBanExport**：电影 + 读书 + 音乐 + 游戏 + 舞台剧全导出，抓取快、不爬详情页。
- **ScriptCat 豆瓣观影记录导出脚本**（#5485）：油猴类脚本，把「看过 / 想看」导出成 **CSV**。

> **同一天拿到了自己豆瓣电影 + 豆瓣 FM 的数字资产。** 电影用上面的导出工具，FM 红心用本仓库——两份个人数据都在同一天本地化落地，可以做成一个「我的豆瓣记忆库」。

---

## 📜 License

MIT © yunhaiming1542
