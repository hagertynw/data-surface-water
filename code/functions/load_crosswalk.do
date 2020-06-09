

// Load names crosswalk
preserve

	* load basic list & set aside
	import excel using "names_crosswalk.xlsx", sheet("allnames") firstrow clear
	keep user std_name
	duplicates drop
	isid user
	tempfile masternames
	save `masternames'
	
	* don't forget the standardized names themselves
	gen same = (user==std_name)
	bys std_name: egen totsame = total(same)
	keep if totsame==0
	keep std_name
	duplicates drop
	
	* tack them onto the original list
	gen user = std_name
	order user, first
	append using `masternames'

	* save this combined list in a tempfile
	sort user
	isid user
	save `masternames', replace

restore


// Merge in standardized names
merge m:1 user using `masternames', gen(mergemaster)
	drop if mergemaster==2
	assert mergemaster==3
	drop mergemaster

	