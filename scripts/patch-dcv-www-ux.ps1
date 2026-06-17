# One-time DCV www UX patch for running lab EC2 instances (duplicate-session message + Stop Lab alert).
# Requires: AWS CLI, SSM agent Online on target instance, LabSSMRole / AmazonSSMManagedInstanceCore.
#
# Usage:
#   .\patch-dcv-www-ux.ps1 -InstanceIds i-abc123,i-def456
#   .\patch-dcv-www-ux.ps1 -InstanceIds i-abc123 -Region ap-south-1

param(
  [Parameter(Mandatory = $true)]
  [string[]] $InstanceIds,

  [string] $Region = $env:AWS_DEFAULT_REGION
)

if (-not $Region) { $Region = 'ap-south-1' }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$bashScript = Join-Path $scriptDir 'patch-dcv-www-ux.sh'
if (-not (Test-Path $bashScript)) {
  throw "Missing $bashScript"
}

$lines = @(Get-Content -Path $bashScript)
$paramsObj = @{ commands = $lines }
$paramsFile = Join-Path $env:TEMP ("dcv-www-ux-params-{0}.json" -f ([guid]::NewGuid().ToString('N')))
$paramsObj | ConvertTo-Json -Depth 4 | Set-Content -Path $paramsFile -Encoding UTF8

try {
  Write-Host "Sending DCV www UX patch to: $($InstanceIds -join ', ') (region=$Region)"
  $respJson = aws ssm send-command `
    --region $Region `
    --instance-ids $InstanceIds `
    --document-name 'AWS-RunShellScript' `
    --comment 'manual lab-dcv-www-ux-patch' `
    --timeout-seconds 120 `
    --parameters "file://$($paramsFile -replace '\\','/')" `
    --output json
  if ($LASTEXITCODE -ne 0) { throw "aws ssm send-command failed (exit $LASTEXITCODE)" }
  $resp = $respJson | ConvertFrom-Json
  $cmdId = $resp.Command.CommandId
  Write-Host "CommandId: $cmdId"
  Write-Host "Poll: aws ssm list-command-invocations --command-id $cmdId --details --region $Region"
}
finally {
  Remove-Item -Path $paramsFile -Force -ErrorAction SilentlyContinue
}
