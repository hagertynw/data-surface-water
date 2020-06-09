
// Purpose: Clean State Water Project data

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


// LOAD EACH COMPONENT DATASET

	// Load contractor names
	import excel using "$DATA_SWP/bulletin_132/B132-18 Tables.xlsx", sheet("Contractors") firstrow clear
	rename Contractor user_long
	rename Shortname user
	replace user_long = upper(user_long)
	tempfile swp_names
	save `swp_names'

	// Load list of sectors
	import delimited using "$DATA_SWP/swp_contractors.csv", clear
	gen user = upper(contractor)
	keep user ag mi
	tempfile miag
	save `miag'

	// Load percentage allocations
	import excel using "$DATA_SWP/pct_allocations.xlsx", firstrow clear
	rename mi pctallo_mi
	rename ag pctallo_ag
	replace pctallo_mi = pctallo_mi / 100
	replace pctallo_ag = pctallo_ag / 100
	tempfile pctallo
	save `pctallo'
	
	// Load maximum contract amounts (Table B-4)
	import excel using "$DATA_SWP/bulletin_132/B132-18 Tables.xlsx", sheet("B4") cellrange(A3:AN79) clear
	drop in 2
	foreach v of varlist A-AN {
		rename `v' v`v'
	}
	reshape long v, i(vA) j(col) string
	rename vA year
	gen user = v if year=="Calendar Year"
	gsort col -user year
	by col: replace user=user[1]
	drop if year=="Calendar Year"
	drop if year=="TOTAL"
	drop if year==""
	drop if user=="Total"
	destring year v, replace
	drop col
	rename v maxcontract
	sort user year
	isid user year
	tempfile contract_amounts
	save `contract_amounts'

	// Load deliveries (Table B-5B)
	import excel using "$DATA_SWP/bulletin_132/B132-18 Tables.xlsx", sheet("B-5B") cellrange(A3:AN79) clear
	drop in 2
	foreach v of varlist A-AN {
		rename `v' v`v'
	}
	reshape long v, i(vA) j(col) string
	rename vA year
	gen user = v if year=="Calendar Year"
	gsort col -user year
	by col: replace user=user[1]
	drop if year=="Calendar Year"
	drop if year=="TOTAL"
	drop if year==""
	drop if user=="Total"
	destring year v, replace
	drop col
	rename v deliveries
	sort user year
	isid user year
	tempfile deliveries
	save `deliveries'

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

	// Load subcontracts data
	import excel "$REF_KERN/swp-contracts-in-kern-county.xlsx", cellrange(A4) firstrow clear
	keep std_name-mi
	drop if std_name==""
	egen tot_ag = total(ag)
	egen tot_mi = total(mi)
	gen pct_ag_sub = ag/tot_ag
	gen pct_mi_sub = mi/tot_mi
	drop tot_*
	rename std_name std_name2
	tempfile subcontracts_kern
	save `subcontracts_kern'


// MERGE AND PROCESS

	// Merge data together
	* start with deliveries data
	use `deliveries'
	* merge in maximum contract amounts
	merge 1:1 user year using `contract_amounts', gen(mergecontract)
		assert mergecontract==3
		drop mergecontract
	* merge in percentage allocations
	merge m:1 year using `pctallo', gen(mergeallo)
		drop if mergeallo==2
		drop mergeallo
	* merge in full names
	replace user="Alameda-Zone 7" if user=="Alameda- Zone 7"
	gen user1=user
	replace user="Kern" if regexm(user,"Kern: ")
	drop if user=="Grand Total"
	drop if user=="South Bay Area Future Contractor"
	merge m:1 user using `swp_names', gen(mergenames)
		assert mergenames==3
		drop mergenames
	* merge in mi/ag status
	drop user
	rename user_long user
	order user, after(year)
	merge m:1 user using `miag', gen(mergemiag)
		assert mergemiag==3
		drop mergemiag
		
	// Drop future projections (not real data)
	drop if year>2018

	// Reshape to sector
	gen sector = ""
		replace sector="_mi" if mi==1 & ag==0
		replace sector="_ag" if mi==0 & ag==1
		replace sector="_mi" if user1=="Kern: Municipal and Industrial"
		replace sector="_ag" if user1=="Kern: Agricultural"
		replace sector="_tot" if user1=="Kern: Total"
	drop user1 mi ag
	reshape wide deliveries maxcontract, i(year user) j(sector) string
	sort user year
	order year user deliveries_* maxcontract_*
	egen deltot = rowtotal(deliveries_ag deliveries_mi)
		assert deliveries_tot==deltot if deliveries_tot<.
		replace deliveries_tot=deltot if deliveries_tot==.
	egen maxcontot = rowtotal(maxcontract_ag maxcontract_mi)
		assert maxcontract_tot==maxcontot if maxcontract_tot<.
		replace maxcontract_tot=maxcontot if maxcontract_tot==.
	drop deltot maxcontot
	rename deliveries_tot deliveries
	rename maxcontract_tot maxcontract
	order year user deliveries deliveries_ag deliveries_mi maxcontract maxcontract_ag maxcontract_mi pctallo_ag pctallo_mi

	// Standardize names
	merge m:1 user using `masternames', gen(mergemaster)
		drop if mergemaster==2
		assert mergemaster==3
		drop mergemaster
	drop user
	order year std_name
	sort std_name year
	isid std_name year

	// Reallocate subcontracts
	gen kern = (std_name=="KERN COUNTY W.A.")
	preserve
		keep if kern==1
		gen parent = std_name
		cross using `subcontracts_kern'
		gen new_maxcontract_ag = maxcontract_ag * pct_ag_sub
		gen new_maxcontract_mi = maxcontract_mi * pct_mi_sub
		gen new_deliveries_ag = deliveries_ag * pct_ag_sub
		gen new_deliveries_mi = deliveries_mi * pct_mi_sub
		egen new_maxcontract = rowtotal(new_maxcontract_*)
		egen new_deliveries = rowtotal(new_deliveries_*)
		bys year: egen grtot_deliv = total(new_deliveries)
		bys year: egen grtot_maxcon = total(new_maxcontract)
		assert abs(grtot_deliv - deliveries)<.1
		assert abs(grtot_maxcon - maxcontract)<.1
		drop grtot_*
		foreach var of varlist deliveries-maxcontract_mi {
			drop `var'
			rename new_`var' `var'
		}
		order year std_name2 deliveries deliveries_* maxcontract maxcontract_* pctallo_* parent
		keep year-parent
		rename std_name2 std_name
		tempfile kern_reallo
		save `kern_reallo'
	restore
	drop if kern==1
	append using `kern_reallo'
	drop kern
	sort std_name year
	isid std_name year

	// Define 1990 maximum volumes as the time-invariant baseline
	by std_name: gen swp_basemax_ag = maxcontract_ag if year==1990
	by std_name: gen swp_basemax_mi = maxcontract_mi if year==1990
	sort std_name swp_basemax_ag
		by std_name: replace swp_basemax_ag=swp_basemax_ag[1]
		replace swp_basemax_ag=0 if swp_basemax_ag==.
	sort std_name swp_basemax_mi
		by std_name: replace swp_basemax_mi=swp_basemax_mi[1]
		replace swp_basemax_mi=0 if swp_basemax_mi==.
	gen swp_basemax = swp_basemax_ag + swp_basemax_mi

	// Set to 0 when missing
	foreach var of varlist deliveries* maxcontract* {
		replace `var'=0 if missing(`var')
	}

	// Rename variables
	rename deliveries		swp_deliveries
	rename deliveries_ag 	swp_deliveries_ag
	rename deliveries_mi 	swp_deliveries_mi
	rename maxcontract 		swp_maxvol
	rename maxcontract_ag 	swp_maxvol_ag
	rename maxcontract_mi	swp_maxvol_mi
	rename pctallo_ag		swp_pctallo_ag
	rename pctallo_mi		swp_pctallo_mi


// SAVE
drop parent
order year std_name swp_deliveries swp_deliveries_* swp_maxvol swp_maxvol_* swp_basemax swp_basemax_*
isid std_name year
sort std_name year
compress
save "$PREPPED/allocations_source_swp.dta", replace
