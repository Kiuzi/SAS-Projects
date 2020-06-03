* Hyp_cr.sas;
* 21 Aug 2017;
* Kiumars Zolfaghari* ;


options pagesize=100 linesize = 150 nocenter msglevel = i NOOVP FORMdlim=" " COMPRESS=YES
	formchar="|-++++++++++=|-/|<>*" date obs=max  nofmterr errors=4 mergenoby=warn; *was nodate;
options font="lucida console" 9;


%include  "K:\CTX_CAHR_VDW_Medicine\...\StdVars.sas";*S&W; *<==Edit Pathway;
%include vdw_macs; 
*PullContinuous Macro edited to work with SWC_PAT_ID;
%include  "K:\...\PullCONT_PatID.sas";
*PDC Macro;
%include  "K:\...\PDC.sas";
* Propensity score mathcing;
* Ignore the ERROR;
%include  "K:\...\PropensityScoreMatching.sas";
* Raw data reading macro;
%include "K:\...\macro_readENR_yr_mo.sas";
****************************************************************************************************;
****************************************************************************************************;
****************************************************************************************************;
/* inclusion critera;
###1###	Clinical ASCVD,  identified by ICD9 in pre-index year (???)
###2###	Between 18 years and 85 years old
###3###	Continuous enrollment throughout study period
###4###	At least one prescription for a statin medication during the analysis period 1-year pre-index or 1-year post index
###5###	At least 1 Laboratory measurement of LDL-C during analysis period


/*  Exclusion critera;
###6###	kidney/hepatic disease identified by ICD-9, etc */
****************************************************************************************************;
****************************************************************************************************;
****************************************************************************************************;

*********
****1****
*********

* ASCVD diagnosed patients between 2012 -2016;
* Feb 2018, add the 2017 as well, we can't we need one year follow up;
Data HypWork.Hypdate; set &_vdw_dx (Where=(year(adate) in ( 2012, 2013, 2014, 2015, 2016)));
ARRAY dd origdx dx; DO OVER dd;
if UPCASE(COMPRESS(dd,".")) in: 
('410','411', '413','4292','433','434','4370','4371','440','V4581','V4582',
'I20','I21','I22','I237','I24','I25','I63','I65','I66','I672','I70','Z951','Z955','Z9582','Z986') THEN ASCVD=1;
End;
IF dx ne '' and SWC_PAT_ID ne '';
IF ASCVD;
;run; * 370268;
proc sql; select count (distinct SWC_PAT_ID) from HypWork.Hypdate; quit; * 30997;
* Patient level SWC_PAT_ID and index date;
PROC SQL;
  CREATE TABLE HypWork.Hypcoh as select SWC_PAT_ID
  , MIN(adate) as index_date format=date9.
  , MAX(adate) as ASCVDdate1 format=date9.
  , year(min(adate)) as year 
  , month (min(adate)) as month
  , COUNT(adate) as numASCVDdates
  FROM HypWork.Hypdate
  GROUP BY SWC_PAT_ID;
QUIT; * 30997;

* find demographics- this is test process for finding missing demogs; 
proc sql; create table demogHyp as select distinct a.SWC_PAT_ID, b.index_date, a.race1, a.hispanic, a.gender, a.birth_date,
gender="F" as female, gender="M" as male, race1="WH" as White, race1 in ("HL") or hispanic="Y" as hisp
from &_vdw_demographic as a inner join HypWork.Hypcoh as b on a.SWC_PAT_ID=b.SWC_PAT_ID; quit; * 19182;
Proc freq data=HypWork.demogHyp2; table gender ; run;
data test1; set HypWork.demogHyp2; age=(index_date - birth_date)/365.25; run;
data test2; set demogHyp2; age=(index_date - birth_date)/365.25; run;
Proc freq data=demogHyp2; table gender ; run;
proc means data=test1; var age; run;
proc means data=test2; var age; run;
proc print data= test2; where age le 0; run;
proc sql; create table ForE.missingdemog as select * from hypwork2.demoghyp where SWC_PAT_ID not in  (select SWC_PAT_ID from demogHyp); quit;



proc sql; create table demogHyp2 as select distinct a.SWC_PAT_ID, b.index_date, a.race1, a.hispanic, a.gender, a.birth_date,
gender="F" as female, gender="M" as male, race1="WH" as White, race1 in ("HL") or hispanic="Y" as hisp
from QC.demog_201808_20180828 as a inner join HypWork.Hypcoh as b on a.SWC_PAT_ID=b.SWC_PAT_ID; quit; * 31179;
proc sql; create table ForE.missingdemog2 as select * from hypwork2.demoghyp where SWC_PAT_ID not in  (select SWC_PAT_ID from demogHyp2); quit;

* I added birthday to the below code and the cohort size changed, check the duplicates;
* some patient(14) have more than one birthdate, I just use the maximum, for no good reason; 
PROC SQL;
  CREATE TABLE HypWork.demogHyp2 AS select distinct SWC_PAT_ID, index_date, max(birth_date) as birth_Date format mmddyy10.
  , Gender, MAX(female>0) as female, MAX(male>0) as male
  , MAX(White>0) as White , MAX(hisp>0) as Hisp
  FROM HypWork.demogHyp
  GROUP BY SWC_PAT_ID
  having sum(female, male) eq 1; * removes 4 patients;
QUIT; 

*********
****2****
*********

* Between 18 years and 89 years old;
* I prefer to get the age of each person at the time of index_date;
proc sql; create table HypWork.demoghyp3 as select *, int( (index_date - birth_date)/365.25 ) as Age
from HypWork.demogHyp2  where 18 le int( (index_date - birth_date)/365.25 ) le 89 ; quit; *29524;

*********
****3****
*********

* Continous enrollment criterion;
%PullCONT_PatID(InSet=HypWork.demoghyp3                     /* The name of the input dataset of SWC_PAT_IDs of the ppl whose enrollment you want to check. */
                     , OutSet=HypWork.ZZZdemoghyp                    /* The name of the output dataset of only the continuously enrolled people. */
                     , IndexDate=index_date                 /* Either the name of a date variable in InSet, or, a complete date literal (e.g., "01Jan2005"d) */
                     , PreIndexEnrolledMonths=12    /* The # of months of enrollment required prior to the index date. */
                     , PreIndexGapTolerance=3     /* The length of enrollment gaps in months you consider to be ignorable for pre-index date enrollment. */
                     , PostIndexEnrolledMonths=12   /* The # of months of enrollment required post index date. */
                     , PostIndexGapTolerance=3     /* The length of enrollment gaps in months you consider to be ignorable for post-index date enrollment.*/
                     , DebugOut = work           /* Libname to save interim dsets to for debugging--leave set to work to discard these. */
                     , EnrollDset = &_vdw_enroll /* For testing. */
                     ) ; *3-month gap 18680;

						proc sql; select min (index_date) as mindate format date9., max (index_date) as maxdate format date9. from HypWork.ZZZdemoghyp;quit;
						*mindate maxdate 
						01JAN2012 31DEC2016;


*********
****4****
*********

* NEW Feb 2018: At least one prescription for statin post index date;
Data HypWork.HypNDC2; set &_vdw_EverNDC;
* The warning does not affect the results;
IF INDEX(UPCASE(generic), 'STATIN') OR
INDEX(UPCASE(Brand), 'STATIN') then found1=1;
found2=(prxmatch("/\b(ADVICOR|ALTOCOR|ALTOPREV|ATORVASTATIN|CADUET|CERIVASTATIN|CRESTOR|EQUAPAX|FLOLIPID|FLUVASTATIN|
JUVISYNC|LESCOL|LIPITOR|LIPTRUZET|LIVALO|LOVASTATIN|MEVACOR|PITAVASTATIN|PRAVACHOL|PRAVASTATIN|PRAVIGARD|ROSUVASTATIN|SIMCOR|
SIMVASTATIN|VYTORIN|ZOCOR)\b/io", Brand));
*found3=(prxmatch("/\b(ADVICOR|ALTOCOR|ALTOPREV|ATORVASTATIN|CADUET|CRESTOR|EQUAPAX|FLOLIPID|FLUVASTATIN|
JUVISYNC|LESCOL|LIPITOR|LIPTRUZET|LIVALO|LOVASTATIN|MEVACOR|PITAVASTATIN|PRAVACHOL|PRAVASTATIN|PRAVIGARD|ROSUVASTATIN|SIMCOR|
SIMVASTATIN|VYTORIN|ZOCOR)\b/io", Generic));
if found1 or found2;
IF UPCASE(Brand) in:("NYSTATIN","SANDOSTATIN","IMIPENEM AND CILASTATIN","NYAMYC","NYSTOP", "FIRST") then DELETE; *These values are unwanted in Brand name;
run; *667 unique ndc;

* Find all RX one year pre post index;
proc sql; create table HypWork.HYPRX2 as select b.index_date, a.* , case when index_date-365 le rxdate lt index_date then 1 else 0 end as preindex, 
case when index_date le rxdate lt index_date+365 then 1 else 0 end as postindex from &_vdw_RX (where=( year(rxdate) in (2011, 2012, 2013, 2014, 2015, 2016, 2017))) as a
inner join HypWork.zzzdemoghyp as b on a.SWC_PAT_ID=b.SWC_PAT_ID where index_date-365 le rxdate lt index_date+365 ; quit; *1197040 ;

* Filter by Statin use only;
proc sql; create table HypWork.HYPRX30 as select distinct a.*, b.UNIT_OF_MEASURE, b.Strength, b.DOSAGE_FORM, b.Generic, b.Brand
from HypWork.HYPRX2 as a inner join HypWork.HypNDC2 as b on a.ndc=b.ndc;quit; *98968 ;

* Filter by Post- Statin use only;
proc sql; create table Hypwork.Hyprx3_SWC_PAT_ID as select distinct SWC_PAT_ID from HypWork.HYPRX30 where postindex=1;quit; * 10056 ;

* Now get all data of the above patients;
proc sql; create table HypWork.HYPRX3 as select distinct * from HypWork.HYPRX30 Where SWC_PAT_ID in (Select SWC_PAT_ID from Hypwork.Hyprx3_SWC_PAT_ID) ;quit; * 97340;


******************************************************************************************;
******************************************************************************************;
******************************************************************************************;
******************************************************************************************;
* To get the adherence of Statin in post index date we will use the PDC macro, in order to do so we need to change the data format;
Data HypWork.HYPRX40; set HypWork.HYPRX3;
GPI6='WHATEVER'; * The Macro uses GPI6 code to differentiate different drugs, it is not the case here, so we just need to define a single character variable;
if RXSUP=. and RXAMT ne . then RXSUP=RXAMT;
if 1 le RXSUP le 90; * We need to remove all missing RXSUP for the MACRO to work,
ALso there are only 4 observations with more than 180 days supply, I removed them;
run; *91808 ;

* Let me show you something;
Proc sql; create table Hypwork.HypRX4_1 as select distinct  SWC_PAT_ID, max(postindex) as postindex from Hypwork.HypRX40 group by SWC_PAT_ID  ;quit; * 10006 ;
proc freq; table postindex;run; * There are still people with postindex=0, this is because of using SWC_PAT_ID;
* S0, filter those out;
Proc sql; create table Hypwork.HypRX4_2 as select distinct  SWC_PAT_ID, max(postindex) as postindex from Hypwork.HypRX40 group by SWC_PAT_ID having postindex=1 ;quit; * 9971 ;
proc freq; table postindex;run; 

proc sql; create table Hypwork.HYPRX4 as select * from HypWork.HYPRX40 where SWC_PAT_ID in (select SWC_PAT_ID from Hypwork.HypRX4_2); quit; * 917019 ;

proc freq data=HypWork.zzzStatin; table preidx_statin*postidx_statin/ nopercent nocol;run;

%PDC_Change(
input=hypwork.HYPRX4,
output=hypwork.PDC,
indexdateVar= index_date,
ObserveWindow=365,
pid=SWC_PAT_ID,
filldt=RXDATE,
dos=RXsup,
status=post); * 9971 patients, PDC average= 0.780, those whose PDC=0 will be automatically deleted from the output;

* This is different from HYPRX4 and thats because some patients post index RXsup is missing, to be consistent let's only keep those with PDC > zero;
* Add the PDC (which is at patient level) to the HYPRX4;
* Exclude patient with missing PDC values ;
* This data includes pre and post statin use and PDC at patient level;
Proc sql; create table hypwork.zzzStatin as select distinct a.SWC_PAT_ID,  a.index_date, max(a.preindex) as preIdx_statin,
max(a.postindex) as postIdx_statin, b.PDC as PostIDX_PDCStat from hypwork.HYPRX4 as a inner join hypwork.PDC as b on a.SWC_PAT_ID=b.SWC_PAT_ID group by a.SWC_PAT_ID;
quit; *9971 SWC_pat_ID ;

proc sql; select count (distinct SWC_PAT_ID) as SWC_PAT_IDcount from HypWork.zzzStatin;run; *9971;

******************************************************************************************;
******************************************************************************************;
* Find Statin equivalent dose post index_date;
* lets provide this list for Stephanie so She can find the equivalents;
proc sort data=hypwork.HYPRX4(keep=GENERIC BRAND STRENGTH UNIT_OF_MEASURE) nodupkey out=hypwork.HYPRX50; by  GENERIC BRAND STRENGTH;
run; * 72;
*  This one has 4 more new combinations, I could verify their equivalents using the previous data sent by Stephanie;

								/* proc export 
								  data=hypwork.HYPRX50
								  dbms=xlsx 
								  outfile="K:\SWHP DMARDS FILE\DG Stephanie\ACCAHA2013\DATA\EXPORT\HypSTAINdose.xlsx" 
								  replace;
								run; */
* Stephanie sent back the file on 11/07/2017;

* By looking at all different measuremtns on strength, It seems easier if I import the file and use the exact matching from there;
proc import  out=hypwork.StatindoseEQ0
datafile= "K:\SWHP DMARDS FILE\...\HypSTAINdose_with equivalents.xlsx"
dbms=xlsx replace; getnames=Yes; sheet='HypSTAINdose'; 
run; * 77 ;

proc sql; create table hypwork.StatindoseEQ1 as select distinct a.SWC_PAT_ID, a.index_date , a.Rxdate, a.rxsup, a.preindex, a.postindex, a.strength, b.Atorvastatin_dose as ATOREQ
from hypwork.HYPRX4 as a inner join hypwork.StatindoseEQ0 as b on a.Generic=b.Generic and a.Brand=b.Brand and a.STRENGTH=b.STRENGTH;quit; * 91718;

*new Statin dose by name, max daily dose;
* This data will come to use later;
proc sql; create table hypwork.StatindoseEQ1_Names as select distinct a.SWC_PAT_ID, a.index_date , a.Rxdate, a.rxsup, a.preindex, a.postindex, b.Atorvastatin_dose as ATOREQ,
b.Generic, b.Brand, b.Strength from hypwork.HYPRX4 as a inner join hypwork.StatindoseEQ0 as b on a.Generic=b.Generic and a.Brand=b.Brand and a.STRENGTH=b.STRENGTH;quit;

* I explored patients with more than one prescription per day, some of them are due to duplicate pat ID and sometimes its a different medication,
I feel more comfortable to keep the maximum of Statin per day for each patient, this affects tiny portion of the data, about 100 obs out of 80,000;
* only for post index_date;
proc sql; create table hypwork.StatindoseEQ2 as select distinct SWC_PAT_ID, RXDATE, max(ATOREQ) as ATOREQ from hypwork.StatindoseEQ1
group by SWC_PAT_ID, RXDATE
having postindex=1;quit; * 52829;

* get the avg of ATOR EQ per patient;
* Feb 2018, change the decimals to;
proc sql; create table hypwork.ZZZStatindoseEQ as select distinct SWC_PAT_ID, round(avg(ATOREQ),10) as POSTIDX_ATOREQ from hypwork.StatindoseEQ2 group by SWC_PAT_ID;
quit; * 9971, nice; 


******************************************************************************************;
******************************************************************************************;

* Find patients with High Statin dose, post-index date which is:
Atrovastatin 40-80 mg or Rosuvastatin 20-40 mg daily;
* Start by filtering data;
Data hypwork.HYPRX5; set hypwork.HYPRX4 (where=( index_date le RXDATE lt index_date+365)); * or if Postindex=1;
If Generic in:('ATORVASTATIN') or Brand in: ('ATORVASTATIN') then ATOR=1;
else if Generic in:('ROSUVASTATIN') or Brand in: ('ROSUVASTATIN') then ROSU=1;
if ATOR or ROSU;
run; * 25587 obs ;

* Change the format of strength to numeric;
Data hypwork.HYPRX6; set hypwork.HYPRX5 (rename=(strength=strength_char));
temp_strength=substr(strength_char,1,2); * remove the 'MG' from strength vars;
Strength=input(temp_strength,best9.);
If ATOR then Strength_ATOR=Strength;
else if ROSU then Strength_ROSU=Strength;
keep SWC_PAT_ID SWC_PAT_iD RXDATE NDC ATOR ROSU Strength Strength_ATOR Strength_ROSU;
run; 

/* Separate ATOR and ROSU strength;
Data hypwork.HYPRX7; set hypwork.HYPRX6 (keep=SWC_PAT_ID SWC_PAT_iD RXDATE NDC ATOR ROSU Strength);
If ATOR then Strength_ATOR=Strength;
else if ROSU then Strength_ROSU=Strength;
run; * 24196;*/
* Get the maximum per day;
* There are only few cases with more than one prescription per day, so instead of sum per day I used the maximum, I don't trust those duplicates;
* Therefore I just get the maximum of STATIN instance post index date per patient;
proc sql; create table hypwork.HYPRX7 as select distinct SWC_PAT_ID, max(ATOR>0) as ATOR, max(ROSU>0) as ROSU, max(Strength_ATOR) as Strength_ATOR,
max(Strength_ROSU) as Strength_ROSU from hypwork.HYPRX6 group by SWC_PAT_ID;quit; * 4811; 
proc freq; table Strength_ATOR Strength_ROSU;run;
*looks good;
/* THIS IS OLD DATA

                                          Cumulative    Cumulative
Strength_ATOR    Frequency     Percent     Frequency      Percent
------------------------------------------------------------------
           10         514       13.81           514        13.81
           20         870       23.37          1384        37.17
           40        1582       42.49          2966        79.67
           80         757       20.33          3723       100.00

                      Frequency Missing = 946


                                          Cumulative    Cumulative
Strength_ROSU    Frequency     Percent     Frequency      Percent
------------------------------------------------------------------
            5         145       13.30           145        13.30
           10         337       30.92           482        44.22
           20         371       34.04           853        78.26
           40         237       21.74          1090       100.00

                     Frequency Missing = 3579


*/

* Find the high statin dose patients;
* This data has High Statin post index at patient level;
Data hypwork.zzzHighStatin; set hypwork.HYPRX7;
POSTIDX_HighStat=0;
if 40 le Strength_ATOR le 80 then POSTIDX_HighStat=1;
if POSTIDX_HighStat=0 then do;
if 20 le Strength_ROSU le 40 then POSTIDX_HighStat=1;
end;
run; 

******************************************************************************************;
******************************************************************************************;
* Lets put things together sofar;
proc sql; create table HypWork.POSTINDEX0 as select distinct a.*, b.POSTIDX_ATOREQ  format 4.1 from HypWork.zzzStatin as a
left join HypWork.ZZZStatindoseEQ as b on a.SWC_PAT_ID=b.SWC_PAT_ID ;quit; *9971;
proc sql; create table HypWork.POSTINDEX1 as select distinct a.*, b.POSTIDX_HighStat  from HypWork.POSTINDEX0 as a
left join HypWork.zzzHighStatin as b on a.SWC_PAT_ID=b.SWC_PAT_ID ;quit; 
Data HypWork.zzzPOSTINDEX; set HypWork.POSTINDEX1;
array nonmissing PostIDX_PDCStat POSTIDX_ATOREQ POSTIDX_HighStat; do over nonmissing;
if nonmissing=. then nonmissing=0;end;run; 
proc sql; select count(distinct SWC_PAT_ID) from HypWork.zzzPOSTINDEX;quit; * 9971;
*
proc datasets library=HYPWORK nolist;
   delete Hypdate demogHyp demogHyp2 demoghyp3
	HypNDC2 HYPRX2 HYPRX3 
	StatindoseEQ0 StatindoseEQ1 StatindoseEQ2
	HYPRX50 HYPRX5 HYPRX6 HYPRX7 HYPRX8
POSTINDEX0 POSTINDEX1 ;
run;
******************************************************************************************;
* This section was provided initially for Vee Anne to find the Lab data on Hypcohort patients;
******************************************************************************************;
* NEW * 
* Feb 2018;
proc sql; create table HypWork.inclusioncohort as select distinct a.MRN, b.SWC_pat_id, a.index_date, a.birth_date, a.Gender from HypWork.zzzdemoghyp as a right join
HypWork.ZZZStatin as b on a.SWC_PAT_ID=b.SWC_PAT_ID; quit; *11093;

* Add names and SSN from the raw data for verification;
proc import datafile='F:\HMORN\...\VDW_ENROLLMENT.TXT' dbms=dlm out=HypWork.ENR201801 replace;
delimiter = "|";
 getnames=yes;
 guessingrows=1000;
run;
Data HypWork.ENR201801_2; set HypWork.ENR201801(rename=(SWC_PAT_ID=SWC_PAT_ID_num BIRTH_DATE=BIRTH_DATE_old));
SWC_PAT_ID=input(SWC_PAT_ID_num,$12.);
BIRTH_DATE=datepart(BIRTH_DATE_old);
format BIRTH_DATE date9.;
run;

proc sql; create table HypWork.ZZZinclusioncohort as select distinct b.PAT_FNAME, b.PAT_LNAME, a.mrn, a.SWC_pat_id, a.birth_Date , a.index_date, a.Gender, b.SSN from 
HypWork.inclusioncohort as a left join HypWork.ENR201801_2 as b on a.SWC_PAT_ID=b.SWC_PAT_ID and a.birth_Date=b.BIRTH_DATE and a.Gender=b.Gender;quit; * 11093;
* new Feb 2018, we already have most of the cohort lab data, this time we only ask for part of the cohort that is new and of course all indexes are in 2016;
* So let's get everything for the whole 2016 cohort;
Data Hypwork.inclusion2016; set HypWork.ZZZinclusioncohort;
if year(index_date)=2016;
drop index_date;
run; * 1673;

proc export 
data=HypWork.inclusion2016 dbms=xlsx 
outfile="K:\SWHP DMARDS FILE\...\EXPORT\inclusion2016.xlsx" 
replace;
run;

* Vee Anne sent back the data on 28 Feb 2018 in text format, lets read them in;
proc import datafile='K:\SWHP DMARDS FILE\...\LABS.txt' dbms=dlm out=KZHYPEXP.LAB2016 replace;
 delimiter="|";
 getnames=yes;
 guessingrows=100;
run; * 23283 of 1240 SWC_PAT_ID;
proc sql; select count (distinct SWC_PAT_ID) from KZHYPEXP.LAB2016;quit;
proc sql; select min (LAB_DATE) as minLAB_DATE format date9., max (LAB_DATE) as maxLAB_DATE format date9. from KZHYPEXP.LAB2016;quit;

*minLAB_DATE maxLAB_DATE 
02JAN2015 30DEC2017 
;

******************************************************************************************;
******************************************************************************************;
* OLD * 
* Sep 2017;

/*proc sql; create table HypWork.ZZZinclusioncohort as select distinct SWC_PAT_ID, SWC_pat_id, birth_date, female from HypWork.ZZZHYPRX; quit; *11364;*/
/*Data KZHYPEXP.ZZZHYPRX; set HypWork.ZZZHYPRX;run;*/
/*Data KZHYPEXP.Hyp2011_2016; set HypWork.ZZZinclusioncohort;run;*

* Exporting data to EXCEL for Vee Anne;
* This was used to pull data from EPIC;
/*
								proc export 
								  data=inclusioncohort 
								  dbms=xlsx 
								  outfile="K:\SWHP DMARDS FILE\DG Stephanie\ACCAHA2013\DATA\EXPORT\Hyp2011_2016.xlsx" 
								  replace;
								run;
								* let's add the name and SSN of these patients from raw data for Vee Anne to verify;
								%READENR(2017,02);
								proc sql; create table inclusioncohort2 as select  PAT_FNAME, PAT_LNAME, b.SWC_PAT_ID, b. SWC_pat_id, DOB, Gender, SSN from Enr201702 as b where b.SWC_PAT_ID in 
								(select SWC_PAT_ID from KZHYPEXP.Hyp2011_2016);quit; * 195190;
								Data inclusioncohort3; set inclusioncohort2;
								if GENDER not in ("F","M") then Delete;
								if PAT_FNAME in: ("1","2","3","4","5","6","7","8","9") then Delete;
								run; * 195113;
								proc sql; create table inclusioncohort4 as select MAX(PAT_FNAME) as PAT_FNAME, MAX(PAT_LNAME) as PAT_LNAME , MAX(SWC_PAT_ID) as SWC_PAT_ID, MAX(SWC_PAT_ID) as SWC_PAT_ID ,
								MAX(DOB) as DOB format date9., MAX(Gender) as GENDER, MAX(SSN) as SSN
								from inclusioncohort3 group by SWC_PAT_ID; quit; * 11361 SWC_pat_id and 9321 SWC_PAT_ID;
								* This was provided later for verification; 
								proc export 
								  data=inclusioncohort4 
								  dbms=xlsx 
								  outfile="K:\SWHP DMARDS FILE\DG Stephanie\ACCAHA2013\DATA\EXPORT\Hyp2011_2016_names.xlsx" 
								  replace;
								  run;
*/
******************************************************************************************;
******************************************************************************************;
/*
* Vee Anne sent back the data on 21 SEP 2017 in text format, lets read them in;
proc import datafile='K:\SWHP DMARDS FILE\DG Stephanie\ACCAHA2013\DATA\IMPORT\FINAL HYPERLIPIDEMIA LABS W PATID.txt' dbms=dlm out=KZHYPEXP.LAB0 replace;
 delimiter="|";
 getnames=yes;
 guessingrows=100;
run;* 223332 of 8838 SWC_PAT_ID;
proc import datafile='K:\SWHP DMARDS FILE\DG Stephanie\ACCAHA2013\DATA\IMPORT\FINAL HYPERLIPIDEMIA SYSTOLIC BP W PATID.txt' dbms=dlm out=KZHYPEXP.BloodP0 replace;
 delimiter="|";
 getnames=yes;
 guessingrows=100;
run;* 967362 of 9691 SWC_PAT_ID;
* We asked for triglycerides  and Vee Anne sent back the data on 25 SEP 2017 in text format;
proc import datafile='K:\SWHP DMARDS FILE\DG Stephanie\ACCAHA2013\DATA\IMPORT\FINAL TRIGL LABS W PATID.txt' dbms=dlm out=KZHYPEXP.TRIGL0 replace;
 delimiter="|";
 getnames=yes;
 guessingrows=100;
run;* 58148 of 8684 SWC_PAT_ID;

* Lets merge Trigl0 and LAB0;

proc freq data=KZHYPEXP.LABS; table LAB_NAME; run;
*
LAB_NAME Frequency Percent 
CHOL 		59183   21.03  
HDL 		59027   20.97  
LDL 		58611   20.82  
NON_HDL 	46511   16.52
TRIGL 		58148   20.66 
;*/

* Let's keep only "LDL-C" for inclusion criterion;

*********
****5****
*********

* Talked to stephanie, We need at least one measurement of LDLC in the year post index date;
Data HypWork.Labs2LDL; set KZHYPEXP.Lab0;
where LAB_NAME="LDL";
LabDate=input(lab_date,MMDDYY10.);
resultvalue=input(result_value, best9.);
format LabDate mmddyy10.;
drop lab_date result_value;
run; *58611 of 8672;
Data HypWork.Labs2LDL2016; set KZHYPEXP.Lab2016 (rename=(Lab_date=LabDate result_val=resultvalue MRN=MRNold SWC_PAT_ID=IDold));
where LAB_NAME="LDL"; 
MRN=put(MRNold, z7.);
SWC_PAT_ID=put(IDold, z11.);
drop MRNold IDold;
run; *4558 ;
Data HypWork.LDL0; set HypWork.Labs2LDL HypWork.Labs2LDL2016;run; * 63169 ;
proc sql; create table HypWork.LDL as select distinct * from HypWork.LDL0; quit; * 60792 ;

* lets fix the date and numeric values in Trigl data;
Data HypWork.Labs2Tri; set KZHYPEXP.trigl0;
LabDate=input(lab_date,MMDDYY10.);
resultvalue=input(result_value, best9.);
format LabDate mmddyy10.;
drop lab_date result_value;
run; * 58148 of 8684; 
Data HypWork.Labs2Tri2016; set KZHYPEXP.Lab2016 (rename=(Lab_date=LabDate result_val=resultvalue MRN=MRNold SWC_PAT_ID=IDold));
where LAB_NAME="TRIGL"; 
MRN=put(MRNold, z7.);
SWC_PAT_ID=put(IDold, z11.);
drop MRNold IDold;
run; *4707;
Data HypWork.TRI0; set HypWork.Labs2Tri HypWork.Labs2Tri2016;run; * 62855 ;
proc sql; create table HypWork.TRI as select distinct * from HypWork.TRI0; quit; * 60407 ;

* Data for NonHDL;
Data HypWork.Labs2NHDL; set KZHYPEXP.Lab0;
where LAB_NAME="NON_HDL";
LabDate=input(lab_date,MMDDYY10.);
resultvalue=input(result_value, best9.);
format LabDate mmddyy10.;
drop lab_date result_value;
run; *46511 of 8404;
Data HypWork.Labs2NHDL2016; set KZHYPEXP.Lab2016 (rename=(Lab_date=LabDate result_val=resultvalue MRN=MRNold SWC_PAT_ID=IDold));
where LAB_NAME="NON_HDL"; 
MRN=put(MRNold, z7.);
SWC_PAT_ID=put(IDold, z11.);
drop MRNold IDold;
run; *4667;
Data HypWork.NHDL0; set HypWork.Labs2NHDL HypWork.Labs2NHDL2016;run; * 51178 ;
proc sql; create table HypWork.NHDL as select distinct * from HypWork.NHDL0; quit; * 48744 ;

* Data for HDL;
Data HypWork.Labs2HDL; set KZHYPEXP.Lab0;
where LAB_NAME="HDL";
LabDate=input(lab_date,MMDDYY10.);
resultvalue=input(result_value, best9.);
format LabDate mmddyy10.;
drop lab_date result_value;
run; *59027 of ;
Data HypWork.Labs2HDL2016; set KZHYPEXP.Lab2016 (rename=(Lab_date=LabDate result_val=resultvalue MRN=MRNold  SWC_PAT_ID=IDold));
where LAB_NAME="HDL"; 
MRN=put(MRNold, z7.);
SWC_PAT_ID=put(IDold, z11.);
drop MRNold IDold;
run; *4670;
Data HypWork.HDL0; set HypWork.Labs2HDL HypWork.Labs2HDL2016;run; * 63697 ;
proc sql; create table HypWork.HDL as select distinct * from HypWork.HDL0; quit; * 61263 ;

Data HypWork.Alllabs; set HypWork.LDL HypWork.NHDL HypWork.TRI HypWork.HDL; run; * 231206;
/* Waste of time!;
* now lets get the equivalent of LDLC from Non-HDL and Triglyceride by this formula provided by Stephanie from the below paper;
* https://www.ncbi.nlm.nih.gov/pubmed/24240933 ; 
*LDL=(non-HDL) - (Triglycerides/adjustable factor in table);

* Patient with no LDLC but with Triglyc and HDL;
proc sql; create table HypWork.List1 as select distinct * from HypWork.Labs2Tri where
SWC_PAT_ID not in (select SWC_PAT_ID from HypWork.Labs2LDL) and SWC_PAT_ID in (select SWC_PAT_ID from HypWork.Labs2NHDL); quit; * 59 obs ;
* Find the Non-HDL value of above patients;
proc sql; create table HypWork.list2 as select distinct * from HypWork.Labs2NHDL where SWC_PAT_ID in (select SWC_PAT_ID from HypWork.list1); quit; *56 ;
* lets put Non-HDL and TRI together based on date;
proc sql; create table HypWork.list3 as select distinct a.*,a.resultvalue as TRIresult, b.Lab_name as Labname, b.resultvalue as NHDLresult from HypWork.List1 as a
inner join HypWork.List2 as b on a.SWC_PAT_ID=b.SWC_PAT_ID and a.labdate=b.labdate ; quit; * 52 of 18 patients;
* Lets find the LDLC equivalent, All TRIGLYC values are above 400 which makes life easier;
proc sort data=HypWork.List3; by TRIresult;run;
Data HypWork.List4;
Set HypWork.List3 ;
Lab_name="LDLCEQ";
If  400 le TRIresult le 13974 then DO;
IF NHDLresult lt 100 then LDLCEQ=NHDLresult - TRIresult/11.9;
Else if 100 le  NHDLresult le 129 then LDLCEQ=NHDLresult - TRIresult/10;
Else if 130 le  NHDLresult le 159 then LDLCEQ=NHDLresult - TRIresult/8.8;
Else if 160 le  NHDLresult le 189 then LDLCEQ=NHDLresult - TRIresult/8.1;
Else if 190 le  NHDLresult le 219 then LDLCEQ=NHDLresult - TRIresult/7.5;
Else if NHDLresult ge 200 then LDLCEQ=NHDLresult - TRIresult/6.7;
END;
format LDLCEQ 6.2;
if LDLCEQ ge 0; * WHY? Because some values turn out to be minus or missing;
run; * 47 obs of 18 patients;
*Analysis Variable : LDLCEQ after removing negative values 
N   Min  5thPctl Mean Median 95thPctl Maximum 
47 17.44 24.54  94.18 95.34  172.76   201.58  ; 

Data HypWork.list5; set HypWork.List4 ( rename=(LDLCEQ=resultvalue) Drop=Lab_name Labname resultvalue TRIresult NHDLresult) HypWork.Labs2LDL;
IF LAB_NAME = '' then LAB_NAME="LDLCEQ"; run; *58658 of 8690;
*/

* Stephanie said she spoke with Dr.McNeal and she wants to include these 18 patients if their triglycerides is <13974, so we use list5 instead of labs2LDL;
	* Now, jan 2018, Stephanie wants to exclude patients with extrapolated LDLc which means using labs2LDL data instead of list5;
* One inclusion criteria is to have at least one measurement of LDL-C during the analysis period;
* this section should wait till I get the SWC_PAT_ID verification from VEe Anne;
* Which I received the new files on Sep 27th;


proc sql; create table HypWork.LDLwithIndex as select distinct a.*, b.index_date from  HypWork.LDL as a
inner join HypWork.zzzpostindex  as b on a.SWC_PAT_ID=b.SWC_PAT_ID ;quit; *51251;

* This is the complete list of SWC_PAT_IDs based on the inclusion criteria of at least one LDL measure in post index date;
proc sql; create table Hypwork.zzzHypMRNindex as select distinct SWC_PAT_ID, index_date from HypWork.LDLwithindex
where (index_date) le labdate le (index_date+364);quit; * 5870;
* keep these SWC_PAT_IDs in lab data;
proc sql; create table Hypwork.LDLwithindex2 as select distinct *, year(index_date) as year from HypWork.LDLwithindex
where SWC_PAT_ID in (select SWC_PAT_ID from Hypwork.zzzHypMRNindex);quit; * 45115;

* We want total number of LDL measurements postindex date; 
Proc sql; create table HypWork.LDLlag_count as select distinct SWC_PAT_ID, index_date, min(labdate) as LDLindex_date format mmddyy10., 
count(distinct labdate) as LDLCount from HypWork.LDLwithindex2 where (index_date) le labdate le (index_date+364) group by SWC_PAT_ID;quit; * 5870;
* and also the lag time to minimum LDL date;
Data HypWork.LDLlag_count2; set HypWork.LDLlag_count; LDLlag=LDLindex_date-index_date;run;



******************************************************************************************;
******************************************************************************************;

* lets get the minimum of post index LDL and non-hdl for each patient;

Data HypWork.Alllabs2; set HypWork.Alllabs (where=( LAB_NAME in ("LDL", "NON_HDL", "TRIGL", "HDL")));
if Lab_Name="LDL" then LDL=resultvalue; else if lab_Name="NON_HDL" then NHDL=resultvalue; else if lab_Name="TRIGL" then TRIGL=resultvalue;
else if lab_Name="HDL" then HDL=resultvalue;
run; *231206;

*group by SWC_PAT_ID and lab date and also filter the SWC_PAT_IDs by the HYPSWC_PAT_IDindex;
proc sql; create table  HypWork.Alllabs3 as select distinct a.SWC_PAT_ID, a.LabDate, min(a.LDl) as LDl, min(a.NHDL) as NHDL , min (a.TRIGL) as TRIGL,
 min (a.HDL) as HDL, b.Index_date
from HypWork.Alllabs2 as a inner join  Hypwork.zzzHypMRNindex as b on a.SWC_PAT_ID=b.SWC_PAT_ID group by a.SWC_PAT_ID, labDate
having index_date le Labdate lt index_date+365;
; quit; *10844;

		* NEW request after receiving feedback from the Journal on Dec 2018;
		* "consider using measurements that encompassed a farther out post_index time (i.e., at least 4 month)";
		Proc sql; create table Hypwork.LDL4monthGap as select distinct SWC_PAT_ID, labDate, LDL, index_Date from HypWork.Alllabs3 where 
		(index_date+120) le labDate le (index_date+364);quit; *6470;
		Proc sql; create table Hypwork.LDL4monthGap2 as select *, min(LDL) as MinLDL4monthGap from HypWork.LDL4monthGap group by SWC_PAT_ID;
		;quit;
		* The above could wasn't necessary as we have the LDLlag and we could filter by LDLlag ge 120 and reached the same result;

Proc sql; create table Hypwork.ALLlabs4 as select *, min(LDL) as MinLDL from HypWork.Alllabs3 group by SWC_PAT_ID having LDL= minLDL order by SWC_PAT_ID, labdate;
;quit; * 5982;

* some patients have more than one date equal to minLDL, so keep the first one;
Data  Hypwork.ALLlabs5; set Hypwork.ALLlabs4;
By SWC_PAT_ID LAbdate;
if first.SWC_PAT_ID;run; * 5870 patient;

* Add the minLDL Date to the Alllabs3; 
Proc sql; create table Hypwork.ALLlabs6 as select a.*, b.LABdate as LDLdate from HypWork.Alllabs3 as a left join Hypwork.ALLlabs5 as b on 
a.SWC_PAT_ID=b.SWC_PAT_ID; 
;quit; * 10844;
Data Hypwork.ALLlabs7; set Hypwork.ALLlabs6;
if TRIGL ne . then Tri_TimDif=abs(LAbdate-LDLdate);
if NHDL ne . then NHDL_TimDif=abs(LAbdate-LDLdate);
if HDL ne . then HDL_TimDif=abs(LAbdate-LDLdate);
run;
* find TRIGL PostIDX ;
proc sql; create table Hypwork.TRIGLpost as select distinct *, min(Tri_TimDif) as minTimdif from Hypwork.ALLlabs7 
group by SWC_PAT_ID;quit;
Data Hypwork.TRIGLpost2; set Hypwork.TRIGLpost;
if Tri_TimDif=minTimdif then PostIDX_TRIGL=TRIGL;run;

proc sql; create table Hypwork.TRIGLpost3 as select distinct SWC_PAT_ID, min(PostIDX_TRIGL) as PostIDX_TRIGL from Hypwork.TRIGLpost2 
group by SWC_PAT_ID;quit;* 5870;

* find NHDL PostIDX;
proc sql; create table Hypwork.NHDLpost as select distinct *, min(NHDL_TimDif) as minNHDL_TimDif from Hypwork.ALLlabs7 
group by SWC_PAT_ID;quit;
Data Hypwork.NHDLpost2; set Hypwork.NHDLpost;
if NHDL_TimDif=minNHDL_TimDif then PostIDX_NHDL=NHDL;run;
proc sql; create table Hypwork.NHDLpost3 as select distinct SWC_PAT_ID, min(PostIDX_NHDL) as PostIDX_NHDL from Hypwork.NHDLpost2 
group by SWC_PAT_ID;quit; * 5870;

* find HDL PostIDX;
proc sql; create table Hypwork.HDLpost as select distinct *, min(HDL_TimDif) as minHDL_TimDif from Hypwork.ALLlabs7 
group by SWC_PAT_ID;quit;
Data Hypwork.HDLpost2; set Hypwork.HDLpost;
if HDL_TimDif=minHDL_TimDif then PostIDX_HDL=HDL;run;
proc sql; create table Hypwork.HDLpost3 as select distinct SWC_PAT_ID, min(PostIDX_HDL) as PostIDX_HDL from Hypwork.HDLpost2 
group by SWC_PAT_ID;quit; * 5870;

* The below data has the minimum of LDL and NonHDL post index date, all patients have LDL (as it is an inclusion criterion), except 5 patients,
those are the one who have been added by LDL equivalent method used, but not all of them have the Non HDl;
proc sql; create table Hypwork.Alllabs8 as select SWC_PAT_ID, min(LDL) as POSTIDX_LDLmin format 6. 
from HypWork.Alllabs3 group by SWC_PAT_ID;quit; 
proc sql; create table Hypwork.Alllabs9 as select a.*, b.PostIDX_TRIGL format 6. 
from HypWork.Alllabs8 as a left join  Hypwork.TRIGLpost3 as b on a.SWC_PAT_ID=b.SWC_PAT_ID; quit; 
proc sql; create table Hypwork.Alllabs10 as select a.*, b.PostIDX_NHDL format 6. 
from HypWork.Alllabs9 as a left join  Hypwork.NHDLpost3 as b on a.SWC_PAT_ID=b.SWC_PAT_ID; quit; 
proc sql; create table Hypwork.Alllabs11 as select a.*, b.PostIDX_HDL format 6. 
from HypWork.Alllabs10 as a left join  Hypwork.HDLpost3 as b on a.SWC_PAT_ID=b.SWC_PAT_ID; quit; 
proc sql; create table Hypwork.Alllabs11_2 as select a.*, b.MinLDL4monthGap as PostIDX_LDL4monthGap format 6. 
from HypWork.Alllabs11 as a left join  Hypwork.LDL4monthGap2 as b on a.SWC_PAT_ID=b.SWC_PAT_ID; quit; 
proc means data=hypwork.alllabs11_2 n nmiss mean min max; var PostIDX_LDL4monthGap POSTIDX_LDLmin;run;

* We need to add age for ACC/AHA target;
proc sql; create table Hypwork.Alllabs12 as select a.*, b.Age from  Hypwork.Alllabs11_2 as a left join HypWork.Zzzdemoghyp as b on a.SWC_PAT_ID=b.SWC_PAT_ID
;quit;

* NLA Target and ACC/AHA Target;
Data Hypwork.Alllabs13; set Hypwork.Alllabs12; 
if POSTIDX_LDLmin lt 70 or (0 lt POSTIDX_NHDL lt 100) then NLATarget70=1; else NLATarget70=0;
if Age ge 21 and (POSTIDX_LDLmin lt 70 or (0 lt POSTIDX_NHDL lt 100)) then ACCAHATarget70=1; else ACCAHATarget70=0;
if POSTIDX_LDLmin lt 100 or (0 lt POSTIDX_NHDL lt 100) then NLATarget100=1; else NLATarget100=0;
if Age ge 21 and (POSTIDX_LDLmin lt 100 or (0 lt POSTIDX_NHDL lt 100)) then ACCAHATarget100=1; else ACCAHATarget100=0;
run; 

* Lets add everything together sofar;
* we have zzzPOSTINDEX data, we have LDLlag_count2 data that has the finalized SWC_PAT_IDs list;
* We also have the Alllabs12 data which has the NLA and ACCAHA Target;
* Cohort size drops from 11370 to 5529;
proc sql; create table HypWork.ZZZHYPPOSTINDEX as select distinct d.*, c.LDLcount, c.LDLlag from ( select a.*, b.POSTIDX_LDLmin,
b.POSTIDX_NHDL, b.PostIDX_TRIGL, b.POSTIDX_HDL, b.PostIDX_LDL4monthGap,
b.NLATarget70, b.ACCAHATarget70, b.NLATarget100, b.ACCAHATarget100 from HypWork.zzzPOSTINDEX as a inner join HypWork.Alllabs13 as b on a.SWC_PAT_ID=b.SWC_PAT_ID)
as d inner join HypWork.LDLlag_count2 as c on c.SWC_PAT_ID=d.SWC_PAT_ID;quit; * 5870;

				proc means data=HypWork.ZZZHYPPOSTINDEX n nmiss mean std; var POSTIDX_LDLmin PostIDX_LDL4monthGap;run;
				proc means data=HypWork.ZZZHYPPOSTINDEX n nmiss mean std; var POSTIDX_LDLmin PostIDX_LDL4monthGap; where LDLlag ge 100;run;
*
proc datasets library=HYPWORK nolist;
delete
Labs2LDL Labs2ldl2016 LDL0 LDL
Labs2Tri Labs2Tri2016 TRI0 TRI
Labs2NHDL Labs2NHDL2016 NHDL0 NHDL 
LDLwithindex LDLwithindex2 LDLlag_count LDLlag_count2
TRIGLpost TRIGLpost2 TRIGLpost3 
NHDLpost NHDLpost2 NHDLpost3
Alllabs:
;run;

******************************;
* COMORBIDITY;
******************************;
proc sql; create table hypwork.HYPdx as select b.SWC_PAT_ID, b.index_date, a.*  from &_vdw_dx (where=(year(adate) in (2011, 2012,2013,2014,2015,2016,2017))) as a
right join hypwork.zzzHypMRNindex as b on a.SWC_PAT_ID=b.SWC_PAT_ID
and index_date-365 le adate lt index_date+365;quit; * 1275166 ;

* lets consider excluison criteria of kidney/hepatic disease;
data hypwork.HypRenalExcludedx; set hypwork.HYPdx;
array diag dx origdx;
	do over diag;
if COMPRESS(diag,".") in: ('40301','40311','40391',' 40402','40403','40412','40413','40492','40493','5855','5856','v451','v4511','v4512')or 
	COMPRESS(diag,".") in: ('I120','I120','I1311','I132','N185','N186','Z992','Z9115') then renalESRD=1; else renalESRD=0;
if COMPRESS(diag,".") in:('570','K7200','K762') then LiverDisease=1; else liverDisease=0;
if COMPRESS(diag,".") in:('T466X5A','E9422') then StatinIntol=1;
END;
IF renalESRD or LiverDisease or STATINintol;
run; 
******************************;
* I tried the ICD9/10 code that Stephanie provided but couldn't find anyone with those PXs, with the CPT, 5 patients are found;
proc sql; create table hypwork.HYPpx as select b.SWC_PAT_ID,  b.index_date, a.*  from &_vdw_px (where=(year(adate) in (2011,2012,2013,2014,2015,2016,2017))) as a
right join hypwork.zzzHypMRNindex as b on a.SWC_PAT_ID=b.SWC_PAT_ID
and index_date-365 le procdate lt index_date+365;quit; *1092660 ;

data hypwork.HypRenalExcludepx; set hypwork.HYPpx;
array proc px origpx;
	do over proc;
if COMPRESS(proc,".") in: ('36147','36148','36800',' 36810','36815','36831','36832','36833','36838','90935','90937','90940','90945','90947')or 
	COMPRESS(proc,".") in: ('90965','90966','90969','90970','90989','90993','90999','90997','99512') then renalCPT=1; else renalCPT=0;
END;
IF renalCPT;
run; * 3221;
* add the SWC_PAT_IDs of above cohorts;
proc sql; create table hypwork.HypRenalExcludeTotal as select distinct SWC_PAT_ID from 
(select SWC_PAT_ID from hypwork.HypRenalExcludedx union select SWC_PAT_ID from hypwork.HypRenalExcludepx); quit; * 156;
* 126 patients will be excluded;

* Remove the last cohort from the Hypdx file;
proc sql; create table hypwork.Hypdx2 as select * from hypwork.Hypdx where SWC_PAT_ID not in (select SWC_PAT_ID from hypwork.HypRenalExcludeTotal);quit; 
* Also update the zzzHypMRNindex file;
proc sql; create table hypwork.zzzHypMRNindex2 as select * from hypwork.zzzHypMRNindex where SWC_PAT_ID not in (select SWC_PAT_ID from hypwork.HypRenalExcludeTotal);quit; * 5731;
************************************************;
* So far 
* zzzHypMRNindex has all patients after inclusion criteria;
* zzzHypMRNindex2 has all patients after inclusion and exclusion criteria;

data hypwork.HYPdx3 (compress=yes ); set hypwork.HYPdx2;
	array adx dx origdx;
	do over adx;
	*flag DM;
	if COMPRESS(adx,".")  in:("250") then DM=1; else DM=0;

***DCSI, see protocol for details;
	*code the weights;
	*if adx IN:("2505","36201","3621","36283","36253","36281","36282","2504","580","581","582","583","3569","2506","3581",
			   "9510","9511","9513","354","355","7135","3572","59654","3370","3371","5645","5363","458","435","440","411",
			   "413","414","4292","2507","4423","44381","4439","8921","4439") then DCSI_WT = 1;
	*if adx in:("36202","361","369","37923","585","586","5939","431","433","434","436","410","4271","4273","4274","4275",
			   "412","428","44023","44024","441","44422","7854","0400","7071","2501","2502","2503") then DCSI_WT = 2;

	*code the categories;
	*if adx in:("2505","36201","3621","36283","36253","36281","36282","36202","361","369","37923") then DCSI_RETINO = 1;
	if COMPRESS(adx,".")  in:("2505","36201","3621","36283","36253","36281","36282") then DCSI_RETINO = 1;
	if COMPRESS(adx,".")  in:("36202","361","369","37923") then DCSI_RETINO = 2;
 
	*if adx in:("2504","580","581","582","583","585","586","5939")then DCSI_NEPHRO = 1;
	if COMPRESS(adx,".")  in:("2504","580","581","582","583") then DCSI_NEPHRO = 1;
	if COMPRESS(adx,".")  in:("585","586","5939") then DCSI_NEPHRO = 2;
	/*got the lab data, but Stephanie is looking to see if we should include them since there are so few values;
	if urine_creatinine >= "30 mg/g" or dipstick_pr = "+" or serum_creatinine >= "1.5 mg/dL" then do; DCSI_WT =1; DCSI_NEPHRO = 1; end;
	if serum_creatinine > "2.0 mg/dL" then do; DCSI_WT = 2;DCSI_NEPHRO=1; end; */

	if COMPRESS(adx,".")  in:("3569","2506","3581","9510","9511","9513","354","355","7135","3572","59654","3370","3371","5645","5363","458")then DCSI_NEURO = 1;*only has one weight;

	*if adx in:("435","431","433","434","436") then DCSI_CEREBRO = 1;
	if COMPRESS(adx,".")  in:("435") then DCSI_CEREBRO = 1;
	if COMPRESS(adx,".")  in:("431","433","434","436") then DCSI_CEREBRO = 2;

	*if adx in:("440","411","413","414","4292","410","4271","4273","4274","4275","412","428","44023","44024","441") then DCSI_CARDIO = 1;
	if COMPRESS(adx,".")  in:("440","411","413","414","4292") then DCSI_CARDIO = 1;
	if COMPRESS(adx,".")  in:("410","4271","4273","4274","4275","412","428","44023","44024","441") then DCSI_CARDIO = 2;

	*if adx in:("2507","4423","44381","4439","8921","4439","44422","7854","0400","7071") then DCSI_PVD = 1;
	if COMPRESS(adx,".")  in:("2507","4423","44381","4439","8921","4439") then DCSI_PVD = 1;
	if COMPRESS(adx,".")  in:("44422","7854","0400","7071") then DCSI_PVD = 2;

	if COMPRESS(adx,".")  in:("2501","2502","2503") then DCSI_METABO = 2;*only has one weight;


	***ICD-9 microvescular complications:;
	*Chronic kidney disease (excluding ESRD);
	if COMPRESS(adx,".")  in:("5851","5852","5853","5854") then do;MICRO = 1; COMORB_DTL="Chronic kidney disease (no ESRD)";end;
	*End-stage renal disease (ESRD);
	if COMPRESS(adx,".")  in:("28521","40301","40311","40391","40402","40403","40412","40413","40492","40493","45821",
			   "5845","5846","5847","5848","5849","5855","5856","586","7925","99656","99668","99673","99681",
			   "V420","V4511","V4512","V56","E8791","3895","3927","3995","5498","5552","5553","5554","5569")
			   then do;MICRO = 1; COMORB_DTL="End-stage renal disease";end;
	*Nephropathy;
	if COMPRESS(adx,".")  in:("2504") then do;MICRO = 1; COMORB_DTL="Nephropathy";end;
	*Peripheral neuropathy;
	if COMPRESS(adx,".")  in:("2506","3371","354","355","3572")then do;MICRO = 1; COMORB_DTL="Peripheral neuropathy";end;
	*Retinopathy;
	if COMPRESS(adx,".")  in:("2505","3620")then do;MICRO = 1; COMORB_DTL="Retinopathy";end;

***ICD-10 microvascular complications:;
	*Chronic kidney disease (excluding ESRD);
	if COMPRESS(adx,".")  in:("N181","N182","N183","N184")then do;MICRO = 1; COMORB_DTL="Chronic kidney disease (no ESRD)";end;
	*End-stage renal disease (ESRD);
	if COMPRESS(adx,".")  in:("D631","I120","I1311","I132","I953","N170","N171","N172",
			   "N178","N179","N185","N186","N19","R880","T85691A","T8571XA","T82818A","T82828A","T82838A","T82848A","T82858A",
			   "T82868A","T82898A","T8610","T8611","T8612","Z940","Z992","Z9115","Z49","Y841","05HY33Z","03130ZD",
			   "03140ZD","03150ZD","03160ZD","03170ZD","03180ZD","03190ZF","031A0ZF","031B0ZF","031C0ZF","5A1D00Z",
			   "5A1D60Z","3E1M39Z","0TT00ZZ","0TT04ZZ","0TT10ZZ","0TT14ZZ","0TT00ZZ","0TT04ZZ","0TT10ZZ","0TT14ZZ",
			   "0TT20ZZ","0TT24ZZ","0TY00Z0","0TY00Z1","0TY00Z2","0TY10Z0","0TY10Z1","0TY10Z2")
			   then do;MICRO = 1; COMORB_DTL="End-stage renal disease";end;
	*Nephropathy;
	if COMPRESS(adx,".")  in:("E1129","E1029","E1121","E1165","E1021","E1065")then do;MICRO = 1; COMORB_DTL="Nephropathy";end;
	*Peripheral neuropathy;
	if COMPRESS(adx,".")  in:("E1140","E1040","E1165","E1065","G990","G56","G57","E0842","E0942","E1042","E1142"
			   "E1342")then do;MICRO = 1; COMORB_DTL="Peripheral neuropathy";end;
	*Retinopathy;
	if COMPRESS(adx,".")  in:("E133","E093","E103","E113","E083","H350")then do;MICRO = 1; COMORB_DTL="Retinopathy";end;

***ICD-9 macrovascular complications:;
	*Heart Failure;
	if COMPRESS(adx,".")  in:("428") then do;MACRO = 1; COMORB_DTL="Heart Failure";end;
	*Unstable angina;
	if COMPRESS(adx,".")  in:("4111") then do;MACRO = 1; COMORB_DTL="Unstable angina";end;
	*Transient ischemic attack (TIA);
	if COMPRESS(adx,".")  in:("4359")then do;MACRO = 1; COMORB_DTL="Transient ischemic attack";end;
	*Atrial fibrillation (AFib);
	if COMPRESS(adx,".")  in:("42731")then do;MACRO = 1; COMORB_DTL="Atrial fibrillation";end;
	*Angina pectoris;
	if COMPRESS(adx,".")  in:("413")then do;MACRO = 1; COMORB_DTL="Angina pectoris";end;
	*Acute myocardial infarction;
	if COMPRESS(adx,".")  in:("410") then do;MACRO = 1; COMORB_DTL="Acute myocardial infarction";end;
	*Other ischemic heart disease;
	if COMPRESS(adx,".")  in:("414")then do;MACRO = 1; COMORB_DTL="Other ischemic heart disease";end;
	*Other heart disease;
	if COMPRESS(adx,".")  in:("40201","40211","40291","420","421","422","423","424","425","426")
			   then do;MACRO = 1; COMORB_DTL="Other heart disease";end;
	*Stroke;
	if COMPRESS(adx,".")  in:("430","431","432","433","434","436")then do;MACRO = 1; COMORB_DTL="Stroke";end;
	*Peripheral arterial disease (PAD);
	if COMPRESS(adx,".")  in:("4439")then do;MACRO = 1; COMORB_DTL="Peripheral arterial disease";end;

***ICD-10 macrovescular complications;
	*Heart Failure;
	if COMPRESS(adx,".")  in:("I50")then do;MACRO = 1; COMORB_DTL="Heart Failure";end;
	**Unstable angina;
	if COMPRESS(adx,".")  in:("I200")then do;MACRO = 1; COMORB_DTL="Unstable angina";end;
	*Transient ischemic attack (TIA);
	if COMPRESS(adx,".")  in:("G459","I67848")then do;MACRO = 1; COMORB_DTL="Transient ischemic attack";end;
	*Atrial fibrillation (AFib);
	if COMPRESS(adx,".")  in:("I4891")then do;MACRO = 1; COMORB_DTL="Atrial fibrillation";end;
	*Angina pectoris;
	if COMPRESS(adx,".")  in:("I20")then do;MACRO = 1; COMORB_DTL="Angina pectoris";end;
	*Acute myocardial infarction;
	if COMPRESS(adx,".")  in:("I21")then do;MACRO = 1; COMORB_DTL="Acute myocardial infarction";end;
	*Other ischemic heart disease;
	if COMPRESS(adx,".")  in:("I25")then do;MACRO = 1; COMORB_DTL="Other ischemic heart disease";end;
	*Other heart disease;
	if COMPRESS(adx,".")  in:("I110","I30","I33","I41","I40","I31","I34","I35","I36","I37","I38","I39","I42","I43",
			   "I44","I45")then do;MACRO = 1; COMORB_DTL="Other heart disease";end;
	*Stroke;
	if COMPRESS(adx,".")  in:("I609","I619","I62","I65","I66","I6789")then do;MACRO = 1; COMORB_DTL="Stroke";end;
	*Peripheral arterial disease (PAD);
	if COMPRESS(adx,".")  in:("I739")then do;MACRO = 1; COMORB_DTL="Peripheral arterial disease";end;

***ICD-9 other complications;
	*Cancer (excluding non-melanoma skin cancer);
	if COMPRESS(adx,".")  in:("140","141","142","143","144","145","146","147","148","149","150","151","152","153","154","155","156",
			   "157","158","159","160","161","162","163","164","165","166","167","168","169","170","171","172","174",
			   "175","176","177","178","179","180","181","182","183","184","185","186","187","188","189","190","191",
			   "192","193","194","195","196","197","198","199","200","201","202","203","204","205","206","207","208",
			   "2090","2091","2092","2093","2097")then do;OTHER = 1; COMORB_DTL="Cancer";end;
	*Chronic obstructive pulmonary disease (COPD);
	if COMPRESS(adx,".")  in:("491","492","496")then do;OTHER = 1; COMORB_DTL="Chronic obstructive pulmonary disease";end;
	*Hyperlipidemia or lipid disorder;
	if COMPRESS(adx,".")  in:("2720","2721","2722","2724")then do;OTHER = 1; COMORB_DTL="Hyperlipidemia or lipid disorder";end;
	*Hypertension;
	if COMPRESS(adx,".")  in:("401","40200","40210","40290","403","404","405")then do;OTHER = 1; COMORB_DTL="Hypertension";end;
	*Obesity or weight gain;
	if COMPRESS(adx,".")  in:("2780","7831","79391","V853","V854")then do;OTHER = 1; COMORB_DTL="Obesity";end;
	*Osteoporosis;
	if COMPRESS(adx,".")  in:("7330")then do;OTHER = 1; COMORB_DTL="Osteoporosis";end;

***ICD-10 other complications;
	*Cancer (excluding non-melanoma skin cancer);
	if COMPRESS(adx,".")  in:("C","D0","D1","D2","D3","D4") and COMPRESS(COMPRESS(adx,".") ,".") not in:("CANCER") then do;OTHER = 1; COMORB_DTL="Cancer";end;
	*Chronic obstructive pulmonary disease (COPD);
	if COMPRESS(adx,".")  in:("J41","J43","J44")then do;OTHER = 1; COMORB_DTL="Chronic obstructive pulmonary disease";end;
	*Hyperlipidemia or lipid disorder;
	if COMPRESS(adx,".")  in:("E780","E781","E782","E784","E785")then do;OTHER = 1; COMORB_DTL="Hyperlipidemia or lipid disorder";end;
	*Hypertension;
	if COMPRESS(adx,".")  in:("I10","I169","I119","I119","I119","I12","I13","I15")then do;OTHER = 1; COMORB_DTL="Hypertension";end;
	*Obesity or weight gain;
	if COMPRESS(adx,".")  in:("E66","R635","R939","Z683","Z684")then do;OTHER = 1; COMORB_DTL="Obesity";end;
	*Osteoporosis;
	if COMPRESS(adx,".")  in:("M81") then do;OTHER = 1; COMORB_DTL="Osteoporosis";end;



***Charlson;
	  	/* Myocardial Infarction */
          if  COMPRESS(adx,".") IN: ('410','412') or 
			COMPRESS(adx,".")  IN: ('I21', 'I22','I252') then CC1MI = 1;

         /* Congestive Heart Failure */
          if  COMPRESS(adx,".") IN: ('39891','40201','40211','40291','40401','40403','40411','40413','40491','40493',
                         '4254','4255','4257','4258','4259','428')  or 
			COMPRESS(adx,".")  IN: ('I43','I50','I099','I110','I130','I132','I255','I420','I425','I426',
                         'I427','I428','I429','P290') then CC2CHF= 1;
         /* Periphral Vascular Disease */
          if  COMPRESS(adx,".") IN: ('0930','4373','440','441','4431','4432','4438','4439','4471','5571','5579','V434')  or 
			COMPRESS(adx,".")  IN:  ('I70','I71','I731','I738','I739','I771','I790','I792','K551','K558',
                         'K559','Z958','Z959') then CC3VASC = 1;
         /* Cerebrovascular Disease */
          if COMPRESS(adx,".") IN: ('36234','430','431','432','433','434','435','436','437','438')  or 
			COMPRESS(adx,".")  IN: ('G45','G46','I60','I61','I62','I63','I64','I65','I66','I67','I68',
                         'I69','H340') then CC4STROKE = 1;
         /* Dementia */
          if  COMPRESS(adx,".") IN: ('290','2941','3312')  or 
			COMPRESS(adx,".")  IN: ('F00','F01','F02','F03','G30','F051','G311') then CC5DEM = 1;
         /* Chronic Pulmonary Disease */
          if  COMPRESS(adx,".") IN: ('4168','4169','490','491','492','493','494','495','496','500','501','502','503',
                          '504','505','5064','5081','5088')  or 
			COMPRESS(adx,".")  IN: ('J40','J41','J42','J43','J44','J45','J46','J47','J60','J61','J62','J63',
                         'J64','J65','J66','J67''I278','I279','J684','J701','J703') then CC6COPD= 1;
         /* Connective Tissue Disease-Rheumatic Disease */
          if  COMPRESS(adx,".") IN: ('4465','7100','7101','7102','7103','7104','7140','7141','7142','7148','725') or 
			COMPRESS(adx,".")  IN: ('M05','M32','M33','M34','M06','M315','M351','M353','M360') then CC7RHEUM = 1;
         /* Peptic Ulcer Disease */
          if   COMPRESS(adx,".") IN: ('531','532','533','534') or 
			COMPRESS(adx,".")  IN: ('K25','K26','K27','K28') then CC8PUD = 1;
         /* Mild Liver Disease */
          if  COMPRESS(adx,".") IN: ('07022','07023','07032','07033','07044','07054','0706','0709','570','571','5733',
                        '5734','5738','5739','V427') or 
			COMPRESS(adx,".")  IN: ('B18','K73','K74','K700','K701','K702','K703','K709','K717','K713',
                         'K714','K715','K760','K762','K763','K764','K768','K769','Z944') then CC9CIRRH = 1;
         /* Diabetes without complications */
          if  COMPRESS(adx,".") IN: ('2500','2501','2502','2503','2508','2509') or 
			COMPRESS(adx,".")  IN: ('E100','E101','E106','E108','E109','E110','E111','E116','E118','E119',
                         'E120','E121','E126','E128','E129','E130','E131','E136','E138','E139',
                         'E140','E141','E146','E148','E149')  then CC10DIAB = 1;
         /* Diabetes with complications */
          if   COMPRESS(adx,".") IN: ('2504','2505','2506','2507') or 
			COMPRESS(adx,".")  IN: ('E102','E103','E104','E105','E107','E112','E113','E114','E115','E117',
                         'E122','E123','E124','E125','E127','E132','E133','E134','E135','E137',
                         'E142','E143','E144','E145','E147') then CC11DIABCOMPL = 1;
         /* Paraplegia and Hemiplegia */
          if  COMPRESS(adx,".") IN: ('3341','342','343','3440','3441','3442','3443','3444','3445','3446','3449') or 
			COMPRESS(adx,".")  IN: ('G81','G82','G041','G114','G801','G802','G830','G831','G832','G833',
                         'G834','G839') then CC12PLEGIA = 1;
         /* Renal Disease */
          if  COMPRESS(adx,".") IN: ('40301','40311','40391','40402','40403','40412','40413','40492','40493','582',
                         '5830','5831','5832','5834','5836','5837','585','586','5880','V420','V451','V56') or 
			COMPRESS(adx,".")  IN: ('N18','N19','N052','N053','N054','N055','N056','N057','N250','I120',
                         'I131','N032','N033','N034','N035','N036','N037','Z490','Z491','Z492',
                         'Z940','Z992') then CC13RENAL = 1;
         /* Cancer */
          if  COMPRESS(adx,".") IN: ('140','141','142','143','144','145','146','147','148','149','150','151','152','153',
                         '154','155','156','157','158','159','160','161','162','163','164','165','170','171',
                         '172','174','175','176','179','180','181','182','183','184','185','186','187','188',
                         '189','190','191','192','193','194','195','200','201','202','203','204','205','206',
                         '207','208','2386') or 
			COMPRESS(adx,".")  IN: ('C00','C01','C02','C03','C04','C05','C06','C07','C08','C09','C10','C11',
                         'C12','C13','C14','C15','C16','C17','C18','C19','C20','C21','C22','C23',
                         'C24','C25','C26','C30','C31','C32','C33','C34','C37','C38','C39','C40',
                         'C41','C43','C45','C46','C47','C48','C49','C50','C51','C52','C53','C54',
                         'C55','C56','C57','C58','C60','C61','C62','C63','C64','C65','C66','C67',
                         'C68','C69','C70','C71','C72','C73','C74','C75','C76','C81','C82','C83',
                         'C84','C85','C88','C90','C91','C92','C93','C94','C95','C96','C97') then CC14CANC = 1;
         /* Moderate or Severe Liver Disease */
          if  COMPRESS(adx,".") IN: ('4560','4561','4562','5722','5723','5724','5728') or 
			COMPRESS(adx,".")  IN: ('K704','K711','K721','K729','K765','K766','K767','I850','I859','I864','I982') then CC15HEPFAIL = 1;
         /* Metastatic Carcinoma */
          if  COMPRESS(adx,".") IN: ('196','197','198','199') or 
			COMPRESS(adx,".")  IN: ('C77','C78','C79','C80')  then CC16CAMETAS = 1;
         /* AIDS/HIV */
          if  COMPRESS(adx,".") IN: ('042','043','044') or 
			COMPRESS(adx,".")  IN: ('B20','B21','B22','B24') then CC17HIVAIDS = 1;
		***** end of charlson;
	END;




/****flag utilization;
	*hospitalization (inpatient);
	if place_of_service_medstat in:("Inpatient") then UTL_INP = 1;
	*ER visit;
	if place_of_service_medstat in:("Urgent Care Facility", "Emergency Room") then UTL_ED = 1;
	*Outpatient;
	if place_of_service_medstat in:("Ambulatory", "Office", "Outpatient", "Rural", "Patient Home") then UTL_OUT = 1;
	*OTHER;
	if place_of_service_medstat in:("Ambulance", "Pharmacy","Independent Lab") then UTL_OTHER = 1;
	*Residental;
	if place_of_service_medstat in:("Comprehensive Inpt", "Nursing", "Skilled") then UTL_RES = 1;
	*/


	if index_date-365 <= adate < index_date then Preindex=1; 
	if index_date <= adate < index_date+365 then preindex=0; 	

	ARRAY zero DCSI_RETINO -- MICRO ; DO OVER zero; if zero='.' then zero=0;end;
	ARRAY zero2 MACRO -- CC17HIVAIDS ; DO OVER zero2; if zero2='.' then zero2=0;end;


run; 

proc sql;
	create table hypwork.hypComorbPreIndex as select distinct SWC_PAT_ID, index_date
		,max(DCSI_RETINO) as DCSI_PRE_RETINO
		,max(DCSI_NEPHRO ) as DCSI_PRE_NEPHRO
		,max(DCSI_NEURO ) as DCSI_PRE_NEURO
		,max(DCSI_CEREBRO) as DCSI_PRE_CEREBRO
		,max(DCSI_CARDIO ) as DCSI_PRE_CARDIO
		,max(DCSI_PVD ) as DCSI_PRE_PVD
		,max(DCSI_METABO) as DCSI_PRE_METABO

		,max(MICRO > 0 ) as COMORB_PRE_MICRO
		,max(MACRO > 0 ) as COMORB_PRE_MACRO
		,max(OTHER > 0) as COMORB_PRE_OTHER

		, MAX(CC1MI >0) as CC1MI 
   		, MAX(CC2CHF >0) as CC2CHF 
  	    , MAX(CC3VASC >0) as CC3VASC 
  		, MAX(CC4STROKE >0) as CC4STROKE 
  		, MAX(CC5DEM >0) as CC5DEM 
 		, MAX(CC6COPD >0) as CC6COPD 
 		, MAX(CC7RHEUM >0) as CC7RHEUM 
 		, MAX(CC8PUD >0) as CC8PUD 
 		, MAX(CC9CIRRH >0) as CC9CIRRH 
 		, MAX(CC10DIAB >0) as CC10DIAB 
 		, MAX(CC11DIABCOMPL >0) as CC11DIABCOMPL 
 		, MAX(CC12PLEGIA >0) as CC12PLEGIA 
 		, MAX(CC13RENAL >0) as CC13RENAL 
 		, MAX(CC14CANC >0) as CC14CANC 
 		, MAX(CC15HEPFAIL >0) as CC15HEPFAIL 
 		, MAX(CC16CAMETAS >0) as CC16CAMETAS 
 		, MAX(CC17HIVAIDS >0) as CC17HIVAIDS

	from hypwork.hypDx3 
	group by SWC_PAT_ID having Preindex=1;
quit; * 5647 have preindex information ;
data hypwork.hypComorbPreIndex2; set hypwork.hypComorbPreIndex;
	DCSI = sum(of DCSI_PRE:);
	CHARLSON_PRE = (CC1MI + CC2CHF + CC3VASC + CC4STROKE + CC5DEM + CC6COPD + CC7RHEUM + CC8PUD + CC9CIRRH + CC10DIAB 
				+ 2*CC11DIABCOMPL + 2*CC12PLEGIA + 2*CC13RENAL + 2*CC14CANC 
				+ 3*CC15HEPFAIL 
				+ 6*CC16CAMETAS + 6*CC17HIVAIDS);
run; * 5647;

* Adding patients with no preindex records;
Proc sql; create table hypwork.hypComorbPreIndex3 as select a.SWC_PAT_ID, a.index_date, b.* from hypwork.zzzHypMRNindex2 as a left join hypwork.hypComorbPreIndex2 as b 
on a.SWC_PAT_ID=b.SWC_PAT_ID;quit; * 5731;

DATA hypwork.zzzhypComorbPreIndex;
SET hypwork.hypComorbPreIndex3;
ARRAY zero DCSI_PRE_RETINO -- CHARLSON_PRE ; DO OVER zero; if zero='.' then zero=0;end;
RUN; 
*
proc datasets library=HYPWORK nolist;
   delete 
HYPdx HypRenalExcludedx HYPpx HypRenalExcludepx HypRenalExcludeTotal
HYPdx2 HYPdx3 hypComorbPreIndex hypComorbPreIndex2 hypComorbPreIndex3
;run;

************************************************************************;
*Cholesterol drugs;
************************************************************************;
Data HypWork.HypNDCCHOL; set &_vdw_EverNDC;

Fibrates=(prxmatch("/\b(ANTARA|CLOFIBRATE|FENOFIBRATE|FENOFIBRIC ACID|FENOGLIDE|LIPOFEN|LOFIBRA|TRICOR|TRIGLIDE|TRILIPIX|
FENOFIBRATE)\b/io", Brand))
		or(prxmatch("/\b(ANTARA|CLOFIBRATE|FENOFIBRATE|FENOFIBRIC ACID|FENOGLIDE|LIPOFEN|LOFIBRA|TRICOR|TRIGLIDE|TRILIPIX|
FENOFIBRATE)\b/io", Generic));

Niacin=(prxmatch("/\b(ADVICOR|B3-50|B3-500-GR|ENDUR-ACIN|HM NIACIN|NIACIN|NIACOR|NIACOR-B3|NIADELAY|NIASPAN|NICO|NICOTINEX|NICOTINIC|
NO FLUSH NIACIN|PLAIN NIACIN|SIMCOR|SLO)\b/io", Generic))
	or (prxmatch("/\b(ADVICOR|B3-50|B3-500-GR|ENDUR-ACIN|HM NIACIN|NIACIN|NIACOR|NIACOR-B3|NIADELAY|NIASPAN|NICO|NICOTINEX|NICOTINIC|
NO FLUSH NIACIN|PLAIN NIACIN|SIMCOR|SLO)\b/io", BRAND));

			NoNiacin=INDEX(UPCASE(generic), 'NIACINAMIDE') or INDEX(UPCASE(generic), 'NIACINATE') ;

Bile_Acid=(prxmatch("/\b(CHOLESTYRAMINE|CHOLESTYRAMINE|LOCHOLEST|PREVALITE|QUESTRAN|COLESTID
|COLESTIPOL|WELCHOL|COLESEVELAM)\b/io", Generic)) or (prxmatch("/\b(CHOLESTYRAMINE|LOCHOLEST|
PREVALITE|QUESTRAN|COLESTID|COLESTIPOL|WELCHOL|COLESEVELAM)\b/io", BRAND));

PCSK9 =(prxmatch("/\b(REPATHA|EVOLOCUMAB|PRALUENT|ALIROCUMAB)\b/io", Generic))
or (prxmatch("/\b(REPATHA|EVOLOCUMAB|PRALUENT|ALIROCUMAB)\b/io", BRAND ));

Inhib =(prxmatch("/\b(EZETIMIBE|ZETIA|LIPTRUZET|VYTORIN)\b/io", Generic))
or (prxmatch("/\b(EZETIMIBE|ZETIA|LIPTRUZET|VYTORIN)\b/io", BRAND ));

if  (Fibrates or NIACIN or Bile_Acid or PCSK9 or Inhib) and ^NoNiacin ;

run; *261 unique ndc;
					/* I sent the list of drug names to Stephanie to check for unwanted drugs that might be in the list-17OCT17; 
					proc sql; create table Hypwork.cholestrol as select distinct Generic, Brand, Fibrates, NIACIN, Bile_Acid, PCSK9, inhib from  HypWork.HypNDCCHOL;quit; * 46;
					proc sort data=Hypwork.cholestrol; by inhib PCSK9 Bile_Acid NIACIN Fibrates   ;run;
					proc export 
					  data=Hypwork.cholestrol
					  dbms=xlsx 
					  outfile="K:\SWHP DMARDS FILE\DG Stephanie\ACCAHA2013\DATA\Cholestrol.xlsx" 
					  replace;
					run;*/
					* Nothing need to change;

* Filter &_vdw_RX by SWC_PAT_ID and one year PRE index date;

proc sql; create table HypWork.HYPRX2_2 as select distinct a.* from &_vdw_RX (where=( year(rxdate) in (2011, 2012, 2013, 2014, 2015, 2016, 2017))) as a
inner join HypWork.zzzHypMRNindex2 as b on a.SWC_PAT_ID=b.SWC_PAT_ID where index_date-365 le rxdate lt index_date; quit; *211755;
proc sql; create table HypWork.HYPRX2_3 as select distinct a.*, Generic, Brand, Fibrates, Niacin, Bile_Acid, PCSK9, inhib  from HypWork.HYPRX2_2 as a
inner join HypWork.HypNDCCHOL as b on a.ndc=b.ndc;quit; *3046;
proc sql; create table HypWork.HYPRX2_4 as select distinct SWC_PAT_ID, max(Fibrates) as Fibrates, max(Niacin) as Niacin, max(Bile_Acid) as Bile_Acid, max(PCSK9) as PCSK9
, max(inhib) as inhib, sum(Fibrates,Niacin,Bile_Acid,PCSK9,inhib) as PREIDX_SUMAgent from HypWork.HYPRX2_3 group by SWC_PAT_ID;quit; *611;

******************************************************************************************;
******************************************************************************************;
* lets put everything together;
proc sql; create table HypWork.HYPPREINDEX00 as select distinct a.*, b.*  from HypWork.zzzhypComorbPreIndex as a
left join HypWork.HYPRX2_4 as b on a.SWC_PAT_ID=b.SWC_PAT_ID;quit; *5731;
proc sql; create table HypWork.HYPPREINDEX0 as select distinct a.*, b.preIdx_statin, sum(PREIDX_SUMAgent,preIdx_statin) as  PREIDX_SUMAgent_withStatin
from HypWork.HYPPREINDEX00 as a
left join HypWork.Zzzhyppostindex as b on a.SWC_PAT_ID=b.SWC_PAT_ID;quit;

Data HypWork.zzzHYPPREINDEX; set HypWork.HYPPREINDEX0;
Array nomiss Fibrates--PREIDX_SUMAgent_withStatin;
do over nomiss;
if nomiss=. then nomiss=0;
End; run;

proc sql; create table hypwork.HYPER00 as select distinct a.*, b.*
from  hypwork.zzzHYPPREINDEX as a left join  hypwork.Zzzhyppostindex as b on a.SWC_PAT_ID=b.SWC_PAT_ID; quit;
proc sql; create table hypwork.HYPER0 as select distinct a.*, b.female, b.age
from  hypwork.HYPER00 as a left join  hypwork.Zzzdemoghyp as b on a.SWC_PAT_ID=b.SWC_PAT_ID; quit;  * 5731;

Data hypwork.ZZZHYPER; set hypwork.HYPER0 ;
if '01Nov2011'd le index_date le '31Oct2012'd then do; Groupyear=2012; Group2012=1; end;
if '01Nov2012'd le index_date le '31Oct2013'd then do; Groupyear=2013; Group2013=1; end;
if '01Nov2013'd le index_date le '31Oct2014'd then do; Groupyear=2014; Group2014=1;  end;
if '01Nov2014'd le index_date le '31Oct2015'd then do; Groupyear=2015; Group2015=1;  end;
if '01Nov2015'd le index_date le '31Oct2016'd then do; Groupyear=2016; Group2016=1;  end;
Array nomiss Group2012--Group2016;
do over nomiss;
if nomiss=. then nomiss=0;
If Groupyear in (2013, 2014, 2015, 2016);
End;
run; *3570(???) was 3904;

proc sql; select count (distinct SWC_PAT_ID) from hypwork.ZZZHYPER; quit;

* Data hypwork.dataF2018_mar; set KZHYPEXP.dataF2018_mar; where For14 or For15 or For16;run; * 2599;


* NEW May 2018, Adding Provider Specialty;
Proc sql; create table HypWork.Provider as select distinct a.SWC_PAT_ID, a.index_date, b.Provider from hypwork.dataF2018_mar as a left join HypWork.Hypdate as b on a.SWC_PAT_ID=b.SWC_PAT_ID
and a.index_date=b.adate;
quit; * 4720;
Proc sql; create table HypWork.Provider2 as select distinct a.*, b.SPECIALTY as Spec from HypWork.Provider as a left join &_vdw_provider_specialty as b
on a.Provider=b.Provider;
quit; 
proc freq data=HypWork.Provider2 order=freq ; table Spec;run;

proc transpose data=HypWork.Provider2 out=HypWork.Provider2_wide prefix=spec; by SWC_PAT_ID;  var spec;run; *2560;

Data HypWork.Provider3_wide; set HypWork.Provider2_wide;
Array specialty spec1--spec10;
Pro_spec="OTH";
do over specialty;
if specialty in ('FAM','IMG','OBS','GER') then Pro_spec='PCP';
end;
do over specialty;
if specialty in ('CAR','CAV','END') then Pro_spec='CAR';
end;
* This one doesn't work, because the arrays are evaluated by colums first, so the last nonmissing column override the previous commands; 
/*do over specialty;
if specialty in ('FAM','IMG','OBS') then Pro_spec='PCP';
if specialty in ('CAR','CAV','END') then Pro_spec='CAR';
end;*/
run;

proc sql; Create Table hypwork.zzzHYPER2 as select distinct a.*, b.Pro_spec from hypwork.dataF2018_mar as a left join HypWork.Provider3_wide as b on a.SWC_PAT_ID=b.SWC_PAT_ID;quit; * 2560;
* Considering the new request in Dec 2018;
proc sql; Create Table hypwork.zzzHYPER3 as select distinct a.*, b.MinLDL4monthGap from hypwork.zzzHYPER2 as a inner join hypwork.Ldl4monthgap2 as b on
a.SWC_PAT_ID=b.SWC_PAT_ID;quit; * 1947;
proc means n nmiss mean data=hypwork.zzzHYPER3; var MinLDL4monthGap; run;
proc means n nmiss mean data=hypwork.zzzHYPER2; var MinLDL4monthGap; run;

**********************************************************************
**********************************************************************
 This is the final data for Dec 2018 before Propensity Score Mathcing
* Data KZHYPEXP.dataF2018_Dec; set hypwork.zzzHYPER3;run; * 1947;
**********************************************************************
**********************************************************************

*
proc datasets library=HYPWORK nolist;
   delete 
HypNDCCHOL cholestrol HYPRX2_2 HYPRX2_3 HYPRX2_4
HYPPREINDEX00 HYPPREINDEX0 HYPER0 
;quit;


proc print data=hypwork.propensity01314 (obs=10); run;

************************************************************************;
*Statin break out data;
************************************************************************;
Proc sql; create table hypwork.Statindoseeq2_names as select distinct * from hypwork.Statindoseeq1_names where SWC_PAT_ID in (select SWC_PAT_ID from hypwork.ZZZHYPER);quit;
proc sql; create table hypwork.Statindoseeq3_names as select distinct SWC_PAT_ID, Brand, Strength from hypwork.Statindoseeq2_names; quit; * 7957;
proc freq data=hypwork.Statindoseeq3_names; table BRAND*Strength;run;
************************************************************************;
*PROPENSITY SCORE MATCHING; * 
************************************************************************;
* So lets start trying to do the propensity score matching, for the first time 10/11/2017;
* Lets do the matching by considering age, gender, charlson index, and number of hyperlipidemia medications;
* We need to do the matching three times...oops, this is not possible!;
* make sure to reverse Treated variable later, this is now coded only for testing;
Data hypwork.propensity01314;
set hypwork.ZZZHYPER3;
If Groupyear=2013 then Treated=0; else if Groupyear=2014 then Treated=1;
If treated=. then delete;
KEEP  SWC_PAT_ID age female charlson_pre Treated;
run; * 982 for 2013 and 2014 ;
proc sql; select count (distinct SWC_PAT_ID) from hypwork.propensity01314 ;quit; * 982 ;
proc logistic noprint data= hypwork.propensity01314 descending;
 model Treated = age female charlson_pre   ;
 output out=hypwork.propensity1314 prob = prob;
run;
 
* this macro requires separate files for cases and control;
data hypwork.propensity_Treated14
 hypwork.propensity_UnTreated13v14;
 set hypwork.propensity1314;
 if Treated = 1 then output hypwork.propensity_Treated14;
 else if Treated = 0 then output hypwork.propensity_UnTreated13v14;
 run; * 447 Treated, and 535 UNtreated;

%include  "K:\SWHP DMARDS FILE\...\PropensityScoreMatching.sas";
%psmatch_multi(pat_dsn = hypwork.propensity_Treated14,
 pat_idvar = SWC_PAT_ID,
 pat_psvar = prob,
 cntl_dsn = hypwork.propensity_UNTreated13v14,
 cntl_idvar = SWC_PAT_ID,
 cntl_psvar = prob,
 match_dsn = hypwork.matched_pairs1314,
 match_ratio= 1,
 score_diff = 0.01
 );
Data hypwork.propensity01315;
set hypwork.ZZZHYPER3;
If Groupyear=2013 then Treated=0; else if Groupyear=2015 then Treated=1;
If treated=. then delete;
KEEP  SWC_PAT_ID age female charlson_pre  Treated;
run; * 970;
proc logistic noprint data= hypwork.propensity01315 descending;
 model Treated = age female charlson_pre    ;
 output out=hypwork.propensity1315 prob = prob;
run;
* this macro requires separate files for cases and control;
data hypwork.propensity_Treated15
 hypwork.propensity_UnTreated13v15;
 set hypwork.propensity1315;
 if Treated = 1 then output hypwork.propensity_Treated15;
 else if Treated = 0 then output hypwork.propensity_UnTreated13v15;
 run; * 435 Treated, and 535 UNtreated;

%include  "K:\SWHP DMARDS FILE\...\PropensityScoreMatching.sas";
%psmatch_multi(pat_dsn = hypwork.propensity_Treated15,
 pat_idvar = SWC_PAT_ID,
 pat_psvar = prob,
 cntl_dsn = hypwork.propensity_UNTreated13v15,
 cntl_idvar = SWC_PAT_ID,
 cntl_psvar = prob,
 match_dsn = hypwork.matched_pairs1315,
 match_ratio= 1,
 score_diff = 0.01
 );
Data hypwork.propensity01316;
set hypwork.ZZZHYPER3;
If Groupyear=2013 then Treated=0; else if Groupyear=2016 then Treated=1;
If treated=. then delete;
KEEP  SWC_PAT_ID age female charlson_pre  Treated;
run; * 1065;
proc logistic data= hypwork.propensity01316 descending;
 model Treated = age female charlson_pre    ;
 output out=hypwork.propensity1316 prob = prob;
run;
* this macro requires separate files for cases and control;
data hypwork.propensity_Treated16
 hypwork.propensity_UnTreated13v16;
 set hypwork.propensity1316;
 if Treated = 1 then output hypwork.propensity_Treated16;
 else if Treated = 0 then output hypwork.propensity_UnTreated13v16;
 run; *  530 Treated, and 535 UNtreated;

%include  "K:\SWHP DMARDS FILE\...\PropensityScoreMatching.sas";
%psmatch_multi(pat_dsn = hypwork.propensity_Treated16,
 pat_idvar = SWC_PAT_ID,
 pat_psvar = prob,
 cntl_dsn = hypwork.propensity_UNTreated13v16,
 cntl_idvar = SWC_PAT_ID,
 cntl_psvar = prob,
 match_dsn = hypwork.matched_pairs1316,
 match_ratio= 1,
 score_diff = 0.01
 ); * 530 matched;

proc sql; select count (distinct cntl_idvar) from Hypwork.Matched_pairs1314;quit; * 446 ;
proc sql; select count (distinct cntl_idvar) from Hypwork.Matched_pairs1315;quit; * 435 ;
proc sql; select count (distinct cntl_idvar) from Hypwork.Matched_pairs1316;quit; * 530 ;
*
proc datasets library=HYPWORK nolist;
   delete 
propensity01314 propensity1314 propensity_Treated14 propensity_UnTreated13v14
propensity01315 propensity1315 propensity_Treated15 propensity_UnTreated13v15
propensity01316 propensity1316 propensity_Treated16 propensity_UnTreated13v16 
;quit;

* Now we have control group, 2013, matched with 2014, 2015, and 2016 groups separately;
* Let's put everything in one data set for analysis;
* After all the duplicate SWC_PAT_IDs causes some issues here;
Proc sql; create table hypwork.For2014 as select pat_idvar,cntl_idvar, 1 as for14 from Hypwork.Matched_pairs1314 where cntl_idvar is not missing;quit;
Proc sql; create table hypwork.For2015 as select pat_idvar,cntl_idvar, 1 as for15 from Hypwork.Matched_pairs1315 where cntl_idvar is not missing ;quit;
Proc sql; create table hypwork.For2016 as select pat_idvar,cntl_idvar, 1 as for16 from Hypwork.Matched_pairs1316 where cntl_idvar is not missing;quit;

proc sql; create table hypwork.dat as select a.*, b.for14 from  hypwork.zzzHYPER3 as a left join hypwork.For2014 as b on a.SWC_PAT_ID=b.cntl_idvar;quit; *1947 ;
proc sql; create table hypwork.dat2 as select a.*, b.for14 as self14 from  hypwork.dat as a left join hypwork.For2014 as b on a.SWC_PAT_ID=b.pat_idvar;quit;

proc sql; create table hypwork.dat3 as select a.*, b.for15 from  hypwork.dat2 as a left join hypwork.For2015 as b on a.SWC_PAT_ID=b.cntl_idvar;quit;
proc sql; create table hypwork.dat4 as select a.*, b.for15 as self15 from  hypwork.dat3 as a left join hypwork.For2015 as b on a.SWC_PAT_ID=b.pat_idvar;quit;

proc sql; create table hypwork.dat5 as select a.*, b.for16 from  hypwork.dat4 as a left join hypwork.For2016 as b on a.SWC_PAT_ID=b.cntl_idvar;quit;
proc sql; create table hypwork.dat6 as select a.*, b.for16 as self16 from  hypwork.dat5 as a left join hypwork.For2016 as b on a.SWC_PAT_ID=b.pat_idvar;quit;

Data hypwork.dat7; set hypwork.dat6; 
IF self14 then for14=1;
IF self15 then for15=1;
IF self16 then for16=1;
If group2013 or group2014 or group2015 or group2016;
Label PREIDX_SUMAgent='# Antihyp agents excluding Statin'  PREIDX_SUMAgent_withStatin= '# Antihyp Agents including Statin' PostIDX_PDCStat= 'Post index PDC'
POSTIDX_ATOREQ= 'Post index Statin dose normalized to  Atorvastatin'  POSTIDX_HighStat= 'Post index high intensity Satin' 
POSTIDX_LDLmin= 'post index LDL-c Level' POSTIDX_NHDL= 'post index NHDL Level' POSTIDX_TRIGL= 'post index TRIGL Level' POSTIDX_HDL= 'post index HDL Level'
LDLCount= 'Post index Frequency of Lipid testing' LDLlag= 'lag from index to first LDL measure (days)' MinLDL4monthGap='post index LDL-c Level 4 months gap' ;
Drop self14 self15 self16;
run; *1947 ;

Data hypwork.dat8; set hypwork.dat7; 
IF for14=1 or for15=1 or for16=1; * This will keep all 2013, 2014, 2015, and 2016 cohorts;
Drop group2011 group2012;
run; * 1947 ;

**********************************************************************
**********************************************************************
 This is the final data for Dec 2018 AFTER Propensity Score Mathcing
* Data KZHYPEXP.dataF2018_Dec_3G; set hypwork.dat8;run; * 1947;
**********************************************************************
**********************************************************************

*
proc datasets library=HYPWORK nolist;
   delete 
For2014 For2015 For2016 dat dat2 dat3  
dat4 dat5 dat6

;quit;



