
// Purpose: Load Central Valley Project allocations


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


// LOAD DELIVERIES DATA

	* import & append data
	clear
	tempfile appendfile
	gen year=.
	save `appendfile'
	forvalues sheet=31/37 {
		disp "`sheet'"
		import excel using "$DATA_CVP/deliveries/deliveries 1993-1997.xlsx", sheet(`sheet') firstrow clear
		tostring category, replace
		tempfile importfile
		save `importfile', replace
		use `appendfile', clear
		append using `importfile'
		save `appendfile', replace
	}
	forvalues sheet=22/28 {
		disp "`sheet'"
		import excel using "$DATA_CVP/deliveries/deliveries 1998-2010.xlsx", sheet(`sheet') firstrow clear
		tostring category, replace
		tempfile importfile
		save `importfile', replace
		use `appendfile', clear
		append using `importfile'
		save `appendfile', replace
	}
	forvalues sheet=22/28 {
		disp "`sheet'"
		import excel using "$DATA_CVP/deliveries/deliveries 2011-2021.xlsx", sheet(`sheet') firstrow clear
		tostring category, replace
		tempfile importfile
		save `importfile', replace
		use `appendfile', clear
		append using `importfile'
		save `appendfile', replace
	}

	* clean up
	drop Total
	rename WaterUser user
	replace user = upper(user)
	replace category="" if category=="."
	
	* drop totals and lines that aren't real water users
	drop if category=="Refuges"
	drop if regexm(user,"TOTAL")
	drop if regexm(user,"DMC PLUS O|TOT DMC DELIVERIES|215 WATER|DWR INTERTIE")
	drop if regexm(user,"PHASE|FLOOD RELEASES|FISH FACILITIES|CONSTRUCTION WATER")
	drop if regexm(user,"CHINA ISLAND|WASTEWAY|OPERATIONAL WATER")
	drop if regexm(user,"SAN JOAQUIN DRAIN|USBR|WARREN CONTRACTS")
	drop if regexm(user,"NEILL PUMP|NEILL NET")
	
	* merge in standardized names
	merge m:1 user using `masternames', gen(mergemaster)
		drop if mergemaster==2
		assert mergemaster==3
		drop mergemaster
	order year std_name branch category
	
	* rename columns
	foreach m of varlist Jan-Dec {
		rename `m' deliv_`m'
	}

	* get list of branch/category with greatest historical volume
	preserve
		egen deliv_tot = rowtotal(deliv_*)
		collapse (sum) deliv_tot, by(std_name branch category)
		gsort std_name -deliv_tot
		by std_name: keep if _n==1
		keep std_name branch category
		tempfile branchcat
		save `branchcat'
	restore

	* set aside locations
	preserve
		keep std_name branch category
		duplicates drop
		tempfile loc_deliveries
		save `loc_deliveries'
	restore

	* sum within user X year
	collapse (sum) deliv_*, by(std_name year)

	* reattach branch/category
	merge m:1 std_name using `branchcat'
		assert _merge==3
		drop _merge

	* set aside
	qui sum year
	scalar yearfirst = r(min)
	scalar yearlast = r(max)
	sort std_name year
	isid std_name year
	tempfile deliveries
	save `deliveries'


// LOAD & CLEAN ALLOCATION PERCENTAGES

	* import	
	import excel using "$DATA_CVP/allocations.xlsx", firstrow clear

	* name the columns
	rename A usertype
	foreach var of varlist * {
		if "`var'"!="usertype" {
			local colname: variable label `var'
			rename `var' pct_`colname'
		}
	}

	* impute where missing or not a percentage
	foreach var of varlist pct_* {
		* impute "North of Delta Urban Contractors"
		replace `var'=`var'[2] if `var'==. & usertype=="American River M&I Contractors"
		replace `var'=`var'[2] if `var'==. & usertype=="In Delta - Contra Costa"
		* convert volumes to percentages (by dividing by total maximum contract volume)
		replace `var'=`var'/155000*100 if `var'>100 & usertype=="Eastside Division Contractors"
		replace `var'=`var'/1401475*100 if `var'>100 & usertype=="Friant - Class 2"
		* category did not exist prior to appearing in dataset
		replace `var'=0 if `var'==. & usertype=="Eastside Division Contractors"
	}

	* abbreviate categories
	gen type = ""
	replace type = "american" if usertype=="American River M&I Contractors"
	replace type = "eastside" if usertype=="Eastside Division Contractors"
	replace type = "friant1" if usertype=="Friant - Class 1"
	replace type = "friant2" if usertype=="Friant - Class 2"
	replace type = "friant0" if usertype=="Friant - Hidden & Buchanan Units"
	replace type = "indelta" if usertype=="In Delta - Contra Costa"
	replace type = "nag" if usertype=="North of Delta Agricultural Contractors (Ag)"
	replace type = "nmi" if usertype=="North of Delta Urban Contractors (M&I)"
	replace type = "nrights" if usertype=="North of Delta Settlement Contractors/Water Rights"
	replace type = "nrefuges" if usertype=="North of Delta Wildlife Refuges (Level 2)"
	replace type = "sag" if usertype=="South of Delta Agricultural Contractors (Ag)"
	replace type = "smi" if usertype=="South of Delta Urban Contractors (M&I)"
	replace type = "srights" if usertype=="South of Delta Settlement Contractors/Water Rights"
	replace type = "srefuges" if usertype=="South of Delta Wildlife Refuges (Level 2)"
	drop usertype

	* reshape
	reshape long pct_, i(type) j(year) string
	reshape wide pct_, i(year) j(type) string
	destring year, replace

	* set aside
	compress
	sort year
	isid year
	tempfile pctallocations
	save `pctallocations'

	

// LOAD & CLEAN LIST OF MAXIMUM CONTRACT VOLUMES

	* import list of contractors
	import excel using "$DATA_CVP/cvp_contractors.xlsx", sheet("cvp_contractors") firstrow clear

	* clean
	gen user = upper(contractor)
	rename MI mi
	rename AG ag
	rename CVPDivision division
	rename Unit unit
	rename MaximumContractQuantity maxvolume
	rename MIHistoricalUse maxvolume_mi
	rename BaseSupply maxvolume_base
	rename ProjectWater maxvolume_project
	drop ContractAmountforAg
	replace mi="1" if mi=="X"
	replace ag="1" if ag=="X"
	replace mi="0" if mi==""
	replace ag="0" if ag==""
	destring mi ag, replace

	* merge standardized names
	merge m:1 user using `masternames', gen(mergemaster)
		drop if mergemaster==2
		assert mergemaster==3
		drop mergemaster
	order std_name maxvolume category division unit

	* for shared contracts, split by apparent ratios from delivery data (calculated separately)
	assert maxvolume=="840000" if ContractNo=="Ilr 1144 (1)"
	replace maxvolume="560000" if ContractNo=="Ilr 1144 (1)"
	replace maxvolume= "56000" if ContractNo=="Ilr 1144 (2)"
	replace maxvolume="168000" if ContractNo=="Ilr 1144 (3)"
	replace maxvolume= "56000" if ContractNo=="Ilr 1144 (4)"

	* for shared contracts, split evenly (when delivery data does not help)
	assert maxvolume==  "6260" if ContractNo=="14-06-200-3365A-IR13-B (SCV)"
	replace maxvolume=  "3130" if ContractNo=="14-06-200-3365A-IR13-B (SCV)"
	replace maxvolume=  "3130" if ContractNo=="14-06-200-3365A-IR13-B (WWD)"
	assert maxvolume=="600000" if contractor=="Oakdale Irrigation District"
	replace maxvolume="300000" if contractor=="Oakdale Irrigation District"
	replace maxvolume="300000" if contractor=="South San Joaquin Irrigation District"
	
	* clean up maxvolume
	replace maxvolume_mi="" if maxvolume_mi=="-"
	destring maxvolume maxvolume_mi, replace
	replace maxvolume_mi=0 if maxvolume_mi==.
	
	* for two related contracts, consolidate (so that maxvolume = maxvolume_project + maxvolume_base)
	replace maxvolume=128000 if std_name=="ANDERSON-COTTONWOOD I.D." & maxvolume==125000
		drop if std_name=="ANDERSON-COTTONWOOD I.D." & maxvolume==3000
	
	* specify max volume by base or project
	replace maxvolume_base=maxvolume 	if project==0 & base==1 & maxvolume_base==.
	replace maxvolume_project=0 		if project==0 & base==1 & maxvolume_project==.
	replace maxvolume_project=maxvolume	if project==1 & base==0 & maxvolume_project==.
	replace maxvolume_base=0 			if project==1 & base==0 & maxvolume_base==.
	
	* for one Sac R Settl. Contr. holder without base/project split, assume it's just project
	replace maxvolume_base=0				if maxvolume_base==.
	replace maxvolume_project=maxvolume		if maxvolume_project==.

	* for 2 obs whose M&I volume exceeds max contract volume, adjust M&I vol to equal contract vol
	replace maxvolume_mi = maxvolume if maxvolume_mi>maxvolume
	assert maxvolume == maxvolume_base + maxvolume_project
	assert maxvolume >= maxvolume_mi
	assert maxvolume >= maxvolume_project
	
	* set up max volume variables for each contract type X sector
	gen mvcat_mi_american = maxvolume_mi			if category=="American River M&I Contracts"
	gen mvcat_ag_american = maxvolume-maxvolume_mi 	if category=="American River M&I Contracts"
	gen mvcat_mi_friant1  = maxvolume_mi			if category=="Friant Division" & class==1
	gen mvcat_ag_friant1  = maxvolume-maxvolume_mi 	if category=="Friant Division" & class==1
	gen mvcat_mi_friant2  = maxvolume_mi			if category=="Friant Division" & class==2
	gen mvcat_ag_friant2  = maxvolume-maxvolume_mi	if category=="Friant Division" & class==2
	gen mvcat_mi_friant0  = maxvolume_mi			if category=="Friant Division" & class==.
	gen mvcat_ag_friant0  = maxvolume-maxvolume_mi	if category=="Friant Division" & class==.
	gen mvcat_mi_indelta  = maxvolume_mi			if category=="In Delta - Contra Costa"
	gen mvcat_ag_indelta  = maxvolume-maxvolume_mi 	if category=="In Delta - Contra Costa"
	gen mvcat_mi_north    = maxvolume_mi 			if category=="Sacramento River Water Service Contracts"
	gen mvcat_ag_north    = maxvolume-maxvolume_mi 	if category=="Sacramento River Water Service Contracts"
	gen mvcat_mi_srights  = maxvolume_mi			if category=="South of Delta Water Rights Contracts"
	gen mvcat_ag_srights  = maxvolume-maxvolume_mi 	if category=="South of Delta Water Rights Contracts"
	gen mvcat_mi_south    = maxvolume_mi 			if category=="South of Delta Water Service Contracts"
	gen mvcat_ag_south    = maxvolume-maxvolume_mi 	if category=="South of Delta Water Service Contracts"
	gen mvcat_mi_eastside = maxvolume_mi			if category=="Stanislaus East Side"
	gen mvcat_ag_eastside = maxvolume-maxvolume_mi 	if category=="Stanislaus East Side"
	gen mvcat_mi_nrights  = .						if category=="Sacramento River Water Rights Settlement Contractors"
	gen mvcat_ag_nrights  = maxvolume_base 			if category=="Sacramento River Water Rights Settlement Contractors"
	replace mvcat_ag_north= maxvolume_project		if category=="Sacramento River Water Rights Settlement Contractors"
		* note: this is the only category that has both base and project water
		* though not 100% is ag, it's pretty close. cannot simultaneously differentiate base/project & MI/ag
	gen mvcat_nrefuges 	  = maxvolume				if category=="Refuges" & regexm(std_name,"NORTH")
	gen mvcat_srefuges    = maxvolume 				if category=="Refuges" & regexm(std_name,"SOUTH")
	order mvcat*, after(maxvolume_project)
	egen mvcat_total = rowtotal(mvcat_*)
	assert maxvolume==mvcat_total
	drop mvcat_total

	* collapse to unique user
	sort std_name category division unit
	gsort std_name -maxvolume
	by std_name: replace category=category[1]
	by std_name: replace division=division[1]
	by std_name: replace unit=unit[1]
	gen n=_n
	collapse (sum) maxvolume maxvolume_mi maxvolume_base maxvolume_project mvcat_*	///
			 (max) mi ag project base (count) n, 	///
			 by(std_name category division unit)
	drop n
	isid std_name

	* organize
	rename category cvpcategory
	gen maxvolume_ag = maxvolume - maxvolume_mi
	order std_name maxvolume maxvolume_mi maxvolume_ag, first

	tempfile contractors
	save `contractors'

	
	
// COMBINE DATA
	
	// Start with contractors & expand to match year range of deliveries data
	use `contractors', clear
	drop if std_name=="OAKDALE I.D." | std_name=="SOUTH SAN JOAQUIN I.D."	// rights-holders, not subject to USBR cutbacks
	drop if std_name=="U.S. FISH & WILDLIFE SERVICE - NORTH OF DELTA REFUGES" | std_name=="U.S. FISH & WILDLIFE SERVICE - SOUTH OF DELTA REFUGES"
	disp yearlast
	disp yearfirst
	disp `=yearlast-yearfirst+1'
	expand `=yearlast-yearfirst+1'
	bys std_name: gen year = yearfirst - 1 + _n
	order year, first

	// Merge in deliveries
	merge 1:1 std_name year using `deliveries', gen(mergedeliveries)
	assert std_name!="OAKDALE I.D." & std_name!="SOUTH SAN JOAQUIN I.D."
	order deliv_*, after(std_name)
	sort std_name year

	// Merge in percent allocations
	merge m:1 year using `pctallocations', gen(mergeallocations)
		drop if mergeallocations==2
		assert mergeallocations==3
		drop mergeallocations

	// Calculate calendar-year and water-year totals
	sort std_name year
	by std_name: gen deliv_nextJan = deliv_Jan[_n+1] if year[_n+1]==year+1
	by std_name: gen deliv_nextFeb = deliv_Feb[_n+1] if year[_n+1]==year+1
	egen deliveries_cy = rowtotal(deliv_Jan-deliv_Dec) if year>=1993
	egen deliveries_wy = rowtotal(deliv_Mar-deliv_Dec deliv_nextJan deliv_nextFeb) if year>=1993
	order deliveries_?y, after(std_name)
	
	// Calculate deliveries by sector (when user is in both sectors, assume deliveries
	//	 are allocated in the same ratio as the maximum contract volume)
	gen deliveries_cy_ag=0 if !missing(deliveries_cy)
	gen deliveries_wy_ag=0 if !missing(deliveries_wy)
	gen deliveries_cy_mi=0 if !missing(deliveries_cy)
	gen deliveries_wy_mi=0 if !missing(deliveries_wy)
	replace deliveries_cy_ag = round( deliveries_cy * (maxvolume_ag / maxvolume) ) if !missing(maxvolume)
	replace deliveries_wy_ag = round( deliveries_wy * (maxvolume_ag / maxvolume) ) if !missing(maxvolume)
	replace deliveries_cy_mi = deliveries_cy - deliveries_cy_ag if !missing(maxvolume)
	replace deliveries_wy_mi = deliveries_wy - deliveries_wy_ag if !missing(maxvolume)
	order deliveries_?y_??, after(deliveries_wy)
	
	// For delivery recipients not appearing in list of contracts:
	// (note missing(maxvolume) is the same as mergedeliveries==2)
	* drop environmental users
	drop if mergedeliveries==2 & regexm(std_name,"GUN CLUB|WATERFOWL|GRASSLAND|WILDLIFE|FOREST SERVICE|MILLERTON LK")
	* drop if not delivered anything
	drop if mergedeliveries==2 & deliveries_cy==0 & deliveries_wy==0
	* classify sector (provided in contract list but not in deliveries data)
	gen sector=.
		replace sector=0 if mergedeliveries==2 & regexm(std_name," I\.D\.$")
		replace sector=0 if mergedeliveries==2 & regexm(std_name,"FARM|RANCH|IRRIGATION|VINEYARD| LAND")
		replace sector=1 if mergedeliveries==2 & regexm(std_name,"CITY OF|PROPERTIES|CONSTRUCTION|GOLF|UNIVERSITY|INC\.|LOS BANOS GRAVEL")
		replace sector=1 if mergedeliveries==2 & regexm(std_name," P\.U\.D\.$")
		replace sector=0 if mergedeliveries==2 & std_name=="KINGS COUNTY W.D."
		replace sector=1 if mergedeliveries==2 & std_name=="LA GRANGE W.D."
		replace sector=1 if mergedeliveries==2 & std_name=="LAKESIDE W.D."
		replace sector=0 if mergedeliveries==2 & sector==.
	* allocate deliveries by sector
	replace deliveries_cy_ag = deliveries_cy if mergedeliveries==2 & sector==0
	replace deliveries_wy_ag = deliveries_wy if mergedeliveries==2 & sector==0
	replace deliveries_cy_mi = deliveries_cy if mergedeliveries==2 & sector==1
	replace deliveries_wy_mi = deliveries_wy if mergedeliveries==2 & sector==1
		
	// Calculate allocation volumes & overall allocation percentage
	assert mvcat_nrefuges==0 if !missing(mvcat_nrefuges)
	assert mvcat_srefuges==0 if !missing(mvcat_srefuges)
	foreach contype in american friant1 friant2 friant0 indelta nrights srights eastside {
		gen allo_ag_`contype' = mvcat_ag_`contype' * pct_`contype' / 100
		gen allo_mi_`contype' = mvcat_mi_`contype' * pct_`contype' / 100
	}
	gen allo_ag_north = mvcat_ag_north * pct_nag / 100
	gen allo_mi_north = mvcat_mi_north * pct_nmi / 100
	gen allo_ag_south = mvcat_ag_south * pct_sag / 100
	gen allo_mi_south = mvcat_mi_south * pct_smi / 100
	egen totallo_ag = rowtotal(allo_ag_*), missing
	egen totallo_mi = rowtotal(allo_mi_*), missing
	egen totallo = rowtotal(totallo_*), missing
	gen pctallo = totallo / maxvolume
	gen pctallo_ag = totallo_ag / maxvolume_ag
	gen pctallo_mi = totallo_mi / maxvolume_mi
	replace pctallo=0 if maxvolume==0
	replace pctallo_ag=0 if maxvolume_ag==0
	replace pctallo_mi=0 if maxvolume_mi==0

	// Organize, remove variables no longer needed, rename
	order year std_name deliveries_cy deliveries_cy_ag deliveries_cy_mi		///
		deliveries_wy deliveries_wy_ag deliveries_wy_mi maxvolume maxvolume_ag maxvolume_mi	///
		maxvolume_base maxvolume_project pctallo pctallo_ag pctallo_mi
	keep year-pctallo_mi
	rename maxvolume* maxvol*
	rename deliveries_cy-pctallo_mi cvp_=

	// Save
	isid std_name year
	sort std_name year
	compress
	save "$PREPPED/allocations_source_cvp.dta", replace
