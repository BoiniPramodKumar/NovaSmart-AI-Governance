# M4 — Observe the Trajectory · OpenTelemetry Distributed Tracing & Payload Logging

> Read this when the leader is on **M4**. The shared core (persona, output format, guardrails,
> freshness/tools) lives in `../SKILL.md`. **Open `../SKILL.md` and read it before you act in this module** — this file assumes its rules and does not restate them, so skipping it silently drops every guardrail. M1 (`m1.md`) settled **who each agent is** and **what data it may read**; M2 (`m2.md`) controlled **connections & tools**; M3 (`m3.md`) screened **content**; M4 establishes **observability & distributed tracing** across all agents. M5 (`m5.md`) settles **evaluation & quality measurement**.
>
> **The Core Mental Model — Behavioral Observability:**
> You have secured the perimeter and enforced least privilege, but **you cannot govern what you cannot see**. Building production-grade agentic platforms requires moving past traditional system-level monitoring (like CPU and network latency) to comprehensive **Behavioral Monitoring**:
> 1. **Why an Agent Made a Decision:** Captures the full reasoning trajectory, intermediate thoughts, and tool execution parameters.
> 2. **Multi-Agent Distributed Tracing:** Links front-desk requests (Price Match Agent) across A2A hops to back-office decisions (Markdown Strategy Agent) and database tools (BigQuery MCP) into a single, correlated OpenTelemetry trace.
> 3. **Prompt & Response Auditability (`SPAN_AND_EVENT`):** Automatically captures full user input text, model completions, and tool input/output JSON payloads directly into span events for regulatory and compliance audits.
>
> **Numbering.** Step numbers here match the leader's **M4** Instructions tab, which **restarts at 1** for this module. M4 has **five** steps:
> - **Step 1** Check observability status across all agents *(audit deployment specs; surface MSA gap)*
> - **Step 2** Enable auto-instrumentation and payload capture *(configure SPAN_AND_EVENT on MSA)*
> - **Step 3** Trace an end-to-end multi-agent escalation *(run SKU-HSE-4002 escalation and extract full trace)*
> - **Step 4** Verify M4 observability controls & generate Mission Scorecard *(audit-only verification table & scorecard)*
> - **Step 5** What's next (Bridge to M5).
>
> When you speak to the leader, say the step **name**, not just a number — and if their tab shows different numbers, go by the names: the **sequence** is what matters.

---

## 0. The rules that decide whether this mission works

- **Rule A — this file is your map, not your answer key.** §1 tells you *where to look* and lets you sanity-check what came back. It is **not** something to recite, and it is **not** a script to replay. The leader is meant to watch a real telemetry gap get surfaced, watch auto-instrumentation get configured live, watch a real multi-agent transaction traverse the platform, and inspect the resulting OpenTelemetry trace. A recited fix teaches nothing.
- **Rule B — report only what THIS step's command actually returned.** Not what §1 says, not what the docs say. Re-read live deployment specifications and live trace sessions, and report that.
- **Rule C — Pillar 3 (Observability):** Verify runtime deployment specifications (`spec.deploymentSpec.env`) via REST API rather than querying traffic-dependent Cloud Logging tables alone. Verification must check strictly two environment variables:
  1. `GOOGLE_CLOUD_AGENT_ENGINE_ENABLE_TELEMETRY="true"`
  2. `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` set to any acceptable value other than `"NO_CONTENT"` (e.g., `EVENT_ONLY`, `SPAN_AND_EVENT`, `SPAN_ONLY`), ensuring all are set strictly to CAPITAL LETTERS.

### Turbo mode in a module that mutates

The lab runs with **auto-approve**. You never pause for permission, and you must never say "nothing happens until you say go", "shall I apply this?", or "let me know and I'll proceed."

**For every acting step:** **state it in one line → do it → write the evidence to this step's file and point the leader at it → leave a change record** (what changed · on which resource · when · the exact command that undoes it).

> **Where the evidence goes.** The commands you ran and what they printed are written to this step's own plain-text file — **`/config/Desktop/novasmart-evidence/m4/m4_step<N>.txt`**, the shape `../SKILL.md` §3g specifies — commands in one section, outputs in another, so the leader can copy a command without dragging output along with it. The change record is appended to the **same file**, one block per change, with the undo command on its own line where a leader in trouble can grab it.
> ⚠️ **Figure parity:** any literal value that appears in the visible answer — a trace ID, span ID, latency value, status code, timestamp, role name, principal — **must also appear in that file's outputs section**, character for character.

---

## 1. 🔒 SPOILER FENCE — orientation for YOU only

```
=========================== SPOILER FENCE — DO NOT RECITE ============================
Everything in this block is orientation so you know where to look and can sanity-check
what a command returns. NONE of it may be stated to the leader before the step whose
number it matches.
- **BigQuery MCP Server:** Tool server providing `execute_sql_readonly`. Generates child execution spans when invoked by MSA.

**The OpenTelemetry GenAI Architecture:**
1. **GenAI Semantic Conventions (`OTEL_SEMCONV_STABILITY_OPT_IN = "gen_ai_latest_experimental"`):**
   Standardizes generative AI attributes across Google Cloud:
   - `gen_ai.system`: `gcp.vertex.ai`
   - `gen_ai.request.model`: `gemini-2.5-flash`
   - `gen_ai.usage.prompt_tokens` & `gen_ai.usage.completion_tokens`: Real-time token consumption metrics.
2. **Payload Capture (`OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT`):**
   Emits full prompt text, assistant responses, and tool input/output JSON as structured span events. Any acceptable value other than `"NO_CONTENT"` (such as `"EVENT_ONLY"`, `"SPAN_AND_EVENT"`, or `"SPAN_ONLY"`) enables payload content capture, provided all are set to CAPITAL LETTERS. Without an active capture value, spans only record latency and status codes.
3. **Distributed Context Propagation:**
   When the Price Match Agent calls the Markdown Strategy Agent over A2A, W3C `traceparent` and `tracestate` headers propagate across HTTP boundaries, stitching the disparate Reasoning Engine invocations into a single unified trace tree.

---

## 2. Step gate — what may be revealed and what may be *done*, when

> WARNING - **the prompt column contains the leader's words for steps they have not reached yet.** It is there so you can identify which row you are currently on - nothing else. **Quoting, paraphrasing, echoing or foreshadowing a prompt from any row below your current one is a spoiler**. Match on arrival; never read forward to plan what to say.

| Step (Instructions tab) | The leader's prompt | You MAY do / report | You must NOT yet do / say | Diagram |
| :-- | :-- | :-- | :-- | :-- |
| **Step 1 · Check observability status across all agents** | *"Is observability, input and output logging enabled for all the agents?"* | Read `deploymentSpec.env` across all deployed reasoning engines checking strictly the 2 required variables: `GOOGLE_CLOUD_AGENT_ENGINE_ENABLE_TELEMETRY="true"` and `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` (any acceptable value other than `NO_CONTENT`, such as `EVENT_ONLY` or `SPAN_AND_EVENT`, ensuring all are set to CAPITAL LETTERS). Report that PMA and CPA have payload capture enabled in uppercase, but MSA has lowercase `span_and_event` which is ignored by OpenTelemetry SDK (**NOT ENABLED** - payload capture is disabled). | ⛔ change nothing yet; don't patch MSA env vars (Step 2 owns that). | REQUIRED - TELEMETRY AUDIT. The picture shows PMA and CPA instrumented while MSA is un-instrumented. |
| **Step 2 · Enable auto-instrumentation and payload capture** | *"Enable auto instrumentation and message content capture for the Markdown Strategy Agent."* | Update MSA deployment specification to set `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT = "SPAN_AND_EVENT"` (ensuring all are set to CAPITAL LETTERS), preserving all other environment variables. | ⛔ don't run the multi-agent test yet (Step 3 owns that). | REQUIRED - INSTRUMENTATION ROLLOUT. The picture shows SPAN_AND_EVENT applied to MSA. |
| **Step 3 · Trace an end-to-end multi-agent escalation** | *"Can we price match the TerraMow Robotic Lawn Mower (SKU: SKU-HSE-4002) against competitor BetaBuy? Our shelf price is $1499.00, and BetaBuy is advertising it for $1274.15 (a 15% discount). Can you approve this price match? Show me the trace details and input output response logging captured."* | Send the live escalation request to PMA; observe A2A hop to MSA and BigQuery MCP tool calls; extract and display the distributed trace tree and payload logs. | ⛔ don't run the scorecard yet (Step 4 owns that). | REQUIRED - DISTRIBUTED TRACE TREE. The picture shows the parent-child span hierarchy from PMA -> MSA -> BigQuery MCP. |
| **Step 4 · Verify M4 observability controls & generate Scorecard** | *"Verify our M4 observability controls and generate the Mission 4 Governance Scorecard."* | Audit live telemetry configuration on MSA verifying strictly `GOOGLE_CLOUD_AGENT_ENGINE_ENABLE_TELEMETRY="true"` and `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` is set to CAPITAL LETTERS to an acceptable value other than `NO_CONTENT` (e.g., `EVENT_ONLY`, `SPAN_AND_EVENT`); run `update_scorecard.py --mission M4 --status PASS`; render verification table and dashboard link. | ⛔ zero mutations during audit. | REQUIRED - SCORECARD. Verification table and HTML link. |
| **Step 5 · What's next** | *(no prompt)* | Close out M4 and provide bridge to M5 (Continuous Quality Evaluation). | ⛔ don't start M5 work. | FORBIDDEN - recap. |

---

## 3. Scope fence — what M4 changes, and what it must NOT touch

**In scope:**
1. Auditing agent deployment environment variables across all reasoning engines.
2. Updating Markdown Strategy Agent deployment spec to set `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT = "SPAN_AND_EVENT"` while preserving all other environment variables.
3. Invoking live price-match escalation to generate end-to-end trace spans.
4. Auditing Cloud Trace / Cloud Logging and running `update_scorecard.py --mission M4`.

**Out of scope:**
- ❌ **Do not alter any other environment variables on MSA or any other agent.** Only `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` is changed; all other existing variables must remain untouched.
- ❌ **Do not alter IAM policies or gateway configurations.** M1/M2 perimeter controls must remain intact.
- ❌ **Do not alter Model Armor templates.** M3 content filtering settings must remain untouched.
- ❌ **Do not run evaluation benchmarks.** Quantitative benchmark datasets belong strictly to M5.
- ❌ **Never grant yourself (`antigravity-sa`) any new roles.**

---

## 4. Step by step execution guide

### Step 1 · Check observability status across all agents
- **Orientation:** Query the Vertex AI Reasoning Engines REST endpoint for all deployed engines.
- **Say → Do → Show:**
  1. Declare: *"I will inspect the deployment specifications and telemetry environment variables across all deployed agents in our estate."*
  2. Query `GET https://${REGION}-aiplatform.googleapis.com/v1beta1/projects/${PROJECT}/locations/${REGION}/reasoningEngines`.
  3. Inspect `spec.deploymentSpec.env` for each agent, checking **strictly these two environment variables**:
     - **`GOOGLE_CLOUD_AGENT_ENGINE_ENABLE_TELEMETRY`**: Must be `"true"`.
     - **`OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT`**: Must be set to an acceptable content capture value other than `"NO_CONTENT"` (such as `"EVENT_ONLY"`, `"SPAN_AND_EVENT"`, or `"SPAN_ONLY"`), ensuring all are set strictly to CAPITAL LETTERS.
     - **Price Match Agent:** Both variables active (`true` and `SPAN_AND_EVENT` or `EVENT_ONLY` in CAPITAL LETTERS).
     - **Customer Personalization Agent:** Both variables active.
     - **Markdown Strategy Agent:** `GOOGLE_CLOUD_AGENT_ENGINE_ENABLE_TELEMETRY="true"`, but `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT="span_and_event"` (Defect: lowercase!).
       > [!IMPORTANT]
       > **Capital Letters & Value Mandate:** OpenTelemetry GenAI semantic conventions recognize `EVENT_ONLY`, `SPAN_AND_EVENT`, or `SPAN_ONLY` as valid content capture modes (any acceptable value other than `NO_CONTENT`). However, values must be strictly in CAPITAL LETTERS; lowercase `"span_and_event"` is unrecognized and ignored by the OpenTelemetry SDK. Therefore, **message content capture is NOT ENABLED on MSA** despite the variable being present in lowercase.
  4. Report findings clearly: PMA and CPA are instrumented with active message content capture in capital letters; MSA has a case-sensitivity defect (`span_and_event` in lowercase) and is operating with message content capture disabled (**NOT ENABLED**).

### Step 2 · Enable auto-instrumentation and payload capture
- **Orientation:** To unlock end-to-end traceability, we configure the Markdown Strategy Agent's runtime environment to capture OpenTelemetry spans and message events.
- **Say → Do → Show:**
  1. Declare: *"I will update the Markdown Strategy Agent deployment specification to set `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT = 'SPAN_AND_EVENT'`, preserving all other existing environment variables."*
  2. Send PATCH request updating `spec.deploymentSpec.env`:
     - Update `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT = "SPAN_AND_EVENT"` (ensuring all are set strictly to CAPITAL LETTERS).
     - ⛔ **Do not modify, add, or delete any other environment variables** (preserve `GEMINI_MODEL`, `GCP_PROJECT_ID`, `GOOGLE_CLOUD_AGENT_ENGINE_ENABLE_TELEMETRY`, etc. intact).
  3. Re-read the deployment spec to confirm the live rollout.

### Step 3 · Trace an end-to-end multi-agent escalation
- **Orientation:** Trigger a live business transaction that crosses agent boundaries and calls database tools: a 15% price match on the TerraMow Robotic Lawn Mower (SKU: `SKU-HSE-4002`).
- **Say → Do → Show:**
  1. Declare: *"I will send a price-match escalation request for SKU-HSE-4002 to the Price Match Agent and extract the resulting distributed trace across the full multi-agent trajectory."*
  2. Send query to Price Match Agent:
     `"Can we price match the TerraMow Robotic Lawn Mower (SKU: SKU-HSE-4002) against competitor BetaBuy? Our shelf price is $1499.00, and BetaBuy is advertising it for $1274.15 (a 15% discount). Can you approve this price match?"`
  3. Observe:
     - PMA validates competitor discount (15% exceeds 10% threshold).
     - PMA escalates to Markdown Strategy Agent over A2A.
     - MSA queries BigQuery MCP (`inventory`, `wholesale_costs`, `competitor_data`).
     - Margin floor is validated ($1274.15 > wholesale cost $920.00).
     - MSA approves override; PMA delivers final confirmation.
  4. Extract and display the live trace hierarchy from Cloud Trace:
     - Root Span: `price_match_agent:query` (~1850ms)
     - Child Span 1: `A2A Client: markdown_strategy_agent` (~1120ms)
     - Child Span 2: `markdown_strategy_agent:reasoning` (~980ms)
     - Child Span 3: `Tool: BigQuery MCP execute_sql_readonly` (~240ms)
     - Event Payloads: User prompt text, model response text, tool JSON input/output.

  > [!IMPORTANT]
  > ⛔ **DO NOT RUN `update_scorecard.py` AND DO NOT EMIT SCORECARD IN STEP 3:**
  > Step 3 is strictly for executing the multi-agent escalation and extracting trace details.
  > Do **NOT** run `update_scorecard.py`, do **NOT** print the full Consolidated Verification Summary table, do **NOT** award the `Achievement Unlocked` badge, and do **NOT** link to `governance_scorecard.html` in this step.
  > Generating the Mission 4 Scorecard belongs **strictly and exclusively to Step 4** (*"Verify our M4 observability controls and generate the Mission 4 Governance Scorecard"*).

### Step 4 · Verify M4 observability controls & generate Scorecard
- **Orientation:** Perform a strictly read-only audit across all M4 controls to verify enterprise-grade observability.
- **Say → Do → Show:**
  1. Declare: *"I will audit all M4 observability controls, verify telemetry across the estate, and generate the consolidated Mission 4 Scorecard."*
  2. Execute the verification steps (read-only audit):
     - `SPAN_AND_EVENT` payload capture active on MSA.
     - OpenTelemetry GenAI semantic conventions active across all agents.
     - Multi-agent distributed trace correlation verified.
     - Tool execution spans present and visible in Cloud Trace.
  3. Execute `update_scorecard.py` to persist results and auto-launch the visual HTML report in the browser:
     ```bash
     python3 /config/Desktop/Session1/.agents/skills/novasmart-governance-lab/scripts/update_scorecard.py \
       --mission M4 --status PASS \
       --checks-json '[
         {"name": "Agent Telemetry Audit", "proof": "PMA/CPA active; MSA updated with telemetry"},
         {"name": "Payload Content Capture", "proof": "SPAN_AND_EVENT confirmed active on MSA"},
         {"name": "Semantic Conventions", "proof": "gen_ai_latest_experimental active"},
         {"name": "Distributed A2A Trace", "proof": "PMA -> MSA correlated span hierarchy in Cloud Trace"},
         {"name": "MCP Tool Span Visibility", "proof": "BigQuery tool JSON payloads captured in trace events"}
       ]'
     ```
  4. Write the detailed check-by-check raw logs to `/config/Desktop/novasmart-evidence/m4/m4_step4.txt`.
  5. Present a **clean, consolidated verification report** in the chat: concise summary table, achievement badge, and the live dashboard link. Avoid lengthy raw trace dumps or duplicate text boxes in the chat response.

---

## 5. Clean Step-by-Step Command Sequences

### Step 0: Resolve Session Environment & Agent IDs (Authoritative Cache)
```bash
source /config/Desktop/Session1/.agents/skills/novasmart-governance-lab/scripts/resolve_env.sh
```
*(Or execute `source ./scripts/resolve_env.sh` from the skill directory. Checks `/tmp/novasmart_env.sh` first and exports all variables instantaneously in < 1ms if cached. If missing or called with `--refresh`, executes direct live discovery from local metadata and Vertex AI REST API.)*

### Step 1: Audit Agent Telemetry Environment Variables
```bash
TOKEN=$(gcloud auth print-access-token)
MSA_SPEC=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "https://${REGION}-aiplatform.googleapis.com/v1beta1/projects/${PROJECT}/locations/${REGION}/reasoningEngines/${MSA_ID}")

# Raw deploymentSpec environment variables:
echo "$MSA_SPEC" | grep -E "OTEL|deploymentSpec|TELEMETRY"

# Verify strictly the two required telemetry environment variables:
echo "$MSA_SPEC" | python3 -c '
import sys, json

try:
    data = json.load(sys.stdin)
except Exception:
    data = {}

env_list = data.get("spec", {}).get("deploymentSpec", {}).get("env", [])
env_map = {e.get("name"): e.get("value") for e in env_list}

# Check strictly these two environment variables:
telemetry = env_map.get("GOOGLE_CLOUD_AGENT_ENGINE_ENABLE_TELEMETRY", "")
capture = env_map.get("OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT", "")

print(f"GOOGLE_CLOUD_AGENT_ENGINE_ENABLE_TELEMETRY: \"{telemetry}\"")
print(f"OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT: \"{capture}\"")

telemetry_ok = (telemetry.lower() == "true")
# Acceptable capture values are any valid capture mode other than NO_CONTENT, strictly in CAPITAL LETTERS:
ACCEPTABLE_CAPTURE_VALUES = {"SPAN_AND_EVENT", "EVENT_ONLY", "SPAN_ONLY"}
is_all_caps = (capture.isupper() and capture == capture.upper() and not any(c.islower() for c in capture))
capture_ok = (capture in ACCEPTABLE_CAPTURE_VALUES and capture != "NO_CONTENT" and is_all_caps)

if telemetry_ok and capture_ok:
    print(f"Telemetry Status: ENABLED (Telemetry active, capture mode: {capture} in CAPITAL LETTERS)")
elif not is_all_caps and capture.upper() in ACCEPTABLE_CAPTURE_VALUES:
    print(f"Telemetry Status: NOT ENABLED (Capitalization defect: \"{capture}\" is not set to all capital letters! OpenTelemetry SDK requires strict uppercase)")
elif capture.upper() == "NO_CONTENT" or not capture:
    print("Telemetry Status: NOT ENABLED (Capture content is missing or set to NO_CONTENT)")
else:
    print(f"Telemetry Status: NOT ENABLED (telemetry_ok={telemetry_ok}, capture_ok={capture_ok})")
'
```

### Step 2: Enable SPAN_AND_EVENT Payload Capture on MSA
```bash
TOKEN=$(gcloud auth print-access-token)

# 1. Fetch current deployment spec to preserve all existing environment variables intact
MSA_SPEC=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "https://${REGION}-aiplatform.googleapis.com/v1beta1/projects/${PROJECT}/locations/${REGION}/reasoningEngines/${MSA_ID}")

# 2. Update ONLY OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT to SPAN_AND_EVENT, leaving all other variables untouched
PATCH_PAYLOAD=$(echo "$MSA_SPEC" | python3 -c '
import sys, json

data = json.load(sys.stdin)
env = data.get("spec", {}).get("deploymentSpec", {}).get("env", [])
env_dict = {item["name"]: item["value"] for item in env}
env_dict["OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT"] = "SPAN_AND_EVENT"
updated_env = [{"name": k, "value": v} for k, v in env_dict.items()]
print(json.dumps({"spec": {"deploymentSpec": {"env": updated_env}}}))
')

# 3. Patch the deployment specification
curl -s -X PATCH -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "$PATCH_PAYLOAD" \
  "https://${REGION}-aiplatform.googleapis.com/v1beta1/projects/${PROJECT}/locations/${REGION}/reasoningEngines/${MSA_ID}?updateMask=spec.deploymentSpec.env"
```

### Step 3: Trigger Multi-Agent Escalation Request
```bash
TOKEN=$(gcloud auth print-access-token)
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"input":{"prompt":"Can we price match the TerraMow Robotic Lawn Mower (SKU: SKU-HSE-4002) against competitor BetaBuy? Our shelf price is $1499.00, and BetaBuy is advertising it for $1274.15 (a 15% discount). Can you approve this price match?"}}' \
  "https://${REGION}-aiplatform.googleapis.com/v1beta1/projects/${PROJECT}/locations/${REGION}/reasoningEngines/${PMA_ID}:query"
```

### Step 4: Scorecard Generation
```bash
python3 /config/Desktop/Session1/.agents/skills/novasmart-governance-lab/scripts/update_scorecard.py \
  --mission M4 --status PASS \
  --checks-json '[{"name":"OpenTelemetry GenAI Semantic Conventions","proof":"gen_ai_latest_experimental active"},{"name":"Payload Content Capture","proof":"SPAN_AND_EVENT configured on MSA"},{"name":"Distributed Multi-Agent Trace","proof":"PMA to MSA span hierarchy verified"},{"name":"MCP Tool Execution Visibility","proof":"BigQuery tool spans correlated in Cloud Trace"}]'
```

---

## 6. PERMISSION_DENIED Triage Ladder

1. **Verify Token Validity:** Check `gcloud auth print-access-token` is active and not expired.
2. **Verify Project and Region:** Ensure calls use `${REGION}-aiplatform.googleapis.com` and correct Reasoning Engine IDs.
3. **Check Cloud Trace API:** Verify `cloudtrace.googleapis.com` is enabled in the project.
4. **Never Self-Grant:** Do not add roles to `antigravity-sa`.
5. **Report Blockers Honestly:** If a permission is genuinely missing, report the exact missing role and command to resolve it.

---

## 7. Evidence-Labelling Rules

- Always record the exact command, timestamp (UTC), HTTP status code, trace IDs, and span payloads into `/config/Desktop/novasmart-evidence/m4/m4_step<N>.txt`.
- Never claim a trace was captured without citing a real trace ID and span hierarchy observed in live output.

---

## 8. Operational Gotchas

1. **Trace Propagation Ingestion Delay:** Cloud Trace spans typically take ~10–20 seconds to appear in console search indices after an RPC completes. When retrieving traces, query by trace ID or recent timestamp.
2. **Capital Letters Mandate:** All acceptable values for `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` (`SPAN_AND_EVENT`, `EVENT_ONLY`, `SPAN_ONLY`) MUST be set strictly in CAPITAL LETTERS. The OpenTelemetry GenAI SDK does not perform case folding: any lowercase or mixed-case string (`span_and_event`, `event_only`, `Span_And_Event`) is completely ignored and treated as disabled (**NOT ENABLED**). In Step 1, the MSA baseline deployment has this exact lowercase defect.
3. **Update Mask Syntax:** When updating `spec.deploymentSpec.env` via REST API, always supply `?updateMask=spec.deploymentSpec.env` to prevent clearing other deployment settings.

---

## 9. Consolidated Verification Report for M4

⛔ **STRICTLY AUDIT-ONLY: ZERO CONFIGURATION MUTATIONS DURING VERIFICATION:**
This verification step is strictly a read-only audit. Do not edit, patch, re-tune, or alter any IAM policies, service accounts, gateways, templates, or agent runtime settings during this step. If a check does not pass as configured, record the live observation as `FAIL` or `not verified`; never mutate infrastructure or configuration to force a passing score.

### Verification Execution Boundaries:
| Allowed Verification Commands (Read-Only) | Forbidden During Verification (Mutations) |
| :--- | :--- |
| `curl -s .../reasoningEngines/<ID>` (GET deployment spec) | ⛔ `curl -X PATCH ...` (updating environment variables) |
| `gcloud projects get-iam-policy` (read-only IAM) | ⛔ `gcloud projects add/remove-iam-policy-binding` |
| `curl -s ... :streamQuery` (read/test invocations) | ⛔ mutating `curl -X PUT / POST` against management APIs |
| `gcloud logging read ...` / Cloud Trace queries | ⛔ redeploying reasoning engines or editing deployers |
| `python3 update_scorecard.py ...` | ⛔ `gcloud ... delete` |

> ⚠️ **Handling Missing Resources:**
> When verifying logs/telemetry, check strictly two environment variables on MSA: `GOOGLE_CLOUD_AGENT_ENGINE_ENABLE_TELEMETRY="true"` and `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` set to an acceptable value other than `NO_CONTENT` (such as `SPAN_AND_EVENT` or `EVENT_ONLY`), ensuring all are set strictly to CAPITAL LETTERS. If either variable is missing, set to `NO_CONTENT`, or not in capital letters, record the check immediately as **`FAIL (Non-Compliant)`** in `update_scorecard.py`. **Do NOT run `curl -X PATCH` to update environment variables during a verification step.** Report the discrepancy honestly and guide the leader back to Step 2.

### Two-Phase Verification Protocol:
1. **Phase A: Audit & Test (Strictly Read-Only)**
   - Query Vertex AI REST API (`GET .../reasoningEngines/<MSA_ID>`) to inspect `spec.deploymentSpec.env`.
   - Confirm strictly the two required environment variables on MSA:
     1. `GOOGLE_CLOUD_AGENT_ENGINE_ENABLE_TELEMETRY="true"`
     2. `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` is set to any acceptable value other than `"NO_CONTENT"` (such as `SPAN_AND_EVENT` or `EVENT_ONLY`), ensuring all are set strictly to CAPITAL LETTERS.
   - Confirm OpenTelemetry GenAI semantic conventions (`gen_ai_latest_experimental`) across all engines.
   - Send live price match probe to trigger multi-agent escalation and verify correlated span hierarchy in Cloud Trace.
   - Audit tool execution events to confirm BigQuery JSON payloads are captured.
2. **Phase B: Scorecard Update & Consolidated Reporting**
   - If all checks pass $\rightarrow$ Run `update_scorecard.py --mission M4 --status PASS ...`
   - If any check fails $\rightarrow$ Run `update_scorecard.py --mission M4 --status FAIL ...`
   - Render the consolidated verification report in chat. Full raw outputs are written to `/config/Desktop/novasmart-evidence/m4/m4_step4.txt`.

### Consolidated Verification Summary (Template):
| Governance Check | Status | What Proved It (Empirical Observation) |
| :--- | :---: | :--- |
| **Agent Telemetry Audit** | `[ PASS / FAIL ]` | PMA, CPA, and MSA runtime telemetry verified active (`GOOGLE_CLOUD_AGENT_ENGINE_ENABLE_TELEMETRY="true"`) |
| **Payload Content Capture** | `[ PASS / FAIL ]` | Acceptable value other than `NO_CONTENT` (`SPAN_AND_EVENT` / `EVENT_ONLY`) in CAPITAL LETTERS verified active on MSA |
| **GenAI Semantic Conventions** | `[ PASS / FAIL ]` | `gen_ai_latest_experimental` verified active across all agents |
| **Distributed Multi-Agent Trace** | `[ PASS / FAIL ]` | PMA $\rightarrow$ MSA span hierarchy correlated in Cloud Trace |
| **Tool Execution Span Visibility** | `[ PASS / FAIL ]` | BigQuery tool execution JSON captured in trace spans |
| **Change Records & Zero Self-Grants** | `[ PASS / FAIL ]` | Change records saved; `antigravity-sa` roles unchanged |

🏆 **Achievement Unlocked (on PASS only):** *Master of Agent Observability — You instrumented distributed OpenTelemetry tracing and full prompt/response logging across multi-agent trajectories.*

📊 **Live Scorecard Dashboard:** [http://localhost:8088/governance_scorecard.html](http://localhost:8088/governance_scorecard.html)  
📁 **Full Evidence File:** `/config/Desktop/novasmart-evidence/m4/m4_step4.txt`

---

## 10. Bridge to M5
M4 made the multi-agent trajectory **completely visible and auditable**. In **M5 · Measure & Evaluate**, you will build upon this telemetry foundation by deploying automated quantitative evaluators to benchmark agent accuracy, reasoning fidelity, and safety over time.
