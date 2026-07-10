# 豆瓣FM红心歌单抓取 (Douban FM red-heart capture)
# 关键结论: 每首歌是单独一个 content-desc 节点, 格式为 "歌名 歌手" (已合并)
#  -> 不再两两配对; 直接按整串去重, 再切分 歌名/歌手
#  -> 同时保留原始串备份, 防止切分失误无法回溯
# 用法: 手机进红心列表并滑到最顶, 亮屏连 USB, 然后运行本脚本
# 先验证: 把 $maxSwipes 改成 3 跑一次确认无 "UI hierchary" 且每屏有新增, 再改回 1000 跑全量

$maxSwipes = 1000      # 上限, 实际到底会自动停
$stableStop = 30       # 连续 N 屏无新增 => 判定到底
$outCsv  = "douban_fm_redheart.csv"
$outRaw  = "douban_fm_redheart_raw.txt"

$garbage = @('我喜欢','歌曲','专辑','歌单','视频','添加到','下载','删除',
             'NEXT SONG','暂无歌曲','UI hierchary dumped to','hierarch','dumped','uiautomator')

function Is-Garbage($s){
    if ([string]::IsNullOrWhiteSpace($s)) { return $true }
    foreach ($g in $garbage) { if ($s -like "*$g*") { return $true } }
    if ($s -match '^\d+首$') { return $true }
    if ($s -match '第 \d+ 个标签|共 \d+ 个') { return $true }
    return $false
}

function Get-Songs {
    adb shell uiautomator dump /sdcard/ui.xml >$null 2>$null
    adb pull /sdcard/ui.xml ./ui.xml >$null 2>$null
    $raw = [System.IO.File]::ReadAllText("./ui.xml", [System.Text.Encoding]::UTF8)
    [xml]$x = $raw
    $out = @()
    foreach ($n in $x.SelectNodes("//node")) {
        $t = $n.Attributes["text"].Value
        $c = $n.Attributes["content-desc"].Value
        if ($t -and $t.Trim()) { $out += ($t.Trim() -replace '[\r\n]+', ' ') }
        if ($c -and $c.Trim()) { $out += ($c.Trim() -replace '[\r\n]+', ' ') }
    }
    $res = @()
    foreach ($s in $out) { if (-not (Is-Garbage $s)) { $res += $s } }
    return $res
}

# 切分 "歌名 歌手": 中文名首词含汉字 -> 第一个空格切; 否则(拉丁/数字开头) -> 最后一个空格切
function Split-Song($s) {
    if ($s -notmatch ' ') { return @($s, '') }
    $first = ($s -split ' ', 2)[0]
    if ($first -match '[\u4e00-\u9fff]') {
        $p = $s -split ' ', 2
        return @($p[0], $p[1])
    } else {
        $i = $s.LastIndexOf(' ')
        return @($s.Substring(0, $i), $s.Substring($i + 1))
    }
}

# 屏幕自适应滑动坐标
$size = adb shell wm size; $w = 1080; $h = 2400
if ($size -match '(\d+)x(\d+)') { $w = [int]$Matches[1]; $h = [int]$Matches[2] }
$cx = [int]($w / 2); $sy = [int]($h * 0.70); $ey = [int]($h * 0.30)

$seen = @{}; $songs = @(); $stable = 0
for ($i = 1; $i -le $maxSwipes; $i++) {
    $items = Get-Songs
    $added = 0
    foreach ($s in $items) {
        if (-not $seen.ContainsKey($s)) { $seen[$s] = $true; $songs += $s; $added++ }
    }
    Write-Host "[$i] 本屏 $($items.Count) | 新增 $added | 累计 $($songs.Count)"
    if ($added -eq 0) { $stable++; if ($stable -ge $stableStop) { Write-Host '=> 已到底, 停止。'; break } } else { $stable = 0 }
    adb shell input swipe $cx $sy $cx $ey 400
    Start-Sleep -Seconds 1.0
}

# 原始串备份 (按整串, 未切分, 最安全)
$songs | Out-File -Encoding utf8 $outRaw

# 解析为 歌名,歌手
$csv = @('歌名,歌手')
foreach ($s in $songs) { $p = Split-Song $s; $csv += "$($p[0]),$($p[1])" }
$csv | Out-File -Encoding utf8 $outCsv

Write-Host "完成 -> 原始 $($songs.Count) 首 | CSV $($songs.Count) 行"
Write-Host "--- 解析预览(前12) ---"
$csv | Select-Object -First 12 | ForEach-Object { Write-Host "  $_" }
