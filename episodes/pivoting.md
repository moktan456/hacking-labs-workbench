---
title: "Lateral Movement & Pivoting"
teaching: 15
exercises: 65
---

:::::::::::::::::::::::::::::::::::::: questions

- How do you use a host you've already compromised as a relay to reach a network your own machine can't route to directly?
- What's the difference between an SSH dynamic SOCKS proxy (`-D`) and direct local port forwarding (`-L`)?
- Why does scanning through a SOCKS proxy require a different nmap technique than a direct scan?
- How does Metasploit's `autoroute` achieve pivoting without a manual SSH tunnel?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Confirm network segmentation from an attacker's perspective
- Establish a foothold via SSH on a dual-homed pivot host
- Build a dynamic SOCKS proxy and route tools through it with `proxychains4`
- Set up direct local port forwarding for a single service
- Understand how Metasploit's `autoroute` achieves the same goal without manual tunnels

::::::::::::::::::::::::::::::::::::::::::::::::

## Introduction

Real networks are segmented — the host you land on first is rarely the one
holding what you actually want. This lab teaches pivoting: using a
compromised host as a relay to reach an internal network your attacker
machine can't touch directly.

::::::::::::::::::::::::::::::::::::: callout

### Scope note

Every command below targets only the containers started by this lab's own
`docker-compose.yaml` (subnets `10.10.9.0/24` and `10.10.90.0/24`). Don't
point these tools anywhere else. See the [statutory warning on the lesson
home page](../index.html) and [Setup](../learners/setup.html) before you
begin.

::::::::::::::::::::::::::::::::::::::::::::::::

**Tools used:** `ssh` (`-D`/`-L`), `proxychains4`, `nmap`, `msfconsole`, `mysql` client

**Network map:**

- `lab9-attacker` (10.10.9.2) — Metasploit-equipped attacker, **external
  network only**
- `lab9-pivot` (10.10.9.10 external + 10.10.90.10 internal) — dual-homed
  "the hop"; your only path from the external network into the internal one
- `lab9-internal-web` (10.10.90.20) — nginx, **internal-only**, reachable
  only via the pivot
- `lab9-internal-db` (10.10.90.21) — MariaDB, **internal-only**, reachable
  only via the pivot

The internal network (`10.10.90.0/24`) is a Docker `internal: true` network
— it genuinely has no route out except through `lab9-pivot`, which is
bridged into both networks. This isn't simulated; it's actually unreachable
any other way.

Follow [Setup](../learners/setup.html), then:

```bash
cd episodes/files/lab9-pivoting
docker compose up -d
docker exec -it lab9-attacker bash
```

## Part 0: Confirm the Segmentation

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 0.1: Confirm the internal network is actually unreachable

```bash
ping -c 2 10.10.9.10     # the pivot host - should respond
ping -c 2 10.10.90.20    # an internal target - should NOT respond
```

Why can't you reach `10.10.90.20` directly, even though you know its IP
address?

:::::::::::::::::::::::: solution

`lab9-attacker` only has an interface on the external network
(`10.10.9.0/24`). `10.10.90.0/24` is a Docker `internal: true` network with
no gateway to the outside world at all — the only container bridged into
both networks is `lab9-pivot`. Knowing an IP address is irrelevant if there
is no routed path to it; the packets have nowhere to go.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 1: Establish the Foothold

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 1.1: SSH into the pivot host

```bash
ssh pivotuser@10.10.9.10
# password: pivot123
cat user.txt
exit
```

What flag did you retrieve?

:::::::::::::::::::::::: solution

`flag{lab9_pivot_host_accessed}`

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 2: Pivot with a Dynamic SOCKS Proxy

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 2.1: Open a SOCKS tunnel through the pivot

`-D` turns your SSH connection into a SOCKS proxy — anything you point
through it gets relayed via the pivot host's network view, which *does*
include the internal subnet.

```bash
ssh -f -N -D 1080 pivotuser@10.10.9.10
# runs in the background (-f), no remote command (-N), SOCKS proxy on local port 1080
```

Is there now a process listening on `127.0.0.1:1080`? Run
`ss -tlnp | grep 1080` to confirm.

:::::::::::::::::::::::: solution

Yes — after the command completes, `ss -tlnp | grep 1080` shows the `ssh`
process bound and listening on `127.0.0.1:1080`. That's the local end of the
SOCKS proxy; anything sent to it is relayed out through the pivot's own
network view.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 2.2: Route traffic through the proxy

`proxychains4` forces any command's network traffic through your SOCKS
proxy. Check its config first:

```bash
cat /etc/proxychains/proxychains.conf | tail -5
```

What proxy type and port does it list at the bottom?

Now reach the internal web server *through* the tunnel:

```bash
proxychains4 curl -s http://10.10.90.20
```

Did you get the internal page back this time, and what flag did it contain?

:::::::::::::::::::::::: solution

The config's last line reads `socks5  127.0.0.1  1080` — matching the local
end of the tunnel you opened in Exercise 2.1.

Yes, the page loads this time (it failed with a direct `curl` before the
tunnel existed, since `10.10.90.20` isn't routable from the attacker).
The page contains `flag{lab9_internal_web_via_pivot}`.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 2.3: Scan the internal subnet through the proxy

```bash
proxychains4 nmap -sT -Pn -p 80,3306 10.10.90.20 10.10.90.21
```

Why did this exercise use `nmap -sT` (full TCP connect) instead of `-sS`
(SYN scan)? What does routing through a SOCKS proxy via proxychains require
of the scan technique?

:::::::::::::::::::::::: solution

A SYN scan (`-sS`) needs raw socket access to craft and read individual
TCP flag packets directly — proxychains can't intercept that at the socket
level. A full-connect scan (`-sT`) only ever makes ordinary
`connect()` calls, which proxychains *can* transparently redirect through
the SOCKS proxy. Any tool being pivoted through a SOCKS proxy is limited to
techniques built on regular TCP connections.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 3: Direct Port Forwarding

Dynamic proxying (`-D`) is flexible but requires every tool to support
SOCKS (via proxychains). For a single specific service, local port
forwarding (`-L`) is simpler — it maps one local port straight to one
destination through the tunnel, and ordinary tools connect to `localhost`
with no special configuration.

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 3.1: Forward MySQL through the pivot

```bash
ssh -f -N -L 3307:10.10.90.21:3306 pivotuser@10.10.9.10
```

Confirm the forward is listening with `ss -tlnp | grep 3307`.

:::::::::::::::::::::::: solution

`ss -tlnp | grep 3307` should show `ssh` listening on `127.0.0.1:3307`.

If a connection attempt fails immediately with something like
`Can't connect to server on '127.0.0.1'`, the `-f` flag occasionally
backgrounds the process a moment before the forward is fully established.
If nothing is listening yet, just re-run the `ssh -L` command (or drop `-f`
and background it yourself with `&`) and try again.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 3.2: Connect as if the database were local

```bash
mysql -h 127.0.0.1 -P 3307 -u appuser -papppass456 --skip-ssl -e "SHOW DATABASES;"
```

Did it work? From the perspective of the `mysql` client, is there any
difference between this and connecting to a real local database? What does
that tell you about how invisible a well-placed pivot can be?

:::::::::::::::::::::::: solution

Yes — `SHOW DATABASES;` returns results, including `internaldb`, even
though `10.10.90.21` is on a network the attacker container can't route to
at all.

From the `mysql` client's point of view, there is **no difference
whatsoever** — it just opens a TCP socket to `127.0.0.1:3307` and speaks
the MySQL protocol. It has no way of knowing the other end of that socket
is actually forwarded, by SSH, through a completely different host, onto a
network that would otherwise be unreachable. That transparency is exactly
what makes a compromised jump host so dangerous: any tool you already trust
can be pointed at "localhost" and end up talking to something deep inside
a segmented network.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 4: Metasploit's Built-In Pivoting

Metasploit can pivot without a manual SSH tunnel at all, once it has a
session on the pivot host — useful when you have a Meterpreter session but
not SSH credentials.

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 4.1: Explore autoroute (conceptual — no live Meterpreter session in this lab)

```bash
msfconsole -q -x "show post" 2>&1 | grep -i autoroute
```

In a real engagement, once you have a Meterpreter session on `lab9-pivot`,
the module `post/multi/manage/autoroute` adds a route through that session
so every other Metasploit module can reach the internal subnet
automatically. Compare this to the manual SSH tunnel you just built — what's
the tradeoff (setup effort vs. what you get) between the two approaches?

:::::::::::::::::::::::: solution

A manual SSH tunnel (`-D`/`-L`) only needs valid SSH credentials on the
pivot — no exploitation required — and works with any external tool via
proxychains or a forwarded port. But you have to decide up front exactly
what you need (one proxy, or one forwarded port) and keep the tunnel
running yourself.

`post/multi/manage/autoroute` needs an active Meterpreter session on the
pivot (i.e., you already popped it some other way), but once run, **every**
Metasploit module — scanners, exploits, post modules — can reach the
internal subnet automatically, with no per-tool configuration at all. The
tradeoff is initial-access method (SSH credentials vs. an existing
Meterpreter session) against convenience and scope (manual, tool-by-tool
setup vs. automatic routing for the whole framework).

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Quick Knowledge Check

::::::::::::::::::::::::::::::::::::: challenge

### Check your understanding

1. What does `ssh -D 1080 user@host` create?
   - A) A direct port forward  B) A dynamic SOCKS proxy through the SSH connection  C) A reverse shell  D) A file transfer channel

2. What does `proxychains4` do to a command you prefix it with?
   - A) Runs it faster  B) Forces its network connections through the configured proxy chain  C) Encrypts its output  D) Nothing without root

3. What's the key difference between `-D` (dynamic) and `-L` (local) SSH forwarding?
   - A) No difference  B) `-D` is a general-purpose SOCKS proxy for any destination; `-L` maps one fixed local port to one fixed remote destination  C) `-L` requires root, `-D` doesn't  D) `-D` only works with HTTP

4. Why does scanning through a SOCKS proxy typically require `-sT` instead of `-sS`?
   - A) SYN scans need raw socket access that a SOCKS-proxied connection can't provide — proxied traffic goes through regular TCP connect calls  B) There's no real difference  C) `-sT` is always faster  D) SOCKS doesn't support TCP

5. Why is a Docker `internal: true` network a good stand-in for a segmented internal corporate network?
   - A) It isn't a good comparison  B) It genuinely has no route to the outside except through a host that's bridged into both networks — the same shape as a real segmented network with one gateway/jump host  C) It's slower  D) It only allows UDP

:::::::::::::::::::::::: solution

1. B) A dynamic SOCKS proxy through the SSH connection
2. B) Forces its network connections through the configured proxy chain
3. B) `-D` is a general-purpose SOCKS proxy for any destination; `-L` maps one fixed local port to one fixed remote destination
4. A) SYN scans need raw socket access that a SOCKS-proxied connection can't provide — proxied traffic goes through regular TCP connect calls
5. B) It genuinely has no route to the outside except through a host that's bridged into both networks — the same shape as a real segmented network with one gateway/jump host

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Optional: CTF challenge

Once you've completed the exercises above, try the optional flag-capture
challenge. Three flags, only reachable by pivoting through `lab9-pivot`
(10.10.9.10):

1. `user.txt` on the pivot host itself
2. A flag on the internal web server (10.10.90.20) — unreachable without a tunnel
3. A flag in the internal database (10.10.90.21) — unreachable without a tunnel

Rules: you can only initiate connections from `lab9-attacker`; the internal
network (`10.10.90.0/24`) has no route to it except through the pivot; flag
format `flag{...}`. No hints below — ask your instructor if you get stuck.

:::::::::::::::::::::::: instructor

The full CTF walkthrough for this lab (including all three flag values and
the exact steps) is provided separately to instructors rather than inline
here, so it stays out of a learner's browser history/search results. See
the [instructor notes](../instructors/lab9-notes.html).

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Cleanup

```bash
# Kill any background ssh tunnels first
pkill -f "ssh -f -N" 2>/dev/null
exit
cd episodes/files/lab9-pivoting
docker compose down
```

:::::::::::::::::::::::::::::::::::::: keypoints

- A Docker `internal: true` network is a faithful stand-in for real network
  segmentation — no route out except through a host bridged into both
  networks
- `ssh -f -N -D <port>` turns an SSH connection into a general-purpose SOCKS
  proxy; `proxychains4 <command>` forces that command's traffic through it
- `ssh -f -N -L <local-port>:<dest-host>:<dest-port>` maps one local port
  straight to one remote destination — simpler than a SOCKS proxy when only
  one service matters, and needs no proxy-aware tooling
- Scanning through a SOCKS proxy requires `nmap -sT` (full TCP connect)
  because proxied traffic only supports regular `connect()` calls, not the
  raw-socket half-open handshake `-sS` needs
- A well-placed pivot is completely transparent to client tools — a
  `mysql` client pointed at `127.0.0.1` has no way to know it's actually
  talking to a host on an otherwise-unreachable internal network
- Metasploit's `post/multi/manage/autoroute` achieves the same result as a
  manual tunnel automatically, once you already have a session on the pivot

::::::::::::::::::::::::::::::::::::::::::::::::
