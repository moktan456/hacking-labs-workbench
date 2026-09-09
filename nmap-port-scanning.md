---
title: "Nmap Port & Service Scanning"
teaching: 20
exercises: 75
---

:::::::::::::::::::::::::::::::::::::: questions

- How do you discover live hosts and open ports on a subnet with nmap?
- How do you identify the exact service and version listening on a port?
- How does a SYN scan differ from a full connect scan, and why does that matter?
- How do NSE scripts automate checks like anonymous FTP access or SSH enumeration?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Run host discovery and full-subnet port scans with nmap
- Detect service versions with `-sV` and combine detection modes with `-A`
- Compare SYN scans (`-sS`) to full connect scans (`-sT`) and explain the difference in what each leaves on the target
- Use NSE scripts to automate checks such as `ftp-anon` and SSH enumeration
- Save and document scan output in multiple formats for later reference

::::::::::::::::::::::::::::::::::::::::::::::::

## Introduction

Nmap is the workhorse of active scanning: discovering hosts, finding open
ports, fingerprinting exactly what's listening on them, and running
scripted checks against known services. This lab walks through the full
range — ping sweeps, connect/SYN scans, version detection, aggressive
scans, and NSE scripts — against three realistic targets.

::::::::::::::::::::::::::::::::::::: callout

### Scope note

Every command below targets only the containers started by this lab's own
`docker-compose.yaml` (subnet `10.10.3.0/24`). Don't point these tools
anywhere else. See the [statutory warning on the lesson home page](../index.html)
and [Setup](../learners/setup.html) before you begin.

::::::::::::::::::::::::::::::::::::::::::::::::

**Tools used:** `nmap`
**Network:** `lab3-attacker` (10.10.3.2, Kali) · `lab3-web` (10.10.3.10, HTTP/Nginx) · `lab3-ftp` (10.10.3.11, FTP/vsftpd, anonymous access enabled) · `lab3-ssh` (10.10.3.12, SSH/OpenSSH, password auth enabled)

Follow [Setup](../learners/setup.html) to build the shared attacker image,
then:

```bash
cd episodes/files/lab3-nmap-scanning
docker compose up -d
```

before continuing.

## Part 1: Basic Port Scanning

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 1.1: Default TCP scan

```bash
nmap 10.10.3.10
```

Record the open ports found. Then answer: what does it mean when nmap
reports a port as "filtered" rather than "closed"?

:::::::::::::::::::::::: solution

`lab3-web` runs Nginx, so nmap will report port `80/tcp` as `open`.

"Filtered" means nmap couldn't determine whether the port is open or
closed — a firewall, ACL, or other packet filter is dropping or blocking
the probe, so nmap can't tell either way. "Closed" means a probe reached
the host and got an explicit response (e.g. a `RST`) saying nothing is
listening there.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 1.2: Scan the full lab subnet

```bash
nmap 10.10.3.0/24
```

How many hosts are up, and what open ports does each report?

:::::::::::::::::::::::: solution

Three target hosts should show as up (plus the attacker itself, if it's
included in the range you scan from):

| Host IP | Open Ports |
|---------|------------|
| 10.10.3.10 | 80 (HTTP) |
| 10.10.3.11 | 21 (FTP) |
| 10.10.3.12 | 22 (SSH) |

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 1.3: Ping sweep (host discovery only)

```bash
nmap -sn 10.10.3.0/24
```

Why run `-sn` before a full port scan on a large, unfamiliar network?

:::::::::::::::::::::::: solution

`-sn` skips port scanning entirely and only checks which hosts respond
(host discovery). On a large or unfamiliar subnet this is much faster than
port-scanning every possible address, and it lets you narrow a full scan
down to only the hosts that are actually live — saving time and reducing
the amount of noisy traffic you generate against addresses with nothing
listening.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 2: Service Version Detection

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 2.1: Version scan

```bash
nmap -sV 10.10.3.10
nmap -sV 10.10.3.11
nmap -sV 10.10.3.12
```

Fill in the service version table, then answer: why is knowing the exact
version of a service valuable during recon/scanning, before you've
attempted anything against it?

:::::::::::::::::::::::: solution

| Target IP | Port | Service | Version |
|-----------|------|---------|---------|
| 10.10.3.10 | 80 | http | nginx (Alpine build) |
| 10.10.3.11 | 21 | ftp | vsftpd (banner: "CyberCorp FTP Server v3.0.5") |
| 10.10.3.12 | 22 | ssh | OpenSSH (on Ubuntu 22.04) |

Knowing the exact version lets you check it against known CVEs and public
exploit databases before you touch the service further — it turns a
generic "there's an SSH server here" into "there's *this specific,
possibly vulnerable* SSH server here," which drives what you try next and
avoids wasting time on exploits that don't apply to this version.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 2.2: Aggressive scan

```bash
nmap -A 10.10.3.0/24
```

What additional information did `-A` reveal compared to `-sV` alone? Did
nmap detect an OS for any target?

:::::::::::::::::::::::: solution

`-A` combines version detection with OS detection, NSE default script
scanning, and traceroute — so beyond service/version info, you also get
NSE script output (e.g. FTP banner details, SSH host keys) and an OS
guess/fingerprint for each host, in a single command instead of running
`-sV`, `-O`, `-sC`, and `--traceroute` separately.

OS detection results depend on how distinguishable each container's
network stack looks to nmap's fingerprinting database — in a container
environment nmap will typically guess "Linux" (matching the underlying
Ubuntu/Alpine images) with varying confidence, rather than a precise
kernel version.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 3: Scan Techniques and Detection Signatures

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 3.1: SYN scan vs. full connect scan

```bash
nmap -sS 10.10.3.0/24
nmap -sT 10.10.3.0/24
```

How does a SYN scan (`-sS`) differ mechanically from a full connect scan
(`-sT`)? Which leaves a more complete connection log entry on the target,
and why?

:::::::::::::::::::::::: solution

A SYN scan (`-sS`) sends only a `SYN` packet and reads the response
(`SYN,ACK` = open, `RST` = closed) without ever completing the TCP
three-way handshake — it's often called a "half-open" scan. A full
connect scan (`-sT`) uses the OS's normal `connect()` call, completing the
full three-way handshake for every port it probes.

`-sT` leaves a more complete log entry on the target, because a fully
established connection is what gets logged by applications and system
connection-tracking — the half-open connections from `-sS` frequently
never reach the point where an application-level log line gets written.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 3.2: NSE script scans

```bash
nmap -sC -sV 10.10.3.11
nmap --script ftp-anon 10.10.3.11
```

Does the FTP server allow anonymous login? What's the practical risk of a
service allowing anonymous read access?

:::::::::::::::::::::::: solution

Yes — `lab3-ftp` is configured with `anonymous_enable=YES`, so
`ftp-anon` will report anonymous FTP login is allowed and list the
contents of the anonymous root.

The practical risk is unauthenticated information disclosure: anyone on
the network can read whatever files are reachable from the anonymous
root, with no credentials and no audit trail tying access to an identity.
If sensitive files are ever placed there (intentionally or by mistake),
they're exposed to anyone who can reach the service.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 3.3: SSH enumeration scripts

```bash
nmap --script ssh-hostkey 10.10.3.12
nmap --script ssh-auth-methods --script-args="ssh.user=sysadmin" 10.10.3.12
```

What authentication methods does the SSH server advertise?

:::::::::::::::::::::::: solution

`lab3-ssh` has `PasswordAuthentication yes` set in `sshd_config`, so
`ssh-auth-methods` should report `password` as an available authentication
method for the `sysadmin` account (alongside any other methods OpenSSH
advertises by default, such as `publickey`). `ssh-hostkey` separately
prints the server's host key fingerprint(s), useful for confirming you're
talking to the same host on a later connection.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 4: Output and Documentation

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 4.1: Save scan results in all formats

```bash
nmap -sV -oA /tmp/lab3-scan 10.10.3.0/24
ls /tmp/lab3-scan*
cat /tmp/lab3-scan.nmap
```

What's the `.xml` output format useful for, that the plain-text `.nmap`
format isn't?

:::::::::::::::::::::::: solution

`-oA` writes the same scan results in three formats at once: `.nmap`
(normal human-readable text), `.gnmap` (grepable, line-oriented), and
`.xml`. The `.xml` format is structured and machine-parseable — tools like
report generators, vulnerability scanners, and scripts (including nmap's
own `xsltproc`-based HTML conversion) can reliably read specific fields
out of it, whereas the plain-text `.nmap` format is meant for a human to
read and isn't reliable to parse programmatically.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 4.2: Write a recon summary

Using everything gathered in Parts 1–3, write a recon summary table for
`10.10.3.0/24` (IP, hostname, OS if detected, open ports, key services),
list your notable findings, and note what you'd scan or enumerate next.

:::::::::::::::::::::::: solution

A correct summary pulls together the results from the earlier exercises,
for example:

| IP | Hostname | OS (if detected) | Open Ports | Key Services |
|----|----------|-------------------|-------------|----------------|
| 10.10.3.10 | web-server | Linux (guessed) | 80 | HTTP (Nginx) |
| 10.10.3.11 | ftp-server | Linux (guessed) | 21 | FTP (vsftpd, anonymous access enabled) |
| 10.10.3.12 | ssh-server | Linux (guessed) | 22 | SSH (OpenSSH, password auth enabled) |

Notable findings should call out the two real weaknesses this lab
demonstrates: anonymous FTP access on `lab3-ftp`, and password-based SSH
authentication (rather than key-only) on `lab3-ssh`. A reasonable "what's
next" answer is to enumerate the anonymous FTP share further (exactly what
the optional CTF challenge below asks you to do), and to consider
password-guessing/brute-force risk against the SSH service given
password auth is enabled.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Quick Knowledge Check

::::::::::::::::::::::::::::::::::::: challenge

### Check your understanding

1. What flag enables service version detection?
   A) `-sV`  B) `-sS`  C) `-A`  D) `-p`
2. What does `-sn` do?
   A) Scan all ports  B) Ping sweep only (host discovery, no ports)
   C) Enable NSE scripts  D) OS fingerprinting
3. Which nmap output format is best for feeding into other tools?
   A) `.nmap` (normal)  B) `.xml`  C) `.gnmap`  D) Plain text
4. What does "filtered" mean in nmap's output?
   A) Port is open  B) Port is closed
   C) A firewall/ACL may be blocking the probe, so nmap can't tell
   D) Port doesn't exist
5. What does the `-A` flag combine?
   A) Just version detection
   B) Version detection + OS detection + script scanning + traceroute
   C) Only OS detection  D) Only NSE scripts

:::::::::::::::::::::::: solution

1. A) `-sV`
2. B) Ping sweep only (host discovery, no ports)
3. B) `.xml`
4. C) A firewall/ACL may be blocking the probe, so nmap can't tell
5. B) Version detection + OS detection + script scanning + traceroute

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Optional: CTF challenge

Once you've completed the exercises above, try the optional flag-capture
challenge: two flags are hidden on `lab3-ftp` (10.10.3.11), both findable
through scanning and enumeration alone — no credentials required —
`user.txt` and `root.txt`. Target `10.10.3.0/24` only, attack from
`lab3-attacker`, flag format `flag{...}`. No hints below — ask your
instructor if you get stuck.

:::::::::::::::::::::::: instructor

The full CTF walkthrough for this lab (including both flag values and the
exact steps) is provided separately to instructors rather than inline
here, so it stays out of a learner's browser history/search results. See
the [instructor notes](../instructors/lab3-notes.html).

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Cleanup

```bash
cd episodes/files/lab3-nmap-scanning
docker compose down
```

:::::::::::::::::::::::::::::::::::::: keypoints

- `nmap -sn <subnet>` does host discovery only, without scanning ports —
  useful to narrow down a large or unfamiliar network first
- `nmap -sV` fingerprints the exact service and version listening on each
  open port, which drives what you try against it next
- `-sS` (SYN scan) never completes the TCP handshake, so it leaves a much
  weaker connection log trail on the target than `-sT` (full connect scan)
- `-A` bundles version detection, OS detection, default NSE scripts, and
  traceroute into one scan
- NSE scripts (`--script <name>`) automate specific checks, like
  `ftp-anon` for anonymous FTP access or `ssh-auth-methods` for advertised
  SSH authentication methods
- `-oA <basename>` saves scan results in `.nmap`, `.gnmap`, and `.xml`
  simultaneously — `.xml` is the format to parse programmatically

::::::::::::::::::::::::::::::::::::::::::::::::
