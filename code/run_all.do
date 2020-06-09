
clear all
set more off
pause on

// Set root
if "`c(os)'"=="Windows" {
	local ROOT "H:"
}
else {
	local ROOT "/bbkinghome/nhagerty"
}

// Set path to pathfile
local pathpath "`ROOT'/analysis/allo/do"

// Run file to set path globals
do "`pathpath'/allo_pathfile.do"



// I. CLEAN WATER RIGHTS DATA

// 1. Clean eWRIMS data (statewide data, with 2010-13 diversions)
* inputs:	$DATA_RIGHTS/ewrims/wr70_corrected.csv
* outputs:	$DATA_TEMP/waterrights_ewrims.dta
do "$CODE/2_rights/1_rights_clean_ewrims.do"

// 2. Clean WRUDS data (Central Valley only, with 2014 diversions)
* inputs:	$DATA_RIGHTS/drought_analysis/info_order_demand/WRUDS 2015-06-15.xlsx
* outputs:	$DATA_TEMP/waterrights_wruds.dta
do "$CODE/2_rights/2_rights_clean_wruds.do"

// 3. Combine datasets and calculate annual diversions
* inputs:	$DATA_TEMP/waterrights_ewrims.dta
*			$DATA_TEMP/waterrights_wruds.dta
* outputs:	$DATA_TEMP/waterrights_diversions.dta
do "$CODE/2_rights/3_rights_combine.do"

// 4. Calculate diversions per user and sector
* inputs:	$DATA_TEMP/waterrights_diversions.dta
*			$DATA_TEMP/userXdauco.dta
*			$REF_NAMES/names_crosswalk.xlsx
*			$REF_KINGS/kings_members.xlsx
* outputs:	$PREPPED/allocations_source_rights_means.dta
*			$PREPPED/allocations_source_rights_yearly.dta
do "$CODE/2_rights/4_rights_calculate.do"



// II. CLEAN PROJECT DATA

// State Water Project
* inputs:	$DATA_SWP/bulletin_132/B132-18 Tables.xlsx
*			$DATA_SWP/swp_contractors.csv
*			$DATA_SWP/pct_allocations.xlsx
*			$REF_NAMES/names_crosswalk.xlsx
*			$REF_KERN/swp-contracts-in-kern-county.xlsx
* outputs:	$PREPPED/allocations_source_swp.dta
do "$CODE/3_projects/1_part_swp.do"

// Central Valley Project
* inputs:	$DATA_CVP/deliveries/deliveries 1993-1997.xlsx
*			$DATA_CVP/deliveries/deliveries 1998-2010.xlsx
*			$DATA_CVP/deliveries/deliveries 2011-2018.xlsx
*			$DATA_CVP/allocations.xlsx
*			$DATA_CVP/cvp_contractors.xlsx
*			$REF_NAMES/names_crosswalk.xlsx
* outputs:	$PREPPED/allocations_source_cvp.dta
do "$CODE/3_projects/1_part_cvp.do"

// Lower Colorado Project
* inputs:	$DATA_LOCO/accounting_reports.xlsx
*			$REF_NAMES/names_crosswalk.xlsx
* outputs:	$PREPPED/allocations_source_loco.dta
do "$CODE/3_projects/1_part_loco.do"



// III. COMBINE DATA

// 0. Create shapefiles of water districts and other geographical polygons
* inputs:	$DATA_GIS/dwr/watersheds/CA_SDE_Extraction_17Dec2008.mdb/WBD/HU12_polygon
*			$DATA_GIS/dwr/dau/dau_v2_105.shp
*			$DATA_GIS/dwr/districts/combined/water_agencies.shp
*			$DATA_GIS/ca_atlas/counties/cnty24k09_1_multipart.shp
*			$DATA_GIS/ca_atlas/districts/federal/WD-WaterUsers.mdb/FederalWaterUsers
*			$DATA_GIS/ca_atlas/districts/federal/WD-WaterUsers.mdb/Master
*			$DATA_GIS/ca_atlas/districts/state/wdst24.shp
*			$DATA_GIS/ca_atlas/districts/private/wdpr24.shp
*			$DATA_GIS/ca_atlas/mojave/Mojave_Water_Agency_Service_Area_Water_Companies_2012.shp
*			$DATA_GIS/cehtp/service_areas.shp
*			$DATA_GIS/nass_cdl/CMASK_2015_06.tif
* outputs:	$GIS_SHP/huc8_final.shp
*			$GIS_SHP/dauco_final.shp
*			$GIS_SHP/users_final.shp
*			$GIS_TAB/users_huc8.xls
*			$GIS_TAB/users_dauco.xls
*			$GIS_TAB/federal_table.xls
do "$CODE/make_users.py"

// 1. Prepare tables of geographical polygons
* inputs:	$GIS_SHP/users_final.shp
*			$GIS_SHP/dauco_final.shp
*			$GIS_SHP/huc8_final.shp
*			$GIS_TAB/users_huc8.xls
*			$GIS_TAB/users_dauco.xls
*			$REF_NAMES/names_crosswalk.xlsx
* outputs:	$DATA_TEMP/polygons_huc8.dta
*			$DATA_TEMP/polygons_dauco.dta
*			$DATA_TEMP/polygons_dau.dta
*			$DATA_TEMP/polygons_pa.dta
*			$DATA_TEMP/polygons_county.dta
*			$DATA_TEMP/polygons_district.dta
*			$DATA_TEMP/intersections_districtXhuc8.dta
*			$DATA_TEMP/intersections_districtXhuc8Xyears.dta
*			$DATA_TEMP/intersections_districtXdauco.dta
*			$DATA_TEMP/intersections_districtXdaucoXyears.dta
do "$CODE/4_combine/1_geographies.do"

// 2. Combine parts
* inputs:	$PREPPED/allocations_source_cvp.dta
*			$PREPPED/allocations_source_swp.dta
*			$PREPPED/allocations_source_loco.dta
*			$PREPPED/allocations_source_rights_means.dta
*			$PREPPED/allocations_source_rights_yearly.dta
* outputs:	$PREPPED/allocations_all.dta
do "$CODE/4_combine/2_combine_parts.do"

// 3. Match geographies
* inputs:	$PREPPED/allocations_all.dta
*			$REF_GEOLOC/manual_geolocating.xlsx
*			$GIS_SHP/dauco_final_shp.dta
*			$GIS_SHP/huc8_final_shp.dta
*			$DATA_TEMP/polygons_district.dta
*			$DATA_TEMP/polygons_dauco.dta
*			$DATA_TEMP/polygons_huc8.dta
*			$DATA_TEMP/polygons_pa.dta
*			$DATA_TEMP/intersections_districtXdauco.dta
*			$DATA_TEMP/intersections_districtXdaucoXyears.dta
*			$DATA_TEMP/intersections_districtXhuc8Xyears.dta
* outputs:	$PREPPED/allocations_subset_polygonusers.dta
*			$PREPPED/allocations_subset_polygonusersXdauco.dta
*			$PREPPED/allocations_subset_polygonusersXhuc8.dta
*			$PREPPED/allocations_subset_pointusers.dta
*			$PREPPED/allocations_aggregate_huc8.dta
*			$PREPPED/allocations_aggregate_dauco.dta
*			$PREPPED/allocations_aggregate_dau.dta
*			$PREPPED/allocations_aggregate_pa.dta
*			$PREPPED/allocations_aggregate_county.dta
do "$CODE/4_combine/3_match_geographies.do"


























