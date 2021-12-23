
// Purpose: Match users/districts to geographic polygons & distribute volumes across multiple areas


local volvars	vol_deliv_cy vol_deliv_wy vol_maximum 	///
				swp_deliveries swp_maxvol swp_basemax	///
				cvp_deliveries_cy cvp_deliveries_wy cvp_maxvol 	////
				loco_maxvol loco_deliveries	rights_avgdivert

				
// Load variable-labeling code
include "$CODE/functions/labelAllocationVariables.do"


// Prepare list of manual geolocations
import excel using "$REF_GEOLOC/manual_geolocating.xlsx", firstrow clear
keep std_name lat lon
rename lat lat_manual
rename lon lon_manual
tempfile manual_locations
save `manual_locations'


// 1. SEPARATE USERS INTO POLYGONS AND POINTS
//	  (Polygon = we know the exact service area of this water user)
//	  (Point = we only know a single lat/lon for the user)

// Load allocations data
use "$PREPPED/allocations_all.dta", clear

// Merge in districts
merge m:1 std_name using "$DATA_TEMP/polygons_district.dta", gen(mergeDist)
	drop if mergeDist==2

// Save set of point users
preserve
	keep if mergeDist==1
	drop user_x-mergeDist
	tempfile pointusers
	save `pointusers'
restore

// Keep only polygon users
keep if mergeDist==3
rename user_x user_centroid_lon
rename user_y user_centroid_lat
keep year-user_id
tempfile polygonusers
save `polygonusers'



// 2. MAKE DATASET OF POLYGON USERS

// Prepare total cropland area (from dauco pieces)
use "$DATA_TEMP/intersections_districtXdauco.dta", clear
keep std_name user_cropland
duplicates drop
isid std_name
tempfile cropland
save `cropland'

// Load polygon users and merge in cropland area
use `polygonusers', clear
merge m:1 std_name using `cropland'
	drop if _merge==2
	assert _merge==3
	drop _merge

// Save
order year std_name user_id user_centroid_lat user_centroid_lon user_area user_cropland
labelAllocationVariables
sort std_name year
isid std_name year
save "$PREPPED/allocations_subset_polygonusers.dta", replace
export delimited "$PREPPED/allocations_subset_polygonusers.csv", replace



// 3. MAKE DATASETS OF POLYGON USERS X GEOGRAPHIES
//  (Each has N observations for each polygon user, where N is the number of
//	 unique geographies the user's polygon intersects with)

// a. Geography: DAUCo

	* load allocations data
	use `polygonusers', clear

	* merge in multiple dauco pieces
	merge 1:m std_name year using "$DATA_TEMP/intersections_districtXdaucoXyears.dta", gen(mergemult)
		drop if mergemult==2
		assert mergemult==3
		drop mergemult

	* allocate district's water volumes across its DAUCo pieces
	*   ag water: on the basis of cropland area
	*	m&i water: on the basis of total land area
	foreach var of varlist `volvars' {
		rename `var'	tot_`var'
		rename `var'_ag tot_`var'_ag
		rename `var'_mi tot_`var'_mi
		gen `var'_ag = tot_`var'_ag * ishare_cropland
		gen `var'_mi = tot_`var'_mi * ishare_area
		egen `var' = rowtotal(`var'_ag `var'_mi), missing
		order `var' `var'_ag `var'_mi, before(tot_`var')
		drop tot_`var' tot_`var'_ag tot_`var'_mi
	}
	order `volvars', after(std_name)

	* merge in DAUCo information
	merge m:1 dauco_id using "$DATA_TEMP/polygons_dauco.dta", gen(mergedauco)
		drop if mergedauco==2

	* set aside
	duplicates tag std_name year dauco_id, gen(dups)
		assert dups==0
		drop dups
	keep year-user_id dauco_id dau_code-dauco_pctcrop
	order year std_name user_id dauco_id
	labelAllocationVariables
	sort std_name year dauco_id
	isid std_name year dauco_id
	isid user_id year dauco_id
	compress
	save "$PREPPED/allocations_subset_polygonusersXdauco.dta", replace
	export delimited "$PREPPED/allocations_subset_polygonusersXdauco.csv", replace

	
// b. Geography: HUC8

	* load allocations data
	use `polygonusers', clear

	* merge in multiple HUC8 pieces
	merge 1:m std_name year using "$DATA_TEMP/intersections_districtXhuc8Xyears.dta", gen(mergemult)
		drop if mergemult==2
		assert mergemult==3
		drop mergemult

	* allocate user's water volumes across its HUC8 pieces
	*   ag water: on the basis of cropland area
	*	m&i water: on the basis of total land area
	foreach var of varlist `volvars' {
		rename `var'	tot_`var'
		rename `var'_ag tot_`var'_ag
		rename `var'_mi tot_`var'_mi
		gen `var'_ag = tot_`var'_ag * ishare_cropland
		gen `var'_mi = tot_`var'_mi * ishare_area
		egen `var' = rowtotal(`var'_ag `var'_mi), missing
		order `var' `var'_ag `var'_mi, before(tot_`var')
		drop tot_`var' tot_`var'_ag tot_`var'_mi
	}
	order `volvars', after(std_name)

	* merge in HUC8 information
	merge m:1 huc8 using "$DATA_TEMP/polygons_huc8.dta", gen(mergehuc8)
		drop if mergehuc8==2
	
	* set aside
	duplicates tag std_name year huc8, gen(dups)
		assert dups==0
		drop dups
	keep year-user_id huc8 huc8_*
	order year std_name user_id huc8
	labelAllocationVariables
	sort std_name year huc8
	isid std_name year huc8
	isid user_id year huc8
	compress
	save "$PREPPED/allocations_subset_polygonusersXhuc8.dta", replace
	export delimited "$PREPPED/allocations_subset_polygonusersXhuc8.csv", replace


	
// 4. MAKE DATASET OF POINT USERS

	* Load set of point users
	use `pointusers', clear

	* Merge in manual geolocations
	merge m:1 std_name using `manual_locations'
		drop if _merge==2
		drop _merge

	* Use lat/lon of point of diversion, unless have a manual location
	gen lat = rights_pod_latitude
	gen lon = rights_pod_longitude
	replace lat = lat_manual if !missing(lat_manual)
	replace lon = lon_manual if !missing(lon_manual)

	* Geolocate each known lat/lon point to DAUCo that contains it
	isid std_name year
	count
	geoinpoly lat lon using "$GIS_SHP/dauco_final_shp.dta", unique
	isid std_name year
	count

	* Merge in DAUCo information
	merge m:1 _ID using "$DATA_TEMP/polygons_dauco.dta", gen(mergedauco)
		drop if mergedauco==2
	drop _ID

	* Geolocate each known lat/lon point to HUC8 that contains it
	isid std_name year
	count
	geoinpoly lat lon using "$GIS_SHP/huc8_final_shp.dta", unique
	isid std_name year
	count

	* Merge in HUC8 information
	merge m:1 _ID using "$DATA_TEMP/polygons_huc8.dta", gen(mergehuc8)
		drop if mergehuc8==2
	drop _ID

	* Save
	sort std_name year
	isid std_name year
	drop lat lon merge*
	labelAllocationVariables
	compress
	save "$PREPPED/allocations_subset_pointusers.dta", replace
	export delimited "$PREPPED/allocations_subset_pointusers.csv", replace



	
// 5. MAKE GEOGRAPHICAL AGGREGATE ALLOCATION DATASETS

//  a. Geography: HUC8

	* load point users
	use "$PREPPED/allocations_subset_pointusers.dta", clear
	drop if missing(huc8)				// drops 570 obs & 0.06% of volume
	drop dauco_id-dauco_pctcrop

	* append polygon users
	append using "$PREPPED/allocations_subset_polygonusersXhuc8.dta"
	drop user_id-user_area

	* keep only years with full data
	drop if missing(vol_deliv_cy)

	* allocations: go from percentages to volumes for aggregation
	gen allocation = vol_maximum * pct_allocation
	gen allocation_ag = vol_maximum_ag * pct_allocation_ag
	gen allocation_mi = vol_maximum_mi * pct_allocation_mi
	gen swp_allo_ag = swp_basemax_ag * swp_pctallo_ag
	gen swp_allo_mi = swp_basemax_mi * swp_pctallo_mi
	gen cvp_allo_ag = cvp_maxvol_ag * cvp_pctallo_ag
	gen cvp_allo_mi = cvp_maxvol_mi * cvp_pctallo_mi
	foreach var of varlist allocation* ??p_allo_?? {
		replace `var'=0 if missing(`var')
	}
	drop *pct*allo* rights_pod_l*itude rights_m*_year rights_diversion* l??_manual

	* aggregate to HUC8 by year
	collapse (sum) vol_deliv_cy-rights_avgdivert_mi allocation-cvp_allo_mi, by(huc8 year)
	isid huc8 year

	* allocations: reconstruct percentages
	gen pct_allocation = allocation / vol_maximum
	gen pct_allocation_ag = allocation_ag / vol_maximum_ag
	gen pct_allocation_mi = allocation_mi / vol_maximum_mi
	gen swp_pctallo_ag = swp_allo_ag / swp_basemax_ag
	gen swp_pctallo_mi = swp_allo_mi / swp_basemax_mi
	gen cvp_pctallo_ag = cvp_allo_ag / cvp_maxvol_ag
	gen cvp_pctallo_mi = cvp_allo_mi / cvp_maxvol_mi
	drop allocation* ??p_allo_??

	* save
	isid huc8 year
	sort huc8 year
	labelAllocationVariables
	compress
	save "$PREPPED/allocations_aggregate_huc8.dta", replace
	export delimited "$PREPPED/allocations_aggregate_huc8.csv", replace


// b. Geography: DAUCo / PA / county

	* load point users
	use "$PREPPED/allocations_subset_pointusers.dta", clear
	drop if missing(dauco_id)				// drops 608 obs & 0.07% of volume
	drop huc8*

	* append polygon users
	append using "$PREPPED/allocations_subset_polygonusersXdauco.dta"
	drop user_id-user_area

	* keep only years with full data
	drop if missing(vol_deliv_cy)

	* allocations: go from percentages to volumes for aggregation
	gen allocation = vol_maximum * pct_allocation
	gen allocation_ag = vol_maximum_ag * pct_allocation_ag
	gen allocation_mi = vol_maximum_mi * pct_allocation_mi
	gen swp_allo_ag = swp_basemax_ag * swp_pctallo_ag
	gen swp_allo_mi = swp_basemax_mi * swp_pctallo_mi
	gen cvp_allo_ag = cvp_maxvol_ag * cvp_pctallo_ag
	gen cvp_allo_mi = cvp_maxvol_mi * cvp_pctallo_mi
	foreach var of varlist allocation* ??p_allo_?? {
		replace `var'=0 if missing(`var')
	}
	drop *pct*allo* rights_pod_l*itude rights_m*_year rights_diversion* l??_manual

	* aggregate to DAUCo by year
	collapse (sum) vol_deliv_cy-rights_avgdivert_mi allocation-cvp_allo_mi, by(year dauco_id-dauco_pctcrop)
	sort dauco_id year
	isid dauco_id year
	tempfile dauco
	save `dauco'
	
	
	* save DAUCo-level dataset

		* allocations: reconstruct percentages
		gen pct_allocation = allocation / vol_maximum
		gen pct_allocation_ag = allocation_ag / vol_maximum_ag
		gen pct_allocation_mi = allocation_mi / vol_maximum_mi
		gen swp_pctallo_ag = swp_allo_ag / swp_basemax_ag
		gen swp_pctallo_mi = swp_allo_mi / swp_basemax_mi
		gen cvp_pctallo_ag = cvp_allo_ag / cvp_maxvol_ag
		gen cvp_pctallo_mi = cvp_allo_mi / cvp_maxvol_mi

		* save
		isid dauco_id year
		sort dauco_id year
		preserve
			drop allocation* ??p_allo_??
			labelAllocationVariables
			compress
			save "$PREPPED/allocations_aggregate_dauco.dta", replace
			export delimited "$PREPPED/allocations_aggregate_dauco.csv", replace
		restore

		
	* save datasets at other levels
	
		local var_dau dau_code
		local var_pa pa_code
		local var_county county_name

		foreach level in dau pa county {
		
			* collapse to level
			use `dauco', clear
			collapse (sum) vol_deliv_cy-rights_avgdivert_mi allocation-cvp_allo_mi, by(year `var_`level'')
			sort `var_`level'' year
			isid `var_`level'' year
			
			* allocations: reconstruct percentages
			gen pct_allocation = allocation / vol_maximum
			gen pct_allocation_ag = allocation_ag / vol_maximum_ag
			gen pct_allocation_mi = allocation_mi / vol_maximum_mi
			gen swp_pctallo_ag = swp_allo_ag / swp_basemax_ag
			gen swp_pctallo_mi = swp_allo_mi / swp_basemax_mi
			gen cvp_pctallo_ag = cvp_allo_ag / cvp_maxvol_ag
			gen cvp_pctallo_mi = cvp_allo_mi / cvp_maxvol_mi
			drop allocation* ??p_allo_??
			
			* merge in PA-level area and crop area
			merge m:1 `var_`level'' using "$DATA_TEMP/polygons_`level'.dta"
				drop if _merge==2
				assert _merge==3
				drop _merge
			order `level'_*, after(year)

			* save
			isid `var_`level'' year
			sort `var_`level'' year
			labelAllocationVariables
			compress
			save "$PREPPED/allocations_aggregate_`level'.dta", replace
			export delimited "$PREPPED/allocations_aggregate_`level'.csv", replace

		}
		
