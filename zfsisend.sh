#!/usr/bin/env bash

## Send an incremental ZFS snapshot
## Assumptions:
##  i) The most recent snapshot exists on both $SRC and $DEST
##  ii) Only one snapshot per day (otherwise naming collisions occur)

[ "$UID" -eq 0 ] || exec sudo "$0" "$@"

set -o xtrace
set -o pipefail
set -o errexit
set -o nounset

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -ne 2 ]]
then
    echo "Insufficient arguments: '$@'" >&2
    echo "Usage: '$0 source_filesystem destination_filesystem'" >&2
    exit 1
fi

SRC=$1
DEST=$2

today=$(date  +"%b%d_%Y") # Replace this with a more granular name, if
                          # intra-daily snapshots desired

# List our filesystems, import if they don't exist
zpool list $SRC $DEST || zpool import $SRC || zpool import $DEST

# Find old snapshot & create new snapshot on source filesystem
srcOldSnapshot=$(zfs list -t snapshot -oname,creation  -s creation | \
    grep "^$SRC@" | tail -n1 | cut -f1 -d' ')
srcNewSnapshot="$SRC@$today"
zfs snapshot "$srcNewSnapshot"

# Send
zfs send -pvi $srcOldSnapshot $srcNewSnapshot | zfs receive -F $DEST
