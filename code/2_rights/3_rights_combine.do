
// Purpose: Combine water rights data from two source files, clean, and estimate diversions
// 	 (Follows and builds upon cleaning procedures specified by SWRCB)

clear all
pause on
set more off

// Set root and load pathfile
if "`c(os)'"=="Windows" {
	local ROOT "H:"
}
else {
	local ROOT "/bbkinghome/nhagerty"
}
qui do "`ROOT'/analysis/allo/do/allo_pathfile.do"


// Prepare dataset of 2014 reported diversions and SWRCB demand estimates (WRUDS spreadsheet)
use "$DATA_TEMP/waterrights_wruds.dta", clear
foreach var of varlist * {
	rename `var' w_`var'
}
rename w_appno appno
tempfile wruds
save `wruds'

// Start with full set of water rights and 2010-13 reported diversions (from eWRIMS/Exhibit WR-70)
use "$DATA_TEMP/waterrights_ewrims.dta"

// Merge in WRUDS data
merge 1:1 appno using `wruds', gen(mergeW)
drop if mergeW==2
order appno user facevalue netacres source_name latitude longitude inactive yearstart yearend, first

// Use diversion numbers from WRUDS dataset where available & different (it's been corrected by SWRCB)
foreach var of varlist ???_2010_m* ???_2011_m* ???_2012_m* ???_2013_m* {
	*bro appno user `var' w_`var' if mergeW==3 & `var'!=w_`var' & !missing(w_`var') & abs(`var'-w_`var')>.1
	replace `var'=w_`var' if mergeW==3 & `var'!=w_`var' & !missing(w_`var')
}
rename w_div_2014_m* div_2014_m*

// Keep only non-minor surface water rights (except for groundwater recordations, no others have reported diversions)
keep if regexm(wrtype,"Appropriative|Statement of Div")
drop wrtype


// 1. CORRECT OUTLIERS (likely errors in unit selection) (SWRCB did not separately do this)
// (I.e., high outliers. There are also likely low outliers, but I don't have a good way to detect them.)

// Initialize outlier factors
gen factorA_div_2010 = 1
gen factorA_div_2011 = 1
gen factorA_div_2012 = 1
gen factorA_div_2013 = 1
gen factorA_div_2014 = 1
gen factorA_use_2010 = 1
gen factorA_use_2011 = 1
gen factorA_use_2012 = 1
gen factorA_use_2013 = 1
gen factorA_use_2014 = 1

// Calculate annual totals
forvalues y=2010/2014 {
	egen div_`y'_tot = rowtotal(div_`y'_m*)
	replace div_`y'_tot=. if div_`y'_tot==0
}
forvalues y=2010/2013 {
	egen use_`y'_tot = rowtotal(use_`y'_m*)
	replace use_`y'_tot=. if use_`y'_tot==0
}
egen div_avg_tot = rowmean(div_20??_tot)
egen use_avg_tot = rowmean(use_20??_tot)

// Flag outliers
foreach var of varlist div_20* use_20* {
	gen ms`var' = round(`var') if `var'>0
}
foreach var of varlist div_20* use_20* {
	gen ln`var' = ln(ms`var')
}
egen sd_div = rowsd(msdiv_20*)
egen sd_use = rowsd(msuse_20*)
egen sd_lndiv = rowsd(lndiv_20*)
egen sd_lnuse = rowsd(lnuse_20*)
gen flag_div=0
gen flag_use=0
replace flag_use=1 if sd_lnuse>2 & sd_lnuse<. & (use_avg_tot-facevalue>100)
replace flag_use=2 if sd_lnuse>4 & sd_lnuse<. & (use_avg_tot-facevalue>100)
replace flag_div=1 if sd_lndiv>2 & sd_lndiv<. & (div_avg_tot-facevalue>100)
replace flag_div=2 if sd_lndiv>4 & sd_lndiv<. & (div_avg_tot-facevalue>100)
egen min_div_ann = rowmin(div_20??_tot) if flag_div>0
egen min_use_ann = rowmin(use_20??_tot) if flag_use>0
*browse user facevalue acres div_*_tot sd_lndiv merge demand* if flag>0

// Generate new diversion/use data, with outliers corrected (scaled down to smallest reported annual diversion)
forvalues y=2010/2014 {
	replace factorA_div_`y' = max(1,div_`y'_tot/min_div_ann) if flag_div>0 & min_div_ann>0 & div_`y'_tot/min_div_ann>100
	replace factorA_div_`y' = 0 if div_avg_tot>1000^3		// 1 obs: Louis Chacon
	forvalues m=1/12 {
		gen div2_`y'_m`m' = div_`y'_m`m'/factorA_div_`y'
	}
	egen div2_`y'_tot = rowtotal(div2_`y'_m*)
	replace div2_`y'_tot=. if div2_`y'_tot==0
}
forvalues y=2010/2013 {
	replace factorA_use_`y' = max(1,use_`y'_tot/min_use_ann) if flag_use>0 & min_use_ann>0 & use_`y'_tot/min_use_ann>100
	forvalues m=1/12 {
		gen use2_`y'_m`m' = use_`y'_m`m'/factorA_use_`y'
	}
	egen use2_`y'_tot = rowtotal(use2_`y'_m*)
	replace use2_`y'_tot=. if use2_`y'_tot==0
}
egen div2_avg_tot = rowmean(div2_20??_tot)
egen use2_avg_tot = rowmean(use2_20??_tot)
*browse user facevalue div_*_tot div2_*_tot factorA_* sd_lndiv if flag_div>0


// 2. CORRECT POWER- & AQUACULTURE-ONLY DIVERSIONS (as per SWRCB)

// Identify power-only diversions
egen defnotpower = rowtotal(benuse1-benuse5 benuse7-benuse15 benuse18-benuse19)
		// i.e., all but power (16), recreational (17), and fish (6)
rename w_power power
replace power = (benuse16==1 & defnotpower==0) if mergeW==1
rename w_div_factor div_factor
replace div_factor="NONE" if mergeW==1 & power==1 & anystorage==0
replace div_factor="NET" if mergeW==1 & power==1 & anystorage==1

// Identify aquaculture-only diversions
egen notaquaculture = rowtotal(benuse1 benuse3-benuse19)	// i.e., all but aquaculture (2)
gen aquaculture = (benuse2==1 & notaquaculture==0) if mergeW==1
replace div_factor="NONE" if mergeW==1 & aquaculture==1

// Calculate net use (diversion minus use)
forvalues y=2010/2013 {
	forvalues m=1/12 {
		gen net2_`y'_m`m' = max(0,div2_`y'_m`m'-use2_`y'_m`m') if div_factor=="NET"
	}
	egen net2_`y'_tot = rowtotal(net2_`y'_m*)
	replace net2_`y'_tot=. if div2_`y'_tot==. | use2_`y'_tot==.
}
egen net2_avg_tot = rowmean(net2_20??_tot)
gsort -net2_avg_tot

// Generate new diversion data, corrected for power/aquaculture, as well as SWRCB-determined duplicates
forvalues y=2010/2013 {
	forvalues m=1/12 {
		gen div3_`y'_m`m' = div2_`y'_m`m'
		replace div3_`y'_m`m' = net2_`y'_m`m' if div_factor=="NET"
		replace div3_`y'_m`m' = 0 			  if div_factor=="NONE"
	}
	egen div3_`y'_tot = rowtotal(div3_`y'_m*)
	replace div3_`y'_tot=. if div3_`y'_tot==0 & net2_`y'_tot==.
}
forvalues y=2014/2014 {
	forvalues m=1/12 {
		gen div3_`y'_m`m' = div2_`y'_m`m'
	}
	gen div3_`y'_tot = div2_`y'_tot
}
egen div3_avg_tot = rowmean(div3_20??_tot)


// 3. CORRECT OVER-REPORTING
// Mostly following SWRCB, but year-wise rather than averages, and with more checks

// Initialize over-reporting factors
gen factorB_2010 = 1
gen factorB_2011 = 1
gen factorB_2012 = 1
gen factorB_2013 = 1
gen factorB_2014 = 1

// Post-1914, reporting facevalue: if diversion > face value, limit to face value
replace factorB_2010 = max(1,div3_2010_tot/facevalue) if pre1914==0 & riparian==0 & facevalue>0 & facevalue<.
replace factorB_2011 = max(1,div3_2011_tot/facevalue) if pre1914==0 & riparian==0 & facevalue>0 & facevalue<.
replace factorB_2012 = max(1,div3_2012_tot/facevalue) if pre1914==0 & riparian==0 & facevalue>0 & facevalue<.
replace factorB_2013 = max(1,div3_2013_tot/facevalue) if pre1914==0 & riparian==0 & facevalue>0 & facevalue<.
replace factorB_2014 = max(1,div3_2014_tot/facevalue) if pre1914==0 & riparian==0 & facevalue>0 & facevalue<.

// Riparian/Pre-1914, reporting irrigated acres: if diversion > 8 af/acre, limit to this level
replace facevalue=. if (riparian==1|pre1914==1) & facevalue==0
replace factorB_2010 = max(1,div3_2010_tot/(netacres*8)) if (pre1914==1|riparian==1) & benuse11==1 & netacres>0 & netacres<.
replace factorB_2011 = max(1,div3_2011_tot/(netacres*8)) if (pre1914==1|riparian==1) & benuse11==1 & netacres>0 & netacres<.
replace factorB_2012 = max(1,div3_2012_tot/(netacres*8)) if (pre1914==1|riparian==1) & benuse11==1 & netacres>0 & netacres<.
replace factorB_2013 = max(1,div3_2013_tot/(netacres*8)) if (pre1914==1|riparian==1) & benuse11==1 & netacres>0 & netacres<.
replace factorB_2014 = max(1,div3_2014_tot/(netacres*8)) if (pre1914==1|riparian==1) & benuse11==1 & netacres>0 & netacres<.
*browse user facevalue netacres div3_*_tot factorB_* if merge==2 & (pre1914==1|riparian==1) & netacres>0 & netacres<.

// Post-1914, reporting acres but not facevalue: acres-based correction as above (but only egregious ones)
count if pre1914==0 & riparian==0 & (facevalue==0|facevalue==.) & benuse11==1 & netacres>0 & netacres<.
replace factorB_2010 = max(1,div3_2010_tot/(netacres*8)) if div3_2010_tot/(netacres*8)>10 & pre1914==0 & riparian==0 & (facevalue==0|facevalue==.) & benuse11==1 & netacres>0 & netacres<.
replace factorB_2011 = max(1,div3_2011_tot/(netacres*8)) if div3_2011_tot/(netacres*8)>10 & pre1914==0 & riparian==0 & (facevalue==0|facevalue==.) & benuse11==1 & netacres>0 & netacres<.
replace factorB_2012 = max(1,div3_2012_tot/(netacres*8)) if div3_2012_tot/(netacres*8)>10 & pre1914==0 & riparian==0 & (facevalue==0|facevalue==.) & benuse11==1 & netacres>0 & netacres<.
replace factorB_2013 = max(1,div3_2013_tot/(netacres*8)) if div3_2013_tot/(netacres*8)>10 & pre1914==0 & riparian==0 & (facevalue==0|facevalue==.) & benuse11==1 & netacres>0 & netacres<.
replace factorB_2014 = max(1,div3_2014_tot/(netacres*8)) if div3_2013_tot/(netacres*8)>10 & pre1914==0 & riparian==0 & (facevalue==0|facevalue==.) & benuse11==1 & netacres>0 & netacres<.
*gen factorB_any = (factorB_2010>1|factorB_2011>1|factorB_2012>1|factorB_2013>1|factorB_2014>1) & pre1914==0 & riparian==0 & (facevalue==0|facevalue==.) & benuse11==1 & netacres>0 & netacres<.
*tab factorB_any
*browse user facevalue acres div3_*_tot factorB_* * if factorB_any==1

// Post-1914, not reporting facevalue nor acres: everything looks OK
gsort -div3_avg_tot
*browse user facevalue div3_*_tot * if riparian==0 & pre1914==0 & facevalue==0 & netacres==0 & div3_avg_tot<.

// Riparian/Pre-1914, not reporting irrigated acres:
*browse user facevalue netacres div3_*_tot factorB_* power mergeE flag_div flag_use sd_lndiv if netacres==0 & (riparian==1|pre1914==1) & div3_avg_tot>1000 & div3_avg_tot<. & power!=1 & aquaculture!=1
* not an institution
*browse user facevalue netacres div3_*_tot factorB_* power mergeE flag_div flag_use sd_lndiv if !regexm(user,"DISTRICT|COMPANY|BUREAU|CITY|DITCH|COMMITTEE|WATER CO|CORP|AUTHORITY|DEPARTMENT|ASSOCIATION|INDUSTRIES|AUTHORITY|NATL| CO|AGENCY|CLUB|ASSOC|US ") & netacres==0 & (riparian==1|pre1914==1) & div3_avg_tot>1000 & div3_avg_tot<. & power!=1 & aquaculture!=1
* over 100k af
*browse user facevalue netacres div3_*_tot factorB_* * power mergeE flag_div flag_use sd_lndiv if !regexm(user,"DISTRICT|COMPANY|BUREAU|CITY|DITCH|COMMITTEE|WATER CO|CORP|AUTHORITY|DEPARTMENT|ASSOCIATION|INDUSTRIES|AUTHORITY|NATL| CO|AGENCY|CLUB|ASSOC|US ") & netacres==0 & (riparian==1|pre1914==1) & div3_avg_tot>100000 & div3_avg_tot<. & power!=1 & aquaculture!=1
* drop this -- tough to believe (1 obs)
drop if !regexm(user,"DISTRICT|COMPANY|BUREAU|CITY|DITCH|COMMITTEE|WATER CO|CORP|AUTHORITY|DEPARTMENT|ASSOCIATION|INDUSTRIES|AUTHORITY|NATL| CO|AGENCY|CLUB|ASSOC|US ") & netacres==0 & (riparian==1|pre1914==1) & div3_avg_tot>100000 & div3_avg_tot<. & power!=1 & aquaculture!=1

// Generate new diversion data, corrected for over-reporting
forvalues y=2010/2014 {
	forvalues m=1/12 {
		gen div4_`y'_m`m' = div3_`y'_m`m'/factorB_`y'
	}
}


// 4. FINISH UP

// Calculate yearly totals
forvalues y=2010/2014 {
	egen div4_`y'_tot = rowtotal(div4_`y'_m*)
	egen div4_`y'_data = rownonmiss(div4_`y'_m*)
	replace div4_`y'_tot=. if div4_`y'_data==0
}
egen div4_avg_tot = rowmean(div4_20??_tot)

// Calculate monthly averages
forvalues m=1/12 {
	egen div4_avg_m`m' = rowmean(div4_*_m`m')
}
egen div4_avg_tot2 = rowtotal(div4_avg_m*)
egen div4_avg_data = rownonmiss(div4_avg_m*)
replace div4_avg_tot2=. if div4_avg_data==0
sum div4_avg_tot*

// Investigate differences between my processing and SWRCB's
egen demand_tot = rowtotal(w_demand_m*)
gen diff = abs(div4_avg_tot2-demand_tot)
gen pctdiff = abs((div4_avg_tot2-demand_tot)/div4_avg_tot2)
*browse user div4_avg_tot2 demand_tot pctdiff diff if merge==3 & w_responded!=1 & !(demand_tot==0 & div4_avg_tot2==0)
count if merge==3 & w_responded!=1 & !(demand_tot==0 & div4_avg_tot2==0)	& pctdiff>.1 & diff>1000
*browse user div4_avg_tot2 demand_tot pctdiff diff if merge==3 & w_responded!=1 & !(demand_tot==0 & div4_avg_tot2==0)	& pctdiff>.1 & diff>1000 & div4_avg_tot2<.
* 42 obs with large differences, appears to be driven by my outlier procedure.
* I.e., otherwise I am replicating SWRCB's calculations correctly.

// Review list of largest diverters
gsort -div4_avg_tot
*browse appno user div4_avg_tot *

// Clean up
keep appno user facevalue source_name latitude longitude 	///
	 inactive yearstart yearend riparian pre1914 	///
	 benuse* div4_*_tot div4_avg_m*
rename div4_avg_tot avgdiversion
forvalues y=2010/2014 {
	rename div4_`y'_tot diversion_`y'
	label variable diversion_`y' "Diversions reported to SWRCB, `y' total"
}
forvalues m=1/12 {
	rename div4_avg_m`m' avgdiversion_m`m'
}
order appno user avgdiversion avgdiversion_m* source_name latitude longitude	///
	  yearstart yearend inactive riparian pre1914 facevalue benuse*

// Label variables
label variable appno "SWRCB application ID"
label variable avgdiversion "Diversions based on water rights, annual mean (2010-14)"
label variable avgdiversion_m1 "Diversions based on water rights, January mean (2010-14)"
label variable avgdiversion_m2 "Diversions based on water rights, February mean (2010-14)"
label variable avgdiversion_m3 "Diversions based on water rights, March mean (2010-14)"
label variable avgdiversion_m4 "Diversions based on water rights, April mean (2010-14)"
label variable avgdiversion_m5 "Diversions based on water rights, May mean (2010-14)"
label variable avgdiversion_m6 "Diversions based on water rights, June mean (2010-14)"
label variable avgdiversion_m7 "Diversions based on water rights, July mean (2010-14)"
label variable avgdiversion_m8 "Diversions based on water rights, August mean (2010-14)"
label variable avgdiversion_m9 "Diversions based on water rights, September mean (2010-14)"
label variable avgdiversion_m10 "Diversions based on water rights, October mean (2010-14)"
label variable avgdiversion_m11 "Diversions based on water rights, November mean (2010-14)"
label variable avgdiversion_m12 "Diversions based on water rights, December mean (2010-14)"
label variable benuse0 "Beneficial use: (blank)"
label variable benuse1 "Beneficial use: Aesthetic"
label variable benuse2 "Beneficial use: Aquaculture"
label variable benuse3 "Beneficial use: Domestic"
label variable benuse4 "Beneficial use: Dust Control"
label variable benuse5 "Beneficial use: Fire Protection"
label variable benuse6 "Beneficial use: Fish and Wildlife Preservation and Enhancement"
label variable benuse7 "Beneficial use: Frost Protection"
label variable benuse8 "Beneficial use: Heat Control"
label variable benuse9 "Beneficial use: Incidental Power"
label variable benuse10 "Beneficial use: Industrial"
label variable benuse11 "Beneficial use: Irrigation"
label variable benuse12 "Beneficial use: Milling"
label variable benuse13 "Beneficial use: Mining"
label variable benuse14 "Beneficial use: Municipal"
label variable benuse15 "Beneficial use: Other"
label variable benuse16 "Beneficial use: Power"
label variable benuse17 "Beneficial use: Recreational"
label variable benuse18 "Beneficial use: Snow Making"
label variable benuse19 "Beneficial use: Stockwatering"
label variable yearstart "Priority year (sometimes estimated)"
label variable yearend "Year right ceased"
label variable inactive "Right has ceased"
label variable source_name "Source name"
label variable latitude "Latitude"
label variable longitude "Longitude"

// Save
isid appno
gsort -avgdiversion
compress
save "$DATA_TEMP/waterrights_diversions.dta", replace
