---
title: "Directory Service & DB Enumeration"
teaching: 15
exercises: 62
---

:::::::::::::::::::::::::::::::::::::: questions

- How do you enumerate an LDAP directory anonymously versus authenticated?
- How do you list and access SMB shares, and what's the practical difference
  between an unlisted share and one that actually enforces authentication?
- How do you enumerate a MySQL server's databases, tables, and data using
  application-level credentials?
- What information can automated tools like `enum4linux` pull in a single
  pass that you'd otherwise have to gather manually?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Perform an anonymous LDAP bind and compare it to an authenticated search
- Query specific LDAP attributes to map an organization's directory structure
- List SMB shares with `smbclient` and automate enumeration with `enum4linux`
- Access public and private SMB shares, contrasting unlisted vs.
  authenticated access
- Enumerate a MySQL server's databases, tables, and data using
  application-level credentials

::::::::::::::::::::::::::::::::::::::::::::::::

## Introduction

Ports found by nmap are just the start — real enumeration means talking to
each service in its own protocol to pull out usernames, shares, database
names, and anything else that helps plan the next phase. This lab covers
three of the most common enterprise services: LDAP (directory services),
SMB (file shares), and MySQL (databases).

::::::::::::::::::::::::::::::::::::: callout

### Scope note

Every command below targets only the containers started by this lab's own
`docker-compose.yaml` (subnet `10.10.5.0/24`). Don't point these tools
anywhere else. See the [statutory warning on the lesson home page](../index.html)
and [Setup](../learners/setup.html) before you begin.

::::::::::::::::::::::::::::::::::::::::::::::::

**Tools used:** `ldapsearch`, `smbclient`, `enum4linux`, `mysql` client
**Network:** `lab5-attacker` (10.10.5.2, Kali) · `lab5-ldap` (10.10.5.10,
OpenLDAP directory, domain `cybercorp.local`) · `lab5-mysql` (10.10.5.11,
MySQL 8.0, database `corpdb`) · `lab5-smb` (10.10.5.12, Samba file server —
public + private shares)

Follow [Setup](../learners/setup.html) to build the shared attacker image,
then

```bash
cd episodes/files/lab5-service-enumeration
docker compose up -d
docker exec -it lab5-attacker bash
```

before continuing.

## Part 1: LDAP Enumeration

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 1.1: Anonymous bind attempt

```bash
ldapsearch -x -H ldap://10.10.5.10 -b "dc=cybercorp,dc=local"
```

What happened — did you get directory entries back, or a permissions error?

:::::::::::::::::::::::: solution

An anonymous (unauthenticated) bind against this directory is restricted by
its default access controls, so the search comes back empty or with a
permissions/insufficient-access error rather than listing entries — the
directory doesn't hand out its contents to anyone who simply connects.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 1.2: Authenticated search

```bash
ldapsearch -x -H ldap://10.10.5.10 -D "cn=readonly,dc=cybercorp,dc=local" -w readonly123 -b "dc=cybercorp,dc=local"
```

Compare this result to Exercise 1.1. What changed once you authenticated,
even with a low-privilege read-only account?

:::::::::::::::::::::::: solution

Binding as `readonly` (even though it has no administrative privileges)
satisfies the directory's access controls, so the full tree is now
returned: the `people` and `groups` organizational units, and the user
entries inside them (`jsmith` — Network Administrator, `mrodriguez` —
Database Administrator) with attributes like `cn`, `sn`, `mail`, and
`title`. Authentication, not privilege level, was the gate here.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 1.3: Query specific attributes

```bash
ldapsearch -x -H ldap://10.10.5.10 -D "cn=readonly,dc=cybercorp,dc=local" -w readonly123 -b "dc=cybercorp,dc=local" "(objectClass=organizationalUnit)"
```

What organizational units (OUs) exist in this directory?

:::::::::::::::::::::::: solution

Two: `ou=people,dc=cybercorp,dc=local` and `ou=groups,dc=cybercorp,dc=local`
— a standard split between user accounts and group definitions (the
`itadmins` group, containing `jsmith`, lives under `groups`).

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 2: SMB Enumeration

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 2.1: List shares anonymously

```bash
smbclient -L 10.10.5.12 -N
```

What shares are listed?

| Share | Comment |
|-------|---------|
| `public` | (no comment set) |
| `IPC$` | IPC Service |

:::::::::::::::::::::::: solution

Only `public` (browsable, guest access allowed) and the default `IPC$`
administrative share show up. The `private` share exists on the server but
does **not** appear in this listing, because its `smb.conf` stanza sets
`browsable = no` — it's deliberately left out of anonymous share
enumeration.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 2.2: enum4linux automated enumeration

```bash
enum4linux -a 10.10.5.12
```

What information did `enum4linux` pull automatically that you'd otherwise
have to gather manually?

:::::::::::::::::::::::: solution

A single `enum4linux -a` run surfaces the share names (including ones a
plain `smbclient -L` might make you dig for) *and* the local Samba/system
usernames (`alice`, `bob`) in one pass — combining what would otherwise
take a `smbclient -L`, plus separate NetBIOS/RID-cycling enumeration steps,
into one automated tool.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 2.3: Access the public share

```bash
smbclient //10.10.5.12/public -N
# smb: \> ls
# smb: \> get user.txt
# smb: \> exit
cat user.txt
```

Did you retrieve a flag?

:::::::::::::::::::::::: solution

Yes — `user.txt` on the `public` share contains
`flag{lab5_smb_guest_accessed}`, retrievable with no credentials at all
since `public` sets `guest ok = yes`.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 2.4: Try the private share without credentials, then with them

```bash
smbclient //10.10.5.12/private -N
```

What happened?

```bash
smbclient //10.10.5.12/private -U alice%alice123
# smb: \> ls
# smb: \> get root.txt
# smb: \> exit
cat root.txt
```

Did you retrieve a flag this time?

What's the practical difference, from an attacker's perspective, between a
share that's merely unlisted versus one that actually enforces
authentication?

:::::::::::::::::::::::: solution

The anonymous (`-N`) attempt against `private` is rejected — `private` sets
`guest ok = no` and `valid users = alice`, so an unauthenticated session is
refused outright (access denied), regardless of whether the share's name is
already known.

With valid credentials (`alice` / `alice123`, the one account listed in
`valid users`), the connection succeeds and `root.txt` contains
`flag{lab5_smb_valid_creds_private_share}`. Note that `bob` / `bob456` is a
real account on the box but is **not** authorized on `private` — only
`alice` is listed.

Practical difference: an *unlisted* share (`browsable = no`) is only hidden
from casual browsing — anyone who already knows or guesses the share name
can still try to connect, and if guest access were allowed, they'd get in.
A share that *enforces authentication* (`guest ok = no` plus `valid users`)
rejects any connection lacking valid credentials for an authorized user, no
matter how the attacker learned the share name. `private` in this lab does
both, but only the authentication requirement is actual access control —
being unlisted is just obscurity.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Part 3: MySQL Enumeration

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 3.1: Connect with application credentials

```bash
mysql -h 10.10.5.11 -u dbuser -pdbpass123 --skip-ssl -e "SHOW DATABASES;"
```

What databases are visible to `dbuser`?

:::::::::::::::::::::::: solution

`corpdb` — the application database `dbuser` was granted access to when the
container was provisioned (`MYSQL_DATABASE=corpdb`, `MYSQL_USER=dbuser`) —
plus the always-visible system schema `information_schema`. `dbuser` is not
an admin account, so it doesn't see every database on the server, only the
one it's scoped to.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Exercise 3.2: Enumerate tables and data

```bash
mysql -h 10.10.5.11 -u dbuser -pdbpass123 --skip-ssl corpdb -e "SHOW TABLES;"
mysql -h 10.10.5.11 -u dbuser -pdbpass123 --skip-ssl corpdb -e "SELECT * FROM users;"
mysql -h 10.10.5.11 -u dbuser -pdbpass123 --skip-ssl corpdb -e "SELECT * FROM notes;"
```

What usernames/roles did you find in the `users` table? Did the `notes`
table contain anything interesting?

`dbuser` is meant to be an application account, not an admin account. Why is
it still worth enumerating what an app-level account can see, rather than
only going after `root`?

:::::::::::::::::::::::: solution

The `users` table lists three accounts and roles: `jsmith`
(`network_admin`), `mrodriguez` (`db_admin`), and `svc_backup`
(`service_account`).

Yes — the `notes` table is interesting: it contains a flag,
`flag{lab5_mysql_app_credentials_enumerated}`, alongside an operational
reminder ("rotate `dbuser` password after the Q1 audit") that leaks
internal process information.

Why bother with an app-level account: it's often the account you *actually
have* — application credentials are more commonly exposed (config files,
default/reused passwords) than root, and getting root is never guaranteed.
Even a scoped, non-admin account can still `SELECT` real usernames, roles,
and leftover internal notes, which is exactly the kind of information that
helps plan lateral movement or privilege escalation — you don't need `root`
to get value out of a database.

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Quick Knowledge Check

::::::::::::::::::::::::::::::::::::: challenge

### Check your understanding

1. What does `smbclient -L <target> -N` do?
   - A) Lists shares with a null (anonymous) session  B) Deletes a share
     C) Lists local files  D) Forces authentication
2. What's the main advantage of `enum4linux -a` over doing SMB enumeration
   manually?
   - A) It's stealthier  B) It automates and combines several SMB/NetBIOS
     enumeration checks into one run  C) It cracks passwords  D) It only
     works on Windows
3. In `ldapsearch`, what does `-D` specify?
   - A) The base DN to search under  B) The distinguished name (identity) to
     bind as  C) The LDAP server URL  D) A search filter
4. Why check both anonymous and authenticated access during LDAP/SMB
   enumeration?
   - A) There's no reason to check both  B) Some information is only exposed
     once authenticated, even with low-privilege credentials  C) Anonymous
     access is always more revealing  D) Authentication is never required
5. What MySQL client flag lets you pass the password inline without a
   prompt?
   - A) `-h`  B) `-u`  C) `-p<password>` (no space)  D) `-e`

:::::::::::::::::::::::: solution

1. A
2. B
3. B
4. B
5. C

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: challenge

### Optional: CTF challenge

Once you've completed the exercises above, try the optional flag-capture
challenge on `lab5-smb` (10.10.5.12): two flags — `user.txt` on the public
share, and `root.txt` on the private share (requires valid credentials —
check what LDAP enumeration revealed). Bonus: a third flag is sitting in a
MySQL table on `lab5-mysql` (10.10.5.11). Targets: `10.10.5.0/24` only.
Attack from `lab5-attacker`. Flag format `flag{...}`. No hints below — ask
your instructor if you get stuck.

:::::::::::::::::::::::: instructor

The full CTF walkthrough for this lab (including all flag values and the
exact steps) is provided separately to instructors rather than inline here,
so it stays out of a learner's browser history/search results. See the
[instructor notes](lab5-notes.html).

:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::

## Cleanup

```bash
exit
cd episodes/files/lab5-service-enumeration
docker compose down
```

:::::::::::::::::::::::::::::::::::::: keypoints

- Anonymous LDAP binds are often restricted by default; even a
  low-privilege authenticated account (like a readonly bind) can reveal the
  full directory tree — authentication, not privilege level, is the gate
- `smbclient -L -N` lists shares visible to an anonymous/null session;
  `enum4linux -a` automates SMB/NetBIOS enumeration (shares, users, OS
  info) in a single pass
- An SMB share with `browsable = no` is merely *unlisted* — real access
  control comes from `guest ok = no` plus `valid users`, which actually
  enforces authentication regardless of whether the share name is known
- Application-level database credentials are worth enumerating on their
  own — `SHOW DATABASES`/`SHOW TABLES` and reading table contents can
  reveal usernames, roles, and leftover internal notes without ever
  reaching `root`
- Never invent credentials or targets: this lab's real accounts are
  `readonly`/`readonly123` (LDAP), `alice`/`alice123` (SMB), and
  `dbuser`/`dbpass123` (MySQL), all scoped to `10.10.5.0/24`

::::::::::::::::::::::::::::::::::::::::::::::::
