---
name: address-review-comments
description: Parse reviewer comments, plan responses, apply changes, push, reply "addressed" on each thread.
trigger: ADDRESS_REVIEW state — reviewer pushed `request_changes` and/or left review comments.
inputs: PR_NUMBER, TICKET_ID.
outputs: follow-up commits, PR thread replies, possible question/escalation messages.
---

# address-review-comments

Deterministic procedure. Run once per `request_changes` round.

1. **Fetch every open review comment** on the PR via the host CLI.
   - Build a list `comments = [{id, file, line, body, thread_url}, ...]`.
   - Also fetch the `request_changes` summary review body.

2. **Classify each comment** into exactly one bucket:
   - **A — code change requested:** apply.
   - **B — question about intent:** answer in-thread; only change code if the answer reveals a defect.
   - **C — style/naming nit:** apply unless it contradicts a project rule.
   - **D — contract/architecture pushback:** route to architect via `question`; do not change code based on reviewer alone.
   - **E — out-of-scope ask** (the reviewer is requesting something outside the ticket): reply with "out of scope for <TICKET-ID>; will file follow-up ticket via project-lead if appropriate" — do NOT silently absorb.

3. **For each A/C comment, plan a fix** and write the plan to memory:
   ```
   comment <id> on <file>:<line> — plan: <one-line>
   ```

4. **Apply fixes**
   - Make focused edits.
   - One logical change per commit. Subject: `[<TICKET-ID>] review: <imperative>`.
   - Run lint/format/type-check after each change.

5. **Run tests**
   - Focused test on touched files.
   - Full backend suite.
   - Both green before pushing.

6. **Push**
   ```sh
   git push
   ```

7. **Reply on each thread**
   - For each A comment: reply `addressed in <SHA>` where `<SHA>` is the commit that contains the fix.
   - For each B comment: reply with the answer; if answering led to a fix, also link the SHA.
   - For each C comment: same as A.
   - For each D comment: reply `routing to architect — see question <outbox filename>` and send the `question` to architect.
   - For each E comment: reply with the out-of-scope template above; if it's a real new ask, send a `handoff` to project-lead suggesting a new ticket.

8. **Re-request review** from `reviewer` via the host CLI.

9. **Update the PR body** if anything in `Acceptance`, `Changes`, `Tests`, `Out-of-scope`, or `Risks` changed.

10. **Log to memory**
    - Round number, count of comments per bucket, SHAs pushed.

11. **Stay in ADDRESS_REVIEW** — loop until verdict is `approve`. Maximum two back-and-forth rounds with the same reviewer on the same point before escalating to project-lead per WORKFLOWS.md §8 on-error.
