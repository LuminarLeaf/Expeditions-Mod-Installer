$updateMods = 0
$debug = 0
$clearCache = 0

# available args:
# -c or --clear-cache : clear cache
# -u or --update      : update mods
# -d or --debug       : show debug output
# -v or --version     : show version

# load env vars
Get-Content .env | ForEach-Object {
    if ([string]::IsNullOrWhiteSpace($_) -or $_.Contains('#')) { continue }
    $name, $value = $_.split('=')
    $name = $name.Trim()
    $value = $value.Trim()
    Set-Content env:\$name $value
}

# check if args are given
if ($args.Length -gt 0) {
    foreach ($arg in $args) {
        if ($arg -eq "-c" -or $arg -eq "--clear-cache") {
            $clearCache = 1
        }
        elseif ($arg -eq "-u" -or $arg -eq "--update") {
            $updateMods = 1
        }
        elseif ($arg -eq "-d" -or $arg -eq "--debug") {
            $debug = 1
        }
        elseif ($arg -eq "-v" -or $arg -eq "--version") {
            Write-Output "ModIO_EXP.ps1 v1.1"
            exit 0
        }
        else {
            Write-Output "ERROR: Unknown argument: $arg"
            exit 1
        }
    }
}

# set debug preference
if ($debug -eq 1) { $DebugPreference = "Continue" }


# Write-Debug $AccessToken
Write-Debug "Mods dir : $env:MODS_DIR"
Write-Debug "User profile : $env:USER_PROFILE"
Write-Debug "Access token : $($env:ACCESS_TOKEN.Substring(0, 10) + "..." + $env:ACCESS_TOKEN.Substring($env:ACCESS_TOKEN.Length - 10, 10))"

# check if either of the required env vars are empty
$vars = @($env:ACCESS_TOKEN, $env:USER_PROFILE, $env:MODS_DIR)
if ($null -in $vars -or $vars -contains "") {
    Write-Output "ERROR: AccessToken or UserProfile or ModsDir not set in .env file"
    exit 1
}

# check if userprofile dir exists
if (-not (Test-Path $env:USER_PROFILE)) {
    Write-Output "ERROR: UserProfile does not exist in given path"
    exit 1
}

# check if mod dir exists
if (-not (Test-Path $env:MODS_DIR)) {
    Write-Output "ERROR: ModsDir does not exist in given path"
    exit 1
}

Set-Content env:CACHE_DIR "$env:MODS_DIR\..\cache"
Write-Debug "Cache dir : $env:CACHE_DIR"
if (-not (Test-Path $env:CACHE_DIR)) {
    Write-Debug "Cache dir does not exist, creating..."
    New-Item -Path "$env:CACHE_DIR" -ItemType Directory
    Write-Debug "Done"
}

if ($clearCache -eq 1) {
    Write-Output "Clearing cache..."
    # get user confirmation
    $confirmation = Read-Host "Are you sure you want delete the directory $env:CACHE_DIR? (y/n)"
    if ($confirmation -ne "y" -and $confirmation -ne "Y" -and $confirmation -ne "yes" -and $confirmation -ne "Yes") {
        Write-Output "Aborted"
        exit 0
    }
    Get-ChildItem -Path "$env:CACHE_DIR" | Remove-Item -Recurse
    Write-Output "Done"
    exit 0
}

# load userprofile as json
$UserProfileJson = Get-Content -Path "$env:USER_PROFILE"
while ($UserProfileJson[-1] -ne "}") {
    $UserProfileJson = $UserProfileJson.Substring(0, $UserProfileJson.Length - 1)
}
$UserProfileJson = $UserProfileJson | ConvertFrom-Json

# check if userprofile is valid
if ($null -eq $UserProfileJson.UserProfile) {
    Write-Output "ERROR: UserProfile is not valid"
    exit 1
}

# get subscribed mods
Write-Output "Getting subscribed mods..."

$headers = @{
    "Authorization"    = "Bearer $env:ACCESS_TOKEN"
    "Accept"           = "application/json"
    "X-Modio-Platform" = "Windows"
}
$body = @{
    game_id = 5734
}

$data = Invoke-RestMethod -Method Get -Uri "https://api.mod.io/v1/me/subscribed" -Headers $headers -Body $body

if ($data.result -eq "401") {
    Write-Output "ERROR: AccessToken is invalid"
    exit 1
}

Write-Debug $data
if ($DebugPreference -eq "Continue") { $data | ConvertTo-Json -Depth 100 | Out-File -FilePath "./data.json" }

$subscribedMods = @()

foreach ($mod in $data.data) {
    $modID = $mod.id
    $modName = $mod.name
    $modVersionDownload = $mod.modfile.version
    $modDir = "$env:MODS_DIR\$modID"
    $subscribedMods += @{
        id = $modID
    }
    # if (Test-Path "$CacheDir\$modID") {
    if ((Test-Path "$env:CACHE_DIR\$modID") -and -not (Test-Path "$modDir")) {
        Write-Output "Mod with ID $modID found in cache, moving from cache to mods dir..."
        Move-Item -Path "$env:CACHE_DIR\$modID" -Destination "$env:MODS_DIR"
        Write-Output "Done"
        continue
    }
    $updateRequired = 0
    if (Test-Path "$modDir") {
        $installedVersion = ( Get-Content "$modDir\modio.json" | ConvertFrom-Json | Select-Object -ExpandProperty modfile | Select-Object -ExpandProperty version )
        if ($installedVersion -eq $modVersionDownload) {
            Write-Debug "Mod $modID is up to date"
            continue
        }
        elseif ($updateMods -ne 1) {
            Write-Output "Update available for mod $modID ($modName), use -u or --update to update"
            continue
        }
        else {
            $updateRequired = 1
        }
    }
    if ($updateRequired -eq 1) {
        Write-Output "Updating mod $modID ($modName)..."]
        Remove-Item -Path "$modDir" -Recurse
    }
    else {
        Write-Output "Installing mod $modID ($modName)..."
    }

    if (-not (Test-Path "$modDir")) {
        New-Item -Path "$modDir" -ItemType Directory | Out-Null
    }

    $resolutions = @('320x180', '640x360')
    foreach ($res in $resolutions) {
        $url = $mod.logo."thumb_$res"
        $logo_path = "$modDir/logo_$res.png"
        Invoke-WebRequest -Uri $url -Method Get -OutFile $logo_path
    }
    Write-Output "--> Downloading thumbs --> OK"

    Set-Content -Path "$modDir\modio.json" -Value ($mod | ConvertTo-Json -Depth 100 -Compress)
    Write-Output "--> Creating modio.json --> OK"

    $modUrl = $mod.modfile.download.binary_url
    $modFileName = $mod.modfile.filename
    $modFullPath = "$modDir\$modFileName"
    try {
        Write-Output "--> Downloading mod"
        Invoke-WebRequest -Uri $modUrl -Method Get -Headers $headers -OutFile $modFullPath
        Write-Output "--> OK"
    }
    catch {
        Write-Output "Failed to download mod. Halting script execution."
        Write-Output "Error: $_"
        exit 1
    }

    Write-Output "--> Extracting mod $modID ($modName)..."
    $extracted = $false
    try {
        Expand-Archive -Path $modFullPath -DestinationPath $modDir
        $extracted = $true
    }
    catch {
        Write-Output "Failed to extract mod $modID ($modName). Halting script execution."
        Write-Output "Error: $_"
        exit 1
    }

    if ($extracted) {
        Remove-Item -Path $modFullPath
        Write-Output "--> OK"
    }
}

# get previously installed mods
$modsInstalled = $UserProfileJson.userprofile.modDependencies.SslValue.dependencies

# check if mods are no longer subscribed
$modsInstalled | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    # if mod is no longer subscribed, move to cache
    if ($subscribedMods.id -notcontains $_) {
        Write-Output "Mod with ID $_ is not subscribed, moving to cache..."
        Move-Item -Path "$env:MODS_DIR\$_" -Destination "$env:CACHE_DIR"
        Write-Output "Done"
    }
}

# update installed mods list
$modsInstalled = @{}
foreach ($mod in $subscribedMods) {
    $modsInstalled["$($mod.id)"] = @()
}
$UserProfileJson.userprofile.modDependencies.SslValue.dependencies = $modsInstalled
Write-Debug "Mods Installed: $(ConvertTo-Json $modsInstalled -Compress)"

$UserProfileJson.UserProfile | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name | Where-Object { $_ -like "modStateList" } | ForEach-Object {
    $modsEnabledB4 = $UserProfileJson.UserProfile.$_
    $enabledMods = @()
    foreach ($mod in $modsEnabledB4) {
        if ($mod.modId -in $subscribedMods.id) {
            $enabledMods += @{
                modId    = $mod.modId
                modState = $mod.modState
            }
        }
    }
    Write-Debug "Mod States: $(ConvertTo-Json $enabledMods -Compress)"
    $UserProfileJson.UserProfile.$_ = $enabledMods
}

Write-Output "Updating userprofile..."
# Set-Content -Path "$UserProfile" -Value ($UserProfileJson | ConvertTo-Json -Depth 100)
Set-Content -Path "$env:USER_PROFILE" -Value ($UserProfileJson | ConvertTo-Json -Depth 100 -Compress)
Write-Output "Done"

Pause