* Propensity Score matching macro;
* This macro is derived from:http://www.lexjansen.com/nesug/nesug10/ad/ad05.pdf;
* it works fine on smaller samples, on larger samples like the one that I tried for a sample of 4000 it takes about half a day to run;

* First split data into two cohort of treated(case) vs not treated(control);
data prop_score_treated
 prop_score_untreated;
 set propensity_scores;
 if drug_treat_flag = 1 then output prop_score_treated;
 else if drug_treat_flag = 0 then output prop_score_untreated;
 run;

* The matching macro;
%macro psmatch_multi(pat_dsn =, /* Name of data set with patient data */
 pat_idvar=, /* Name of Patient ID variable in data set &PAT_DSN */
 pat_psvar=, /* Name of Propensity Score variable in data set &PAT_DSN */
 cntl_dsn=, /* Name of data set with control data */
 cntl_idvar=, /* Name of Control ID variable in data set &CNTL_DSN */
 cntl_psvar=, /* Name of Propensity Score variable in data set &CNTL_DSN */
 match_dsn=, /* Name of output data set with N:1 matches */
 match_ratio=, /* Number of control matches per patient */
 score_diff=, /* Maximum allowable absolute differences between propensity scores*/
 seed=1234567890) /* Optional input seed for random number generator */
;

 proc datasets nolist;
 delete __final_matched_pairs;
 run;
 quit;

 %local __dsid __varnum __cntl_type __rc __num;

 %let __dsid = %sysfunc(open(&cntl_dsn,i));
 %let __varnum = %sysfunc(varnum(&__dsid, &cntl_idvar));
 %let __cntl_type = %sysfunc(vartype(&__dsid, &__varnum));
 %let __rc = %sysfunc(close(&__dsid));
 %put &__cntl_type;

 data __patmatch (keep = &pat_idvar &pat_psvar);
 set &pat_dsn;
 run;

 data __contmatch (keep = &cntl_idvar &cntl_psvar);
 set &cntl_dsn;
 run;

 proc sql;
 create table __matches0 as
 select
 p.&pat_idvar as pat_idvar,
 c.&cntl_idvar as cntl_idvar,
 p.&pat_psvar as pat_score,
 c.&cntl_psvar as cntl_score
 from __patmatch p left join __contmatch c
 on abs(p.&pat_psvar - c.&cntl_psvar) <= &score_diff
 order by pat_idvar;
 quit;

 data __possible_matches;
 set __matches0;

 rand_num = ranuni(&seed);

 %if &__cntl_type = C %then %do;
 if cntl_idvar ^= '';
 %end;
 %else %if &__cntl_type = N %then %do;
 if cntl_idvar ^= .;
 %end;

 n = 1;

 run;

 proc freq data=__possible_matches noprint;
 tables pat_idvar / out=__matchfreq (keep = pat_idvar count);
 run;

 data __matches_freq0;
 merge __possible_matches
 __matchfreq;
 by pat_idvar;
 run;

 proc freq data=__possible_matches noprint;
 tables cntl_idvar / out=__cntlfreq (keep = cntl_idvar count rename = (count = cntl_count));
 run;
 proc sort data=__matches_freq0;
 by cntl_idvar;
 run;
 data __matches_freq;
 merge __matches_freq0
 __cntlfreq;
 by cntl_idvar;

 if count >= &match_ratio;
 run;
 proc datasets nolist;
 delete __matches0;
 run;
 quit;

 %let __dsid = %sysfunc(open(__matches_freq,i));
 %let __num = %sysfunc(attrn(&__dsid,nobs));
 %let __rc = %sysfunc(close(&__dsid));
 %do %while (&__num >= 1);
 proc sort data=__matches_freq;
 by count cntl_count rand_num pat_idvar;
 run;

 data __first_pat_idvar (keep = pat_idvar);
 set __matches_freq;
 by n;
 if first.n;
 run;

 proc sort data=__matches_freq;
 by pat_idvar count cntl_count rand_num;
 run;

 data __all_first_id;
 merge __matches_freq
 __first_pat_idvar (in=i);
 by pat_idvar;
 if i;
 num + 1;
 run;
 data __new_matched_pairs (keep = pat_idvar cntl_idvar pat_score cntl_score);
 set __all_first_id;

 label pat_idvar = "Patient ID, original variable name &pat_idvar"
 cntl_idvar = "Matched Control ID, original variable name &cntl_idvar"
 pat_score = "Patient Propensity Score, original var name &pat_psvar"
 cntl_score = "Matched Control Propensity Score, orig var &cntl_psvar"
 ;
 if num <= &match_ratio;
 run;

 proc sort data=__new_matched_pairs (keep = pat_idvar)
 out=__new_matched_pats nodupkey;
 by pat_idvar;
 run;
 data __match_remove_pat;
 merge __possible_matches
 __new_matched_pats (in=id);
 by pat_idvar;
 if ^id;
 run;

 proc sort data=__new_matched_pairs (keep = cntl_idvar) out=__remove_cont;
 by cntl_idvar;
 run;
 proc sort data=__match_remove_pat;
 by cntl_idvar;
 run;

 data __match_remove_cont;
 merge __match_remove_pat
 __remove_cont (in=id);
 by cntl_idvar;
 if ^id;
 run;
 proc sort data=__match_remove_cont out=__possible_matches;
 by pat_idvar;
 run;

 proc append base=__final_matched_pairs data=__new_matched_pairs;
 run;

 proc freq data=__possible_matches noprint;
 tables pat_idvar / out=__matchfreq (keep = pat_idvar count);
 run;

 data __matches_freq0;
 merge __possible_matches
 __matchfreq;
 by pat_idvar;
 run;

 proc freq data=__possible_matches noprint;
 tables cntl_idvar / out=__cntlfreq (keep = cntl_idvar count rename = (count = cntl_count));
 run;
 proc sort data=__matches_freq0;
 by cntl_idvar;
 run;
 data __matches_freq;
 merge __matches_freq0
 __cntlfreq;
 by cntl_idvar;

 if count >= &match_ratio;
 run;

 %let __dsid = %sysfunc(open(__matches_freq,i));
 %let __num = %sysfunc(attrn(&__dsid,nobs));
 %let __rc = %sysfunc(close(&__dsid));
 %end; /* of " %do %while (&__num >= 1); */


 proc sort data=__final_matched_pairs;
 by pat_idvar pat_score;
 run;
 data __patmatch_orig;
 set __patmatch (rename= (&pat_idvar = pat_idvar &pat_psvar = pat_score));
 run;
 proc sort data=__patmatch_orig;
 by pat_idvar;
 run;
 data &match_dsn (label = "Final Matched Pairs for Propensity Score Matching");
 merge __final_matched_pairs
 __patmatch_orig;
 by pat_idvar pat_score;
 run;
 /***************************************************/
 /* Delete all temporary datasets created by macro
 /***************************************************/
 proc datasets nolist;
 delete __contmatch __final_matched_pairs __matches_freq0 __matches_freq
 __match_pair0 __matchfreq __match_remove_cont __match_remove_pat
 __new_matched_pairs __patmatch __patmatch_orig __possible_matches
 __remove_cont __cntlfreq __first_pat_idvar __all_first_id
 __new_matched_pats;
 run;
 quit;
%mend psmatch_multi;
