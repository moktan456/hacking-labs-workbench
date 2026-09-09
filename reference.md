---
title: 'Reference'
---

## Glossary

pcap
: Packet capture file format (`.pcap`/`.pcapng`) storing raw network
  packets, readable by both `tcpdump`/`tshark` and Wireshark.

tcpdump
: Command-line packet capture tool; writes live traffic to a `.pcap` file
  or prints it to the terminal.

tshark
: Command-line companion to Wireshark; reads `.pcap` files and applies the
  same display-filter syntax as the Wireshark GUI.

Follow TCP Stream
: A Wireshark feature that reassembles all packets in one TCP conversation,
  in order, into a single readable block of application data.

SYN scan
: An `nmap -sS` port scan that sends a TCP SYN to each target port without
  completing the handshake; a `SYN, ACK` reply means the port is open, a
  `RST, ACK` means it's closed.

CTF (Capture The Flag)
: A hands-on exercise format where the goal is to find hidden strings
  ("flags"), usually formatted like `flag{...}`, by exploiting a
  deliberately vulnerable target.
