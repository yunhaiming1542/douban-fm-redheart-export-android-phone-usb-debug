---
name: douban-fm-redheart-export
description: Export the "红心/我喜欢" (red-heart) song list from Douban FM (com.douban.radio, kuwo-operated) to a local CSV via ADB UI scraping, then clean and de-duplicate. Use when a user wants to back up / download / export their Douban FM liked songs to local files. The app has NO official export; this is the only working path.
description_zh: "把豆瓣FM红心歌单通过ADB抓取导出为本地CSV并清洗去重"
description_en: "Export Douban FM red-heart list to local CSV via ADB scraping, then clean & dedup"
version: 1.0.0
allowed-tools: Bash,Read,Write,Edit
metadata:
  agent_created: true
  tags:
    - "douban fm"
    - "red heart export"
    - "adb scraping"
    - "playlist backup"
  clawdbot:
    emoji: "\u2764\uFE0F"
    requires:
      bins:
        - python3
        - adb
display_name: "豆瓣FM红心导出"
display_name_en: "Douban FM Red-Heart Export"
visibility: "private"
---

# 豆瓣FM 红心歌单导出 (Douban FM Red-Heart Export)

把豆瓣FM（`com.douban.radio`，现由酷我运营）的"红心/我喜欢"歌单导出为本地 CSV。
App **没有任何官方导出功能**，本 skill 是目前唯一验证可用的路径：用 ADB 驱动安卓设备自动滚屏 → `uiautomator dump` 抓界面节点 → 提取歌名/歌手 → 清洗去重 → 输出 CSV。

---

## 何时使用 (When to use)
- 用户想**备份 / 下载 / 导出**自己豆瓣FM的红心（我喜欢）歌单到本地。
- 用户接受"手动做设备侧准备、抓取由脚本自动完成"的方式。

## 前提条件 (Prerequisites)
1. **一台能登录豆瓣FM的安卓设备**（真机或安卓模拟器），且红心列表里**确实有歌**（登录后先肉眼确认非空；2023 年停运换酷我运营时，部分老账号历史红心可能未迁移而丢失）。
2. **一台 Windows/macOS/Linux 电脑**，已安装 `platform-tools`（含 `adb`）。
3. 设备与电脑通过 **USB 数据线**（非纯充电线）连接，或模拟器本地 adb。
4. 设备已开启**开发者选项 + USB 调试**，`adb devices` 能看到设备且状态为 `device`（非 `unauthorized`/空）。
5. **MIUI/部分定制系统必须额外开启「USB调试（安全设置）」**（见下方"操作风险"），否则 `input swipe` 会被系统拦截、界面不滚动。
6. 电脑装有 `python3`（用于清洗去重脚本）。

## 必备硬件条件 (Hardware)
- 安卓设备 1 台（真机推荐屏幕大的，如平板；或 Windows 上的雷电/MuMu/BlueStacks 模拟器）。
- 电脑 1 台。
- USB 数据线 1 根（真机路径必需；模拟器可免）。
- 稳定电量/常亮屏（抓取 3000 首约 15–25 分钟，全程需亮屏不锁屏）。

## 隐私风险 (Privacy risks) — 必须向用户说明
- **本 skill 不索取账号密码、不索取登录 token**。抓取只读取"设备当前已登录界面上显示的文字"，不触碰凭证，隐私风险低。
- 产出文件（CSV/原始 txt）含用户的**音乐偏好数据**，属个人信息，存放在用户本机；分享前请用户自行确认。
- 若改走"API 直连"替代路径（本 skill 不默认使用），会涉及把登录 Cookie/Authorization 交给脚本 —— 风险显著更高，**须用完即焚、不得长期留存**，且应优先劝阻，除非用户坚持。

## 操作风险 (Operational risks)
- **MIUI 拦截注入事件**：报 `SecurityException: Injecting to another application requires INJECT_EVENTS permission` = 默认禁止 adb 模拟触摸。修复：设置→更多设置→开发者选项→开启 **「USB调试（安全设置）」**（普通"USB调试"不够）。此项若为灰色：先登录小米账号、等几分钟、部分机型需插 SIM 卡后才可开；开启后有时需重连 USB 或 `adb kill-server && adb start-server`。
- **设备中途掉线**：出现 `no devices/emulators found` → 重插 USB / 换口换线 / 通知栏 USB 用途改「传输文件(MTP)」/ 撤销并重新授权 USB 调试。
- **中文乱码**：**禁止** `adb exec-out cat` + PowerShell 正则（GBK 会毁中文），**禁止**只用 `Get-Content`（易读到空/旧文件）。必须 `adb pull` 落地 + `ReadAllText(...,UTF8)` + `[xml]` 解析。
- **数据污染（已在脚本中规避）**：`uiautomator dump` 每次向 stdout 输出 `UI hierchary dumped to:...`，须 `>$null 2>$null` 丢弃并加入 garbage 过滤，否则污染数据、撑大行数。
- **外文/日韩歌切分不可靠**：App 把"歌名 歌手"压进同一个 `content-desc` 节点，外文歌无法靠空格 100% 切准 → 本 skill 对非中文开头的歌**整串存歌名、歌手留空**，绝不乱切；原始串另存备份可回溯。
- **数量差额非漏抓**：App 顶部显示的 `N首`（如 3035）通常是「歌曲/专辑/歌单/视频」四标签合计；实际"歌曲"红心往往少于该数（实测约 2700）。

---

## 操作流程 (How it works)

### 步骤 1 — 电脑装 adb 并连上设备
```bash
# Windows 最省事：
winget install Google.PlatformTools
# 或官网 ZIP: https://developer.android.com/tools/releases/platform-tools 解压后加入 PATH
adb devices   # 必须看到一行 "<序列号>  device"
```
真机：开发者选项开 USB 调试 + 「USB调试（安全设置）」，手机弹窗点"一律允许"。
模拟器：启动后 `adb connect 127.0.0.1:5555`（雷电/BlueStacks）或 `:7555`（MuMu）。

### 步骤 2 — 设备侧准备
打开豆瓣FM → 我的 → 红心/我喜欢 → **手动滑到列表最顶** → 保持亮屏、关自动锁屏、USB 连着。
先肉眼确认红心里**有歌**（顶部会显示 `N首`），否则无数据可抓。

### 步骤 3 — 先验证再全量（避免白跑）
把抓取脚本里 `$maxSwipes` 临时改成 `3` 跑一次，看输出：
- 无 `UI hierchary` 字样、每屏"新增"在涨、样例是干净的歌名 → OK；
- 每屏"新增"一直 0 或界面不动 → 多半是「USB调试（安全设置）」没开，见操作风险。

### 步骤 4 — 全量抓取
`$maxSwipes` 改回 `1000`，在**电脑**上运行（PowerShell）：
```powershell
powershell -ExecutionPolicy Bypass -File {baseDir}/scripts/capture_redheart.ps1
```
或直接把脚本内容粘进 PowerShell 窗口运行（避开执行策略）。
产出：`douban_fm_redheart.csv`（歌名,歌手）+ `douban_fm_redheart_raw.txt`（原始串备份，防切错可回溯）。
到底自动停（连续 30 屏无新增）。

### 步骤 5 — 清洗 + 去重
```bash
python3 {baseDir}/scripts/clean_dedup.py <raw_txt路径> <输出csv路径>
```
- 剥离零宽/异常空白：U+200B / U+FEFF / U+00A0 / U+3000 等（App 会在字符间插 U+200B）。
- 去重键 = 「歌名+歌手」**完整清洗串**：完全相同（同一版本出现在不同专辑）→ 删除；不同版本（Live/翻唱/不同艺人）→ 保留。
- 保序（保留首次出现），输出 UTF-8-sig（Excel 直开不乱码）。

### 步骤 6 — 交付
产出的 dedup CSV 即本地备份，可直接进 Excel 或喂给下一步（如建"个人音乐库"界面）。
730 首左右外文歌的歌手列为空，用户可在 Excel 手补，或按需写半自动"末空格预切"脚本（有少量误切需复核）。

---

## 关键技术备忘 (Key gotchas — do not rediscover)
- 歌曲信息在 `content-desc` 节点，**每首歌一个节点、"歌名 歌手"已合并**，不是两个节点成对。
- 切分规则：首词含汉字 → 第一个空格切；拉丁/数字开头 → 最后一个空格切（本 skill 对外文更保守，整串存歌名、歌手留空）。
- garbage 过滤白名单：`我喜欢/歌曲/专辑/歌单/视频/添加到/下载/删除/N首/第N个标签/共N个/NEXT SONG/暂无歌曲/UI hierchary dumped`。
- 滑动坐标屏幕自适应：`wm size` 取 w/h，从 h*0.7 滑到 h*0.3，duration 400，每屏间隔 ~1s。
