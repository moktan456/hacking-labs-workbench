---
title: "Packet Capture & Traffic Analysis"
teaching: 20
exercises: 55
---

:::::::::::::::::::::::::::::::::::::: questions

- How do you capture live network traffic and save it to a `.pcap` file?
- How do you read a captured cleartext protocol exchange back in Wireshark?
- What does port-scan traffic look like on the wire?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Capture live traffic with `tcpdump` and write it to a `.pcap` file
- Open and filter a `.pcap` in Wireshark's GUI
- Use Follow TCP Stream to reconstruct a plaintext Telnet session
- Extract fields from a capture with `tshark` on the command line
- Recognize SYN-scan traffic patterns in a packet capture

::::::::::::::::::::::::::::::::::::::::::::::::

## Introduction

Before you can attack anything, you need to be able to see what's happening
on the wire. This lab teaches you to capture live traffic, save it to a
`.pcap` file, and analyze it in Wireshark — reading a cleartext protocol
exchange to recover credentials, and recognizing what a port scan looks like
on the network.

::::::::::::::::::::::::::::::::::::: callout

### Scope note

Every command below targets only the containers started by this lab's own
`docker-compose.yaml` (subnet `10.10.1.0/24`). Don't point these tools
anywhere else. See the [statutory warning on the lesson home page](../index.html)
and [Setup](../learners/setup.html) before you begin.

::::::::::::::::::::::::::::::::::::::::::::::::

**Tools used:** `tcpdump`, `tshark`, Wireshark
**Network:** `lab1-attacker` (10.10.1.2, Kali) · `lab1-telnet` (10.10.1.10, Telnet target) · `lab1-wireshark` (10.10.1.5, browser GUI at `http://localhost:14501`)

Follow [Setup](../learners/setup.html) to build the shared attacker image and
start this lab's Docker Compose stack before continuing.

## Part 1: Capturing Live Traffic with tcpdump

::::::::::::::::::::::::::::::::::::: callout

### Why capture on the attacker container?

A Docker bridge network only lets a container see traffic to and from
itself — it can't passively observe two *other* containers talking. So this
exercise captures around the attacker's own connection to the target, the
same way you'd capture from a network tap or an in-path device on a real
engagement.

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 1: Start a background capture

```bash
# -i eth0 = capture on the attacker's network interface
# -w      = write raw packets to a file instead of printing them
tcpdump -i eth0 -w /captures/telnet-session.pcap host 10.10.1.10 &
```

What does the `host 10.10.1.10` filter do to what tcpdump records?

:::::::::::::::::::::::: solution

It restricts the capture to only packets where `10.10.1.10` is either the
source or destination address — traffic to or from any other host on the
network is not written to the file.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 2: Generate traffic to capture

While the capture runs in the background, connect to the target and log in:

```bash
telnet 10.10.1.10
# login: netadmin
# password: cleartext123
cat user.txt
exit
```

Did you retrieve a flag?

:::::::::::::::::::::::: solution

Yes — `user.txt` contains a `flag{...}`-formatted string, confirming the
Telnet login succeeded and the shell is readable.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 3: Stop the capture

```bash
# Bring the background job to the foreground and stop it
fg
# press Ctrl+C

ls -la /captures/
```

How large is `telnet-session.pcap`?

:::::::::::::::::::::::: solution

Size varies by session length, but expect a small file (well under 10 KB)
since it's a short cleartext exchange — file size is roughly proportional to
packet count and payload size, not wall-clock time.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 2: Visual Analysis in Wireshark

Open the Wireshark GUI tab (`http://localhost:14501`) and use
**File → Open** to browse to `/captures/telnet-session.pcap`.

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 4: Filter to the Telnet conversation

In the display filter bar, type:

```
telnet
```

How many packets matched the filter?

:::::::::::::::::::::::: solution

Every packet on TCP port 23 for that session — count depends on how many
keystrokes were sent, since Telnet transmits one packet per keystroke by
default.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 5: Follow the TCP Stream

Right-click any Telnet packet → **Follow → TCP Stream**.

1. What username and password can you read in the stream?
2. Why does Follow Stream make this so much easier to read than
   scrolling packet-by-packet, given Telnet sends every keystroke as a
   separate packet?
3. What would you have seen instead if this had been an SSH session?

:::::::::::::::::::::::: solution

1. Username `netadmin`, password `cleartext123`.
2. Follow Stream reassembles every packet in the TCP conversation, in order,
   into one continuous readable block of application data — instead of
   manually reading dozens of single-keystroke packets and mentally
   reassembling them.
3. With SSH, the payload is encrypted — Follow Stream would show unreadable
   binary/ciphertext instead of plaintext credentials.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 3: Command-Line Analysis with tshark

Wireshark's GUI and `tshark` read the same capture files — `tshark` is what
you use when there's no GUI available (a remote server, a script, a CI
pipeline).

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 6: List packets from the command line

```bash
tshark -r /captures/telnet-session.pcap -Y telnet
```

What does `-Y` do, compared to `-r` alone?

:::::::::::::::::::::::: solution

`-r` just reads the capture file. `-Y` applies a **display filter** on top —
the same filter syntax as the Wireshark GUI filter bar — so only packets
matching `telnet` are printed, even though the whole file was read.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 7: Extract specific fields

```bash
tshark -r /captures/telnet-session.pcap -T fields -e ip.src -e ip.dst -e tcp.srcport -e tcp.dstport
```

Record one row of output: source IP, destination IP, source port,
destination port.

:::::::::::::::::::::::: solution

A row will show one endpoint as `10.10.1.2` (attacker) and the other as
`10.10.1.10` (target), with destination port `23` on packets flowing to the
target and an ephemeral high source port on the attacker's side.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 4: Recognizing Scan Traffic in a Capture

Reconnaissance isn't just about reading credentials — you also need to
recognize what an active scan looks like on the wire, since you'll be
running (and later, defending against) exactly this traffic.

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 8: Capture and analyze a port scan

```bash
tcpdump -i eth0 -w /captures/scan.pcap host 10.10.1.10 &
nmap -sS 10.10.1.10
fg
# Ctrl+C to stop the capture

tshark -r /captures/scan.pcap -Y "tcp.flags.syn==1 && tcp.flags.ack==0" | wc -l
```

1. How many SYN-only packets were sent?
2. In the capture, which ports got a `SYN, ACK` back, and which got a
   `RST, ACK`? What does each response mean?
3. Open `scan.pcap` in Wireshark and check **Statistics → Conversations**.
   How would a very large number of SYN packets to sequential ports, all
   from one source IP, in a few seconds, look to someone monitoring this
   traffic?

:::::::::::::::::::::::: solution

1. One SYN packet per port scanned (a default `nmap -sS` scans the top 1000
   TCP ports).
2. `SYN, ACK` means the port is **open** and accepted the connection
   attempt. `RST, ACK` means the port is **closed** — nothing is listening,
   so the OS immediately resets the half-open connection.
3. It looks like a **port scan** — a strong, easily-fingerprinted signal
   that a network intrusion detection system (NIDS) or SOC analyst would
   flag: one source, many destination ports, all within seconds, mostly
   half-open (SYN-only) connections.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Quick Knowledge Check

::::::::::::::::::::::::::::::::::::: challenge

### Check your understanding

1. What flag tells tcpdump to write captured packets to a file instead of
   printing them? `-r` / `-w` / `-Y` / `-i`
2. Which Wireshark feature reconstructs an entire TCP conversation into
   readable text?
3. What TCP flag combination indicates an open port in response to a SYN
   scan?
4. Why is Telnet traffic trivial to read in a packet capture, while SSH
   traffic isn't?
5. What does the tshark flag `-Y` apply — a capture filter or a display
   filter?

:::::::::::::::::::::::: solution

1. `-w`
2. Follow TCP Stream
3. `SYN, ACK`
4. Telnet is unencrypted (SSH encrypts its payload)
5. A display filter (limits what's shown from an already-captured file, not
   what gets captured)

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Optional: CTF challenge

Once you've completed the exercises above, try the optional flag-capture
challenge: two flags are hidden on `lab1-telnet` (10.10.1.10) —
`user.txt` (earned by intercepting valid credentials and logging in) and
`root.txt` (earned by getting a root-level view of the box). Target
`10.10.1.10` only, attack from `lab1-attacker`, flag format `flag{...}`. No
hints below — ask your instructor if you get stuck.

:::::::::::::::::::::::: instructor

The full CTF walkthrough for this lab (including both flag values and the
exact steps) is provided separately to instructors rather than inline here,
so it stays out of a learner's browser history/search results. See the
[instructor notes](instructor-notes.html).

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Cleanup

```bash
exit
cd episodes/files/lab1-packet-capture
docker compose down
```

:::::::::::::::::::::::::::::::::::::: keypoints

- `tcpdump -i <iface> -w <file>` captures live traffic to a `.pcap` file
- Wireshark's **Follow → TCP Stream** reconstructs a full conversation into
  readable text — trivial for cleartext protocols like Telnet, useless for
  encrypted ones like SSH
- `tshark -r <file> -Y <filter>` applies a display filter to an existing
  capture; `-T fields -e <field>` extracts specific values
- A SYN scan shows as one-sided `SYN` packets from a single source to many
  destination ports in a short window — `SYN, ACK` means open, `RST, ACK`
  means closed

::::::::::::::::::::::::::::::::::::::::::::::::
