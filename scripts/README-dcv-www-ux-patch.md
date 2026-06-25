# DCV www UX patch (v9) for running lab EC2 instances

## What it does

1. Ensures `max-concurrent-clients = 1` in `[session-management]` and `client-eviction-policy = "same-user-oldest-connection"` in `[session-management/automatic-console-session]` (DCV ignores these in `[connectivity]` / `[server]`).
2. Injects `lab-stale-tab-guard.js` (v9) and `custom-popup.js` into `/usr/share/dcv/www/`.
3. Reverts mistaken duplicate-session message text to standard DCV **The connection has been closed**.

**Multi-browser takeover** (browser 2 logs in, browser 1 evicted) is enforced by the **backend SSM eviction** triggered when browser 2 loads `/lab/<token>/` through dcv-router. The dcv.conf settings above are belt-and-suspenders; virtual sessions rely on the backend path.

Sessions already use `--max-concurrent-clients 1` from the backend.

## Expected behaviour

| Scenario | Result |
|----------|--------|
| DCV active in browser 1, same user opens lab URL in browser 2 | Backend evicts browser 1 via SSM; browser 2 connects |
| Browser 1 after eviction | **The connection has been closed** (standard DCV) |
| Stop Lab, return to old DCV tab | **The connection has been closed** |
| First Open Lab | Portal OK dialog + `custom-popup.js` alert |

## Automatic

Deploy backend with v9 SSM patch. Reconcile cron / Start Lab runs SSM when `connection_details.dcv_guard_rev` is not current.

`LAB_PATCH_DCV_WWW_UX_ENABLED=false` disables.

## Manual

```powershell
cd semiconlabs-terraform\scripts
.\patch-dcv-www-ux.ps1 -InstanceIds i-xxxxxxxx -Region ap-south-1
```

## New instances

`user-data.sh.tftpl` applies v9 at bootstrap (correct `[session-management]` dcv.conf + guard scripts). Requires backend + dcv-router with path-based page-nav takeover (`X-Lab-Page-Nav`).
