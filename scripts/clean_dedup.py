#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
豆瓣FM 红心歌单 清洗 + 去重
输入: capture_redheart.ps1 产出的原始串备份 (douban_fm_redheart_raw.txt, 每行一首 "歌名 歌手")
输出: 干净的 CSV (歌名,歌手), UTF-8-sig, Excel 直开不乱码

去重规则:
  - 唯一键 = 「歌名+歌手」完整清洗串
  - 完全相同(同一版本出现在不同专辑) -> 删除
  - 不同版本(Live/翻唱/不同艺人, 只要有一处不同) -> 保留
  - 保序(保留首次出现)

切分规则:
  - 中文/日/韩开头 -> 第一个空格切 歌名/歌手
  - 外文(拉丁/数字开头) -> 无法可靠切分, 整串存歌名, 歌手留空(原始信息不丢, 待手补)

用法:
  python3 clean_dedup.py <raw_txt> <out_csv>
"""
import re
import csv
import sys

# 需要剥离的不可见 / 异常空白字符
ZWS = {0x200b, 0x200c, 0x200d, 0xfeff, 0x00a0, 0x3000}


def clean(s: str) -> str:
    for c in ZWS:
        s = s.replace(chr(c), '')
    s = re.sub(r'\s+', ' ', s)   # 所有空白(含换行/制表)压成单空格
    return s.strip()


def is_cjk(ch: str) -> bool:
    o = ord(ch)
    return (0x4E00 <= o <= 0x9FFF      # 中日韩统一表意
            or 0x3040 <= o <= 0x30FF   # 日文假名
            or 0xAC00 <= o <= 0xD7AF   # 韩文
            or 0x3100 <= o <= 0x312F)  # 注音


def first_is_cjk(s: str) -> bool:
    for ch in s:
        if ch.isspace():
            continue
        return is_cjk(ch)
    return False


def main():
    if len(sys.argv) < 3:
        print("用法: python3 clean_dedup.py <raw_txt> <out_csv>")
        sys.exit(1)
    raw_path, out_path = sys.argv[1], sys.argv[2]

    lines = open(raw_path, encoding='utf-8-sig').read().splitlines()
    cleaned = [clean(l) for l in lines]
    cleaned = [c for c in cleaned if c]

    # 去重: 完整清洗串为键, 保序
    seen = set()
    uniq = []
    for s in cleaned:
        if s not in seen:
            seen.add(s)
            uniq.append(s)

    # 切分
    rows = []
    foreign = 0
    for s in uniq:
        if first_is_cjk(s):
            if ' ' in s:
                ti, ar = s.split(' ', 1)
            else:
                ti, ar = s, ''
            rows.append((ti, ar))
        else:
            rows.append((s, ''))  # 外文: 整串存歌名, 歌手留空
            foreign += 1

    with open(out_path, 'w', encoding='utf-8-sig', newline='') as f:
        w = csv.writer(f)
        w.writerow(['歌名', '歌手'])
        for ti, ar in rows:
            w.writerow([ti, ar])

    print(f"读取原始行数        : {len(lines)}")
    print(f"清洗后非空行        : {len(cleaned)}")
    print(f"去重后唯一歌曲      : {len(uniq)}")
    print(f"本次去除重复        : {len(cleaned) - len(uniq)}")
    print(f"中文类(已切分 歌名/歌手): {len(rows) - foreign}")
    print(f"外文类(整串存歌名,歌手待补): {foreign}")
    print(f"输出 -> {out_path}")


if __name__ == '__main__':
    main()
