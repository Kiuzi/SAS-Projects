*-----------------------------------------------------------------------------;
*  Focus on psychotherapy -- less about med mgt and psych-rx   ;
*  Years of the study: 2014 
*-----------------------------------------------------------------------------;

*1)------------------------BEGIN EDIT SECTION----------------------------------

 Please edit pathway below to point to your copy of StdVars.sas for your site.
 Example of pathway follows.
 *%include "//aaa/bbb/StdVars.sas"; *<==EXAMPLE;
%include  "K:\CTX_CAHR_VDW_Medicine\...\StdVars.sas";*S&W; *<==Edit Pathway;

%include vdw_macs; * No need to change unless read standard macros out of a local directory; 

*2)----------------------------------------------------------------------------
 Please edit pathway below to point to the root directory where you expanded the
 folders in the zip file. The folders Input, Share, and Local appear under THE ROOT NAME YOU SUPPLIED.
 Seven sas datasets named antidepoth, anxother, atypical, benzo, prazosin, ssrni_antidep, and typical should be copied in the input folder
 Note that the macro variable, root, does NOT end with a slash.
 Example of pathway follows.  
*%let root=//xxx/yyy/zzz/THE ROOT NAME YOU SUPPLIED; *<==EXAMPLE(note no quotes or ending slash);

%let root=K:/...; *<==Edit Pathway;

*-----------------------------END EDIT SECTION---------------------------------;

*3)----------------------------------------------------------------------------
De identified data set excluding HIPAA protected variables will be saved in the Share folder that
will be transfered to Baylor Scott and White Health for final analysisl;

options pagesize=100 linesize = 150 nocenter msglevel = i NOOVP FORMdlim=" " COMPRESS=YES
formchar="|-++++++++++=|-/|<>*" date obs=max  nofmterr errors=4 mergenoby=warn; *was nodate;
options font="lucida console" 9;

libname input "&root/input";
libname share   "&root/share";
libname local "&root/local";  

%let StudyYear = 2014;
%let sdate =  01JAN2014;
%let edate =  31DEC2014;

%let infile = local.cookptsd_&_sitecode;
%let outfile = Share.DEID_cookptsd_&Studyyear._&_sitecode ;

* 1 * Identify the cohort of patients with at least 1 dx of PTSD 309.81 in CY *;
PROC SQL; 
  CREATE TABLE PTSDdates0 as select DISTINCT mrn
  , adate as dtPTSD
  , provider
  , diagprovider
  , enctype
  , enc_id
  , dx
  , "1" as ptsd
  FROM &_vdw_dx
  WHERE year(adate)=&StudyYear AND 
		mrn NE "" AND 
	   (COMPRESS(origdx,".")="30981" OR (COMPRESS(dx,".")="30981"))
	ORDER BY mrn, dtPTSD;
QUIT;


PROC SQL;
  CREATE TABLE PTSDcoh0 as select MRN
  , MIN(dtPTSD) as dtPTSD0 format=date9.
  , MAX(dtPTSD) as dtPTSDlast format=date9.
  , COUNT(dtPTSD) as numPTSDdates
  FROM PTSDdates0
  GROUP BY mrn;
QUIT; 

DATA coh0;
 SET ptsdcoh0(KEEP=mrn);
  RETAIN label 'xxxxxxxxxxxxxxxxxxxx'
         fmtname '$coh_';
		 start=mrn; format start $20.; RUN;
PROC format
	cntlin=coh0 ;QUIT;
 PROC datasets lib=work nolist; delete coh0; QUIT;

Data demoga(COMPRESS=YES); * Add demographics to "PTSDcoh" ;
 set &_vdw_demographic(
	WHERE=( PUT(mrn,$coh_.)="xxxxxxxxxxxxxxxxxxxx"  AND gender IN:("F","M")  )
	KEEP = mrn race1 hispanic gender birth_date )   ; * must have valid gender ;
	 age=INT( ("&sdate"d - birth_date)/365.25 );  * label age="as of Jan 1 2014"; 
	 if age LT 15 then DELETE;  * drop young kids and missing-on-age ;
	 if age GT 89 then DELETE; 	* drop 90+ ;
	female=(gender =:"F" ); male=(gender=:"M" );
	Asian = (race1="AS");
	Black = (race1="BA");
	White = (race1="WH");
	HNPI  = (race1="HP"); * native hawaiian or other pacific islander ;
	NATAM = (race1="IN"); 
	Hisp  = (race1="HL" or hispanic="Y"); 
	OtherRace = (race1 in("OT","MU"));
	KEEP MRN age female male Asian Black White HNPI NATAM Hisp OtherRace;
RUN; 

PROC SQL;
  CREATE TABLE demogb AS select mrn
  , MAX(female>0) as female, MAX(male>0) as male
  , MIN(age) as age
  , MAX(asian>0) as Asian, MAX(black>0) as Black, MAX(White>0) as White, MAX(hnpi>0) as HNPI, MAX(natam>0) as NATAM,MAX(otherrace>0) as OtherRace , MAX(hisp>0) as Hisp
  FROM demoga
  GROUP BY mrn
  having sum(female, male) eq 1;
QUIT; ;

* 2 * days covered by insurance * ;
%SimpleContinuous(people=ptsdcoh0     /* A dataset of MRNs whose enrollment we are considering. */
                     , StartDt= &sdate     /* A date literal identifying the start of the period of interest. */
                     , EndDt= &edate        /* A date literal identifying the end of the period of interest. */
                     , DaysTol=62      /* 2 months- The # of days gap between otherwise contiguous periods of enrollment that is tolerable. */
                     , OutSet= PtsdInsur       /* Name of the desired output dset */
                     ); 
					
Data PtsdInsur1(COMPRESS=YES); set PtsdInsur; 
Where ContinuouslyEnrolled ;run; * this applied recently 4/27/17;

* Updating the Cohort;
PROC SQL; create table PTSDdates as select distinct * from PTSDdates0 where MRN in ( Select MRN from demogb where MRN in (Select MRN from PtsdInsur1));QUIT;
PROC SQL;
  CREATE TABLE PTSDcoh as select * from PTSDcoh0 where MRN in (Select MRN from PTSDdates);QUIT;
DATA coh;
 SET ptsdcoh(KEEP=mrn);
  RETAIN label 'xxxxxxxxxxxxxxxxxxxx'
         fmtname '$coh_';
		 start=mrn; format start $20.; RUN;
PROC format
	cntlin=coh ;QUIT;
PROC datasets lib=work nolist; delete coh ptsdcoh0 ptsddates0; QUIT;
***************************************************;

* 3 * * PTSD mental vs PCP Visits * ;
PROC SQL; * adding specialty of provider;
	CREATE TABLE PTSD_spec as
	select DISTINCT p.*, s.specialty as prov_spec
	FROM  PTSDdates p 
		left join &_vdw_provider_specialty s on p.provider = s.provider;
			quit; 

PROC SQL; * adding specialty of diagprovider;
	CREATE TABLE PTSD_spec2 as
	select DISTINCT p.*, s.specialty as dxProv_spec
	FROM  PTSD_spec p
		left join &_vdw_provider_specialty s on p.diagprovider = s.provider;
			quit; 
	
Data PTSDCareType (Compress=YES);

	set PTSD_spec2;
	if prov_spec in ('PHA','UNK') then DELETE;

	if enctype IN ( 'IP' ) then PTSD_IP=1; 
	else if enctype IN( 'ED' ) or prov_spec in ('EME') then PTSD_ED=1;
	else if enctype IN ( 'AV' ) then DO; 

	if prov_spec ne '' then DO;
			if prov_spec in ('MEN', 'PSY') then PTSD_MentalViz=1;
			if prov_spec in ('FAM', 'IMG') then PTSD_PCPViz=1;
			END;

		if missing(prov_spec) then DO; 
				if dxProv_spec in ('MEN', 'PSY') then PTSD_MentalViz=1;
				if dxProv_spec in ('FAM', 'IMG') then PTSD_PCPViz=1;
				if dxProv_spec in ('EME') then PTSD_ED=1;
				END;
	END;
	if ^PTSD_MentalViz AND ^PTSD_PCPViz AND ^PTSD_ED AND ^PTSD_IP then PTSD_SpecViz=1; * lose 10 recs ;
	if PTSD_MentalViz or PTSD_PCPViz; 
	* if PTSD_PCPViz or PTSD_SpecViz then PTSD_NoMentalViz=1;
run; 

PROC SQL; 
 CREATE TABLE PTSDCareType2 as select MRN,dtPTSD,
	MAX(PTSD_MentalViz>0) as PTSD_MentalViz,
	MAX(PTSD_PCPViz>0) as PTSD_PCPViz
	FROM PTSDCareType
	GROUP BY MRN, dtPTSD;
quit; 

PROC SQL;  
 CREATE TABLE PTSDCareType3 as select MRN,				
	MAX(PTSD_MentalViz>0) as PTSD_MentalViz, SUM(PTSD_MentalViz>0) as PTSD_MentalViz_N label='Total PTSD Mental Health Visits', 
	MAX(PTSD_PCPViz>0) as PTSD_PCPViz, SUM(PTSD_PCPViz>0) as PTSD_PCPViz_N label='Total PTSD Primarycare Visits'
	FROM PTSDCareType2
	GROUP BY MRN;
quit; 

* 4 * * ALL cause mental vs PCP Visits * ;
* Redoing the above section for all visits of the cohort, not just PTSD visits;
PROC SQL; * adding specialty of provider;
	CREATE TABLE all_spec as
	select DISTINCT p.*, s.specialty as prov_spec
	FROM  &_vdw_dx(WHERE=(year(adate)=&StudyYear AND put(mrn,$coh_.)="xxxxxxxxxxxxxxxxxxxx")) p 
		left join &_vdw_provider_specialty s on p.provider = s.provider;
			quit; 

PROC SQL; * adding specialty of diagprovider;
	CREATE TABLE all_spec2 as 
	select DISTINCT p.*, s.specialty as dxProv_spec
	FROM  all_spec p
		left join &_vdw_provider_specialty s on p.diagprovider = s.provider;
			quit; 	
			
Data AllCareType (Compress=YES);
	set all_spec2;
	if prov_spec in ('PHA','UNK') then DELETE;

	if enctype IN ( 'IP' ) then Any_IP=1; 
	else if enctype IN( 'ED' ) or prov_spec in ('EME') then Any_ED=1;
	else if enctype IN ( 'AV' ) then DO; 

	if prov_spec ne '' then DO;
			if prov_spec in ('MEN', 'PSY') then Any_MentalViz=1;
			if prov_spec in ('FAM', 'IMG') then Any_PCPViz=1;
			END;

		if missing(prov_spec) then DO;
				if dxProv_spec in ('MEN', 'PSY') then Any_MentalViz=1;
				if dxProv_spec in ('FAM', 'IMG') then Any_PCPViz=1;
				if dxProv_spec in ('EME') then Any_ED=1;
				END;
	END;
	if ^Any_MentalViz AND ^Any_PCPViz AND ^Any_ED AND ^Any_IP then Any_SpecViz=1; * lose 10 recs ;
	if Any_MentalViz or Any_PCPViz; 
	*if Any_PCPViz or Any_SpecViz then Any_NoMentalViz=1;
run; 

PROC SQL; 
 CREATE TABLE AllCareType2 as select MRN, adate,
	MAX(Any_MentalViz>0) as Any_MentalViz,
	MAX(Any_PCPViz>0) as Any_PCPViz
	FROM AllCareType
	GROUP BY MRN, adate;
quit; 

PROC SQL;  
 CREATE TABLE AllCareType3 as select MRN,				
	MAX(Any_MentalViz>0) as Any_MentalViz, SUM(Any_MentalViz>0) as Any_MentalViz_N label='Total Mental Health Visits', 
	MAX(Any_PCPViz>0) as Any_PCPViz, SUM(Any_PCPViz>0) as Any_PCPViz_N label='Total Primary care Visits'		
	FROM AllCareType2
	GROUP BY MRN;
quit; 


Data Caretype;
 MERGE 
	PTSDcaretype3(IN=in1)
	AllCareType3(IN=in2);
		BY mrn;
		length PTSDViz AnyViz $16.;
		if PTSD_MentalViz then PTSDViz='Ment'; else PTSDviz='PCPonly';
		if Any_MentalViz then AnyViz='Ment'; else AnyViz='PCPonly'; 
		label PTSDViz='PTSD diagnosed health visits at Mental vs PCP' AnyViz='Any health visits at Mental vs PCP';
 if in1;
RUN; 

 PROC datasets lib=work nolist; delete dxall demoga PtsdInsur ptsdInsur1 PTSD_spec PTSD_spec2 PTSDCareType PTSDCareType2 PTSDcaretype3
all_spec all_spec2 AllCareType AllCareType2 AllCareType3 ; QUIT;

* PTSD-related psychotherapy and all-type psychotherapy ;
PROC SQL;
	CREATE TABLE PXALL as select DISTINCT mrn, px, enctype, provider, performingprovider, ProcDate, adate, enc_id
	FROM  &_vdw_px (where=(year(ProcDate)=&studyyear))
	where mrn in (select mrn FROM ptsdcoh);
quit;

PROC SQL; * joining the ptsd cohort with px to assess psychotherapy for PTSD (only) ;
	CREATE TABLE pxa( Compress=YES) as  
	select  DISTINCT p.*, t.dx, t.ptsd
	FROM pxall p right join PTSDdates t on p.mrn = t.mrn
									AND (p.ProcDate = t.dtPTSD or p.adate= t.dtPTSD)
									AND p.provider = t.provider AND p.enc_id = t.enc_id 
									 ;
quit; 

PROC SQL; * adding specialty of provider;
	CREATE TABLE pxb(Compress=YES) as  
	select  DISTINCT pxa.*, s.specialty as prov_spec
	FROM pxa p
		left join &_vdw_provider_specialty s on p.provider = s.provider
				where p.enctype not in ('LO', 'RO', 'EaM', 'TE') ;
quit; 

PROC SQL; * adding specialty of performingprovider;
	CREATE TABLE pxc as
	select DISTINCT p.*, s.specialty as pxProv_spec
	FROM  pxb p
		left join &_vdw_provider_specialty s on p.performingprovider = s.provider;
			quit;

Data pxd(COMPRESS=YES);
SET pxc;
if prov_spec in ('PHA','UNK') then DELETE;
if px in: 
	( '90804', '90805', '90806', '90807', '90808', '90809', '90810', 
	 '90811', '90812', '90813', '90814', '90815', 
	 '90832', '90833', '90834', '90836', '90837', '90838', '90839', '90840', '90847', '90853',
	 '96152', '96153', '96154', '96155') then DO;
PTSD_psyther=1; * Psychotherapy visit ;
if enctype='AV' AND prov_spec ne '' then DO;
if prov_spec in ('MEN', 'PSY') then PTSD_psytMHC=1; 
if prov_spec in ('FAM', 'IMG') then PTSD_psytPCP=1;	 
END;
if enctype='AV' AND missing(prov_spec) then DO; * This section doesn't apply to our data;
			if pxProv_spec in ('MEN', 'PSY') then PTSD_psytMHC=1;
			if prov_spec in ('FAM', 'IMG') then PTSD_psytPCP=1;
END;	
END;

 if px in:
 	( '90862', '90863')  then DO;
PTSD_psymedmgt=1; * med mgnt no psy-therapy;
if enctype='AV' AND prov_spec ne '' then DO;
if prov_spec in ('MEN', 'PSY') then PTSD_mgtMHC=1;
if prov_spec in ('FAM', 'IMG') then PTSD_mgtPCP=1;
END;
if enctype='AV' AND missing(prov_spec) then DO; * This section doesn't apply to our data;
			if pxProv_spec in ('MEN', 'PSY') then PTSD_mgtMHC=1; 
			if pxprov_spec in ('FAM', 'IMG') then PTSD_mgtPCP=1;
END;
END;

if PTSD_psyther AND ^PTSD_psytMHC AND ^PTSD_psyTPCP then PTSD_PsytOTH=1;
if PTSD_psymedmgt AND ^PTSD_mgtMHC AND ^PTSD_mgtPCP then PTSD_mgtOTH=1;

if PTSD_psyTPCP or PTSD_PsytOTH then PTSD_NopsytMHC=1; 
if PTSD_mgtPCP or PTSD_mgtOTH then PTSD_nomgtMHC=1;

run; 

PROC SQL;  
 CREATE TABLE pxe as select MRN, ProcDate,
 	MAX(PTSD_psyther>0) as PTSD_psyther, 
	MAX(PTSD_psymedmgt>0) as PTSD_psymedmgt,
	MAX(PTSD_psyTMHC>0) as PTSD_psytMHC, 
	MAX(PTSD_NopsyTMHC>0) as PTSD_NopsytMHC, 
	MAX(PTSD_psyTPCP>0) as PTSD_psytPCP,
	MAX(PTSD_PsyTOTH>0) as PTSD_PsytOTH, 
	MAX(PTSD_mgtMHC>0) as PTSD_mgtMHC,
	MAX(PTSD_NomgtMHC>0) as PTSD_NomgtMHC,
	MAX(PTSD_mgtPCP>0) as PTSD_mgtPCP,
	MAX(PTSD_mgtOTH>0) as PTSD_mgtOTH
	FROM pxd
	GROUP BY MRN, ProcDate;
quit; 

PROC SQL; 
 CREATE TABLE pxf as select MRN,
 	MAX(PTSD_psyther>0) as PTSD_psyther, 			SUM(PTSD_psyther>0) as PTSD_psyther_N Label='Total any PTSD Psychotherapy sessions',
	MAX(PTSD_psymedmgt>0) as PTSD_psymedmgt, 		SUM(PTSD_psymedmgt>0) as PTSD_psymedmgt_N  Label='Total any PTSD Medication Management sessions',
	MAX(PTSD_psyTMHC>0) as PTSD_psytMHC, 	SUM(PTSD_psytMHC>0) as PTSD_psytMHC_N Label='Total PTSD Mental Health Psychotherapy sessions',
	MAX(PTSD_NopsyTMHC>0) as PTSD_NopsytMHC, 	SUM(PTSD_NopsytMHC>0) as PTSD_NopsytMHC_N Label='Total PTSD Non-Mental Health Psychotherapy sessions',
	MAX(PTSD_psyTPCP>0) as PTSD_psytPCP,	SUM(PTSD_psytPCP>0) as PTSD_psytPCP_N Label='Total PTSD Primary Care Psychotherapy sessions',
	MAX(PTSD_PsyTOTH>0) as PTSD_PsytOTH, 	SUM(PTSD_PsytOTH>0) as PTSD_PsytOTH_N Label='Total PTSD Other Psychotherapy sessions',
	MAX(PTSD_mgtMHC>0) as PTSD_mgtMHC,	SUM(PTSD_mgtMHC>0) as PTSD_mgtMHC_N Label='Total PTSD Mental Health Medication Management sessions',
	MAX(PTSD_NomgtMHC>0) as PTSD_NomgtMHC,	SUM(PTSD_NomgtMHC>0) as PTSD_NomgtMHC_N Label='Total PTSD Non-Mental Health Medication Management sessions',
	MAX(PTSD_mgtPCP>0) as PTSD_mgtPCP,	SUM(PTSD_mgtPCP>0) as PTSD_mgtPCP_N Label='Total PTSD Primary Care Medication Management sessions',
	MAX(PTSD_mgtOTH>0) as PTSD_mgtOTH,	SUM(PTSD_mgtOTH>0) as PTSD_mgtOTH_N Label="Total PTSD Other Medication Management sessions"
	FROM pxe
	GROUP BY MRN;
quit; 


PROC SQL; * adding specialty of provider;
	CREATE TABLE pxall1(Compress=YES) as  
	select  DISTINCT p.*, s.specialty as prov_spec
	FROM pxall p
		left join &_vdw_provider_specialty s on p.provider = s.provider
				where p.enctype not in ('LO', 'RO', 'EM', 'TE');
quit; 
PROC SQL; * adding specialty of performingprovider;
	CREATE TABLE pxall2 as
	select DISTINCT p.*, s.specialty as pxProv_spec
	FROM  pxall1 p
		left join &_vdw_provider_specialty s on p.performingprovider = s.provider;
quit; 
Data pxall3(COMPRESS=YES);
 SET pxall2;
 if px in: 
	('90804', '90805', '90806', '90807', '90808', '90809', '90810', 
	 '90811', '90812', '90813', '90814', '90815', 
	 '90832', '90833', '90834', '90836', '90837', '90838', '90839', '90840', '90847', '90853',
	 '96152', '96153', '96154', '96155') then DO;
psyther=1;
if enctype='AV' AND prov_spec ne '' then DO;
if prov_spec in ('MEN', 'PSY') then psyTMHC=1;
if prov_spec in ('FAM', 'IMG') then psyTPCP=1;
END;
if enctype='AV' AND missing(prov_spec) then DO; * This section doesn't apply to our data;
			if pxProv_spec in ('MEN', 'PSY') then psyTMHC=1;
			if prov_spec in ('FAM', 'IMG') then psyTPCP=1;
END;	
END;

if px in:
 	('90862', '90863')  then DO;
psymedmgt=1; * med mgnt no psy-therapy;
if enctype='AV' AND prov_spec ne '' then DO;
if prov_spec in ('MEN', 'PSY') then MgtMHC=1;
if prov_spec in ('FAM', 'IMG') then MgtPCP=1;
END;
if enctype='AV' AND missing(prov_spec) then DO; * This section doesn't apply to our data;
			if pxProv_spec in ('MEN', 'PSY') then MgtMHC=1;
			if pxprov_spec in ('FAM', 'IMG') then MgtPCP=1;
END;
END;

if psyther AND ^psyTMHC AND ^psyTPCP then PsyTOTH=1;
if psymedmgt AND ^MgtMHC AND ^MgtPCP then MgtOTH=1;

if psyTPCP or PsyTOTH then psyTNoMHC=1;
if MgtPCP or MgtOTH then MgtNoMHC=1; 

if prov_spec in ('PHA','UNK') then DELETE;
run; 

PROC SQL;  
 CREATE TABLE pxall4 as select MRN, ProcDate,
 	MAX(psyther>0) as psyther, 
	MAX(psymedmgt>0) as psymedmgt,
	MAX(psyTMHC>0) as psyTMHC, 
	MAX(psyTNoMHC>0) as psyTNoMHC, 
	MAX(psyTPCP>0) as psyTPCP,
	MAX(PsyTOTH>0) as PsyTOTH, 
	MAX(MgtMHC>0) as MgtMHC,
   	MAX(MgtNoMHC>0) as MgtNoMHC,
	MAX(MgtPCP>0) as MgtPCP,
	MAX(MgtOTH>0) as MgtOTH
	FROM pxall3
	GROUP BY MRN, ProcDate;
quit; 

PROC SQL; 
 CREATE TABLE pxall5 (Compress=YES label='psychotherapy + medication management sesssions')  as select MRN,
 	MAX(psyther>0) as psyther, 		SUM(psyther>0) as psyther_N Label='Total Psychotherapy Sessions',
	MAX(psymedmgt>0) as psymedmgt, 	SUM(psymedmgt>0) as psymedmgt_N Label='Total Medication Management Sessions',
	MAX(psyTMHC>0) as psytMHC, 	SUM(psyTMHC>0) as psytMHC_N Label='Total Mental Health Psychotherapy Sessions',
	MAX(psyTNoMHC>0) as psyTNoMHC, 	SUM(psyTNoMHC>0) as psyTNoMHC_N Label='Total Non-Mental Health Psychotherapy Sessions',
	MAX(psyTPCP>0) as psytPCP,	SUM(psyTPCP>0) as psytPCP_N Label='Total Primary Care Psychotherapy Sessions',
	MAX(PsyTOTH>0) as PsytOTH, 	SUM(PsyTOTH>0) as PsytOTH_N Label='Total Other Psychotherapy Sessions',
	MAX(MgtMHC>0) as MgtMHC,	SUM(MgtMHC>0) as MgtMHC_N Label='Total Mental Health Medication Management Sessions',
	MAX(MgtNoMHC>0) as MgtNoMHC,	SUM(MgtNoMHC>0) as MgtNoMHC_N Label='Total Non-Mental Health Medication Management Sessions',
	MAX(MgtPCP>0) as MgtPCP,	SUM(MgtPCP>0) as MgtPCP_N Label='Total Primary Care Medication Management Sessions',
	MAX(MgtOTH>0) as MgtOTH,	SUM(MgtOTH>0) as MgtOTH_N Label="Total Other Medication Management Sessions"
	FROM pxall4
	GROUP BY MRN;
quit; 
PROC datasets lib=work nolist; delete  pxa pxb pxc pxd pxe pxall pxall1 pxall2 pxall3 pxall4 ; QUIT;

* 5 * * RX codes for the year prior and the year post-index date * ;
* Apply the drug class specs to create indicators of ever/never for Year 0 (pre-index) and Year 1 (post-index);

%GetRxForPeople(
People=ptsdcoh   /* The name of a dataset containing the MRNs of people whose fills you want. */
, StartDt=%sysfunc(PUTn("&sdate"d-365, DATE9.)) /* The date on which you want to start collecting fills. */
, EndDt=%sysfunc(PUTn("&edate"d+365, DATE9.)) /* The date on which you want to stop collecting fills. */
, Outset= Rxa   /* The name of the output dataset containing the fills. */
) ; 

PROC SQL; CREATE TABLE Rxb as select DISTINCT r.MRN, r.rxdate, r.ndc, r.rxsup, r.rxamt, p.dtPTSD0 
FROM Rxa r inner join ptsdcoh p on r.mrn=p.mrn where (dtPTSD0-365) LE rxdate LT (dtPTSD0+365) ;quit;

%ndclookup(
inds=input.Ssrni_antidep     /* An input dataset of strings to search for, in a var named "drugname".  */
, outds=rxSSRNI    /* The name of the output dset of NDCs, which contain one of the input strings. */
, EverNDC=&_vdw_everndc  /* The name of your local copy of the EverNDC file. */
); 
PROC SQL; CREATE TABLE RxPT1 as select DISTINCT R.*, E.GENERIC FROM rxb R left join rxSSRNI as E
on R.ndc=E.ndc where generic is not missing; quit; 
Data Rxc01; set RxPT1;
RXSSRNI=1;
if (dtPTSD0-365) le rxdate lt dtPTSD0 then DO;
				RxSSRNI0=1; 
				if rxsup in (28,30,34) then rxSSRNI30d0=1; else if rxsup in (60,84,90,120,150,180) then DO;
				rxSSRNI30d0=round(rxsup/30,1);
				if (rxdate+rxsup) gt (dtPTSD0) then DO;
				if rxdate+30 gt (dtPTSD0) then rxSSRNI30d0=1;
				else if rxdate+60 gt (dtPTSD0)  then rxSSRNI30d0=2;
				else if rxdate+90 gt (dtPTSD0) then rxSSRNI30d0=3;
				else if rxdate+120 gt (dtPTSD0) then rxSSRNI30d0=4;
				else if rxdate+150 gt (dtPTSD0) then rxSSRNI30d0=5;
				END;
			END;
		END;
else if dtPTSD0 le rxdate lt (dtPTSD0+365) then DO;
				RxSSRNI1=1;
				if rxsup in (28,30,34) then rxSSRNI30d1=1; else if rxsup in (60,84,90,120,150,180) then DO;
				rxSSRNI30d1=round(rxsup/30,1);
				if (rxdate+rxsup) gt (dtPTSD0+365) then DO;
				if rxdate+30 gt (dtPTSD0+365) then rxSSRNI30d1=1;
				else if rxdate+60 gt (dtPTSD0+365)  then rxSSRNI30d1=2;
				else if rxdate+90 gt (dtPTSD0+365) then rxSSRNI30d1=3;
				else if rxdate+120 gt (dtPTSD0+365) then rxSSRNI30d1=4;
				else if rxdate+150 gt (dtPTSD0+365) then rxSSRNI30d1=5;
				END;
			END;
		END;
run;
PROC SQL; CREATE TABLE Rxc11 as select DISTINCT MRN,rxdate,ndc,rxsup,rxamt,dtPTSD0,RXSSRNI,RxSSRNI0,RxSSRNI1,rxSSRNI30d0,rxSSRNI30d1 
	FROM Rxc01;quit; 
PROC SQL; CREATE TABLE RXA1 as select mrn, sum(rxSSRNI30d0) as rxSSRNI30d0N,
sum(rxSSRNI30d1) as rxSSRNI30d1N FROM  RXc11
GROUP BY mrn;quit;


%ndclookup(
inds=input.Antidepoth     /* An input dataset of strings to search for, in a var named "drugname".  */
, outds=rxDeprOther    /* The name of the output dset of NDCs, which contain one of the input strings. */
, EverNDC=&_vdw_everndc   /* The name of your local copy of the EverNDC file. */
); 
PROC SQL; CREATE TABLE RxPT2 as select DISTINCT R.*, E.GENERIC FROM rxb R left join rxDeprOther as E
on R.ndc=E.ndc where generic is not missing; quit; 
Data Rxc02; set RxPT2;
rxDeprOther=1;
if (dtPTSD0-365) le rxdate lt dtPTSD0 then DO;
				rxDeprOther0=1; 
				if rxsup in (28,30,34) then rxDeprOther30d0=1; else if rxsup in (60,84,90,120,150,180) then DO;
				rxDeprOther30d0=round(rxsup/30,1);
				if (rxdate+rxsup) gt (dtPTSD0) then DO;
				if rxdate+30 gt (dtPTSD0) then rxDeprOther30d0=1;
				else if rxdate+60 gt (dtPTSD0)  then rxDeprOther30d0=2;
				else if rxdate+90 gt (dtPTSD0) then rxDeprOther30d0=3;
				else if rxdate+120 gt (dtPTSD0) then rxDeprOther30d0=4;
				else if rxdate+150 gt (dtPTSD0) then rxDeprOther30d0=5;
				END;
			END;
		END;
else if dtPTSD0 le rxdate lt (dtPTSD0+365) then DO;
				rxDeprOther1=1;
				if rxsup in (28,30,34) then rxDeprOther30d1=1; else if rxsup in (60,84,90,120,150,180) then DO;
				rxDeprOther30d1=round(rxsup/30,1);
				if (rxdate+rxsup) gt (dtPTSD0+365) then DO;
				if rxdate+30 gt (dtPTSD0+365) then rxDeprOther30d1=1;
				else if rxdate+60 gt (dtPTSD0+365)  then rxDeprOther30d1=2;
				else if rxdate+90 gt (dtPTSD0+365) then rxDeprOther30d1=3;
				else if rxdate+120 gt (dtPTSD0+365) then rxDeprOther30d1=4;
				else if rxdate+150 gt (dtPTSD0+365) then rxDeprOther30d1=5;
				END;
			END;
		END;
run;
PROC SQL; CREATE TABLE Rxc22 as select DISTINCT 
 MRN,rxdate,ndc,rxsup,rxamt,dtPTSD0,rxDeprOther,rxDeprOther0,rxDeprOther1,rxDeprOther30d0,rxDeprOther30d1 
 FROM Rxc02;quit; 
PROC SQL; CREATE TABLE RXA2 as select mrn, sum(rxDeprOther30d0) as rxDeprOther30d0N,  sum(rxDeprOther30d1) as rxDeprOther30d1N 
 FROM  RXc22
 GROUP BY mrn;quit; 


%ndclookup(
inds=input.Typical     /* An input dataset of strings to search for, in a var named "drugname".  */
, outds=rxTypical    /* The name of the output dset of NDCs, which contain one of the input strings. */
, EverNDC=&_vdw_everndc   /* The name of your local copy of the EverNDC file. */
); 
PROC SQL; CREATE TABLE RxPT3 as select DISTINCT R.*, E.GENERIC FROM rxb R left join rxTypical as E
 on R.ndc=E.ndc where generic is not missing; quit;
Data Rxc03; set RxPT3;
rxTypical=1;
if (dtPTSD0-365) le rxdate lt dtPTSD0 then DO;
				rxTypical0=1; 
				if rxsup in (28,30,34) then rxTypical30d0=1; else if rxsup in (60,84,90,120,150,180) then DO;
				rxTypical30d0=round(rxsup/30,1);
				if (rxdate+rxsup) gt (dtPTSD0) then DO;
				if rxdate+30 gt (dtPTSD0) then rxTypical30d0=1;
				else if rxdate+60 gt (dtPTSD0)  then rxTypical30d0=2;
				else if rxdate+90 gt (dtPTSD0) then rxTypical30d0=3;
				else if rxdate+120 gt (dtPTSD0) then rxTypical30d0=4;
				else if rxdate+150 gt (dtPTSD0) then rxTypical30d0=5;
				END;
			END;
		END;
else if dtPTSD0 le rxdate lt (dtPTSD0+365) then DO;
				rxTypical1=1;
				if rxsup in (28,30,34) then rxTypical30d1=1; else if rxsup in (60,84,90,120,150,180) then DO;
				rxTypical30d1=round(rxsup/30,1);
				if (rxdate+rxsup) gt (dtPTSD0+365) then DO;
				if rxdate+30 gt (dtPTSD0+365) then rxTypical30d1=1;
				else if rxdate+60 gt (dtPTSD0+365)  then rxTypical30d1=2;
				else if rxdate+90 gt (dtPTSD0+365) then rxTypical30d1=3;
				else if rxdate+120 gt (dtPTSD0+365) then rxTypical30d1=4;
				else if rxdate+150 gt (dtPTSD0+365) then rxTypical30d1=5;
				END;
			END;
		END;
run;
PROC SQL; CREATE TABLE Rxc33 as select DISTINCT 
 MRN,rxdate,ndc,rxsup,rxamt,dtPTSD0,rxTypical,rxTypical0,rxTypical1,rxTypical30d0,rxTypical30d1 
 FROM Rxc03;quit; 
PROC SQL; CREATE TABLE RXA3 as select mrn, sum(rxTypical30d0) as rxTypical30d0N,  sum(rxTypical30d1) as rxTypical30d1N 
 FROM  RXc33
 GROUP BY mrn;quit;

%ndclookup(
inds=input.Atypical     /* An input dataset of strings to search for, in a var named "drugname".  */
, outds=rxAtypical    /* The name of the output dset of NDCs, which contain one of the input strings. */
, EverNDC=&_vdw_everndc   /* The name of your local copy of the EverNDC file. */
);
PROC SQL; CREATE TABLE RxPT4 as select DISTINCT R.*, E.GENERIC FROM rxb R left join rxATypical as E
 on R.ndc=E.ndc  where generic is not missing; quit; 
Data Rxc04; set RxPT4;
rxATypical=1;
if (dtPTSD0-365) le rxdate lt dtPTSD0 then DO;
				rxATypical0=1; 
				if rxsup in (28,30,34) then rxATypical30d0=1; else if rxsup in (60,84,90,120,150,180) then DO;
				rxATypical30d0=round(rxsup/30,1);
				if (rxdate+rxsup) gt (dtPTSD0) then DO;
				if rxdate+30 gt (dtPTSD0) then rxATypical30d0=1;
				else if rxdate+60 gt (dtPTSD0)  then rxATypical30d0=2;
				else if rxdate+90 gt (dtPTSD0) then rxATypical30d0=3;
				else if rxdate+120 gt (dtPTSD0) then rxATypical30d0=4;
				else if rxdate+150 gt (dtPTSD0) then rxATypical30d0=5;
				END;
			END;
		END;
else if dtPTSD0 le rxdate lt (dtPTSD0+365) then DO;
				rxATypical1=1;
				if rxsup in (28,30,34) then rxATypical30d1=1; else if rxsup in (60,84,90,120,150,180) then DO;
				rxATypical30d1=round(rxsup/30,1);
				if (rxdate+rxsup) gt (dtPTSD0+365) then DO;
				if rxdate+30 gt (dtPTSD0+365) then rxATypical30d1=1;
				else if rxdate+60 gt (dtPTSD0+365)  then rxATypical30d1=2;
				else if rxdate+90 gt (dtPTSD0+365) then rxATypical30d1=3;
				else if rxdate+120 gt (dtPTSD0+365) then rxATypical30d1=4;
				else if rxdate+150 gt (dtPTSD0+365) then rxATypical30d1=5;
				END;
			END;
		END;
run;
PROC SQL; CREATE TABLE Rxc44 as select DISTINCT 
 MRN,rxdate,ndc,rxsup,rxamt,dtPTSD0,rxATypical,rxATypical0,rxATypical1,rxATypical30d0,rxATypical30d1 
 FROM Rxc04;quit; 
PROC SQL; CREATE TABLE RXA4 as select mrn, sum(rxATypical30d0) as rxATypical30d0N, sum(rxATypical30d1) as rxATypical30d1N 
 FROM  RXc44 GROUP BY mrn;quit;

%ndclookup(
inds=input.Anxother     /* An input dataset of strings to search for, in a var named "drugname".  */
, outds=rxAnxOther    /* The name of the output dset of NDCs,which contain one of the input strings. */
, EverNDC=&_vdw_everndc  /* The name of your local copy of the EverNDC file. */
);
PROC SQL; CREATE TABLE RxPT5 as select DISTINCT R.*, E.GENERIC FROM rxb R left join rxAnxOther as E
 on R.ndc=E.ndc  where generic is not missing; quit;
Data Rxc05; set RxPT5;
rxAnxother=1;
if (dtPTSD0-365) le rxdate lt dtPTSD0 then DO;
				rxAnxother0=1; 
				if rxsup in (28,30,34) then rxAnxother30d0=1; else if rxsup in (60,84,90,120,150,180) then DO;
				rxAnxother30d0=round(rxsup/30,1);
				if (rxdate+rxsup) gt (dtPTSD0) then DO;
				if rxdate+30 gt (dtPTSD0) then rxAnxother30d0=1;
				else if rxdate+60 gt (dtPTSD0)  then rxAnxother30d0=2;
				else if rxdate+90 gt (dtPTSD0) then rxAnxother30d0=3;
				else if rxdate+120 gt (dtPTSD0) then rxAnxother30d0=4;
				else if rxdate+150 gt (dtPTSD0) then rxAnxother30d0=5;
				END;
			END;
		END;
else if dtPTSD0 le rxdate lt (dtPTSD0+365) then DO;
				rxAnxother1=1;
				if rxsup in (28,30,34) then rxAnxother30d1=1; else if rxsup in (60,84,90,120,150,180) then DO;
				rxAnxother30d1=round(rxsup/30,1);
				if (rxdate+rxsup) gt (dtPTSD0+365) then DO;
				if rxdate+30 gt (dtPTSD0+365) then rxAnxother30d1=1;
				else if rxdate+60 gt (dtPTSD0+365)  then rxAnxother30d1=2;
				else if rxdate+90 gt (dtPTSD0+365) then rxAnxother30d1=3;
				else if rxdate+120 gt (dtPTSD0+365) then rxAnxother30d1=4;
				else if rxdate+150 gt (dtPTSD0+365) then rxAnxother30d1=5;
				END;
			END;
		END;
run;
PROC SQL; CREATE TABLE Rxc55 as select DISTINCT 
  MRN,rxdate,ndc,rxsup,rxamt,dtPTSD0,rxAnxother,rxAnxother0,rxAnxother1,rxAnxother30d0,rxAnxother30d1 
	FROM Rxc05;quit; 
PROC SQL; CREATE TABLE RXA5 as select mrn, sum(rxAnxother30d0) as rxAnxother30d0N, sum(rxAnxother30d1) as rxAnxother30d1N 
 FROM  RXc55 GROUP BY mrn;quit; 

%ndclookup(
inds=input.Benzo     /* An input dataset of strings to search for, in a var named "drugname".  */
, outds=rxBenzo    /* The name of the output dset of NDCs, which contain one of the input strings. */
, EverNDC=&_vdw_everndc  /* The name of your local copy of the EverNDC file. */
); 
PROC SQL; CREATE TABLE RxPT6 as select DISTINCT R.*, E.GENERIC FROM rxb R left join rxBenzo as E
 on R.ndc=E.ndc  where generic is not missing; quit; 
Data Rxc06; set RxPT6;
rxBenzo=1;
if (dtPTSD0-365) le rxdate lt dtPTSD0 then DO;
				rxBenzo0=1; 
				if rxsup in (28,30,34) then rxBenzo30d0=1; else if rxsup in (60,84,90,120,150,180) then DO; 
				rxBenzo30d0=round(rxsup/30,1);
				if (rxdate+rxsup) gt (dtPTSD0) then DO;
				if rxdate+30 gt (dtPTSD0) then rxBenzo30d0=1;
				else if rxdate+60 gt (dtPTSD0)  then rxBenzo30d0=2;
				else if rxdate+90 gt (dtPTSD0) then rxBenzo30d0=3;
				else if rxdate+120 gt (dtPTSD0) then rxBenzo30d0=4;
				else if rxdate+150 gt (dtPTSD0) then rxBenzo30d0=5;
				END;
			END;
		END;
else if dtPTSD0 le rxdate lt (dtPTSD0+365) then DO;
				rxBenzo1=1;
				if rxsup in (28,30,34) then rxBenzo30d1=1; else if rxsup in (60,84,90,120,150,180) then DO;
				rxBenzo30d1=round(rxsup/30,1);
				if (rxdate+rxsup) gt (dtPTSD0+365) then DO;
				if rxdate+30 gt (dtPTSD0+365) then rxBenzo30d1=1;
				else if rxdate+60 gt (dtPTSD0+365)  then rxBenzo30d1=2;
				else if rxdate+90 gt (dtPTSD0+365) then rxBenzo30d1=3;
				else if rxdate+120 gt (dtPTSD0+365) then rxBenzo30d1=4;
				else if rxdate+150 gt (dtPTSD0+365) then rxBenzo30d1=5;
				END;
			END;
		END;
run;
PROC SQL; CREATE TABLE Rxc66 as select DISTINCT 
 MRN,rxdate,ndc,rxsup,rxamt,dtPTSD0,rxBenzo,rxBenzo0,rxBenzo1,rxBenzo30d0,rxBenzo30d1 
 FROM Rxc06;quit; 
PROC SQL; CREATE TABLE RXA6 as select mrn, sum(rxBenzo30d0) as rxBenzo30d0N, sum(rxBenzo30d1) as rxBenzo30d1N FROM  RXc66
 GROUP BY mrn;quit; 

%ndclookup(
inds=input.Prazosin     /* An input dataset of strings to search for, in a var named "drugname".  */
, outds=rxPrazosin    /* The name of the output dset of NDCs, which contain one of the input strings. */
, EverNDC=&_vdw_everndc /* The name of your local copy of the EverNDC file. */
); 
PROC SQL; CREATE TABLE RxPT7 as select DISTINCT R.*, E.GENERIC FROM rxb R left join rxPrazosin as E
 on R.ndc=E.ndc  where generic is not missing; quit; 
Data Rxc07; set RxPT7;
rxPrazosin=1;
if (dtPTSD0-365) le rxdate lt dtPTSD0 then DO;
				rxPrazosin0=1; 
				if rxsup in (28,30,34) then rxPrazosin30d0=1; else if rxsup in (60,84,90,120,150,180) then DO;
				rxPrazosin30d0=round(rxsup/30,1);
				if (rxdate+rxsup) gt (dtPTSD0) then DO;
				if rxdate+30 gt (dtPTSD0) then rxPrazosin30d0=1;
				else if rxdate+60 gt (dtPTSD0)  then rxPrazosin30d0=2;
				else if rxdate+90 gt (dtPTSD0) then rxPrazosin30d0=3;
				else if rxdate+120 gt (dtPTSD0) then rxPrazosin30d0=4;
				else if rxdate+150 gt (dtPTSD0) then rxPrazosin30d0=5;
				END;
			END;
		END;
else if dtPTSD0 le rxdate lt (dtPTSD0+365) then DO;
				rxPrazosin1=1;
				if rxsup in (28,30,34) then rxPrazosin30d1=1; else if rxsup in (60,84,90,120,150,180) then DO;
				rxPrazosin30d1=round(rxsup/30,1);
				if (rxdate+rxsup) gt (dtPTSD0+365) then DO;
				if rxdate+30 gt (dtPTSD0+365) then rxPrazosin30d1=1;
				else if rxdate+60 gt (dtPTSD0+365)  then rxPrazosin30d1=2;
				else if rxdate+90 gt (dtPTSD0+365) then rxPrazosin30d1=3;
				else if rxdate+120 gt (dtPTSD0+365) then rxPrazosin30d1=4;
				else if rxdate+150 gt (dtPTSD0+365) then rxPrazosin30d1=5;
				END;
			END;
		END;
run;
PROC SQL; CREATE TABLE Rxc77 as select DISTINCT 
 MRN,rxdate,ndc,rxsup,rxamt,dtPTSD0,rxPrazosin,rxPrazosin0,rxPrazosin1,rxPrazosin30d0,rxPrazosin30d1 
 FROM Rxc07;quit; 
PROC SQL; CREATE TABLE RXA7 as select mrn, sum(rxPrazosin30d0) as rxPrazosin30d0N,  sum(rxPrazosin30d1) as rxPrazosin30d1N 
 FROM  RXc77
 GROUP BY mrn;quit;


Data RXF;
merge RXA1 RXA2 RXA3 RXA4 RXA5 RXA6 RXA7;by mrn;
ARRAY rr rxSSRNI30d0N -- rxPrazosin30d1N  ; DO OVER rr; if rr=. then rr=0;END;
run;  
  PROC datasets lib=work nolist;
 delete Rxanxother Rxatypical Rxbenzo Rxdeprother Rxprazosin Rxssrni Rxtypical
		Rxc01 RxPT1 Rxc11 RXA1
	    Rxc02 RxPT2 Rxc22 RXA2
        Rxc03 RxPT3 Rxc33 RXA3
		Rxc04 RxPT4 Rxc44 RXA4
		Rxc05 RxPT5 Rxc55 RXA5
		Rxc06 RxPT6 Rxc66 RXA6
		Rxc07 RxPT7 Rxc77 RXA7
		RXa RXb;
quit; 

* 6 * DIAGNOSED COMORBIDITY * Within one year prior to the PTSD diagnosis;
* using the enhanced University of Manitoba Charlson code;
PROC SQL; CREATE TABLE comorbid2 as select c.*, p.dtPTSD0 
 FROM &_vdw_dx c inner join ptsdcoh p on c.mrn=p.mrn
 WHERE year(adate)  in (%sysfunc(putn(&Studyyear-1,best9.)), &Studyyear) AND COALESCE(p.mrn,c.mrn) NE ''
 ;quit; 

Data comorbid3(COMPRESS=YES);
 SET comorbid2 (Where=((dtPTSD0-365) LE adate LT dtPTSD0)) ; 
	ARRAY dd origdx dx; DO OVER dd;  
	  if COMPRESS(dd,".") IN:("30981")  then ptsd=1;
	  if COMPRESS(dd,".") IN:("272")  then dyslip=1;
	  if COMPRESS(dd,".") IN:("401","402","403","404","405") then HTN=1;
	  if COMPRESS(dd,".") IN:("3000") then anxiety=1;
	  if COMPRESS(dd,".") IN:("29383", "2962", "2963", "29690", "2980", "3004", "3090","3091", "311") then depress=1;
	  if COMPRESS(dd,".") IN:("291","292","303","304","305") AND COMPRESS(dd,".") not IN:("3051") then SUD=1;
	  if COMPRESS(dd,".") IN:("295","297","298") then psychosis=1;
	  if COMPRESS(dd,".") IN:("2960","2961","2964","2965","2966","2967","2968") then bipolar=1;

	  /* Myocardial Infarction */
          if  COMPRESS(dd,".") IN: ('410','412') then CC1MI = 1;
         /* Congestive Heart Failure */
          if  COMPRESS(dd,".") IN: ('39891','40201','40211','40291','40401','40403','40411','40413','40491','40493',
                         '4254','4255','4257','4258','4259','428') then CC2CHF= 1;
         /* Periphral Vascular Disease */
          if  COMPRESS(dd,".") IN: ('0930','4373','440','441','4431','4432','4438','4439','4471','5571','5579','V434')
                          then CC3VASC = 1;
         /* Cerebrovascular Disease */
          if COMPRESS(dd,".") IN: ('36234','430','431','432','433','434','435','436','437','438') then CC4STROKE = 1;
         /* Dementia */
          if  COMPRESS(dd,".") IN: ('290','2941','3312') then CC5DEM = 1;
         /* Chronic Pulmonary Disease */
          if  COMPRESS(dd,".") IN: ('4168','4169','490','491','492','493','494','495','496','500','501','502','503',
                          '504','505','5064','5081','5088') then CC6COPD= 1;
         /* Connective Tissue Disease-Rheumatic Disease */
          if  COMPRESS(dd,".") IN: ('4465','7100','7101','7102','7103','7104','7140','7141','7142','7148','725')
                         then CC7RHEUM = 1;
         /* Peptic Ulcer Disease */
          if  COMPRESS(dd,".") IN: ('531','532','533','534') then CC8PUD = 1;
         /* Mild Liver Disease */
          if  COMPRESS(dd,".") IN: ('07022','07023','07032','07033','07044','07054','0706','0709','570','571','5733',
                        '5734','5738','5739','V427') then CC9CIRRH = 1;
         /* Diabetes without complications */
          if  COMPRESS(dd,".") IN: ('2500','2501','2502','2503','2508','2509') then CC10DIAB = 1;
         /* Diabetes with complications */
          if  COMPRESS(dd,".") IN: ('2504','2505','2506','2507') then CC11DIABCOMPL = 1;
         /* Paraplegia and Hemiplegia */
          if  COMPRESS(dd,".") IN: ('3341','342','343','3440','3441','3442','3443','3444','3445','3446','3449')
                          then CC12PLEGIA = 1;
         /* Renal Disease */
          if  COMPRESS(dd,".") IN: ('40301','40311','40391','40402','40403','40412','40413','40492','40493','582',
                         '5830','5831','5832','5834','5836','5837','585','586','5880','V420','V451','V56')
                         then CC13RENAL = 1;
         /* Cancer */
          if  COMPRESS(dd,".") IN: ('140','141','142','143','144','145','146','147','148','149','150','151','152','153',
                         '154','155','156','157','158','159','160','161','162','163','164','165','170','171',
                         '172','174','175','176','179','180','181','182','183','184','185','186','187','188',
                         '189','190','191','192','193','194','195','200','201','202','203','204','205','206',
                         '207','208','2386') then CC14CANC = 1;
         /* Moderate or Severe Liver Disease */
          if  COMPRESS(dd,".") IN: ('4560','4561','4562','5722','5723','5724','5728')
                         then CC15HEPFAIL = 1;
         /* Metastatic Carcinoma */
          if  COMPRESS(dd,".") IN: ('196','197','198','199') then CC16CAMETAS = 1;
         /* AIDS/HIV */
          if  COMPRESS(dd,".") IN: ('042','043','044') then CC17HIVAIDS = 1;
	  END;
RUN; 

PROC SQL; 
 CREATE TABLE comorbid4 as select MRN
   , MAX(ptsd>0) as ptsd
   , MAX(dyslip>0) as dyslip
   , MAX(HTN>0) as HTN
   , MAX(anxiety>0) as anxiety
   , MAX(depress>0) as depress
   , MAX(SUD>0) as SUD
   , MAX(psychosis>0) as psychosis
   , MAX(bipolar>0) as bipolar
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
   , MAX(CC17HIVAIDS>0) as CC17HIVAIDS
	FROM comorbid3
	GROUP BY MRN;
quit; 
Data PTSDcomorbid (COMPRESS=YES); set comorbid4;
  if (CC10DIAB or CC11DIABCOMPL) then DiabAny=1;else DiabAny=0;
  CharlsonY0=SUM( of CC: );
CharlsonY0_Weight = (CC1MI + CC2CHF + CC3VASC + CC4STROKE + CC5DEM + CC6COPD + CC7RHEUM + CC8PUD + CC9CIRRH + CC10DIAB 
				+ 2*CC11DIABCOMPL + 2*CC12PLEGIA + 2*CC13RENAL + 2*CC14CANC 
				+ 3*CC15HEPFAIL 
				+ 6*CC16CAMETAS + 6*CC17HIVAIDS);
 label CharlsonY0 = "Prior year CCI" CharlsonY0_Weight= "Prior year CCI weighted" DiabAny = "Any Diabetes w/wo complications"
 CC1MI="Myocardial Infarction"  CC2CHF="Congestive Heart Failure" CC3VASC="Periphral Vascular Disease" CC4STROKE="Cerebrovascular Disease"
 CC5DEM="Dementia" CC6COPD="Chronic Pulmonary Disease" CC7RHEUM="Connective Tissue Disease-Rheumatic Disease" CC8PUD="Peptic Ulcer Disease"
CC9CIRRH="Mild Liver Disease" CC10DIAB="Diabetes without complications" CC11DIABCOMPL="Diabetes with complications" CC12PLEGIA="Paraplegia and Hemiplegia"
CC13RENAL="Renal Disease" CC14CANC="Cancer" CC15HEPFAIL="Moderate or Severe Liver Disease" CC16CAMETAS="Metastatic Carcinoma" CC17HIVAIDS="AIDS/HIV";
RUN;

PROC datasets lib=work nolist; delete comorbid4 comorbid3 comorbid2 ; QUIT;

PROC format library=work;
value age_fmt
0-29='15-29 years' 
30-64='30-64 years' 
65-90='65-989years';
run;
Data &infile; *local.COOKPTSD&_sitecode; * For site use only since it has PHI;
 MERGE 
	ptsdcoh(IN=in0)
	demogb(IN=in1) 
	Caretype(IN=in3)
	pxf(IN=in4)
	pxall5(IN=in5)
	rxF(IN=in6)
	PTSDcomorbid ;
		BY mrn;
		if in0 AND in1 AND in3;
 RaceMiss=(SUM(asian, black, white, hnpi, natam, otherrace)=0);
Age_G=put(age, age_fmt.);
Age10=Age/10;
  * replace missing with zero for persons without that condition ;
Array pp PTSD_MentalViz -- Any_PCPViz_N; DO over pp; if pp=. then pp=0; END;
ARRAY dd ptsd dyslip HTN anxiety depress SUD psychosis bipolar CC1MI CC2CHF CC3VASC CC4STROKE CC5DEM CC6COPD
          CC7RHEUM CC8PUD CC9CIRRH CC10DIAB CC11DIABCOMPL CC12PLEGIA CC13RENAL CC14CANC CC15HEPFAIL CC16CAMETAS
          CC17HIVAIDS Diabany CharlsonY0 CharlsonY0_Weight; 
  		 DO OVER dd; if dd=. then dd=0; END; 
  * recreate indicators FROM counts ;
ARRAY vv(*) rxSSRNI0 rxSSRNI1 rxDeprOther0 rxDeprOther1 rxTypical0 rxTypical1 rxAtypical0 rxAtypical1 rxBenzo0 rxBenzo1 rxAnxother0 rxAnxother1 rxPrazosin0 rxPrazosin1;
ARRAY rr(*) rxSSRNI30d0n rxSSRNI30d1n rxDeprOther30d0n rxDeprOther30d1n rxTypical30d0n rxTypical30d1n rxAtypical30d0n rxAtypical30d1n 
	     rxBenzo30d0n rxBenzo30d1n rxAnxother30d0n rxAnxother30d1n rxPrazosin30d0n rxPrazosin30d1n;
		 DO i=1 to DIM(rr); if rr(i)=. then rr(i)=0; END;
		 DO i=1 to DIM(vv);
		 	vv(i)=( rr(i) >0 );
		 END;	DROP i;
RUN; 

* Deidentifying data and saving in the share folder;
data CookPTSDtemp;
set &infile;
retain seed 1234321; ckvar=ranuni(seed); run;
run;
proc sort data=CookPTSDtemp; by ckvar;run;
data &outfile (COMPRESS=YES); set CookPTSDtemp ; 
length ID $9.;
site=&_sitecode;
idtemp=put(_N_, Z7.);
ID=CAT(&_sitecode,idtemp); 
drop seed ckvar idtemp MRN dtPTSD0 dtPTSDlast; run; 

PROC datasets lib=work nolist; delete ptsdcoh demogb  Caretype pxf pxall5 rxF PTSDcomorbid ptsddates CookPTSDtemp; QUIT;
