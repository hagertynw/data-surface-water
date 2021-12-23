
// Purpose: Clean Lower Colorado Project diversions & entitlements
// 	Diversions from: Colorado River Accounting & Water Use Reports
//						https://www.usbr.gov/lc/region/g4000/wtracct.html
//	Entitlements from:	https://www.usbr.gov/lc/region/g4000/contracts/entitlements.html
// 						https://www.usbr.gov/lc/region/programs/strategies/FEIS/index.html


// Load master names list
import excel using "$REF_NAMES/names_crosswalk.xlsx", sheet("allnames") firstrow clear
keep user std_name
duplicates drop
isid user
tempfile masternames
save `masternames'
gen same = (user==std_name)
bys std_name: egen totsame = total(same)
keep if totsame==0
keep std_name
duplicates drop
gen user = std_name
order user, first
append using `masternames'
sort user
isid user
save `masternames', replace

// Import entitlements
import excel using "$DATA_LOCO/accounting_reports.xlsx", sheet("Entitlements") firstrow clear
tempfile entitlements
save `entitlements'

// Import quantity diverted
import excel using "$DATA_LOCO/accounting_reports.xlsx", sheet("Diversion") firstrow clear
rename Diversionsacrefeet user
foreach var of varlist * {
	if "`var'"!="user" {
		local colname: variable label `var'
        rename `var' diversion`colname'
	}
}
reshape long diversion, i(user) j(year)
replace user="Metropolitan Water District of Southern California" if user=="Transfer from SDCWA to MWD (originally from IID)"
replace user="San Diego County Water Authority" if user=="Transfer to San Diego County Water Authority"
replace user="Yuma Project Reservation Division" if regexm(user,"Yuma Project Reservation Division")
collapse (sum) diversion, by(user year)

// Combine all datasets
merge m:1 user using `entitlements', gen(mergeEntitlements)
	assert mergeEntitlements==3
	drop mergeEntitlements
keep user year diversion entitlement
replace user = upper(user)

// Merge in standardized names
merge m:1 user using `masternames', gen(mergemaster)
	drop if mergemaster==2
	assert mergemaster==3
	drop mergemaster
drop user
order year std_name
sort std_name year
isid std_name year
rename entitlement loco_maxvol
rename diversion loco_deliveries

// Manually classify into municipal/agricultural
gen loco_maxvol_mi = loco_maxvol if regexm(std_name,"GOVERNMENT CAMP|METROPOLITAN|CITY OF|SAN DIEGO")
gen loco_maxvol_ag = loco_maxvol if regexm(std_name,"COACHELLA|I\.D\.|INDIAN RESERVATION|OTHER USERS|YUMA PROJECT")
gen loco_deliveries_mi = loco_deliveries if regexm(std_name,"GOVERNMENT CAMP|METROPOLITAN|CITY OF|SAN DIEGO")
gen loco_deliveries_ag = loco_deliveries if regexm(std_name,"COACHELLA|I\.D\.|INDIAN RESERVATION|OTHER USERS|YUMA PROJECT")
foreach var of varlist *_ag *_mi {
	replace `var'=0 if missing(`var')
}

// Save
order year std_name loco_maxvol loco_maxvol_ag loco_maxvol_mi loco_deliveries loco_deliveries_ag loco_deliveries_mi
isid std_name year
sort std_name year
compress
save "$PREPPED/allocations_source_loco.dta", replace
