#!/usr/bin/env bash
# Append Pico VID/PIDs to the ccid driver's Info.plist.
# Idempotent: pairs already present are skipped, arrays stay aligned.
set -oue pipefail

python3 - "${1:-/usr/lib64/pcsc/drivers/ifd-ccid.bundle/Contents/Info.plist}" <<'EOF'
import plistlib
import sys

path = sys.argv[1]
want = [
    ('0x2E8A', '0x10FF', 'Pico OpenPGP'),
    ('0x2E8A', '0x10FE', 'Pico FIDO'),
    ('0xFEFF', '0xFCFD', 'Pico SDK fallback'),
]
with open(path, 'rb') as f:
    d = plistlib.load(f)
have = set(zip(d['ifdVendorID'], d['ifdProductID']))
for vid, pid, name in want:
    if (vid, pid) not in have:
        d['ifdVendorID'].append(vid)
        d['ifdProductID'].append(pid)
        d['ifdFriendlyName'].append(name)
assert len(d['ifdVendorID']) == len(d['ifdProductID']) == len(d['ifdFriendlyName'])
with open(path, 'wb') as f:
    plistlib.dump(d, f)
print('ccid plist entries:', len(d['ifdVendorID']))
EOF
