#!/bin/bash
# Anti-forensics verification script - checks whether you actually covered your tracks.
PASS=1

echo "=== Covering Tracks Verification ==="

if grep -q "10.10.11.2" /var/log/auth.log 2>/dev/null; then
    echo "[FAIL] auth.log still references your source IP (10.10.11.2)"
    PASS=0
else
    echo "[PASS] auth.log clean"
fi

LASTCOUNT=$(last -f /var/log/wtmp 2>/dev/null | grep -v "^$" | grep -vc "wtmp begins")
if [ "$LASTCOUNT" -gt 0 ]; then
    echo "[FAIL] wtmp still has $LASTCOUNT login record(s)"
    PASS=0
else
    echo "[PASS] wtmp cleared"
fi

if [ -s /root/.bash_history ]; then
    echo "[FAIL] .bash_history is not empty"
    PASS=0
else
    echo "[PASS] bash history cleared"
fi

DROPPED_MTIME=$(stat -c %Y /root/dropped_tool.sh 2>/dev/null)
REF_MTIME=$(stat -c %Y /root/legit_reference.txt 2>/dev/null)
if [ -n "$DROPPED_MTIME" ] && [ "$DROPPED_MTIME" == "$REF_MTIME" ]; then
    echo "[PASS] dropped_tool.sh timestamp matches the reference file"
else
    echo "[FAIL] dropped_tool.sh timestamp does not match legit_reference.txt (timestomp not applied)"
    PASS=0
fi

echo
if [ "$PASS" -eq 1 ]; then
    echo "ALL CHECKS PASSED"
    echo "flag{lab11_covered_all_tracks}"
else
    echo "Some checks failed - keep working."
fi
