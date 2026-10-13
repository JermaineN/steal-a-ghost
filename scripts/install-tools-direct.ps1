# Downloads Roblox dev tools directly from their official GitHub releases
# (fallback for when Rokit can't reach GitHub on this machine).
$ErrorActionPreference = "Stop"
$bin = Join-Path $env:USERPROFILE ".roblox-tools\bin"
New-Item -ItemType Directory -Force $bin | Out-Null

$tools = @(
    @{ repo = "rojo-rbx/rojo";        pattern = "windows-x86_64\.zip$" },
    @{ repo = "JohnnyMorganz/StyLua"; pattern = "windows-x86_64\.zip$" },
    @{ repo = "Kampfkarren/selene";   pattern = "^selene-[\d.]+-windows\.zip$" },
    @{ repo = "UpliftGames/wally";    pattern = "win64\.zip$" }
)

foreach ($t in $tools) {
    $rel = Invoke-RestMethod "https://api.github.com/repos/$($t.repo)/releases/latest"
    $asset = $rel.assets | Where-Object { $_.name -match $t.pattern } | Select-Object -First 1
    if (-not $asset) { Write-Warning "No Windows build found for $($t.repo)"; continue }
    $tmp = Join-Path $env:TEMP $asset.name
    Write-Host "Downloading $($t.repo) $($rel.tag_name) ($($asset.name))"
    Invoke-WebRequest $asset.browser_download_url -OutFile $tmp
    Expand-Archive $tmp -DestinationPath $bin -Force
    Remove-Item $tmp
}

# Add to the user PATH permanently (if not already there)
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$bin*") {
    [Environment]::SetEnvironmentVariable("Path", "$bin;$userPath", "User")
    Write-Host "Added $bin to your PATH (open a new terminal to use it)."
}
Get-ChildItem $bin -Filter *.exe | ForEach-Object { & $_.FullName --version }
