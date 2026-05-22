# Graph Report - Godot MCP Marcel  (2026-05-22)

## Corpus Check
- 23 files · ~4,587 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 177 nodes · 151 edges · 27 communities (18 shown, 9 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `9ed926d3`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]

## God Nodes (most connected - your core abstractions)
1. `godot-mcp-terravolt` - 8 edges
2. `Impact Analysis with GitNexus` - 8 edges
3. `Debugging with GitNexus` - 7 edges
4. `Exploring Codebases with GitNexus` - 7 edges
5. `Refactoring with GitNexus` - 7 edges
6. `scripts` - 6 edges
7. `Commands` - 6 edges
8. `GitNexus Guide` - 6 edges
9. `GitNexus — Code Intelligence` - 5 edges
10. `GitNexus — Code Intelligence` - 5 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Communities (27 total, 9 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.12
Nodes (15): description, devDependencies, dependency-cruiser, gitnexus, madge, license, name, private (+7 more)

### Community 1 - "Community 1"
Cohesion: 0.13
Nodes (14): After Indexing, analyze — Build or refresh the index, clean — Delete the index, code:bash (npx gitnexus analyze), code:bash (npx gitnexus status), code:bash (npx gitnexus clean), code:bash (npx gitnexus wiki), code:bash (npx gitnexus list) (+6 more)

### Community 2 - "Community 2"
Cohesion: 0.14
Nodes (13): Checklist, code:block1 (1. gitnexus_impact({target: "X", direction: "upstream"})  → ), code:block2 (- [ ] gitnexus_impact({target, direction: "upstream"}) to fi), code:block3 (gitnexus_impact({), code:block4 (gitnexus_detect_changes({scope: "staged"})), code:block5 (1. gitnexus_impact({target: "validateUser", direction: "upst), Example: "What breaks if I change validateUser?", Impact Analysis with GitNexus (+5 more)

### Community 3 - "Community 3"
Cohesion: 0.14
Nodes (13): Checklist, code:block1 (1. gitnexus_query({query: "<error or symptom>"})            ), code:block2 (- [ ] Understand the symptom (error message, unexpected beha), code:block3 (gitnexus_query({query: "payment validation error"})), code:block4 (gitnexus_context({name: "validatePayment"})), code:cypher (MATCH path = (a)-[:CodeRelation {type: 'CALLS'}*1..2]->(b:Fu), code:block6 (1. gitnexus_query({query: "payment error handling"})), Debugging Patterns (+5 more)

### Community 4 - "Community 4"
Cohesion: 0.15
Nodes (12): Checklist, code:block1 (1. READ gitnexus://repos                          → Discover), code:block2 (- [ ] READ gitnexus://repo/{name}/context), code:block3 (gitnexus_query({query: "payment processing"})), code:block4 (gitnexus_context({name: "validateUser"})), code:block5 (1. READ gitnexus://repo/my-app/context       → 918 symbols, ), Example: "How does payment processing work?", Exploring Codebases with GitNexus (+4 more)

### Community 5 - "Community 5"
Cohesion: 0.15
Nodes (12): code:block1 (1. gitnexus_impact({target: "X", direction: "upstream"})  → ), code:block5 (gitnexus_rename({symbol_name: "validateUser", new_name: "aut), code:block6 (gitnexus_impact({target: "validateUser", direction: "upstrea), code:block7 (gitnexus_detect_changes({scope: "all"})), code:cypher (MATCH (caller)-[:CodeRelation {type: 'CALLS'}]->(f:Function ), code:block9 (1. gitnexus_rename({symbol_name: "validateUser", new_name: "), Example: Rename `validateUser` to `authenticateUser`, Refactoring with GitNexus (+4 more)

### Community 6 - "Community 6"
Cohesion: 0.18
Nodes (10): Activate / refresh, Always Do, CLI, code:bash (npm run intel:graphs), Cursor, GitNexus — Code Intelligence, GitNexus — this workspace, Graphify (+2 more)

### Community 7 - "Community 7"
Cohesion: 0.25
Nodes (7): Always Start Here, code:cypher (MATCH (caller)-[:CodeRelation {type: 'CALLS'}]->(f:Function ), GitNexus Guide, Graph Schema, Resources Reference, Skills, Tools Reference

### Community 8 - "Community 8"
Cohesion: 0.29
Nodes (7): Checklists, code:block2 (- [ ] gitnexus_rename({symbol_name: "oldName", new_name: "ne), code:block3 (- [ ] gitnexus_context({name: target}) — see all incoming/ou), code:block4 (- [ ] gitnexus_context({name: target}) — understand all call), Extract Module, Rename Symbol, Split Function/Service

### Community 9 - "Community 9"
Cohesion: 0.33
Nodes (5): Always Do, CLI, GitNexus — Code Intelligence, Never Do, Resources

### Community 10 - "Community 10"
Cohesion: 0.40
Nodes (4): Agent policies (safety), Branching, Data handling, Destructive operations

### Community 11 - "Community 11"
Cohesion: 0.40
Nodes (4): Layers, Layout ( evolving ), Purpose, TerraVolt Godot MCP — system overview

### Community 12 - "Community 12"
Cohesion: 0.40
Nodes (4): args, command, mcpServers, gitnexus

### Community 13 - "Community 13"
Cohesion: 0.20
Nodes (9): code:bash (git clone --depth 1 https://github.com/youichi-uda/godot-mcp), Contributing (Git hooks), godot-mcp-terravolt, Omni / intel stack, Omni protocol stack (this repo), Reference repos (local), Repository layout, Status (+1 more)

### Community 19 - "Community 19"
Cohesion: 0.40
Nodes (4): Layers, Layout, Purpose, TerraVolt Godot MCP — system overview

### Community 20 - "Community 20"
Cohesion: 0.40
Nodes (4): code:bash (git fetch origin), code:bash (git config core.hooksPath .githooks), Dropping `Co-authored-by: Cursor <cursoragent@cursor.com>`, Git hooks (optional)

### Community 21 - "Community 21"
Cohesion: 0.40
Nodes (4): depConfig, out, outDir, repoRoot

## Knowledge Gaps
- **104 isolated node(s):** `name`, `version`, `private`, `description`, `license` (+99 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Refactoring with GitNexus` connect `Community 5` to `Community 8`?**
  _High betweenness centrality (0.009) - this node is a cross-community bridge._
- **Why does `Checklists` connect `Community 8` to `Community 5`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **What connects `name`, `version`, `private` to the rest of the system?**
  _104 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.125 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.13333333333333333 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._
- **Should `Community 3` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._