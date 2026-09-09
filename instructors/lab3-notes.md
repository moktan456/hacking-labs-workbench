---
title: "Lab 3 Notes: Nmap Port & Service Scanning"
---

## CTF walkthrough (spoiler)

The episode's optional CTF challenge asks learners to find `user.txt` and
`root.txt` on `lab3-ftp` (10.10.3.11), both findable through scanning and
enumeration alone, no credentials required.

### Step 1: Confirm anonymous FTP

```bash
nmap --script ftp-anon 10.10.3.11
```

Confirms anonymous login is allowed.

### Step 2: user.txt

```bash
ftp 10.10.3.11
# Name: anonymous
# Password: (blank/anonymous)
cd pub
get user.txt
quit
cat user.txt
```

Flag: `flag{lab3_anon_ftp_reader}`

### Step 3: root.txt (hidden directory)

A plain `ls` inside `pub/` won't show dotfiles/dot-directories. List
everything:

```bash
ftp 10.10.3.11
# Name: anonymous
cd pub
ls -a
cd .backup
get root.txt
quit
cat root.txt
```

Or do it in one shot with nmap's script, which lists hidden entries too:

```bash
nmap -p21 --script ftp-anon 10.10.3.11
```

Flag: `flag{lab3_hidden_dir_enumeration}`

**Lesson:** a default directory listing hides dotfiles — thorough
enumeration means explicitly checking for hidden files and directories,
not stopping at the first listing you see.

## Common sticking points

- `lab3-ftp` and `lab3-ssh` install their packages (`vsftpd`,
  `openssh-server`) at container start via `apt-get` in the compose
  command, so both containers take a few seconds after `docker compose up
  -d` before the service is actually listening — an immediate `nmap` run
  right after startup may show the port as closed/filtered. If a scan
  looks wrong, wait a few seconds and rerun it (or check `docker compose
  logs lab3-ftp` / `lab3-ssh`).
- Exercise 3.3's `ssh-auth-methods` script needs
  `--script-args="ssh.user=sysadmin"` to report per-user results — if
  learners omit the username argument they'll get a less useful generic
  result, so double-check they copied the full command.
- The aggressive scan (`-A`) in Exercise 2.2 runs noticeably slower than
  the earlier scans (it layers version detection, OS detection, default
  scripts, and traceroute together) — let learners read ahead in the
  worksheet while it completes rather than assuming it's hung.
