
// Purpose: Combine the four datasets

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


// Start with CVP data
use "$PREPPED/allocations_source_cvp.dta", clear

// Merge in SWP data
merge 1:1 std_name year using "$PREPPED/allocations_source_swp.dta", gen(mergeswp) update

// Merge in Lower Colorado data
merge 1:1 std_name year using "$PREPPED/allocations_source_loco.dta", gen(mergeloco) update

// Keep only years after 1980
local firstyear = 1981
keep if year>=`firstyear'

// Make a balanced panel of average diversions to match project data
qui sum year
local lastyear = r(max)
disp `=`lastyear'-`firstyear'+1'
preserve
	clear
	set obs `=`lastyear'-`firstyear'+1'
	gen year = `firstyear' - 1 + _n
	cross using "$PREPPED/allocations_source_rights_means.dta"
	tempfile rights_means
	save `rights_means'
restore

// Merge in water rights (average diversions)
merge 1:1 std_name year using `rights_means', gen(mergerights1) update

// Merge in water rights (yearly diversions)
merge 1:1 std_name year using "$PREPPED/allocations_source_rights_yearly.dta", gen(mergerights2) update

// Expand to create a balanced panel
count
fillin std_name year
count

// Fill in zeroes to clarify data. After this point:
//	* Zeros: no deliveries were received in that year (known zero) 
//	* Missing values: no data was available for that year (unknown)
rename cvp_deliveries_cy cvp_deliveries
foreach proj in cvp swp loco {
	qui sum year if !missing(`proj'_deliveries)
	local `proj'_yearfirst r(min)
	local `proj'_yearlast r(max)
	foreach var of varlist `proj'_* {
		replace `var'=0 if missing(`var') & inrange(year,``proj'_yearfirst',``proj'_yearlast')
	}
}
rename cvp_deliveries cvp_deliveries_cy
foreach var of varlist rights_avgdivert* {
	replace `var'=0 if missing(`var')
}

// Correct duplicate reporting for CVP settlement/exchange contractors
//	* These users hold water rights but receive their water as CVP deliveries, so the same water
//	   likely appears in the data twice: as water rights diversions and as CVP deliveries.)
//  * To correct this, I subtract CVP maximum entitlements from average rights diversions.
//  * An alternative would be to subtract CVP actual deliveries. But we don't know whether rights-
//	   holders are reporting diversions net of cutbacks or not. To err on the side of not 
//	   introducing more noise, I assume none are cutbacks.
//  * This may mean I am underestimating rights for some users that hold rights both converted
//	   under USBR settlement/exchange agreements and not (still directly diverting).
//  * I also subtract CVP actual deliveries from year-specific reported rights diversions.
*bro year std_name cvp* rights*diver* if cvp_maxvol_base>0 & cvp_maxvol_base<. & rights_avgdivert>0 & rights_avgdivert<.
gen corr_rights_avgdivert 		 = rights_avgdivert
gen corr_rights_avgdivert_ag 	 = rights_avgdivert_ag
gen corr_rights_diversion_ag 	 = rights_diversion_ag
replace corr_rights_avgdivert    = max(0, rights_avgdivert - cvp_maxvol_base) 	///
	if cvp_maxvol_base>0 & !missing(cvp_maxvol_base) & rights_avgdivert>0 & !missing(rights_avgdivert)
replace corr_rights_avgdivert_ag = max(0, rights_avgdivert_ag - cvp_maxvol_base) 	///
	if cvp_maxvol_base>0 & !missing(cvp_maxvol_base) & rights_avgdivert_ag>0 & !missing(rights_avgdivert_ag)
replace corr_rights_diversion_ag = max(0, rights_diversion_ag - cvp_deliveries_cy_ag) 	///
	if cvp_deliveries_cy_ag>0 & !missing(cvp_deliveries_cy_ag) & rights_diversion_ag>0 & !missing(rights_diversion_ag)
gen corr_rights_avgdivert_mi 	 = corr_rights_avgdivert - corr_rights_avgdivert_ag
gen corr_rights_diversion_mi 	 = corr_rights_diversion - corr_rights_diversion_ag
foreach var of varlist rights_avgdivert* rights_diversion* {
	replace `var' = corr_`var'
	drop corr_`var'
}

// Construct sums across water sources
* deliveries & diversions, including CVP deliveries for the calendar year
gen vol_deliv_cy    = cvp_deliveries_cy    + swp_deliveries    + loco_deliveries    + rights_avgdivert
gen vol_deliv_cy_ag = cvp_deliveries_cy_ag + swp_deliveries_ag + loco_deliveries_ag + rights_avgdivert_ag
gen vol_deliv_cy_mi = cvp_deliveries_cy_mi + swp_deliveries_mi + loco_deliveries_mi + rights_avgdivert_mi
* deliveries & diversions, including CVP deliveries for the water year
gen vol_deliv_wy    = cvp_deliveries_wy    + swp_deliveries    + loco_deliveries    + rights_avgdivert
gen vol_deliv_wy_ag = cvp_deliveries_wy_ag + swp_deliveries_ag + loco_deliveries_ag + rights_avgdivert_ag
gen vol_deliv_wy_mi = cvp_deliveries_wy_mi + swp_deliveries_mi + loco_deliveries_mi + rights_avgdivert_mi
* maximum entitlements
gen vol_maximum    = cvp_maxvol    + swp_basemax    + loco_maxvol    + rights_avgdivert
gen vol_maximum_ag = cvp_maxvol_ag + swp_basemax_ag + loco_maxvol_ag + rights_avgdivert_ag
gen vol_maximum_mi = cvp_maxvol_mi + swp_basemax_mi + loco_maxvol_mi + rights_avgdivert_mi
* overall allocation percentage (average of allocation percentages weighted by maximum entitlement)
foreach s in ag mi {
	gen allo_cvp_`s' = cvp_maxvol_`s' * cvp_pctallo_`s'
	gen allo_swp_`s' = swp_basemax_`s' * swp_pctallo_`s'
	gen allo_tot_`s' = allo_cvp_`s' + allo_swp_`s' + loco_maxvol_`s' + rights_avgdivert_`s'
	gen pct_allocation_`s' = allo_tot_`s' / vol_maximum_`s'
}
egen allo_tot = rowtotal(allo_tot_??), missing
gen pct_allocation = allo_tot/vol_maximum
drop allo_*
foreach var of varlist *pct*allo* {
	assert inrange(`var',0,1) if !missing(`var')
}

// Drop false levels of precision
foreach var of varlist vol_* {
	replace `var' = round(`var',0.1)
}

// Clean up
order year std_name vol_deliv* vol_maximum* pct_allocation pct_allocation_*	///
		swp_deliveries* swp_maxvol* swp_basemax* swp_pctallo*	///
		cvp_deliveries* cvp_maxvol* cvp_pctallo* loco_maxvol* loco_deliveries* rights_*
drop cvp_maxvol_base cvp_maxvol_project
drop parent merge* _fillin

// Save
compress
save "$PREPPED/allocations_all.dta", replace

