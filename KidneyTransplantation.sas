* 11-Dec-2017;
* Kiumars Zolfaghari;
* Kidney Transplant data from 2006 to 2018 available publicly by UNOS data base;
************;
* Some notes;
* Variable defintion:
* COMPOSITE_DEATH_DATE= Composite Patient Death Date from OPTN or Verified from External Sources
* TX_DATE= TRR Transplant Date
* PX_STAT_DATE= Date of Death, Re-TX or Last Follow-Up
* The combinations:
* Always Gtime=PX_STAT_DATE - TX_DATE;
* Almost always the PTIME=PX_STAT_DATE - TX_DATE;
* But when the px_stat is equal to "A", "R", or "L" and the PSTATUS is "1" then the PTIME=COMPOSITE_DEATH_DATE - TX_DATE!
* When the px_stat="D", the Pstatus is always=1 and so COMPOSITE_DEATH_DATE = PX_STAT_DATE. Then PTIME=PX_STAT_DATE - TX_Date;
* After all these special cases are very few in relative to the whole data, here aout 300 cases;
* There is not any case that the px_stat is (A,D,R) and pstatus is 1 and ptime is less than 30 days;

*Glossory;
	*Transplant Recipient Registration (TRR)
	*Transplant Candidate Registration (TCR)
	*Transplant Recipient Follow-up (TRF)
	*Deceased Donor Registration (DDR)?
	*Living Donor Registration (LDR)?;

*Patient Variables
Age 
Sex
Employment status
BMI
Transplant history
Multiple organ recipient? (Yes, No)
Length of inpatient hospitalization stay prior to transplant
"Medical condition” at time of transplant (i.e., ICU, hospitalized, not hospitalized)
LVAD statWORK_INCOME_TCRus (lvad, rvad, both, none)
;
* Notes:
* Two Diagnosis variables are consistent among 4 different data sets DGN_TCR/TCR_DGN and Diag/Diag_KI, I used DGN_TCR as the primary diagnosis at listing;
* Two variables for previous Transplantation, both are binary but are not completely consistent, PREV_TX and NUM_PREV_TX;
	** Kidney pancreas file has more variables reagarding previous transplant : PREV_TX NUM_PREV_TX PREV_KI_TX PREV_PA_TX PREV_TX NPKID NPPAN
* If we want to remove any previous transplant history we should use NUM_PREV_TX=0 and PREV_TX ="N";


LIBNAME mainT 'K:\PsychResearch\DATA'; 
LIBNAME KIDEXP 'K:\PsychResearch\DATA\EXPORT';
LIBNAME TRANS "K:\PsychResearch\DATA\Work" ; options user = TRANS;


proc contents data=mainT.kidpan_data;run; 
proc contents data=KIDEXP.kidpan5_2006_2015(keep=KDPI KDRI_MED KDRI_RAO);run;
proc sql; select  min(tx_date) format mmddyy10.,max(tx_date) format mmddyy10. from KIDEXP.kidpan5_2006_2015; quit;
**********************************************************************************************************;	

* We won't need pancreas for this project but lets make the variables so it would be complete;
data Kidpan0(COMPRESS=YES); set mainT.kidpan_data(where=('01jan2006'd <= /*admission_date*/ tx_date <= '30JUN2018'd));
array notmiss age age_don ; do over notmiss; if notmiss=. then Delete;end;
keep age age_don gender gender_don bmi_calc bmi_don_calc Organ 
PT_CODE DONOR_ID WL_ID_CODE HIST_DIABETES_DON
PREV_KI_DATE  
NUM_PREV_TX PREV_KI_DATE PRVTXDIF_KI PRVTXDIF_PA NPKID NPPAN PREV_KI_TX PREV_PA_TX PREV_TX MULTIORG tx_date
/*DGN_TCR COD2_KI COD2_OSTXT_KI INIT_EPTS END_EPTS RESUM_MAINT_DIAL_DT RESUM_MAINT_DIAL
CONTIN_ALCOHOL_OLD_DON HIST_IV_DRUG_OLD_DON CONTIN_IV_DRUG_OLD_DON
INSULIN_DUR_DON INSULIN_DEP_DON
HIST_CIG_DON  HIST_COCAINE_DON  HIST_OTH_DRUG_DON CONTIN_CIG_DON  CONTIN_COCAINE_DON CONTIN_OTH_DRUG_DON  PRE_AVG_INSULIN_USED_TRR (too many missing)*/      
PX_STAT PX_STAT_DATE PSTATUS composite_death_date ptime LOS  DISCHARGE_DATE   
DON_TY ETHCAT ETHNICITY ETHCAT_DON 
PRI_PAYMENT_TRR_KI PRI_PAYMENT_TRR_PA DONOR_ID PT_CODE 
FAILDATE_KI FAILDATE_PA GRF_STAT_KI GRF_STAT_PA  GSTATUS_KI GSTATUS_PA GTIME_KI GTIME_PA   
PX_STAT PX_STAT_DATE PSTATUS composite_death_date ptime LOS DISCHARGE_DATE DAYSWAIT_CHRON_KI
DIAB  HIST_HYPERTENS_DON DIABETES_DON INSULIN_DON DIALYSIS_DATE DIAL_DATE DIAL_TRR FIRST_WK_DIAL ON_DIALYSIS 
DWFG_KI COD2_KI COD2_OSTXT_KI KDPI KDRI_MED KDRI_RAO
PERIP_VASC;
run; *232374 obs and 66  variables;
proc freq data=mainT.kidpan_data; Table CONTIN_ALCOHOL_OLD_DON  HIST_ALCOHOL_OLD_DON  CONTIN_CIG_DON HIST_CIG_DON ; run; 

* KDPI is missing for about 40% of the data;
proc format library=work;
value age_fmt
50-59='50-59 years' 
60-69='60-69 years'
70-79='70-79 years';
run;
proc format library=work;
value age_fmt_don
18-49='18-49 years' 
50-79='50-79 years';
run;
proc freq data=Kidpan0; table organ; run;
Data kidpan1; set kidpan0 (where =(Organ='KI' and DON_TY in ('C','L')) rename=(ON_DIALYSIS=ON_DIALYSIS_char dial_trr=dial_trr_char
Diabetes_Don=Diabetes_Don_char insulin_Don=Insulin_don_char)); * let's keep only Kidny and alive/dead donors;
year=year(tx_date);
if 50 le age le 79;
if 18 le age_don le 79;
  age10=age/10; 
  age10_don=age_don/10;
  if DAYSWAIT_CHRON_KI=. then DAYSWAIT_CHRON_KI=0;
  DAYSWAIT_CHRON_KI_YR=DAYSWAIT_CHRON_KI/365;

age_G=put(age, age_fmt.);
age_don_G=put(age_don, age_fmt_don.);
if Age_don ge 50 then Age_don50=1; else Age_don50=0;
if gender='F' then female=1; if gender='M' then female=0;
if gender_don='F' then female_don=1; if gender_don='M' then female_don=0;

Livingdonor=(DON_TY="L");
Multi_org=(MULTIORG="Y");
 died30d = (pstatus=1 and (.<PTIME<=30)); 
 died90d = (pstatus=1 and (.<PTIME<=90));
 died1yr = (pstatus=1 and (.<PTIME<=365));
 died3yr = (pstatus=1 and (.<PTIME<=1095));
 died5yr = (pstatus=1 and (.<PTIME<=1825));
 died10yr= (pstatus=1 and (.<PTIME<=3650));

 Reject30d = (Gstatus_KI=1 and (.<gtime_KI<=30)); 
 Reject90d = (Gstatus_KI=1 and (.<gtime_KI<=90));
 Reject1yr = (Gstatus_KI=1 and (.<gtime_KI<=365));
 Reject3yr = (Gstatus_KI=1 and (.<gtime_KI<=1095));
 Reject5yr = (Gstatus_KI=1 and (.<gtime_KI<=1825));
 Reject10yr= (Gstatus_KI=1 and (.<gtime_KI<=3650));

 Diabetes=(DIAB IN (2,3,4,5) ); 
 Diabetes_Don=(Diabetes_Don_char IN ('Y'));
 PVD=(PERIP_VASC IN ('Y'));
 DIAL_TRR=(dial_trr_char IN ('Y'));
 ON_DIALYSIS=(ON_DIALYSIS_char IN ('Y')); * This is 1 whenever DIALYSIS_DATE is not missing;
 Hyp=(HIST_HYPERTENS_DON IN ('Y'));
 INSULIN_Don=(Insulin_don_char IN ('Y'));
 PrevTX=(PREV_TX IN ('Y'));
 if DIAL_TRR=1 then YearsonDialysis=(tx_date-DIALYSIS_DATE)/362.25; else YearsonDialysis=0;
	if YearsonDialysis le 0 then YearsonDialysis=0;

array notunknown Multiorg    ; do over notunknown; if notunknown='' or notunknown='U' then notunknown='N';end;
if PX_STAT='R' and Pstatus=1 then Delete; * There is only one case with this conmbination so lets delete it;
* ALl PREV_PA_TX is missing, now Prev_TX and Prev_KI_TX are 100% the same;
Drop Insulin_don_char ON_DIALYSIS_char Insulin_don_char DON_TY MULTIORG gender gender_don  PRI_PAYMENT_TRR_PA PREV_PA_TX FAILDATE_PA -- GSTATUS_PA
DIAB Diabetes_Don_char  HIST_DIABETES_DON PERIP_VASC  HIST_HYPERTENS_DON Prev_KI_TX PREV_TX COD2_KI COD2_OSTXT_KI dial_trr_char
; 
label Diabetes_Don='Donor DIABETES' Diabetes='TCR DIABETES' dial_trr='TRR DIALYSIS (Y,N)' ON_DIALYSIS='WL MOST RECENT CANDIDATE ON DIALYSIS?' PVD='peripheral vascular disease' 
DAYSWAIT_CHRON_KI_YR='Years on Waiting List' INSULIN_DON="Deceased Donor Registeration Insulin";
run; 

* Replace missing values of BMI with an existing value of other transplantation record for the same patient or donor
( not exact because of time difference but better than missing I think);
*adjusting patient BMI;
proc sql; create table kidpan2 as select distinct *, max(BMI_calc) as BMI_calcNew format 4.2 from kidpan1 group by pt_code;quit;
*adjusting Donor BMI;
proc sql; create table kidpan3 as select distinct *, max(bmi_don_calc) as bmi_don_calcNew format 4.2 from kidpan2 group by DONOR_ID;quit;
* replacing missing BMIs with availabel ones;
Data Kidpan4; set Kidpan3;

if BMI_calc=. and BMI_calcNew ne . then BMI_calc=BMI_calcNew;
if bmi_don_calc=. and bmi_don_calcNew ne . then bmi_don_calc=bmi_don_calcNew;
	if (/*15.0 <=*/ 1 <= bmi_calc < 18.5) then do; bmi_G='under'; *bmi_under=1; end;	* includes missing? I added "12<=" --lac jan2016 ;
	if (18.5 <= bmi_calc < 25) then do; bmi_G='norm'; *bmi_norm=1; end; *other sources say normal is 18.5-25;
	if (25 <= bmi_calc < 30.0) then do; bmi_G='over'; *bmi_over=1; end;
	if (30.0 <= bmi_calc < 35 ) then do; bmi_G='obese'; *bmi_obese=1; end;
	if (35.0 <= bmi_calc ) then do; bmi_G='35+'; *bmi_35=1; end;
	*bmi_don_under=0; *bmi_don_norm=0; *bmi_don_over=0;* bmi_don_obese=0;

	if (/*15.0 <=*/ 1 <= bmi_don_calc < 18.5) then do; bmi_don_G='under';* bmi_don_under=1; end;	* includes missing? I added "12<=" --lac jan2016 ;
	if (18.5 <= bmi_don_calc < 25) then do; bmi_don_G='norm';* bmi_don_norm=1; end; *other sources say normal is 18.5-25;
	if (25 <= bmi_don_calc < 30.0) then do; bmi_don_G='over';* bmi_don_over=1; end;
	if (30.0 <= bmi_don_calc < 35 ) then do; bmi_don_G='obese';* bmi_don_obese=1; end;
	if (35.0 <= bmi_don_calc ) then do; bmi_don_G='35+'; *bmi_don_35=1; end;


*There are Retranstplants that have been done in the same day, lets remove those because they are uninformative;
if PX_STAT='R' and PTIME=0 then Delete;
if PTIME=. then Delete;
PTIMEyrs=(PTIME/365.242199);
GTIMEyrs=(GTIME_KI/365.242199);
if BMI_don_calc=. or BMI_calc=. then delete; * about 1000 obs;

LABEL ptimeyrs="Patient survival time in years" DWFG_KI="Recipient Died with Functioning Kidney Graft" GTIMEyrs="Graft Survival Time (years)";
Drop BMI_calcNew bmi_don_calcNew ;
format bmi_calc bmi_don_calc DAYSWAIT_CHRON_KI_YR 5.2 ;
run; * 115818;

* We decided to keep the first Transplant of each patient, of course this would be their first transplant during the study period;
proc sort data=Kidpan4; by pt_code TX_DATE; run;
Data Kidpan5(COMPRESS=YES LABEL="Romers UNOS Kidney 2006-2018 n=113228"); set Kidpan4 ; by pt_code; if first.pt_code; run; *113228, so ~2590 rows deleted;
 proc compare data=Kidpan5 compare=KIDEXP.Kidpan5 listvar; ID PT_CODE; run;
* Data KIDEXP.Kidpan5 ; set Kidpan5;run;

proc freq; table Diabetes*dial_trr/chisq;run;
proc contents data=kidpan5;run;
proc freq data=Kidpan5; table FIRST_WK_DIAL;run;
proc print data=Kidpan5(obs=100); var DIALYSIS_DATE  tx_date FIRST_WK_DIAL DIAL_TRR ON_DIALYSIS YearsonDialysis; where  DIALYSIS_DATE gt 0; run;

**********************************************************************************************************;	
**********************************************************************************************************;	
**********************************************************************************************************;	

proc freq data=Kidpan4; table Gstatus_KI GRF_STAT_KI  GRF_FAIL_CAUSE_OSTXT_KI GRF_FAIL_CAUSE_TY_KI GRF_FAIL_CAUSE_OSTXT_KI;run;
proc freq data=Kidpan4; table died30d Reject30d died30d*Reject30d died90d*Reject90d died1yr*Reject1yr;run;
proc print data=kidpan4(obs=100); var Gstatus_KI GRF_STAT_KI GRF_FAIL_CAUSE_OSTXT_KI GRF_FAIL_CAUSE_TY_KI;run;
proc options option = work;
run;
*ANALYSIS;
*ANALYSIS;
*ANALYSIS;
*ANALYSIS;
*ANALYSIS;

LIBNAME TRANS "K:\PsychResearch\DATA\Work" ; options user = TRANS;
LIBNAME KIDEXP 'K:\PsychResearch\DATA\EXPORT';
Data Kidpan5 ; set KIDEXP.Kidpan5;run;

* Graft Survival censored for death with a functioning graft;
* In the event of death with functioning graft, the follow up period is censored at the date of death;
Data Kidpan7_L; set Kidpan5;
if  DWFG_KI='Y' then Gstatus_KI=0;
 Reject30d = (Gstatus_KI=1 and (.<gtime_KI<=30)); 
 Reject90d = (Gstatus_KI=1 and (.<gtime_KI<=90));
 Reject1yr = (Gstatus_KI=1 and (.<gtime_KI<=365));
 Reject3yr = (Gstatus_KI=1 and (.<gtime_KI<=1095));
 Reject5yr = (Gstatus_KI=1 and (.<gtime_KI<=1825));
 Reject10yr= (Gstatus_KI=1 and (.<gtime_KI<=3650));
run;
****************************************************;
****************************************************;
*Cochran Armitage test without 2018;
Data Kidpan_Cochran; set Kidpan5 (where=( year < 2018)); * because we only have 6 months of 2018 data and this would cause cochran armitage test...;
if age_G='70-79 years' then Age_older_than70="YES"; else Age_older_than70="NO";
run;
ods listing close; 
proc freq data=Kidpan_Cochran;
   tables Age_older_than70*year / trend measures cl nopercent norow
          plots=freqplot(SCALE=percent twoway=stacked  );
   test smdrc ;
run;
*Cochran Armitage test with 2018;
Data Kidpan_Cochran; set Kidpan5 ; * because we only have 6 months of 2018 data and this would cause cochran armitage test...;
if age_G='70-79 years' then Age_older_than70="YES"; else Age_older_than70="NO";
run;
ods listing close; 
proc freq data=Kidpan_Cochran;
   tables Age_older_than70*year / trend measures cl nofreq nopercent norow
          plots=freqplot(SCALE=PERCENT twoway=stacked);
   test smdrc ;
run;
*do you think we should still run analysis that teases out if diabetes is “accounting” for or “absorbing” some of the hazard ratio on obese BMI;
proc ttest data=Kidpan5 ; var BMI_don_calc  ; class Diabetes_don; run;
proc freq data=Kidpan5; table ( Diabetes ) * ( BMI_G) / chisq; run; 
proc freq data=Kidpan5; table ( age_don_G ) * ( DWFG_KI) / chisq; run; 
****************************************************;
****************************************************;
proc sql; select min (BMI_calc) as minBMI, max (BMI_calc) as maxBMI from  Kidpan5; quit; * min BMI 14.99, max BMI 63.83;
proc means data=Kidpan5 N mean std min median max fw=4 maxdec=1; var age age_don PTIMEyrs GTIMEyrs BMI_calc Bmi_don_calc LOS  DAYSWAIT_CHRON_KI_YR DAYSWAIT_CHRON_KI; run;
proc means data=Kidpan5 N mean std min median max fw=4 maxdec=1; var  age_don; class Livingdonor;run;
proc freq data=Kidpan5; table year age_G age_don_G female female_don BMI_G BMI_don_G Livingdonor diabetes Diabetes_Don prevtx Multi_org
 HYP PVD Dial_trr on_dialysis DWFG_KI;run;
/*proc freq data=Kidpan5; table died30d died90d died1yr Died3yr Died5yr Died10yr Reject30d Reject90d Reject1yr Reject3yr Reject5yr Reject10yr;run;*/
proc freq data=Kidpan5; table died30d; run;
proc freq data=Kidpan5; table died90d ; where tx_date <= '30MAR2018'd; run;
proc freq data=Kidpan5; table died1yr ; where tx_date <= '30JUN2017'd; run;
proc freq data=Kidpan5; table Died3yr ; where tx_date <= '30JUN2015'd; run;
proc freq data=Kidpan5; table Died5yr ; where tx_date <= '30JUN2013'd; run;
proc freq data=Kidpan5; table Died10yr ; where  tx_date <= '30JUN2008'd; run;

proc freq data=Kidpan7_L; table Reject30d ;run;
proc freq data=Kidpan7_L; table Reject90d ;where tx_date <= '30MAR2018'd; run;
proc freq data=Kidpan7_L; table Reject1yr; where tx_date <= '30JUN2017'd; run;
proc freq data=Kidpan7_L; table Reject3yr ;where tx_date <= '30JUN2015'd; run;
proc freq data=Kidpan7_L; table Reject5yr ;where tx_date <= '30JUN2013'd; run;
proc freq data=Kidpan7_L; table Reject10yr;where  tx_date <= '30JUN2008'd; run;
* Tests by Age groups;
proc freq data=Kidpan5; table ( age_G ) * ( female female_don Prevtx Multi_org Livingdonor Diabetes Diabetes_Don HYP PVD Dial_trr on_dialysis DWFG_KI) /
nopercent nocol chisq; run; 
proc freq data=Kidpan5; table ( age_G ) * (  PVD ) /
nopercent nocol chisq expected cellchi2;  run;

proc freq data=Kidpan7_L; table  age_G *(Reject30d  )/ CHISQ nocol nopercent ; run;
proc freq data=Kidpan7_L; table  age_G *(Reject90d  )/ CHISQ nocol nopercent ; where tx_date <= '30MAR2018'd; run;
proc freq data=Kidpan7_L; table  age_G *(Reject1yr  )/ CHISQ nocol nopercent ; where tx_date <= '30JUN2017'd; run;
proc freq data=Kidpan7_L; table  age_G *(Reject3yr  )/ CHISQ nocol nopercent ; where tx_date <= '30JUN2015'd; run;
proc freq data=Kidpan7_L; table  age_G *(Reject5yr  )/ CHISQ nocol nopercent ; where tx_date <= '30JUN2013'd; run;
proc freq data=Kidpan7_L; table  age_G *(Reject10yr  )/ CHISQ nocol nopercent ; where tx_date <= '30JUN2008'd; run;

proc freq data=Kidpan5; table  age_G *(died30d )/CHISQ nocol nopercent; run;
proc freq data=Kidpan5; table  age_G *(died90d )/CHISQ nocol nopercent; where tx_date <= '30MAR2018'd; run;
proc freq data=Kidpan5; table  age_G *(died1yr)/CHISQ nocol nopercent; where tx_date <= '30JUN2017'd; run;
proc freq data=Kidpan5; table  age_G *(Died3yr )/CHISQ nocol nopercent; where tx_date <= '30JUN2015'd; run;
proc freq data=Kidpan5; table  age_G *(Died5yr )/CHISQ nocol nopercent; where tx_date <= '30JUN2013'd; run;
proc freq data=Kidpan5; table  age_G *(Died10yr)/CHISQ nocol nopercent; where  tx_date <= '30JUN2008'd; run;


proc means data=Kidpan5 mean std min median max fw=4; class age_G; var age age_don PTIMEyrs GTIMEyrs BMI_calc Bmi_don_calc LOS  DAYSWAIT_CHRON_KI; run;

* P-values for continuous variables;
proc anova data=Kidpan5; class age_G; model age_don=age_G; run; * P<.001;
proc anova data=Kidpan5; class age_G; model BMI_calc=age_G; run; * P<.001;
proc anova data=Kidpan5; class age_G; model Bmi_don_calc=age_G; run; * P<.001;
proc anova data=Kidpan5; class age_G; model LOS=age_G; run; * P<.001;
proc anova data=Kidpan5; class age_G; model DAYSWAIT_CHRON_KI_YR=age_G; run; * P<.001;

proc anova data=Kidpan5; class age_G; model DAYSWAIT_CHRON_KI_YR=age_G; run; * p=0.6;
proc anova data=Kidpan5; class age_G; model PTIMEyrs=age_G; run; * P<.001;
	proc npar1way wilcoxon data=Kidpan5; class age_G; var PTIMEyrs; run;
proc anova data=Kidpan5; class age_G; model GTIMEyrs=age_G; run; * P<.001;

* KM curves ;
/* Check proportionality assumption*/
ods listing gpath="K:\PsychResearch\DATA\Work";
PROC LIFETEST NOTABLE DATA=Kidpan5 alpha=0.05 PLOTS=(ls,lls) nocens MAXTIME=15;
TITLE 'Survival by Age group';
TIME PTIMEyrs*PSTATUS(0); 
STRATA Age_G;
quit;

* Do the same thing for Graft Survival;
PROC LIFETEST NOTABLE DATA=Kidpan7_L alpha=0.05 PLOTS=(ls, lls) nocens graphics ;
TITLE 'Graft Survival by Age group';
TIME GTIMEyrs*Gstatus_KI(0);
STRATA Age_G;
quit;
* I tested BMI_G and BMI_don_G here- Age_G, BMi_G, and Bmi_Don_G don't look completely proportional;
* Below is another test for porpotionality, the significant p-Value for each variable in the "test" section 
will be considered as not meeting the proportionality assumption for that variable;
proc phreg data=Kidpan7_L;
class Age_G;
  model gtime_KI*Gstatus_KI(0)= female Diabetes YearsonDialysis
	 	age10_don female_don Diabetes_Don 
			/*BMI_G BMI_don_G*/
				  PrevTx Multi_org Livingdonor 
					Hyp PVD on_dialysis DAYSWAIT_CHRON_KI_YR
femalet Diabetest YearsonDialysist age10_dont female_dont Diabetes_Dont
PrevTxt Multi_orgt Livingdonort Hypt PVDt on_dialysist DAYSWAIT_CHRON_KIt/rl ties=efron;

 * Age_Gt = Age_G*log(gtime_KI);
 femalet = female*log(gtime_KI); Diabetest = Diabetes*log(gtime_KI);YearsonDialysist = YearsonDialysis*log(gtime_KI);
	    age10_dont = age10_don*log(gtime_KI); female_dont = female_don*log(gtime_KI); Diabetes_Dont = Diabetes_Don*log(gtime_KI);
			  PrevTxt = PrevTx*log(gtime_KI); Multi_orgt = Multi_org*log(gtime_KI); Livingdonort = Livingdonor*log(gtime_KI);
				    Hypt = Hyp*log(gtime_KI); PVDt = PVD*log(gtime_KI); on_dialysist = on_dialysis*log(gtime_KI); DAYSWAIT_CHRON_KIt = DAYSWAIT_CHRON_KI_YR*log(gtime_KI);
					
  proportionality_test: test  femalet, Diabetest, YearsonDialysist, age10_dont, female_dont, Diabetes_Dont,
PrevTxt, Multi_orgt, Livingdonort, Hypt, PVDt, on_dialysist, DAYSWAIT_CHRON_KIt;
run; 
* keep track, these variables Don't look good/ok:
female Diabetes Multi_orgt Livingdonort Hypt ;


* Test fot the AGE_G variable;
Data Kidpan7_L2;
set Kidpan7_L;
if Age_G="50-59 years" then Age_G2=50;
if Age_G="60-69 years" then Age_G2=60;
if Age_G="70-79 years" then Age_G2=70;
run;

proc phreg data=Kidpan7_L2;
class Age_G2;
  model gtime_KI*Gstatus_KI(0)= Age_G2 Age_G2t
female Diabetes YearsonDialysis
	 	age10_don female_don Diabetes_Don 
			/*BMI_G BMI_don_G*/
				  PrevTx Multi_org Livingdonor 
					Hyp PVD on_dialysis DAYSWAIT_CHRON_KI_YR
femalet Diabetest YearsonDialysist age10_dont female_dont Diabetes_Dont
PrevTxt Multi_orgt Livingdonort Hypt PVDt on_dialysist DAYSWAIT_CHRON_KIt/rl ties=efron;

 femalet = female*log(gtime_KI);   Diabetest = Diabetes*log(gtime_KI);   YearsonDialysist = YearsonDialysis*log(gtime_KI);
	    age10_dont = age10_don*log(gtime_KI);   female_dont = female_don*log(gtime_KI);    Diabetes_Dont = Diabetes_Don*log(gtime_KI);
			  PrevTxt = PrevTx*log(gtime_KI);   Multi_orgt = Multi_org*log(gtime_KI);    Livingdonort = Livingdonor*log(gtime_KI);
				    Hypt = Hyp*log(gtime_KI);   PVDt = PVD*log(gtime_KI); on_dialysist = on_dialysis*log(gtime_KI);  
						DAYSWAIT_CHRON_KIt = DAYSWAIT_CHRON_KI_YR*log(gtime_KI);
  proportionality_test: test  Age_G2t, femalet, Diabetest, YearsonDialysist, age10_dont, female_dont, Diabetes_Dont,
PrevTxt, Multi_orgt, Livingdonort, Hypt, PVDt, on_dialysist, DAYSWAIT_CHRON_KIt;
run; 
* keep track, these variables Don't look good/ok:
Age_G female Diabetes Multi_orgt Hypt ;
* We haven't test BMI here ;


ods listing gpath="K:\...\WORKDict";

* Checking the model fit; 
* USE Diabetes and not BMI;
proc phreg data=Kidpan7_L;
class Age_G BMI_G(ref='norm') BMI_don_G(ref='norm');
model gtime_KI*Gstatus_KI(0)= female 
	 	age10_don  Diabetes_Don 
			/*BMI_G BMI_don_G*/
				  PrevTx  Livingdonor 
					 PVD on_dialysis DAYSWAIT_CHRON_KI_YR ;
output out=residuals xbeta=xb resmart=mres resdev=dev logsurv=cs;
run;
data residuals;
set residuals;
cs=-cs;
run;
/* Cox-snell*/
proc lifetest data=residuals plots=(ls) notable ;
time cs*Gstatus_KI(0);
run;
* This looks good, should be 45 degree line;

/* martingle */
proc sgplot data=residuals;
refline 0/axis=y;
scatter y=mres x=xb;
run;
* Not good;

/* Deviance*/
* Range between -1 and 1 is ideal;
proc sgplot data=residuals;
refline 0/axis=y;
scatter y=dev x=xb;
run;
* Not good;

/* Assess the PH model Assumption using Schoenfield residuals*/

proc phreg data=Kidpan7_L;
class Age_G BMI_G(ref='norm') BMI_don_G(ref='norm');
model gtime_KI*Gstatus_KI(0)=Age_G female Diabetes
	 	age10_don female_don Diabetes_Don 
			/*BMI_G BMI_don_G*/
				  PrevTx Multi_org Livingdonor 
					Hyp PVD on_dialysis DAYSWAIT_CHRON_KI_YR ; 
output out=schoen  ressch= schAge_G schAge_G2 /* since Age_G has 3 levels*/ schfemale schDiabetes schage10_don schfemale_don schDiabetes_Don schPrevTx schMulti_org schLivingdonor schHyp schPVD
schon_dialysis schDAYSWAIT_CHRON_KI_YR;
run;

Data schoen; set schoen;
loggtime_KI=log(gtime_KI);
run;

proc means; var NUM_PREV_TX;run;
ods select FitPanel;
proc loess data=schoen  PLOTS(MAXPOINTS=10000000);
model schMulti_org=gtime_KI/ smooth=0.2 0.4 0.6 0.8;
run;

ods select FitPanel;
proc loess data=schoen PLOTS(MAXPOINTS=10000000);
model schMulti_org=loggtime_KI/ smooth=0.2 0.4 0.6 0.8;
run;
* keep track, these variables looks good/ok:
female  age10_don female_don Diabetes_Don PrevTx Multi_org PVD;
* keep track, these variables Don't look good/ok:
Diabetes Livingdonor Hyp on_dialysis;

*below is to just test the BMI;
proc phreg data=Kidpan7_L;
class Age_G BMI_G(ref='norm') BMI_don_G(ref='norm');
model gtime_KI*Gstatus_KI(0)=Age_G female /*Diabetes Diabetes_Don*/
	 	age10_don female_don  
			BMI_G BMI_don_G
				  PrevTx Multi_org Livingdonor 
					Hyp PVD on_dialysis DAYSWAIT_CHRON_KI_YR ;
output out=schoen  ressch= schAge_G schAge_G2 schfemale  schage10_don schfemale_don schBMI_G1 schBMI_G2 schBMI_G3 schBMI_G4 
schBMI_don_G1 schBMI_don_G2 schBMI_don_G3 schBMI_don_G4  schPrevTx schMulti_org schLivingdonor schHyp schPVD
schon_dialysis schDAYSWAIT_CHRON_KI_YR;
run;
Data schoen; set schoen;
loggtime_KI=log(gtime_KI);
run;
proc means; var NUM_PREV_TX;run;
ods select FitPanel;
proc loess data=schoen  PLOTS(MAXPOINTS=10000000);
model schBMI_don_G4=gtime_KI/ smooth=0.2 0.4 0.6 0.8;
run;

ods select FitPanel;
proc loess data=schoen PLOTS(MAXPOINTS=10000000);
model schBMI_don_G4=loggtime_KI/ smooth=0.2 0.4 0.6 0.8;
run;

* keep track, these variables looks good/ok:
schBMI_G1 schBMI_G2 schBMI_G3 schBMI_G4 schBMI_don_G1 schBMI_don_G2;
* keep track, these variables Don't look good/ok:
schBMI_don_G3;


**************************************************************************************
* How things change if we limit the study to those with at least 10 years of follow up - was no different;
**************************************************************************************;

* So now we know that for Graft Survival not all variables follow the proportionality assumption, we can remove those from the model, but 
the problem is that Age_G is not proportional, let's now try to fit an AFT model, and wee if we can compare the models;
* Among Parametric models, Weibull and Gamma has lower AICs;
proc lifereg data=Kidpan7_L;
class Age_G;
  model gtime_KI*Gstatus_KI(0)= female Diabetes YearsonDialysis
	 	age10_don female_don Diabetes_Don 
			/*BMI_G BMI_don_G*/
				  PrevTx Multi_org Livingdonor 
					Hyp PVD on_dialysis DAYSWAIT_CHRON_KI_YR/dist=Gamma;
					output out=Weibout cdf=f cresidual=csr sresidual=sr;
run; * AIC: 94997 ;
data Weibout2;
  set Weibout;
  cox = -log( 1-f );
run;
proc lifetest data=Weibout2 outsurv=surv_wei noprint;
  time cox*Gstatus_KI(0);
run;
data surv_wei;
  set surv_wei;
  ls = -log(survival);
run;
axis1 order=(0 to 2.5 by 0.5) minor=none label=('Weibull Reg Model Cum Hazard');
axis2 order=(0 to 2.5 by 0.5) minor=none label=( a=90 'Kaplan-Meier Cum Hazard');
symbol1 i=l1p  c= blue v=dot h=.4;
symbol2 i = join c = red l = 3;
proc gplot data=surv_wei;
  plot (ls cox)*cox / overlay haxis=axis1 vaxis= axis2;
run;
quit;
* Check cox snell residulas;
proc lifetest data=Weibout plot=(ls) notable graphics;
time csr*Gstatus_KI(0);
run;

proc lifereg data=Kidpan7_L;
class Age_G;
  model gtime_KI*Gstatus_KI(0)= female Diabetes YearsonDialysis
	 	age10_don female_don Diabetes_Don 
			/*BMI_G BMI_don_G*/
				  PrevTx Multi_org Livingdonor 
					Hyp PVD on_dialysis DAYSWAIT_CHRON_KI_YR/dist=Gamma;
					output out=Gamout cdf=f cresidual=csr sresidual=sr;
run; * AIC: 94647  ;
data Gamout2;
  set Gamout;
  cox = -log( 1-f );
run;
proc lifetest data=Gamout2 outsurv=surv_wei noprint;
  time cox*Gstatus_KI(0);
run;
data surv_wei;
  set surv_wei;
  ls = -log(survival);
run;
axis1 order=(0 to 2.5 by 0.5) minor=none label=('Weibull Reg Model Cum Hazard');
axis2 order=(0 to 2.5 by 0.5) minor=none label=( a=90 'Kaplan-Meier Cum Hazard');
symbol1 i=l1p  c= blue v=dot h=.4;
symbol2 i = join c = red l = 3;
proc gplot data=surv_wei;
  plot (ls cox)*cox / overlay haxis=axis1 vaxis= axis2;
run;
quit;
* Check cox snell residulas;
proc lifetest data=Weibout plot=(ls) notable graphics;
time csr*Gstatus_KI(0);
run;




* USE Diabetes and not BMI;
proc phreg data=Kidpan7_l ;
class Age_G BMI_G(ref='norm') BMI_don_G(ref='norm')  ;
model gtime_KI*Gstatus_KI(0)= 
	Age_G female Diabetes
	 	age10_don female_don Diabetes_Don 
			/*BMI_G BMI_don_G*/
				  PrevTx Multi_org Livingdonor 
					Hyp PVD on_dialysis DAYSWAIT_CHRON_KI_YR   
					     
						 
		/rl; 
run;

* USE BMI and not Diabetes;
proc phreg data=Kidpan7_l ;
class Age_G BMI_G(ref='norm') BMI_don_G(ref='norm')  ;
model gtime_KI*Gstatus_KI(0)= 
	Age_G female BMI_G
	 	age10_don female_don BMI_don_G 
				/*Diabetes Diabetes_Don*/Hyp PVD  
					   PrevTx Multi_org Livingdonor 
					Hyp PVD on_dialysis DAYSWAIT_CHRON_KI_YR 
		/rl; 
run;
proc freq data=kidpan5; table BMI_don_G*Diabetes_don/chisq; run;


***************************;
***************************;
* Some testing on the data;
***************************;
***************************;
proc freq data=Kidpan5; table HIST_DIABETES_DON year age_G age_don_G gender gender_don BMI_G BMI_don_G DON_TY PX_STAT PSTATUS MULTIORG GSTATUS_KI DIAL_TRR INSULIN_DON diabetes DIABETES_DON 
HIST_HYPERTENS_DON died30d died90d died1yr died3yr died5yr died10yr;run;
proc freq; table diab; run;

				proc freq data=Kidpan1; table HIST_DIABETES_DON INSULIN_DON *DIABETES_DON  diabetes ;run;
				proc freq data=Kidpan2; table PREV_TX*NUM_PREV_TX PREV_TX*PREV_KI_TX;run;
				proc freq data=Kidpan0; table prev_TX*(PREV_KI_TX PREV_PA_TX ); *where PREV_KI_DATE ne .; run;
				proc freq data=Kidpan1; table NPKID*NUM_PREV_TX ;run;
				proc freq data=Kidpan1; table NPKID*PREV_KI_TX ;run;

************************************* Below shows the relation between PX_stat and PSTATUS;

	Data test; set kidpan2; where PX_STAT='R';run;
	proc freq data=test; table NUM_PREV_TX PREV_KI_TX NPKID;run;
	Data testA; set kidpan2; where PX_STAT='A' and Pstatus=1;run;
	Data testL; set kidpan2; where PX_STAT='L' ;run;
	Data testP; set kidpan2; where NUM_PREV_TX ge 3;run;
	Data testB; set kidpan1; where BMI_calc=.;run;

proc sql; create table test2 as select distinct a.pt_code, a.age, a.bmi_calc, a.PREV_TX, a.NUM_PREV_TX, a.DONOR_ID, a.TX_DATE, a.PX_STAT_DATE, a.COMPOSITE_DEATH_DATE,
a.PTIME, a.PSTATUS, a.PX_STAT from kidpan2 as a inner join test on a.pt_code=test.pt_code;quit; * 2108 ;
proc sort data=test2 ;by pt_code tx_date;run;
proc print data=test2(obs=100); var  pt_code age bmi_calc PREV_TX NUM_PREV_TX DONOR_ID TX_DATE PX_STAT_DATE COMPOSITE_DEATH_DATE PTIME PSTATUS PX_STAT;
run;
proc print data=test2(obs=100); var  pt_code age bmi_calc PREV_TX NUM_PREV_TX DONOR_ID TX_DATE PX_STAT_DATE COMPOSITE_DEATH_DATE PTIME PSTATUS PX_STAT;
where PX_STAT in ('R') or (PX_stat='D' and pstatus=1); run;

proc sql; create table test2A as select distinct a.pt_code, a.age, a.bmi_calc, a.PREV_TX, a.NUM_PREV_TX, a.DONOR_ID, a.TX_DATE, a.PX_STAT_DATE, a.COMPOSITE_DEATH_DATE, a.PTIME, a.PSTATUS, a.PX_STAT
from kidpan2 as a inner join testA on a.pt_code=testA.pt_code;quit;
proc sort data=test2A ;by pt_code tx_date;run;
proc print data=test2A(obs=1000); var  pt_code age bmi_calc PREV_TX NUM_PREV_TX DONOR_ID TX_DATE PX_STAT_DATE COMPOSITE_DEATH_DATE PTIME PSTATUS PX_STAT;
where PX_STAT in ('R') or (PX_stat='A'); run;

proc sql; create table test2L as select distinct a.pt_code, a.age, a.bmi_calc, a.PREV_TX, a.NUM_PREV_TX, a.DONOR_ID, a.TX_DATE, a.PX_STAT_DATE, a.COMPOSITE_DEATH_DATE, a.PTIME, a.PSTATUS, a.PX_STAT
from kidpan2 as a inner join testL on a.pt_code=testL.pt_code;quit;
proc sort data=test2L ;by pt_code tx_date;run;
proc print data=test2L(obs=1000); var  pt_code age bmi_calc PREV_TX NUM_PREV_TX DONOR_ID TX_DATE PX_STAT_DATE COMPOSITE_DEATH_DATE PTIME PSTATUS PX_STAT; 
where px_stat ne 'L';
 run; * 0 ;
Data test2LR; set test2L; where px_stat ne 'L';run;
 proc sql; create table test2LR2 as select * from test2L where pt_code in (select pt_code from  test2LR);quit;
proc print data=test2LR2(obs=1000);
 run;

* Previous transplant;
proc sql; create table test2P as select distinct a.pt_code, a.age, a.bmi_calc, a.PREV_TX, a.NUM_PREV_TX, a.DONOR_ID, a.TX_DATE, a.PX_STAT_DATE, a.COMPOSITE_DEATH_DATE, a.PTIME, a.PSTATUS, a.PX_STAT
from kidpan2 as a inner join testP on a.pt_code=testP.pt_code;quit; * 189;
proc sort data=test2P ;by pt_code tx_date;run;
proc print data=test2P(obs=1000); var  pt_code age bmi_calc PREV_TX NUM_PREV_TX DONOR_ID TX_DATE PX_STAT_DATE COMPOSITE_DEATH_DATE PTIME PSTATUS PX_STAT;
 run;
* Missing BMI;
proc sql; create table test2B as select distinct a.pt_code, a.age, a.bmi_calc, a.PREV_TX, a.NUM_PREV_TX, a.DONOR_ID, a.TX_DATE, a.PX_STAT_DATE, a.COMPOSITE_DEATH_DATE,
a.PTIME, a.PSTATUS, a.PX_STAT from kidpan1 as a inner join testB as b on a.pt_code=b.pt_code;quit; * 257 ;
proc means n nmiss mean data=test2b;run;
proc sql; create table test3b as select distinct *, max(BMI_calc) as BMI_calcN format 4.2 from test2B group by pt_code;quit;
proc means n nmiss mean data=test3b;run;
proc sort data=test2 ;by pt_code tx_date;run;
proc print data=test2(obs=100); var  pt_code age bmi_calc PREV_TX NUM_PREV_TX DONOR_ID TX_DATE PX_STAT_DATE COMPOSITE_DEATH_DATE PTIME PSTATUS PX_STAT;
run;
proc print data=test2(obs=100); var  pt_code age bmi_calc PREV_TX NUM_PREV_TX DONOR_ID TX_DATE PX_STAT_DATE COMPOSITE_DEATH_DATE PTIME PSTATUS PX_STAT;
where PX_STAT in ('R') or (PX_stat='D' and pstatus=1); run;
**********************************************************************************************************;

/* This is just for the record, UNOS has 5 BMI field that are created as below:
bmi_calc =(wgt_kg_calc/((hgt_cm_calc/100)*(hgt_cm_calc/100)));
bmi_TCR =(WGT_KG_TCR/((HGT_CM_TCR/100)*(HGT_CM_TCR/100)));
INIT_BMI_CALC =(INIT_WGT_KG_CALC/((INIT_HGT_CM_CALC/100)*(INIT_HGT_CM_CALC/100)));
bmi_don_calc =(WGT_KG_DON_CALC/((HGT_CM_DON_CALC/100)*(HGT_CM_DON_CALC/100)));
END_BMI_CALC =(END_WGT_KG_CALC/((END_HGT_CM_CALC/100)*(END_HGT_CM_CALC/100)));*/

proc freq data=trans2006_2015; table year_TX gender gender_don Organ age_g 
age_don_g  died30d; run;
Title 'Gender by Year';
Proc freq data=trans2006_2015; table  (gender gender_don)*year_TX/nopercent norow;run;
Title 'Organ  by Year';
Proc freq data=trans2006_2015; table  (Organ )*year_TX/nopercent norow;run;
Title 'Mortality by Year';
Proc freq data=trans2006_2015; table  (Died30d)*year_TX/nopercent norow;run;
Title 'Age by Year';
proc freq data=trans2006_2015; table (age_g age_don_g)*year_TX/nopercent ;run;
Title 'Age greater than 65 and greater than 80 by year';
proc freq data=trans2006_2015; table (Age65 Age65_DON Age80 Age80_DON)*year_TX/nopercent ;run;
Title 'Gender by Organ';
proc freq data=trans2006_2015; table (gender gender_don)*(Organ )/nopercent;run;
* gender age Organ year;
* Now lets focus on 65+ and 80+;
Title 'Average Age and length of stay';
proc means data=trans2006_2015 n nmiss mean std min median max; var Age Age_don LOS ; run; * There are donors and receipients with age of zero!!!;
Title 'Age 65+ and 80+ frequency';
proc freq data=trans2006_2015; table Age65 Age65_DON age80 age80_Don;run;
Title 'Age 65+ and 80+ by gender';
proc freq data=trans2006_2015; table (age65 age80 Age65_don Age80_don)*(gender gender_don)/nopercent ;run;
Title 'Age 65+ and 80+ by Organ';
proc freq data=trans2006_2015; table (age65 age80 Age65_don Age80_don)*Organ /nopercent;run;
Title 'Age 65+ and 80+  by year';
proc freq data=trans2006_2015; table (age65 age80 Age65_don Age80_don)*Year_TX/nopercent ;run;
Title 'Age 65+ and 80+ by gender by Organ';
proc freq data=trans2006_2015; table (age65 age80 Age65_don Age80_don)*(gender gender_don)*(Organ )/nopercent;run;
Title 'Age 65+ and 80+ by gender by Year';
proc freq data=trans2006_2015; table (age65 age80 Age65_don Age80_don)*(gender gender_don)*(Year_TX )/nopercent;run;
ODS HTML CLOSE;



**********************************************************************************************************


