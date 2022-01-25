
// Purpose: Load shapefiles and their intersections

// Convert shapefiles to dta
cd "$GIS_SHP"
spshape2dta users_final, replace
spshape2dta dauco_final, replace
spshape2dta huc8_final, replace

// Prepare master names list
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


// Prepare HUC8 shapefile table
use "$GIS_SHP/huc8_final.dta", clear
keep HUC_8 huc8_area huc8_pctcr _ID
rename HUC_8 huc8
rename huc8_pctc huc8_pctcrop
replace huc8_pctcrop=. if huc8_pctcrop==0
replace huc8_pctcrop=huc8_pctcrop-1
isid huc8
save "$DATA_TEMP/polygons_huc8.dta", replace


// Prepare DAUCO shapefile table
use "$GIS_SHP/dauco_final.dta", clear
keep dauco_id DAU_CODE DAU_NAME PSA_CODE PSA_NAME HR_CODE HR_NAME PA_NO 	///
	 COUNTY_NAM COUNTY_COD COUNTY_ANS dauco_area dauco_pctc _ID
order dauco_id, first
isid dauco_id
rename DAU_CODE dau_code
rename DAU_NAME dau_name
rename PSA_CODE psa_code
rename PSA_NAME psa_name
rename HR_CODE hr_code
rename HR_NAME hr_name
rename PA_NO pa_code
rename COUNTY_NAM county_name
rename COUNTY_COD county_code
rename COUNTY_ANS county_ansi
rename dauco_pctc dauco_pctcrop
replace dauco_pctcrop=. if dauco_pctcrop==0
replace dauco_pctcrop=dauco_pctcrop-1
save "$DATA_TEMP/polygons_dauco.dta", replace


// Prepare zipcode shapefile table
*use "$GIS_SHP/zipcodes.dta", clear



// Prepare tables for more aggregated geographies

	* DAU
	use "$DATA_TEMP/polygons_dauco.dta", clear
	gen dauco_cropland = dauco_area * dauco_pctcrop
	collapse (sum) dau_area=dauco_area dau_cropland=dauco_cropland, by(dau_code)
	gen dau_pctcrop = dau_cropland/dau_area
	isid dau_code
	count
	save "$DATA_TEMP/polygons_dau.dta", replace

	* PA
	use "$DATA_TEMP/polygons_dauco.dta", clear
	gen dauco_cropland = dauco_area * dauco_pctcrop
	collapse (sum) pa_area=dauco_area pa_cropland=dauco_cropland, by(pa_code)
	gen pa_pctcrop = pa_cropland/pa_area
	isid pa_code
	count
	save "$DATA_TEMP/polygons_pa.dta", replace

	* County
	use "$DATA_TEMP/polygons_dauco.dta", clear
	gen dauco_cropland = dauco_area * dauco_pctcrop
	collapse (sum) county_area=dauco_area county_cropland=dauco_cropland, by(county_name)
	gen county_pctcrop = county_cropland/county_area
	isid county_name
	count
	save "$DATA_TEMP/polygons_county.dta", replace



// Prepare districts shapefile table

	use "$GIS_SHP/users_final.dta", clear
	order user_id source username pwsid AGENCYUNIQ user_x user_y totarea
	keep user_id-totarea
	rename totarea user_area
	rename username user
	replace user=upper(user)
	replace AGENCYUNIQ=. if AGENCYUNIQ==0

	* merge standardized names
	merge m:1 user using `masternames', gen(mergemaster)
		drop if mergemaster==2
	drop if mergemaster==1 & user==""
	drop if mergemaster==1 & regexm(user,"DDIGATION")
	assert mergemaster==3
	drop mergemaster

	* drop duplicates within sources (keep largest shape)
	gsort std_name source -user_area
	by std_name source: keep if _n==1
	isid std_name source

	* apply information to all obs within name
	gsort std_name -pwsid
	by std_name: replace pwsid=pwsid[1] if pwsid==""
	sort std_name AGENCYUNIQ
	by std_name: replace AGENCYUNIQ=AGENCYUNIQ[1] if AGENCYUNIQ==.

	* drop duplicates across sources (in priority order; keep information from all)
	gen priority = .
		replace priority=1 if source=="agencies"
		replace priority=2 if source=="federal"
		replace priority=3 if source=="swp"
		replace priority=4 if source=="private"
		replace priority=5 if source=="mojave"
		replace priority=6 if source=="cehtp"
	sort std_name priority
	by std_name: keep if _n==1
	drop priority
	rename source shape_source

	* clean up
	isid user_id
	isid std_name
	sort std_name
	order std_name user_x user_y user_area, first
	compress

	* save all shapes
	save "$DATA_TEMP/polygons_district.dta", replace


	
// Prepare list of intersections between districts and HUC8
import excel using "$GIS_TAB/users_huc8.xls", firstrow clear

	* clean up
	keep user_id HUC_8 iuser*
	rename HUC_8 huc8
	replace iuser_pctcrop=. if iuser_pctcrop==0
	replace iuser_pctcrop=iuser_pctcrop-1

	* merge district shapes
	merge m:1 user_id using "$DATA_TEMP/polygons_district.dta"
		drop if _merge==1		// user duplicates
		drop if _merge==2		// outside of state or on the Channel Islands
		assert _merge==3
		drop _merge
	isid user_id huc8
	isid std_name huc8
	order std_name-AGENCYUNIQ, after(user_id)

	* calculate cropland in each shape
	* calculate total & proportions of area and cropland in district belonging to each piece	
	gen double iuser_cropland = iuser_area * iuser_pctcrop
	bys std_name: egen double user_cropland = total(iuser_cropland)
	bys std_name: egen double user_totarea = total(iuser_area)
	gen double ishare_cropland = iuser_cropland/user_cropland
	gen double ishare_area = iuser_area/user_totarea

	* clean up
	count
	isid std_name huc8
	sort std_name huc8
	compress
	save "$DATA_TEMP/intersections_districtXhuc8.dta", replace

	* expand to year, for merging
	expand 41
	bys std_name huc8: gen year = 1980+_n
	save "$DATA_TEMP/intersections_districtXhuc8Xyears.dta", replace

	

// Prepare list of intersections between districts and DAU-counties
import excel using "$GIS_TAB/users_dauco.xls", firstrow clear

	* clean up
	keep user_id dauco_id iuser*
	replace iuser_pctcrop=. if iuser_pctcrop==0
	replace iuser_pctcrop=iuser_pctcrop-1

	* merge district shapes
	merge m:1 user_id using "$DATA_TEMP/polygons_district.dta"
		drop if _merge==1		// user duplicates
		drop if _merge==2		// outside of state or on the Channel Islands
		assert _merge==3
		drop _merge
	isid user_id dauco_id
	isid std_name dauco_id
	order std_name-AGENCYUNIQ, after(user_id)

	* calculate cropland in each shape
	* calculate total & proportions of area and cropland in district belonging to each piece	
	gen double iuser_cropland = iuser_area * iuser_pctcrop
	bys std_name: egen double user_cropland = total(iuser_cropland)
	bys std_name: egen double user_totarea = total(iuser_area)
	gen double ishare_cropland = iuser_cropland/user_cropland
	gen double ishare_area = iuser_area/user_totarea

	* clean up
	count
	isid std_name dauco_id
	sort std_name dauco_id
	compress
	save "$DATA_TEMP/intersections_districtXdauco.dta", replace

	* expand to year, for merging
	expand 41
	bys std_name dauco_id: gen year = 1980+_n
	save "$DATA_TEMP/intersections_districtXdaucoXyears.dta", replace

