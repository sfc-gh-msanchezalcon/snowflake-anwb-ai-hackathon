# Use cases & evaluation areas

The two challenges in this repo are the **use cases ANWB defined for the pilot**, rebuilt as a
hands-on kit. This page ties each one back to the **capability areas ANWB is evaluating** in the
GenAI platform assessment, so you can see which criteria you're demonstrating as you build.

> This is a **category-level** map. ANWB's full, detailed criteria and the platform scorecard are
> the Day-1 capability assessment and are kept as a separate internal reference - ask the facilitator.

> **How the pilot is scored.** Day 1 ("Understand, Assess, Score") is a capability assessment: ANWB
> scores each capability category on their own, and Snowflake brings its own scorecard for the same
> categories. The two are then compared side by side. The use cases below are **ANWB's own
> definitions** from the pilot plan — vision, capabilities, tools, sample questions, and success
> criteria are reproduced faithfully so what you build maps directly to what's being assessed.

## ANWB's use cases

| Use case | What it is | Build it in |
|---|---|---|
| **ReisNogWijzer** | An AI travel assistant that answers member trip questions by combining a travel/camping knowledge base (RAG) with live-style tools (vehicle lookup, weather, advisories). | [`challenges/01-reisnogwijzer/`](challenges/01-reisnogwijzer/) |
| **Marketing Agent** | A multi-step agent that turns a product + audience into an on-brand campaign plan and a ready-to-present deck. | [`challenges/02-marketing-agent/`](challenges/02-marketing-agent/) |

## ANWB's evaluation areas (capability categories)

ANWB's "Capabilities to test for GenAI" list groups **145 criteria into 11 categories**: **Overall,
LLM Gateway, Evaluation, Guardrails, Tracing, Prompt management, Agent registry, Skill registry,
Tool registry, RAG, and Agent runtime.** (Governance / IAM / RBAC lives inside *Overall*; the
no-code builder lives inside *Agent runtime*.)

## Which areas each use case lets you demonstrate

| Evaluation area | ReisNogWijzer | Marketing Agent |
|---|:---:|:---:|
| Overall (platform, governance/RBAC, ops) | ● | ● |
| LLM Gateway (model calls, compare models) | ● | ● |
| RAG (Cortex Search over a knowledge base) | ● | ● |
| Agent runtime (multi-step orchestration) | ● | ● |
| Tool registry (custom tools / functions) | ● (vehicle, weather, advisory) | ● (deck generator) |
| Agent registry (build as a Cortex Agent) | ● | ● |
| Evaluation (judge answer quality) | ○ optional | ○ optional |
| Guardrails (PII redaction, scope, safety) | ○ optional | ○ optional |
| Tracing (traces, cost, latency) | ● | ● |
| Prompt management (structured / versioned prompts) | ○ | ● (structured plan) |
| Skill registry (reusable skills/functions) | ○ | ○ |

● = a natural part of the challenge  ○ = available as a stretch

Both use cases run entirely on Snowflake Cortex - the same platform the assessment evaluates - so
building either one is itself a demonstration of the areas above.
