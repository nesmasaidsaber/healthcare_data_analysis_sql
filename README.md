# healthcare_data_analysis_sql
SQL data analysis of a clinical dataset investigating emergency admission rates, hospital operations, patient demographics, and financial billing anomalies.
# Healthcare Utilization & Financial Data Analysis (SQL)

## 📌 Project Overview
This project delivers a comprehensive data analysis of a healthcare dataset containing around 55,500 patient admission records. Using advanced SQL queries, the analysis evaluates patient demographics, clinical prevalence, operational metrics (Length of Stay), and financial trends to uncover insights into emergency room utilization and payer behaviors.

## 🔍 Key Findings
* **Emergency Admission Baseline:** Exactly **32.9%** of all admissions enter through the emergency department.
* **The Pediatric Paradox:** While adult patients make up the vast majority of raw emergency room volume, **Pediatric patients hold the highest individual emergency admission rate at 41.4%**.
* **Clinical Parity:** The dataset exhibits a uniform distribution across gender, blood types (~12.5% each), and the six represented chronic conditions (Arthritis, Diabetes, Hypertension, Obesity, Cancer, and Asthma), each sitting tightly at an emergency admission rate of ~32% to 33%.
* **Data Quality Audit:** Uncovered and isolated **negative billing anomalies** (down to -$1,428.84) and extreme low-yield outlier bills (<$100.00). Filtering out these data corruptions revealed a true institutional billing average of **~$52,000 per admission** rather than the distorted global average of $25,500.

## 🛠️ Tech Stack & Skills Demonstrated
* **Database Environment:** SQL (DBeaver)
* **Advanced SQL Techniques:** Window Functions (`SUM() OVER(PARTITION BY)`), Conditional Aggregations (`AVG(CASE WHEN...)`), CTEs, Subqueries, and Complex Joins.
* **Analytical Skills:** Data Profiling, Baseline Demographics, Descriptive Analysis, Cross-Tabulation, and Data Quality Auditing (Anomaly Detection).
