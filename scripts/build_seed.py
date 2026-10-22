#!/usr/bin/env python3
"""Build Kachiiro/Resources/irodori_seed.json from the Irodori spreadsheets.

Usage: python3 scripts/build_seed.py --src ~/Downloads --out Kachiiro/Resources/irodori_seed.json

Cleaning order is load-bearing: parenthetical notes are stripped *before*
splitting on the full-width slash, because notes themselves contain slashes.
"""
import argparse
import json
import os
import re
import sys

import pandas as pd

SURU_RE = re.compile(r"[(（]する[)）]")
VERB_ADJ = {"V［1］", "V［2］", "V［3］", "イA", "ナA"}
LEVEL_OK = {"A1", "A2-1", "A2-2"}
BOOK_LEVEL = {"入門": "A1", "初級1": "A2-1", "初級2": "A2-2"}
POS_TAGS = {
    "V［1］": "V［1］", "V［2］": "V［2］", "V［3］": "V［3］",
    "イA": "イA", "ナA": "ナA", "N": "N", "Exp": "Exp",
}


def strip_groups(s: str):
    """Remove top-level (nested-aware) parenthesised groups with their leading
    whitespace. Returns (text, [group bodies])."""
    out, notes, depth, buf = [], [], 0, []
    for ch in s:
        if ch in "(（":
            if depth == 0:
                while out and out[-1] in " \u3000\t":
                    out.pop()
                buf = []
            else:
                buf.append(ch)
            depth += 1
        elif ch in ")）" and depth > 0:
            depth -= 1
            if depth == 0:
                notes.append("".join(buf))
            else:
                buf.append(ch)
        elif depth > 0:
            buf.append(ch)
        else:
            out.append(ch)
    return "".join(out).strip(), notes


def clean_text(s: str, pos: str, collect_notes: bool):
    """Returns (text, notes). Applies steps (a)-(c) from the plan."""
    s = str(s)
    if pos == "N/V［3］":
        s = SURU_RE.sub("する", s)
    s, groups = strip_groups(s)
    notes = [g for g in groups if g != "な"]
    return s, (notes if collect_notes else [])


def split_main(s: str, pos: str):
    parts = [p.strip() for p in s.split("／") if p.strip()]
    if not parts:
        return "", []
    return parts[0], ([] if pos in VERB_ADJ else parts[1:])


def build_words(path):
    df = pd.read_excel(path, sheet_name="wordlist")
    df = df[df["再出"].isna()]
    out = []
    for _, r in df.iterrows():
        raw_pos = r["品詞"]
        pos = "Other" if pd.isna(raw_pos) or str(raw_pos).strip() == "" else str(raw_pos).strip()
        if pos == "N/V［3］":
            pos = "V［3］"
            surufix = True
        else:
            surufix = False
        pos_for_clean = "N/V［3］" if surufix else pos
        head, notes = clean_text(r["見出し"], pos_for_clean, True)
        read, _ = clean_text(r["読み"], pos_for_clean, False)
        pitch, _ = clean_text(r["アクセント"] if not pd.isna(r["アクセント"]) else "", pos_for_clean, False)
        head_main, head_alts = split_main(head, pos)
        read_main, read_alts = split_main(read, pos)
        pitch_main, _ = split_main(pitch, pos)
        alternates = []
        for a in head_alts + read_alts:
            if a not in alternates and a not in (head_main, read_main):
                alternates.append(a)
        lesson = int(re.search(r"L(\d+)", str(r["課"])).group(1))
        topic = r["補足情報"]
        out.append({
            "id": int(r["「ことばリスト」順"]),
            "headword": head_main,
            "reading": read_main,
            "pitch": pitch_main,
            "meaning": "" if pd.isna(r["英訳"]) else str(r["英訳"]).strip(),
            "pos": pos,
            "contextNote": " / ".join(n.replace("／", " / ") for n in notes),
            "alternates": alternates,
            "level": str(r["部"]),
            "lesson": lesson,
            "activity": int(r["活動"]),
            "topicTag": "" if pd.isna(topic) else str(topic).strip(),
        })
    return out


def build_patterns(path):
    df = pd.read_excel(path, sheet_name="★いろどり文法･文型リスト", header=2)
    for c in ("冊", "トピック", "タイトル"):
        df[c] = df[c].ffill()
    df = df[df["文型"].notna() & df["例文"].notna()]
    out = []
    for i, (_, r) in enumerate(df.iterrows(), start=1):
        title = str(r["タイトル"])
        m = re.search(r"第(\d+)課", title)
        lesson = int(m.group(1)) if m else 0
        title_lines = [t.strip() for t in title.split("\n") if t.strip()]
        lesson_title = title_lines[-1] if len(title_lines) > 1 else title.strip()
        out.append({
            "id": i,
            "level": BOOK_LEVEL[str(r["冊"]).strip()],
            "lesson": lesson,
            "lessonTitle": lesson_title,
            "topic": str(r["トピック"]).replace("\n", " ").strip(),
            "pattern": " / ".join(l.strip() for l in str(r["文型"]).split("\n") if l.strip()),
            "example": " ".join(l.strip() for l in str(r["例文"]).split("\n") if l.strip()),
        })
    return out


def build_kanji(path):
    df = pd.read_excel(path, sheet_name="単漢字リスト", header=1)
    out = []
    for i, (_, r) in enumerate(df.iterrows(), start=1):
        out.append({
            "id": i,
            "kanjiNumber": int(r["漢字\n番号"]),
            "isFirstAppearance": str(r["提出\n状況"]).strip() == "初出",
            "kanji": str(r["漢字"]).strip(),
            "reading": str(r["読み方"]).strip(),
            "word": str(r["単語"]).strip(),
            "wordReading": str(r["読み"]).strip(),
            "level": BOOK_LEVEL[str(r["冊"]).strip()],
            "lesson": int(r["課"]),
        })
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=os.path.expanduser("~/Downloads"))
    ap.add_argument("--out", default="Kachiiro/Resources/irodori_seed.json")
    a = ap.parse_args()

    words = build_words(os.path.join(a.src, "wordlist_all.xlsx"))
    patterns = build_patterns(os.path.join(a.src, "sentence_patterns_list.xlsx"))
    kanji = build_kanji(os.path.join(a.src, "kanji_list.xlsx"))

    assert len(words) == 3797, len(words)
    assert len(patterns) == 259, len(patterns)
    assert len(kanji) == 659, len(kanji)
    assert len({k["kanji"] for k in kanji}) == 429
    assert len({w["id"] for w in words}) == len(words)
    assert {w["level"] for w in words} <= LEVEL_OK
    bad = []
    for w in words:
        if w["pos"] in ("V［1］", "V［2］", "V［3］", "イA", "ナA"):
            for f in ("headword", "reading"):
                if re.search(r"[（）()／]", w[f]):
                    bad.append((w["id"], f, w[f]))
    assert not bad, bad[:10]

    os.makedirs(os.path.dirname(a.out) or ".", exist_ok=True)
    with open(a.out, "w", encoding="utf-8") as f:
        json.dump({"words": words, "patterns": patterns, "kanji": kanji}, f, ensure_ascii=False, indent=0)
    print(f"words={len(words)} patterns={len(patterns)} kanji={len(kanji)} unique_kanji={len({k['kanji'] for k in kanji})}")


if __name__ == "__main__":
    sys.exit(main())
