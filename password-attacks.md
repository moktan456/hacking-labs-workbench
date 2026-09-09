---
title: "Password Attacks"
teaching: 20
exercises: 65
---

:::::::::::::::::::::::::::::::::::::: questions

- What's the difference between offline hash cracking and online service brute-forcing?
- How do you identify a hash type before choosing a cracking tool and mode?
- How does Hydra brute-force SSH logins and HTTP login forms?
- Why do small curated wordlists fail where breach-derived lists like rockyou succeed?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Crack MD5 and shadow-style hashes offline with John the Ripper
- Identify a hash type by its character length and crack it with Hashcat
- Brute-force a live SSH service with Hydra
- Brute-force an HTTP login form with Hydra's `http-post-form` module
- Cross-check a brute-force result with Medusa
- Escalate from a small wordlist to a breach-derived wordlist (rockyou) when needed

::::::::::::::::::::::::::::::::::::::::::::::::

## Introduction

Weak passwords remain one of the most reliable ways into a system. This lab
covers both sides of password attacks: **offline** cracking of hashes you
already have (John the Ripper, Hashcat) and **online** brute-forcing of live
login services (Hydra, Medusa).

::::::::::::::::::::::::::::::::::::: callout

### Scope note

Every command below targets only the containers started by this lab's own
`docker-compose.yaml` (subnet `10.10.6.0/24`). Don't point these tools
anywhere else. See the [statutory warning on the lesson home page](../index.html)
and [Setup](../learners/setup.html) before you begin.

::::::::::::::::::::::::::::::::::::::::::::::::

**Tools used:** Hydra, Medusa, John the Ripper, Hashcat
**Network:** `lab6-attacker` (10.10.6.2, Kali — wordlists and hashes
pre-loaded) · `lab6-ssh` (10.10.6.10, SSH target with weak passwords) ·
`lab6-web` (10.10.6.11, HTTP login form for `hydra http-post-form` practice)

Follow [Setup](../learners/setup.html), then:

```bash
cd episodes/files/lab6-password-attacks
docker compose up -d
docker exec -it lab6-attacker bash
```

before continuing. Wordlists are mounted at `/wordlists`, sample hashes at
`/hashes`. The full `rockyou.txt` wordlist is also available at
`/usr/share/wordlists/rockyou.txt` inside the attacker container.

## Part 1: Offline Cracking with John the Ripper

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 1: Crack MD5 hashes

```bash
john --wordlist=/wordlists/basic.txt --format=Raw-MD5 /hashes/easy-md5.txt
john --show --format=Raw-MD5 /hashes/easy-md5.txt
```

What plaintext passwords did you recover?

:::::::::::::::::::::::: solution

`/hashes/easy-md5.txt` contains two raw MD5 hashes, both crackable from
`/wordlists/basic.txt`:

| Hash (first 8 chars) | Plaintext |
|------------------------|-----------|
| `0d107d09`              | `letmein` |
| `8621ffdb`              | `dragon`  |

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 2: Crack a shadow-style hash

```bash
john --wordlist=/wordlists/basic.txt /hashes/john-format.txt
john --show /hashes/john-format.txt
```

Did the small wordlist crack it?

If not, escalate to the full rockyou wordlist:

```bash
john --wordlist=/usr/share/wordlists/rockyou.txt /hashes/john-format.txt
john --show /hashes/john-format.txt
```

1. What password did you recover, and which wordlist found it?
2. Why did the small curated wordlist fail here while rockyou (a real
   breach-derived list) succeeded?

:::::::::::::::::::::::: solution

1. No — `/hashes/john-format.txt` holds an MD5-crypt shadow-style hash
   (`svc_backup:$1$xyzabc$...`), and none of the 10 entries in `basic.txt`
   crack it. You need to escalate to `/usr/share/wordlists/rockyou.txt`
   inside the attacker container; the crack depends on which real
   breach-derived password is in that 14-million-entry list, so run the
   command above and read the recovered plaintext from `john --show` — a
   correct answer names whatever password John reports, plus "rockyou.txt".
2. `basic.txt` only covers 10 hand-picked guesses. `rockyou.txt` is a real
   password list leaked from an actual data breach, with 14 million+
   entries — since people reuse passwords across services, a password that
   shows up in a real breach is far more likely to match this account's
   actual (reused) password than a small curated guess list is.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 2: Offline Cracking with Hashcat

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 3: Identify the hash type

Hash formats have recognizable lengths: MD5 is 32 hex characters, SHA-1 is
40, SHA-256 is 64.

```bash
cat /hashes/medium-sha256.txt
wc -c /hashes/medium-sha256.txt
```

How many hex characters is this hash? What type must it be?

:::::::::::::::::::::::: solution

The hash is 64 hex characters long (`wc -c` reports 65, counting the
trailing newline) — that length identifies it as **SHA-256**.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 4: Crack it with hashcat

SHA-256 raw hashes are hashcat mode `1400`.

```bash
hashcat -a 0 -m 1400 /hashes/medium-sha256.txt /wordlists/basic.txt
hashcat -m 1400 /hashes/medium-sha256.txt --show
```

1. What was the plaintext?
2. `-a 0` is a straight wordlist attack. What does hashcat's `-a 3`
   (mask/brute-force) mode do differently, and when would you reach for it
   instead?

:::::::::::::::::::::::: solution

1. `qwerty` — its SHA-256 digest matches `/hashes/medium-sha256.txt`.
2. `-a 3` doesn't read guesses from a wordlist at all — it generates every
   possible combination of characters that fits a mask you define (e.g.
   `?l?l?l?l?d?d` for four lowercase letters followed by two digits),
   trying every combination in that search space. Reach for it when you
   have some idea of a password's length or structure but no wordlist is
   likely to contain it — it's exhaustive rather than guess-based, so it
   trades speed for guaranteed coverage of a defined space.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 3: Online Brute-Forcing with Hydra

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 5: SSH brute-force

```bash
hydra -l admin -P /wordlists/basic.txt ssh://10.10.6.10
```

Did Hydra find valid credentials? What were they?

:::::::::::::::::::::::: solution

Yes — `admin:letmein`. The `lab6-ssh` container's `admin` account uses
password `letmein`, which is entry 3 in `/wordlists/basic.txt`.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 6: Confirm access and grab the flag

```bash
ssh admin@10.10.6.10
# use the password Hydra found
cat user.txt
```

What flag did you retrieve?

:::::::::::::::::::::::: solution

Logging in as `admin` with password `letmein` and reading `user.txt`
returns `flag{lab6_password_cracked_ssh}`.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 7: Web login form brute-force

`hydra`'s `http-post-form` module needs the login path, the POST body
template (with `^USER^`/`^PASS^` placeholders), and a string that appears
only on failure:

```bash
hydra -l admin -P /wordlists/basic.txt 10.10.6.11 http-post-form "/login:user=^USER^&pass=^PASS^:Invalid username or password"
```

1. Did Hydra find valid credentials for the web login?
2. Why does Hydra need you to tell it what a *failed* login response looks
   like, rather than just trying every password until one seems to work?

:::::::::::::::::::::::: solution

1. Yes — `admin:letmein`. The web login form's `admin` account also uses
   password `letmein`, which is in `basic.txt`.
2. The login form always responds with HTTP `200 OK`, whether the
   credentials were right or wrong — the status code alone can't tell
   Hydra whether an attempt succeeded. So Hydra has to inspect the actual
   response body: it's told what text ("Invalid username or password")
   only appears on a failed attempt, and treats any response *without*
   that text as a successful login.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 4: Medusa as a Second Opinion

Different tools implement the same attack differently — worth knowing more
than one.

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 8: Cross-check with Medusa

```bash
medusa -h 10.10.6.10 -u user1 -P /wordlists/basic.txt -M ssh
```

Did Medusa recover `user1`'s password? What was it?

:::::::::::::::::::::::: solution

Yes — `qwerty`. The `lab6-ssh` container's `user1` account uses password
`qwerty`, entry 4 in `/wordlists/basic.txt`.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Quick Knowledge Check

::::::::::::::::::::::::::::::::::::: challenge

### Check your understanding

1. What's the fundamental difference between offline and online password
   attacks?
   - A) Offline attacks are always faster because you're not limited by
     network round-trips or lockout policies
   - B) There's no difference
   - C) Online attacks are always faster
   - D) Offline attacks require a network connection
2. Why might a small, curated wordlist fail where a large breach-derived
   list (like rockyou) succeeds?
   - A) Curated lists are always better
   - B) Real users tend to reuse passwords found in actual historical
     breaches
   - C) rockyou is faster to load
   - D) There's no meaningful difference
3. In `hydra ... http-post-form
   "/login:user=^USER^&pass=^PASS^:Invalid username or password"`, what
   does the third field do?
   - A) Sets a timeout
   - B) Tells Hydra what text in the response means the attempt failed
   - C) Sets the HTTP method
   - D) Specifies an SSL port
4. What does hashcat mode `1400` correspond to?
   - A) MD5  B) SHA-1  C) SHA-256  D) NTLM
5. Why check a hash's character length before choosing a cracking mode?
   - A) You shouldn't — it doesn't matter
   - B) The length is a strong hint at the hash algorithm, which
     determines which mode/format to use
   - C) It determines the wordlist
   - D) It sets the salt

:::::::::::::::::::::::: solution

1. A — offline cracking works on a hash you already possess, so it isn't
   slowed by network round-trips or blocked by an account lockout policy
   the way an online attack against a live service is.
2. B
3. B
4. C — SHA-256
5. B

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Optional: CTF challenge

Once you've completed the exercises above, try the optional flag-capture
challenge: two flags are hidden on `lab6-ssh` (10.10.6.10), reachable via
password attacks against two different accounts — `user.txt` and
`root.txt`. Bonus: the web login form on `lab6-web` (10.10.6.11) returns
its own flag once you find valid credentials. Target `10.10.6.0/24` only,
attack from `lab6-attacker`, flag format `flag{...}`. No hints below — ask
your instructor if you get stuck.

:::::::::::::::::::::::: instructor

The full CTF walkthrough for this lab (including all flag values and the
exact steps) is provided separately to instructors rather than inline
here, so it stays out of a learner's browser history/search results. See
[Lab 6 Notes](../instructors/lab6-notes.html).

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Cleanup

```bash
exit
cd episodes/files/lab6-password-attacks
docker compose down
```

:::::::::::::::::::::::::::::::::::::: keypoints

- Offline cracking (John the Ripper, Hashcat) works on hashes you already
  have and isn't slowed by network round-trips or lockout policies; online
  brute-forcing (Hydra, Medusa) attacks a live service and is bounded by
  both
- A hash's character length is a strong clue to its algorithm — 32 hex
  characters is MD5, 40 is SHA-1, 64 is SHA-256 — which determines the
  cracking mode/format you select
- Small curated wordlists fail where large breach-derived lists (rockyou,
  14 million+ entries) succeed, because real users reuse passwords found in
  real breaches
- Hydra's `http-post-form` module needs the login path, a POST body
  template with `^USER^`/`^PASS^` placeholders, and a string that only
  appears on a failed login — since an HTTP response's status code alone
  often can't tell success from failure
- Different tools (Hydra vs. Medusa) implement the same brute-force attack
  differently — cross-checking a result with a second tool is a useful
  sanity check
- Even a 10-entry test wordlist is often enough to crack real weak
  passwords, which is why "long enough to survive a wordlist attack" is a
  much lower bar than most people assume

::::::::::::::::::::::::::::::::::::::::::::::::
