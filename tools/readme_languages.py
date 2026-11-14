#!/usr/bin/env python3
"""Keeps the README language chooser in sync and checks the translated READMEs.

    tools/readme_languages.py          rewrite the chooser in README.md and docs/i18n/README.*.md
    tools/readme_languages.py --check  report problems (exit code 1 if there are any)

The English README.md is the original; the translations are docs/i18n/README.<code>.md. To add a language: add a
row to LANGUAGES, write docs/i18n/README.<code>.md with the two <!-- languages:... --> markers (leave them empty),
and run this script without arguments. The layout follows the Caption Finder README.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Codes and native names follow HomePad's localization (English first, the rest alphabetical by English name).
LANGUAGES = [
    ("en", "English"), ("ar", "العربية"), ("bn", "বাংলা"), ("zh-Hans", "简体中文"), ("fil", "Filipino"),
    ("fr", "Français"), ("de", "Deutsch"), ("hi", "हिन्दी"), ("id", "Bahasa Indonesia"), ("it", "Italiano"),
    ("ja", "日本語"), ("ko", "한국어"), ("fa", "فارسی"), ("pt-BR", "Português (Brasil)"), ("ru", "Русский"),
    ("es", "Español"), ("te", "తెలుగు"), ("th", "ไทย"), ("tr", "Türkçe"), ("vi", "Tiếng Việt"),
]
COLUMNS = 5
START = "<!-- languages:start -->"
END = "<!-- languages:end -->"
# The word "Language" in many scripts, so every reader can recognise the menu.
LABEL = "🌐 Language · Idioma · Langue · Sprache · Язык · 语言 · 言語 · 언어 · भाषा · لغة"

ENGLISH = os.path.join(ROOT, "README.md")


def path_for(code):
    return ENGLISH if code == "en" else os.path.join(ROOT, "docs", "i18n", f"README.{code}.md")


def chooser(current):
    def href(code):
        if current == "en":
            return "README.md" if code == "en" else f"docs/i18n/README.{code}.md"
        return "../../README.md" if code == "en" else f"README.{code}.md"

    cells = [f'    <td align="center"><b>{name}</b></td>' if code == current
             else f'    <td align="center"><a href="{href(code)}">{name}</a></td>' for code, name in LANGUAGES]
    rows = [f"  <tr>\n" + "\n".join(cells[i:i + COLUMNS]) + "\n  </tr>" for i in range(0, len(cells), COLUMNS)]
    return "\n".join([START, '<div align="center">', "", "<details>", f"<summary><b>{LABEL}</b></summary>", "<br>", "",
                      "<table>", *rows, "</table>", "", "</details>", "", "</div>", END])


def with_chooser(text, current):
    body = text.replace("\r\n", "\n")
    block = chooser(current)
    a, b = body.find(START), body.find(END)
    if a >= 0 and b > a:
        return body[:a] + block + body[b + len(END):]
    return f"{block}\n\n{body}"          # README.md gets the chooser above its title the first time


def strip_chooser(text):
    return re.sub(re.escape(START) + r"[\s\S]*?" + re.escape(END) + r"\n*", "", text.replace("\r\n", "\n"))


def reference_text():
    """What a translation has to cover: everything before '## Development', plus the License section."""
    text = strip_chooser(open(ENGLISH, encoding="utf-8").read())
    dev, lic = text.find("\n## Development"), text.find("\n## License")
    if dev < 0 or lic < 0:
        sys.exit("README.md has no Development or License heading")
    return text[:dev] + "\n" + text[lic:]


def spans(text):
    return set(re.findall(r"`([^`\n]+)`", text))


def urls(text):
    return set(re.findall(r"https?://[^\s)\"<>]+", text))


def shape(text):
    count = lambda pattern: len(re.findall(pattern, text, re.M))
    return {"h2": count(r"^## "), "h3": count(r"^### "), "bullets": count(r"^\s*[-*] "),
            "steps": count(r"^\s*\d+\. "), "rows": count(r"^\|.*\|\s*$")}


def check():
    problems = []
    ref = reference_text()
    ref_spans, ref_urls, ref_shape = spans(ref), urls(ref), shape(ref)
    english = open(ENGLISH, encoding="utf-8").read().replace("\r\n", "\n")
    if english != with_chooser(english, "en"):
        problems.append("README.md: the language chooser is out of date")
    for code, _ in LANGUAGES:
        if code == "en":
            continue
        file, label = path_for(code), f"docs/i18n/README.{code}.md"
        if not os.path.exists(file):
            problems.append(f"{label}: missing")
            continue
        raw = open(file, encoding="utf-8").read().replace("\r\n", "\n")
        if raw != with_chooser(raw, code):
            problems.append(f"{label}: the language chooser is out of date")
        body = re.sub(r"</?div[^>]*>\n?", "", strip_chooser(raw))
        got_spans, got_urls = spans(body), urls(body)
        problems += [f"{label}: missing code text `{s}`" for s in sorted(ref_spans - got_spans)]
        problems += [f"{label}: unexpected code text `{s}`" for s in sorted(got_spans - ref_spans)]
        problems += [f"{label}: missing link {u}" for u in sorted(ref_urls - got_urls)]
        problems += [f"{label}: unexpected link {u}" for u in sorted(got_urls - ref_urls)]
        got = shape(body)
        want = dict(ref_shape, h2=ref_shape["h2"] + 1)          # one extra heading: the Development note
        problems += [f"{label}: {k} is {got[k]}, expected {want[k]}" for k in want if got[k] != want[k]]
        for m in re.finditer(r'\]\((?!https?:|#)([^)\s]+)\)|src="([^"]+)"', body):
            target = (m.group(1) or m.group(2)).split("#")[0]
            if target and not os.path.exists(os.path.normpath(os.path.join(os.path.dirname(file), target))):
                problems.append(f"{label}: broken path {target}")
    return problems


def main():
    if "--check" in sys.argv:
        problems = check()
        if problems:
            print("\n".join(problems))
            print(f"\n{len(problems)} problem(s).")
            sys.exit(1)
        print(f"README languages are in sync ({len(LANGUAGES)} languages).")
        return
    changed = 0
    for code, _ in LANGUAGES:
        file = path_for(code)
        if not os.path.exists(file):
            continue
        before = open(file, encoding="utf-8").read()
        after = with_chooser(before, code)
        if after != before:
            open(file, "w", encoding="utf-8").write(after)
            changed += 1
    print(f"Updated the chooser in {changed} file(s).")


if __name__ == "__main__":
    main()
