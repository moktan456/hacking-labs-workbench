---
title: "OSINT & Active Host Discovery"
teaching: 15
exercises: 65
---

:::::::::::::::::::::::::::::::::::::: questions

- What's the difference between passive and active reconnaissance?
- How do you use WHOIS and DNS lookups to gather public information about a domain?
- What can a misconfigured DNS zone transfer reveal about an internal network?
- How do you grab and interpret service banners to guide further attack planning?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Run WHOIS and DNS lookups (`dig`) against a real, safe, documentation-reserved domain
- Distinguish passive reconnaissance from active reconnaissance
- Enumerate a network with `nmap -sL` (list scan) and `nmap -sn` (ping sweep)
- Exploit a misconfigured DNS zone transfer (`AXFR`) to enumerate hidden hosts
- Grab service banners with `curl` and `nc`, and explain why exact version numbers matter

::::::::::::::::::::::::::::::::::::::::::::::::

## Introduction

Reconnaissance splits into two flavors: **passive** (gathering public
information without touching the target — WHOIS, DNS records, public web
pages) and **active** (lightly touching the target's network — ping sweeps,
banner grabs). This lab covers both. You'll query real public registry data
for a safe, reserved-for-documentation domain, then pivot to a simulated
internal network to enumerate a misconfigured DNS server and grab service
banners.

::::::::::::::::::::::::::::::::::::: callout

### Scope note

Every command below targets only the containers started by this lab's own
`docker-compose.yaml` (subnet `10.10.2.0/24`). Don't point these tools
anywhere else. See the [statutory warning on the lesson home page](../index.html)
and [Setup](../learners/setup.html) before you begin.

::::::::::::::::::::::::::::::::::::::::::::::::

**Tools used:** `whois`, `dig`, `nslookup`, `curl`, `nc`, `nmap` (`-sL`, `-sn`)
**Network:** `lab2-attacker` (10.10.2.2, Kali attacker) · `lab2-dns` (10.10.2.5, internal DNS server for `cybercorp.lab`, zone transfer misconfigured) · `lab2-web` (10.10.2.10, internal web portal, page source leaks a path) · `lab2-legacy` (10.10.2.11, legacy FTP + SSH gateway, revealing service banners)

Follow [Setup](../learners/setup.html) to build the shared attacker image,
then start this lab's Docker Compose stack before continuing:

```bash
cd episodes/files/lab2-osint-recon
docker compose up -d
docker exec -it lab2-attacker bash
```

## Part 1: Passive OSINT Against a Real Domain

`example.com` is IANA-reserved specifically so people can safely practice
exactly this kind of lookup, from anywhere, any time.

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 1: WHOIS lookup

```bash
whois example.com
```

Who is the registrant organization listed, and what name servers are listed?

:::::::::::::::::::::::: solution

`example.com` is one of the domains IANA reserves for documentation and
testing, so its WHOIS record lists **IANA (Internet Assigned Numbers
Authority)** as the registrant organization, and its name servers are the
`iana-servers.net` pair (e.g. `a.iana-servers.net` / `b.iana-servers.net`).
This is exactly why it's safe to query from any environment — no real
organization's private registration data is exposed.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 2: DNS records

Query a known public resolver explicitly with `@1.1.1.1` rather than
trusting whatever default resolver your environment has configured — a
local/default resolver can be slow, filtered, or (on a real engagement, if
you're on the target's network) intercepted.

```bash
dig @1.1.1.1 example.com A
dig @1.1.1.1 example.com MX
dig @1.1.1.1 example.com NS
```

1. What's the A record's IP address?
2. Why would an attacker care about MX records specifically, during recon on
   a real target?

:::::::::::::::::::::::: solution

1. The `ANSWER SECTION` of the `A` query output shows a single IPv4 address
   for `example.com` — the exact address can change over time as IANA
   re-points the record, so read it from your own `dig` output rather than
   memorizing one.
2. MX records point to the mail servers a domain actually uses. During recon
   they reveal what mail infrastructure (and often what hosting provider or
   security vendor, e.g. a spam-filtering gateway) sits in front of an
   organization — valuable for planning phishing infrastructure or for
   identifying a completely different attack surface (the mail provider)
   from the domain's web hosting.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 2: Local Host Discovery

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 3: List scan (no packets sent)

```bash
nmap -sL 10.10.2.0/24
```

`-sL` doesn't touch the targets at all — it just does reverse-DNS lookups.
Why might you run this before anything else on an unfamiliar network?

:::::::::::::::::::::::: solution

Because it produces a list of hostnames/IPs with zero packets sent to the
targets themselves — nothing to trigger an IDS/IPS alert or show up in a
target's logs. It's a free first pass at what's in scope before you commit
to any traffic that actually touches a host.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 4: Ping sweep

```bash
nmap -sn 10.10.2.0/24
```

Which hosts responded: `10.10.2.5`, `10.10.2.10`, `10.10.2.11`?

:::::::::::::::::::::::: solution

All three respond — `lab2-dns` (10.10.2.5), `lab2-web` (10.10.2.10), and
`lab2-legacy` (10.10.2.11) are all running containers on the lab network, so
each answers the ICMP/ARP probes `-sn` sends.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 3: DNS Zone Enumeration

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 5: Query known records

```bash
dig @10.10.2.5 www.cybercorp.lab
dig @10.10.2.5 mail.cybercorp.lab
```

What IPs did you get back?

:::::::::::::::::::::::: solution

`www.cybercorp.lab` resolves to `10.10.2.10` (the web portal) and
`mail.cybercorp.lab` resolves to `10.10.2.11` (the legacy gateway) — both
are the internal DNS server's authoritative `A` records for those names.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 6: Attempt a zone transfer

A DNS zone transfer (`AXFR`) is meant only for secondary name servers to
sync from the primary — but a misconfigured server will hand the *entire*
zone to anyone who asks.

```bash
dig @10.10.2.5 cybercorp.lab AXFR
```

1. Did the transfer succeed?
2. List every hostname the zone transfer revealed, including any you hadn't
   seen yet. Did you find a TXT record?
3. You found a hostname (`admin-portal.cybercorp.lab`) that was never
   advertised anywhere public. What does that tell you about the value of a
   misconfigured AXFR?

:::::::::::::::::::::::: solution

1. Yes — `lab2-dns` is configured with `allow-transfer { any; };`, so it
   hands the full zone to any client that asks, with no restriction to
   known secondary servers.
2. The full zone reveals `ns.cybercorp.lab` (10.10.2.5), `www.cybercorp.lab`
   (10.10.2.10), `mail.cybercorp.lab` (10.10.2.11), and two hostnames not
   visible from the earlier targeted lookups: `vpn.cybercorp.lab`
   (10.10.2.13) and `admin-portal.cybercorp.lab` (10.10.2.14). There's also
   a TXT record on `_flag.cybercorp.lab` — its value is `flag{...}`-formatted,
   which is this lab's optional CTF flag (see below).
3. It shows that a misconfigured AXFR can silently leak an organization's
   entire internal naming scheme — including hosts (like an admin portal or
   a VPN gateway) that were never linked from a public web page or
   registered anywhere a normal passive scan would find them. One
   misconfigured name server can undo all the effort an org put into
   keeping sensitive hostnames unlisted.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 4: Banner Grabbing

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 7: HTTP banner via curl

```bash
curl -I http://10.10.2.10
```

What does the `Server:` header reveal?

:::::::::::::::::::::::: solution

`lab2-web` runs on the `nginx:alpine` image, so the `Server:` header
identifies it as `nginx` (and typically the version, e.g. `nginx/1.x.x`).
Knowing the exact web server software (and version) narrows down what
known vulnerabilities or default misconfigurations to check next.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 8: Read the page source

```bash
curl -s http://10.10.2.10 | grep -i "TODO\|backup\|<!--"
```

Did the HTML contain a comment referencing something interesting? Follow up
on what it says:

```bash
curl -s http://10.10.2.10/backup.txt
```

What did you find?

:::::::::::::::::::::::: solution

The page source contains an HTML comment left in by mistake — a `TODO`
noting that a config backup was exposed at `/backup.txt` and should have
been removed before the production push. Fetching that path returns a
config-backup file containing internal notes (including a reference to
`admin-portal.cybercorp.lab`) and a `flag{...}`-formatted string — this
lab's second optional CTF flag (see below). It's a textbook example of
recon paying off from a developer's leftover comment rather than any
exploit.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 9: Raw banner grab with nc

```bash
nc -nv 10.10.2.11 21
# Ctrl+C once you've read the banner

nc -nv 10.10.2.11 22
# Ctrl+C once you've read the banner
```

1. What does the FTP banner say? What does the SSH banner say?
2. The FTP banner claims to be `vsftpd 2.3.4`. Why would an attacker
   specifically care about the *exact version number* of a service, rather
   than just knowing "it's FTP"?

:::::::::::::::::::::::: solution

1. The FTP banner reads `CyberCorp FTP Server (vsftpd 2.3.4) ready.` The SSH
   connection shows the raw SSH protocol identification string first,
   followed by the custom pre-login banner configured on the box:
   `CyberCorp Legacy SSH Gateway - OpenSSH 8.2 - Authorised access only`.
2. An exact version string lets an attacker look up known CVEs and public
   exploits for that specific build, instead of just knowing the protocol
   in general. `vsftpd 2.3.4` is a well-known teaching example: a
   backdoored build of that exact version once circulated publicly, so
   seeing that precise banner is an immediate red flag for anyone doing
   recon — a generic "it's running FTP" gives none of that signal.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Quick Knowledge Check

::::::::::::::::::::::::::::::::::::: challenge

### Check your understanding

1. Which of these is passive reconnaissance? A) Port scanning B) WHOIS
   lookup C) Banner grabbing D) Ping sweep
2. What does `nmap -sL` do differently from `nmap -sn`?
3. What is a DNS zone transfer (AXFR) meant to be used for?
4. Why is an exact software version (like "vsftpd 2.3.4") valuable during
   recon?
5. What HTTP client flag returns only the response headers, not the body?

:::::::::::::::::::::::: solution

1. B) WHOIS lookup
2. `-sL` sends no packets to the targets at all — it just does reverse-DNS
   lookups; `-sn` actively pings hosts to see which ones are alive.
3. Syncing zone data between a primary name server and its secondary/slave
   name servers.
4. It lets you look up known vulnerabilities for that specific version.
5. `-I`

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Optional: CTF challenge

Once you've completed the exercises above, try the optional flag-capture
challenge: two flags, hidden using OSINT/recon techniques only — no
exploitation involved. One is hidden in a DNS record on `10.10.2.5`; the
other is hidden behind a clue on the web server at `10.10.2.10`. Target
`10.10.2.0/24` only, attack from `lab2-attacker`, flag format `flag{...}`.
No hints below — ask your instructor if you get stuck.

:::::::::::::::::::::::: instructor

The full CTF walkthrough for this lab (including both flag values and the
exact steps) is provided separately to instructors rather than inline here,
so it stays out of a learner's browser history/search results. See the
[instructor notes for this lab](lab2-notes.html).

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Cleanup

```bash
exit
cd episodes/files/lab2-osint-recon
docker compose down
```

:::::::::::::::::::::::::::::::::::::: keypoints

- Passive recon (WHOIS, DNS lookups) gathers public information without
  touching the target; active recon (ping sweeps, banner grabs) lightly
  touches it and is detectable
- `nmap -sL` resolves hostnames without sending any packets to the targets;
  `nmap -sn` performs a ping sweep to find which hosts are alive
- A misconfigured DNS zone transfer (`AXFR`) can hand an entire zone to any
  client that asks, exposing hostnames that were never advertised anywhere
  public
- Service banners — an HTTP `Server:` header, or a raw FTP/SSH banner via
  `nc` — reveal exact software versions that attackers use to look up known
  vulnerabilities
- Recon wins often come from misconfigurations and leftover files
  (comments, backup files) rather than sophisticated exploitation

::::::::::::::::::::::::::::::::::::::::::::::::
