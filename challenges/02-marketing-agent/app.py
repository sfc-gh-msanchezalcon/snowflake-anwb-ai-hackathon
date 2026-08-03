import json
import streamlit as st
import streamlit.components.v1 as components
from snowflake.snowpark.context import get_active_session

# Marketing Agent — reference Streamlit app (Streamlit in Snowflake)
session = get_active_session()
session.sql("USE DATABASE ANWB_AI_HACKATHON").collect()

st.set_page_config(page_title="ANWB Marketing Agent", page_icon="📣", layout="wide")
st.title("📣 ANWB Marketing Agent")
st.caption("Product brief → on-brand campaign plan → presentation deck.")


def complete(prompt, model="mistral-large2"):
    return session.sql("SELECT AI_COMPLETE(?, ?) AS a", params=[model, prompt]).collect()[0]["A"]


def search_kb(query, limit=4):
    spec = json.dumps({"query": query, "columns": ["title", "content"], "limit": limit})
    row = session.sql(
        "SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(?, ?) AS r",
        params=["ANWB_AI_HACKATHON.MARKETING.MARKETING_KB", spec],
    ).collect()[0]
    return json.loads(row["R"]).get("results", [])


def slides_to_html(slides):
    css = ("body{font-family:sans-serif;margin:0} "
           ".s{border:2px solid #FFD100;margin:12px;padding:20px;border-radius:12px;background:#fff} "
           "h2{color:#0a2a66;margin-top:0}")
    out = [f"<style>{css}</style>"]
    for s in slides:
        bl = "".join(f"<li>{b}</li>" for b in s.get("bullets", []))
        out.append(f"<div class='s'><h2>{s['title']}</h2><ul>{bl}</ul></div>")
    return "".join(out)


products = session.sql(
    "SELECT product_id, name, description FROM MARKETING.PRODUCTS ORDER BY name"
).to_pandas()
segments = session.sql(
    "SELECT segment_id, name, key_motivator FROM MARKETING.AUDIENCE_SEGMENTS ORDER BY name"
).to_pandas()

c1, c2 = st.columns(2)
prod_name = c1.selectbox("Product", products["NAME"])
seg_name = c2.selectbox("Target audience", segments["NAME"])
prod = products[products["NAME"] == prod_name].iloc[0]
seg = segments[segments["NAME"] == seg_name].iloc[0]

if st.button("Generate campaign", type="primary"):
    with st.spinner("Researching brand & building the plan…"):
        brand = search_kb("tone of voice, brand positioning, campaign planning framework, deck structure")
        brand_ctx = json.dumps([b["content"] for b in brand])
        prompt = (
            "You are an ANWB marketing strategist. Use the brand context to stay on-brand.\n"
            "BRAND CONTEXT: " + brand_ctx + "\n\n"
            f"Build a campaign for the product \"{prod['NAME']}\" ({prod['DESCRIPTION']}) "
            f"targeting {seg['NAME']} (motivator: {seg['KEY_MOTIVATOR']}).\n"
            "Return ONLY valid JSON (no markdown fences) with keys: objective, audience, key_message, "
            "tagline, channels (array), timeline (array of {phase, weeks}), kpis (array), "
            "slides (array of {title, bullets}). Follow the ANWB deck structure and warm tone."
        )
        raw = complete(prompt).strip()
        raw = raw.removeprefix("```json").removeprefix("```").removesuffix("```").strip()
        try:
            plan = json.loads(raw)
        except json.JSONDecodeError:
            st.error("Model returned invalid JSON — click generate again.")
            st.stop()

    st.subheader(plan.get("tagline", "Campaign"))
    a, b = st.columns(2)
    a.metric("Objective", "") ; a.write(plan.get("objective"))
    b.write("**Channels:** " + ", ".join(plan.get("channels", [])))
    b.write("**KPIs:** " + ", ".join(plan.get("kpis", [])))

    st.markdown("### Presentation")
    components.html(slides_to_html(plan.get("slides", [])), height=520, scrolling=True)

    # Build a real .pptx and offer it for download
    session.sql("CREATE STAGE IF NOT EXISTS MARKETING.DECKS").collect()
    session.sql(
        "CALL MARKETING.build_deck(PARSE_JSON(?), ?)",
        params=[json.dumps(plan.get("slides", [])), "anwb_campaign.pptx"],
    ).collect()
    data = session.file.get_stream("@MARKETING.DECKS/anwb_campaign.pptx").read()
    st.download_button("⬇️ Download .pptx", data=data, file_name="anwb_campaign.pptx",
                       mime="application/vnd.openxmlformats-officedocument.presentationml.presentation")

    with st.expander("Full plan JSON"):
        st.json(plan)
