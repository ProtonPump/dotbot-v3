<#
.SYNOPSIS
Imports ADRs from a project proposal repository into dotbot Decision records.

.DESCRIPTION
Phase 0a script. Reads ADR markdown files from the proposal repo, parses their
structured fields, and creates dotbot Decision JSON files. Builds an ADR-to-Decision
ID mapping table for cross-reference resolution.

Only Accepted, Deprecated, and Superseded ADRs are converted to Decisions.
Proposed, Open, and Conflict ADRs are stored as unresolved questions for Phase 0c.

.PARAMETER BotRoot
Path to the .bot directory.

.PARAMETER Model
Claude model name (unused — this is a deterministic script phase).

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
Import-Module "$BotRoot\systems\runtime\modules\DotBotTheme.psm1" -Force
$t = Get-DotBotTheme

. "$BotRoot\systems\runtime\modules\ui-rendering.ps1"

if ($ProcessId) {
    $env:DOTBOT_PROCESS_ID = $ProcessId
}

function Write-ImportActivity {
    param([string]$Message)
    try { Write-ActivityLog -Type "text" -Message $Message } catch {}
    Write-Status $Message -Type Info
}

# --- Resolve proposal path from kickstart prompt ---
$productDir = Join-Path $BotRoot "workspace\product"

# The kickstart prompt is saved by ProductAPI to .control/launchers/kickstart-prompt.txt
$promptFile = Join-Path $BotRoot ".control\launchers\kickstart-prompt.txt"
$proposalPath = $null
if (Test-Path $promptFile) {
    $proposalPath = (Get-Content $promptFile -Raw).Trim().Trim('"').Trim("'")
}

if (-not $proposalPath) {
    throw "Could not find proposal path. The kickstart prompt file was not found at: $promptFile"
}

# Normalise path separators
$proposalPath = $proposalPath -replace '\\', '/'
if ($proposalPath -match '^[A-Za-z]:') {
    # Windows absolute path — keep as-is but normalise
    $proposalPath = $proposalPath -replace '/', '\'
}

if (-not (Test-Path $proposalPath)) {
    throw "Proposal path does not exist: $proposalPath"
}

# Validate expected structure
$adrDir = Join-Path $proposalPath "adr"
if (-not (Test-Path $adrDir)) {
    throw "No adr/ directory found in proposal repo: $proposalPath"
}

Write-Header "Import Decisions from Proposal ADRs"
Write-ImportActivity "Proposal repo: $proposalPath"

# --- Store proposal source for subsequent phases ---
$proposalSourcePath = Join-Path $productDir "proposal-source.json"
if (-not (Test-Path $productDir)) { New-Item -ItemType Directory -Force -Path $productDir | Out-Null }
@{
    proposal_path = $proposalPath
    imported_at = (Get-Date).ToUniversalTime().ToString("o")
} | ConvertTo-Json | Set-Content -Path $proposalSourcePath -Encoding UTF8

# --- Parse ADR markdown ---
function ConvertFrom-AdrMarkdown {
    param([string]$FilePath)

    $content = Get-Content $FilePath -Raw -Encoding UTF8
    $adr = @{
        file = (Split-Path $FilePath -Leaf)
        title = ''
        date = ''
        status = ''
        deciders = @()
        context = ''
        decision_drivers = ''
        options_considered = @()
        decision = ''
        consequences = ''
        change_log = ''
        adr_references = @()
    }

    # Extract title from first heading
    $titleMatch = [regex]::Match($content, '^#\s+ADR-\d{4}:\s*(.+)', [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if ($titleMatch.Success) {
        $adr.title = $titleMatch.Groups[1].Value.Trim()
    }

    # Extract ADR ID
    $idMatch = [regex]::Match($content, 'ADR-(\d{4})')
    if ($idMatch.Success) {
        $adr.adr_id = "ADR-$($idMatch.Groups[1].Value)"
    }

    # Extract date
    $dateMatch = [regex]::Match($content, '\*\*Date:\*\*\s*(.+)')
    if ($dateMatch.Success) {
        $adr.date = $dateMatch.Groups[1].Value.Trim()
    }

    # Extract status
    $statusMatch = [regex]::Match($content, '\*\*Status:\*\*\s*(.+)')
    if ($statusMatch.Success) {
        $rawStatus = $statusMatch.Groups[1].Value.Trim()
        # Handle "Superseded by ADR-NNNN"
        if ($rawStatus -match '^Superseded\s+by\s+(ADR-\d{4})') {
            $adr.status = 'Superseded'
            $adr.superseded_by_adr = $Matches[1]
        } else {
            $adr.status = $rawStatus
        }
    }

    # Extract deciders
    $decidersMatch = [regex]::Match($content, '\*\*Deciders:\*\*\s*(.+)')
    if ($decidersMatch.Success) {
        $adr.deciders = @($decidersMatch.Groups[1].Value.Trim() -split ';\s*' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }

    # Extract sections by heading
    function Get-Section {
        param([string]$Content, [string]$Heading)
        $pattern = "(?m)^##\s+$Heading\s*`n([\s\S]*?)(?=^##\s|\z)"
        $match = [regex]::Match($Content, $pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
        if ($match.Success) {
            return $match.Groups[1].Value.Trim()
        }
        return ''
    }

    $adr.context = Get-Section -Content $content -Heading 'Context'
    $adr.decision_drivers = Get-Section -Content $content -Heading 'Decision Drivers'
    $adr.decision = Get-Section -Content $content -Heading 'Decision'
    $adr.consequences = Get-Section -Content $content -Heading 'Consequences'
    $adr.change_log = Get-Section -Content $content -Heading 'Change Log'

    # Extract options considered
    $optionsSection = Get-Section -Content $content -Heading 'Options Considered'
    if ($optionsSection) {
        $optionMatches = [regex]::Matches($optionsSection, '###\s+(?:Option\s+\w+:\s*)?(.+?)(?=\n###\s|\z)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        foreach ($om in $optionMatches) {
            $optName = ($om.Groups[1].Value -split "`n")[0].Trim()
            $optBody = $om.Groups[1].Value.Trim()
            # Extract pros and cons
            $prosMatch = [regex]::Match($optBody, '\*\*Pros:\*\*\s*(.+?)(?=\*\*Cons|\z)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
            $consMatch = [regex]::Match($optBody, '\*\*Cons:\*\*\s*(.+?)(?=\n###|\z)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
            $adr.options_considered += @{
                name = $optName
                pros = if ($prosMatch.Success) { $prosMatch.Groups[1].Value.Trim() } else { '' }
                cons = if ($consMatch.Success) { $consMatch.Groups[1].Value.Trim() } else { '' }
            }
        }
    }

    # Find all ADR cross-references
    $refMatches = [regex]::Matches($content, 'ADR-(\d{4})')
    $refs = @($refMatches | ForEach-Object { "ADR-$($_.Groups[1].Value)" } | Select-Object -Unique)
    # Exclude self-reference
    $adr.adr_references = @($refs | Where-Object { $_ -ne $adr.adr_id })

    return $adr
}

# --- Collect ADR files ---
$adrStatusDirs = @{
    'accepted' = 'Accepted'
    'proposed' = 'Proposed'
    'gap' = 'Open'
    'deprecated' = 'Deprecated'
}

$allAdrs = @()
foreach ($dirName in $adrStatusDirs.Keys) {
    $dirPath = Join-Path $adrDir $dirName
    if (-not (Test-Path $dirPath)) { continue }

    $files = @(Get-ChildItem -Path $dirPath -Filter "*.md" -File |
        Where-Object { $_.Name -ne 'template.md' })

    foreach ($f in $files) {
        $parsed = ConvertFrom-AdrMarkdown -FilePath $f.FullName
        # Use folder to determine status if not parsed correctly
        if (-not $parsed.status -or $parsed.status -eq '') {
            $parsed.status = $adrStatusDirs[$dirName]
        }
        $parsed.source_folder = $dirName
        $allAdrs += $parsed
    }
}

Write-ImportActivity "Found $($allAdrs.Count) ADRs across $(($adrStatusDirs.Keys | Where-Object { Test-Path (Join-Path $adrDir $_) }).Count) folders"

# --- Create Decision records ---
$decisionsBaseDir = Join-Path $BotRoot "workspace\decisions"
$adrToDecMap = @{}  # ADR-NNNN -> dec-XXXXXXXX
$createdCount = @{ accepted = 0; deprecated = 0; superseded = 0; skipped = 0 }
$unresolvedAdrs = @()

foreach ($adr in $allAdrs) {
    $adrId = $adr.adr_id
    if (-not $adrId) { continue }

    $normalizedStatus = switch ($adr.status) {
        'Accepted' { 'accepted' }
        'Deprecated' { 'deprecated' }
        { $_ -match '^Superseded' } { 'superseded' }
        'Proposed' { 'unresolved' }
        'Open' { 'unresolved' }
        'Conflict' { 'unresolved' }
        'Rejected' { 'accepted' }  # Rejected -> negative accepted decision
        default { 'unresolved' }
    }

    if ($normalizedStatus -eq 'unresolved') {
        $unresolvedAdrs += $adr
        $createdCount.skipped++
        continue
    }

    # Generate decision ID
    $decId = "dec-" + ([guid]::NewGuid().ToString('N').Substring(0, 8))
    $adrToDecMap[$adrId] = $decId

    # Build context (merge decision drivers if present)
    $contextText = $adr.context
    if ($adr.decision_drivers) {
        $contextText += "`n`nDecision Drivers:`n$($adr.decision_drivers)"
    }

    # Build decision text (for Rejected: rewrite as negative)
    $decisionText = $adr.decision
    if ($adr.status -eq 'Rejected') {
        $decisionText = "REJECTED: $($adr.decision) — This approach was explicitly rejected and must not be implemented."
    }

    # Build alternatives_considered from non-chosen options
    $alternatives = @()
    foreach ($opt in $adr.options_considered) {
        # Check if this option was the chosen one (appears in the decision text)
        $isChosen = $decisionText -match [regex]::Escape($opt.name)
        if (-not $isChosen) {
            $alternatives += @{
                option = $opt.name
                reason_rejected = $opt.cons
            }
        }
    }

    # Infer type
    $type = 'technical'
    $titleLower = $adr.title.ToLower()
    if ($titleLower -match 'business|commercial|pricing|subscription|budget|revenue|market') {
        $type = 'business'
    } elseif ($titleLower -match 'architecture|infrastructure|platform|database|deployment|cluster|api') {
        $type = 'architecture'
    } elseif ($titleLower -match 'process|workflow|governance|compliance|gdpr|approval') {
        $type = 'process'
    }

    # Infer impact
    $impact = 'medium'
    if ($titleLower -match 'mandatory|binding|critical|core|fundamental') {
        $impact = 'high'
    } elseif ($titleLower -match 'minor|optional|cosmetic') {
        $impact = 'low'
    }

    # Build tags
    $tags = @("proposal-import", $adrId.ToLower())

    # Build slug
    $slug = ($adr.title -replace '[^\w\s-]', '' -replace '\s+', '-').ToLower()
    if ($slug.Length -gt 60) { $slug = $slug.Substring(0, 60).TrimEnd('-') }

    # Determine target status for file storage
    $fileStatus = if ($normalizedStatus -eq 'superseded') { 'superseded' }
                  elseif ($normalizedStatus -eq 'deprecated') { 'deprecated' }
                  else { 'accepted' }

    $targetDir = Join-Path $decisionsBaseDir $fileStatus
    if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Force -Path $targetDir | Out-Null }

    $dec = @{
        id = $decId
        title = $adr.title
        type = $type
        status = $fileStatus
        date = if ($adr.date) { $adr.date } else { (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd") }
        context = $contextText
        decision = $decisionText
        consequences = $adr.consequences
        alternatives_considered = $alternatives
        stakeholders = $adr.deciders
        related_task_ids = @()
        related_decision_ids = @()  # Populated in second pass
        supersedes = $null
        superseded_by = $null
        tags = $tags
        impact = $impact
        deprecation_reason = if ($normalizedStatus -eq 'deprecated') { "Deprecated in project proposal" } else { $null }
    }

    # Handle superseded
    if ($normalizedStatus -eq 'superseded' -and $adr.superseded_by_adr) {
        $dec.superseded_by = $adr.superseded_by_adr  # Will be resolved to dec-ID in second pass
    }

    $fileName = "$decId-$slug.json"
    $filePath = Join-Path $targetDir $fileName
    $dec | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Encoding UTF8

    $createdCount[$normalizedStatus]++
    Write-ImportActivity "Created $fileStatus decision $decId from ${adrId}: $($adr.title)"
}

# --- Second pass: resolve cross-references ---
Write-ImportActivity "Resolving ADR cross-references..."

$allDecFiles = @()
foreach ($statusDir in @('accepted', 'proposed', 'deprecated', 'superseded')) {
    $dirPath = Join-Path $decisionsBaseDir $statusDir
    if (Test-Path $dirPath) {
        $allDecFiles += @(Get-ChildItem -Path $dirPath -Filter "*.json" -File)
    }
}

foreach ($decFile in $allDecFiles) {
    $dec = Get-Content $decFile.FullName -Raw | ConvertFrom-Json
    $updated = $false

    # Check if this decision has an ADR tag to find its original ADR references
    $originalAdrId = $dec.tags | Where-Object { $_ -match '^adr-\d{4}$' } | Select-Object -First 1
    if ($originalAdrId) {
        $originalAdr = $allAdrs | Where-Object { $_.adr_id -and $_.adr_id.ToLower() -eq $originalAdrId } | Select-Object -First 1
        if ($originalAdr -and $originalAdr.adr_references) {
            $resolvedRefs = @()
            foreach ($ref in $originalAdr.adr_references) {
                if ($adrToDecMap.ContainsKey($ref)) {
                    $resolvedRefs += $adrToDecMap[$ref]
                }
            }
            if ($resolvedRefs.Count -gt 0) {
                $dec.related_decision_ids = $resolvedRefs
                $updated = $true
            }
        }
    }

    # Resolve superseded_by from ADR ID to Decision ID
    if ($dec.superseded_by -and $dec.superseded_by -match '^ADR-') {
        if ($adrToDecMap.ContainsKey($dec.superseded_by)) {
            $dec.superseded_by = $adrToDecMap[$dec.superseded_by]
            $updated = $true
        }
    }

    if ($updated) {
        $dec | ConvertTo-Json -Depth 10 | Set-Content -Path $decFile.FullName -Encoding UTF8
    }
}

# --- Save mapping table ---
$mapPath = Join-Path $productDir "adr-decision-map.json"
$adrToDecMap | ConvertTo-Json -Depth 5 | Set-Content -Path $mapPath -Encoding UTF8
Write-ImportActivity "ADR-to-Decision mapping saved: $mapPath"

# --- Save unresolved ADRs for Phase 0c interview ---
if ($unresolvedAdrs.Count -gt 0) {
    $unresolvedPath = Join-Path $productDir "unresolved-adrs.json"
    $unresolvedData = @{
        generated_at = (Get-Date).ToUniversalTime().ToString("o")
        count = $unresolvedAdrs.Count
        adrs = @($unresolvedAdrs | ForEach-Object {
            @{
                adr_id = $_.adr_id
                title = $_.title
                status = $_.status
                context = $_.context
                decision_drivers = $_.decision_drivers
                options_considered = $_.options_considered
                decision = $_.decision
                consequences = $_.consequences
            }
        })
    }
    $unresolvedData | ConvertTo-Json -Depth 10 | Set-Content -Path $unresolvedPath -Encoding UTF8
    Write-ImportActivity "Saved $($unresolvedAdrs.Count) unresolved ADRs for interview phase"
}

# --- Summary ---
Write-Header "Import Complete"
Write-ImportActivity "Decisions created: $($createdCount.accepted) accepted, $($createdCount.deprecated) deprecated, $($createdCount.superseded) superseded"
Write-ImportActivity "Unresolved ADRs (for interview): $($createdCount.skipped)"
Write-ImportActivity "Total ADRs processed: $($allAdrs.Count)"
