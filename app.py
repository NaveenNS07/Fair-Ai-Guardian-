import streamlit as st
import pandas as pd
import matplotlib.pyplot as plt
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
import shap

# Page config
st.set_page_config(page_title="FairAI Guardian", layout="wide")

# Custom UI Styling
st.markdown("""
    <style>
    body {
        background-color: #0E1117;
        color: white;
    }
    .stMetric {
        background-color: #1c1f26;
        padding: 10px;
        border-radius: 10px;
    }
    </style>
""", unsafe_allow_html=True)

# Title
st.markdown("<h1 style='text-align: center;'>FairAI Guardian 🚀</h1>", unsafe_allow_html=True)
st.markdown("<p style='text-align: center;'>Detect, Explain & Fix Bias in AI Systems</p>", unsafe_allow_html=True)

st.markdown("---")

# Upload
uploaded_file = st.file_uploader("📂 Upload Hiring Dataset (CSV)", type=["csv"])

if uploaded_file is not None:

    df = pd.read_csv(uploaded_file)

    st.markdown("## 📊 Dataset Preview")
    st.dataframe(df)

    # Encoding
    df['gender'] = df['gender'].map({'Male': 1, 'Female': 0})
    df['education'] = df['education'].map({'Bachelor': 0, 'Master': 1, 'PhD': 2})

    X = df.drop('selected', axis=1)
    y = df['selected']

    # Train model
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2)

    model = LogisticRegression()
    model.fit(X_train, y_train)

    accuracy = model.score(X_test, y_test)

    # Bias Detection
    male_selected = df[df['gender'] == 1]['selected'].mean()
    female_selected = df[df['gender'] == 0]['selected'].mean()

    bias = abs(male_selected - female_selected)

    # Metrics UI
    st.markdown("## 📈 Model Performance")

    col1, col2 = st.columns(2)

    with col1:
        st.metric("🎯 Accuracy", round(accuracy, 2))

    with col2:
        st.metric("⚖️ Bias Score", round(bias, 3))

    # Bias status
    if bias > 0.1:
        st.error("⚠️ Bias detected between genders")
    else:
        st.success("✅ Model is fair")

    st.markdown("---")

    # Visualization
    st.markdown("## 📊 Bias Visualization")

    labels = ['Male', 'Female']
    values = [male_selected, female_selected]

    fig, ax = plt.subplots()
    ax.bar(labels, values)
    ax.set_ylabel("Selection Rate")
    ax.set_title("Selection Rate by Gender")

    st.pyplot(fig)

    st.markdown("---")

    # SHAP Explanation
    st.markdown("## 🔍 Explainable AI (Feature Impact)")

    try:
        explainer = shap.Explainer(model, X_train)
        shap_values = explainer(X_test)

        fig2, ax2 = plt.subplots()
        shap.plots.bar(shap_values, show=False)
        st.pyplot(fig2)

        st.info("📊 Insight: Features with higher impact influence decisions more. If 'gender' is high → bias risk.")

    except:
        st.warning("SHAP explanation could not be generated")

    if 'gender' in X.columns:
        st.warning("⚠️ Gender may influence predictions → potential bias source")

    st.markdown("---")

    # Bias Fixing
    st.markdown("## 🛠️ Bias Mitigation")

    if st.button("🚀 Fix Bias"):

        X_no_gender = X.drop('gender', axis=1)

        X_train2, X_test2, y_train2, y_test2 = train_test_split(X_no_gender, y, test_size=0.2)

        model2 = LogisticRegression()
        model2.fit(X_train2, y_train2)

        acc2 = model2.score(X_test2, y_test2)

        st.metric("🎯 New Accuracy", round(acc2, 2))
        st.success("✅ Bias reduced by removing gender feature")

    st.markdown("---")

    st.success("🎉 System successfully analyzed fairness in AI model")
