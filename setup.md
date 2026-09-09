---
title: Setup
---

> **⚠️ Statutory Warning:** This lesson is for learning ethical hacking in
> isolated, self-contained lab environments only. Do not point any tool
> covered here at a system you don't own or lack explicit written
> authorization to test. See the [lesson home page](../index.html) for the
> full statement.

## Software Setup

::::::::::::::::::::::::::::::::::::::: discussion

### Details

Every lab in this lesson is a Docker Compose stack — a Kali Linux "attacker"
container plus purpose-built vulnerable target containers — running on its
own private, isolated Docker network. Nothing in these labs touches a real
system or the public internet.

:::::::::::::::::::::::::::::::::::::::::::::::::::

| Tool | Min Version | Install |
|------|-------------|---------|
| Docker Desktop (macOS / Windows) or Docker Engine (Linux) | 24.x | <https://docs.docker.com/get-docker/> |
| Docker Compose | v2.x | Bundled with Docker Desktop |
| Git | Any | <https://git-scm.com/> |

**Recommended:** 8 GB RAM, 20 GB free disk space.

:::::::::::::::: spoiler

### Windows

Run all commands in **Git Bash** or **WSL2**.

::::::::::::::::::::::::

:::::::::::::::: spoiler

### MacOS

Docker Desktop + Terminal.app — no extra setup needed.

::::::::::::::::::::::::

:::::::::::::::: spoiler

### Linux

Install `docker` and the `docker-compose-plugin` from your distro's package
manager, or follow Docker's official install docs.

::::::::::::::::::::::::

## Build the shared attacker image

All labs share one base image (`ethical-base`), built once from
[`episodes/files/base.Dockerfile`](files/base.Dockerfile) — Kali Linux
Rolling with `nmap`, `hydra`, `medusa`, `john`, `hashcat`,
`wireshark`/`tshark`/`tcpdump`, `gobuster`, `dirb`, `ffuf`, `nikto`,
`sqlmap`, `enum4linux`, `smbclient`, and other standard pentest tooling
pre-installed.

```bash
git clone https://github.com/moktan456/hacking-labs-workbench.git
cd hacking-labs-workbench
docker build -t ethical-base -f episodes/files/base.Dockerfile .
```

## Start a lab

Each episode names its own lab directory under `episodes/files/`. General
pattern:

```bash
cd episodes/files/<lab-directory>
docker compose up -d
docker exec -it <attacker-container-name> bash
# ... work through the episode ...
docker compose down
```

The exact attacker container name, target IPs, and any extra steps (e.g.
Lab 1's Wireshark GUI at `http://localhost:14501`) are given at the top of
each episode.

| Episode | Lab directory |
|---|---|
| Packet Capture & Traffic Analysis | `lab1-packet-capture` |
| OSINT & Active Host Discovery | `lab2-osint-recon` |
| Nmap Port & Service Scanning | `lab3-nmap-scanning` |
| Web Enumeration | `lab4-web-enumeration` |
| Directory Service & DB Enumeration | `lab5-service-enumeration` |
| Password Attacks | `lab6-password-attacks` |
| Web Application Exploitation | `lab7-web-exploitation` |
| Exploit Development (Buffer Overflow) | `lab8-buffer-overflow` |
| Lateral Movement & Pivoting | `lab9-pivoting` |
| Persistence & Backdoors | `lab10-persistence` |
| Log Manipulation & Anti-Forensics | `lab11-log-anti-forensics` |
| Full-Chain Capstone CTF | `lab12-full-chain-ctf` |

Only one lab's containers need to run at a time — run `docker compose down`
in a lab's directory before starting the next one to avoid Docker network/IP
conflicts between labs.

## Data Sets

No external data download is required — each lab's target data (flags,
credentials, sample services) is generated inside its own containers on
startup.
