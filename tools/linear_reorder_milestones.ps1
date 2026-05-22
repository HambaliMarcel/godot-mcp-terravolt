# Re-order project milestones by canonical roadmap sequence via Linear GraphQL.
# Requires: $env:LINEAR_API_KEY (Linear docs: Authorization header value is the raw key).

$ErrorActionPreference = 'Stop'

if (-not $env:LINEAR_API_KEY) {
  Write-Error 'Set LINEAR_API_KEY (personal API key from Linear Settings > API).'
  exit 1
}

$uri = 'https://api.linear.app/graphql'
$headers = @{
  Authorization  = $env:LINEAR_API_KEY
  'Content-Type' = 'application/json'
  Accept         = 'application/json'
}

# Mutation: milestone IDs are UUIDs returned by Linear (list milestones / MCP).
$m = @'
mutation UpdateMilestoneSort($id: String!, $sortOrder: Float!) {
  projectMilestoneUpdate(id: $id, input: { sortOrder: $sortOrder }) {
    success
    projectMilestone { id name sortOrder }
  }
}
'@

$rows = @(
  @{ id = '3705cc53-8db7-48c6-8818-56ef125443b6'; sortOrder = 10 }  # [TV-00]
  @{ id = '4a388d05-96ac-4ae0-8c23-48f2ba97fcdd'; sortOrder = 20 }  # [TV-01]
  @{ id = '59dd00a8-4308-4471-bd4b-2b988b9f68d4'; sortOrder = 30 }  # [TV-02-04]
  @{ id = '0ce83d66-626a-430d-bc23-90f6ee55de1d'; sortOrder = 40 }  # [TV-05-06]
  @{ id = '36065e35-438b-4b80-a278-e55ed35e31f4'; sortOrder = 50 }  # [TV-07]
  @{ id = '7794d5f7-d7fb-464d-8745-eff25d200a46'; sortOrder = 60 }  # [TV-08]
  @{ id = '73e1ed06-7555-458a-a60b-1d7e1ff28f67'; sortOrder = 70 }  # [TV-09]
  @{ id = 'c53878ca-3db7-4e99-b71b-d29933a49e84'; sortOrder = 80 }  # [TV-10]
)

foreach ($r in $rows) {
  $body = @{ query = $m; variables = @{ id = $r.id; sortOrder = [double]$r.sortOrder } } | ConvertTo-Json -Compress -Depth 5
  $resp = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
  if ($resp.errors) {
    Write-Output "Error for $($r.id)"
    $resp.errors | ConvertTo-Json -Depth 6 | Write-Output
    exit 2
  }
  $pm = $resp.data.projectMilestoneUpdate.projectMilestone
  Write-Output "$($pm.sortOrder) $($pm.name)"
}
