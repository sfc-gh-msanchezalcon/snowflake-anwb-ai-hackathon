# Use cases & evaluation areas

The two challenges in this repo are the **use cases ANWB defined for the pilot**, rebuilt as a
hands-on kit. This page ties each one back to the **capability areas ANWB is evaluating** in the
GenAI platform assessment, so you can see which criteria you're demonstrating as you build.

> This is a **category-level** map. ANWB's full, detailed criteria and the platform scorecard are
> the Day-1 capability assessment and are kept as a separate internal reference - ask the facilitator.

## ANWB's use cases

| Use case | What it is | Build it in |
|---|---|---|
| **ReisNogWijzer** | An AI travel assistant that answers member trip questions by combining a travel/camping knowledge base (RAG) with live-style tools (vehicle lookup, weather, advisories). | [`challenges/01-reisnogwijzer/`](challenges/01-reisnogwijzer/) |
| **Marketing Agent** | A multi-step agent that turns a product + audience into an on-brand campaign plan and a ready-to-present deck. | [`challenges/02-marketing-agent/`](challenges/02-marketing-agent/) |

## ANWB's evaluation areas (capability categories)

The assessment groups capabilities into these areas: **LLM Gateway, RAG, Agent Runtime, Agent
Registry, Tool use, Evaluation, Guardrails, Tracing / Observability, Prompt Management, Model
Deployment, Governance (IAM/RBAC), Monitoring, and UI / Low-code agent builder.**

## Which areas each use case lets you demonstrate

| Evaluation area | ReisNogWijzer | Marketing Agent |
|---|:---:|:---:|
| LLM Gateway (model calls, compare models) | ● | ● |
| RAG (Cortex Search over a knowledge base) | ● | ● |
| Agent Runtime (multi-step orchestration) | ● | ● |
| Tool use (custom tools / functions) | ● (vehicle, weather, advisory) | ● (deck generator) |
| Agent Registry (build as a Cortex Agent) | ● | ● |
| Evaluation (judge answer quality) | ○ optional | ○ optional |
| Guardrails (PII redaction, scope, safety) | ○ optional | ○ optional |
| Tracing / Observability (traces, cost, latency) | ● | ● |
| Prompt Management (structured / versioned prompts) | ○ | ● (structured plan) |
| Model Deployment / structured output | ○ | ● (JSON plan + deck) |
| Governance (RBAC, masking) | platform-level, always available | platform-level, always available |
| UI (Snowsight, Streamlit) | ● (optional app.py) | ● (optional app.py) |

● = a natural part of the challenge  ○ = available as a stretch

Both use cases run entirely on Snowflake Cortex - the same platform the assessment evaluates - so
building either one is itself a demonstration of the areas above.
