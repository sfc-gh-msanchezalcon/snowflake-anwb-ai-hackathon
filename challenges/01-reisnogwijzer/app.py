import json
import streamlit as st
from snowflake.snowpark.context import get_active_session

# ReisNogWijzer — reference Streamlit chat app (Streamlit in Snowflake)
session = get_active_session()
# Use whatever database this app is deployed in, so it works under any DB name / account.
DB = (session.get_current_database() or "ANWB_AI_HACKATHON").strip('"')

st.set_page_config(page_title="ReisNogWijzer", page_icon="🚐", layout="centered")
st.title("🚐 ReisNogWijzer")
st.caption("Your ANWB travel assistant — grounded in the travel knowledge base and live tools.")


def search_kb(query, columns, limit=3):
    spec = json.dumps({"query": query, "columns": columns, "limit": limit})
    row = session.sql(
        "SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(?, ?) AS r",
        params=[f"{DB}.TRAVEL.TRAVEL_KB", spec],
    ).collect()[0]
    return json.loads(row["R"]).get("results", [])


def complete(prompt, model="mistral-large2"):
    return session.sql("SELECT AI_COMPLETE(?, ?) AS a", params=[model, prompt]).collect()[0]["A"]


def tool(sql, params):
    return session.sql(sql, params=params).collect()[0][0]


with st.sidebar:
    st.header("Trip context (optional)")
    kenteken = st.text_input("Licence plate (kenteken)", value="XD-429-P")
    city = st.text_input("City you want to drive into", value="Munich")
    country = st.text_input("Country for a safety advisory", value="")
    use_real = st.toggle("Use real APIs (RDW + open-meteo)", value=False)

rdw_fn = "real_rdw_lookup" if use_real else "mock_rdw_lookup"

if "messages" not in st.session_state:
    st.session_state.messages = []
for m in st.session_state.messages:
    st.chat_message(m["role"]).markdown(m["content"])

if q := st.chat_input("Ask a travel question…"):
    st.session_state.messages.append({"role": "user", "content": q})
    st.chat_message("user").markdown(q)
    with st.chat_message("assistant"):
        with st.spinner("Thinking…"):
            ctx = search_kb(q, ["title", "content"], limit=3)
            facts = {}
            if kenteken:
                facts["vehicle"] = tool(f"SELECT TRAVEL.{rdw_fn}(?)", [kenteken])
            if city:
                facts["emission_zone"] = tool(
                    "SELECT OBJECT_CONSTRUCT(*)::string FROM TRAVEL.EMISSION_ZONES WHERE city = ?",
                    [city],
                )
            if country:
                facts["advisory"] = tool("SELECT TRAVEL.travel_advisory_tool(?)", [country])
            prompt = (
                "You are ReisNogWijzer, a warm and helpful ANWB travel expert. "
                "Use ONLY the knowledge and facts below. Be concise and practical.\n\n"
                "KNOWLEDGE:\n" + json.dumps([h["content"] for h in ctx]) + "\n\n"
                "FACTS:\n" + json.dumps(facts) + "\n\n"
                "QUESTION: " + q
            )
            answer = complete(prompt)
            st.markdown(answer)
            with st.expander("Sources & facts used"):
                st.write("Docs:", [h["title"] for h in ctx])
                st.json(facts)
    st.session_state.messages.append({"role": "assistant", "content": answer})
