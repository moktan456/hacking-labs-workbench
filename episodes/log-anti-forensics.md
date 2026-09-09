---
title: "Log Manipulation & Anti-Forensics"
teaching: 20
exercises: 80
---

:::::::::::::::::::::::::::::::::::::: questions

- How do attackers erase or falsify bash history, auth logs, and login
  records after gaining access?
- What is "timestomping," and how does `touch -r` make a dropped file blend
  in with files already on the system?
- Why doesn't deleting a file with `rm` actually erase its data, and how does
  `shred` address that?
- What defensive countermeasures make each of these anti-forensics
  techniques harder to pull off against a well-defended target?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Generate realistic evidence of attacker activity: a failed login, a
  successful login, command history, and a dropped file
- Control what does and doesn't get written to bash history, and clear
  history that's already on disk
- Selectively edit a text log (`auth.log`) to remove specific evidence
  without leaving an obviously-truncated file behind
- Clear binary login records (`wtmp`) read by the `last` command
- Timestomp a file's modification time with `touch -r` to blend it in with
  legitimate files
- Securely delete a file with `shred` instead of `rm`
- Verify cleanup work programmatically with an included checker script

::::::::::::::::::::::::::::::::::::::::::::::::

## Introduction

The fifth phase of the attack lifecycle isn't about getting in or staying
in — it's about not leaving a trail once you were there. This lab has you
generate realistic evidence of your own activity (login records, command
history, a dropped file) and then remove or falsify each piece, verified by
an included checker script. Every technique here has a direct defensive
mirror: log integrity monitoring, file integrity checking, and centralized
logging are all built specifically to catch what you're about to do.
Knowing the attack side — what log tampering and timestomping actually look
like from the inside — is what makes the defensive side make sense; a blue
team analyst who has never seen `sed -i '/pattern/d'` used against a log
file won't know what subtle tampering looks like when they're staring at
one.

::::::::::::::::::::::::::::::::::::: callout

### Scope note

Every command below targets only the containers started by this lab's own
`docker-compose.yaml` (subnet `10.10.11.0/24`). Don't point these tools
anywhere else. See the [statutory warning on the lesson home page](../index.html)
and [Setup](../learners/setup.html) before you begin.

::::::::::::::::::::::::::::::::::::::::::::::::

**Tools used:** bash history controls, log editing (`sed`, log truncation),
`touch` timestomping, `shred`
**Network:** `lab11-attacker` (10.10.11.2, Kali attacker) · `lab11-target`
(10.10.11.10, SSH target — root access given, rsyslog running)

Follow [Setup](../learners/setup.html) to build the shared attacker image,
then

```bash
cd episodes/files/lab11-log-anti-forensics
docker compose up -d
```

before continuing.

## Setup: Generate Some Noise First

You need real evidence on disk before you can practice erasing it.

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 0.1: Generate activity to clean up later

```bash
docker exec -it lab11-attacker bash

# One failed attempt (wrong password on purpose)
sshpass -p wrongpass ssh -o StrictHostKeyChecking=no root@10.10.11.10 whoami 2>&1 || true

# Now the real login
ssh root@10.10.11.10
# password: toor123
cat user.txt
whoami
ls -la
exit
```

Why does that final `exit` matter for the rest of this lab?

:::::::::::::::::::::::: solution

Bash only writes its in-memory command history out to `~/.bash_history`
when a session ends normally. Exiting cleanly here is what makes Part 1
meaningful — it's what actually leaves history on disk for you to later
find and clear. (`cat user.txt` also confirms the SSH login succeeded and
you have a readable shell — root access is handed to you for this lab, so
the challenge isn't getting in.)

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 1: Bash History

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 1.1: See what's already there

```bash
ssh root@10.10.11.10
cat ~/.bash_history
```

Did you see the commands from your previous session?

:::::::::::::::::::::::: solution

Yes. Because the previous session ended with a normal `exit`, bash flushed
its in-memory history buffer to `~/.bash_history` on disk before closing —
that's why this new session's `cat` can read them back.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 1.2: Prevent new commands from being logged

```bash
unset HISTFILE
```

`unset HISTFILE` only helps going forward. Why doesn't it erase what's
already on disk from before you ran it?

:::::::::::::::::::::::: solution

`unset HISTFILE` only changes where *this running shell* writes history
from this point on — it tells bash to stop targeting a file for future
writes. It has no effect on the file's existing contents, which were
already flushed to disk by the previous session's normal exit, long before
this command ran.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 1.3: Clear what's already there

```bash
history -c
> ~/.bash_history
cat ~/.bash_history
```

Is the file empty now? `history -c` clears your *in-memory* history for
this session — why was the separate `> ~/.bash_history` (truncating the
file directly) also necessary?

:::::::::::::::::::::::: solution

Yes, the file is empty afterward. `history -c` and truncating the file
target two entirely separate copies of your history: the shell's in-memory
list for the current session, and the on-disk file written by past
sessions. Clearing only the in-memory copy leaves the old on-disk file
completely untouched — you have to truncate the file directly to remove
what earlier sessions already wrote there.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 2: Auth Log Cleanup

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 2.1: Find your own entries

```bash
grep "10.10.11.2" /var/log/auth.log
```

How many lines reference your attacker IP? What do the failed vs.
successful attempts look like differently in the log?

:::::::::::::::::::::::: solution

The exact count varies with how many connections you made, but expect
several lines: SSH logs at least one line per connection attempt (a
`Failed password` line for the wrong-password attempt in Exercise 0.1),
plus additional lines for a successful login — an `Accepted password` line
and separate `session opened`/`pam_unix` lines. Failed attempts show
`Failed password for root from 10.10.11.2`; successful attempts show
`Accepted password for root from 10.10.11.2` followed by a `session opened
for user root` line.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 2.2: Remove just those lines

```bash
sed -i '/10.10.11.2/d' /var/log/auth.log
grep "10.10.11.2" /var/log/auth.log
```

Is the grep now empty? This used `sed -i` to selectively delete matching
lines rather than truncating the whole file (`> /var/log/auth.log`). Why is
selective deletion less suspicious to a defender than an empty log file?

:::::::::::::::::::::::: solution

Yes, the grep returns nothing afterward. Selectively deleting only the
matching lines leaves the rest of the log — every other user's and every
other IP's activity — completely intact and normal-looking in both size and
content. A log file that's suddenly empty or truncated to zero bytes is
itself a glaring anomaly: any admin, monitoring tool, or file-integrity
check would immediately notice a log that should be growing continuously
suddenly reset to nothing, whereas a log that's merely missing a few lines
looks unremarkable at a glance.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 3: Login Records — wtmp

`auth.log` isn't the only record of a login — `wtmp` is a separate binary
log that the `last` command reads.

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 3.1: View login records

```bash
last -f /var/log/wtmp
```

Do you see your SSH sessions listed?

:::::::::::::::::::::::: solution

Yes — `last -f /var/log/wtmp` shows your earlier SSH logins as entries,
independent of anything in `auth.log`.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 3.2: Clear it

```bash
> /var/log/wtmp
last -f /var/log/wtmp
```

`auth.log` and `wtmp` both recorded the same login events, in two
completely different formats (text log vs. binary record). Why does
covering your tracks properly require handling both, not just one?

:::::::::::::::::::::::: solution

`auth.log` and `wtmp` are two independently maintained records of the same
underlying events, read by completely different tools — text log viewers
and `grep` for one, the `last` command for the other. Clearing only one
leaves the other as a fully intact, separately-discoverable trail: a
forensic examiner (or an automated checker, like this lab's `verify.sh`)
that checks `wtmp` would still find your login sessions even if `auth.log`
is spotless, and vice versa. Full cleanup means covering every independent
record of the same activity, not just the first one you think to check.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 4: Timestomping

A freshly modified file stands out. Matching its timestamp to something
already on the system blends it in.

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 4.1: Compare timestamps

```bash
stat /root/dropped_tool.sh
stat /root/legit_reference.txt
```

How do the `Modify` timestamps differ?

:::::::::::::::::::::::: solution

`legit_reference.txt` was deliberately set to an old date (2023-01-15) when
the target container was built, so it has a long-standing, "always been
there" modification time. `dropped_tool.sh` was created when the container
started up, so its `Modify` timestamp is recent — freshly created files
like this stand out immediately to anyone reviewing file timestamps for
signs of recent tampering.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 4.2: Match them

```bash
touch -r /root/legit_reference.txt /root/dropped_tool.sh
stat /root/dropped_tool.sh
```

Do the `Modify` timestamps match now? `touch -r` copies a reference file's
timestamp. What's the risk of picking a *badly chosen* reference file
(e.g. one that was itself created five minutes ago)?

:::::::::::::::::::::::: solution

Yes, both files now show the same `Modify` timestamp. If the reference file
you pick is itself recent — say, something created five minutes ago — then
`touch -r` just makes your dropped file match another suspicious, recently
created file instead of blending in with anything genuinely old. A
forensic analyst reviewing timestamps would then find *two* files that
look freshly planted instead of one, which is worse, not better. A good
reference file needs a timestamp that's independently credible for its
location — something that plausibly belongs to the system, not something
that raises the same question you were trying to avoid.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 5: Secure Deletion

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 5.1: Create and delete a file normally

```bash
echo "sensitive staging notes" > /root/scratch.txt
rm /root/scratch.txt
```

`rm` removes the filename from the directory listing, but does it
necessarily erase the file's actual data from disk? What could a forensic
recovery tool potentially still find?

:::::::::::::::::::::::: solution

No — `rm` only unlinks the filename from its directory entry and marks the
underlying disk blocks as free for reuse. The actual bytes of
`"sensitive staging notes"` remain physically present on disk until
something else happens to overwrite those same blocks, which could be
seconds or never. A forensic recovery tool that scans raw disk blocks for
unlinked-but-not-yet-overwritten data (e.g. `photorec`, `scalpel`,
`testdisk`) could potentially recover the full file content even though it
no longer appears in any directory listing.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 5.2: Delete it securely instead

```bash
echo "sensitive staging notes" > /root/scratch2.txt
shred -u /root/scratch2.txt
ls /root/scratch2.txt 2>&1
```

What does `shred` actually do differently from `rm` before removing the
file?

:::::::::::::::::::::::: solution

`shred` overwrites the file's actual data on disk — by default, multiple
passes of patterned/random data — *before* unlinking it. `rm` skips that
step entirely and just removes the directory entry, leaving the original
bytes intact wherever they were stored. Because `shred -u` destroys the
underlying data first, the same disk-recovery approach that could rescue a
plain `rm`'d file finds only overwritten noise instead of the original
content.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 6: Verify Your Work

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 6.1: Run the checker script

```bash
bash /root/verify.sh
```

Did every check pass? If something failed, which part of the lab does it
point you back to?

:::::::::::::::::::::::: solution

If Parts 1–4 were all completed correctly, all four checks should print
`[PASS]`: `auth.log` no longer references your attacker IP, `wtmp` has no
remaining login records, `/root/.bash_history` is empty, and
`dropped_tool.sh`'s timestamp matches `legit_reference.txt`. Each `[FAIL]`
line names exactly which record is still dirty — for example, a wtmp
failure means Part 3 wasn't finished, and a timestamp failure means Part 4
wasn't finished — so re-run the corresponding part and then re-run
`verify.sh` until every line reads `[PASS]`.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Quick Knowledge Check

::::::::::::::::::::::::::::::::::::: challenge

### Check your understanding

1. Why does `unset HISTFILE` alone not clean up a session that already
   happened?
   - A) It does clean up past sessions too
   - B) It only prevents *future* commands in the current session from
     being written to disk — history already on disk is unaffected
   - C) It deletes all logs
   - D) It requires root

2. Why edit `auth.log` with `sed -i '/pattern/d'` instead of truncating the
   whole file?
   - A) No real reason
   - B) Selectively removing only the relevant lines leaves the rest of the
     log looking normal, while an empty/truncated log file is itself an
     obvious red flag
   - C) sed is faster
   - D) Truncating doesn't work on log files

3. What does `wtmp` track that `auth.log` doesn't fully overlap with?
   - A) Nothing, they're identical
   - B) `wtmp` is a separate binary login/logout record read by tools like
     `last`, independent of the text-based syslog
   - C) wtmp only tracks failed logins
   - D) wtmp is encrypted

4. What is "timestomping"?
   - A) Deleting a file
   - B) Altering a file's timestamps (e.g. with `touch -r`) to make it
     blend in with legitimate, older files
   - C) Compressing a file
   - D) A type of log rotation

5. What does `shred` do before deleting a file that `rm` does not?
   - A) Nothing different
   - B) Overwrites the file's data on disk (multiple passes by default)
     before unlinking it, making recovery much harder
   - C) Encrypts the file
   - D) Backs up the file first

:::::::::::::::::::::::: solution

1. B
2. B
3. B
4. B
5. B

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Optional: CTF challenge

Two starting flags are given immediately — root access is granted for this
lab, so the challenge isn't getting in. The real objective:

- Generate real evidence of your own activity (a failed login, a successful
  login, command history, a dropped file).
- Remove or falsify every trace of it.
- Run `/root/verify.sh` on the target. Passing all four checks reveals a
  bonus flag.

**Rules:** target `10.10.11.10` only, attack from `lab11-attacker`
(10.10.11.2) — the verification script checks specifically for this IP.
Flag format `flag{...}`. No hints below — ask your instructor if you get
stuck.

:::::::::::::::::::::::: instructor

The full CTF walkthrough for this lab (including all flag values and the
exact steps) is provided separately to instructors rather than inline here,
so it stays out of a learner's browser history/search results. See the
[instructor notes](lab11-notes.html).

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Cleanup

```bash
exit
cd episodes/files/lab11-log-anti-forensics
docker compose down
```

:::::::::::::::::::::::::::::::::::::: keypoints

- Bash only flushes command history to disk on a normal session exit;
  `unset HISTFILE` stops future writes, but `history -c` (in-memory) and
  truncating `~/.bash_history` directly are both needed to remove what's
  already on disk
- Selectively deleting matching lines from a log (`sed -i '/pattern/d'`) is
  far less suspicious than truncating or emptying the whole file, which is
  itself an obvious red flag to a defender
- Text logs (`auth.log`) and binary login records (`wtmp`, read by `last`)
  are independent records of the same events — covering tracks means
  handling both, not just the first one you think to check
- Timestomping (`touch -r`) copies a reference file's timestamp onto
  another file to blend it in — but the reference file's own age has to be
  credible, or you've just created two suspicious files instead of one
- `rm` only unlinks a filename; the underlying data can still be
  forensically recovered until it's overwritten. `shred -u` overwrites the
  data first, then removes it
- Every anti-forensics technique here has a direct defensive
  countermeasure: centralized/remote logging (so a compromised host can't
  edit the copy that matters), file integrity monitoring (so timestomping
  and silent edits get flagged), and auditd rules that are harder to fully
  suppress than syslog

::::::::::::::::::::::::::::::::::::::::::::::::
