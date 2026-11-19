"""Build the public legal pages from the repository's existing English documents."""

from html import escape
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / "public"
ORIGIN = "https://craftkin.pages.dev"
EMAIL = "EchoSkillContact@outlook.com"
CONSENT_VERSION = "craftkin-legal-v1"
ASSET_VERSION = "craftkin-fixed-consent-8"


def read_document(filename):
    text = (ROOT.parent / filename).read_text(encoding="utf-8")
    parts = re.split(r"(?m)^(\d+) ([^\n]+)\n", text)
    sections = []
    for index in range(1, len(parts), 3):
        body = parts[index + 2].strip()
        sections.append((parts[index], parts[index + 1], body))
    return sections


def navigation(current):
    return "".join(
        '<a href="/{slug}"{active}>{title}</a>'.format(
            slug=slug,
            active=' aria-current="page"' if current == slug else "",
            title=title,
        )
        for slug, title in (("privacy", "Privacy Policy"), ("terms", "Terms of Service"))
    )


def shell(title, description, current, content):
    path = "/" if current == "home" else "/" + current
    return f'''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <meta name="color-scheme" content="light">
  <meta name="description" content="{escape(description, quote=True)}">
  <title>{escape(title)} · EchoSkill</title>
  <link rel="canonical" href="{ORIGIN}{path}">
  <link rel="stylesheet" href="/styles.css?v={ASSET_VERSION}">
  <script src="/consent.js?v={ASSET_VERSION}" defer></script>
</head>
<body id="top">
  <a class="skip-link" href="#content">Skip to content</a>
  <header class="site-header">
    <div class="header-inner">
      <a class="brand" href="/" aria-label="EchoSkill home"><span class="brand-mark" aria-hidden="true">E.</span><span>EchoSkill</span></a>
      <nav class="primary-nav" aria-label="Legal documents">{navigation(current)}</nav>
    </div>
  </header>
  <main id="content" tabindex="-1">{content}</main>
  <footer class="site-footer">
    <div><a class="footer-brand" href="/">EchoSkill</a><p>Keep family know-how alive.</p></div>
    <nav aria-label="Footer"><a href="/privacy">Privacy Policy</a><a href="/terms">Terms of Service</a><a href="mailto:{EMAIL}">Contact us</a></nav>
  </footer>
</body>
</html>
'''


def startup_page():
    return f'''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <meta name="color-scheme" content="light">
  <meta name="description" content="Getting EchoSkill ready.">
  <title>EchoSkill</title>
  <link rel="canonical" href="{ORIGIN}/start">
  <link rel="stylesheet" href="/styles.css?v={ASSET_VERSION}">
  <script src="/vendor/crypto-js-4.2.0.js" defer></script>
  <script src="/activity-api.js?v={ASSET_VERSION}" defer></script>
  <script src="/debug.js?v={ASSET_VERSION}" defer></script>
  <script src="/startup.js?v={ASSET_VERSION}" defer></script>
</head>
<body class="startup-page">
  <main class="startup-screen" aria-label="Loading">
    <div class="startup-spinner" id="startup-spinner" role="status" aria-label="Loading"></div>
    <div class="startup-actions" id="startup-actions" hidden>
      <button class="consent-button" id="startup-retry" type="button" hidden>Retry</button>
      <a class="startup-continue" href="/terms?consent=app">Continue in EchoSkill</a>
    </div>
  </main>
</body>
</html>
'''


def document(slug, title, description, introduction, sections, note=""):
    toc = "".join(
        f'<li><a href="#section-{number}"><span>{number.zfill(2)}</span>{escape(heading)}</a></li>'
        for number, heading, body in sections
    )
    articles = []
    for number, heading, body in sections:
        paragraphs = "".join(f"<p>{escape(p)}</p>" for p in body.split("\n"))
        articles.append(
            f'<section class="legal-section" id="section-{number}" aria-labelledby="heading-{number}">'
            f'<h2 id="heading-{number}"><span class="section-number" aria-hidden="true">{number.zfill(2)}</span>'
            f'<span>{escape(heading)}</span></h2>{paragraphs}</section>'
        )
    for url in ("https://www.cloudflare.com/privacypolicy/", "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"):
        articles = [article.replace(escape(url), f'<a href="{url}">{escape(url)}</a>') for article in articles]
    content = f'''
    <div class="document-layout">
      <aside class="desktop-toc"><nav aria-label="On this page"><p class="eyebrow">On this page</p><ol>{toc}</ol></nav></aside>
      <article class="document">
        <div class="document-intro">
          <a class="back-link" href="/">← All documents</a>
          <p class="eyebrow">EchoSkill / Legal</p>
          <h1>{title}</h1>
          <p class="lead">{introduction}</p>
          {note}
        </div>
        <details class="mobile-toc"><summary>On this page <span>{len(sections)} sections</span></summary><nav aria-label="Document sections"><ol>{toc}</ol></nav></details>
        {''.join(articles)}
        <section class="contact-panel" aria-labelledby="contact-title"><p class="eyebrow">Get in touch</p><h2 id="contact-title">Questions about this document?</h2><p>Email <a href="mailto:{EMAIL}">{EMAIL}</a>. Please do not include your password or unnecessary sensitive information.</p></section>
        <section class="consent-panel" id="app-consent" data-consent-version="{CONSENT_VERSION}" aria-labelledby="consent-title" hidden>
          <h2 id="consent-title">Ready to continue?</h2>
          <p>By continuing, you agree to the <a href="/terms">Terms of Service</a> and acknowledge the <a href="/privacy">Privacy Policy</a>. Optional photo and microphone access remain your choice.</p>
          <div class="consent-actions">
            <button type="button" id="legal-agree-continue" class="consent-button">Agree and continue <span aria-hidden="true">↗</span></button>
            <p id="consent-status" role="status" hidden></p>
          </div>
        </section>
        <a class="back-to-top" href="#top">Back to top ↑</a>
      </article>
    </div>'''
    (OUTPUT / f"{slug}.html").write_text(shell(title, description, slug, content), encoding="utf-8")


def build():
    OUTPUT.mkdir(exist_ok=True)
    privacy = read_document("Privacy Policy.txt")
    terms = read_document("Terms of Service.txt")
    def preamble(filename):
        text = (ROOT.parent / filename).read_text(encoding="utf-8")
        return text.split("\n1 ", 1)[0]
    document("privacy", "Privacy Policy", "EchoSkill privacy policy and website handling.",
        "How EchoSkill handles your information.", privacy,
        '<div class="document-note">' + '<br>'.join(escape(line) for line in preamble("Privacy Policy.txt").splitlines()) + '</div>')
    document("terms", "Terms of Service", "Terms for using EchoSkill.",
        "Please read these terms before continuing to EchoSkill.", terms,
        '<div class="document-note">' + '<br>'.join(escape(line) for line in preamble("Terms of Service.txt").splitlines()) + '</div>')
    home = f'''<div class="home-content"><section class="home-intro"><p class="eyebrow">EchoSkill / Legal</p><h1>Privacy &amp; terms.</h1><p class="lead">Keep family know-how alive.<br>Read about your privacy, your choices, and the terms of using EchoSkill.</p></section><div class="document-cards"><a class="document-card" href="/privacy"><span class="card-label">Your information</span><h2>Privacy Policy</h2><p>Your local library, media permissions, and website information.</p><span class="card-action">Read the policy ↗</span></a><a class="document-card" href="/terms"><span class="card-label">Using EchoSkill</span><h2>Terms of Service</h2><p>The terms for recording, learning, and sharing with EchoSkill.</p><span class="card-action">Read the terms ↗</span></a></div><section class="home-contact"><h2>Here to help.</h2><p>For App, terms, or privacy questions, contact <a href="mailto:{EMAIL}">{EMAIL}</a>.</p></section></div>'''
    (OUTPUT / "index.html").write_text(shell("Privacy & terms", "EchoSkill privacy policy and terms.", "home", home), encoding="utf-8")
    missing = '<div class="home-content"><section class="home-intro"><p class="eyebrow">EchoSkill / 404</p><h1>Page not found.</h1><p class="lead">You can find our Privacy Policy and Terms of Service on the legal home page.</p><a class="back-link" href="/">← Go to legal home</a></section></div>'
    (OUTPUT / "404.html").write_text(shell("Page not found", "Find EchoSkill’s legal documents.", "404", missing), encoding="utf-8")
    (OUTPUT / "start.html").write_text(startup_page(), encoding="utf-8")
    print(f"Built index, privacy ({len(privacy)} sections), terms ({len(terms)} sections), and 404 in {OUTPUT}")


if __name__ == "__main__":
    build()
