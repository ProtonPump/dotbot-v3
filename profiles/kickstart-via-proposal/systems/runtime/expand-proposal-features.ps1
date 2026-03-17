<#
.SYNOPSIS
Creates implementation tasks by iterating through each proposal feature.

.DESCRIPTION
Phase 2 orchestrator. Reads proposal feature docs one at a time, loads the parent
EPIC and referenced decisions, then invokes Claude to create implementation tasks
assigned to the appropriate task groups.

.PARAMETER BotRoot
Path to the .bot directory.

.PARAMETER Model
Claude model name to use (e.g., claude-sonnet-4-6).

.PARAMETER ProcessId
Process registry ID for activity logging.
#>

param(
    [Parameter(Mandatory)]
    [string]$BotRoot,

    [Parameter(Mandatory)]
    [string]$Model,

    [string]$ProcessId
)

# --- Setup ---
Import-Module "$BotRoot\systems\runtime\ClaudeCLI\ClaudeCLI.psm1" -Force
Import-Module "$BotRoot\systems\runtime\ProviderCLI\ProviderCLI.psm1" -Force
Import-Module "$BotRoot\systems\runtime\modules\DotBotTheme.psm1" -Force
$t = Get-DotBotTheme

. "$BotRoot\systems\runtime\modules\ui-rendering.ps1"

if ($ProcessId) {
    $env:DOTBOT_PROCESS_ID = $ProcessId
}

function Write-FeatureActivity {
    param([string]$Message)
    try { Write-ActivityLog -Type "text" -Message $Message } catch {}
    Write-Status $Message -Type Info
}

# --- Load context ---
$productDir = Join-Path $BotRoot "workspace\product"
$todoDir = Join-Path $BotRoot "workspace\tasks\todo"
$templatePath = Join-Path $BotRoot "prompts\workflows\03b-expand-proposal-feature.md"

# Read proposal source
$proposalSourcePath = Join-Path $productDir "proposal-source.json"
if (-not (Test-Path $proposalSourcePath)) {
    throw "proposal-source.json not found. Phase 0a must run first."
}
$proposalSource = Get-Content $proposalSourcePath -Raw | ConvertFrom-Json
$proposalPath = $proposalSource.proposal_path

# Read ADR-Decision mapping
$mapPath = Join-Path $productDir "adr-decision-map.json"
$adrToDecMap = @{}
if (Test-Path $mapPath) {
    $mapData = Get-Content $mapPath -Raw | ConvertFrom-Json
    foreach ($prop in $mapData.PSObject.Properties) {
        $adrToDecMap[$prop.Name] = $prop.Value
    }
}

# Read task groups
$groupsPath = Join-Path $productDir "task-groups.json"
if (-not (Test-Path $groupsPath)) {
    throw "task-groups.json not found. Phase 1 must run first."
}
$manifest = Get-Content $groupsPath -Raw | ConvertFrom-Json
$groups = @($manifest.groups)

# Task groups path for template substitution (LLM reads the file directly)
$groupsFilePath = $groupsPath

# Read template
if (-not (Test-Path $templatePath)) {
    throw "Template not found: $templatePath"
}
$template = Get-Content $templatePath -Raw

# Find latest architecture doc
$archDir = Join-Path $proposalPath "architecture"
$archPath = ""
if (Test-Path $archDir) {
    $archFiles = @(Get-ChildItem -Path $archDir -Filter "arch-*-v*.md" -File | Sort-Object Name)
    if ($archFiles.Count -gt 0) {
        $archPath = $archFiles[-1].FullName
    }
}

# --- Discover all features ---
$featuresDir = Join-Path $proposalPath "backlog\features"
$epicsDir = Join-Path $proposalPath "backlog\epics"

if (-not (Test-Path $featuresDir)) {
    throw "No backlog/features/ directory found in proposal repo: $proposalPath"
}

# Get all feature files, excluding superseded
$featureFiles = @(Get-ChildItem -Path $featuresDir -Filter "F-*.md" -File |
    Where-Object { $_.DirectoryName -notmatch 'superseded' } |
    Sort-Object Name)

Write-Header "Create Tasks from Proposal Features"
Write-FeatureActivity "Found $($featureFiles.Count) features to process"
Write-FeatureActivity "Task groups available: $($groups.Count)"

# --- Process each feature ---
$totalTasksCreated = 0
$skippedFeatures = @()
$processedFeatures = @()

foreach ($featureFile in $featureFiles) {
    $featureFileName = $featureFile.Name
    # Extract feature ID (e.g., F-02.02)
    $featureIdMatch = [regex]::Match($featureFileName, '^(F-\d+\.\d+)')
    $featureId = if ($featureIdMatch.Success) { $featureIdMatch.Groups[1].Value } else { $featureFileName }

    # Extract EPIC number to find parent EPIC
    $epicNumMatch = [regex]::Match($featureId, 'F-(\d+)\.')
    $epicNum = if ($epicNumMatch.Success) { $epicNumMatch.Groups[1].Value } else { '00' }

    Write-Header "Feature: $featureId"
    Write-FeatureActivity "Processing feature: $featureId ($featureFileName)"

    # Read feature content for title extraction only
    $featureContent = Get-Content $featureFile.FullName -Raw -Encoding UTF8

    # Extract feature title from first heading
    $titleMatch = [regex]::Match($featureContent, '^#\s+(.+)', [System.Text.RegularExpressions.RegexOptions]::Multiline)
    $featureTitle = if ($titleMatch.Success) { $titleMatch.Groups[1].Value.Trim() } else { $featureId }

    # Find parent EPIC file path
    $epicPath = "(No parent EPIC found)"
    if (Test-Path $epicsDir) {
        $epicFiles = @(Get-ChildItem -Path $epicsDir -Filter "E-$epicNum-*.md" -File)
        if ($epicFiles.Count -gt 0) {
            $epicPath = "Read: $($epicFiles[0].FullName)"
        }
    }

    # Find referenced ADRs and resolve to Decision file paths
    $adrRefs = @([regex]::Matches($featureContent, 'ADR-(\d{4})') | ForEach-Object { "ADR-$($_.Groups[1].Value)" } | Select-Object -Unique)
    $decisionIds = @($adrRefs | ForEach-Object { if ($adrToDecMap.ContainsKey($_)) { $adrToDecMap[$_] } } | Where-Object { $_ })

    # Build decision file paths for referenced decisions
    $decisionsPaths = "(No applicable decisions)"
    if ($decisionIds.Count -gt 0) {
        $decPathList = @()
        $decisionsBaseDir = Join-Path $BotRoot "workspace\decisions"
        foreach ($decId in $decisionIds) {
            foreach ($statusDir in @('accepted', 'proposed', 'deprecated', 'superseded')) {
                $dirPath = Join-Path $decisionsBaseDir $statusDir
                if (-not (Test-Path $dirPath)) { continue }
                $decFiles = @(Get-ChildItem -LiteralPath $dirPath -Filter "*.json" -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -like "$decId-*.json" })
                if ($decFiles.Count -gt 0) {
                    $decPathList += "- Read: $($decFiles[0].FullName)"
                    break
                }
            }
        }
        if ($decPathList.Count -gt 0) {
            $decisionsPaths = $decPathList -join "`n"
        }
    }

    # Build architecture path reference
    $archRef = if ($archPath) { "Read: $archPath" } else { "(No architecture document found)" }

    # Substitute template variables — use file paths, not content
    $prompt = $template
    $prompt = $prompt -replace '\{\{FEATURE_ID\}\}', $featureId
    $prompt = $prompt -replace '\{\{FEATURE_TITLE\}\}', $featureTitle
    $prompt = $prompt -replace '\{\{FEATURE_PATH\}\}', "Read: $($featureFile.FullName)"
    $prompt = $prompt -replace '\{\{EPIC_PATH\}\}', $epicPath
    $prompt = $prompt -replace '\{\{DECISIONS_PATHS\}\}', $decisionsPaths
    $prompt = $prompt -replace '\{\{TASK_GROUPS_PATH\}\}', "Read: $groupsFilePath"
    $prompt = $prompt -replace '\{\{ARCHITECTURE_PATH\}\}', $archRef

    # Snapshot todo directory before expansion
    $beforeFiles = @()
    if (Test-Path $todoDir) {
        $beforeFiles = @(Get-ChildItem -Path $todoDir -Filter "*.json" | ForEach-Object { $_.FullName })
    }

    # Invoke provider
    $sessionId = New-ProviderSession
    try {
        Invoke-ProviderStream -Prompt $prompt -Model $Model -SessionId $sessionId -PersistSession:$false
    } catch {
        Write-FeatureActivity "Error processing feature $featureId : $($_.Exception.Message)"
        Write-Status "Failed to process feature: $featureId" -Type Error
        continue
    }

    # Discover newly created tasks
    $afterFiles = @()
    if (Test-Path $todoDir) {
        $afterFiles = @(Get-ChildItem -Path $todoDir -Filter "*.json" | ForEach-Object { $_.FullName })
    }
    $newFiles = @($afterFiles | Where-Object { $_ -notin $beforeFiles })

    if ($newFiles.Count -eq 0) {
        $skippedFeatures += @{ id = $featureId; title = $featureTitle }
        Write-FeatureActivity "Feature $featureId skipped (non-implementation or zero tasks)"
    } else {
        $newTasks = @()
        foreach ($f in $newFiles) {
            try {
                $taskData = Get-Content $f -Raw | ConvertFrom-Json
                $newTasks += @{ id = $taskData.id; name = $taskData.name; group_id = $taskData.group_id }
            } catch {}
        }
        $processedFeatures += @{ id = $featureId; title = $featureTitle; task_count = $newTasks.Count }
        $totalTasksCreated += $newTasks.Count
        Write-FeatureActivity "Feature ${featureId}: $($newTasks.Count) tasks created"
    }

    # Brief pause between features to avoid rate limits
    if ($featureFile -ne $featureFiles[-1]) {
        Start-Sleep -Seconds 2
    }

    # Check stop signal between features
    # TODO: Replace with Test-ProcessStopSignal once it is exported from a shared module
    #       (currently defined inline in launch-process.ps1 and not importable)
    if ($ProcessId) {
        $stopFile = Join-Path $BotRoot ".control\processes\$ProcessId.stop"
        if (Test-Path $stopFile) {
            Write-FeatureActivity "Stop signal received — halting feature expansion"
            break
        }
    }
}

# --- Generate summary ---
Write-Header "Feature Expansion Complete"

$summaryPath = Join-Path $productDir "feature-expansion-summary.md"
$summaryLines = @()
$summaryLines += "# Feature Expansion Summary"
$summaryLines += ""
$summaryLines += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$summaryLines += "**Total features processed:** $($featureFiles.Count)"
$summaryLines += "**Tasks created:** $totalTasksCreated"
$summaryLines += "**Features skipped:** $($skippedFeatures.Count)"
$summaryLines += ""
$summaryLines += "## Processed Features"
$summaryLines += ""
foreach ($pf in $processedFeatures) {
    $summaryLines += "- **$($pf.id):** $($pf.title) — $($pf.task_count) tasks"
}
$summaryLines += ""
$summaryLines += "## Skipped Features (Non-Implementation)"
$summaryLines += ""
foreach ($sf in $skippedFeatures) {
    $summaryLines += "- **$($sf.id):** $($sf.title)"
}

$summaryLines -join "`n" | Set-Content -Path $summaryPath -Encoding UTF8

Write-FeatureActivity "Summary written to: $summaryPath"
Write-FeatureActivity "Total: $totalTasksCreated tasks created from $($processedFeatures.Count) features ($($skippedFeatures.Count) skipped)"
