
// Purpose: Calculate water rights diversions per user and sector


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


// Load Kings River district areas (for reallocation of association)
* load list of members
import excel "$REF_KINGS/kings_members.xlsx", firstrow clear
drop if regexm(notes,"Doesn\'t use Kings River")
drop if std_name==""
keep std_name
rename std_name user
merge m:1 user using `masternames', gen(mergemaster)
	drop if mergemaster==2
	assert mergemaster==3
	drop mergemaster
keep std_name
tempfile kings_members
save `kings_members'
* load district areas
use "$DATA_TEMP/userXdauco.dta", clear
keep user_id-user_area user_cropland
duplicates drop
merge 1:1 std_name using `kings_members', gen(mergekings)
	assert mergekings!=2
keep if mergekings==3
egen tot_cropland = total(user_cropland)
gen kings_pct_cropland = user_cropland/tot_cropland
keep std_name user_cropland kings_pct_cropland
rename std_name std_name2
tempfile kings_areas
save `kings_areas'


// Rights data (combined)
use "$DATA_TEMP/waterrights_diversions.dta", clear
merge m:1 user using `masternames', gen(mergemaster)
	drop if mergemaster==2
	assert mergemaster==3 if user!="" & avgdiversion>0 & avgdiversion<.
	drop mergemaster
drop user
order appno std_name
sort appno std_name
isid appno

// Drop obs SWRCB has determined are not using rights or are duplicates
drop if avgdiversion==0

// Drop obs not reporting usage data to SWRCB (their face value is small so this should not be a problem)
//	(more specifically, face value of users who don't report any volumes is small)
drop if avgdiversion==.


// Drop water rights reported as part of federal & state projects
	
	* Central Valley Project water rights (allocations will be added later)
	drop if std_name=="U.S. BUREAU OF RECLAMATION"
	
	* State Water Project water rights (allocations will be added later)
	drop if std_name=="CALIFORNIA DEPT. OF WATER RESOURCES"

	* Colorado River water rights (allocations will be added later)
	drop if source_name=="COLORADO RIVER"

	
// Categorize beneficial uses
	
	gen use_agriculture = 0
	gen use_municipal = 0
	gen use_nonconsumptive = 0
	gen use_other = 0
	
	* Agricultural uses
	replace use_agriculture=1		if benuse11==1		// irrigation
	replace use_agriculture=1		if benuse19==1		// stockwatering
	
	* Municipal uses
	replace use_municipal=1  		if benuse3==1		// domestic
	replace use_municipal=1  		if benuse10==1		// industrial
	replace use_municipal=1			if benuse14==1		// municipal

	* Nonconsumptive uses
	replace use_nonconsumptive=1  	if benuse1==1		// aesthetic
	replace use_nonconsumptive=1  	if benuse2==1		// aquaculture
	replace use_nonconsumptive=1  	if benuse6==1		// fish & wildlife
	replace use_nonconsumptive=1  	if benuse9==1		// incidental power
	replace use_nonconsumptive=1  	if benuse16==1		// power
	replace use_nonconsumptive=1  	if benuse17==1		// recreational
	replace use_nonconsumptive=1  	if benuse18==1		// snow-making

	* Other uses
	replace use_other=1				if benuse0==1		// blank
	replace use_other=1  			if benuse4==1		// dust control
	replace use_other=1  			if benuse5==1		// fire protection
	replace use_other=1				if benuse7==1		// frost protection
	replace use_other=1  			if benuse8==1		// heat control
	replace use_other=1  			if benuse12==1		// milling
	replace use_other=1  			if benuse13==1		// mining
	replace use_other=1  			if benuse15==1		// other

	* Verify categories are exhaustive
	assert (1-use_agriculture)*(1-use_municipal)*(1-use_nonconsumptive)*(1-use_other)==0

	
// Drop nonconsumptive uses

	drop if use_nonconsumptive==1 & use_agriculture==0 & use_municipal==0 & use_other==0

	* Assumed environmental/recreational based on name
	drop if std_name=="WHITE MALLARD, INC."
	drop if std_name=="PINE MOUNTAIN LAKE ASSOCIATION"
	drop if std_name=="NATURE CONSERVANCY"
	drop if std_name=="WOODY'S ON THE RIVER, LLC"
	drop if regexm(std_name,"DUCK CLUB|GUN CLUB|SHOOTING CLUB")
	drop if regexm(std_name,"FISH & WILDLIFE|FOREST SERVICE|BUREAU OF LAND MANAGEMENT|NATIONAL PARK SERVICE|PARKS & RECREATION|FORESTRY & FIRE PREVENTION")
	drop if regexm(std_name,"WATERFOWL|PRESERVATION|WETLANDS|TUSCANY RESEARCH")
	
	* Assumed electricity generation based on name
	drop if use_agriculture==0 & std_name=="SOUTHERN CALIFORNIA EDISON COMPANY"
	drop if use_agriculture==0 & std_name=="PACIFIC GAS & ELECTRIC CO."
	drop if use_agriculture==0 & regexm(std_name,"POWER ") & !regexm(std_name,"WATER")

	
// Designate right as Ag or MI (municipal/industrial), based on whether it lists
//	irrigation or stockwatering as a beneficial use.

	rename use_agriculture ag

	* Set cities to MI
	replace ag=0 if regexm(std_name,"CITY OF")
	
	* Set golf courses to MI (yes they're irrigated, but they're not agriculture)
	replace ag=0 if regexm(std_name," GOLF ")
	
	* Manually verified edits in Orange County
	replace ag=0 if std_name=="ORANGE COUNTY W.D."
	replace ag=0 if std_name=="SERRANO W.D."
	replace ag=0 if std_name=="IRVINE RANCH W.D."
	replace ag=0 if std_name=="SANTA MARGARITA W.D."


// Reallocate jointly-held rights to member districts

	gen parent = ""

	* Joint Water Districts Board
	* reference: Joint Water Districts.xlsx
	gen joint = (std_name=="JOINT WATER DISTRICTS BOARD")
	replace parent = std_name if joint==1
	expand 4 if joint==1
	bys std_name appno: gen member=_n if joint==1
	replace std_name="BUTTE W.D."				if joint==1 & member==1
	replace std_name="BIGGS-WEST GRIDLEY W.D."	if joint==1 & member==2
	replace std_name="RICHVALE I.D." 			if joint==1 & member==3
	replace std_name="SUTTER EXTENSION W.D." 	if joint==1 & member==4
	foreach var of varlist avgdiversion avgdiversion_m* diversion_* {
		replace `var' = `var' * 0.24 if joint==1 & std_name=="BUTTE W.D."
		replace `var' = `var' * 0.29 if joint==1 & std_name=="BIGGS-WEST GRIDLEY W.D."
		replace `var' = `var' * 0.27 if joint==1 & std_name=="RICHVALE I.D."
		replace `var' = `var' * 0.20 if joint==1 & std_name=="SUTTER EXTENSION W.D."
	}
	drop joint member

	* Kings River Water Association
	gen kings = (std_name=="KINGS RIVER WATER ASSOCIATION")
	preserve
		keep if kings==1
		replace parent = std_name
		cross using `kings_areas'
		replace std_name=std_name2
		foreach var of varlist avgdiversion avgdiversion_m* diversion_* {
			replace `var' = `var' * kings_pct_cropland
		}
		drop std_name2 user_cropland kings_pct_cropland
		tempfile kings_reallo
		save `kings_reallo'
	restore
	drop if kings==1
	append using `kings_reallo'
	drop kings

	
// Sum to user X sector (ag/mi)
sort std_name ag appno
* average: sum over averages
by std_name: egen tot_avgdiversion = total(avgdiversion)
by std_name ag: egen tot_avgdiversion_mi = total(avgdiversion) if ag==0
by std_name ag: egen tot_avgdiversion_ag = total(avgdiversion) if ag==1
by std_name: replace tot_avgdiversion_mi = tot_avgdiversion_mi[1]
by std_name: replace tot_avgdiversion_ag = tot_avgdiversion_ag[_N]
replace tot_avgdiversion_mi=0 if missing(tot_avgdiversion_mi)
replace tot_avgdiversion_ag=0 if missing(tot_avgdiversion_ag)
* each year: show sum only if every right has a report
foreach var of varlist diversion_* {
	by std_name ag: egen tot_mi_`var' = total(`var') if ag==0
	by std_name ag: egen tot_ag_`var' = total(`var') if ag==1
	by std_name ag: egen rpt_`var'_mi = count(`var') if ag==0
	by std_name ag: egen rpt_`var'_ag = count(`var') if ag==1
	by std_name ag: gen obs_`var'_mi = _N if ag==0
	by std_name ag: gen obs_`var'_ag = _N if ag==1
	replace tot_mi_`var'=. if rpt_`var'_mi!=obs_`var'_mi
	replace tot_ag_`var'=. if rpt_`var'_ag!=obs_`var'_ag
	by std_name: replace tot_mi_`var' = tot_mi_`var'[1]
	by std_name: replace tot_ag_`var' = tot_ag_`var'[_N]
}
drop rpt_*_* obs_*_*


// Find min, max, median, and mean start years
sort std_name
by std_name: egen int min_year = min(yearstart)
by std_name: egen int max_year = max(yearstart)
gen yearXvol = yearstart*avgdiversion
	by std_name: egen tot_yearXvol = total(yearXvol), missing
	gen mean_year = tot_yearXvol / tot_avgdiversion
	drop yearXvol tot_yearXvol
assert mean_year+.001>=min_year & mean_year-.001<=max_year
egen med_year = wpctile(yearstart), p(50) weights(avgdiversion) by(std_name)
assert med_year>=min_year & med_year<=max_year


// Drop rights with no location information (drops 151 obs & 42k af)
drop if missing(latitude) | missing(longitude)


// Collapse to user, keeping location information for one representative POD (of largest volume)
gsort std_name -avgdiversion
by std_name: keep if _n==1
keep std_name parent latitude longitude tot_*diversion* m*_year
gsort -tot_avgdiversion
isid std_name


// Drop false levels of precision
foreach var of varlist *diversion* {
	replace `var' = round(`var',0.1)
}


// Reshape to user X year
reshape long tot_mi_diversion_ tot_ag_diversion_, i(std_name) j(year)


// Rename and order variables
rename tot_avgdiversion 	rights_avgdivert
rename tot_avgdiversion_mi	rights_avgdivert_mi
rename tot_avgdiversion_ag	rights_avgdivert_ag
rename tot_mi_diversion		rights_diversion_mi
rename tot_ag_diversion		rights_diversion_ag
rename latitude				rights_pod_latitude
rename longitude			rights_pod_longitude
rename m*_year				rights_m*_year
order std_name year parent rights_avgdivert rights_avgdivert_ag rights_avgdivert_mi 	///
	  rights_diversion_ag rights_diversion_mi rights_pod_latitude rights_pod_longitude


// Save dataset of means
preserve
	drop year rights_diversion_ag rights_diversion_mi
	duplicates drop
	isid std_name
	compress
	save "$PREPPED/allocations_source_rights_means.dta", replace
restore
	

// Save dataset of reported yearly diversions
drop rights_avgdivert*
drop if missing(rights_diversion_ag) & missing(rights_diversion_mi)
isid std_name year
sort std_name year
compress
save "$PREPPED/allocations_source_rights_yearly.dta", replace

