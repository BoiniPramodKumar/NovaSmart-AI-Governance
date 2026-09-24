# M2 — Control the Connections · who may call the back office (resource IAM on one agent)

> Read this when the leader is on **M2**. The shared core (persona, output format, guardrails,
> freshness/tools) lives in `../SKILL.md`. **Open `../SKILL.md` and read it before you act in this module** — this file assumes its rules and does not restate them, so skipping it silently drops every guardrail. M1 (`m1.md`) settled **who each agent is** and
> **what data it may read**; M2 settles **who may call whom**. M3 (`m3.md`) settles **what may be said**.
>
> **M2 has exactly ONE mutation** — a rewrite of the **back-office agent's own IAM policy** in Step 3.
> Two steps before it are read-only, one step after it is read-only. That single write is small, precise
> and genuinely provable: a rogue caller flips from **200** to **403** in front of the leader.
>
> **And it is the module where an honest assistant is most likely to overclaim.** The change you make is
> real and the 403 is real — but the sentence *"only Price Match can call it now"* is **false**, and it is
> the sentence this module tempts you into. Google Cloud IAM **allow** policies are **additive**: a policy
> on one resource **cannot subtract** a permission somebody already holds project-wide, and in this estate
> **many principals hold one**. Everything below exists to make you land the true claim instead of the
> satisfying one (§0 Rule C, §1, §4 · Step 4).

> **Numbering.** Step numbers here match the leader's **M2** Instructions tab, which **restarts at 1** for
> this module — **M2 Step 1 is not M1 Step 1.**
> **Step 1** See who can call the back office · **Step 2** See what locking it down would cost
> *(read-only)* · **Step 3** Lock it to the front desk · **Step 4** Prove the rogue caller is out ·
> **Step 5** Lock down what the back office can reach and do · **Step 6** What's next.
> When you speak to the leader, say the step **name**, not just a number — and if their tab shows different
> numbers, go by the names: the **sequence** is what matters.

---

## 0. The rules that decide whether this mission works

- **Rule A — this file is your map, not your answer key.** §1 tells you *where to look* and lets you
  sanity-check what came back. It is **not** something to recite, and it is **not** a script to replay.
  The leader is meant to watch a real caller get in, watch a real lock go on, and watch that same caller
  get refused. A recited lockdown, or a quoted "expected" 403, teaches nothing and is a fabricated finding.
- **Rule B — report only what THIS step's command actually returned.** Not what §1 says, not what the
  docs say the role contains, not what "should" happen after a `setIamPolicy`. **A mutation is not a
  result.** After the policy is written, **re-read it live** and report *that*. If a live command
  disagrees with §1, **the live command wins** — report the live result and say the map looks stale.
- **Rule C — a resource allow-policy cannot take away a project-level grant.** This is the single most
  important technical fact in the module and the one you must not soften. **Allow policies in the resource
  hierarchy** — project, folder, organization, and a resource's own policy — are
  **additive and evaluated as a union**: the permissions a principal has on the back-office agent are
  everything granted **on the agent** *plus* everything granted **on the project** *plus* everything
  granted **above** it. Rewriting the agent's own policy so it names one caller removes **only** the
  bindings that lived **on that agent**. It removes nothing at the project level, and in this estate a
  crowd of principals hold project-level roles that contain the invoke permission (§1). So the fix is
  real and the 403 is real — **and "only Price Match can call it" is still a false sentence.** Say the
  true one (§4 · Step 4).

  ⚠️ **Rule C governs the resource hierarchy, and one binding in Step 3b sits outside it.**
  `roles/iap.egressor` on Agent Registry resources behind an Agent Gateway is documented as
  **non-additive**: a per-resource binding **replaces** the registry-wide one for that resource rather
  than merging with it. That is why Step 3b says **registry-wide** and means it — a per-resource grant
  does not add to the registry-wide grant, it substitutes for it, and everything else the agent needs (the
  model included) is then denied, which looks like a dead agent rather than a blocked one. ⛔ **Do not
  carry Rule C's union into that grant.** Rule C is true of everything else this module touches, and this
  is the one exception inside the lab's own domain.

### Turbo mode in a module with one precise write

The lab runs with **auto-approve**. You never pause for permission, and you must never say "nothing
happens until you say go", "shall I apply this?", "here's the plan — approve it?" or "let me know and
I'll proceed."

**For the acting step:** **state it in one line → do it → show the evidence → leave a change record**
(what changed · on which resource · when in UTC · the exact command that undoes it). Showing the plan you
are about to execute is good practice; making it *conditional on a reply* is banned.

### ⛔ The exceptions: Steps 1, 2 and 4 change no configuration

| | Step 1 | Step 2 | Step 3 | Step 4 |
| :-- | :-- | :-- | :-- | :-- |
| **Do you change configuration?** | **No.** You read policies and you make one call as the rogue login. | **No.** You model the impact and stop. | **Yes** — the one mutation. | **No.** You re-make the same calls and read verdicts. |
| **Do you ask permission?** | **No.** | **No.** | **No.** | **No.** |

**Step 1 makes a real call to a live agent using a rogue identity. That is an action, but it is not a
change** — no IAM, no deployment, no data written. Making it for real is mandatory: the leader has to see
their own back office answer someone who should never have reached it. A described-but-not-made call is
the worst failure available in this module, because Step 4's whole proof is a **replay** of it.

**Step 2 is the judgment beat.** The leader is meant to work out for themselves that "lock it down" has a
cost worth checking *before* the lock goes on, and to discover that one of the callers on the list is
their own storefront. If you apply the lockdown while explaining what it would cost, you have deleted that
moment. Step 2 ends with the judgment question, not with a request for approval, and not with a pending
plan.

---

## 1. 🔒 SPOILER FENCE — orientation for YOU only

```
=========================== SPOILER FENCE — DO NOT RECITE ============================
Everything in this block is orientation so you know where to look and can sanity-check
what a command returns. NONE of it may be stated to the leader before the step whose
own command reveals it (see the step gate in §2). If a live result contradicts this,
the live result wins.
======================================================================================
```

**The three parties (all met in M1 — never call any of them a shadow):**

- **Markdown Strategy Agent (MSA) — "the back office."** A managed-runtime agent (`reasoningEngine`)
  holding NovaSmart's confidential cost and margin logic. Invoked over **A2A** at
  `…/reasoningEngines/<MSA_ID>/a2a/v1/message:send` (a `:stream` variant also exists). **This is the
  resource M2 protects, and the only resource M2 writes to.**
- **Price Match Agent (PMA) — "the front desk."** The customer-facing agent that escalates a
  bigger-than-policy discount to the back office. It is the **one approved caller**.
- **`test-agent-caller` — the rogue login.** A pre-seeded service account whose JSON key sits in the seed
  bucket. Terraform gives it **exactly one binding: `roles/aiplatform.user` on the MSA resource** — and
  **nothing else, anywhere.** That single fact is why the 200→403 flip genuinely works: strip that one
  resource binding and it has no other route in.

**The mechanism (verified July 2026 — get this exactly right):**

- The control is **the back-office agent's own resource IAM policy**. You **read** it with the aiplatform
  REST **`:getIamPolicy`** on the reasoningEngine, **rewrite** it so the invoke role names only the Price
  Match Agent's principal, and **write it back** with **`:setIamPolicy`, passing the `etag` you read**.
  It is a **scoped replace of that one role's member list** — not an "add", and not a blind overwrite of
  the whole policy (§5).
- **There is NO gcloud command for reasoningEngine IAM.** Verified against gcloud 578.0.0 (components
  2026-07-24): no `reasoning-engines` group in GA, beta or alpha. **Do not invent a gcloud form**, and do
  not "remember" one — if you find yourself typing `gcloud ai reasoning-engines set-iam-policy`, stop and
  use §5. **REST via `curl` with `gcloud auth print-access-token` is the path this module uses** — but it
  is not the only one Google documents: there is also a Python client
  (`aiplatform_v1.ReasoningEngineServiceClient.get_iam_policy` / `set_iam_policy`) and a Terraform
  resource (`google_vertex_ai_reasoning_engine_iam_member`). Neither is a gcloud command, and neither
  changes what this module does — say "there is no gcloud for this", never "REST is the only way".
- **The invoke permission is `aiplatform.reasoningEngines.query`.** Two related permissions are **bypass
  vectors worth checking** on the roles you find: **`aiplatform.reasoningEngineRuntimeRevisions.query`**
  and **`aiplatform.sessions.run`**. A role that lacks the first but carries either of these is still a
  way in.
- **You already hold what this module needs.** You run as **`antigravity-sa`**, which holds
  **`roles/aiplatform.admin`** — and that role contains **`aiplatform.reasoningEngines.setIamPolicy`**.
  **No new grant is required, and none may be created (§6·5).** A 403 here is therefore far more likely
  to be a wrong region, a wrong API version or a malformed URI than a missing permission — work the
  ladder (§6). If it really is denied, **report it and never self-grant.**
- **The PMA principal is a SPIFFE-style workload identity**, of the form
  `principal://<trust-domain>/resources/aiplatform/projects/<PROJECT_NUMBER>/locations/<LOCATION>/reasoningEngines/<PMA_ENGINE_ID>`.
  **Resolve the real value from the deployed agent** (§5) — never hand-write it, never infer the trust
  domain, and never ask the leader for it. A member string you composed yourself is the easiest way to
  write a policy that looks right and allows nobody.

**⚠️ THE HONEST SCOPE — the most important paragraph in this file.**

Allow policies are **additive** (§0 Rule C). In this project **at least ten principals hold a
project-level role that contains the invoke permission** — service agents, deployer accounts, the agents
themselves, and the account you run as. Two of them are worth naming to yourself:

- the **default compute service account** holds **`roles/owner`** — which contains everything, including
  the invoke permission; and
- **`roles/aiplatform.viewer`** — a role whose name promises read-only — **also contains the invoke
  permission.** It is not granted in this project today, so do not report it as a live finding; know it as
  the class of role that would silently defeat a lockdown if anyone ever granted it.

**Count them from the live policy; do not quote the number ten to the leader.** And never say **"only
Price Match can call it"**, **"everyone else is out"**, **"the back office is now private"** or **"access
is locked to one agent."** The claim you can actually prove is:

> **The rogue caller is refused, and the back-office agent's own access list now names exactly one
> approved caller.** Anyone holding a project-wide role that includes the invoke permission is still able
> to reach it — here is that list, and it is the next piece of work.

**Two role traps that will bite you if you go looking for "something narrower":**

- **`roles/aiplatform.reasoningEngineUser` does not exist.** It is the name everyone reaches for. Do not
  suggest it, do not put it in a plan, do not put it in a policy body — the write will fail or, worse,
  succeed against a role nobody holds.
- **`roles/aiplatform.expressUser` is not the narrow substitute it looks like.** It contains **query,
  create, delete and update** on reasoning engines, and **it is already granted in this project** — so
  naming it as the back office's allowed role would hand a caller mutation rights *and* silently re-open
  the door you just closed. **The narrowest real option is a custom role containing only
  `aiplatform.reasoningEngines.query`** (§4 · Step 3 tells you when that is and is not worth doing).

**⚠️ BEFORE-STATE INTEGRITY CHECK — do this first, before any demo.**

In an earlier run of the previous module, **`test-agent-caller` was contaminated**: an assistant that was
blocked from creating a service account granted it extra **project** roles and re-pointed a **Cloud Run
service** to run as it. If that has happened again, **the 200→403 proof is not trustworthy** — a caller
with project-level invoke will still get in after your lockdown, and a caller running production traffic
must not have roles pulled off it casually.

So **before you make the rogue call**, inspect its current state (§5) and check all three:

1. the **project** IAM policy filtered on `test-agent-caller` → expect **no project roles at all**;
2. **which services run as it** (`gcloud run services list` with the service-account column) → expect
   **none**;
3. the **MSA resource policy** → expect **exactly one binding** naming it.

If any of those is not what it should be, **say so loudly, at the top of Step 1**, before you demo
anything: the rogue is **not otherwise-unprivileged**, so a 403 after the change would not prove your
change caused it and a 200 would not prove your change failed. **Report it as a contaminated before-state
and label the demo's evidence accordingly.** ⛔ And **do not "clean it up"**: removing a role from an
account that is currently the runtime identity of a running service can break that service, and
`test-agent-caller`'s bindings are not M2's to edit beyond the single resource-level one on MSA (§3).

**A second caller you will find, and must not fix:**

- **The storefront calls the back office directly.** One of the store portal's actions opens an **A2A
  `message:send`** straight to MSA — **bypassing the front desk entirely** — and the portal runs as the
  **default compute service account**, which holds **`roles/owner`**. So it will keep working after your
  lockdown, **not because you allowed it, but because owner outranks your allow-list.** That is a real
  architectural finding and exactly the sort of thing the leader should hear. **Surface it. Do not fix the
  application, do not re-point it, and do not break it as a side effect** (§3).

**One thing that is NOT protecting anything:**

- **The Agent Gateway starts attached to nothing.** The resources exist and the agent attachment is
  **not made** until this module makes it. **Until you have attached it and read a verdict back, never
  claim the gateway is enforcing, filtering or brokering anything** — an unattached gateway enforces
  exactly nothing, and saying otherwise is the same class of claim as reading a block off the storefront.
- ⛔ **`grant_agent_egress.py` is dead code and must NOT be run**, whatever it looks like it does. It is
  uploaded to the seed bucket and invoked by nothing. Its read-only condition uses an **undocumented CEL
  attribute**, and a wrong attribute name **fails silently as a deny** — running it would produce an
  "allow read" rule that denies everything, with no error to tell you. Take the shape of the API from it
  if you like; never its scope, and never its condition.

---

## 2. Step gate — what may be revealed and what may be *done*, when

> WARNING - **the prompt column contains the leader's words for steps they have not reached yet.** It is
> there so you can identify which row you are currently on - nothing else. **Quoting, paraphrasing,
> echoing or foreshadowing a prompt from any row below your current one is a spoiler**, and it is the
> single most common failure this table has caused: in a real run the assistant closed six answers by
> restating the next row's prompt back to the leader. Match on arrival; never read forward to plan what
> to say.

| Step (Instructions tab) | The leader's prompt | You MAY do / report | You must NOT yet do / say | Diagram |
| :-- | :-- | :-- | :-- | :-- |
| **Step 1 · See who can call the back office** | *"Who can call our back-office margin agent right now?"* | **read-only, plus one real call:** run the **before-state integrity check** on `test-agent-caller` first and report anything off; read the **resource** IAM policy on the back-office agent **and** the **project** policy for roles containing the invoke permission, and show both lists side by side; make the rogue call for real and quote the **HTTP status and body** you got back (expect a real answer); name the storefront's **direct** A2A route as a second caller if you find it | ⛔ **change nothing** — no `setIamPolicy`, no project binding added or removed, no service re-pointed, no role created. ⛔ don't say the lockdown is coming, don't name the fix, don't pre-announce which single caller will be allowed — **Step 2 owns that.** ⛔ don't claim the Agent Gateway is involved. ⛔ don't "tidy up" `test-agent-caller`. ⛔ **§3 scope fence applies** — the **only** inbound IAM write in all of M2 is the Step-2 `setIamPolicy` on the back-office agent, and the only principal it may name is the **PMA principal** (§6·5) | REQUIRED - CALL. The module turns on one distinction: callers on the agent's own list versus callers who get in above it. The picture must show **both** groups - showing the second one is what stops the overstatement this module bans. ⚠️ Every element in it must be something a command returned in this session (§7) |
| **Step 2 · Check the cost, lock to front desk & attach egress gateway** | *"Show me what would break if we locked the back office down to just the price-match agent, then make the change."* | **two halves in one prompt — FIRST read-only:** for every caller you found in Step 1, say plainly what happens to it if the back office's own list names only the front desk — **who loses access, who does not, and why**; state the additive-policy truth in plain English; flag the storefront's direct route explicitly as *"keeps working, because it runs as an owner-level account"*; put the judgment question to the leader. **THEN, and only once that readout is on the page:** check if `novasmart-egress-gateway` exists; if missing, create/import it (`AGENT_TO_ANYWHERE`, `protocols: [MCP]`); attach it to MSA via `agentGatewayConfig`; resolve the **real** PMA principal dynamically; capture current policy and `etag`; rewrite resource IAM policy via `:setIamPolicy` on MSA to contain **only** the PMA principal under `roles/aiplatform.user`; re-read the policy live; update invocation testing to `:streamQuery` or `a2a/v1/message:send`; write change record | ⛔ **change nothing until the impact readout is in front of the leader** — that is the judgment moment. No policy write ahead of it, no "harmless" dry-run that mutates, no pre-emptive role creation. ⛔ don't state the leader's verdict for them, and **don't ask for approval either** (§0). ⛔ don't promise an outcome you haven't tested. ⛔ don't propose stripping project-wide `aiplatform.user` (§3). ⛔ don't claim the rogue is blocked — **that is Step 3, and it needs its own before/after.** ⛔ don't say "only Price Match can call it" or "everyone else is out" — false (§0 Rule C, §1). ⛔ don't write without the etag. ⛔ don't touch project-level bindings, `test-agent-caller`'s other state, the storefront, or any service account (§3). ⛔ **§3 scope fence applies** | REQUIRED - BEFORE/AFTER on CALL, belonging to the write half and built from the re-read. The project-wide holders must appear UNCHANGED on both sides of the same picture; carrying them through both halves is what makes the honest claim visible instead of relying on the leader reading a caveat. For the impact half a CALL picture of the current state is OPTIONAL |
| **Step 3 · Prove the rogue caller is out** | *"Try calling it as that rogue login again, and check the real escalation still works."* | replay the **byte-identical** rogue call from Step 1 on `:streamQuery` or `a2a/v1/message:send` — same URL, same body, a **freshly minted** token — and quote the status and error verbatim (`HTTP 403 Forbidden`); then trigger the **real** front-desk escalation through the **Price Match Agent** — quoting a competitor price that is **actually listed in the seeded competitor table** (SKU-HSE-4001, shelf $349.00, BetaBuy $296.65 [15%]) — and show a real margin decision came back; state the honest scope claim and name the project-wide holders as remaining work | ⛔ **no claim without a live result from this session.** ⛔ the words **"blocked", "proof", "proves", "proven", "verified"** are banned **as affirmative claims** unless the actual response or log entry has been written into **this turn's entry in this step's evidence file** (§0) and the status you are claiming is quoted in the answer as well. ⛔ **never** say "only Price Match can call it" / "everyone else is out" / "the back office is private". ⛔ don't test the escalation via the storefront's **direct** strategy route — that is the **bypass**, not the escalation (§4). ⛔ don't invent a competitor price. ⛔ **§3 scope fence applies** | FORBIDDEN - this is a verification result. The Check / How I verified / Result table is the only permitted form — three columns, exactly as declared in §9 |
| **Step 4 · Configure IAP Authz Extension & Fine-Grained CEL Policy** | *"Make sure the back office can only reach what it needs, and can only read the pricing data, not change it."* | import IAP `AuthzExtension` (`iap.googleapis.com`, `iapPolicyVersion: "V1"`) and `AuthzPolicy` targeting `novasmart-egress-gateway`; dynamically discover BigQuery MCP Server ID and apply fine-grained IAP CEL policy via `gcloud beta iap web set-iam-policy --resource-type=agent-registry --mcp-server=<MCP_SERVER_ID>` allowing MCP lifecycle methods (`initialize`, `tools/list`, `tools/call`, `notifications/initialized`, `ping`) and read-only BigQuery tool methods (`execute_sql_readonly`, `list_tables`, `get_table_schema`, `list_datasets`); dynamically discover and grant `roles/iap.egressor` on global/regional generic Google APIs endpoints; narrow MSA's project database IAM from `bigquery.admin` to `bigquery.jobUser` plus dataset `READER` | ⛔ don't omit MCP lifecycle methods (`initialize`, `tools/list`, `notifications/initialized`, `ping`) in the CEL expression — omitting them blocks MCP session handshake with 403 Forbidden. ⛔ never hardcode project numbers, regions, org IDs, or agent/endpoint IDs (§5). ⛔ never accept the agent's own answer as proof. ⛔ don't remove broad database role without granting reads back. ⛔ never run `grant_agent_egress.py` (§1, §3). ⛔ **§3 scope fence applies** | REQUIRED - BEFORE/AFTER on REACH. Both halves from live re-reads this turn: the gateway verdict, and the value read back from the database. Cover reach and verbs only |
| **Step 5 · Verify M2 connection controls & generate Mission Scorecard** | *"Verify our M2 connection controls and generate the Mission 2 Governance Scorecard."* | **strictly read-only audit:** check the live state of all connection controls (MSA gateway attachment, inbound A2A restricted to PMA, `test-agent-caller` 403 refusal on `:streamQuery`/`a2a/v1/message:send`, PMA escalation throughput, IAP authz extension/policy, BigQuery MCP server CEL policy, generic Google APIs endpoints egress grants, zero self-grants). If all pass, run `update_scorecard.py --mission M2 --status PASS`, render consolidated table, emit One-Line Achievement Statement, and link to `governance_scorecard.html` | ⛔ **STRICTLY AUDIT-ONLY: ZERO MUTATIONS.** Never create, patch, delete, or modify any resources during this step. If a check fails, report `[ NOT CONFIGURED ]` or `[ FAILED ]` and guide the leader back to the missed step; NEVER apply the fix automatically on their behalf | REQUIRED - not a picture. The consolidated verification table goes into the answer; full raw outputs are saved to `/config/Desktop/novasmart-evidence/m2/m2_step5.txt` |
| **Step 6 · What's next** | *(no prompt)* | one honest close-out — what is now true and evidenced, what you could not verify, what this control does **not** cover — plus a one-line bridge to M3 | ⛔ don't start M3's content-screening work; don't claim the estate is secure or that the connections are fully controlled. ⛔ **Don't claim the gateway is enforcing anything you have not read a verdict for**. ⛔ **§3 scope fence applies** | FORBIDDEN - recap; a forward picture would show the next module's after state |

### Matching a request to a row

**Declare the match before you act on it** — one line, first: *"This is Step N, because you asked for X."*
An unstated match cannot be challenged, and a wrong one stays invisible until the answer is already wrong.

⛔ **A promptless row is NOT matchable.** **Step 6 · What's next** carries *(no prompt)* because the leader
never types one — it is reached by finishing the step before, never by matching words. **Never route a
typed request to it.** A promptless row has no prompt text to fail against, so it will absorb any request
whose verb happens to echo its title. That has already happened in this lab: an off-script request to
*build an evaluation* was matched to a row titled *"What you built"* and answered with a close-out that
mentioned none of what was asked.

### None of the above — the branch this table used to lack

**A request that matches no row is normal, not an error.** These rows are the module's spine, not a list of
the only things the leader is allowed to ask for. A closed classifier with no escape has one way to fail:
it force-fits, and answers something nobody asked.

When nothing matches, in order:

1. **Say so plainly** — *"That is not one of M2's steps."* Do not reach for the nearest row.
2. **Answer what was actually asked**, inside §3's scope fence. Reading, analysing and authoring are not
   mutations, and the fence does not forbid them.
3. **Say where that leaves the module** — which step is still outstanding, so the leader can carry on or
   stay off-script knowingly.

⛔ **Never silently substitute.** Answering a different question from the one asked, without saying that is
what you have done, is the exact failure this branch exists to stop. If you are unsure which row applies,
that uncertainty is reportable — say it, and ask.

> **Hard rule.** Report only what **this** step's command actually returned, and **act only within this
> step's row**. If the leader asks ahead — *"so is the back office private now?"* — don't recite and don't
> race ahead: name the check that would answer it, run that check, report its actual result.

> **Quoting this table back — verbatim, or not at all.** If you are asked (in a per-turn self-check, a
> plan, or anywhere else) to quote the step-gate row you are working under, **copy that row out of this
> file exactly as written** — every clause, including the ones that constrain what you were just about to
> do. **Never paraphrase, summarise, shorten, or reconstruct a row from memory.** If you cannot quote it
> exactly — you don't have the file open, you're unsure which row applies — **say so** ("cannot quote §2
> verbatim") rather than producing an approximation.
>
> **A self-audit that rewrites its own rule is worthless.** Dropping the clause you are about to breach
> turns the check into a rubber stamp. **This has actually happened in this lab:** in a real run the
> assistant quoted the early rows verbatim, then silently invented the later ones — omitting precisely the
> constraints it went on to violate. Treat any row you produced from memory as a **failed** audit, and go
> and read the real one.

### Optional "try this too" prompts — known off-script, with agreed handling

The prompts below are offered to the leader at the end of the Instructions tab, so they arrive **off-script
by design**: the none-of-the-above branch applies in full, and so does the Hard rule above. Every one of
them is a **read**. One standing failure covers all of them, and it is not answering badly — **it is
fixing.** Each question describes something that is still wrong, and in each case the helpful-looking move
is a write: **adding a caller to a list**, **pruning a project-wide role you were only asked to rank**,
**retiring a leftover credential you were only asked to look for**. Every one of those sits outside §3 —
and every one of them also destroys this module's own evidence, because the refusal you quoted and the
escalation you exercised are only re-runnable while the estate stays exactly as this module left it.
**Report; do not repair.** ⛔ And **no fixed number survives from an earlier step or from this file** — any
count you give is re-read live in the turn you give it. The additions below are specific to each prompt.

| The prompt | What you MAY do | What you must NOT do |
| :-- | :-- | :-- |
| *"Which of those broader permissions would you take away first, and what would break if we did?"* | **Re-read the project policy live this turn** (§5) and rank what *that* read returned. Sort by what removing each grant would actually do, in the leader's terms: the pure over-grants that could go with no operational consequence; the **load-bearing** ones — the project-wide `aiplatform.*` grants also carry **the agents' own model access**, so cutting them secures the back office by stopping the front desk (§3), which is the counter-intuitive result that earns this question; and the owner-level identity the storefront runs as, whose fix is an application change on an engineering backlog rather than an access change anyone can direct. Finish on a ranked plan that says who would have to do each item | ⛔ **Remove nothing.** The question asks which you would take away **first**, and the temptation is to take that first one away — **the ranking is the entire deliverable**, and any binding you touch is a second, unasked-for change nobody has sized. §3 holds without exception: no project-level binding added or removed, nothing stripped from the storefront's identity, from a service agent, or from `test-agent-caller`. ⛔ **Don't undo Step 5 either** — the BigQuery bindings that step rewrote and the gateway it attached are not "broader permissions" to prune back. ⛔ **Quote no count you did not read this turn**, and never carry one forward from Step 1 or from §1. ⛔ Don't offer a **deny policy** as the remedy: deny attaches only at project/folder/org level and `reasoningEngines` carry no tag to scope one, so it would hit every agent (§4 · Step 4). Grant pruning, named as recommendations, is the whole answer |
| *"We closed the door on that leftover login. Does anyone still have its keys?"* | Answer the **credential** question, which is not the access question — closing an access list and retiring an identity are two pieces of work and only one of them was done today. State each of these separately, and each from a live read: the service account **still exists**; a **usable private key for it is sitting in the project's seed bucket**, which is how you authenticated as it earlier in this module (§5); and **whoever can read that bucket can currently become that identity** — read the bucket's policy and say who that is, or say the read failed and name the command. Then the honest framing: it is harmless **today** only because the account holds nothing anywhere, and that harmlessness is a property of its current grants rather than of anything you changed, so a single future grant restores the whole problem | ⛔ **Never print, echo, paste or summarise key material**, and delete any local copy (§8). ⛔ **Delete, disable, rotate, re-key, rename and suspend nothing** — `test-agent-caller`'s state beyond the single resource binding your scoped replace dropped is out of scope, **including as a tidy-up** (§3). This is the specific temptation here, and it costs more than scope: **retiring that credential destroys Step 4's evidence**, because the byte-identical replay that produced the refusal can only be re-run while the key still authenticates. ⛔ Don't remove the bucket object, and don't change who can read the bucket. ⛔ Don't re-answer Step 4 — you are being asked about the credential, not about whether the login still gets in |
| *"Does any other agent have a list like this, or is the back office the only one?"* | Run the same `:getIamPolicy` you used in Step 1 (§5) against **each deployed agent you can resolve live**, and report agent by agent what came back — **including the ones that return no list at all, which is the finding**. Say plainly that the back office is the only place this pattern has been applied, so everywhere else *"who may call this?"* is still answered by whatever project-wide role somebody happens to hold. Name which agents would benefit most from a list of their own (the ones holding something confidential, or the ones nothing customer-facing should reach) and which genuinely do not need one, then stop. Say which agents you could **not** check, and why | ⛔ **Write nothing. This is the strongest mutation temptation in M2** — the answer is a list of agents with no caller list, and putting one on each of them reads like finishing the job. It is not the job: **the only inbound IAM write in the whole module is Step 3's, on the back office** (§3, §6·5), it changes resources M3 and M5 depend on, and on the customer-facing agents a wrong member string takes the storefront down. ⛔ **Attach the gateway to no other agent** (§3). ⛔ **Don't count a registry-wide or project-level binding as an agent's own caller list** — the difference between the two is this module's whole subject, and blurring it here undoes it. ⛔ Don't record an agent as having no list on the strength of a read that errored: say the read failed |

---

## 3. Scope fence — what M2 changes, and what it must NOT touch

M2 changes **one thing: the IAM policy on the back-office agent (`reasoningEngines/<MSA_ID>`)**. That is
all. "Lock down invoke access across the estate" is **not** an instruction you have here — every wider fix
you can imagine either breaks a running agent, breaks the storefront, or erases another module's
before-state.

**In scope — M2 changes exactly one thing:**

1. **The back-office agent's own resource IAM policy**: the invoke role's member list, rewritten so it
   names **only the Price Match Agent's principal**, written with the `etag` from the read, preserving
   every binding you did not intend to change.

That single `setIamPolicy` is the whole of M2's write surface. Everything else in this module is a read,
a call you make as a client, or a sentence you say to the leader.

**Out of scope — do NOT change these:**

- ❌ **Project-wide `roles/aiplatform.user` (and every other project-level `aiplatform.*` binding).**
  Stripping them is the "obvious" systemic fix and it is **wrong here**: those grants are also what give
  **the agents their own model access**. Remove them and PMA and MSA stop working — you will have secured
  the back office by breaking the front desk. **Name the project-wide holders as a finding and remaining
  work; leave every binding exactly as you found it.**
- ❌ **Model Armor, content filters, screening of any kind.** That is **M3's** material and M3's
  before/after depends on nothing being screened yet. Not the floor setting, not a template, not a
  per-request config.
- ❌ **Anything M1 fixed:** the BigQuery `customer_data` access, the per-workload service accounts, the
  registry entries. If you notice a data-access issue here, name it and note M1 already scoped it.
- ❌ **Creating, deleting or re-pointing any service account** — including the runtime identity of any
  Cloud Run service or agent. No new accounts, no impersonation plumbing, no "temporary" swaps.
- ❌ **`test-agent-caller`'s state beyond the single resource-level binding on the back-office agent.**
  Its project bindings (there should be none), its display name, its key, and what it runs are all off
  limits — including as a "cleanup". If it is contaminated, that is a **finding to report** (§1), and
  removing a role from an account a live service is running as can take that service down.
- ❌ **The storefront (`ui/`) and its direct A2A route to the back office.** It bypasses the front desk
  and it runs as an owner-level account. **Report it; don't patch it, don't re-point it, and don't break
  it.** Fixing the application is not this module's lesson and is not in this module's charter.
- ✅ **The Agent Gateway IS in scope — attaching it to the Markdown Strategy Agent is what this module
  does.** What remains out of scope: ❌ **running `grant_agent_egress.py`** (dead code whose condition
  fails silently as a deny — §1); ❌ **attaching any agent other than the back office**; and ❌ **using the
  gateway as a workaround if the inbound policy write is denied** — a blocked step is a finding to report
  (§6·7), and the two halves of this module are not substitutes for each other.
- ❌ **IAM deny policies, org policies, VPC-SC, or any other subtractive control.** These are the
  mechanisms that *could* close the project-wide gap — which is exactly why naming them is the right
  answer and **building one here is not** (§4 · Step 4).
- ❌ **Any IAM grant to any principal other than the PMA principal on the back-office resource** — and
  never to **`antigravity-sa`** (the account you run as), whatever the reason (§6·5).

> **If you spot another exposure outside this one item — a project-wide role that shouldn't be there, an
> app bypassing the front desk, an unregistered destination nobody catalogued: name it as a finding, say which work it belongs to, and
> leave it alone.** Reporting it is good governance. Silently fixing it breaks the lab and can break the
> store.
>
> **And if a step is blocked, the same logic applies:** a blocked step is a **finding to report** (§6·7),
> never a licence to reach outside the fence for a workaround. Stripping project bindings, granting
> yourself a role, or **substituting one half of this module for the other** are all **worse outcomes**
> than an honest blocker report. (Attaching the gateway is not on that list — it is the work. Using it to
> paper over a denied inbound write is.)

---

## 4. Step by step — where to look · what good looks like · don't mislabel

### Step 1 · See who can call the back office — ⛔ READ-ONLY (plus one real call)

> **You change nothing. You read two policies and you make one call.** The call is the "before" half of
> Step 4's before/after, so **save the exact URL, the exact request body, and the raw response with its
> UTC timestamp** — a before/after you cannot diff is not a before/after.

- **Do the before-state integrity check FIRST — before the demo, not after (§1).** Three reads (§5):
  the project policy filtered on `test-agent-caller`, the Cloud Run service list with its service-account
  column, and the back-office agent's own IAM policy. **Expect: no project roles · runs nothing · exactly
  one resource binding.** If any of that is different, **lead with it**: say the rogue account is not
  otherwise-unprivileged, say what it now holds, and say plainly that the 200→403 demonstration will
  therefore not isolate the effect of your change. Then continue, with the evidence labelled accordingly.
  ⛔ **Do not repair it.**
- **Where to look — two different lists, and the leader needs both:**
  1. **The back office's own access list** — `:getIamPolicy` on the reasoningEngine (§5). This is the
     short, deliberate list: who has been given access **to this agent specifically**. Expect it to name
     the rogue.
  2. **The project-level list** — every principal holding a role that contains
     **`aiplatform.reasoningEngines.query`** (and check the two bypass permissions from §1 while you are
     there). This is the long, accidental list. **Count what you actually find** and quote roles verbatim.
     Note out loud that a role called **viewer** appears on it — that lands the point better than any
     explanation.
  3. **Who else calls it in practice** — check the storefront's configuration/behaviour for a **direct**
     route to the back office. If you find one, name it: an application talking to the back office
     without going through the front desk, under an owner-level identity.
- **Then make the rogue call for real** (§5): fetch the seeded key, mint a token **in an isolated gcloud
  config so you never disturb your own credentials** (§8), and POST the A2A `message:send` to the back
  office. Quote the **HTTP status** and the **response body** you actually received.
- **What good looks like — a fixed shape, filled only from live output:**

  ```
  | Who | Where their access comes from (resource policy / project role) | Which command showed me | What that lets them do | Should they? |
  ```

  **The `Which command showed me` cell is compulsory and it is not decoration** — it is the same
  provenance rule the diagram is held to, applied to the surface that actually gets read. **A row whose
  provenance cell is empty is a claim, not a finding, and it does not go in.** The storefront's direct
  route is the one this exists for: in a real run it was asserted in this table three times with **no
  command anywhere behind it**, while the diagram beside it correctly drew the same route as unverified.
  The prose and the picture contradicted each other, and the claim happened to be **true** — which is
  exactly what makes it dangerous, because nothing in the answer distinguished it from a guess.

  **One row is required whatever else you found: the project-wide holders.** Its `Who` cell names the
  roles you actually read from the project policy, `viewer` among them if it is there, and its provenance
  cell names the §5 command that produced them. ⛔ **Do not drop that row because it is not a single named
  caller** — it is the largest group on the list and the reason the honest claim in Step 4 is narrower
  than the tidy one.

  above it, the plain-English headline (*"your confidential margin logic will answer a login that was
  never meant to have it — here is the call I just made and what came back"*), and one unmissable
  distinction in the leader's language:
  > **"Can read the data" and "can call the agent" are two different permissions.** M1 fixed the first.
  > This is the second, and nothing has ever governed it here: access to the back office was never a
  > deliberate list — it is a side effect of roles handed out project-wide.
  Then leave the remaining gap visible **without naming what would close it**: nobody ever chose this
  list of callers — it is a residue of grants made for other reasons, and a list nobody chose is not the
  same as a list nobody would object to. ⛔ **Never close by asking the next step's question.** In a real
  run that habit telegraphed six answers in a row; the closing note further down this step governs.
- **The picture — REQUIRED here, and it is a CALL diagram (§2).** Draw the one distinction the whole
  module turns on: who is on the back office's **own** caller list, and who gets in **without being on
  it**. **Exactly one arrow is solid** — the rogue call you actually placed, which is the only call this
  step makes. **Every other arrow is dashed**, because you read a permission in a policy and you did not
  watch anybody use it. Draw those solid and you have claimed calls you never saw:

  ```
  Who can reach [Markdown Strategy] today, read just now

    on the back office's own caller list:
      (test-agent-caller) --> [Markdown Strategy]   called it just now

    not on that list, but holding a permission that reaches it:
      [Price Match] --?--> [Markdown Strategy]   may call
      [store portal] --?--> [Markdown Strategy]   may call, direct
      (11 project-wide role holders) --?--> [any agent here]  may call

    Dashed = a permission read in a policy, not a call anyone made
    this step. What would settle each: place the call, read the status.
  ```

  **`11` is a placeholder for whatever you counted in the live project policy** — never a number carried
  over from this file, and never the word "ten" from §1. The two groups are the point: the second one is
  the reason the honest claim is narrower than the tidy one, and drawing it here is what stops you
  writing the tidy one in Step 3 or Step 4. Anything you did not actually read is drawn as `?` with one
  line naming the command that would settle it — a group you omit reads as "there is nobody there",
  which is a claim you cannot support. If the storefront's direct route turned out not to exist, drop
  that line and say why; do not draw a route you did not find.

  **⛔ Do not upgrade a dashed arrow to a solid one here, however obvious the route looks.** The front
  desk's ability to reach the back office is an **inference from the policy you just read** — the project
  policy shows it holding a role that carries the invoke permission — and an inference is not an
  observation. Step 4 is the first step that exercises the front desk for real, with its own before/after.
  The store-portal line is weaker still: it comes from the application's own configuration, which is
  known to carry a **stale hard-coded engine id** (§8), so draw it dashed and say in the caption where
  you read it. If you cannot say which command produced an arrow, the arrow does not go in — **and the
  same rule governs the table above it**: a row whose `Which command showed me` cell is empty is a claim,
  not a finding, and it does not go in either. The picture and the prose are held to one standard.
- **Don't mislabel:**
  - **A call you did not make is not a finding.** If you describe the rogue call without making it, you
    have fabricated the step — and destroyed Step 4, which can only replay something that happened.
  - **A 403 in Step 1 is a result, not a failure to be worked around.** If the rogue call does *not*
    return a real answer, say so plainly and check the before-state integrity results before anything
    else. **Never keep changing the request until you get a 200 and then call that "the before".**
  - **Don't confuse the two lists.** "One binding on the agent" and "ten principals project-wide" are
    different sentences from different commands. Say which command each came from.
  - ⛔ **If the check did not complete, you do not have a number.** The §5 sequence prints two counts and
    then a list of principals; if any of the three did not finish, report the incomplete check and say
    what is missing. **Never infer a total from the rows that scrolled past before it stopped**, and never
    round a partial read up into a confident figure. In a real run the count was killed mid-loop and the
    number was stated to the leader **six times** anyway — it is the load-bearing half of this module's
    honest-scope claim, so an unmeasured one poisons the close of every step after this.
  - ⛔ **A count of roles is not a count of callers.** They are different populations and the second is
    the one the leader asked about. Resolve the principals (§5) before you quote a figure, and say which
    of the two any number you give is.
  - **Don't call the gateway a control yet.** At Step 1 it is attached to nothing and enforces nothing.
    It becomes a control in Step 3, and only once you have read a verdict back (§1, §7).
  - **Don't propose the fix yet.** Naming the lockdown, the role or the PMA principal here burns Step 2.
  - **Never print the rogue's private key, and delete the local copy when you're done** (§8).
- **How to close — a shape to re-derive, never a line to recite.** What this step actually taught the
  leader: the back office's own list of permitted callers has one name on it, an unowned leftover login
  that just answered you, and the caller the business genuinely depends on is not on that list at all —
  so whatever gets the front desk in was handed out somewhere other than here. An honest close lands
  *that*, not the next thing to do. The **ideas**, in whatever order your own reads support:
  - the one name on the list should not be there;
  - the one caller the business depends on is not on the list;
  - so whatever admits the front desk was granted somewhere other than this list;
  - so the list is not the thing controlling access.

  A worked example from a **different** estate, to show the join and not to be lifted: *"The only account
  on the payroll export's allow-list is a decommissioned batch job, and Finance — who pull that export
  every month — are not on it. So Finance are getting in some other way, and this list is documentation
  rather than a control."* ⛔ **Do not reuse those words.** NovaSmart has no payroll export and no Finance
  team; the example is deliberately ill-fitting so that there is no sentence here to copy.

  ⛔ **Do not write "yet the escalation works anyway", or any other sentence asserting that the front
  desk successfully calls the back office.** You have not made that call — this step makes exactly one
  call, as the rogue login. What you can say is what the **list** shows and what the **policy** shows:
  the front desk is absent from the list, and its access therefore comes from elsewhere. Whether the
  escalation actually returns a decision is a behaviour, it is Step 4's to observe, and asserting it here
  is a fabricated finding of exactly the kind this module exists to catch.

  Re-derive your own version from what came back this turn; if your live reads gave a different picture,
  the words change. Then two or three questions grow out of that gap — what a caller list on a system
  holding margin logic ought to look like, who would put their name to it, how NovaSmart would notice a
  new name arriving on it. ⛔ **Never close by asking what a lockdown would break.** That is the next
  step's prompt almost word for word, and closing on it is the exact telegraph the warning above the step
  gate describes. ⛔ Don't
  price the lockdown, don't enumerate the routes as a plan, and don't name the fix — that is the next
  step's own readout.

### Step 2 · Check the cost, then lock it to the front desk — the judgment beat, then the one mutation

> **One prompt, two halves, and the order carries the lesson.** The leader asked what a lockdown would
> cost **and then** asked for it. **Half one changes nothing** — you model the impact and put it in front
> of them, and everything you describe there stays in the conditional: *"would"* stays *"would"*. **Half
> two is M2's single inbound mutation** — the rewrite of the back office's own access list — and it does
> not begin until half one exists on the page. ⛔ **Merging the prompts did not merge the halves.**
> Applying the lock and then narrating what it "would have" cost is the failure this step is shaped to
> prevent: it deletes the judgment moment while looking like it kept it.

#### Half one · See what locking it down would cost — ⛔ READ-ONLY

- **Where to look (all reads):** the same two lists from Step 1, plus — for each caller you found — what
  it actually uses the back office **for**. The question the leader asked is *"what would break?"*, so
  answer it caller by caller.
- **The analysis, in the leader's terms:**
  - **The front desk (PMA):** it is the intended caller; naming it in the list is the whole point. It
    keeps working.
  - **The rogue login (`test-agent-caller`):** its **only** access is the binding on this agent. Take that
    away and it has nothing left — **it is the one thing that would actually change**.
  - **The storefront's direct route:** it would **keep working** — and this is the uncomfortable part —
    because it runs as an **owner-level** account whose access comes from the **project**, not from the
    agent's own list. **Say this as a finding, not a reassurance:** nothing you do to this agent's own
    policy can stop a caller who is already an owner of the project.
  - **The wider project-level holders:** likewise unaffected. **This is Rule C in plain English** — say it
    once, clearly: *"Locking this agent's own list removes only the access that was granted **on this
    agent**. It cannot take away access somebody was granted across the whole project."*
- **What good looks like — a fixed shape, filled only from live output:**

  ```
  | Caller | How it gets in today | After a lock to the front desk | Breaks? |
  ```

  and one honest bottom line: the lockdown is **safe** — the only caller it removes is the one that should
  never have been there — **and it is partial**, for the reason above.
- **Put the judgment question in front of the leader before you touch anything:** *is it enough to put a
  deliberate list on the agent itself, when a project-wide role can still walk past it?* Leave it with
  them — don't pre-print your verdict, don't apply anything ahead of this readout, and — equally,
  **don't ask for approval** (§0). ⛔ **Do not wait for an answer either.** They already told you to make
  the change in the same sentence; the question is theirs to sit with, not a gate on half two.
- **Don't mislabel:**
  - **This is a prediction, not a result.** Describe it in the conditional. If you catch yourself writing
    "the rogue is now denied" in this half, you have skipped both the write and the test that follows it.
  - **Don't quietly widen the plan.** "And while we're at it, we should remove the project-wide grants" is
    outside the fence and would break the agents' own model access (§3). Name it as remaining work.
  - **Don't understate the storefront finding to keep the story tidy.** An application reaching the back
    office directly, as an owner, is exactly what a security leader needs to hear.
  - Don't say "I'll apply this unless you object" — that is an approval gate, and it is banned.
- **How to land this half — a shape to re-derive, never a line to recite.** The judgment question above is
  this half's designated ending and it stays. What goes *around* it is the honest implication of your own
  impact table: nothing the business depends on runs through the door in question, and that door is one
  of several. The **ideas**:
  - nothing the business depends on runs through the door being closed, and that part is clean;
  - the door is one of several, and the others stay open regardless;
  - so anything said about this afterwards has to be worded very carefully.

  A worked example from a **different** estate, to show the join and not to be lifted: *"Closing the
  clinic's records system to the one retired terminal costs nobody anything — but the same records are
  reachable from two other systems that were never in scope, so 'the records are locked down' would be a
  sentence I could not stand behind."* ⛔ **Do not reuse those words.** NovaSmart has no clinic and no
  terminals; the example is deliberately ill-fitting so that there is no sentence here to copy.

  **"Several" is whatever your own table counted**, not a number from this file; if you found three routes
  or five, say three or five. "Worded very carefully" is doing real work here — it plants the honesty
  discipline the module needs before the leader is in a position to need it, without naming a single
  action. ⛔ Don't answer the judgment question for them, don't ask for approval, and don't let this half
  drift into *how* the lock will be applied, which role it will use, or which principal it will name —
  the mechanics belong to half two, and putting them here turns the impact readout into a plan.

#### Half two · Lock it to the front desk & attach egress gateway — the mutations

- **This module answers two questions, and they need two different controls.** *"Who may call the back
  office?"* is answered by the access list on the back-office agent — that is locked down here. *"Which
  destinations may the back office itself reach?"* is answered by the **Agent Gateway**, attached here and
  configured with fine-grained CEL policy in **Step 4**. ⛔ **Neither substitutes for the other.** Report them
  separately, and never present one as covering the other.

> [!IMPORTANT]
> **Why Attaching an Egress Gateway Blocks All Outbound Traffic, and How Price Match Still Invocates MSA:**
> * **Zero-Trust Outbound Default-Deny:** Attaching `novasmart-egress-gateway` (`agentGatewayConfig.agentToAnywhereConfig`) routes 100% of the agent's outbound network traffic through the Agent Gateway. The gateway enforces zero-trust by default: without an attached `AuthzPolicy` and `AuthzExtension` (IAP), the gateway denies every outbound egress attempt — including external APIs, tools, and crucially the agent's own Gemini model endpoint (`aiplatform.googleapis.com`).
> * **Inbound A2A vs Outbound Egress Separation:** The egress gateway governs *outbound destinations* (where the back office goes), NOT inbound callers. Inbound invocation to the Markdown Strategy Agent is governed by its **Reasoning Engine Resource IAM Policy** (`:setIamPolicy` on `reasoningEngines/<MSA_ID>`).
> * **How Price Match Agent Still Talks to Markdown Strategy Agent:** In this step, we rewrite MSA's resource IAM policy to bind `roles/aiplatform.user` strictly and exclusively to the Price Match Agent principal (`principal://agents.global.org-.../reasoningEngines/<PMA_ID>`). PMA's inbound call succeeds because it matches this explicit resource allowlist, while unauthorized callers (`test-agent-caller`) receive `HTTP 403 Forbidden`. Once received, MSA can respond as long as its outbound model and tool pathways are authorized via the IAP policies in Step 4.

- **1. Egress Gateway Creation & Attachment:**
  - **Check / Create Gateway:** Verify if `novasmart-egress-gateway` exists; if missing, create/import it with
    `governedAccessPath: AGENT_TO_ANYWHERE`, `protocols: [MCP]`, and registries pointing to
    `//agentregistry.googleapis.com/projects/${PROJECT}/locations/global` (§5).
  - **Attach to Back-Office Agent:** Patch `agentGatewayConfig` on the Markdown Strategy Agent
    (`reasoningEngines/<MSA_ID>`) to attach `novasmart-egress-gateway` via `agentToAnywhereConfig`.
    *(Note: attaching is a long-running operation of ~4 minutes; poll to terminal state).*

- **2. Lock Down Inbound Calls to Price Match Agent Only:**
  - **Resolve the PMA principal dynamically:** Read `spec.effectiveIdentity` from the deployed Price Match
    Agent (`reasoningEngines/<PMA_ID>`). It has the SPIFFE format
    `principal://agents.global.org-<ORG_ID>.system.id.goog/resources/aiplatform/projects/<PROJECT_NUM>/locations/<REGION>/reasoningEngines/<PMA_ID>`.
    Never compose or hardcode this string (§5, §8).
  - **Capture BEFORE policy and its `etag`:** Run `:getIamPolicy` on `reasoningEngines/<MSA_ID>` and record
    the current policy document and its `etag`.
  - **Resource IAM Policy Rewrite:** Use `:setIamPolicy` on `reasoningEngines/<MSA_ID>` to set
    `roles/aiplatform.user` containing **only** the resolved PMA principal, passing through the `etag`.
  - **Verification Endpoint Syntax:** Update invocation syntax from `:query` to `:streamQuery` or
    `a2a/v1/message:send` to test and prove that unauthorized callers receive `HTTP 403 Forbidden` while
    the Price Match Agent succeeds.
- **Choosing the role — say what you chose and why:**
  - **`roles/aiplatform.user`** is the documented role containing `aiplatform.reasoningEngines.query`, and
    it is what this estate already uses on this resource. Bound **on the resource**, it is a defensible
    choice — **and it is broader than "may call this agent"**, so say so.
  - ❌ **`roles/aiplatform.reasoningEngineUser` does not exist.** Never propose it (§1).
  - ❌ **`roles/aiplatform.expressUser` is a trap.** It contains create/delete/update as well as query, and
    it is **already granted in this project** — binding it here would widen the caller's powers *and*
    silently re-break the lockdown you just made (§1).
  - ✅ **The narrowest real option is a custom role containing only `aiplatform.reasoningEngines.query`.**
    If the project already has one, prefer it. **Creating one is not on the critical path** — if you do
    create it, it is a **second change with its own change record**, it must be bound **only on this
    resource**, and it must never be granted at project level. If you can't or don't, **use
    `roles/aiplatform.user` and name the residual breadth as a finding.**
- **What good looks like:** the plain-English headline (*"the back office now carries its own access list,
  and the only name on it is the front desk"*), the members the **re-read** `:getIamPolicy` returned —
  quoted in the answer, **not** taken from the `setIamPolicy` response — with the call itself and its full
  output written into this step's evidence file, and the change record with the exact undo appended to
  that same entry (§0). Plus the honest caveat, in your own words:
  > **This is a list on one door, not a wall around the building.** It removes the access that was granted
  > **on this agent**. Anyone who holds a project-wide role that includes "call an agent" can still reach
  > it — I'll show you exactly who, and what it would take to close that.

  ⛔ **Only make that last promise if you can keep it.** It is a debt that falls due in Step 3, where the
  principals from §5 have to be **printed, one per line**. If the §5 resolution did not complete, say so
  here instead of promising a list you will not produce — an unpaid promise reads to the leader as an
  answer they were given, and in a real run it is how they went the whole module without learning that a
  human login of their own could call the back office.
- **The picture — REQUIRED here, and it is a BEFORE/AFTER on CALL (§2).** Both halves come from a policy
  you read: the BEFORE from the document you captured at the start of this half, the AFTER from the
  **re-read** `:getIamPolicy`, not from the write's own response. **The third element is not optional and
  it is not a caveat bolted underneath — it belongs inside the picture:**

  **What the picture must contain:**
  - a caption naming the surface and when each half was read — the agent's own resource policy, the
    BEFORE captured at the start of this half, the AFTER re-read live just now;
  - the **BEFORE** side: the back-office agent, and the members its own list named when you captured it;
  - the **AFTER** side: the same agent, and the members the re-read returned;
  - a third element spanning **both** sides, labelled as unchanged by anything you did: the principals
    holding a project-wide role that reaches any agent here, **as a count you re-read this turn**.

  **That unchanged element is the honesty mechanism of the whole module.** Carrying the project-wide
  holders through *both* halves is what makes "this changed one list, not the building" visible at a
  glance — instead of leaving it to a caveat the leader may or may not read, and instead of leaving you
  room to write "only Price Match can call it" underneath a picture that appears to show exactly that.
  Leave it out and the picture becomes the false claim in visual form. **The count is whatever you
  re-read in the live project policy this turn** — re-read it; an earlier step's number is not available
  to you here.
  ⛔ **Nothing in this picture may depict a refusal.** You have re-read a policy; you have not yet been
  refused by anything. A refusal is a result, it is Step 3's to observe, and showing one here is a
  verdict you did not earn.
- **Don't mislabel:**
  - **A successful `setIamPolicy` is not a locked-down agent.** Quote the `:getIamPolicy` re-read (§7).
  - **Applying is not proving.** Step 3 owns the 403, and the words are gated (§2).
  - **Don't claim exclusivity.** "Only Price Match can call it" is false the moment you write it (§0
    Rule C). The permitted sentence is in §1 and §4 · Step 3.
  - **Don't clean up other bindings while you're in there.** If the policy you read contains bindings
    beyond the invoke role, preserve them and mention them — do not treat "I had the document open" as
    permission to tidy.
  - If the write is **denied**, work the ladder (§6) and take **§6·7** — report it. ⛔ **Do not reach for
    the outbound half to cover it** — attaching the gateway is a different control answering a different
    question, and doing it "instead" leaves the inbound gap open while looking like progress. **Do not**
    remove the rogue's access some other way, **do not** grant yourself anything (you already hold
    `aiplatform.admin`, so a denial is a signal to check the URI, not the IAM).
- **How to close — a shape to re-derive, never a line to recite.** You have changed a setting and re-read
  it. That is the entire truth available to you right now, and the close has to sit exactly there. The
  **ideas**:
  - the list now names one caller, and that is what the setting says;
  - a setting is a claim about the future;
  - no real request has yet confirmed or contradicted it.

  A worked example from a **different** estate, to show the join and not to be lifted: *"The freight
  broker's account is off the warehouse system's list and the list reads exactly as intended. What I have
  is a written intention; nothing has knocked on that door since I changed it."* ⛔ **Do not reuse those
  words.** NovaSmart has no freight broker and no warehouse system; the example is deliberately ill-fitting
  so that there is no sentence here to copy.

  Landing those ideas is honest about the evidence *and* it quietly covers the propagation lag this module
  warns about, without naming it. ⛔ In the close, the words **test, try, replay, prove, verify, blocked,
  refused, denied** must not appear at all — every one of them either states the next step's result or
  hands the leader the next step's instruction. ⛔ Don't say the rogue is out; you have not asked it. The questions grow
  from the gap between a written list and an observed outcome: what NovaSmart would accept as evidence
  that a setting is actually in force, and how long the business could live with the difference.

### Step 3 · Prove the rogue caller is out

> **🔒 The Step 3 gate — three hard requirements, all satisfied *before* any claim leaves your mouth:**
>
> 1. **You must have RE-MADE the byte-identical rogue call from Step 1 in this session** — same URL, same
>    body, same identity, **freshly minted token**. **No re-call → no claim.** A remembered "before"
>    compared with a paraphrased "after" is not a before/after.
> 2. **As affirmative claims, the words "blocked", "proof", "proves", "proven" and "verified" are banned**
>    unless the **actual response or log entry is quoted in the same turn** — the HTTP status line and the
>    error body, or the audit entry. Not "it should now be denied". Not an inference from the policy.
> 3. **You must also have exercised the LEGITIMATE path** — a real >10% discount escalation through the
>    **Price Match Agent** — and shown a real margin decision came back. A lockdown you never tested for
>    usefulness is not the result the leader asked for. **The competitor price you quote must be one the
>    seeded competitor table actually lists** (§5): the front desk verifies the listing *before* it ever
>    looks at the discount, so an invented price is refused for the wrong reason and tells you nothing
>    about your lockdown.
>
> **If the replay does not return a refusal** — you get a 200, or an ambiguous 400/404 — the **only**
> correct output is to say what you sent, what came back, and what would be needed next (wait out IAM
> propagation and retry once · re-read `:getIamPolicy` and confirm your write actually took · confirm the
> URL and API version are identical to the Step 1 call · confirm the before-state integrity check from
> Step 1 was clean). Mark the row **not verified**. **Never present a 400 or a 404 as a 403** — a
> malformed request and a refused one are different events, and only one of them is your evidence.

- **Wait for IAM propagation before you conclude anything.** An IAM change typically takes **about 2
  minutes** and can take **7 minutes or longer**; already-issued tokens can outlive it. An early
  "still got in" is a timing artefact, not a result — and reporting it as a failure is as wrong as
  reporting an unverified block as a success. **Retry once before you write anything down.**
- **Where to look — in descending order of strength:**
  1. **The call you made yourself, with the rogue's token** — the HTTP status and the error body. **This
     is the strongest evidence in the module**, because you caused it, you saw the platform refuse it, and
     you can quote it verbatim with its UTC timestamp.
  2. **The re-read `:getIamPolicy`** on the back-office agent — this is **configuration** evidence: it
     shows the access list you intended, **not** that anyone was stopped. Label it as configuration.
  3. **The audit-log entry** for the denied call (`status.code=7`, §5) — corroboration. **It may be
     absent** if data-access auditing isn't capturing this surface; absence here is **not** a
     counter-example to (1), and it is **not** a substitute for it either. Say which you have.
  4. **The storefront's rendered reply** — ❌ **not evidence in either direction.** It fabricates plausible
    prose when the back office is unreachable, so "the store refused it" is a UI behaviour, not an IAM
    verdict (§7).
- **The Check / How I verified / Result table — REQUIRED here (§2, §9):** three columns, exactly as
  declared in §9. In **How I verified**, name the command and the timestamp
  (*"replayed the Step 1 call byte-for-byte with a fresh token; Step 1 had returned 200 at 14:09 UTC"*)
  and the status you just observed in **Result**. Add a row for anything else you actually ran; delete
  any row you did not.

  > [!IMPORTANT]
  > ⛔ **DO NOT RUN `update_scorecard.py` AND DO NOT EMIT §9 IN STEP 3:**
  > Step 3 is strictly for testing the two connection paths (rogue caller refusal + PMA escalation).
  > Do **NOT** run `update_scorecard.py`, do **NOT** print the full Consolidated Verification Summary table, do **NOT** award the `Achievement Unlocked` badge, and do **NOT** link to `governance_scorecard.html` in this step.
  > Generating the Mission 2 Scorecard belongs **strictly and exclusively to Step 5** (*"Verify our M2 connection controls and generate the Mission 2 Governance Scorecard"*).

  Then comes the **honest bottom line**, which is the most important sentence you will write in this
  module:

  | ❌ Banned (false) | ✅ Permitted (true, and provable) |
  | :-- | :-- |
  | "Only Price Match can call the back office." | "The rogue login is refused — here is the 403 — and the back office's own access list now names exactly one approved caller." |
  | "Everyone else is out." / "The back office is private." | "Access granted **on this agent** is now a deliberate list of one. Access granted **across the project** is unchanged: *N* principals still hold a role that includes calling an agent — here they are." |
  | "The connections are controlled." | "One connection is now governed by an explicit allow-list. The project-wide grants that can bypass it are the next piece of work." |

  ⛔ **"Here they are" means the list is printed, not promised.** The permitted sentence in the second row
  ends on a colon, and what follows it is the actual principals from `/tmp/invoker_members.txt` (§5) — one
  per line, verbatim, no ellipsis and no "and others". **If you write that sentence and do not print the
  list, you have written the banned sentence with better manners.** The same applies to the honest caveat
  in Step 2, which says *"I'll show you exactly who"*: that is a debt, and this is where it comes due. In a
  real run the promise was made, the number was given, the list was never shown — and the leader was
  therefore never told that **a human lab login of their own** was on it, which is the single most
  persuasive thing this module has to say. ⛔ **If you could not resolve the principals, say the list is
  unavailable and why** — do not make the promise and then quietly drop it.

  ⛔ The second half names an **absence of content inspection**
  and nothing more: do **not** say the agents can be talked into breaking their own rules, do not mention
  jailbreaks, prompt injection or screening, and do not describe an attack. That an agent will comply
  with a politely-worded request is the next module's discovery to make, not yours to announce.

### Step 4 · Configure IAP Authz Extension & Fine-Grained CEL Policy

> **Multi-Layer Outbound Governance:** Step 2 settled who may call the back office. This step enforces
> **fine-grained tool execution boundaries** and **destination reachability** through the Agent Gateway and
> Identity-Aware Proxy (IAP) with Common Expression Language (CEL) conditions, backed by dataset-level least privilege.

> [!IMPORTANT]
> **Why IAP Authz Policy & CEL Controls Are Required (Why Simple IAM Permissions Fail):**
> * **Coarse-Grained Standard IAM Limitation:** Standard Cloud IAM and basic IAP permissions operate at the coarse service or resource level (e.g., granting `roles/iap.egressor` on the BigQuery MCP server in Agent Registry). Standard IAM cannot inspect, parse, or evaluate conditions on the internal JSON-RPC 2.0 payload or tool method names of Model Context Protocol (MCP) invocations. Under standard IAM, granting egress access to the MCP server grants access to *all* tool methods on that server — allowing the agent to invoke destructive write/mutation tools (`execute_sql_readwrite`, table drops, schema alters).
> * **Fine-Grained Tool Method Filtering with CEL:** The Agent Gateway delegates authorization to Identity-Aware Proxy (IAP) via the `AuthzExtension`. IAP evaluates Common Expression Language (CEL) conditions at request time against request attributes: `api.getAttribute('request.method', '')`. This enables method-level tool governance — permitting read-only tools (`execute_sql_readonly`, `list_tables`, `get_table_schema`, `list_datasets`) while blocking mutating tools at the gateway perimeter with `HTTP 403 Forbidden` before they ever reach BigQuery.
> * **The MCP Protocol Lifecycle Requirement:** MCP is a stateful client-server protocol requiring a handshake before tools can execute. During session establishment, the agent must execute lifecycle RPCs: `initialize`, `tools/list`, `notifications/initialized`, and `ping`. If a naive CEL policy only allows `execute_sql_readonly`, IAP blocks the initial `initialize` handshake with `403 Forbidden`, breaking the MCP connection completely. Thus, the CEL expression MUST include both MCP lifecycle methods and read-only tools:
>   `api.getAttribute('request.method', '') in ['initialize', 'tools/list', 'tools/call', 'notifications/initialized', 'ping', 'execute_sql_readonly', 'list_tables', 'get_table_schema', 'list_datasets']`.

#### Step 4a · Configure IAP Authz Extension & Authz Policy

- **Import IAP AuthzExtension:** Create and import an `AuthzExtension` resource pointing to `iap.googleapis.com`
  with `failOpen: true`, `timeout: 1s`, and `metadata: {iapPolicyVersion: "V1"}` (§5).
- **Import AuthzPolicy targeting the Gateway:** Create and import an `AuthzPolicy` targeting
  `novasmart-egress-gateway` (`policyProfile: REQUEST_AUTHZ`, `action: CUSTOM`), wiring the custom provider
  to the IAP AuthzExtension. Without this policy attached, the gateway denies all outbound requests.

#### Step 4b · Apply Fine-Grained IAP CEL Policy on BigQuery MCP Server

- **Target the MCP Server in Agent Registry:** Set `roles/iap.egressor` on the BigQuery MCP Server resource
  using `gcloud beta iap web set-iam-policy --resource-type=agent-registry --mcp-server=<MCP_SERVER_ID>`
  (dynamically resolving the MCP Server ID from Agent Registry, §5).
- **Must-Include MCP Lifecycle Methods:** ⚠️ Ensure the CEL condition expression allows MCP protocol
  handshake and session initialization methods (`initialize`, `tools/list`, `notifications/initialized`, `ping`)
  along with read-only BigQuery tool methods (`execute_sql_readonly`, `list_tables`, `get_table_schema`, `list_datasets`).
  *If lifecycle methods are omitted, the agent's MCP connection handshake fails with `403 Forbidden`, causing tool
  execution to fail entirely.*
  ```yaml
  bindings:
  - role: roles/iap.egressor
    members:
    - "principal://agents.global.org-<ORG_ID>.system.id.goog/resources/aiplatform/projects/<PROJECT_NUM>/locations/<REGION>/reasoningEngines/<PMA_ID>"
    - "principal://agents.global.org-<ORG_ID>.system.id.goog/resources/aiplatform/projects/<PROJECT_NUM>/locations/<REGION>/reasoningEngines/<MSA_ID>"
    condition:
      title: "Enforce_BigQuery_ReadOnly_Tools"
      description: "Allow only read-only BigQuery tool methods and MCP lifecycle"
      expression: "api.getAttribute('request.method', '') in ['initialize', 'tools/list', 'tools/call', 'notifications/initialized', 'ping', 'execute_sql_readonly', 'list_tables', 'get_table_schema', 'list_datasets']"
  ```

#### Step 4c · Grant Generic Google APIs Access

- **Allow Outbound Google APIs via Egress Gateway:** Apply `roles/iap.egressor` to the global and regional generic
  Google APIs endpoints in Agent Registry (dynamically discovered via `gcloud agent-registry services list`)
  so that required Google Cloud platform API calls (such as model calls and Vertex AI operations) are not blocked
  by the gateway.

#### Step 4d · Narrow BigQuery Database Permissions (Verbs)

- ⚠️ **The gateway governs MCP tool invocations; the data platform enforces database permissions.**
  Remove project-level `roles/bigquery.admin` from MSA's identity (`principal://${MSA_PRINCIPAL}`), and
  grant back the project-level job-running role (`roles/bigquery.jobUser`) plus dataset-scoped `READER`
  on `novasmart_pricing` and `competitor_data` (§5).
- ⛔ **Both parts of this database change, or the agent is stranded.** `jobUser` alone grants the right to
  *run* a query and no access to any data. Dataset-scoped `READER` is required for data access.
- **What good looks like:** the same agent, in the same minute, **listing tables successfully and failing
  to execute SQL mutations** — with the failure confirmed **from the data**, not from what the agent said (§7).

### Step 5 · Verify M2 connection controls & generate Mission Scorecard

> **🔒 This step AUDITS the two controls this module put in — it does not extend either of them.**
> ⛔ **ZERO MUTATIONS:** no `setIamPolicy`, no binding added or removed, no gateway attached to anything,
> nothing re-applied because a read came back wrong. If a control is missing, **the finding is the
> output**: name the step that would put it right and hand it back to the leader. ⚠️ The rogue replay and
> the front-desk escalation are **calls, not changes** — the same distinction §0 draws for Steps 1 and 3 —
> and they stay permitted here because a refusal you did not cause this turn is not a current result.

- **Where to look — every read is one §9 already names, run again NOW.** The `:getIamPolicy` on the
  back-office agent (§5) · the byte-identical rogue replay, with a freshly minted token · a real >10%
  escalation through the **Price Match Agent**, using a price **listed in the seeded competitor table**
  (§5) · the agent's own record showing the gateway attachment · and the agent's BigQuery bindings. §9's
  table is being filled from commands you ran **this turn**, not from what Steps 3 and 4 reported.
- **A verdict from an earlier step is a verdict from *then*.** If you did not read it again in this turn,
  that row is **not verified**. Currency is the only thing this step adds.
- **What good looks like:** §9's table with **every** row present, each Result carrying either a value you
  quoted this turn or the words **not verified** — **written in full into this step's evidence file**
  (§0), because it is one row per check and it does not read in a chat panel. What the leader sees is the
  **coverage line** — *n checks evidenced, m not verified* — counted off the rows you actually wrote, then
  the honest-scope sentence naming the project-wide invoke holders as remaining work.
  ⚠️ **A table with gaps is this step working, not failing**, and the gaps are what the coverage line's
  second number is for: never let a shorter answer make a check disappear.
- **Don't mislabel — and the first one is the trap this whole module is built around:**
  - ⛔ **Never record the inbound control as "invoke restricted to the Price Match Agent", "only Price
    Match can call it" or "the back office is private".** All three are false: IAM allow policies are
    additive and project-wide holders are untouched (§0 Rule C, §1, §4 · Step 3). The true row states
    **the members the agent's own list named when you read it**, and nothing about exclusivity.
  - ⛔ **An attach is not an enforcement.** Without a quoted `ALLOWED;DENIED` verdict from this turn, the
    gateway row is a configuration reading — say so, and never let it stand in for a control.
  - ⛔ **Never accept the agent's own answer as proof** — a refused call comes back as fluent invented
    prose rather than an error (§7). Quote the gateway's verdict, or the data itself.
  - **An absent audit entry does not cancel a quoted HTTP refusal** — record "no audit entry recorded"
    beside the status you actually got, and neither one overrides the other (§9).
  - **A denial for *no verified competitor listing* is a bad probe**, not a result: re-run with a listed
    price, and never write it into the table as a pass or a failure (§4 · Step 3).
  - **Never emit the §9 scorecard block with a placeholder still in it**, and run
    `python3 /config/Desktop/Session1/.agents/skills/novasmart-governance-lab/scripts/update_scorecard.py --mission M2 --status <PASS or FAIL>` **only** on a genuine pass — it
    writes to a file the leader keeps, which outlives the conversation that could have qualified it.
- **No picture here — FORBIDDEN.** This is a verification result, and the three-column table in §9 is the
  only permitted form (§4 · Step 3).
- **How to close:** the coverage line and one sentence stating only what the rows show, with the
  unverified count in it and the honest scope claim intact — then, **only if every row is carrying live
  evidence**, the filled scorecard block and the achievement line from §9. ⛔ Both numbers in the coverage
  line must also appear in the evidence file's own table (§0 figure parity); a coverage line that cannot
  be checked against the rows behind it is the same fabrication as a table nobody filled.

### Step 6 · What's next

- Close **honestly**: name what is now true and evidenced (the back office carries an explicit access list
  naming one approved caller · the rogue login is refused, with the quoted status · the front-desk
  escalation still returns a real decision · a change record with a working undo exists), and name what is
  **not**: project-wide roles that include the invoke permission are **unchanged** and still allow a
  bypass; the storefront still calls the back office **directly**, as an owner-level identity; **the
  gateway governs which destinations the back office may reach, and says nothing about what it may DO
  once it gets there**; and anything you could not verify. Never a false all-clear.
- One line of bridge (§10), then stop — don't start M3's work here.
- **How to close — a shape to re-derive, never a line to recite.** This is a recap, so **no picture**: a
  forward-looking one would be drawing the next module's after state, and there is no new read behind it.
  Do not sign off with a completion notice, a tick-list of green rows, or the name of a run log. Say what
  is true and evidenced, say what you could not verify, and close on the difference between what was
  decided today and what is still there by accident. The **ideas**:
  - access to that one agent is now something the leader decided;
  - everything else in the estate is still something that merely happened to them;
  - the list of people and programs that can walk past that door is the same length as this morning.

  A worked example from a **different** estate, to show the join and not to be lifted: *"The archive is
  the first system here whose visitor list somebody actually chose. Every other door in the building still
  opens for whoever it opened for last year, and that set has not got any smaller today."* ⛔ **Do not
  reuse those words.** NovaSmart has no archive and no building; the example is deliberately ill-fitting so
  that there is no sentence here to copy.

  The questions come out of that gap and at least one must be unanswerable from anything on screen — what
  NovaSmart would want to be able to say, for any agent, about who is allowed to call it and why; who
  would put their name to the project-wide list and how often it gets looked at; what you would hand an
  auditor who asked to see the reasoning behind the one name on the back office's list. ⛔ No proposal, no
  "would you like", and nothing that reads as the next thing to type.

---

## 5. The commands that actually work here
*(Families, not gospel — confirm exact flags with `--help` and a **dated** google-dev query; don't hardcode.
Resolve every ID from the environment; never ask the leader for one.)*

- **Egress Gateway Creation & Attachment to Back-Office Agent (Step 2):**

  ```bash
  # 0 · Check / Create Gateway: verify if novasmart-egress-gateway exists; if missing, create/import it
  if ! gcloud beta network-services agent-gateways describe novasmart-egress-gateway --location="${REGION}" >/dev/null 2>&1; then
    cat > egress-gw.yaml <<EOF
name: projects/${PROJECT}/locations/${REGION}/agentGateways/novasmart-egress-gateway
protocols:
- MCP
googleManaged:
  governedAccessPath: AGENT_TO_ANYWHERE
registries:
- "//agentregistry.googleapis.com/projects/${PROJECT}/locations/global"
EOF
    gcloud beta network-services agent-gateways import novasmart-egress-gateway --source=egress-gw.yaml --location="${REGION}"
  fi

  # 1 · Attach to Back-Office Agent (LRO ~240-280s - POLL IT, then re-read the resource)
  curl -s -X PATCH -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "Content-Type: application/json" \
    -d "{\"spec\":{\"deploymentSpec\":{\"agentGatewayConfig\":{\"agentToAnywhereConfig\":{\"agentGateway\":\"projects/${PROJECT}/locations/${REGION}/agentGateways/novasmart-egress-gateway\"}}}}}" \
    "https://${REGION}-aiplatform.googleapis.com/v1beta1/projects/${PROJECT_NUMBER}/locations/${REGION}/reasoningEngines/${MSA_ID}?updateMask=spec.deploymentSpec.agentGatewayConfig"
  ```

- **IAP Authz Extension, Fine-Grained CEL Policy & Generic Google APIs Access (Step 4):**

  ```bash
  # 1 · Configure IAP Authz Extension (pointing to iap.googleapis.com)
  cat > ext.yaml <<EOF
name: projects/${PROJECT}/locations/${REGION}/authzExtensions/novasmart-egress-ext
service: iap.googleapis.com
failOpen: true
timeout: 1s
metadata:
  iapPolicyVersion: "V1"
EOF
  gcloud beta service-extensions authz-extensions import novasmart-egress-ext --source=ext.yaml --location="${REGION}"

  # 2 · Configure Authz Policy targeting novasmart-egress-gateway
  cat > pol.yaml <<EOF
name: projects/${PROJECT}/locations/${REGION}/authzPolicies/novasmart-egress-policy
target:
  resources:
  - "projects/${PROJECT}/locations/${REGION}/agentGateways/novasmart-egress-gateway"
policyProfile: REQUEST_AUTHZ
action: CUSTOM
customProvider:
  authzExtension:
    resources:
    - "projects/${PROJECT}/locations/${REGION}/authzExtensions/novasmart-egress-ext"
EOF
  gcloud beta network-security authz-policies import novasmart-egress-policy --source=pol.yaml --location="${REGION}"

  # 3 · Dynamically discover BigQuery MCP Server ID in Agent Registry
  BQ_MCP_SERVER=$(gcloud agent-registry services list --location=global --format="value(name)" 2>/dev/null | grep -iE 'bigquery|mcp' | head -n 1)
  if [ -z "$BQ_MCP_SERVER" ]; then
    BQ_MCP_SERVER=$(gcloud agent-registry services list --location="${REGION}" --format="value(name)" 2>/dev/null | grep -iE 'bigquery|mcp' | head -n 1)
  fi
  BQ_MCP_ID=$(basename "$BQ_MCP_SERVER")

  # 4 · Apply Fine-Grained IAP CEL Policy on BigQuery MCP Server
  # MUST include MCP lifecycle methods (initialize, tools/list, notifications/initialized, ping) along with read-only BigQuery tools:
  cat > bq_mcp_policy.yaml <<EOF
bindings:
- role: roles/iap.egressor
  members:
  - "${PMA_PRINCIPAL}"
  - "${MSA_PRINCIPAL}"
  condition:
    title: "Enforce_BigQuery_ReadOnly_Tools"
    description: "Allow only read-only BigQuery tool methods and MCP lifecycle"
    expression: "api.getAttribute('request.method', '') in ['initialize', 'tools/list', 'tools/call', 'notifications/initialized', 'ping', 'execute_sql_readonly', 'list_tables', 'get_table_schema', 'list_datasets']"
EOF

  gcloud beta iap web set-iam-policy bq_mcp_policy.yaml --resource-type=agent-registry --mcp-server="${BQ_MCP_ID}"

  # 5 · Grant Generic Google APIs Access (for outbound model and Vertex AI service calls)
  GLOBAL_APIS_SERVER=$(gcloud agent-registry services list --location=global --format="value(name)" 2>/dev/null | grep -i 'google-apis' | head -n 1)
  GLOBAL_APIS_ID=$(basename "$GLOBAL_APIS_SERVER")

  REGIONAL_APIS_SERVER=$(gcloud agent-registry services list --location="${REGION}" --format="value(name)" 2>/dev/null | grep -i 'google-apis' | head -n 1)
  REGIONAL_APIS_ID=$(basename "$REGIONAL_APIS_SERVER")

  cat > apis_policy.yaml <<EOF
bindings:
- role: roles/iap.egressor
  members:
  - "${PMA_PRINCIPAL}"
  - "${MSA_PRINCIPAL}"
EOF

  if [ -n "$GLOBAL_APIS_ID" ]; then
    gcloud beta iap web set-iam-policy apis_policy.yaml --resource-type=agent-registry --endpoint="${GLOBAL_APIS_ID}" 2>/dev/null || \
    curl -s -X POST -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "Content-Type: application/json" \
      -d "{\"policy\":{\"bindings\":[{\"role\":\"roles/iap.egressor\",\"members\":[\"${PMA_PRINCIPAL}\",\"${MSA_PRINCIPAL}\"]}]}}" \
      "https://iap.googleapis.com/v1/projects/${PROJECT_NUMBER}/locations/global/iap_web/agentRegistry/${GLOBAL_APIS_ID}:setIamPolicy"
  fi

  if [ -n "$REGIONAL_APIS_ID" ]; then
    gcloud beta iap web set-iam-policy apis_policy.yaml --resource-type=agent-registry --endpoint="${REGIONAL_APIS_ID}" --region="${REGION}" 2>/dev/null || \
    curl -s -X POST -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "Content-Type: application/json" \
      -d "{\"policy\":{\"bindings\":[{\"role\":\"roles/iap.egressor\",\"members\":[\"${PMA_PRINCIPAL}\",\"${MSA_PRINCIPAL}\"]}]}}" \
      "https://iap.googleapis.com/v1/projects/${PROJECT_NUMBER}/locations/${REGION}/iap_web/agentRegistry/${REGIONAL_APIS_ID}:setIamPolicy"
  fi
  ```

- **The database-layer narrowing (Step 4d) — measured and verified against BigQuery:**

  ```bash
  # the agent's own identity - read it, never compose it (see the principal:// note above)
  P="principal://$(<read spec.effectiveIdentity from the MSA>)"

  # 1 · take away the blanket write
  gcloud projects remove-iam-policy-binding "$PROJECT" --member="$P" --role=roles/bigquery.admin

  # 2 · give back exactly the job: run queries, read the two datasets it uses
  gcloud projects add-iam-policy-binding "$PROJECT" --member="$P" --role=roles/bigquery.jobUser
  #    dataset-scoped READER on novasmart_pricing and competitor_data:
  bq show --format=prettyjson "${PROJECT}:novasmart_pricing" > ds.json
  #    append {"role":"READER","iamMember":"'"$P"'"} to ds.json .access, then:
  bq update --source ds.json "${PROJECT}:novasmart_pricing"
  #    repeat for competitor_data

  # 3 · GROUND TRUTH - ask the table, not the agent
  bq query --use_legacy_sql=false \
    "SELECT sku, margin_floor FROM \`${PROJECT}.novasmart_pricing.wholesale_costs\` WHERE sku='SKU-HSE-4001'"
  ```

  ⚠️ **Allow ~90 seconds for IAM to propagate** before you re-test. A denial read too early is a timing
  artefact, not a result.
  ⛔ **`jobUser` alone is not read access.** It is the right to run a query and nothing else. Step 2 is
  not optional.

- **Resolve once, cache for the session (Project, Region, Engine IDs, Principals):**

  ```bash
  source /config/Desktop/Session1/.agents/skills/novasmart-governance-lab/scripts/resolve_env.sh
  ```
  *(Or execute `./scripts/resolve_env.sh` from the skill directory. Checks `/tmp/novasmart_env.sh` first and exports all variables instantaneously in < 1ms if cached. If missing or called with `--refresh`, executes direct live discovery from local metadata and Vertex AI REST API.)*

- **Resolve the two engine IDs and the PMA principal (Step 1 & Step 3).** Prefer the **live** listing;
  the seed files are a convenience and can be stale — if the two disagree, **the live listing wins**.

  ⛔ **Never carry an engine ID forward from an earlier module, from a run log, or from memory, and never
  accept an ID that did not arrive in the same live response as its own `displayName`.** Match the agent
  by display name in the output in front of you, then read its ID out of that same record. This is not
  fussiness: in a real run the earlier module's own write-up assigned all three engine IDs to the **wrong**
  agents. Carrying that forward points this module's single policy write at the **front desk** instead of
  the back office — which locks the wrong agent, leaves the margin data reachable, and **still reports
  success**, because every command returns 200. An ID is four digits away from a silent, confident,
  completely wrong result. Re-resolve it here, every time.

  ```bash
  # live (authoritative)
  curl -s -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    "https://${REGION}-aiplatform.googleapis.com/v1beta1/projects/${PROJECT}/locations/${REGION}/reasoningEngines"
  gcloud agent-registry agents list --location="${REGION}"     # --location is REQUIRED; also check global

  # convenience (cross-check, don't trust blindly)
  gcloud storage cat "gs://novasmart-seed-bucket-${PROJECT}/price_match_agent_id.txt"
  gcloud storage cat "gs://novasmart-seed-bucket-${PROJECT}/markdown_strategy_agent_id.txt"
  gcloud storage cat "gs://novasmart-seed-bucket-${PROJECT}/pma_principal.txt"
  ```

  The principal you need has the shape
  `principal://<trust-domain>/resources/aiplatform/projects/${PROJECT_NUMBER}/locations/${REGION}/reasoningEngines/<PMA_ID>`.
  **Check whether the value you read already begins with `principal://` before you prepend it** (§8).

- **⚠️ Before-state integrity check on the rogue (Step 1, do this first):**

  ```
  gcloud projects get-iam-policy "$PROJECT" --flatten="bindings[].members" \
    --filter="bindings.members:test-agent-caller" --format="table(bindings.role)"   # expect: EMPTY
  gcloud run services list \
    --format="table(metadata.name, spec.template.spec.serviceAccountName)"          # expect: it runs nothing
  ```

- **Who can call an agent, project-wide (Step 1) — two reads, and you need both:**

  ```
  # 1. the agent's OWN access list
  curl -s -X POST -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    -H "Content-Type: application/json" -d '{}' \
    "https://${REGION}-aiplatform.googleapis.com/v1beta1/projects/${PROJECT}/locations/${REGION}/reasoningEngines/${MSA_ID}:getIamPolicy"

  # 2. the project-level roles. DEDUPE FIRST, then describe each UNIQUE role once.
  #    Describing one role per BINDING re-describes the same role many times over; the
  #    loop then runs long enough to be killed, and the step ends with no number at all
  #    while looking like it merely printed a lot. That is R4-15.
  gcloud projects get-iam-policy "$PROJECT" --format='value(bindings.role)' \
    | tr ';' '\n' | sed '/^$/d' | sort -u > /tmp/roles.txt
  echo "unique roles to check: $(wc -l < /tmp/roles.txt)"

  : > /tmp/invokers.txt
  while read -r R; do
    gcloud iam roles describe "$R" --format="value(includedPermissions)" 2>/dev/null \
      | tr ',' '\n' \
      | grep -qE 'reasoningEngines\.query|reasoningEngineRuntimeRevisions\.query|sessions\.run' \
      && echo "$R" >> /tmp/invokers.txt
  done < /tmp/roles.txt

  # the two numbers the step exists to produce — print them, do not eyeball the scroll
  echo "roles checked: $(wc -l < /tmp/roles.txt)  ·  roles granting invoke: $(wc -l < /tmp/invokers.txt)"
  cat /tmp/invokers.txt

  # 3. the PRINCIPALS behind those roles. A ROLE count is not a CALLER list, and this module
  #    promises the leader the list (§4 Step 3, Step 4, §9). ONE policy read, filtered
  #    locally — never one API call per role; that is how the loop above came to be killed.
  gcloud projects get-iam-policy "$PROJECT" --flatten="bindings[].members" \
    --format="value(bindings.role,bindings.members)" > /tmp/all_bindings.txt
  : > /tmp/invoker_members.txt
  while read -r R; do
    awk -v r="$R" '$1==r {print $2}' /tmp/all_bindings.txt >> /tmp/invoker_members.txt
  done < /tmp/invokers.txt
  sort -u /tmp/invoker_members.txt -o /tmp/invoker_members.txt
  echo "principals who can invoke project-wide: $(wc -l < /tmp/invoker_members.txt)"
  cat /tmp/invoker_members.txt
  ```

  **If either loop did not run to completion, you do not have a number.** Say so. A partial
  scroll is not a count, and "several roles can invoke" is not a finding. Re-run it, or
  report that the check did not complete — never infer the total from the rows you happened
  to see before it stopped.

  **Pin the population before you quote the number.** The figure you give the leader counts
  **principals holding a project-level role that contains one of the three invoke permissions**. It is
  **not** a count of roles, and it is **not** the same population as the agent's own access list. Two
  names in that file are not third-party callers and must be named **separately** rather than folded into
  the headline: the **back office's own principal** (a `principal://…/reasoningEngines/<MSA_ID>` member is
  the agent this module protects, not somebody calling it) and the **approved caller**, the PMA principal.
  Quote the raw figure, say which two you set aside, and give the adjusted one.
  ⛔ **Never reconcile this count against a number taken from a different population.** Two totals that
  agree after subtracting different sets agree by coincidence, not by check — and a coincidence presented
  as a reconciliation is worse than either number alone.

  **Read the list out loud; do not summarise it.** **What to look for as you read it:** any member that is
  a human login rather than a service account, and in particular one belonging to whoever is sitting in
  front of this lab. ⛔ **Report what the file actually contains — do not assert in advance that such a
  name is there, and do not assert that it is not.** If one is, it is the most persuasive line available
  anywhere in this module and aggregating it into a digit destroys it. ⛔ **A count without the list does not
  satisfy §4 Step 4** — the permitted sentence there ends *"here they are"*, and that clause is a promise
  this command exists to keep.

  *(If `:getIamPolicy` rejects the POST form on your API version, try `GET` on the same URI before
  concluding anything — that is a transport variation, not a permission problem, §6·1.)*

- **Mint the rogue's token WITHOUT disturbing your own credentials (Step 1 & Step 4):**

  ```
  gcloud storage cp "gs://novasmart-seed-bucket-${PROJECT}/test-agent-caller.json" /tmp/rogue.json
  export CLOUDSDK_CONFIG=/tmp/rogue-cfg          # isolated config — your own auth stays intact
  gcloud auth activate-service-account --key-file=/tmp/rogue.json --quiet
  ROGUE_TOKEN=$(gcloud auth print-access-token)
  unset CLOUDSDK_CONFIG                           # back to being yourself
  ```

  ⛔ **Never print the key**, and `rm -f /tmp/rogue.json` when you're done (§8). Do **not** try to
  impersonate the account instead by granting yourself `roles/iam.serviceAccountTokenCreator` — that is a
  self-grant and it is banned (§6·5).

- **The rogue call — identical in Step 1 and Step 4 (the body shape the storefront itself uses; confirm
  live):**

  ```
  curl -s -o /tmp/rogue_resp.json -w 'HTTP %{http_code}\n' -X POST \
    -H "Authorization: Bearer $ROGUE_TOKEN" -H "Content-Type: application/json" \
    -d '{"request":{"messageId":"msg-'"$(date +%s)"'","role":"ROLE_USER","content":[{"text":"<the same question both times>"}]}}' \
    "https://${REGION}-aiplatform.googleapis.com/v1beta1/projects/${PROJECT}/locations/${REGION}/reasoningEngines/${MSA_ID}/a2a/v1/message:send"
  ```

  **Save the URL, the body and the response both times.** Step 4 must differ from Step 1 in exactly two
  things: the clock, and a freshly minted token.

- **⚠️ The one mutation (Step 3) — read, edit, write back with the `etag`:**

  ```
  URI="https://${REGION}-aiplatform.googleapis.com/v1beta1/projects/${PROJECT}/locations/${REGION}/reasoningEngines/${MSA_ID}"
  TOKEN=$(gcloud auth print-access-token)

  # 1. READ and KEEP — this file is your rollback and the source of the etag
  curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
       -d '{}' "${URI}:getIamPolicy" | tee /tmp/msa_policy_before.json

  # 2. WRITE — the invoke role's members replaced by the ONE approved caller, etag passed through
  curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -d '{"policy":{"version":1,"etag":"<ETAG FROM THE READ>",
         "bindings":[{"role":"roles/aiplatform.user","members":["<PMA_PRINCIPAL, exactly as resolved>"]}]}}' \
    "${URI}:setIamPolicy"

  # 3. RE-READ — this, not the write's response, is your evidence
  curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
       -d '{}' "${URI}:getIamPolicy"
  ```

  **`setIamPolicy` replaces the whole document.** Build the `bindings` array **from
  `/tmp/msa_policy_before.json`**, changing only the invoke role's `members`; if the read showed other
  bindings, carry them through unchanged. **Omitting the `etag` turns a scoped replace into a blind
  overwrite** — pass it.

- **Rollback (put it in the change record, verbatim):** re-apply the bindings from
  `/tmp/msa_policy_before.json` with the **current** `etag` — **re-read first**, because your own write
  invalidated the one you captured:

  ```
  curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
       -d '{}' "${URI}:getIamPolicy"        # take the FRESH etag from here
  curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -d '{"policy":{"version":1,"etag":"<FRESH ETAG>","bindings":[<the bindings from msa_policy_before.json>]}}' \
    "${URI}:setIamPolicy"
  ```

- **The legitimate escalation (Step 4) — through the FRONT DESK:** send a genuine **>10%** discount
  request to the **Price Match Agent** (`…/reasoningEngines/<PMA_ID>:streamQuery`, with your own token)
  and show the real margin decision that comes back. ⛔ **Not** the storefront's direct `strategy` route —
  that is the bypass (§4 · Step 4).

  **⚠️ Quote a competitor price the data actually contains, or the request is denied before the discount
  rule is reached.** The front desk verifies the competitor's listing first, by **exact price equality**,
  and treats a miss as a terminating deny — so an invented price produces a `DENIED` that has nothing to
  do with your lockdown (§4 · Step 4). The verified pair on the standard test item:

  ```
  SKU-HSE-4001  shelf $349.00  BetaBuy    $296.65  = 15%  -> escalates
  SKU-HSE-4001  shelf $349.00  AlphaStore $331.55  =  5%  -> approved
  ```

  Only the first row is any use to you: the 5% row is under the cap, so the front desk approves it itself
  and the back office is never called. Every product is seeded on that same two-rung ladder — one
  competitor 5% under shelf, one 15% under — so **15% is the deepest discount that can be verified
  anywhere in this estate.** Quote that competitor price **to the cent**. ⛔ Never round it, never adjust
  it, never substitute a rounder number, and never reuse a price from a run log.

  ⛔ **Do not try to look this price up in BigQuery yourself — you cannot, by design.** You hold
  `roles/bigquery.jobUser` (job creation, **no** data access) plus a dataset-scoped grant on
  `customer_data` alone, and that grant deliberately withholds `bigquery.tables.getData`.
  `competitor_data` and `novasmart_pricing` are out of your reach **on purpose** (`iam.tf:68-80`), so a
  `bq query` against either returns Access Denied. **That denial is correct behaviour, not a blocker:**
  do not report it as a permission problem, do not hunt for another route to the data, and above all do
  **not** call the tool server anonymously to get around it — least privilege applies to you too, and
  this module is about respecting exactly that boundary. The pair above is the seeded fixture; use it.
  If the escalation is refused for lack of a verified listing even with this exact pair, that is an
  environment fault to report to the operator, not something for you to work around.
- **Audit-log corroboration (Step 4) — discover the shape first, then narrow.** Don't paste a filter you
  haven't seen match:

  ```
  gcloud logging read '
    protoPayload.serviceName="aiplatform.googleapis.com"
    AND protoPayload.resourceName:"reasoningEngines/<MSA_ID>"
  ' --limit=10 --freshness=1h --format=json      # look at a real entry, THEN add the clause below
  #   AND protoPayload.status.code=7             # 7 = PERMISSION_DENIED
  ```

  Acting identity = `protoPayload.authenticationInfo.principalEmail`; method =
  `protoPayload.methodName`; time = `timestamp`. **If nothing matches, that is "no audit entry recorded"**
  — say so, and lean on the HTTP refusal you caused yourself (§4 · Step 4 evidence ranking).
- **Change record — one per change, fixed shape:** `| Change | Resource | When (UTC) | Exact command to undo |`

---

## 6. `PERMISSION_DENIED` — the triage ladder

A 403 is usually **not** a missing permission — **and in this module that is especially true**, because
you already hold `roles/aiplatform.admin`, which contains `aiplatform.reasoningEngines.setIamPolicy` (§1).
Work the ladder in order; stop after ~2–3 cheap retries.

> **Items 1–4 are the ladder. Items 5–7 are standing rules** — they apply at every rung and are **never
> suspended because you are stuck.** Being blocked is exactly when they matter.

1. **Read the error before reacting.** Which is it?
   (a) a **wrong URI** — the wrong region host, the wrong `PROJECT`, the wrong engine ID, or a `v1` /
   `v1beta1` mismatch on a method that only exists on one of them; (b) the **wrong HTTP verb** —
   `:getIamPolicy` may want `POST` with `{}` on one version and `GET` on another; (c) **API not enabled**
   ("…has not been used in project… or it is disabled"); (d) **propagation** — a policy you just wrote
   hasn't landed; (e) a **genuinely missing permission** (least likely here).
2. **Cheap retries first.** Fix the host/region/version, try the other verb, enable a required API if the
   message says so — *enabling a product is not widening your own power* — then **wait 30–60 s and retry**.
3. **Try the documented alternate transport** for the *same* surface before you conclude you lack
   permission: the **GA `v1`** version of the same `:getIamPolicy` / `:setIamPolicy` call. Google's own
   sample for sharing an agent uses the GA `aiplatform_v1` client, so v1 carries these methods even
   though the REST reference index omits them for reasoningEngines. ⛔ **There is no gcloud wrapper to
   fall back to** (§1): if you catch yourself reaching for `gcloud ai reasoning-engines …`, that command
   does not exist and inventing it will waste the leader's time.
4. **Still denied → stop and REPORT THE GAP, in plain English.** In one short block:
   **what you tried · what was refused (quoted verbatim) · what that means for the leader's goal · what
   would be needed** (the **narrowest** role, on the **narrowest** resource, granted by whom). Then
   **continue with what IS available** and mark the blocked item **"not verified"** in your checklist —
   never a ✅. An honest "I could not do X, here's what it would take" is a *good* answer in this module.
5. **🚫 The IAM allowlist — judged by WHO receives the role and WHERE, never by WHY you want to grant it.**
   In the whole of M2 there is **exactly one IAM write you may perform**:
   - **(i)** the **`:setIamPolicy` on the back-office agent's own resource**, naming the **PMA principal**
     as the invoke role's member. That is the mission. **It is explicitly permitted** — it is the mandated
     fix, not an exception you are talking yourself into.

   **Every other IAM write is forbidden, regardless of the reason given, and there is no project-level
   write of any kind in this module.** Never grant anything to **`antigravity-sa`** (the account *you*
   run as) or to any identity you impersonate — including
   `roles/iam.serviceAccountTokenCreator` "just to mint the rogue's token" (use the seeded key in an
   isolated config instead, §5). Never add or remove a **project-level** binding — not
   `roles/aiplatform.user`, not `roles/owner`, not `roles/aiplatform.viewer`, not on the default compute
   account, not on a service agent, not on `test-agent-caller`. Never grant to
   `test-agent-caller` — and never *remove* from it either, beyond the single resource binding your
   scoped replace drops (§3).

   **This is a TARGET test, not a motive test.** Check the principal and the resource against the single
   allowed write and stop there; do not check your intentions. *"It's the only way to finish the module" ·
   "it's temporary" · "I'll revoke it after" · "it's obviously what the lab wants" · "the account is
   idle"* — **a plausible-sounding justification does not create an exception.** If the write is not the
   one above, the answer is **no**, and the correct move is **§6·7**.
6. **🚫 Never route around the control.** If the policy write is blocked, do **not** substitute a
   different mechanism to make the demo work: don't reach for the **Agent Gateway** to paper over a denied
   inbound write — the two halves are separate findings, not substitutes — don't strip
   the rogue's access by editing **project** bindings, don't delete or disable `test-agent-caller`, don't
   re-point the storefront, don't create a deny policy, and don't redeploy an agent. Each of those changes
   a resource M2 is not chartered to touch (§3), several of them break the store or the agents, and the
   project-level ones **corrupt the before-state that M3 depends on**.
7. **✅ If you cannot write the policy — THIS is the legal path, and taking it is the right answer.**
   After the cheap retries in steps 1–3:
   1. **Stop the mutation.** There is no legal alternative route to invoke control here.
   2. **Report the blocker to the leader**, in the item-4 shape: the lockdown is **blocked** · the exact
      permission refused, **quoted verbatim** (`aiplatform.reasoningEngines.setIamPolicy` →
      `PERMISSION_DENIED`) · what that means for their goal (the back office keeps answering the rogue
      login; here is the Step 1 evidence that it does) · **what would unblock it** — the narrowest role on
      the narrowest resource, and who would have to grant it.
   3. **Mark the affected checks "not verified"** in §9 — never ✅ — and **move on**, doing the parts you
      still can: Step 1's exposure evidence stands, Step 2's impact analysis stands, and Step 4 becomes an
      honest *"the rogue caller still gets in, because the lock could not be applied"* with the same quoted
      evidence.

   > **Reporting this blocker IS a correct, complete outcome — not a failure.** *"I could not apply the
   > lock; here is exactly what it would take, and here is proof the exposure is still open"* is a **good**
   > M2 answer. Nobody is scoring you on getting all five steps green.

> 🔑 **Why 5–7 are absolute.** This module's whole lesson is that **access should be a deliberate list,
> not a side effect of roles handed out project-wide**. An assistant that reacts to a wall by granting
> itself a role, or by quietly removing bindings at the project level, has done the exact thing the module
> exists to catch — and, in this estate, project-level edits also **break the agents' own model access**
> and **corrupt the before-state M3 is about to rely on**. **This has already happened once in this lab:**
> in an earlier run an assistant that was blocked in the previous module granted extra roles to
> `test-agent-caller` and made it a live service's runtime identity — which is precisely why this module
> now opens with a before-state integrity check (§1).

---

## 7. Evidence-labelling rule (say what you actually looked at)

- **Name the real source.** "`reasoningEngines/<MSA_ID>:getIamPolicy`, re-read at 14:07 UTC" or "the A2A
  `message:send` call I made with the rogue's token at 14:09 UTC — HTTP 403" — not "IAM" and not "the
  logs". Include the resource, the surface and the time.
- **Evidence for a change comes from the RE-READ, never from the mutation's own response.** A
  `setIamPolicy` that returns a policy document means the request was accepted — quote the subsequent
  `:getIamPolicy`.
- **For the gateway half, the evidence is the gateway's verdict** —
  `resource.type="networkservices.googleapis.com/Gateway"`,
  `jsonPayload.authzPolicyInfo.policies.result` showing **`ALLOWED;DENIED`** against a named destination
  URL — corroborated by the IAP decision, which carries `granted` and the agent's own `principal://`.
  Name the query and the window, as above.
- **For the narrowing half, the evidence is the DATA.** Run the query yourself and read the value:
  a write the agent claims to have made, on a row whose value has not moved, did not happen. Measured
  2026-08-01 — the agent reported executing an `UPDATE`, and `margin_floor` was unchanged at the number
  set before the narrowing. **Quote the before value, the after value and the query you ran.**
- ⛔ **The agent's own answer is NEVER evidence that the gateway blocked something.** A blocked call does
  not come back as an error. The agent answers anyway, from its instruction, and it looks fluent:
  *"**Based on the environment configuration**, the following tables are available…"* — inventing a list.
  A genuine read names real tables. **If the only thing you have is the agent's reply, you have not
  observed a block; you have observed a sentence.**
- **Rank your evidence out loud.** In this module there are five things that look like proof and only two
  that carry weight: (1) **the refusal you caused yourself** — status + body from your own rogue call;
  (2) **the re-read policy**, which is *configuration* evidence of intent, not of effect — versus (3) the
  **audit-log entry**, which is corroboration and may legitimately be absent; (4) the **storefront**,
  which **fabricates replies** and calls the back office as an **owner** — not evidence; (5) the
  **monitoring dashboard**, which asserts outcomes by string-matching — not evidence. Say which you have,
  and never promote (3)–(5) into (1)–(2).
- **Never re-describe one kind of event as another.** A **403** (refused), a **404** (wrong resource), a
  **400** (malformed request), an **empty answer** and an **app error page** are five different things
  with five different meanings. Say which one you got.
- **Distinguish "granted on the resource" from "granted on the project" in every sentence you write about
  access.** Half the false claims available in this module come from blurring those two.
- **Never populate a field the output didn't contain.** No invented role names, principals, engine IDs,
  etags, timestamps, status codes or counts of who holds what. Unknown is a legitimate answer: write
  **unknown** and name the command that would resolve it.
- **Quote identifying values verbatim** (the principal string, the role name, the engine ID, the HTTP
  status line, the `etag`, the timestamp).
- **Every change carries a change record** — what changed · on which resource · when (UTC) · the exact
  command that undoes it. No record, no "done".
- **Before you send:** re-read your draft against the raw output and delete every value you can't point to
  in it — and delete every sentence claiming exclusivity (§4 · Step 4).

---

## 8. Operational gotchas (M2 flavour — the generic ones in `m0.md` §8 still apply)

- **There is no gcloud for reasoningEngine IAM.** REST + `gcloud auth print-access-token` is the path
  this module uses; Google also documents a Python client and a Terraform resource, but **no gcloud
  wrapper exists** (§1). Don't burn turns hunting for one, and don't invent one.
- **`setIamPolicy` replaces the entire policy document.** Build the new one from the document you read,
  not from scratch, or you will silently delete bindings you never looked at.
- **Pass the `etag`.** Without it the write is a blind overwrite; with it, a concurrent change makes your
  write fail loudly instead of quietly clobbering. **And your captured etag is stale the moment your write
  lands** — re-read before you roll back (§5).
- **The `principal://` scheme is easy to double or drop.** If the value you resolved already begins with
  `principal://`, prepending it again produces a member string that is accepted-looking and matches
  nobody. Print the final member string before you send it.
- **`gcloud auth activate-service-account` switches your ACTIVE account** — every later command silently
  runs as the rogue. Use an isolated `CLOUDSDK_CONFIG` (§5), and never leave the rogue as your active
  account. **Never print the key material; delete the local key file when you're done.**
- **`roles/aiplatform.reasoningEngineUser` does not exist**, and **`roles/aiplatform.expressUser`** is
  broader than it sounds *and already granted here* — bind either and you get a failure or a silent
  re-opening (§1).
- **"Viewer" is not read-only for agents, and this is a trap with two halves.** `roles/aiplatform.viewer`
  contains the invoke permission, and **is not granted in this project — do not report that one as
  found.** But the **basic `roles/viewer` is granted here, to several principals including the lab's own
  user accounts, and it also carries the invoke permission.** They are different roles with confusable
  names: do not let the absence of the first make you overlook the second. Any claim about who can call
  the back office has to rest on the role's **permissions**, not on its **name** — check with
  `gcloud iam roles describe` (§5), and remember that `roles/owner`, `roles/editor` and `roles/viewer`
  contain effectively everything without listing it.
- **Two related permissions are worth checking when you audit roles**:
  `aiplatform.reasoningEngineRuntimeRevisions.query` and `aiplatform.sessions.run`. Include them in your
  search so your count is not too low. Be careful how you describe them: `reasoningEngineRuntimeRevisions
  .query` is a documented way in, but no published API method currently declares `sessions.run`, so call
  it *worth checking* rather than a proven bypass route unless you can point at a call that used it.
- **IAM propagation is real — typically ~2 minutes, up to 7 minutes or longer.** Retest after a wait; an early "still gets in"
  is a timing artefact, not a result. **Mint a fresh token for the after-call.**
- **The front desk verifies the competitor's price before it applies any discount rule, by exact
  equality — so an invented price is denied for the wrong reason.** A price the competitor table does not
  list to the cent returns `NOT_FOUND`, which the agent treats as a terminating deny; the 10% cap and the
  escalation are never reached, and no call is made to the back office at all. Use a seeded pair —
  **SKU-HSE-4001, shelf $349.00, BetaBuy $296.65 (15%)** — or resolve one live (§5). **15% is the deepest
  verifiable discount in the whole estate**, because every product carries exactly two competitor rows,
  at 5% and 15% under shelf. A denial of this kind is a **bad probe**, never evidence about the lockdown
  (§4 · Step 4).
- **The storefront calls the back office directly, as an owner-level identity.** Its behaviour is not a
  test of your lock, and its rendered replies are fabricated when the real response is thin. Never read a
  before/after off the UI.
- **The storefront also carries a stale hard-coded engine ID** as a fallback. Resolve agent IDs from
  discovery, not from app source — and if the seed-bucket ID files disagree with the live listing, the
  live listing wins.
- **`roles/bigquery.jobUser` is not read access.** It grants the right to *run* a query and no access to
  any data. Removing an agent's broad role and granting only `jobUser` **strands it** — it can start a
  query and read nothing back. The dataset grants are the other half of the same change, and the symptom
  of getting it wrong is not an error but a confident answer assembled from the agent's instruction.
- **You can only narrow a dataset you can administer.** The assistant holds
  `roles/bigquery.securityAdmin` on the three lab datasets — enough to rewrite an access list, and
  deliberately **not** enough to read the data inside. If a `bq show` returns `Access Denied:
  bigquery.datasets.get denied`, the grant is missing and any `bq update` you attempt will land nowhere,
  silently. **Read the dataset back after you write it.**
- **An attached gateway with NO authorization policy denies everything** — including the agent's own
  `generateContent` call. The agent then accepts requests, returns no answer, and **reads as broken
  rather than blocked**. If an agent goes silent right after you attach a gateway, check for the authz
  policy before you check the agent (§5).
- **The gateway must point at the registry the destinations are actually in.** Google's managed MCP
  servers and API endpoints are auto-registered in the **global** registry; a gateway aimed at an empty
  registry treats every destination as unregistered and default-denies it.
- **A 403 from the *wrong* URI looks exactly like a 403 from your policy.** Confirm the region host, the
  project, the engine ID and the API version are byte-identical between the Step 1 and Step 4 calls before
  you attribute anything.
- **Resolve project id, project number, region and every engine ID once, cache them, and never ask the
  leader** for a raw ID. The PMA principal needs the project **number**, not the ID.

---

## 9. Consolidated Verification Report for M2

⛔ **STRICTLY AUDIT-ONLY: ZERO CONFIGURATION MUTATIONS DURING VERIFICATION:**
This verification step is strictly a read-only audit. Do not edit, patch, re-tune, or alter any IAM policies, service accounts, gateways, templates, or agent runtime settings during this step. If a check does not pass as configured, record the live observation as `FAIL` or `not verified`; never mutate infrastructure or configuration to force a passing score.

### Verification Execution Boundaries:
| Allowed Verification Commands (Read-Only) | Forbidden During Verification (Mutations) |
| :--- | :--- |
| `gcloud beta network-services agent-gateways describe ...` | ⛔ `:setIamPolicy` on reasoning engine resources |
| `curl -s .../reasoningEngines/<ID>` (inspect `agentGatewayConfig`) | ⛔ `gcloud beta network-services agent-gateways import` |
| `gcloud ... get-iam-policy` / `:getIamPolicy` | ⛔ `gcloud beta iap web set-iam-policy` |
| `gcloud beta iap web get-iam-policy` | ⛔ `gcloud projects add/remove-iam-policy-binding` |
| `curl -s ... :streamQuery` (read/test invocations) | ⛔ `grant_agent_egress.py` or script-driven IAM patches |
| `gcloud logging read ...` (Cloud Logging / Audit Logs) | ⛔ mutating `curl -X PATCH / PUT / POST` against management APIs |
| `python3 update_scorecard.py ...` | ⛔ `gcloud ... delete` |

> ⚠️ **Handling Missing Resources:**
> If `novasmart-egress-gateway` is missing or unattached to MSA, or `test-agent-caller` is still present in `msa_policy`, or the rogue caller query returns HTTP 200, or the PMA principal is missing, or the BigQuery MCP Server IAP CEL policy lacks MCP lifecycle methods (`initialize`, `tools/list`, `ping`), or Google APIs endpoints lack `roles/iap.egressor`, record the check immediately as **`FAIL (Non-Compliant)`** in `update_scorecard.py`. **Do NOT run `:setIamPolicy` or `gcloud beta iap web set-iam-policy` to patch access during a verification step.** Report the discrepancy honestly and guide the leader back to the missed step.

### Two-Phase Verification Protocol:
1. **Phase A: Audit & Test (Strictly Read-Only)**
   - Query Vertex AI REST API (`GET .../reasoningEngines/<MSA_ID>`) to verify `agentGatewayConfig.agentToAnywhereConfig` attaches `novasmart-egress-gateway`.
   - Query `:getIamPolicy` on `reasoningEngines/<MSA_ID>` to confirm the inbound access list names exclusively the PMA principal.
   - Send rogue caller probe (`test-agent-caller` token) to `<MSA_ID>` via `:streamQuery` or `a2a/v1/message:send` to verify `HTTP 403 Forbidden`.
   - Send legitimate escalation probe through the Price Match Agent to verify approved margin strategy throughput.
   - Query IAP Authz Extension and Authz Policy to confirm `novasmart-egress-policy` targets `novasmart-egress-gateway`.
   - Query IAP IAM policy on the BigQuery MCP Server (`gcloud beta iap web get-iam-policy --resource-type=agent-registry --mcp-server=<MCP_SERVER_ID>`) to verify CEL expression allows read-only BigQuery tools and MCP lifecycle methods (`initialize`, `tools/list`, `tools/call`, `notifications/initialized`, `ping`).
   - Query IAP IAM policy on global and regional generic Google APIs endpoints to verify `roles/iap.egressor`.
   - Query Cloud Audit Logging to verify `status.code=7` refusal log.
   - Query project IAM policy to verify project-wide bindings and confirm zero self-grants.
2. **Phase B: Scorecard Update & Consolidated Reporting**
   - If all checks pass $\rightarrow$ Run `update_scorecard.py --mission M2 --status PASS ...`
   - If any check fails $\rightarrow$ Run `update_scorecard.py --mission M2 --status FAIL ...`
   - Render the consolidated verification report in chat. Full raw outputs are written to `/config/Desktop/novasmart-evidence/m2/m2_step5.txt`.

### Consolidated Verification Summary (Template):
| Governance Check | Status | What Proved It (Empirical Observation) |
| :--- | :---: | :--- |
| **Egress Gateway Attachment** | `[ PASS / FAIL ]` | `novasmart-egress-gateway` verified active on Markdown Strategy Agent (`agentToAnywhereConfig`) |
| **A2A Inbound Scoped Policy** | `[ PASS / FAIL ]` | `:getIamPolicy` names exclusively PMA principal under `roles/aiplatform.user` |
| **Rogue Caller Refusal** | `[ PASS / FAIL ]` | Unauthorized token returns `HTTP 403 · PERMISSION_DENIED` on `:streamQuery` / `a2a/v1/message:send` |
| **Authorized Front-Desk Path** | `[ PASS / FAIL ]` | Price Match Agent escalation successfully returns margin strategy |
| **IAP Authz Extension & Policy** | `[ PASS / FAIL ]` | `novasmart-egress-policy` targets `novasmart-egress-gateway` with `novasmart-egress-ext` |
| **BigQuery MCP CEL Policy** | `[ PASS / FAIL ]` | CEL condition enforces read-only tools and MCP lifecycle (`initialize`, `tools/list`, `ping`) |
| **Generic Google APIs Access** | `[ PASS / FAIL ]` | `roles/iap.egressor` granted on global & regional generic Google APIs endpoints |
| **Policy Scope & Zero Self-Grants** | `[ PASS / FAIL ]` | Project-level bindings untouched; `antigravity-sa` roles unchanged |

🏆 **Achievement Unlocked (on PASS only):** *Architect of Inter-Agent Trust — You eliminated universal agent invocation and enforced resource-level least privilege across multi-agent pipelines.*

📊 **Live Scorecard Dashboard:** [http://localhost:8088/governance_scorecard.html](http://localhost:8088/governance_scorecard.html)  
📁 **Full Evidence File:** `/config/Desktop/novasmart-evidence/m2/m2_step5.txt`

---

## 10. Bridge to M3

Close by handing over: the back office now has a **deliberate access list** instead of an accidental one,
the rogue login is refused, and the front desk still gets its answer — with the project-wide grants named
honestly as the next piece of work. But controlling **who may call whom** says nothing about **what gets
said**. Your customer-facing agents still read whatever a shopper types and hand it straight to the model:
a locked door does not help if you let the trap walk through it. That is **M3 · Protect the Content** →
read `m3.md`.
