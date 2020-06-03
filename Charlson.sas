proc import  out=Charlson0
datafile= "K:\Center for Applied Health Research\...\Charlson.xlsx"
dbms=xlsx replace; getnames=Yes; 
run; 

proc sort data=Charlson0; by MRN; run;
**********************************
* Find Charlson ;
*********************************;

data Charlson1 (compress=yes ); set Charlson0;
	array adx code;
	do over adx;
	
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
			COMPRESS(adx,".")  IN: ('K704','K711','K721','K729','K765','K766','K767') then CC15HEPFAIL = 1;
         /* Metastatic Carcinoma */
          if  COMPRESS(adx,".") IN: ('196','197','198','199') or 
			COMPRESS(adx,".")  IN: ('C77','C78','C79','C80')  then CC16CAMETAS = 1;
         /* AIDS/HIV */
          if  COMPRESS(adx,".") IN: ('042','043','044') or 
			COMPRESS(adx,".")  IN: ('B20','B21','B22','B24') then CC17HIVAIDS = 1;
		***** end of charlson;
	END;

	ARRAY zero CC1MI -- CC17HIVAIDS ; DO OVER zero; if zero='.' then zero=0;end;

	run;

proc sql;
	create table Charlson2 as select distinct MRN, pat_ID  
	
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

	from Charlson1 
	group by MRN;
quit;

data Charlson3; set Charlson2 ;
	CHARLSON_PRE = (CC1MI + CC2CHF + CC3VASC + CC4STROKE + CC5DEM + CC6COPD + CC7RHEUM + CC8PUD + CC9CIRRH + CC10DIAB 
				+ 2*CC11DIABCOMPL + 2*CC12PLEGIA + 2*CC13RENAL + 2*CC14CANC 
				+ 3*CC15HEPFAIL 
				+ 6*CC16CAMETAS + 6*CC17HIVAIDS);
keep MRN Pat_ID CHARLSON_PRE;
run;
