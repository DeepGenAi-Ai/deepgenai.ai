# Runbook — checks before pushing

This site is deployed via GitHub Pages at
`https://deepgenai-ai.github.io/deepgenai.ai/` (not yet on the
`deepgenai.ai` custom domain — see "Deployment / domain" below). GitHub
Pages builds with **`_config.yml` only**, using a non-empty `baseurl`
(`/deepgenai.ai`), which is what makes this repo unusually easy to break in
a way that only shows up after you push: a link that works fine in local
dev (baseurl `""`) can 404 in production if it skips Jekyll's `relative_url`
filter. That exact bug shipped twice in one session before this runbook
existed — hence this checklist and `bin/checklinks.rb`.

## Local dev

```
bundle exec jekyll serve --port 4000 --config _config.yml,_config_dev.yml
```

`_config_dev.yml` overrides `baseurl`/`url` for local serving so links
resolve at plain `http://127.0.0.1:4000/`. Don't run local dev with just
`_config.yml` unless you're deliberately reproducing the production
baseurl (e.g. debugging a link issue) — pass `--baseurl /deepgenai.ai` if
you do, and remember the server address becomes
`http://127.0.0.1:4000/deepgenai.ai/`, not the plain root.

## Before every push

1. **Run the link checker** — builds the site exactly the way GitHub Pages
   does (`_config.yml` only, no dev overrides) and checks every internal
   `href`/`src`:

   ```
   bundle exec ruby bin/checklinks.rb
   ```

   This catches: links missing the `/deepgenai.ai` baseurl prefix (a raw
   `href="/foo/"` or `{{ item.url }}` instead of
   `{{ '/foo/' | relative_url }}`), links pointing at pages that don't
   exist, and a build accidentally containing `localhost`/`127.0.0.1`
   (a sign the dev config leaked into what should be a production build).
   Fix everything it reports — don't push past a red run.

2. **If you touched anything in `_includes/header.html`, `_sass/_header.scss`,
   or `assets/js/effects.js`** (the responsive header/nav), eyeball it at a
   few widths, not just your own monitor size. A quick way without a real
   device:

   ```
   cd /tmp && npm init -y >/dev/null 2>&1 && npm install playwright >/dev/null 2>&1 \
     && npx playwright install chromium
   ```

   then screenshot the header at 320, 344 (Galaxy Z Fold 5 cover screen —
   this is what surfaced the original overlap bug), 375, 414, 760, 800,
   900, and 961px. Check for: the brand name and any header buttons not
   overlapping, the hamburger menu actually opening/closing, and no
   unexpected wrapped/stacked text. The header has broken at "in-between"
   widths (761–930px) before — don't just check phone widths and assume
   desktop is fine.

3. **If you touched `_config.yml`** — specifically `url` or `baseurl` —
   re-run the link checker (step 1) and re-read "Deployment / domain"
   below before changing either value; they're deliberately not what
   you'd guess from the domain name.

4. **New pages/links**: use `{{ '/your/path/' | relative_url }}` for every
   internal `href`/`src`, never a hardcoded `href="/your/path/"` and never
   raw Liquid data (`{{ item.url }}`) without piping it through
   `relative_url` first. The link checker will catch it if you forget, but
   it's faster to just get it right.

## Commit / push

- Commit at the end of every turn unless it ends with a question back to
  the owner (standing preference — see project memory).
- This repo has no CI, so `bin/checklinks.rb` passing locally is the only
  gate before GitHub Pages serves whatever you pushed. There's no staging
  environment — a push to `main` is live within ~1 minute.
- Track anything on the live site that isn't yet owner-confirmed in
  `../resources/deepgenai.ai-website/Owner_Questions.md`, not just this repo.

## Deployment / domain

- Production config (`_config.yml`): `url: https://deepgenai-ai.github.io`,
  `baseurl: /deepgenai.ai`. This matches the current GitHub Pages
  project-page URL, **not** the eventual `deepgenai.ai` custom domain.
- `deepgenai.ai`'s DNS currently points to a live GoDaddy Website Builder
  site (confirmed 2026-09-06) — something real is served there today, so
  don't add a `CNAME` file or point DNS at GitHub Pages without the
  owner's explicit go-ahead.
- When the custom domain is actually wired up: change `_config.yml` to
  `url: https://deepgenai.ai`, `baseurl: ""`, add a `CNAME` file containing
  `deepgenai.ai`, and point DNS at GitHub Pages. GitHub Pages will then
  301-redirect the old `deepgenai-ai.github.io/deepgenai.ai/` URL to the
  custom domain automatically — you don't need both configs to work at
  once.
