---
title: Instructor Notes
---

## Overview

This lesson ports the full 12-lab, 5-phase curriculum from the companion
[Hacking-Labs-Training](https://github.com/moktan456/Hacking-Labs-Training)
repository into The Carpentries Workbench format:

| # | Episode | Phase |
|---|---|---|
| 1 | Packet Capture & Traffic Analysis | 1 — Reconnaissance |
| 2 | OSINT & Active Host Discovery | 1 — Reconnaissance |
| 3 | Nmap Port & Service Scanning | 2 — Scanning & Enumeration |
| 4 | Web Enumeration | 2 — Scanning & Enumeration |
| 5 | Directory Service & DB Enumeration | 2 — Scanning & Enumeration |
| 6 | Password Attacks | 3 — Gaining Access |
| 7 | Web Application Exploitation | 3 — Gaining Access |
| 8 | Exploit Development (Buffer Overflow) | 3 — Gaining Access |
| 9 | Lateral Movement & Pivoting | 4 — Maintaining Access |
| 10 | Persistence & Backdoors | 4 — Maintaining Access |
| 11 | Log Manipulation & Anti-Forensics | 5 — Covering Tracks |
| 12 | Full-Chain Capstone CTF | Capstone |

Each episode after the first has its own instructor notes page (`lab2-notes.md`
through `lab12-notes.md`) with that lab's CTF walkthrough and sticking points.
This page covers the lesson as a whole plus **Lab 1** specifically.

Only one lab's Docker Compose stack should run at a time — each uses its own
subnet, but running several simultaneously wastes resources and complicates
debugging. Have learners `docker compose down` before moving to the next
episode (see [Setup](../learners/setup.html)).

## Timing

Each lab runs roughly 60–100 minutes end to end (teaching + exercises); see
each episode's front matter for its specific `teaching`/`exercises` split.
The full 12-lab curriculum is designed as a multi-week course (it mirrors the
companion repo's 8 weeks of presentation slides plus 4 additional labs) — it
is not intended to be run in a single session.

## Lab 1: Packet Capture & Traffic Analysis

### CTF walkthrough (spoiler — instructors only)

The episode's optional CTF challenge asks learners to find `user.txt` and
`root.txt` on `lab1-telnet` (10.10.1.10) with no hints. Answers:

- **user.txt**: `flag{lab1_telnet_sniffed_credentials}` — obtained by
  capturing the Telnet login (`netadmin` / `cleartext123`) with `tcpdump`,
  then either reading it live in the session or via Follow TCP Stream in
  Wireshark, and `cat user.txt` after logging in.
- **root.txt**: `flag{lab1_wireshark_stream_master}` — this lab's target
  container runs services under a permissive configuration for teaching
  purposes, so `root.txt` is world-readable (`chmod 644`) once you're
  logged into the box; no privilege escalation exploit is required for this
  particular lab (that skill is introduced in later phases).

### Common sticking points

- Learners sometimes try `tcpdump` on the **target** container instead of
  the attacker — reinforce the callout in the episode about why a Docker
  bridge network requires capturing from one of the two endpoints.
- The Wireshark GUI container can take 10–15 seconds to become reachable at
  `http://localhost:14501` after `docker compose up -d` — don't let learners
  assume it's broken if the first load fails.
- `fg` after backgrounding `tcpdump` with `&` confuses learners unfamiliar
  with shell job control; a quick live demo of `jobs`, `fg`, `Ctrl+C` helps.
