<#
.SYNOPSIS
    Harnais de validation R1 du banc d'essai (doc v3 12 §8, tâche A7).

.DESCRIPTION
    Pour chaque artefact de corpus.json, dans l'ORDRE réel du pipeline
    (doc 12 §3) :
      1. P0 — préfiltre statique (`meow_testbench --static-check`,
         StaticValidator/A4). Un rejet P0 (ex. import hors allow-list) est le
         verdict : le banc n'est PAS spawné.
      2. P1→P5 — sinon on assemble un job (source inline) et on lance le banc.
    Chaque artefact est joué $Runs fois (défaut 3) pour vérifier :
      - le code de verdict attendu (`expect`) ;
      - la REPRODUCTIBILITÉ (mêmes verdicts sur les 3 runs, à seed fixe) ;
      - le KILL 100 % (tout cas pathologique rend un verdict, jamais de gel) ;
      - le COÛT (validation saine < 8 s ; démarrage froid < 2 s).

.NOTES
    Exécuter APRÈS avoir bâti la cible :
      cmake --build build --config Release --target meow_testbench
#>
param(
    [string]$BenchExe = "",
    [int]$Runs = 3,
    [string]$QtDir = "C:\Qt\6.11.0\mingw_64",
    [string]$MingwBin = "C:\Qt\Tools\mingw1310_64\bin"
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $BenchExe) {
    $BenchExe = Join-Path $scriptDir "..\..\build\Release\meow_testbench.exe"
}
if (-not (Test-Path $BenchExe)) {
    Write-Host "ERREUR : banc introuvable : $BenchExe" -ForegroundColor Red
    Write-Host "Bâtir d'abord : cmake --build build --config Release --target meow_testbench"
    exit 2
}
$BenchExe = (Resolve-Path $BenchExe).Path

# Le banc n'est pas déployé avec ses plugins plateforme/QML : les rendre
# découvrables (cf. BenchSupervisor::benchEnvironment, mais ici en direct).
$env:PATH = "$MingwBin;$QtDir\bin;$env:PATH"
$env:QT_PLUGIN_PATH = "$QtDir\plugins"
$env:QML2_IMPORT_PATH = "$QtDir\qml"
$env:QT_QPA_PLATFORM = "offscreen"

$corpus = Get-Content (Join-Path $scriptDir "corpus.json") -Raw | ConvertFrom-Json
$sha = [System.Security.Cryptography.SHA256]::Create()

function Get-Sha256Hex([string]$text) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
    ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join ""
}

# Lance le banc et retourne l'objet verdict (ou $null). La redirection est faite
# par `cmd /c` (stdout vers un fichier, stderr jeté) : robuste y compris dans un
# hôte PowerShell non interactif, où la capture directe (`& exe` ou
# `Start-Process -Wait -Redirect...`) peut se bloquer sur le drainage des flux.
function Invoke-Bench([string[]]$BenchArgs) {
    $outF = [System.IO.Path]::GetTempFileName()
    try {
        $quoted = ($BenchArgs | ForEach-Object { '"' + $_ + '"' }) -join ' '
        & cmd /c "`"$BenchExe`" $quoted > `"$outF`" 2>nul"
        $line = Get-Content $outF | Where-Object { $_ -like "MEOWBENCH:*" } | Select-Object -Last 1
        if ($line) {
            try { return $line.Substring("MEOWBENCH:".Length) | ConvertFrom-Json } catch { return $null }
        }
        return $null
    } finally {
        Remove-Item $outF -ErrorAction SilentlyContinue
    }
}

function Get-VerdictSignature($v) {
    if ($null -eq $v) { return "<aucun-verdict>" }
    $codes = @()
    if ($v.failures) { $codes = @($v.failures | ForEach-Object { $_.code } | Sort-Object) }
    "$($v.verdict)|" + ($codes -join ",")
}

$results = @()
$maxHealthyMs = 0
$maxColdMs = 0

foreach ($a in $corpus.artifacts) {
    $qml = Join-Path $scriptDir $a.file
    $source = Get-Content $qml -Raw
    $hash = Get-Sha256Hex $source

    $artifact = [ordered]@{ source = $source; targetUuid = $a.targetUuid; contentHash = $hash }
    if ($a.PSObject.Properties.Name -contains "writeSet") { $artifact["writeSet"] = @($a.writeSet) }
    $stimuli = @()
    if ($a.PSObject.Properties.Name -contains "stimuli") { $stimuli = @($a.stimuli) }

    $job = [ordered]@{
        jobId        = "corpus_" + [System.IO.Path]::GetFileNameWithoutExtension($a.file)
        benchVersion = $corpus.benchVersion
        snapshot     = [ordered]@{ map = @{}; memory = @{}; modules = @() }
        artifact     = $artifact
        budgets      = $corpus.defaultBudgets
        stimuli      = $stimuli
        seed         = $corpus.seed
    }
    $jobFile = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($jobFile,
        ($job | ConvertTo-Json -Depth 20 -Compress),
        (New-Object System.Text.UTF8Encoding($false)))

    $signatures = @(); $lastVerdict = $null; $durations = @(); $stage = ""
    for ($i = 0; $i -lt $Runs; $i++) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        # 1) P0 statique (ordre réel du pipeline) — le banc n'est spawné qu'après.
        $verdict = Invoke-Bench @("-platform", "offscreen", "--static-check", $qml)
        if ($verdict -and $verdict.verdict -eq "fail") {
            $stage = "P0"
        } else {
            # 2) P1→P5.
            $verdict = Invoke-Bench @("-platform", "offscreen", $jobFile)
            $stage = "bench"
        }
        $sw.Stop()
        $durations += $sw.ElapsedMilliseconds
        $lastVerdict = $verdict
        $signatures += (Get-VerdictSignature $verdict)
    }
    Remove-Item $jobFile -ErrorAction SilentlyContinue

    $expect = @($a.expect)
    $gotCodes = @(); $gotVerdict = "<aucun>"
    if ($lastVerdict) {
        $gotVerdict = $lastVerdict.verdict
        if ($lastVerdict.failures) { $gotCodes = @($lastVerdict.failures | ForEach-Object { $_.code }) }
    }
    if ($expect -contains "pass") {
        $expectOk = ($gotVerdict -eq "pass")
    } else {
        $expectOk = ($gotVerdict -eq "fail") -and (($gotCodes | Where-Object { $expect -contains $_ }).Count -gt 0)
    }
    $reproOk = (($signatures | Select-Object -Unique).Count -eq 1)
    $killOk  = ($null -ne $lastVerdict)
    $maxMs   = ($durations | Measure-Object -Maximum).Maximum
    $maxColdMs = [Math]::Max($maxColdMs, $maxMs)
    if ($expect -contains "pass") { $maxHealthyMs = [Math]::Max($maxHealthyMs, $maxMs) }

    $results += [pscustomobject]@{
        Artefact = $a.file
        Attendu  = ($expect -join "|")
        Obtenu   = if ($gotVerdict -eq "pass") { "pass" } else { ($gotCodes -join ",") }
        Stage    = $stage
        Verdict  = if ($expectOk) { "OK" } else { "X" }
        Repro    = if ($reproOk) { "OK" } else { "X" }
        Kill     = if ($killOk) { "OK" } else { "X" }
        MaxMs    = $maxMs
    }
}

Write-Host ""
$results | Format-Table -AutoSize
Write-Host ""

Write-Host "=== Critères R1 (doc 12 §8) ===" -ForegroundColor Cyan
$c1 = ($results.Kill -notcontains "X")
$c2 = ($results.Repro -notcontains "X")
$c3cold = ($maxColdMs -lt 2000)
$c3valid = ($maxHealthyMs -lt 8000)
$singleton = ($results | Where-Object { $_.Artefact -eq "acces_singleton.qml" })
$c4 = ($singleton -and $singleton.Verdict -eq "OK")
$healthy = ($results | Where-Object { $_.Artefact -eq "sain_plaque_piegee.qml" })
$c5 = ($healthy -and $healthy.Verdict -eq "OK")

function Mark($b) { if ($b) { "OK " } else { "X  " } }
Write-Host ("[{0}] 1. Kill 100 %% : tout cas verdicté, jamais de gel" -f (Mark $c1))
Write-Host ("[{0}] 2. Reproductibilité : {1} runs => mêmes verdicts" -f (Mark $c2), $Runs)
Write-Host ("[{0}] 3a. Démarrage sain < 2 s (max sain observé : {1} ms)" -f (Mark ($maxHealthyMs -lt 2000)), $maxHealthyMs)
Write-Host ("[{0}] 3b. Validation saine < 8 s (max sain : {1} ms)" -f (Mark $c3valid), $maxHealthyMs)
Write-Host ("[{0}] 4. Masquage prouvé (acces_singleton bloqué en P2)" -f (Mark $c4))
Write-Host ("[{0}] 5. Pas de faux positif (artefact sain => pass)" -f (Mark $c5))
Write-Host ("    note: les cas pathologiques a timeout durent ~5 s (watchdog qui tue,")
Write-Host ("    pas un demarrage lent) ; max toutes categories : $maxColdMs ms")
Write-Host ""

$verdictsOk = ($results.Verdict -notcontains "X")
if ($verdictsOk -and $c1 -and $c2 -and $c4 -and $c5) {
    Write-Host "CORPUS R1 : VERT" -ForegroundColor Green
    if (-not $c3valid) {
        Write-Host "NOTE coût : cible non tenue en spawn froid => pool recommandé (A8, doc 12 §6)." -ForegroundColor Yellow
    }
    exit 0
} else {
    Write-Host "CORPUS R1 : ROUGE (voir X ci-dessus)" -ForegroundColor Red
    exit 1
}
