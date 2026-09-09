---
title: "Lab 2 Notes: OSINT & Active Host Discovery"
---

## CTF walkthrough (spoiler)

The episode's optional CTF challenge asks learners to find two flags on the
`10.10.2.0/24` network with no hints, using OSINT/recon techniques only (no
exploitation involved). Answers:

- **Flag 1 — DNS TXT record via zone transfer**, hidden on `lab2-dns`
  (10.10.2.5):

  ```bash
  dig @10.10.2.5 cybercorp.lab AXFR
  ```

  Look for the `_flag.cybercorp.lab. TXT` line in the output:

  ```
  flag{lab2_axfr_zone_leak}
  ```

- **Flag 2 — page-source clue on the web server**, hidden on `lab2-web`
  (10.10.2.10):

  ```bash
  curl -s http://10.10.2.10 | grep -i backup
  ```

  This reveals an HTML comment pointing at `/backup.txt`:

  ```bash
  curl -s http://10.10.2.10/backup.txt
  ```

  ```
  flag{lab2_html_comment_led_to_backup}
  ```

**Lesson for learners:** neither flag required exploiting anything — one
came from a DNS server handing over its whole zone to any client that
asked, the other from a developer leaving a comment (and a file) in
production that was never meant to ship. Recon wins are often just "someone
left the door unlocked," not clever exploitation.

Note that both flags are also reachable through the *required* worksheet
exercises (Exercise 6's zone transfer, and Exercise 8's page-source/backup
lookup) — the episode's solutions for those exercises deliberately confirm
the `flag{...}` format without printing the literal value, so learners who
want the full CTF experience still have to go find it themselves.

## Common sticking points

- Part 1 depends on outbound internet access from `lab2-attacker` to query
  the real `example.com` domain — if the training environment's network
  blocks outbound DNS/WHOIS, that part will hang or fail even though the
  rest of the lab (fully local) works fine.
- Learners are told to query `@1.1.1.1` explicitly rather than the
  container's default resolver — some Docker/corporate networks filter or
  cache DNS unexpectedly, and querying a known public resolver directly
  sidesteps that (and is good recon practice besides).
- `lab2-dns`, `lab2-web`, and `lab2-legacy` all run `apt-get install` at
  container start (see `docker-compose.yaml`), so they can take a little
  while to become fully ready after `docker compose up -d` — don't let
  learners assume `dig`/`curl`/`nc` failures mean something is broken if
  they try immediately.
