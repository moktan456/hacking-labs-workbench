---
title: "Lab 4 Notes: Web Enumeration"
---

## CTF walkthrough (spoiler)

The episode's optional CTF challenge asks learners to find two flags on
`lab4-web` (10.10.4.10) with no hints. Answers:

### Step 1: Find the hidden admin path

```bash
gobuster dir -u http://10.10.4.10 -w /usr/share/dirb/wordlists/common.txt
```

or check `robots.txt` first — it lists `/admin/` and `/backup/` directly:

```bash
curl http://10.10.4.10/robots.txt
```

### Flag 1 (found via brute-forcing / robots.txt)

```bash
curl -s http://10.10.4.10/admin/
```

The page source contains:

```
flag{lab4_robots_txt_led_to_admin}
```

...and a second HTML comment: "nightly db export lands in `/backup/` as
`db_export_2024.sql`".

### Flag 2 (found by following up on the clue)

```bash
curl -s http://10.10.4.10/backup/db_export_2024.sql
```

```
flag{lab4_direct_filename_guess}
```

### Lesson

The wordlist scan gets learners to `/admin/` and `/backup/` — but the
actual sensitive file (`db_export_2024.sql`) was never in any wordlist.
They only find it by *reading* what the first discovery told them and
following up manually. Automated enumeration and manual follow-up are both
required; neither replaces the other.

## Common sticking points

- `web-content/backup/index.html` is a static page whose text literally
  reads "403 Forbidden" — but Nginx still serves it with a real HTTP `200`
  status, since it's a genuine file on disk, not an actual access-control
  response. Learners who only glance at the rendered page (rather than
  checking the actual status code with `curl -I` or their brute-force
  tool's status column) can walk away thinking `/backup/` is properly
  locked down, when it isn't — that's the point of the exercise, but it's
  worth calling out explicitly if a learner seems confused about why a
  "403 page" counted as a discovered, accessible path.
- The db export filename (`db_export_2024.sql`) must be copied exactly as
  it appears in the admin page's HTML comment — learners sometimes guess
  at a filename instead of reading the comment carefully, and get a `404`.
- `nikto`'s exact banner/header output depends on the specific
  `nginx:alpine` image version pulled at build time, so don't expect
  identical output across different learners' environments or reruns —
  the important result is that it reports *a* server version banner and
  *at least one* missing security header, not a specific string.
