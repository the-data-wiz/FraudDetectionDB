"""
Fraud Detection System - Streamlit Dashboard
=============================================
SETUP INSTRUCTIONS:
1. Install dependencies:
   pip install streamlit pyodbc pandas plotly

2. Update the DB_CONFIG below with your actual SQL Server details.

3. Run:
   streamlit run fraud_dashboard.py
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import pyodbc
from datetime import datetime

# ─────────────────────────────────────────────
# DATABASE CONFIG  ← Update these values
# ─────────────────────────────────────────────
DB_CONFIG = {
    "server":   "localhost\\SQLEXPRESS",   # or just "localhost" if using default instance
    "database": "FraudDetection",
    "trusted_connection": "yes",           # Use Windows Authentication (recommended for SSMS)
    # If using SQL Server login, comment out trusted_connection and use:
    # "username": "your_username",
    # "password": "your_password",
}


@st.cache_resource
def get_connection():
    conn_str = (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER=localhost;"
        f"DATABASE=FraudDetection;"
        f"Trusted_Connection=yes;"
	"TrustServerCertificate=yes;"
    )
    return pyodbc.connect(conn_str)


def run_query(sql, params=None):
    try:
        conn = get_connection()
        if params:
            df = pd.read_sql(sql, conn, params=params)
        else:
            df = pd.read_sql(sql, conn)
        return df
    except Exception as e:
        st.error(f"Database error: {e}")
        return pd.DataFrame()


def run_procedure(proc_name, params: dict):
    try:
        conn = get_connection()
        cursor = conn.cursor()
        param_placeholders = ", ".join([f"@{k} = ?" for k in params])
        cursor.execute(f"EXEC {proc_name} {param_placeholders}", list(params.values()))
        conn.commit()
        return True
    except Exception as e:
        st.error(f"Procedure error: {e}")
        return False


# ─────────────────────────────────────────────
# PAGE CONFIG
# ─────────────────────────────────────────────
st.set_page_config(
    page_title="Fraud Detection System",
    page_icon="🛡️",
    layout="wide",
    initial_sidebar_state="expanded",
)

st.markdown("""
<style>
    .metric-card {
        background: #1e1e2e;
        border-radius: 12px;
        padding: 20px;
        border-left: 4px solid;
        margin-bottom: 10px;
    }
    .critical { border-color: #ff4444; }
    .high     { border-color: #ff8800; }
    .medium   { border-color: #ffcc00; }
    .low      { border-color: #44bb44; }
    .stButton > button {
        background-color: #e63946;
        color: white;
        border-radius: 8px;
        border: none;
        padding: 8px 20px;
    }
</style>
""", unsafe_allow_html=True)

# ─────────────────────────────────────────────
# SIDEBAR NAVIGATION
# ─────────────────────────────────────────────
st.sidebar.image("https://img.icons8.com/color/96/shield.png", width=80)
st.sidebar.title("🛡️ Fraud Detection")
st.sidebar.markdown("---")

page = st.sidebar.radio(
    "Navigation",
    ["📊 Dashboard", "🔍 Transactions", "🚨 Fraud Alerts",
     "👥 Customers", "⛔ Blacklist", "🔧 Admin Tools"],
    label_visibility="collapsed"
)

st.sidebar.markdown("---")
st.sidebar.markdown("**Database:** FraudDetection")
st.sidebar.markdown("**Tool:** SQL Server (SSMS)")

# ─────────────────────────────────────────────
# PAGE: DASHBOARD
# ─────────────────────────────────────────────
if page == "📊 Dashboard":
    st.title("📊 Fraud Detection Dashboard")
    st.markdown("Real-time overview of transactions and fraud alerts.")
    st.markdown("---")

    # KPI Metrics Row
    col1, col2, col3, col4 = st.columns(4)

    total_txn    = run_query("SELECT COUNT(*) AS n FROM Transactions").iloc[0, 0]
    flagged_txn  = run_query("SELECT COUNT(*) AS n FROM Transactions WHERE Status='Flagged'").iloc[0, 0]
    blocked_txn  = run_query("SELECT COUNT(*) AS n FROM Transactions WHERE Status='Blocked'").iloc[0, 0]
    open_alerts  = run_query("SELECT COUNT(*) AS n FROM FraudAlerts WHERE IsResolved=0").iloc[0, 0]

    col1.metric("Total Transactions", total_txn)
    col2.metric("🚩 Flagged",         flagged_txn, delta=f"{round(flagged_txn/max(total_txn,1)*100,1)}%")
    col3.metric("🚫 Blocked",         blocked_txn)
    col4.metric("🔔 Open Alerts",     open_alerts)

    st.markdown("---")
    col_left, col_right = st.columns(2)

    # Alerts by Severity
    with col_left:
        st.subheader("Alerts by Severity")
        df_sev = run_query("""
            SELECT Severity, COUNT(*) AS Count
            FROM FraudAlerts
            GROUP BY Severity
        """)
        if not df_sev.empty:
            color_map = {"Critical": "#ff4444", "High": "#ff8800", "Medium": "#ffcc00", "Low": "#44bb44"}
            fig = px.pie(df_sev, names="Severity", values="Count",
                         color="Severity", color_discrete_map=color_map, hole=0.45)
            fig.update_layout(margin=dict(t=20, b=20))
            st.plotly_chart(fig, use_container_width=True)

    # Daily Fraud Stats
    with col_right:
        st.subheader("Daily Transaction Overview")
        df_daily = run_query("""
            SELECT TransactionDate, TotalTransactions, FlaggedTransactions, BlockedTransactions
            FROM vw_DailyFraudStats
            ORDER BY TransactionDate
        """)
        if not df_daily.empty:
            fig = go.Figure()
            fig.add_trace(go.Bar(name="Total",    x=df_daily["TransactionDate"], y=df_daily["TotalTransactions"],   marker_color="#4488ff"))
            fig.add_trace(go.Bar(name="Flagged",  x=df_daily["TransactionDate"], y=df_daily["FlaggedTransactions"],  marker_color="#ffcc00"))
            fig.add_trace(go.Bar(name="Blocked",  x=df_daily["TransactionDate"], y=df_daily["BlockedTransactions"],  marker_color="#ff4444"))
            fig.update_layout(barmode="group", margin=dict(t=20, b=20))
            st.plotly_chart(fig, use_container_width=True)

    # Risk Score Table
    st.subheader("Account Risk Scores")
    df_risk = run_query("""
        SELECT
            a.AccountNumber, c.FullName, a.Balance, a.Status,
            dbo.fn_GetRiskScore(a.AccountID) AS RiskScore
        FROM Accounts  a
        JOIN Customers c ON a.CustomerID = c.CustomerID
        ORDER BY RiskScore DESC
    """)
    if not df_risk.empty:
        df_risk["Risk Level"] = df_risk["RiskScore"].apply(
            lambda s: "🔴 HIGH" if s >= 70 else ("🟡 MEDIUM" if s >= 40 else "🟢 LOW")
        )
        st.dataframe(df_risk, use_container_width=True, hide_index=True)

# ─────────────────────────────────────────────
# PAGE: TRANSACTIONS
# ─────────────────────────────────────────────
elif page == "🔍 Transactions":
    st.title("🔍 Transaction Explorer")
    st.markdown("Search and filter all transactions using stored procedure `sp_SearchTransactions`.")
    st.markdown("---")

    with st.expander("🔎 Filter Transactions", expanded=True):
        col1, col2, col3 = st.columns(3)
        min_amt  = col1.number_input("Min Amount", min_value=0.0, value=0.0)
        max_amt  = col2.number_input("Max Amount", min_value=0.0, value=100000.0)
        status   = col3.selectbox("Status", ["All", "Pending", "Completed", "Flagged", "Blocked"])
        location = st.text_input("Location (partial match)", "")

    status_filter = None if status == "All" else status
    location_filter = None if not location else location

    query = """
        SELECT
            t.TransactionID, c.FullName AS Customer, a.AccountNumber,
            t.TransactionType, t.Amount, t.Currency, t.Timestamp,
            t.MerchantName, t.Location, t.IPAddress, t.Status
        FROM Transactions t
        JOIN Accounts  a ON t.AccountID  = a.AccountID
        JOIN Customers c ON a.CustomerID = c.CustomerID
        WHERE t.Amount BETWEEN ? AND ?
          AND (? IS NULL OR t.Status = ?)
          AND (? IS NULL OR t.Location LIKE '%' + ? + '%')
        ORDER BY t.Timestamp DESC
    """
    df_txn = run_query(query, (
        min_amt, max_amt,
        status_filter, status_filter,
        location_filter, location_filter
    ))

    st.markdown(f"**{len(df_txn)} transactions found**")

    def style_status(val):
        colors = {"Flagged": "background-color:#fff3cd", "Blocked": "background-color:#f8d7da",
                  "Completed": "background-color:#d4edda", "Pending": ""}
        return colors.get(val, "")

    if not df_txn.empty:
        styled = df_txn.style.applymap(style_status, subset=["Status"])
        st.dataframe(styled, use_container_width=True, hide_index=True)

        st.subheader("Transaction Amount Distribution")
        fig = px.histogram(df_txn, x="Amount", nbins=20, color="Status",
                           color_discrete_map={"Flagged": "#ffcc00", "Blocked": "#ff4444",
                                               "Completed": "#44bb44", "Pending": "#4488ff"})
        st.plotly_chart(fig, use_container_width=True)

# ─────────────────────────────────────────────
# PAGE: FRAUD ALERTS
# ─────────────────────────────────────────────
elif page == "🚨 Fraud Alerts":
    st.title("🚨 Fraud Alerts")
    st.markdown("Active alerts from view `vw_ActiveFraudAlerts`. Resolve alerts using `sp_ResolveFraudAlert`.")
    st.markdown("---")

    tab1, tab2 = st.tabs(["Active Alerts", "All Alerts History"])

    with tab1:
        df_alerts = run_query("SELECT * FROM vw_ActiveFraudAlerts ORDER BY AlertCreatedAt DESC")

        if df_alerts.empty:
            st.success("No active alerts. System is clean!")
        else:
            st.warning(f"⚠️ {len(df_alerts)} active unresolved alerts")

            for _, row in df_alerts.iterrows():
                sev_color = {"Critical": "🔴", "High": "🟠", "Medium": "🟡", "Low": "🟢"}.get(row["Severity"], "⚪")
                with st.expander(f"{sev_color} Alert #{row['AlertID']} — {row['AlertType']} | {row['CustomerName']}"):
                    c1, c2, c3 = st.columns(3)
                    c1.markdown(f"**Customer:** {row['CustomerName']}")
                    c1.markdown(f"**Account:** {row['AccountNumber']}")
                    c2.markdown(f"**Amount:** ${row['Amount']:,.2f}")
                    c2.markdown(f"**Transaction Type:** {row['TransactionType']}")
                    c3.markdown(f"**Location:** {row['Location']}")
                    c3.markdown(f"**IP Address:** {row['IPAddress']}")
                    st.markdown(f"**Message:** {row['AlertMessage']}")

                    if st.button(f"✅ Resolve Alert #{row['AlertID']}", key=f"resolve_{row['AlertID']}"):
                        success = run_procedure("sp_ResolveFraudAlert", {
                            "AlertID": int(row["AlertID"]),
                            "ResolvedBy": "Dashboard User"
                        })
                        if success:
                            st.success("Alert resolved!")
                            st.rerun()

    with tab2:
        df_all = run_query("""
            SELECT fa.AlertID, fa.AlertType, fa.Severity, fa.AlertMessage,
                   fa.IsResolved, fa.ResolvedBy, fa.CreatedAt,
                   t.Amount, c.FullName AS Customer
            FROM FraudAlerts fa
            JOIN Transactions t ON fa.TransactionID = t.TransactionID
            JOIN Accounts     a ON t.AccountID      = a.AccountID
            JOIN Customers    c ON a.CustomerID     = c.CustomerID
            ORDER BY fa.CreatedAt DESC
        """)
        st.dataframe(df_all, use_container_width=True, hide_index=True)

# ─────────────────────────────────────────────
# PAGE: CUSTOMERS
# ─────────────────────────────────────────────
elif page == "👥 Customers":
    st.title("👥 Customer Overview")
    st.markdown("Customer transaction summaries from `vw_CustomerTransactionSummary`.")
    st.markdown("---")

    df_customers = run_query("SELECT * FROM vw_CustomerTransactionSummary ORDER BY TotalAmount DESC")

    if not df_customers.empty:
        st.dataframe(df_customers, use_container_width=True, hide_index=True)

        st.subheader("Flagged Transactions per Customer")
        fig = px.bar(df_customers.sort_values("FlaggedCount", ascending=False).head(10),
                     x="FullName", y="FlaggedCount", color="FlaggedCount",
                     color_continuous_scale="Reds")
        fig.update_layout(xaxis_title="Customer", yaxis_title="Flagged Count")
        st.plotly_chart(fig, use_container_width=True)

    st.markdown("---")
    st.subheader("Customer Lookup (uses `sp_GetCustomerTransactions`)")
    df_ids = run_query("SELECT CustomerID, FullName FROM Customers ORDER BY FullName")
    if not df_ids.empty:
        options = {f"{row['FullName']} (ID: {row['CustomerID']})": row["CustomerID"]
                   for _, row in df_ids.iterrows()}
        choice = st.selectbox("Select Customer", list(options.keys()))
        cust_id = options[choice]

        df_cust_txn = run_query("""
            SELECT a.AccountNumber, t.TransactionType, t.Amount, t.Currency,
                   t.Timestamp, t.MerchantName, t.Location, t.Status
            FROM Transactions t
            JOIN Accounts  a ON t.AccountID  = a.AccountID
            JOIN Customers c ON a.CustomerID = c.CustomerID
            WHERE c.CustomerID = ?
            ORDER BY t.Timestamp DESC
        """, (cust_id,))
        st.dataframe(df_cust_txn, use_container_width=True, hide_index=True)

# ─────────────────────────────────────────────
# PAGE: BLACKLIST
# ─────────────────────────────────────────────
elif page == "⛔ Blacklist":
    st.title("⛔ Blacklist Management")
    st.markdown("Uses stored procedure `sp_AddToBlacklist`.")
    st.markdown("---")

    df_bl = run_query("SELECT * FROM Blacklist WHERE IsActive=1 ORDER BY AddedAt DESC")
    st.subheader(f"Active Blacklist Entries ({len(df_bl)})")
    st.dataframe(df_bl, use_container_width=True, hide_index=True)

    st.markdown("---")
    st.subheader("Add New Blacklist Entry")
    with st.form("blacklist_form"):
        col1, col2 = st.columns(2)
        entity_type  = col1.selectbox("Entity Type", ["IPAddress", "DeviceID", "MerchantName", "Account"])
        entity_value = col2.text_input("Entity Value (e.g. 192.168.1.1)")
        reason       = st.text_area("Reason")
        added_by     = st.text_input("Added By (your name/team)")
        submitted    = st.form_submit_button("⛔ Add to Blacklist")

        if submitted:
            if entity_value and reason and added_by:
                success = run_procedure("sp_AddToBlacklist", {
                    "EntityType":  entity_type,
                    "EntityValue": entity_value,
                    "Reason":      reason,
                    "AddedBy":     added_by
                })
                if success:
                    st.success(f"{entity_type} '{entity_value}' added to blacklist.")
                    st.rerun()
            else:
                st.warning("Please fill all fields.")

    st.markdown("---")
    st.subheader("Blacklisted Transactions")
    df_bl_txn = run_query("SELECT * FROM vw_BlacklistedTransactions ORDER BY Timestamp DESC")
    st.dataframe(df_bl_txn, use_container_width=True, hide_index=True)

# ─────────────────────────────────────────────
# PAGE: ADMIN TOOLS
# ─────────────────────────────────────────────
elif page == "🔧 Admin Tools":
    st.title("🔧 Admin Tools")
    st.markdown("Manual transaction flagging and audit log viewer.")
    st.markdown("---")

    col_left, col_right = st.columns(2)

    with col_left:
        st.subheader("Flag a Transaction Manually")
        df_txns = run_query("""
            SELECT t.TransactionID, c.FullName, t.Amount, t.Status, t.Timestamp
            FROM Transactions t
            JOIN Accounts  a ON t.AccountID  = a.AccountID
            JOIN Customers c ON a.CustomerID = c.CustomerID
            WHERE t.Status NOT IN ('Flagged','Blocked')
            ORDER BY t.Timestamp DESC
        """)
        if not df_txns.empty:
            options = {
                f"#{row['TransactionID']} — {row['FullName']} — ${row['Amount']} — {row['Status']}": row["TransactionID"]
                for _, row in df_txns.iterrows()
            }
            choice   = st.selectbox("Select Transaction", list(options.keys()))
            txn_id   = options[choice]
            reason   = st.text_area("Reason for Flagging")
            flagged_by = st.text_input("Flagged By")

            if st.button("🚩 Flag Transaction"):
                if reason and flagged_by:
                    success = run_procedure("sp_FlagTransaction", {
                        "TransactionID": int(txn_id),
                        "Reason":        reason,
                        "FlaggedBy":     flagged_by
                    })
                    if success:
                        st.success(f"Transaction #{txn_id} flagged and alert created.")
                        st.rerun()
                else:
                    st.warning("Please enter reason and your name.")

    with col_right:
        st.subheader("Audit Log")
        df_audit = run_query("""
            SELECT TOP 50 * FROM AuditLog ORDER BY ChangedAt DESC
        """)
        st.dataframe(df_audit, use_container_width=True, hide_index=True)

    st.markdown("---")
    st.subheader("Test Stored Procedures")
    with st.expander("Run sp_SearchTransactions"):
        c1, c2, c3 = st.columns(3)
        p_min    = c1.number_input("Min Amount", 0.0, key="sp_min")
        p_max    = c2.number_input("Max Amount", 100000.0, key="sp_max")
        p_status = c3.selectbox("Status", ["All", "Pending", "Completed", "Flagged", "Blocked"], key="sp_status")

        if st.button("Run Search"):
            s = None if p_status == "All" else p_status
            df_result = run_query("""
                SELECT t.TransactionID, c.FullName, t.Amount, t.Status, t.Timestamp
                FROM Transactions t
                JOIN Accounts  a ON t.AccountID  = a.AccountID
                JOIN Customers c ON a.CustomerID = c.CustomerID
                WHERE t.Amount BETWEEN ? AND ?
                  AND (? IS NULL OR t.Status = ?)
                ORDER BY t.Timestamp DESC
            """, (p_min, p_max, s, s))
            st.dataframe(df_result, use_container_width=True, hide_index=True)
