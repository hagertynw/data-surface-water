
// Purpose: Load and clean SWRCB's 2015 Informational Order Demand Dataset
//	(Contains reported diversions in 2014 for select water rights.)
//	(Also contains annual diversions for all rights in the Central Valley as estimated by SWRCB 
//	 after following certain quality control procedures. I use this to verify that my data cleaning 
//	 procedures for the entire state are able to accurately reproduce SWRCB's procedures.)
//  Downloaded from: https://www.waterboards.ca.gov/waterrights/water_issues/programs/drought/analysis/


// Import data
import excel using "$DATA_RIGHTS/drought_analysis/info_order_demand/WRUDS 2015-06-15.xlsx", 	///
	firstrow case(lower) clear

// Label variables
label var app_id 			"Rights application ID"
label var primary_owner 	"Owner name"
label var net_acres 		"Net irrigated acreage (riparian/pre-1914)"
label var face_value		"Face value (post-1914) (acre-feet)"
label var area				"Evaluation area"
label var hydrologic_unit	"Hydrologic unit of POD (or majority of PODs)"
label var add_hu			"Hydrologic units of additional PODs"
label var huc_12			"HUC12 of (selected) POD"
label var add_huc_12		"HUC12 of additional PODs"
label var wr_type			"Type of right"
label var status_type		"Status of right"
label var riparian			"Riparian claim"
label var pre_1914			"Pre-1914 claim"
label var year_first_use	"Year of first use (riparian/pre-1914)"
label var priority_date		"Priority date (post-1914)"
label var pre_14_priority	"Priority date (pre-1914)"
label var power_only		"Use for power only"
label var info_order		"Subject to Order 2015-0002-DWR"
label var responded			"Responded to order & submitted 2014/15 diversion information"
label var projects			"USBR/DWR rights"
label var demand_jan		"Demand, per DWR (acre-feet/month)"
label var demand_feb		"Demand, per DWR (acre-feet/month)"
label var demand_mar		"Demand, per DWR (acre-feet/month)"
label var demand_apr		"Demand, per DWR (acre-feet/month)"
label var demand_may		"Demand, per DWR (acre-feet/month)"
label var demand_jun		"Demand, per DWR (acre-feet/month)"
label var demand_jul		"Demand, per DWR (acre-feet/month)"
label var demand_aug		"Demand, per DWR (acre-feet/month)"
label var demand_sep		"Demand, per DWR (acre-feet/month)"
label var demand_oct		"Demand, per DWR (acre-feet/month)"
label var demand_nov		"Demand, per DWR (acre-feet/month)"
label var demand_dec		"Demand, per DWR (acre-feet/month)"
label var demand_total		"Demand, per DWR (acre-feet/year)"

// Rename variables
rename app_id			appno
rename primary_owner	user
rename net_acres 		acres
rename face_value		quantity
rename area				evalarea
rename hydrologic_unit	hu_name
rename add_hu			hu_name_others
rename huc_12			huc12
rename add_huc_12		huc12_others
rename wr_type			wrtype
rename status_type		status
rename riparian			riparian
rename pre_1914			pre1914
rename year_first_use	firstyear
rename priority_date	priority_post1914
rename pre_14_priority	priority_pre1914
rename power_only		power
rename projects			projects
rename demand_jan		demand_m1
rename demand_feb		demand_m2
rename demand_mar		demand_m3
rename demand_apr		demand_m4
rename demand_may		demand_m5
rename demand_jun		demand_m6
rename demand_jul		demand_m7
rename demand_aug		demand_m8
rename demand_sep		demand_m9
rename demand_oct		demand_m10
rename demand_nov		demand_m11
rename demand_dec		demand_m12
rename demand_total		demand
foreach type in div use {
	forvalues y=2010/2013 {
		local mm=1
		foreach var of varlist jan_`type'_`y'-dec_`type'_`y' {
			rename `var' `type'_`y'_m`mm'
			local mm = `mm'+1
		}
	}
}

// Trim blank space from strings
replace hu_name = stritrim(hu_name)
replace user = strtrim(user)
replace user = stritrim(user)

// Recode binary variables
replace riparian="1" if riparian=="Y"
replace riparian="0" if riparian==""
replace pre1914="1"	 if pre1914=="Y"
replace pre1914="0"  if pre1914==""
replace power="1" if power=="Y"
replace power="0" if power==""|power=="N"
replace info_order="1" if info_order=="Y"
replace info_order="0" if info_order==""
replace responded="1" if responded=="Y"
replace responded="0" if responded==""
destring riparian pre1914 power info_order responded, replace

// Construct beneficial uses
gen use_aesthetic 	= regexm(beneficial_use,"Aesthetic")
gen use_aquaculture	= regexm(beneficial_use,"Aquaculture")
gen use_domestic 	= regexm(beneficial_use,"Domestic")
gen use_dustcontrol = regexm(beneficial_use,"Dust Control")
gen use_fireprev 	= regexm(beneficial_use,"Fire Protection")
gen use_fish		= regexm(beneficial_use,"Fish and Wildlife Preservation and Enhancement")
gen use_frostprev 	= regexm(beneficial_use,"Frost Protection")
gen use_heatcontrol	= regexm(beneficial_use,"Heat Control")
gen use_incidental 	= regexm(beneficial_use,"Incidental Power")
gen use_industrial 	= regexm(beneficial_use,"Industrial")
gen use_irrigation 	= regexm(beneficial_use,"Irrigation")
gen use_milling 	= regexm(beneficial_use,"Milling")
gen use_mining 		= regexm(beneficial_use,"Mining")
gen use_municipal 	= regexm(beneficial_use,"Municipal")
gen use_other 		= regexm(beneficial_use,"Other")
gen use_power 		= regexm(beneficial_use,"Power")
gen use_recreation 	= regexm(beneficial_use,"Recreational")
gen use_snowmaking 	= regexm(beneficial_use,"Snow Making")
gen use_stock 		= regexm(beneficial_use,"Stockwatering")

// Tidy up
drop include
drop demand demand_aprsep avg_div_??? avg_div_total ave_use_???
foreach var of varlist div_2010_m1-demand_m12 {
	replace `var'=round(`var',.01)
}

// Reconstruct reported diversions for 2014 (responses to Informational Order 2015-0002-DWR)
forvalues m=1/12 {
	gen div_rip_2014_m`m' = demand_m`m' if info_order==1 & responded==1 & pre1914==0 & riparian==1
	replace demand_m`m'=. 				if info_order==1 & responded==1 & pre1914==0 & riparian==1
}
forvalues m=1/12 {
	gen div_pre_2014_m`m' = demand_m`m' if info_order==1 & responded==1 & pre1914==1 & riparian==0
	replace demand_m`m'=. 				if info_order==1 & responded==1 & pre1914==1 & riparian==0
}

// Consolidate observations arising from multiple responses to the informational order
sort info_order responded appno pre1914 riparian
by info_order responded appno: replace pre1914=1 if info_order==1 & responded==1 & pre1914[_n+1]==1
by info_order responded appno: replace riparian=1 if info_order==1 & responded==1 & riparian[_n-1]==1
foreach var of varlist div_rip_2014_m* {
	by info_order responded appno: replace `var'=`var'[_n-1] if info_order==1 & responded==1 & `var'==. & `var'[_n-1]!=.
}
foreach var of varlist div_pre_2014_m* priority_pre1914 {
	by info_order responded appno: replace `var'=`var'[_n+1] if info_order==1 & responded==1 & `var'==. & `var'[_n+1]!=.
}
foreach var of varlist notes {
	by info_order responded appno: replace `var'=`var'[_n+1] if info_order==1 & responded==1 & `var'=="" & `var'[_n+1]!=""
}
duplicates drop

// Deal with other duplicates
drop if user=="GARY M GRAHAM" & firstyear==1800
egen div_pre_2014_tot = rowtotal(div_pre_2014_m*) if appno=="S004683"
gsort appno -div_pre_2014_tot
forvalues m=1/12 {
	by appno: egen div_pre_2014_m`m'_tot = total(div_pre_2014_m`m') if appno=="S004683"
	replace div_pre_2014_m`m' = div_pre_2014_m`m'_tot if appno=="S004683"
}
drop div_pre_2014_m*_tot
by appno: drop if _n>1 & appno=="S004683"
drop div_pre_2014_tot

// Sum 2014 responses across riparian and pre-1914 water right types
forvalues m=1/12 {
	egen div_2014_m`m' = rowtotal(div_rip_2014_m`m' div_pre_2014_m`m')
	replace div_2014_m`m'=. if div_rip_2014_m`m'==. & div_pre_2014_m`m'==.
}

// Save
keep appno demand_m* div_2014_m* power div_factor responded acres div_2010_m1-use_2013_m12
isid appno
sort appno
compress
save "$DATA_TEMP/waterrights_wruds.dta", replace

