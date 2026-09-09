---
title: "Web Enumeration"
teaching: 15
exercises: 65
---

:::::::::::::::::::::::::::::::::::::: questions

- How do you discover hidden directories and files a web server hosts but doesn't link to?
- Why does a path listed in `robots.txt` become *more* interesting to check, not less?
- What's the difference between what gobuster/dirb/ffuf are designed to find and what nikto is designed to find?
- Why can't a wordlist-based brute-force tool find every sensitive file on its own?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Check `robots.txt` as a first, free reconnaissance step
- Brute-force directories and files with `gobuster`, `dirb`, and `ffuf`
- Follow up manually on a discovery to find content a wordlist can't
- Run `nikto` for automated misconfiguration and missing-header checks

::::::::::::::::::::::::::::::::::::::::::::::::

## Introduction

A web server's homepage rarely shows everything that's actually deployed on
it. This lab practices finding what's *not* linked — hidden directories,
backup files, admin panels — using directory/file brute-forcing tools, plus
`nikto` for automated misconfiguration checks.

::::::::::::::::::::::::::::::::::::: callout

### Scope note

Every command below targets only the containers started by this lab's own
`docker-compose.yaml` (subnet `10.10.4.0/24`). Don't point these tools
anywhere else. See the [statutory warning on the lesson home page](../index.html)
and [Setup](../learners/setup.html) before you begin.

::::::::::::::::::::::::::::::::::::::::::::::::

**Tools used:** `gobuster`, `dirb`, `ffuf`, `nikto`
**Network:** `lab4-attacker` (10.10.4.2, Kali attacker) · `lab4-web` (10.10.4.10, Nginx web server with undisclosed paths)

Follow [Setup](../learners/setup.html) to build the shared attacker image,
then

```bash
cd episodes/files/lab4-web-enumeration
docker compose up -d
```

before continuing.

## Part 1: Check the Obvious First

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 1.1: robots.txt

Before brute-forcing anything, always check `robots.txt` — it exists to
tell *search engine crawlers* what to skip, which ironically makes it a
great list of "paths the owner doesn't want indexed."

```bash
curl http://10.10.4.10/robots.txt
```

1. What paths does it disallow?
2. Why would a path being listed in `robots.txt` make it *more* interesting
   to check manually, not less?

:::::::::::::::::::::::: solution

1. `/admin/` and `/backup/`.
2. `robots.txt` isn't an access-control mechanism — it's a plain-text file
   the server hands to anyone who asks, and it only works because
   well-behaved crawlers *choose* to respect it. A site owner listing a path
   there is effectively publishing a list of things they'd rather not have
   found, which makes it the first place an attacker should look, not the
   last.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 2: Directory Brute-Forcing

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 2.1: gobuster

```bash
gobuster dir -u http://10.10.4.10 -w /usr/share/dirb/wordlists/common.txt
```

List every directory/file gobuster found, with its status code.

:::::::::::::::::::::::: solution

The exact table depends on what's in `common.txt`, but this server has
three real directories under its web root: `/admin/`, `/backup/`, and
`/uploads/`, each holding a static `index.html` that Nginx serves directly
(so a hit reports status `200`, or a `301` redirect from `/admin` to
`/admin/` if requested without the trailing slash). `robots.txt` itself may
also turn up as a `200` hit, since it's a very common wordlist entry.
Anything not present on the server (the vast majority of the wordlist)
reports Nginx's default `404`.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 2.2: dirb

```bash
dirb http://10.10.4.10 /usr/share/dirb/wordlists/common.txt
```

Did dirb find the same paths as gobuster? Note any differences in what
each tool reported.

:::::::::::::::::::::::: solution

Against the same target with the same wordlist, dirb should turn up the
same three directories (`/admin/`, `/backup/`, `/uploads/`) that gobuster
found — the *paths discovered* don't depend on which tool asked for them.
The differences are in behavior and output: dirb is noticeably slower
(single-threaded by default), recurses into directories it finds
automatically, and formats its report differently (a running `+` list of
hits rather than gobuster's one-line-per-request status output).

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 2.3: ffuf

`ffuf` uses an explicit `FUZZ` keyword in the URL to mark where the
wordlist gets substituted:

```bash
ffuf -w /usr/share/dirb/wordlists/common.txt -u http://10.10.4.10/FUZZ
```

`ffuf` is generally much faster than `dirb`. What in its output (besides
speed) tells you it found a real hit versus a false positive?

:::::::::::::::::::::::: solution

`ffuf` prints the response size, word count, and line count alongside the
status code for every request. A genuine hit (like `/admin`) returns a
distinct status and a content length matching the real page, while every
non-existent path returns Nginx's consistent default `404` response with
its own fixed size. Once you know what the "nothing here" response looks
like, any request whose status or size breaks that pattern is a real find
— not just a coincidence of the wordlist.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 3: Following Up on What You Found

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 3.1: Visit the discovered admin path

```bash
curl -s http://10.10.4.10/admin/
```

Did the page contain anything interesting in an HTML comment? If so, what
did it say?

:::::::::::::::::::::::: solution

Yes. The page source has two HTML comments: one contains a
`flag{...}`-formatted string, and a second is a developer note saying the
site's nightly database export lands in `/backup/` as a specific
`.sql` filename — a direct clue for where to look next.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 3.2: Act on a filename the page mentioned

A brute-force wordlist can only find paths that are *in the wordlist*.
Once a page tells you an exact filename, request it directly — that's
manual enumeration picking up where automated enumeration stops.

```bash
curl -s http://10.10.4.10/backup/<filename-you-found>
```

1. What did the file contain?
2. Why couldn't gobuster/dirb/ffuf have found this file on their own, even
   with a good wordlist?

:::::::::::::::::::::::: solution

1. The filename from the admin page's comment is `db_export_2024.sql`.
   Requesting it returns a small SQL dump: an `INSERT` statement for a
   `users` table referencing a `svc_backup` account with a note reading
   "do not expose this file publicly," plus another `flag{...}`-formatted
   string.
2. Wordlist tools can only guess filenames that are actually *in* their
   wordlist — generic terms like `admin`, `backup`, `login`. A filename
   like `db_export_2024.sql` is specific to this one deployment and its
   naming convention; no generic wordlist would contain it. The only way
   to find it is to read what the server itself told you (the developer
   comment) and act on that clue manually.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 4: Automated Vulnerability Scanning with Nikto

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 4.1: Run nikto

```bash
nikto -h http://10.10.4.10
```

1. What did nikto report about the server version / headers?
2. Did nikto flag anything about missing security headers? If so, name
   one.
3. `nikto` and `gobuster`/`dirb` both probe a web server, but for
   different things. In one sentence, what's the difference in what each
   is designed to find?

:::::::::::::::::::::::: solution

1. The exact banner text depends on the Nginx version bundled in the
   `nginx:alpine` image, but expect nikto to report the `Server` response
   header (e.g. `nginx/1.2x.x`), which discloses the exact web server
   software and version running.
2. Yes — Nginx doesn't set several security headers by default, so expect
   nikto to flag at least one of: missing `X-Frame-Options` (clickjacking
   protection), missing `X-Content-Type-Options` (MIME-sniffing
   protection), or missing `Content-Security-Policy`.
3. `gobuster`/`dirb`/`ffuf` are built to discover *paths that exist but
   aren't linked* by brute-forcing candidate names against a wordlist;
   `nikto` is built to check a *known* target against a database of
   known-risky files, outdated software banners, and common
   misconfigurations — it doesn't brute-force generic names, it checks for
   specific known issues.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Quick Knowledge Check

::::::::::::::::::::::::::::::::::::: challenge

### Check your understanding

1. What does `robots.txt` actually control?
   A) Which paths require login  B) Which paths search-engine crawlers
   should skip  C) Server-side access control  D) SSL certificate
   validation
2. In `ffuf -u http://target/FUZZ`, what does `FUZZ` represent?
   A) A literal folder name  B) The substitution point where each wordlist
   entry gets inserted  C) A HTTP header  D) An IP range
3. What kind of file will directory brute-forcing with a generic wordlist
   *never* find on its own?
   A) Common folder names like `/admin/`  B) A file with an unpredictable
   or context-specific name mentioned nowhere else  C) The homepage
   D) `robots.txt`
4. What is nikto primarily designed to check for?
   A) Only directory names  B) Server misconfigurations, outdated software
   banners, missing security headers, and known-risky files  C) Only SQL
   injection  D) DNS records
5. Why check `robots.txt` before running a full directory brute-force?
   A) It's required by law  B) It's an instant, free hint at paths the
   site owner considers sensitive  C) It speeds up gobuster automatically
   D) It isn't useful

:::::::::::::::::::::::: solution

1. B) Which paths search-engine crawlers should skip
2. B) The substitution point where each wordlist entry gets inserted
3. B) A file with an unpredictable or context-specific name mentioned
   nowhere else
4. B) Server misconfigurations, outdated software banners, missing
   security headers, and known-risky files
5. B) It's an instant, free hint at paths the site owner considers
   sensitive

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Optional: CTF challenge

Once you've completed the exercises above, try the optional flag-capture
challenge: two flags are hidden on `lab4-web` (10.10.4.10) — one found via
directory brute-forcing, and a second found by following up on a clue the
first flag's page gave you. Target `10.10.4.10` only, attack from
`lab4-attacker`, flag format `flag{...}`. No hints below — ask your
instructor if you get stuck.

:::::::::::::::::::::::: instructor

The full CTF walkthrough for this lab (including both flag values and the
exact steps) is provided separately to instructors rather than inline here,
so it stays out of a learner's browser history/search results. See the
[instructor notes](../instructors/lab4-notes.html).

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Cleanup

```bash
exit
cd episodes/files/lab4-web-enumeration
docker compose down
```

:::::::::::::::::::::::::::::::::::::: keypoints

- `robots.txt` is a free hint, not an access-control mechanism — paths it
  disallows are worth checking manually, not skipping
- `gobuster`, `dirb`, and `ffuf` all brute-force paths against a wordlist —
  they can only find what's already in that wordlist
- `ffuf` marks the substitution point explicitly with `FUZZ` and reports
  per-request size/word/line counts, which is how you tell a real hit from
  Nginx's default 404 response
- Automated brute-forcing and manual follow-up on a discovered clue (like
  a filename mentioned in an HTML comment) are both required — neither
  replaces the other
- `nikto` checks a known target for misconfigurations, outdated banners,
  and missing security headers — a different job from discovering unknown
  paths

::::::::::::::::::::::::::::::::::::::::::::::::
