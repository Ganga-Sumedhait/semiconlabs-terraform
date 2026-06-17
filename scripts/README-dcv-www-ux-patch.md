# One-time DCV www UX patch for running lab EC2 instances

Patches **already-running** lab VMs without reprovisioning:

1. Replaces NICE DCV **"The connection has been closed"** with a duplicate-session message.
2. Injects `custom-popup.js` (Stop Lab reminder on first DCV opens).

Idempotent: marker file `/etc/lab/dcv-www-ux-v1.done` on the guest.

## Automatic (recommended)

Deploy **Semiconlabs-backend**. The reconcile cron (every 60s) and Start Lab will SSM-patch any `RUNNING` lab instance that does not yet have `connection_details.dcv_www_ux_patch_v1=true`.

Disable with env: `LAB_PATCH_DCV_WWW_UX_ENABLED=false`

## Manual — PowerShell (Windows)

```powershell
cd semiconlabs-terraform\scripts
.\patch-dcv-www-ux.ps1 -InstanceIds i-03dd6bdd8a735e055 -Region ap-south-1
```

## Manual — AWS CLI

```bash
cd semiconlabs-terraform/scripts
aws ssm send-command \
  --region ap-south-1 \
  --instance-ids i-xxxxxxxx \
  --document-name AWS-RunShellScript \
  --comment "manual lab-dcv-www-ux-patch" \
  --timeout-seconds 120 \
  --parameters file://<(jq -Rn --arg f "$(cat patch-dcv-www-ux.sh)" '{commands: ($f|split("\n"))}')
```

On Windows without `jq`, use the PowerShell script above.

## Verify

```bash
aws ssm list-command-invocations --command-id <CommandId> --details --region ap-south-1
ssh centos@<lab-ip> "test -f /etc/lab/dcv-www-ux-v1.done && ls -la /usr/share/dcv/www/custom-popup.js"
```

## New instances

New labs get the same patch from `user-data.sh.tftpl` at bootstrap — no SSM needed.
