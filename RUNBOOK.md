# Runbook — checks before pushing

This site is deployed via GitHub Pages on the `deepgenai.ai` custom domain
(root, `baseurl: ""` — see "Deployment / domain" below). GitHub Pages
builds with **`_config.yml` only**. Before the custom domain was wired up,
this repo briefly ran with a non-empty `baseurl` (`/deepgenai.ai`, to match
the interim `deepgenai-ai.github.io/deepgenai.ai/` project-page URL), and
that's what makes this repo unusually easy to break in a way that only
shows up after you push: a link that skips Jekyll's `relative_url` filter
works fine whenever `baseurl` is `""` and silently 404s the moment it isn't
— which is exactly what happened twice in one session before this runbook
existed. `baseurl` is `""` again now, so that specific failure mode is
dormant, but keep using `relative_url` for every internal link anyway
(cheap insurance if `baseurl` ever changes again — e.g. a future preview
deploy under a subpath) and keep running `bin/checklinks.rb`, which also
catches plain broken/typo'd links regardless of baseurl.

## Local dev

```
bundle exec jekyll serve --port 4000 --config _config.yml,_config_dev.yml
```

`_config_dev.yml` overrides `url` for local serving (points it at
`127.0.0.1:4000` instead of `https://deepgenai.ai`, which mostly matters
for canonical tags/sitemap, not for links) — `baseurl` is `""` in both
configs now, so plain `bundle exec jekyll serve` works fine too if you
don't need that. Still prefer the `--config` form above out of habit;
if `baseurl` ever needs to diverge from production again (see the intro),
this is the file that absorbs it.

## Before every push

1. **Run the link checker** — builds the site exactly the way GitHub Pages
   does (`_config.yml` only, no dev overrides) and checks every internal
   `href`/`src`:

   ```
   bundle exec ruby bin/checklinks.rb
   ```

   This catches: links missing the `baseurl` prefix if it's ever non-empty
   again (a raw `href="/foo/"` or `{{ item.url }}` instead of
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

- Production config (`_config.yml`): `url: https://deepgenai.ai`,
  `baseurl: ""`. Matches the `CNAME` file (`deepgenai.ai`) and the custom
  domain set in the repo's GitHub Pages settings (owner-configured
  2026-09-06). The old interim URL,
  `https://deepgenai-ai.github.io/deepgenai.ai/`, should 301-redirect to
  the custom domain automatically once DNS/HTTPS are fully live — no
  config on our side handles that, it's GitHub Pages' behavior whenever a
  `CNAME` file is present.
- Before this, `deepgenai.ai`'s DNS pointed to a live GoDaddy Website
  Builder site (confirmed 2026-09-06) — the owner is the one switching
  DNS to GitHub Pages, not something to redo/undo from this repo. If
  `deepgenai.ai` ever stops resolving to this site, that's a DNS/registrar
  question, not a Jekyll one — don't "fix" it by reverting `url`/`baseurl`
  without checking with the owner first.
- If a future preview ever needs to run from a subpath again (e.g. back on
  `deepgenai-ai.github.io/deepgenai.ai/`), that means `baseurl` needs to
  be non-empty again for that build — see the intro above for why that's
  the one config change most likely to break links.
