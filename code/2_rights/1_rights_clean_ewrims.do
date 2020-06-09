
// Purpose: Load and clean SWRCB's eWRIMS database from 2015
//  (Contains records of all water rights in the state and reported diversions in 2010-13)
//	Downloaded from: http://www.waterboards.ca.gov/waterrights/water_issues/programs/hearings/byron_bethany/docs/exhibits/pt/wr70.csv

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


// Load raw data
import delimited using "$DATA_RIGHTS/ewrims/wr70_corrected.csv", stringcols(4) clear

// Drop variables not needed
drop pod_nbr dd_beg_* dd_end_* store_beg_* store_end_*

// Establish whether right has any storage
gen storage = regexm(diversion_type,"Storage")
bys wr_water_right_id: egen anystorage = max(storage)
drop storage
order anystorage, before(diversion_type)

// Establish unique ID
duplicates drop
sort wr_water_right_id pod_id beneficial_use
*duplicates report wr_water_right_id pod_id beneficial_use
duplicates tag wr_water_right_id pod_id beneficial_use, gen(dups)
*bro wr_water_right_id pod_id source_name beneficial_use quantity diversion_amount diversion_storage_amount direct_diversion_amount storage_amount acres gross_acres if dups
* when there are duplicate records at this level, take largest value
gsort wr_water_right_id pod_id beneficial_use -direct_diversion_amount
by wr_water_right_id pod_id beneficial_use: replace direct_diversion_amount=direct_diversion_amount[1] if dups>0 & _n>1
gsort wr_water_right_id pod_id beneficial_use -storage_amount
by wr_water_right_id pod_id beneficial_use: replace storage_amount=storage_amount[1] if dups>0 & _n>1
gsort wr_water_right_id pod_id beneficial_use -net_acres
by wr_water_right_id pod_id beneficial_use: replace net_acres=net_acres[1] if dups>0 & _n>1
gsort wr_water_right_id pod_id beneficial_use -gross_acres
by wr_water_right_id pod_id beneficial_use: replace gross_acres=gross_acres[1] if dups>0 & _n>1
drop dups
duplicates drop
egen useid = group(beneficial_use), missing
	replace useid = useid-1
isid wr_water_right_id pod_id useid

// Make acreage unique within right X pod
replace net_acres=. if beneficial_use!="Irrigation"
replace gross_acres=. if beneficial_use!="Irrigation"
gsort wr_water_right_id pod_id -net_acres
by wr_water_right_id pod_id: replace net_acres=net_acres[1] if net_acres==.
gsort wr_water_right_id pod_id -gross_acres
by wr_water_right_id pod_id: replace gross_acres=gross_acres[1] if gross_acres==.

// Reshape to right X pod
sort wr_water_right_id pod_id useid
forvalues u=0/19 {
	gen use`u'_0 = (useid==`u')
	by wr_water_right_id pod_id: egen use`u' = total(use`u'_0)
}
drop use*_0 beneficial_use beneficial_use_list useid
drop direct_diversion_amount direct_diversion_rate_units storage_amount storage_amount_units_1
duplicates drop
isid wr_water_right_id pod_id
count

// Organize
rename application_number	appno
rename primary_owner		user
rename net_acres			netacres
rename gross_acres			grossacres
rename face_value_amount	facevalue
rename huc_12				huc12
rename wr_type				wrtype
rename status_type			status
rename pre_1914				pre1914
rename year_first_use		firstyear
label var appno 			"Rights application ID"
label var user 				"Owner name"
label var netacres	 		"Net irrigated acreage (riparian/pre-1914)"
label var grossacres	 	"Gross irrigated acreage (riparian/pre-1914)"
label var facevalue			"Face value (post-1914) (acre-feet/year)"
label var wrtype			"Type of right"
label var status			"Status of right"
label var status_date		"Date of status of right"
label var riparian			"Riparian claim"
label var pre1914			"Pre-1914 claim"
label var firstyear			"Year of first use (riparian/pre-1914)"

// Clean
replace user = strtrim(user)
replace user = stritrim(user)
replace user = upper(user)
replace appno = strtrim(appno)
replace riparian="1" if riparian=="Y"
replace riparian="0" if riparian==""
replace pre1914="1"	 if pre1914=="Y"
replace pre1914="0"  if pre1914==""
destring riparian pre1914, replace
replace facevalue=. if (riparian==1|pre1914==1) & facevalue==0
replace firstyear=. if firstyear<1500

// Convert dates
foreach var of varlist status_date permit_original_issue_date license_original_issue_date {
	gen date_`var' = date(`var',"MDY")
	gen time_`var' = clock(`var',"MDYhm")
	replace date_`var' = dofc(time_`var') if date_`var'==. & time_`var'<.
	drop time_`var'
	format %td date_`var'
	assert date_`var'!=. if `var'!=""
	assert year(date_`var')>=1500 & year(date_`var')<=2020 if date_`var'<.
	order date_`var', before(`var')
	drop `var'
	rename date_`var' `var'
}

// Drop PODs that are not active
drop if regexm(pod_status,"Canceled|Inactive|Removed|Revoked")
drop pod_status

// Collapse rights to one POD, as per SWRCB methodology, but choosing the POD a bit more rationally
* tag duplicates
duplicates tag 	wr_water_right_id, gen(dups4)
duplicates tag 	wr_water_right_id watershed, gen(dups3)
duplicates tag 	wr_water_right_id watershed source_name, gen(dups2)
duplicates tag 	wr_water_right_id watershed source_name huc12, gen(dups1)
* collapse to unique right X watershed X source_name X HUC12 (keep POD with earliest number within HUC12)
gsort 			wr_water_right_id watershed source_name huc12 -dups1 pod_id
 *browse 		wr_water_right_id watershed source_name huc12 pod_id dups* if dups1>=1
by 				wr_water_right_id watershed source_name huc12: keep if _n==1
* collapse to unique right X watershed X source_name (keep HUC12 with most PODs within source)
gsort 			wr_water_right_id watershed source_name -dups2 -dups1 pod_id
 *browse 		wr_water_right_id watershed source_name huc12 pod_id dups* if dups2>=1
by 				wr_water_right_id watershed source_name: keep if _n==1
* collapse to unique right X watershed (keep source with most PODs within watershed)
gsort 			wr_water_right_id watershed -dups3 -dups2 -dups1 pod_id
 *browse 		wr_water_right_id watershed source_name huc12 pod_id dups* if dups3>=1
by 				wr_water_right_id watershed: keep if _n==1
* collapse to unique right (keep watershed with most PODs within right)
gsort 			wr_water_right_id -dups4 -dups3 -dups2 -dups1 pod_id
 *browse 			wr_water_right_id watershed source_name huc12 pod_id dups* if dups4>=1
by 				wr_water_right_id: keep if _n==1
* verify unique right
isid wr_water_right_id
drop dups4 dups3 dups2 dups1

// Construct year right began
gen yearstart = firstyear
replace yearstart = year(permit_original_issue_date) if yearstart==.
replace yearstart = year(license_original_issue_date) if yearstart==.
replace yearstart = year(status_date) if yearstart==.

// Construct year right ended
gen inactive = regexm(status,"Cancelled|Closed|Inactive|Rejected|Revoked")
gen yearend = .
replace yearend = year(status_date) if inactive==1

// Rename diversion & use variables
local mm=1
foreach var of varlist jan_diversion-dec_diversion {
	rename `var' div_2010_m`mm'
	local mm = `mm'+1
}
local mm=1
foreach var of varlist jan_diversion_1-dec_diversion_1 {
	rename `var' div_2011_m`mm'
	local mm = `mm'+1
}
local mm=1
foreach var of varlist jan_diversion_2-dec_diversion_2 {
	rename `var' div_2012_m`mm'
	local mm = `mm'+1
}
local mm=1
foreach var of varlist jan_diversion_3-dec_diversion_3 {
	rename `var' div_2013_m`mm'
	local mm = `mm'+1
}
local mm=1
foreach var of varlist jan_use-dec_use {
	rename `var' use_2010_m`mm'
	local mm = `mm'+1
}
local mm=1
foreach var of varlist jan_use_1-dec_use_1 {
	rename `var' use_2011_m`mm'
	local mm = `mm'+1
}
local mm=1
foreach var of varlist jan_use_2-dec_use_2 {
	rename `var' use_2012_m`mm'
	local mm = `mm'+1
}
local mm=1
foreach var of varlist jan_use_3-dec_use_3 {
	rename `var' use_2013_m`mm'
	local mm = `mm'+1
}

// Round variables (eliminating likely-false levels of precision)
foreach var of varlist div_20* use_20* {
	replace `var'=round(`var',.01)
}

// Rename variables
forvalues i=0/19 {
	rename use`i' benuse`i'
}

// Save useful variables
keep appno latitude longitude anystorage source_name netacres	///
	 user wrtype riparian pre1914 facevalue yearstart yearend inactive div_*_m* use_*_m* benuse*
order appno, first
isid appno
sort appno
compress
save "$DATA_TEMP/waterrights_ewrims.dta", replace
