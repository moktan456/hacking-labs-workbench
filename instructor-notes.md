---
title: Instructor Notes
---

## Overview

This is a **pilot episode** porting Lab 1 (Packet Capture & Traffic
Analysis, Phase 1 — Reconnaissance) from the companion
[Hacking-Labs-Training](https://github.com/moktan456/Hacking-Labs-Training)
repository — a 12-lab, 5-phase ethical hacking curriculum — into The
Carpentries Workbench format. If this pilot works well for your cohort, the
remaining 11 labs (scanning/enumeration, gaining access, maintaining access,
covering tracks, and the capstone CTF) can be ported the same way.

## Timing

Full episode: ~75 minutes (20 min teaching + 55 min exercises), matching the
original worksheet's four parts plus the knowledge check.

## CTF walkthrough (spoiler — instructors only)

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

Full detail lives in `ctf-walkthrough.md` in the source repository,
`labs/phase1-reconnaissance/lab1-packet-capture/`.

## Common sticking points

- Learners sometimes try `tcpdump` on the **target** container instead of
  the attacker — reinforce the callout in the episode about why a Docker
  bridge network requires capturing from one of the two endpoints.
- The Wireshark GUI container can take 10–15 seconds to become reachable at
  `http://localhost:14501` after `docker compose up -d` — don't let learners
  assume it's broken if the first load fails.
- `fg` after backgrounding `tcpdump` with `&` confuses learners unfamiliar
  with shell job control; a quick live demo of `jobs`, `fg`, `Ctrl+C` helps.
