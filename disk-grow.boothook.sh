#!/bin/bash
# cloud-boothook - runs EARLY in the cloud-init init stage, on every boot.
#
# The DCV AMI ships an ~8G LVM root (/dev/cl/root) that is already ~99% full
# (the base image plus stale /var/log/pcp logs captured from the build host).
# On a larger EBS volume the partition/LVM are NOT auto-grown, so the root fs
# stays 8G and fills immediately. cloud-init then crashes with
# "OSError: [Errno 28] No space left on device" while writing its own status,
# and the main bootstrap (cloud-final) never runs.
#
# This boothook frees the stale pcp logs for scratch space, then grows the
# partition + PV + root LV (and its filesystem) to fill the disk BEFORE the
# init stage needs to write anything. All steps are idempotent: once the LV
# already fills the disk they are no-ops, so running every boot is safe.
exec >>/var/log/lab-disk-grow.log 2>&1
echo "[$(date -u +%FT%TZ)] boothook disk-grow start: $(df -h / 2>/dev/null | tail -1)"

# Reclaim the ~650MB of stale Performance Co-Pilot logs baked into the AMI.
rm -rf /var/log/pcp/pmlogger/* 2>/dev/null || true

if [ -b /dev/nvme0n1p2 ]; then
  command -v growpart >/dev/null 2>&1 && growpart /dev/nvme0n1 2 || true
  command -v pvresize >/dev/null 2>&1 && pvresize /dev/nvme0n1p2 || true
  if command -v lvextend >/dev/null 2>&1 && lvs /dev/cl/root >/dev/null 2>&1; then
    lvextend -r -l +100%FREE /dev/cl/root || true
  fi
fi

echo "[$(date -u +%FT%TZ)] boothook disk-grow done: $(df -h / 2>/dev/null | tail -1)"
