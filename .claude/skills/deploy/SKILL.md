---
name: deploy
description: Deploys this repo's server/ backend (the Node/Express + EJS admin panel and API for GuessRush/Quizo) to its one production host at expensebeam.com. Use this whenever the user asks to deploy, ship, push live, put changes into production, or update the live admin panel — phrases like "deploy this", "ship it to prod", "push the server changes live", "deploy to the server", or just "deploy" in the context of this repo. Do NOT use this for building or releasing the Flutter mobile app (a completely different pipeline) or for running a local dev server.
---

# Deploying the GuessRush server

This repo's `server/` directory (a Node/Express + EJS admin panel and API) runs in
Docker Compose on a shared VPS at `expensebeam.com`. That same host also runs the
unrelated ExpenseBeam app in its own Docker stack — treat everything outside
`guessrush`-prefixed containers, volumes, and networks as off-limits.

The flow below is exactly what was done by hand to deploy the JSON bulk-import
feature: commit → push to GitHub → SSH in → pull → rebuild the one container →
verify. Follow it in order; don't skip the verification steps at the end just
because the build succeeded — a clean build only proves the code compiles, not
that it's actually serving traffic correctly.

## 1. Work out what's actually going into this deploy

Run `git status --short` at the repo root. This repo commonly has unrelated,
still-in-progress Flutter changes (`lib/`, `android/`, etc.) sitting in the
working tree alongside server changes — those belong to a separate, unfinished
piece of work and must never get swept into a deploy commit just because they
happened to be sitting there. Default to staging only paths under `server/`.

If there are server-relevant changes outside `server/` (rare, but possible —
e.g. a shared config), or if it's unclear whether a changed file under `server/`
is finished and meant to ship, ask the user rather than guessing. Silently
including someone's half-finished work in a production push is worse than
pausing to ask.

## 2. Rebuild the compiled CSS if needed

If any staged change touches a `.ejs` view or anything under `server/src/styles`,
run `npm run build:css` inside `server/` before committing, and stage the
regenerated `server/public/admin.css` too. The Docker build reruns this itself
(`build:css` is wired as a `predev`/`prestart` hook and also runs during the
image build), so skipping this step wouldn't break the deploy — but it would
leave the repo's checked-in CSS silently out of sync with the views next to it,
which is confusing for the next person (or the next session) reading the diff.

## 3. Commit and push

Commit the staged files with a message that explains why the change was made,
consistent with how commits are written elsewhere in this repo. Then confirm
with the user before running `git push origin master` — this publishes to the
shared GitHub repo (`abedelraof/GuessRush`), which is a step worth a quick
explicit go-ahead each time rather than assuming standing permission.

## 4. Pull and rebuild on the server

SSH access is already configured on this machine as `root@expensebeam.com`
(key-based, no prompts expected). If auth fails, stop and tell the user —
don't start guessing at other usernames or keys against someone's production
box.

The deployed checkout lives at `/root/guessrush` (same repo, `origin` =
`https://github.com/abedelraof/GuessRush.git`, branch `master`).

```
ssh root@expensebeam.com "cd /root/guessrush && git pull origin master"
```

Then rebuild and restart only the `api` service:

```
ssh root@expensebeam.com "cd /root/guessrush && docker compose -f docker-compose.yml -f docker-compose.prod.yml build api"
ssh root@expensebeam.com "cd /root/guessrush && docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d api"
```

Both compose files are required together — `docker-compose.prod.yml` is the
production overlay (joins the external `expensebeam_default` network so the
main ExpenseBeam stack's Caddy can reverse-proxy to `guessrush.expensebeam.com`,
tunes MySQL down for the shared 2GB host, uses `guessrush_`-prefixed named
volumes, and publishes no host ports). Running compose with only the base file
would drift the running container away from how it's actually meant to be
configured.

**Restarting `api` is meant to be routine and low-risk** — it's stateless, and
`up -d api` only recreates that one service. Confirm with the user before
running it, the same way you would before the push, since it does affect a
live production service — but there's no need to treat it as more dangerous
than that. Leave `mysql` alone entirely unless the user explicitly asks for it:
don't add it to the `build`/`up` target list, and don't run `docker compose
down`, `docker system prune`, or anything else scoped to the whole host — those
would affect the co-located ExpenseBeam app too, and there is no case where
this deploy needs them.

## 5. Read the startup logs — don't just trust a clean build

```
ssh root@expensebeam.com "cd /root/guessrush && docker compose -f docker-compose.yml -f docker-compose.prod.yml logs api --tail=20"
```

A healthy boot looks like: `Schema applied.`, then the seed step reporting
either `Seeded N ...` (first run) or `... already seeded, skipping.` (the
normal case on a redeploy — the seed script is idempotent, so this is not an
error), then `Admin account already exists, skipping.`, and finally `GuessRush
API listening on port 3000`.

One line is a genuine red flag: if that last seed line instead says `Seeded
admin account: ...` on a redeploy (i.e. an admin account already existed
before), that means the database came back empty — the persistent volume
wasn't actually attached, and prior data is gone. Stop immediately and tell the
user; don't paper over it by treating the deploy as successful.

## 6. Smoke-test that the new code is actually live

A successful `docker compose build` only proves the image compiled — confirm
the running container is serving it. Hit a route that changed in this deploy
with an unauthenticated request (or `/admin/login` at minimum) using whatever
browser tool is available. A newly-added admin route should now redirect to
`/admin/login`; if it still 404s ("Cannot GET ..."), the new code didn't
actually make it into the running container and something upstream needs
re-checking (image not rebuilt, wrong compose files, cached layer, etc.).

If verifying something that requires being logged into the admin panel, use
the user's already-authenticated Chrome extension session rather than asking
for or entering admin credentials — entering a password into a login form is
never something to do on the user's behalf, no matter who asks.

## 7. Report back

Summarize concisely: what was committed and pushed (message/hash), that the
container rebuilt and restarted cleanly, what the log check showed, and what
the smoke test confirmed. If anything in steps 5-6 came back unexpected, lead
with that instead of a clean summary — the user needs to know before anything
else.
