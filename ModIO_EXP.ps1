$updateMods = 0
$debug = 0

# available args:
# -c or --clear-cache : clear cache
# -u or --update      : update mods
# -d or --debug       : show debug output
# -v or --version     : show version

# load env vars
$AccessToken = ""
$UserProfile = ""
$ModsDir = ""
$CacheDir = "$ModsDir\..\cache"

# check if args are given
if ($args.Length -gt 0) {
    foreach ($arg in $args) {
        if ($arg -eq "-c" -or $arg -eq "--clear-cache") {
            if (-not (Test-Path "$CacheDir")) {
                Write-Host "Cache directory does not exist, nothing to clear..."
                exit 0
            }
            Write-Host "Clearing cache..."
            Remove-Item -Path "$CacheDir\*" -Recurse -Confirm
            Write-Host "Done"
            exit 0
        }
        elseif ($arg -eq "-u" -or $arg -eq "--update") {
            $updateMods = 1
        }
        elseif ($arg -eq "-d" -or $arg -eq "--debug") {
            $debug = 1
        }
        elseif ($arg -eq "-v" -or $arg -eq "--version") {
            Write-Host "ModIO_SR.ps1 v0.1"
            exit 0
        }
        else {
            Write-Host "ERROR: Unknown argument: $arg"
            exit 1
        }
    }
}

# set debug preference
if ($debug -eq 1) { $DebugPreference = "Continue" }


# Write-Debug $AccessToken
Write-Debug $UserProfile
Write-Debug $ModsDir

# check if either of the required env vars are empty
if ($AccessToken -eq "" -or $UserProfile -eq "" -or $ModsDir -eq "") {
    Write-Host "ERROR: AccessToken or UserProfile or ModsDir not set in .env file"
    exit 1
}

# check if userprofile dir exists
if (-not (Test-Path $UserProfile)) {
    Write-Host "ERROR: UserProfile does not exist in given path"
    exit 1
}

# check if mod dir exists
if (-not (Test-Path $ModsDir)) {
    Write-Host "ERROR: ModsDir does not exist in given path"
    exit 1
}

# load userprofile as json
$UserProfileJson = Get-Content "$UserProfile" | ConvertFrom-Json

# check if userprofile is valid
if ($null -eq $UserProfileJson.UserProfile) {
    Write-Host "ERROR: UserProfile is not valid"
    exit 1
}

# get subscribed mods
Write-Host "Getting subscribed mods..."

$headers = @{
    "Authorization"    = "Bearer $AccessToken"
    "Accept"           = "application/json"
    "X-Modio-Platform" = "Windows"
}
$body = @{
    game_id = 5734
}

$data = Invoke-RestMethod -Method Get -Uri "https://api.mod.io/v1/me/subscribed" -Headers $headers -Body $body

if ($data.result -eq "401") {
    Write-Host "ERROR: AccessToken is invalid"
    exit 1
}

Write-Debug $data
if ($DebugPreference -eq "Continue") { $data | ConvertTo-Json -Depth 100 | Out-File -FilePath "./temp.json" }

$subscribedMods = @()

foreach ($mod in $data.data) {
    $modID = $mod.id
    $modName = $mod.name
    $modVersionDownload = $mod.modfile.version
    $modDir = "$ModsDir\$modID"
    $subscribedMods += @{
        id = $modID
    }
    if (Test-Path "$CacheDir\$modID") {
        Write-Host "Mod with ID $modID found in cache, moving from cache to mods dir..."
        Move-Item -Path "$CacheDir\$modID" -Destination "$ModsDir"
        Write-Host "Done"
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
            Write-Host "Update available for mod $modID ($modName), use -u or --update to update"
            continue
        }
        else {
            $updateRequired = 1
        }
    }
    if ($updateRequired -eq 1) {
        Write-Host "Updating mod $modID ($modName)..."
    }
    else {
        Write-Host "Installing mod $modID ($modName)..."
    }

    if (-not (Test-Path $modDir)) {
        New-Item -Path $modDir -ItemType Directory
    }

    $resolutions = @('320x180', '640x360')
    foreach ($res in $resolutions) {
        $url = $mod.logo."thumb_$res"
        $logo_path = "$modDir/logo_$res.png"
        $mod."logo"."thumb_$res" = "file:///$logo_path"
        Invoke-WebRequest -Uri $url -Method Get -OutFile $logo_path
    }
    Write-Host "--> Downloading thumbs --> OK"

    Set-Content -Path "$modDir\modio.json" -Value ($mod | ConvertTo-Json -Depth 100)
    Write-Host "--> Creating modio.json --> OK"

    $modUrl = $mod.modfile.download.binary_url
    $modFileName = $mod.modfile.filename
    $modFullPath = "$modDir\$modFileName"
    Write-Host "--> Downloading mod"
    Invoke-WebRequest -Uri $modUrl -Method Get -Headers $headers -OutFile $modFullPath
    Write-Host "--> OK"

    Write-Host "--> Extracting mod $modID ($modName)..."
    Expand-Archive -Path $modFullPath -DestinationPath $modDir -Force
    Remove-Item -Path $modFullPath
    Write-Host "--> OK"
}

$modsInstalled = $UserProfileJson.userprofile.modDependencies.SslValue.dependencies

$modsInstalled | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    # if mod is no longer subscribed, move to cache
    if ($subscribedMods.id -notcontains $_) {
        Write-Host "Mod with ID $_ is not subscribed, moving to cache..."
        Move-Item -Path "$ModsDir\$_" -Destination "$CacheDir"
        Write-Host "Done"
    }
}

$modsInstalled = @{}
foreach ($mod in $subscribedMods) {
    $modsInstalled["$($mod.id)"] = @()
}
$UserProfileJson.userprofile.modDependencies.SslValue.dependencies = $modsInstalled

$UserProfileJson.UserProfile | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name | Where-Object { $_ -like "modStateList" } | ForEach-Object {
    $modsEnabled = $UserProfileJson.UserProfile.$_
    $enabledMods = @()
    foreach ($mod in $modsEnabled) {
        if ($mod.modId -in $subscribedMods.id) {
            $enabledMods += @{
                modId    = $mod.modId
                modState = $mod.modState
            }
        }
    }
    Write-Debug "mod States:"
    Write-Debug (ConvertTo-Json $enabledMods)
    $UserProfileJson.UserProfile.$_ = $enabledMods
}

Write-Host "Updating userprofile..."
Set-Content -Path "$UserProfile" -Value ($UserProfileJson | ConvertTo-Json -Depth 100)
Write-Host "Done"

Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

exit 0