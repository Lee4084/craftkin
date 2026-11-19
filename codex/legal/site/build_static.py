"""Build the standalone static legal deployment, preserving the activity source."""

from pathlib import Path
import re
import shutil


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "public"
OUTPUT = ROOT / "static-public"
FILES = ("index.html", "terms.html", "privacy.html", "404.html", "styles.css", "consent.js")
VERSION = "craftkin-static-legal-1"


def build():
    OUTPUT.mkdir(exist_ok=True)
    for name in FILES:
        source = SOURCE / name
        target = OUTPUT / name
        if source.suffix == ".html":
            html = source.read_text(encoding="utf-8")
            html = re.sub(r'((?:styles\.css|consent\.js)\?v=)[^"\s]+', r'\g<1>' + VERSION, html)
            target.write_text(html, encoding="utf-8")
        else:
            shutil.copy2(source, target)
    redirects = (SOURCE / "_redirects").read_text(encoding="utf-8")
    redirects += "\n/start /terms?consent=app 302\n/start.html /terms?consent=app 302\n"
    (OUTPUT / "_redirects").write_text(redirects, encoding="utf-8")
    headers = (SOURCE / "_headers").read_text(encoding="utf-8")
    headers = headers.replace("connect-src 'self' https://test-app.dirtan.work", "connect-src 'none'")
    headers = headers.replace("Cache-Control: public, max-age=300, must-revalidate", "Cache-Control: no-store")
    (OUTPUT / "_headers").write_text(headers, encoding="utf-8")
    unexpected = {path.name for path in OUTPUT.iterdir()} - {*FILES, "_headers", "_redirects"}
    if unexpected:
        raise RuntimeError("Unexpected files in static deployment: " + ", ".join(sorted(unexpected)))
    print(f"Built static legal deployment in {OUTPUT}")


if __name__ == "__main__":
    build()
