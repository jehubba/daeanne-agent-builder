#Requires -Version 5.1
<#
.SYNOPSIS
    TDD test suite for the handoff cycle feature (specs/001-handoff-cycle).

    Tests verify AGENT.md structure, contract compliance, and behavioral
    properties by parsing the Markdown source. These are specification tests
    for a prompt engineering project -- the "code" is Markdown + embedded
    PowerShell that the Dispatcher interprets at runtime.

.DESCRIPTION
    Task IDs from specs/001-handoff-cycle/tasks.md:
      T003  - Seam test: Step 5 substep structure (5a-5e)
      T005  - Contract test: Step 5b dispatch prompt matches Contract 1
      T006  - Contract test: Step 5c callback parsing matches Contract 1
      T010  - Contract test: Step 5d dispatch prompt matches Contract 3
      T011  - Integration test: review-fix loop terminates after 2 cycles
      T015  - Integration test: Dispatcher failure triggers inline fallback
      T019  - Contract test: build-review.md matches Contract 4 schema
      T022  - Contract test: Step 4a template includes Integration Points

.NOTES
    Run: powershell -File tests/Test-HandoffCycle.ps1
    Exit code 0 = all pass, 1 = failures exist.

    All new-feature tests are currently expected to FAIL (RED phase).
    The coding agent implements AGENT.md changes to make them GREEN.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Test infrastructure ---------------------------------------------------

$script:AgentMdPath = Join-Path (Join-Path $PSScriptRoot '..') 'AGENT.md'

$script:Results = @()
$script:PassCount = 0
$script:FailCount = 0

function Assert-True {
    param(
        [Parameter(Mandatory)] [bool]   $Condition,
        [Parameter(Mandatory)] [string] $TestName,
        [string] $FailMessage = 'Assertion failed'
    )
    if ($Condition) {
        $script:Results += [PSCustomObject]@{ Test = $TestName; Result = 'PASS'; Detail = '' }
        $script:PassCount++
    }
    else {
        $script:Results += [PSCustomObject]@{ Test = $TestName; Result = 'FAIL'; Detail = $FailMessage }
        $script:FailCount++
    }
}

function Get-AgentMdContent {
    if (-not (Test-Path $script:AgentMdPath)) {
        throw "AGENT.md not found at $script:AgentMdPath"
    }
    Get-Content $script:AgentMdPath -Raw -Encoding UTF8
}

function Get-AgentMdLines {
    if (-not (Test-Path $script:AgentMdPath)) {
        throw "AGENT.md not found at $script:AgentMdPath"
    }
    Get-Content $script:AgentMdPath -Encoding UTF8
}

# --- Characterization: capture current Step 5 inline eval ------------------
# These document the OLD behavior so we can verify it is preserved as fallback.

function Test-Characterization-Step5HasSelfEvalSection {
    $content = Get-AgentMdContent
    $hasStep5 = $content -match '(?m)^#{2,3}\s+Step\s+5'
    Assert-True $hasStep5 `
        'CHAR-001: AGENT.md has a Step 5 section' `
        'No Step 5 heading found -- the section being replaced must exist first'
}

function Test-Characterization-Step5Has7Criteria {
    $content = Get-AgentMdContent
    # The current Step 5 lists 7 numbered criteria
    $criteria = [regex]::Matches($content, '(?m)^\d+\.\s+\*\*\w+')
    $hasCriteria = $criteria.Count -ge 7
    $msg = 'Found ' + $criteria.Count.ToString() + ' criteria, expected >= 7 -- characterizing the inline eval to preserve as fallback'
    Assert-True $hasCriteria `
        'CHAR-002: Current Step 5 contains at least 7 evaluation criteria' `
        $msg
}

function Test-Characterization-Step5HasScoreThreshold {
    $content = Get-AgentMdContent
    $hasThreshold = $content -match 'score\s*<\s*4/7|If score < 4/7|score 4.6/7|4/7'
    Assert-True $hasThreshold `
        'CHAR-003: Current Step 5 references the 4/7 score threshold' `
        'No 4/7 threshold found -- characterizing the pass/fail logic'
}

# --- T003: Seam test -- Step 5 substep structure (5a-5e) -------------------

function Test-T003-Step5HasNewHeading {
    $content = Get-AgentMdContent
    $hasHeading = $content -match '(?mi)^#{2,3}\s+Step\s+5\s*[\-]+\s*Quality\s+review\s*\(handoff\s+cycle\)'
    if (-not $hasHeading) {
        # Also accept em-dash variant
        $hasHeading = $content -match '(?mi)Step\s+5.*Quality\s+review.*handoff\s+cycle'
    }
    Assert-True $hasHeading `
        'T003-A: Step 5 heading is "Step 5 -- Quality review (handoff cycle)"' `
        'Step 5 heading does not match expected rename. Current heading does not contain "Quality review (handoff cycle)"'
}

function Test-T003-Step5aExists {
    $content = Get-AgentMdContent
    $has5a = $content -match '(?mi)^#{3,4}\s+Step\s+5a'
    Assert-True $has5a `
        'T003-B: Substep 5a heading exists' `
        'No ### Step 5a heading found in AGENT.md'
}

function Test-T003-Step5bExists {
    $content = Get-AgentMdContent
    $has5b = $content -match '(?mi)^#{3,4}\s+Step\s+5b'
    Assert-True $has5b `
        'T003-C: Substep 5b heading exists' `
        'No ### Step 5b heading found in AGENT.md'
}

function Test-T003-Step5cExists {
    $content = Get-AgentMdContent
    $has5c = $content -match '(?mi)^#{3,4}\s+Step\s+5c'
    Assert-True $has5c `
        'T003-D: Substep 5c heading exists' `
        'No ### Step 5c heading found in AGENT.md'
}

function Test-T003-Step5dExists {
    $content = Get-AgentMdContent
    $has5d = $content -match '(?mi)^#{3,4}\s+Step\s+5d'
    Assert-True $has5d `
        'T003-E: Substep 5d heading exists' `
        'No ### Step 5d heading found in AGENT.md'
}

function Test-T003-Step5eExists {
    $content = Get-AgentMdContent
    $has5e = $content -match '(?mi)^#{3,4}\s+Step\s+5e'
    Assert-True $has5e `
        'T003-F: Substep 5e heading exists' `
        'No ### Step 5e heading found in AGENT.md'
}

function Test-T003-SubstepsAreInOrder {
    $lines = Get-AgentMdLines
    $positions = @{}
    foreach ($sub in @('5a', '5b', '5c', '5d', '5e')) {
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match "(?i)^#{3,4}\s+Step\s+$sub") {
                $positions[$sub] = $i
                break
            }
        }
    }
    $allFound = $positions.Count -eq 5
    $inOrder = $false
    if ($allFound) {
        $inOrder = ($positions['5a'] -lt $positions['5b']) -and
        ($positions['5b'] -lt $positions['5c']) -and
        ($positions['5c'] -lt $positions['5d']) -and
        ($positions['5d'] -lt $positions['5e'])
    }
    $msg = 'Found ' + $positions.Count.ToString() + '/5 substeps'
    Assert-True $inOrder `
        'T003-G: Substeps 5a-5e appear in order' `
        $msg
}

# --- T005: Contract test -- Step 5b dispatch matches Contract 1 ------------

function Test-T005-Step5bHasDispatcherPost {
    $content = Get-AgentMdContent
    $hasUrl = $content -match '\$env:DISPATCHER_URL/tasks'
    $hasInvoke = $content -match 'Invoke-RestMethod'
    $hasPost = $hasUrl -and $hasInvoke
    Assert-True $hasPost `
        'T005-A: Step 5b contains POST to $env:DISPATCHER_URL/tasks' `
        'No Invoke-RestMethod call to $env:DISPATCHER_URL/tasks found for Code Gardener dispatch'
}

function Test-T005-DispatchPromptHasAnalysisOnly {
    $content = Get-AgentMdContent
    $hasMode = $content -match 'Analysis\s+Only'
    Assert-True $hasMode `
        'T005-B: Dispatch prompt includes "Analysis Only" mode' `
        'Contract 1 requires "Analysis Only" in the Code Gardener dispatch prompt'
}

function Test-T005-DispatchPromptHasAgentReviewer {
    $content = Get-AgentMdContent
    $hasSkill = $content -match 'agent-reviewer'
    Assert-True $hasSkill `
        'T005-C: Dispatch prompt references agent-reviewer skill' `
        'Contract 1 requires "agent-reviewer" in the dispatch prompt'
}

function Test-T005-DispatchHasParentTaskId {
    $content = Get-AgentMdContent
    $hasParent = $content -match 'parentTaskId.*TASK_ID'
    Assert-True $hasParent `
        'T005-D: Dispatch includes parentTaskId referencing $env:TASK_ID' `
        'Contract 1 requires parentTaskId linked to current task'
}

function Test-T005-DispatchHasTypeCode {
    $content = Get-AgentMdContent
    $hasType = $content -match 'type\s*=\s*"Code"'
    Assert-True $hasType `
        'T005-E: Dispatch body has type = "Code"' `
        'Contract 1 requires type field set to "Code"'
}

function Test-T005-SelfSuspendsAfterDispatch {
    $content = Get-AgentMdContent
    $hasAwait = $content -match '\$env:DISPATCHER_URL/tasks/.*await'
    $hasExit = $content -match 'exit\s+0'
    $both = $hasAwait -and $hasExit
    $msg = 'await found: ' + $hasAwait.ToString() + ', exit 0 found: ' + $hasExit.ToString() + ' -- Contract 2 requires both'
    Assert-True $both `
        'T005-F: Step 5b self-suspends via /await and exits 0' `
        $msg
}

# --- T006: Contract test -- Step 5c callback parsing matches Contract 1 ----

function Test-T006-ReadsCallbackJson {
    $content = Get-AgentMdContent
    $readsCallback = $content -match '\$env:output_path.*callbacks'
    Assert-True $readsCallback `
        'T006-A: Step 5c reads callback from $env:output_path/callbacks/' `
        'No reference to $env:output_path/callbacks/ for reading Code Gardener results'
}

function Test-T006-ParsesDimensionScores {
    $content = Get-AgentMdContent
    $parsesScores = $content -match 'Score.*\d+/5|\*\*Score\*\*'
    Assert-True $parsesScores `
        'T006-B: Step 5c parses dimension scores in "Score: N/5" format' `
        'Contract 1 requires parsing lines matching Score: N/5 or **Score**: N/5'
}

function Test-T006-IdentifiesCriticalFindings {
    $content = Get-AgentMdContent
    $hasCritical = $content -match 'score.*(<=|le)\s*2|critical.*<=?\s*2|<=?\s*2.*critical'
    Assert-True $hasCritical `
        'T006-C: Step 5c identifies scores <= 2 as critical findings' `
        'Contract 1 defines critical finding as any dimension scored <= 2'
}

function Test-T006-HasDecisionMatrix {
    $content = Get-AgentMdContent
    $hasDeliver = $content -match 'all.*>\s*2|no\s+critical'
    $hasFix = $content -match 'critical.*fix|dispatch.*fix|fix.*dispatch'
    $hasDegrade = $content -match 'failed.*fallback|fallback.*degrade|degraded.*inline'
    $anyDecision = $hasDeliver -and ($hasFix -or $hasDegrade)
    $msg = 'Deliver: ' + $hasDeliver.ToString() + ', Fix: ' + $hasFix.ToString() + ', Degrade: ' + $hasDegrade.ToString()
    Assert-True $anyDecision `
        'T006-D: Step 5c has decision matrix (deliver / fix / degrade paths)' `
        $msg
}

function Test-T006-Lists8Dimensions {
    $content = Get-AgentMdContent
    $dimensions = @(
        'Description Quality',
        'Frontmatter Correctness',
        'Tool Minimality',
        'Scope.{0,5}Focus',
        'Progressive Loading',
        'Cross-Reference Integrity',
        'Anti-Pattern Detection',
        'Cross-Scope Consistency'
    )
    $found = 0
    foreach ($dim in $dimensions) {
        if ($content -match $dim) { $found++ }
    }
    $msg = 'Found ' + $found.ToString() + '/8 dimension names. Contract 1 requires all 8 for score parsing.'
    Assert-True ($found -ge 8) `
        'T006-E: AGENT.md references all 8 agent-reviewer dimension names' `
        $msg
}

# --- T010: Contract test -- Step 5d dispatch matches Contract 3 ------------

function Test-T010-Step5dHasDispatcherPost {
    $content = Get-AgentMdContent
    $hasFixDispatch = $content -match 'Execute\s+fixes|Execute\s+Plan|fix.*critical.*findings'
    Assert-True $hasFixDispatch `
        'T010-A: Step 5d dispatch prompt references executing fixes' `
        'Contract 3 requires prompt to instruct Refactor Executor to fix critical findings'
}

function Test-T010-FixPromptReferencesIssues {
    $content = Get-AgentMdContent
    $hasIssueRef = $content -match 'open\s+issues|issues\s+labeled|agent-reviewer\s+findings'
    Assert-True $hasIssueRef `
        'T010-B: Step 5d prompt references open issues from agent-reviewer' `
        'Contract 3 requires prompt to direct fixer at open issues'
}

function Test-T010-FixPromptHasOneFixPerCommit {
    $content = Get-AgentMdContent
    $hasCommitRule = $content -match 'one\s+fix\s+per\s+commit'
    Assert-True $hasCommitRule `
        'T010-C: Step 5d prompt includes "one fix per commit" instruction' `
        'Contract 3 requires "one fix per commit" in the fixer prompt'
}

function Test-T010-FixPromptDoesNotCloseIssues {
    $content = Get-AgentMdContent
    $hasNoClose = $content -match 'Do\s+NOT\s+close\s+the\s+issues|do\s+not\s+close'
    Assert-True $hasNoClose `
        'T010-D: Step 5d prompt says "Do NOT close the issues"' `
        'Contract 3 requires explicit instruction not to close issues'
}

function Test-T010-FixDispatchHasParentTaskId {
    $content = Get-AgentMdContent
    $allMatches = [regex]::Matches($content, 'parentTaskId')
    $count = $allMatches.Count
    $hasMultiple = $count -ge 2
    $msg = 'Found ' + $count.ToString() + ' parentTaskId references, need >= 2 (review + fix)'
    Assert-True $hasMultiple `
        'T010-E: Fix dispatch also includes parentTaskId (at least 2 total in AGENT.md)' `
        $msg
}

# --- T011: Integration test -- loop terminates after 2 cycles --------------

function Test-T011-HasCycleCounter {
    $content = Get-AgentMdContent
    $hasCycleVar = $content -match 'cycle.*=\s*0|cycleNumber|cycle\s*count|cycle_count|\$cycle'
    Assert-True $hasCycleVar `
        'T011-A: AGENT.md tracks a cycle counter (initialized to 0)' `
        'FR-006 requires a bounded loop -- no cycle counter variable found'
}

function Test-T011-HasCycleCap {
    $content = Get-AgentMdContent
    $hasCap = $content -match 'cycle\s*<\s*2|cycle.*less than 2|at most 2|maximum.*2\s+cycle|2\s+cycle.*max'
    Assert-True $hasCap `
        'T011-B: AGENT.md enforces cycle cap of 2' `
        'FR-006 requires "at most 2 cycles" -- no cap check found'
}

function Test-T011-HasCapReachedOutcome {
    $content = Get-AgentMdContent
    $hasCaveat = $content -match 'cap.*reached|cap_reached|deliver.*caveat|caveats.*cap'
    Assert-True $hasCaveat `
        'T011-C: Cap reached leads to delivery with caveats' `
        'FR-006 requires delivery with caveats when cycle cap is hit'
}

function Test-T011-HasNoProgressDetection {
    $content = Get-AgentMdContent
    $hasNoProgress = $content -match 'no.progress|scores.*unchanged|scores.*same|no_progress|NO.PROGRESS'
    Assert-True $hasNoProgress `
        'T011-D: No-progress detection when scores are unchanged' `
        'FR-011 requires early termination when scores do not improve after a fix cycle'
}

function Test-T011-LoopReDispatchesCG {
    $content = Get-AgentMdContent
    $hasReDispatch = $content -match 're-dispatch|re.review|loop.*back.*5b|return.*Step\s+5b|re-run.*Code\s+Gardener|repeat.*review'
    Assert-True $hasReDispatch `
        'T011-E: After fix cycle, Code Gardener is re-dispatched for verification' `
        'FR-005 requires re-dispatch of Code Gardener after fixes'
}

# --- T015: Integration test -- Dispatcher failure triggers fallback --------

function Test-T015-Step5bHasTryCatch {
    $content = Get-AgentMdContent
    $hasTryCatch = $content -match 'try\s*\{|catch\s*\{|try/catch'
    Assert-True $hasTryCatch `
        'T015-A: Step 5b dispatch is wrapped in try/catch' `
        'FR-007 requires error handling around the Dispatcher call'
}

function Test-T015-FallbackToInlineEval {
    $content = Get-AgentMdContent
    $hasFallback = $content -match 'fallback|fall\s+back|inline.*eval|degraded.*mode|degraded.*inline'
    Assert-True $hasFallback `
        'T015-B: Dispatcher failure triggers inline evaluation fallback' `
        'FR-007 requires fallback to inline 7-criteria eval when Dispatcher fails'
}

function Test-T015-InlineCriteriaPreserved {
    $content = Get-AgentMdContent
    $hasCompleteness = $content -match '\*\*Completeness\*\*'
    $hasTriggers = $content -match '\*\*WHEN triggers\*\*'
    $hasTestability = $content -match '\*\*Testability\*\*'
    $preserved = $hasCompleteness -and $hasTriggers -and $hasTestability
    $msg = 'Completeness: ' + $hasCompleteness.ToString() + ', WHEN triggers: ' + $hasTriggers.ToString() + ', Testability: ' + $hasTestability.ToString()
    Assert-True $preserved `
        'T015-C: Original 7-criteria inline eval is preserved (at least 3 key criteria found)' `
        $msg
}

function Test-T015-CGFailureAlsoTriggersFallback {
    $content = Get-AgentMdContent
    $hasCGFailure = $content -match 'Failed.*fallback|Failed.*degrade|status.*Failed|unparseable.*fallback'
    Assert-True $hasCGFailure `
        'T015-D: Code Gardener Failed status triggers degraded fallback' `
        'Contract 1 failure mode: Failed or unparseable response must trigger inline eval'
}

# --- T019: Contract test -- build-review.md matches Contract 4 schema ------

function Test-T019-Step5eWritesBuildReview {
    $content = Get-AgentMdContent
    $writesBR = $content -match 'build-review\.md|build.review'
    Assert-True $writesBR `
        'T019-A: Step 5e references docs/build-review.md' `
        'FR-008 requires writing build-review.md before delivery'
}

function Test-T019-HasCyclesField {
    $content = Get-AgentMdContent
    $hasCycles = $content -match '\*\*Cycles\*\*'
    Assert-True $hasCycles `
        'T019-B: Build review template includes Cycles field' `
        'Contract 4 schema requires a Cycles field (0|1|2)'
}

function Test-T019-HasFinalStatusField {
    $content = Get-AgentMdContent
    $hasStatus = $content -match 'Final\s+status|finalStatus|passed.*delivered_with_caveats.*degraded_fallback'
    Assert-True $hasStatus `
        'T019-C: Build review template includes Final status field' `
        'Contract 4 schema requires a Final status field'
}

function Test-T019-HasModeField {
    $content = Get-AgentMdContent
    $hasMode = $content -match '\*\*Mode\*\*.*handoff|Mode.*degraded'
    Assert-True $hasMode `
        'T019-D: Build review template includes Mode field (handoff|degraded_inline)' `
        'Contract 4 schema requires a Mode field'
}

function Test-T019-HasDimensionsField {
    $content = Get-AgentMdContent
    $hasDims = $content -match 'Dimensions\s+scored|dimensions.*<=\s*2'
    Assert-True $hasDims `
        'T019-E: Build review template includes Dimensions scored <= 2 field' `
        'Contract 4 schema requires listing dimensions scored <= 2'
}

function Test-T019-HasIssuesFields {
    $content = Get-AgentMdContent
    $hasFiled = $content -match 'Issues\s+filed|issuesFiledTotal'
    $hasResolved = $content -match 'Issues\s+resolved|issuesResolvedTotal'
    $both = $hasFiled -and $hasResolved
    $msg = 'Issues filed: ' + $hasFiled.ToString() + ', Issues resolved: ' + $hasResolved.ToString()
    Assert-True $both `
        'T019-F: Build review template includes Issues filed and Issues resolved' `
        $msg
}

function Test-T019-HasCaveatsField {
    $content = Get-AgentMdContent
    $hasCaveats = $content -match '\*\*Caveats\*\*|caveats'
    Assert-True $hasCaveats `
        'T019-G: Build review template includes Caveats field' `
        'Contract 4 schema requires a Caveats field'
}

function Test-T019-CommitsBuildReview {
    $content = Get-AgentMdContent
    $hasGitAdd = $content -match 'git\s+add.*build-review'
    $hasCommit = $content -match 'git\s+commit.*build.review|docs:\s+add\s+build\s+review'
    $either = $hasGitAdd -or $hasCommit
    Assert-True $either `
        'T019-H: Step 5e commits build-review.md to the repo' `
        'Contract 4 requires git add, commit, push for build-review.md'
}

function Test-T019-DegradedModeVariant {
    $content = Get-AgentMdContent
    $hasDegraded = $content -match 'degraded_inline|Mode.*degraded'
    Assert-True $hasDegraded `
        'T019-I: Build review supports degraded_inline mode variant' `
        'Contract 4 requires Mode: degraded_inline when inline eval was used'
}

# --- T022: Contract test -- Step 4a template includes Integration Points ---

function Test-T022-TemplateHasIntegrationPointsSection {
    $content = Get-AgentMdContent
    $hasIP = $content -match '(?m)^#{2,4}\s+Integration\s+Points'
    Assert-True $hasIP `
        'T022-A: Step 4a template includes ## Integration Points section' `
        'FR-009 requires Integration Points section in the agent template'
}

function Test-T022-HasOutboundHandoffsTable {
    $content = Get-AgentMdContent
    $hasOutbound = $content -match 'Outbound\s+handoffs'
    $hasTable = $content -match 'Target\s+agent\s*\|.*When\s+dispatched'
    $both = $hasOutbound -and $hasTable
    $msg = 'Outbound heading: ' + $hasOutbound.ToString() + ', Table columns: ' + $hasTable.ToString()
    Assert-True $both `
        'T022-B: Integration Points includes Outbound handoffs table with required columns' `
        $msg
}

function Test-T022-HasInboundHandoffsTable {
    $content = Get-AgentMdContent
    $hasInbound = $content -match 'Inbound\s+handoffs'
    $hasTable = $content -match 'Source\s+agent\s*\|.*When\s+received'
    $both = $hasInbound -and $hasTable
    $msg = 'Inbound heading: ' + $hasInbound.ToString() + ', Table columns: ' + $hasTable.ToString()
    Assert-True $both `
        'T022-C: Integration Points includes Inbound handoffs table with required columns' `
        $msg
}

# --- Run all tests ---------------------------------------------------------

Write-Host ''
Write-Host '=== Handoff Cycle TDD Test Suite ===' -ForegroundColor Cyan
Write-Host 'Target: AGENT.md' -ForegroundColor Gray
Write-Host 'Contracts: specs/001-handoff-cycle/contracts/dispatcher-handoffs.md' -ForegroundColor Gray
Write-Host ''

# Characterization tests (document existing behavior)
Write-Host '--- Characterization (existing Step 5) ---' -ForegroundColor Yellow
Test-Characterization-Step5HasSelfEvalSection
Test-Characterization-Step5Has7Criteria
Test-Characterization-Step5HasScoreThreshold

# T003: Seam test
Write-Host ''
Write-Host '--- T003: Seam test -- Step 5 substep structure ---' -ForegroundColor Yellow
Test-T003-Step5HasNewHeading
Test-T003-Step5aExists
Test-T003-Step5bExists
Test-T003-Step5cExists
Test-T003-Step5dExists
Test-T003-Step5eExists
Test-T003-SubstepsAreInOrder

# T005: Contract 1 -- Code Gardener dispatch
Write-Host ''
Write-Host '--- T005: Contract 1 -- Step 5b dispatch ---' -ForegroundColor Yellow
Test-T005-Step5bHasDispatcherPost
Test-T005-DispatchPromptHasAnalysisOnly
Test-T005-DispatchPromptHasAgentReviewer
Test-T005-DispatchHasParentTaskId
Test-T005-DispatchHasTypeCode
Test-T005-SelfSuspendsAfterDispatch

# T006: Contract 1 -- Callback parsing
Write-Host ''
Write-Host '--- T006: Contract 1 -- Step 5c callback parsing ---' -ForegroundColor Yellow
Test-T006-ReadsCallbackJson
Test-T006-ParsesDimensionScores
Test-T006-IdentifiesCriticalFindings
Test-T006-HasDecisionMatrix
Test-T006-Lists8Dimensions

# T010: Contract 3 -- Refactor Executor dispatch
Write-Host ''
Write-Host '--- T010: Contract 3 -- Step 5d fix dispatch ---' -ForegroundColor Yellow
Test-T010-Step5dHasDispatcherPost
Test-T010-FixPromptReferencesIssues
Test-T010-FixPromptHasOneFixPerCommit
Test-T010-FixPromptDoesNotCloseIssues
Test-T010-FixDispatchHasParentTaskId

# T011: Review-fix loop termination
Write-Host ''
Write-Host '--- T011: Review-fix loop termination ---' -ForegroundColor Yellow
Test-T011-HasCycleCounter
Test-T011-HasCycleCap
Test-T011-HasCapReachedOutcome
Test-T011-HasNoProgressDetection
Test-T011-LoopReDispatchesCG

# T015: Degraded mode fallback
Write-Host ''
Write-Host '--- T015: Degraded mode fallback ---' -ForegroundColor Yellow
Test-T015-Step5bHasTryCatch
Test-T015-FallbackToInlineEval
Test-T015-InlineCriteriaPreserved
Test-T015-CGFailureAlsoTriggersFallback

# T019: Build review artifact
Write-Host ''
Write-Host '--- T019: Build review artifact (Contract 4) ---' -ForegroundColor Yellow
Test-T019-Step5eWritesBuildReview
Test-T019-HasCyclesField
Test-T019-HasFinalStatusField
Test-T019-HasModeField
Test-T019-HasDimensionsField
Test-T019-HasIssuesFields
Test-T019-HasCaveatsField
Test-T019-CommitsBuildReview
Test-T019-DegradedModeVariant

# T022: Integration Points template
Write-Host ''
Write-Host '--- T022: Integration Points template (Contract 5) ---' -ForegroundColor Yellow
Test-T022-TemplateHasIntegrationPointsSection
Test-T022-HasOutboundHandoffsTable
Test-T022-HasInboundHandoffsTable

# --- Results summary -------------------------------------------------------

Write-Host ''
Write-Host '=== Results ===' -ForegroundColor Cyan
foreach ($r in $script:Results) {
    if ($r.Result -eq 'PASS') {
        Write-Host ('  [PASS] ' + $r.Test) -ForegroundColor Green
    }
    else {
        Write-Host ('  [FAIL] ' + $r.Test) -ForegroundColor Red
        if ($r.Detail) {
            Write-Host ('    -> ' + $r.Detail) -ForegroundColor DarkGray
        }
    }
}

Write-Host ''
$summaryColor = 'Green'
if ($script:FailCount -gt 0) { $summaryColor = 'Red' }
$summary = '  Pass: ' + $script:PassCount.ToString() + '  Fail: ' + $script:FailCount.ToString() + '  Total: ' + $script:Results.Count.ToString()
Write-Host $summary -ForegroundColor $summaryColor

if ($script:FailCount -gt 0) { exit 1 } else { exit 0 }
