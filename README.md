# Ralph Wiggum 🤖

Ralph is an autonomous coding agent system that implements features from PRDs in an iterative, self-contained loop. Each iteration picks up ONE user story, implements it, verifies it, and marks it complete.

## How it Works

1.  **Iterative Loop**: Ralph runs a main script (`ralph.sh`) that spawns an AI agent (Claude, Codex, Gemini, or Cursor) to work on a specific task.
2.  **State Management**: It tracks progress via `prd.json` (user stories) and `progress.txt` (learnings and failure analysis).
3.  **Quality Gates**: It automatically runs test, lint, and build checks before any commit.
4.  **Browser Verification**: For UI changes, it uses the `agent-browser` tool to verify the frontend works as expected.

## Getting Started

### 1. Set up your PRD
Use the `prd` skill to generate a Product Requirements Document with small, verifiable user stories.
Save it to `tasks/prd-[feature-name].md`.

### 2. Convert to prd.json
Use the `ralph` skill to convert the markdown PRD into a `ralph/prd.json` file in your repository.

### 3. Run the Loop
```bash
cd ralph
./ralph.sh --tool claude --iterations 10
```

## Key Files

-   `ralph.sh`: The main execution loop.
-   `prompt.md`: The system instructions for the autonomous agent.
-   `prd.json`: Your feature backlog with `passes` status for each story.
-   `progress.txt`: Consolidated learnings and failure logs.
-   `logs/`: Detailed output from every iteration.

## The One Rule: Story Sizing

**Each story must be ONE focused change completable in a single session.**

If a story is too big (e.g., "Build the entire dashboard"), the agent will likely run out of context and produce broken code. Always split features into:
1.  Schema/Migrations
2.  Backend/API/Server Actions
3.  UI Components
4.  Consolidated Dashboard views

## Quality Gates

Before any commit, Ralph requires:
-   `pnpm test` (or equivalent)
-   `pnpm lint`
-   `pnpm typecheck`
-   `pnpm build`
-   **Browser Verification** (for frontend changes)
