# Renders user-data.sh.tftpl via Terraform (no AWS credentials required).
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path (Join-Path $Root "user-data.sh.tftpl"))) {
  $Root = Split-Path -Parent $PSScriptRoot
}
Set-Location $Root
terraform init -input=false | Out-Null
terraform validate -no-color
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$expr = "length(local.ci_user_data_rendered)"
$len = $expr | terraform console -var="suffix=ci" -var="instance_name=ci" 2>&1
if ($LASTEXITCODE -ne 0) { Write-Error $len; exit $LASTEXITCODE }
Write-Host "user-data.sh.tftpl rendered OK ($($len.Trim()) bytes)"
exit 0
