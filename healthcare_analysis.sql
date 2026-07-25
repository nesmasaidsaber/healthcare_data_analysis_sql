--Dataset normalization 
create table hospital(
id serial primary key,
hospital_name varchar(255) not null unique);


create table doctors(
id serial primary key,
doctor_name varchar(255) not null,
);

create table insurance_provider(
id serial primary key, provider_name varchar(255) not null unique );

create table patient(
id serial primary key,
patient_name varchar(255),
age int,
gender varchar(25),
blood_type varchar(10),
medical_condition varchar(255));

create table admission(
id serial primary key,
patient_id int references patient(id),
hospital_id int references hospital(id),
doctor_id int references doctors(id),
insurance_provider_id int references insurance_provider(id),
admission_date date,
admission_type varchar(55),
room_num int,
billing_amount numeric(12,5),
discharge_date date,
medication varchar(255),
test_result text
);
--populate hospital table
insert into hospital(hospital_name)
select distinct h."Hospital"
from healthcare_dataset h
where "Hospital" is not null;

--populate insurance_provider table
insert into insurance_provider(provider_name)
select "Insurance Provider" 
from healthcare_dataset
where "Insurance Provider" is not null
on conflict (provider_name) do nothing;

--TRUNCATE TABLE insurance_provider RESTART IDENTITY CASCADE;

-- populate doctors table
insert into doctors(doctor_name)
select distinct hd."Doctor" 
from healthcare_dataset hd
where hd."Doctor" is not null;

--populate patient dataset
insert into patient(patient_name, age, gender, blood_type, medical_condition)
select  "Name", "Age", "Gender", "Blood Type", "Medical Condition"
from healthcare_dataset hd
where "Name" is not null;


--populate admission table bridge table between 3 datasets
insert into admission(patient_id, hospital_id, doctor_id, insurance_provider_id, 
admission_date, admission_type, room_num,  discharge_date, medication, test_result)
select distinct p.id,
h.id,
d.id, 
ip.id, 
hd."Date of Admission"::DATE, 
hd."Admission Type", 
hd."Room Number",  
hd."Discharge Date"::DATE, 
hd."Medication", hd."Test Results"
from healthcare_dataset hd 
join hospital h on h.hospital_name= hd."Hospital" 
join insurance_provider ip on ip.provider_name = hd."Insurance Provider"
join patient p on p.patient_name = hd."Name" AND p.age = hd."Age"::INT 
              AND p.gender = hd."Gender"
join doctors d on d.doctor_name = hd."Doctor"; 

--TRUNCATE TABLE admission RESTART IDENTITY CASCADE;
--TRUNCATE TABLE patient RESTART IDENTITY CASCADE;



select count(*) from hospital;

select count(distinct insurance_provider_id) from admission;
select count (distinct "Insurance Provider")
from healthcare_dataset;
--Data Cleaning
--check for duplicates
SELECT patient_id  , COUNT(*) AS occurrences
FROM admission
GROUP BY patient_id  
HAVING COUNT(*) > 1;

--check for missing data
SELECT * 
FROM insurance_provider ip 
WHERE id IS NULL 
   OR ip.provider_name  IS NULL;

select count (*) from healthcare_dataset;


--Fixing the text case for patient_name in patient table
update patient
set patient_name= initcap(patient_name);

--fix billing_amount column
select sum(billing_amount) from admission as sum_admission;

select sum("Billing Amount") from healthcare_dataset as sum_hd;

UPDATE healthcare_dataset SET "Billing Amount" = NULL;


ALTER TABLE healthcare_dataset 
ALTER COLUMN "Billing Amount" TYPE NUMERIC(15, 2);


--create a temp table to reimport billing data
create table  temp_billing_import (
    id int, -- Change this to match your ID column type (e.g., INT)
    new_billing_amount NUMERIC
);

select * from admission limit 10;
select sum(billing_amount) from admission ;

--fixing the billing amount in admission table
UPDATE admission 
SET billing_amount = NULL;


with stage as (SELECT id, MAX(new_billing_amount) AS clean_amount
               FROM temp_billing_import
               GROUP BY id)

UPDATE admission a
SET billing_amount = s.clean_amount
FROM stage as s
WHERE a.patient_id = s.id;


select admission_type from admission limit 10;

--Analysis
--Patients Demographics (Descriptive analysis)
--Age Distribution: total number of cases divided into age groups
select (case when p.age<=17 then 'Pediatric'
             when p.age between 18 and 64 then 'Adult'
             else 'Older Adult' END), 
       count(*)
from patient p
join admission a
on p.id= a.patient_id
group by 1
order by 2 Desc;
--  The vast majority of hospitals volume is driven by the Adult population, followed by Older Adults, while Pediatric patients represent the smallest segment of the sample.
--Gender Distribution
select distinct gender, count(*)
from patient
group by 1
order by 2 desc;
--"The sample exhibits a highly balanced gender distribution, with nearly equal representation between male and female patients. Consequently, gender does not introduce any demographic bias to the dataset."

--Blood Type Distribution
select blood_type, count(*) as blood_type_count,
round((count(*)*100.0)/(select count(*)from patient),2) as blood_type_percentage
from patient 
group by 1
order by 2 desc;
--"The dataset demonstrates a uniform distribution across all blood groups. Each of the eight blood types is equally represented, comprising approximately 12.5% of the total patient sample. This balanced distribution indicates that blood type frequency in this dataset is standardized rather than reflective of natural population variances."
--what are the most common medical condition that are included in the study?
select medical_condition, count(*)
from patient p
group by 1
order by 2 desc;
-- "The scope of this dataset is strictly limited to six primary chronic conditions: Arthritis, Diabetes, Hypertension, Obesity, Cancer, and Asthma. No other medical diagnoses are represented in the sample. Consequently, this analysis focuses exclusively on hospital utilization and emergency trends within this specific cohort of chronic diseases."

--Emergency Admission Rate
select (sum(case when admission_type= 'Emergency' then 1.0 else 0.0 end)/count(*)
)*100 as emergency_admission_rate
from admission;
--the rate of emergency admission is 33% meaning for every 100 admission there is 33 cases are emergency

--Emergency admission demographics
--Percentage of Emergency Admissions by Gender
select p.gender, 
AVG(case when a.admission_type='Emergency' then 100 else 0.0 end)
from patient p
join admission a
on p.id= a.patient_id
group by p.gender;

--The Emergency Admission Rate was nearly identical between genders, standing at 33.3% for females and 32.4% for males.

--Emergency Admissions by age

select (case when p.age<=17 then 'Pediatric'
             when p.age between 18 and 64 then 'Adult'
             else 'Older Adult' END), 
       AVG(case when a.admission_type='Emergency' then 100.0 else 0.0 end)
from patient p
join admission a
on p.id= a.patient_id 
group by 1
order by 2 Desc;

select (case when p.age<=17 then 'Pediatric'
             when p.age between 18 and 64 then 'Adult'
             else 'Older Adult' END), 
       count(a.admission_type)
from patient p
join admission a
on p.id= a.patient_id
where a.admission_type ='Emergency'
group by 1
order by 2 Desc;

--"While Adults make up the vast majority of emergency room volume (12,524 cases), Pediatric patients have the highest Emergency Admission Rate at 41.4%, meaning a child admitted to hospital is statistically more likely to be an emergency case than any other age group."

 --which chronic condition causes the highest rate of emergency admissions?
select p.medical_condition, avg(case when a.admission_type='Emergency' then 100.0 else 0.0 end)
from patient p
join admission a
on p.id = a.patient_id 
group by 1
order by 2 desc;
--"Analysis of clinical variables reveals that the Emergency Admission Rate remains uniform across all six represented chronic conditions. The likelihood of an emergency admission ranges narrowly from a low of 32.4% for Diabetes to a high of 33.9% for Obesity. This lack of variance indicates that within this dataset, the specific type of chronic diagnosis does not statistically alter the probability of an emergency-type admission."

--Length of Stay (LOS)
--Calculate the average days spent in the hospital for emergency vs. non-emergency cases
select a.admission_type, round(avg(a.discharge_date- a.admission_date),2)
from admission a 
group by 1
order by 2 desc;
--"An analysis of operational efficiency reveals a highly uniform Length of Stay (LOS) across all admission categories. Patients admitted under Emergency status remained hospitalized for an average of 15.6 days, which is virtually identical to Elective admissions (15.5 days) and Urgent admissions (15.4 days). This lack of statistical variance suggests that the mode of admission does not influence the overall duration of a patient's hospital stay within this cohort."


--Determine if emergency admissions generate more revenue per patient than regular admissions.
select admission_type, 
round(avg(billing_amount),2) as average_bill_amount,
round(sum(billing_amount),2) as total_revenue
from admission 
group by 1
order by 3 desc;
--"Financial analysis indicates that the Average Billing Amount remains uniform across all admission categories, with a negligible variance of less than $75 per patient. Emergency admissions yielded the highest average bill at $25,568.79, closely followed by Elective ($25,553.04) and Urgent ($25,496.55) admissions. However, due to slightly higher patient volumes, Elective admissions generated the highest Total Revenue for the facility at $476.69 Million, compared to $467.12 Million for Emergency services."

--Identify peak times for emergency admissions to help with hospital staffing models.
--Monthly trends
select (extract(month from admission_date)) as admission_month, count(*) as emergency_admission_volume
from admission
where admission_type ='Emergency'
group by 1
order by 2 desc;

--Day of wekk trends

select to_char(admission_date, 'day') as day_of_the_week, count(*)
from admission
where admission_type = 'Emergency'
group by 1
order by 2 DESC;

--which insurance providers are paying for the majority of emergency room visits.
select provider_name, count(*)
from admission a
join insurance_provider ip 
on a.insurance_provider_id = ip.id 
where admission_type= 'Emergency'
group by 1
order by 2 desc;
--"An analysis of the hospital's payer mix reveals equal distribution among all insurance providers for emergency admissions. Cigna recorded the highest volume with 3,677 cases, followed closely by Medicare and Aetna at 3,675 cases each. Blue Cross (3,629) and UnitedHealthcare (3,613) closely trail the rest. This lack of variance indicates that insurance status or provider type does not correlate with an increased or decreased volume of emergency room utilization in this sample."


--Average billing by hospital

select h.hospital_name, round(avg(a.billing_amount),2) as avg_billing
from hospital h 
join admission a 
on h.id= a.hospital_id 
where a.billing_amount>0
group by 1
order by 2 DESC;

select count(billing_amount) 
from admission 
where billing_amount<0;

--"During the financial analysis, negative billing anomalies were discovered in the dataset around 108, ranging down to -$1,428.84. To ensure analytical accuracy, all negative records were treated as data entries errors and filtered out, revealing that the true institutional billing average is roughly $52,000 per admission."

--does these negative bills happen more often under a specific insurance provider

select ip.provider_name, count(*) as neg_billing_count
from insurance_provider ip 
join admission a 
on ip.id  = a.insurance_provider_id 
where a.billing_amount < 0
group by 1
order by 2 desc;

--"A data quality audit was conducted to investigate the origin of the negative billing anomalies. The analysis revealed a total of 108 negative billing entries, which are evenly distributed across all five insurance providers. Blue Cross recorded the highest frequency with 24 errors, while Medicare recorded the lowest with 18. The uniform distribution of these anomalies indicates a systemic data-generation error rather than a provider-specific billing issue, justifying the global exclusion of these records from final financial modeling."

--Doctor Per ormance by Number of  Patients Treated

select d.id, d.doctor_name, count(*) as treated_cases
from doctors d 
join admission a 
on d.id = a.doctor_id 
group by 1, 2
order by 3 desc;

--Top 10 performance doctors
with ranked_doctor as (select d.id as id, d.doctor_name as doctor_name, count(*) as treated_cases, 
round(sum(a.billing_amount),2) as doctor_total_revunue,
round(avg(a.billing_amount),2) as average_revenue_per_case,
RANK() over(order by count(*) desc) as doctor_rank
from doctors d 
join admission a 
on d.id = a.doctor_id 
group by 1, 2)
select id, doctor_name, treated_cases,doctor_total_revunue, 
average_revenue_per_case, doctor_rank 
from ranked_doctor
where doctor_rank <=10;

--KPI Report: Physician Performance & Admission VolumePeak Performance: Dr. Michael Smith leads the hospital with 27 admissions, creating a clear separation from the rest of the medical staff.Core Performance Tier: A tight cluster of 4 doctors occupies Ranks 2 through 5, averaging 21 cases each, showing consistent operational output.Bracket Capacity: The threshold to enter the Top 10 tier for this period requires a minimum of 17 treated cases. Due to an equal tie at this threshold, 11 doctors mathematically qualify for the top tier.
--"An evaluation of clinician performance data was conducted to identify the highest-utilization physicians by patient volume and total generated billing. Dr. Michael Smith ranked first, managing 27 total admissions and generating $538,193.10 in revenue. Interestingly, financial output did not perfectly correlate with patient volume. For instance, Dr. John Smith managed fewer patients (22) than Dr. Robert Smith (22) but generated $506,769.02 in revenue compared to $406,075.70, indicating a higher financial yield per case."

--Find the Bottom-Ranked Doctors
--the lowest-performing doctors is typically defined by lowest patient volume or lowest revenue generated.
select d.id, d.doctor_name, count(*) as treated_cases,
ROUND(sum(billing_amount),2) as doctor_total_revenue,
ROUND(AVG(billing_amount),2) as average_revenue_per_case
from doctors d 
join admission a 
on a.doctor_id = d.id 
where a.billing_amount >0
group by 1,2
order by 3 asc, 4 asc; 

--"An analysis of underutilized clinical staff reveals a large cohort of physicians tied with an absolute low of exactly 1 patient admission each. Clinicians such as Dr. Cynthia Gray and Dr. Ricky Barker generated negligible institutional billing, with total revenues falling below $100.00 per case. These extreme low-value outliers further support the finding of systemic billing data distortion within the dataset's financial variables."

--Insurance provider billing distribution

select ip.id, ip. provider_name, 
count(*),
round(sum(a.billing_amount),2) as total_billed,
round(avg(a.billing_amount),2) as average_bill
from insurance_provider ip 
join admission a
on a.insurance_provider_id = ip.id
where a.billing_amount>0
group by 1,2
order by total_billed desc;
--A global analysis of the hospitals network's payer mix confirms a highly uniform market share distribution across all five major insurance providers. Cigna represents the largest single segment with 11,229 admissions and a leading $288.92 Million in total billing. However, the financial yield per carrier remains strictly standardized, with the average bill per admission showing a negligible variance across all providers, ranging tightly between $25,358.30 (UnitedHealthcare) and $25,759.81 (Aetna)."

--Clinical Cross-Tabulation: Epidemiological Distribution by Gender
select p.gender, p.medical_condition, count(*) volume,
round((count(*) * 100.0)/ sum(count(*)) over(partition by medical_condition),1) as gender_percentage
from patient p
join admission a
on a.patient_id = p.id 
group by 1,2
order by 2, 1;

--"A cross-tabulation of clinical diagnoses against patient gender reveals a remarkably uniform epidemiological footprint. There are no statistically significant gender biases for any of the six chronic illnesses. Female Arthritis accounts for the highest single cell count at 4,686 cases, while Female Asthma represents the lowest at 4,553 cases. This tight range confirms that the probability of diagnosis for any given chronic condition remains equal for both male and female patients within this cohort."

--Average Billing for Cancer Patients

select count(*) as cancer_patient_volume,
round(avg(a.billing_amount),2) as average_bills
from admission a
join patient p 
on p.id=a.patient_id 
where p.medical_condition = 'Cancer' and a.billing_amount >0
order by 2 desc;

--"Patients admitted with a primary diagnosis of Cancer represented a significant portion of the clinical cohort, accounting for 9,211 total admissions. Financially, this group generated a highly standardized institutional footprint, yielding an average billing amount of $25,798.31 per case, which aligns precisely with the global baseline of the hospital network."

--Conclusion
--Emergency Admission Rate: 32.9% overall.
--Demographics: Perfect balance across genders (~50/50) and all 8 blood types (~12.5% each).
--Age Distribution: High raw volume for Adults, but highest emergency risk for Pediatrics (41.4%).Clinical Prevalence: Uniform splits across all 6 conditions (including Cancer at 9,211 cases).
--Operational Metrics: Average length of stay remains fixed at ~15.5 days.
--Financial Operations: Identified negative data corruption and established a clean true billing average.
--Payer Mix: Proportional 20% split across all 5 major insurance carriers.












