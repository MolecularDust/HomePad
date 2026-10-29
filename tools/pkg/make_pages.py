#!/usr/bin/env python3
"""The installer's text in every language, from tools/pkg/text/<code>.json (English: en.json).

    make_pages.py <out-dir>        writes <out-dir>/<code>.lproj/{welcome,readme,conclusion}.html and
                                   Localizable.strings (the Trash warning in distribution.xml), English also at the top
                                   level as Installer's fallback
    make_pages.py --check          reports keys missing from a language, or <b> tags that don't match English

Installer turns these pages into plain styled text, so they keep to headings, paragraphs and numbered lists
(style.css). The disk image's picture and names come from the same files (the d_* keys; make_installer_dmg.sh).
"""
import glob, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
RTL = {"ar", "fa"}
PAGES = {
    "welcome": [("h1", "w_title"), ("p", "w_p1"), ("p", "w_p2"), ("h2", "w_h"), ("ol", ["w_li1", "w_li2"]), ("muted", "w_muted")],
    "readme": [("h1", "r_title"), ("p", "r_p"),
               ("h2", "r_sr_h"), ("ol", ["r_sr_1", "r_sr_2", "r_sr_3"]),
               ("h2", "r_ax_h"), ("ol", ["r_ax_1", "r_ax_2"]),
               ("h2", "r_fda_h"), ("ol", ["r_fda_1", "r_fda_2"]),
               ("p", "r_end")],
    "conclusion": [("h1", "c_title"), ("p", "c_p"), ("h2", "c_use_h"), ("p", "c_use"), ("h2", "c_open_h"), ("p", "c_open"),
                   ("h2", "c_trash_h"), ("p", "c_trash"), ("muted", "c_muted")],
}


def languages():
    return {os.path.basename(p)[:-5]: json.load(open(p)) for p in sorted(glob.glob(os.path.join(HERE, "text", "*.json")))}


def page(blocks, t, rtl, lang="en"):
    css = open(os.path.join(HERE, "resources", "style.css")).read()
    if rtl:
        css += "body { direction: rtl; text-align: right; }\np.step { margin: 4px 22px 4px 0; }\n"
    out = [f'<!DOCTYPE html>\n<html{" dir=\"rtl\"" if rtl else ""}><head><meta charset="utf-8"><style>\n{css}</style></head><body>']
    for kind, key in blocks:
        if kind == "ol" and rtl:
            # Installer's text conversion puts list numbers on the left even in right-to-left text, so the numbers
            # are written in, in the language's own digits.
            digits = "٠١٢٣٤٥٦٧٨٩" if lang == "ar" else "۰۱۲۳۴۵۶۷۸۹"
            out.append("\n".join(f'<p class="step">{digits[n]}. {t[k]}</p>' for n, k in enumerate(key, 1)))
        elif kind == "ol":
            out.append("<ol>\n" + "\n".join(f"<li>{t[k]}</li>" for k in key) + "\n</ol>")
        elif kind == "muted":
            out.append(f'<p class="muted">{t[key]}</p>')
        else:
            out.append(f"<{kind}>{t[key]}</{kind}>")
    return "\n".join(out) + "\n</body></html>\n"


def strings(t):
    esc = lambda s: s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    return "".join(f'"{k}" = "{esc(t[k])}";\n' for k in ("trash_title", "trash_message"))


def main():
    langs = languages()
    en = langs["en"]
    if sys.argv[1:] == ["--check"]:
        problems = 0
        for code, t in langs.items():
            for k in en:
                if k not in t:
                    problems += 1; print(f"{code}: missing {k}")
                elif re.findall(r"</?b>|\*\*", en[k]).__len__() != re.findall(r"</?b>|\*\*", t[k]).__len__():
                    problems += 1; print(f"{code}: bold marks differ in {k}")
        print(f"{len(langs)} languages, {problems} problems")
        sys.exit(1 if problems else 0)
    out = sys.argv[1]
    for code, t in langs.items():
        t = {**en, **t}
        folder = os.path.join(out, code + ".lproj")
        os.makedirs(folder, exist_ok=True)
        for name, blocks in PAGES.items():
            html = page(blocks, t, code in RTL, code)
            open(os.path.join(folder, name + ".html"), "w").write(html)
            if code == "en":
                open(os.path.join(out, name + ".html"), "w").write(html)
        open(os.path.join(folder, "Localizable.strings"), "w").write(strings(t))


if __name__ == "__main__":
    main()
