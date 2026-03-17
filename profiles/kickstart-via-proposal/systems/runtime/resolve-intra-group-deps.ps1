<#
.SYNOPSIS
Resolves intra-group task dependencies by invoking Claude once per task group.

.DESCRIPTION
Phase 3a orchestrator. Reads task-groups.json, iterates through each group,
collects all tasks assigned to that group, and invokes Claude to set dependencies
between tasks within the same group.

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

function Write-DepActivity {
    param([string]$Message)
    try { Write-ActivityLog -Type "text" -Message $Message } catch {}
    Write-Status $Message -Type Info
}

# --- Load context ---
$productDir = Join-Path $BotRoot "workspace\product"
$todoDir = Join-Path $BotRoot "workspace\tasks\todo"
$templatePath = Join-Path $BotRoot "prompts\workflows\03c-resolve-intra-deps.md"

# Read task groups
$groupsPath = Join-Path $productDir "task-groups.json"
if (-not (Test-Path $groupsPath)) {
    throw "task-groups.json not found. Phase 1 must run first."
}
$manifest = Get-Content $groupsPath -Raw | ConvertFrom-Json
$groups = @($manifest.groups)

# Read template
if (-not (Test-Path $templatePath)) {
    throw "Template not found: $templatePath"
}
$template = Get-Content $templatePath -Raw

# Load all tasks from todo directory
if (-not (Test-Path $todoDir)) {
    throw "No tasks found in $todoDir. Phase 2 must run first."
}

$allTasks = @()
$taskFiles = @(Get-ChildItem -Path $todoDir -Filter "*.json" -File)
foreach ($tf in $taskFiles) {
    try {
        $taskData = Get-Content $tf.FullName -Raw | ConvertFrom-Json
        $allTasks += @{
            id = $taskData.id
            name = $taskData.name
            description = $taskData.description
            group_id = $taskData.group_id
            priority = $taskData.priority
            acceptance_criteria = $taskData.acceptance_criteria
            source_stories = $taskData.source_stories
            file_path = $tf.FullName
        }
    } catch {}
}

Write-Header "Resolve Intra-Group Dependencies"
Write-DepActivity "Total tasks: $($allTasks.Count) across $($groups.Count) groups"

# --- Process each group ---
$totalDepsAdded = 0

foreach ($group in ($groups | Sort-Object { $_.order })) {
    $groupTasks = @($allTasks | Where-Object { $_.group_id -eq $group.id })

    if ($groupTasks.Count -le 1) {
        Write-DepActivity "Group '$($group.name)': $($groupTasks.Count) task(s) — skipping (no dependencies possible)"
        continue
    }

    Write-Header "Group: $($group.name)"
    Write-DepActivity "Resolving dependencies for $($groupTasks.Count) tasks in '$($group.name)'"

    # Build tasks content for template
    $tasksContent = ($groupTasks | ForEach-Object {
        $ac = if ($_.acceptance_criteria) { ($_.acceptance_criteria -join "; ") } else { "(none)" }
        $ss = if ($_.source_stories) { ($_.source_stories -join ", ") } else { "(none)" }
        "- **$($_.id): $($_.name)** (priority $($_.priority))`n  Description: $($_.description)`n  Acceptance criteria: $ac`n  Source stories: $ss"
    }) -join "`n`n"

    # Substitute template variables
    $prompt = $template
    $prompt = $prompt -replace '\{\{GROUP_NAME\}\}', $group.name
    $prompt = $prompt -replace '\{\{TASKS_CONTENT\}\}', $tasksContent

    # Invoke provider
    $sessionId = New-ProviderSession
    try {
        Invoke-ProviderStream -Prompt $prompt -Model $Model -SessionId $sessionId -PersistSession:$false
    } catch {
        Write-DepActivity "Error resolving dependencies for group '$($group.name)': $($_.Exception.Message)"
        Write-Status "Failed to resolve deps: $($group.name)" -Type Error
        continue
    }

    Write-DepActivity "Group '$($group.name)' dependencies resolved"

    # Brief pause between groups
    if ($group -ne ($groups | Sort-Object { $_.order })[-1]) {
        Start-Sleep -Seconds 2
    }

    # Check stop signal between groups
    # TODO: Replace with Test-ProcessStopSignal once it is exported from a shared module
    #       (currently defined inline in launch-process.ps1 and not importable)
    if ($ProcessId) {
        $stopFile = Join-Path $BotRoot ".control\processes\$ProcessId.stop"
        if (Test-Path $stopFile) {
            Write-DepActivity "Stop signal received — halting dependency resolution"
            break
        }
    }
}

# --- Summary ---
Write-Header "Intra-Group Dependency Resolution Complete"
Write-DepActivity "Processed $($groups.Count) groups with $($allTasks.Count) total tasks"
