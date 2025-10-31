Param(
  [switch]$All
)

# Remove transient logs and Vivado backup files
$patterns = @(
  'vivado_*.backup.*',
  'vivado.log',
  'vivado.jou',
  'dfx_runtime.txt',
  'rs_dec_0gfinvrom.mif'
)

foreach ($p in $patterns) {
  Get-ChildItem -LiteralPath . -Filter $p -File -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "Removing $($_.FullName)"
    Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
  }
}

if ($All) {
  # Remove local Vivado workspaces (ignored by .gitignore)
  $dirs = @(
    'vivado_rs_bench',
    'vivado_rs_ede',
    'vivado_rs_synth',
    'vivado_cs_synth',
    'vivado_cs_dec_synth',
    '.Xil'
  )
  foreach ($d in $dirs) {
    if (Test-Path $d) {
      Write-Host "Removing directory $d"
      Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

Write-Host "Cleanup done."

