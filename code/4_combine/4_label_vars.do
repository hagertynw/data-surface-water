
// Purpose: Match users/districts to geographic polygons & distribute volumes across multiple areas

clear all
pause on
set more off
ssc install geoinpoly

// Set root and load pathfile
if "`c(os)'"=="Windows" {
	local ROOT "H:"
}
else {
	local ROOT "/bbkinghome/nhagerty"
}
qui do "`ROOT'/analysis/allo/do/allo_pathfile.do"


local allocation_datasets	allocations_subset_pointusers			///
							allocations_subset_polygonusers			///
							allocations_subset_polygonusersXdauco	///
							allocations_subset_polygonusersXhuc8	///
							allocations_aggregate_huc8				///
							allocations_aggregate_dauco				///
							allocations_aggregate_dau				///
							allocations_aggregate_pa				///
							allocations_aggregate_county

foreach fname of local allocation_datasets {
								
	use "$PREPPED/`fname'.dta", clear

	cap label var year "Year"
	cap label var std_name "User name, standardized"
	cap label var user_id "User ID number (internal to data)"
	cap label var user_centroid_lat "Latitude of user's polygon centroid"
	cap label var user_centroid_lon "Longitude of user's polygon centroid"
	cap label var user_area "Total area of user's polygon (km^2)"
	cap label var user_cropland "Cropland area within user's polygon (km^2)"
	cap label var vol_deliv_cy "Deliveries & diversions, all uses, calendar year (af)"
	cap label var vol_deliv_cy_ag "Deliveries & diversions, ag uses, calendar year (af)"
	cap label var vol_deliv_cy_mi "Deliveries & diversions, M&I uses, calendar year (af)"
	cap label var vol_deliv_wy "Deliveries & diversions, all uses, water year (af)"
	cap label var vol_deliv_wy_ag "Deliveries & diversions, ag uses, water year (af)"
	cap label var vol_deliv_wy_mi "Deliveries & diversions, M&I uses, water year (af)"
	cap label var vol_maximum "Maximum volume in contracts & rights, all uses, time invariant (af/year)"
	cap label var vol_maximum_ag "Maximum volume in contracts & rights, ag uses, time invariant (af/year)"
	cap label var vol_maximum_mi "Maximum volume in contracts & rights, M&I uses, time invariant (af/year)"
	cap label var pct_allocation "Allocation percentage, weighted overall average, all uses"
	cap label var pct_allocation_ag "Allocation percentage, weighted overall average, ag uses"
	cap label var pct_allocation_mi "Allocation percentage, weighted overall average, M&I uses"
	cap label var swp_deliveries "State Water Project deliveries, all uses (af)"
	cap label var swp_deliveries_ag "State Water Project deliveries, ag uses (af)"
	cap label var swp_deliveries_mi "State Water Project deliveries, M&I uses (af)"
	cap label var swp_maxvol "State Water Project maximum volume, year-specific, all uses (af)"
	cap label var swp_maxvol_ag "State Water Project maximum volume, year-specific, ag uses (af)"
	cap label var swp_maxvol_mi "State Water Project maximum volume, year-specific, M&I uses (af)"
	cap label var swp_basemax "State Water Project maximum volume, time-invariant baseline, all uses (af)"
	cap label var swp_basemax_ag "State Water Project maximum volume, time-invariant baseline, ag uses (af)"
	cap label var swp_basemax_mi "State Water Project maximum volume, time-invariant baseline, M&I uses (af)"
	cap label var swp_pctallo_ag "State Water Project allocation percentage, ag uses"
	cap label var swp_pctallo_mi "State Water Project allocation percentage, ag uses"
	cap label var cvp_deliveries_cy "Central Valley Project deliveries, all uses, calendar year"
	cap label var cvp_deliveries_cy_ag "Central Valley Project deliveries, ag uses, calendar year"
	cap label var cvp_deliveries_cy_mi "Central Valley Project deliveries, M&I uses, calendar year"
	cap label var cvp_deliveries_wy "Central Valley Project deliveries, all uses, water year"
	cap label var cvp_deliveries_wy_ag "Central Valley Project deliveries, ag uses, water year"
	cap label var cvp_deliveries_wy_mi "Central Valley Project deliveries, M&I uses, water year"
	cap label var cvp_maxvol "Central Valley Project maximum volume, time-invariant baseline, all uses (af)"
	cap label var cvp_maxvol_ag "Central Valley Project maximum volume, time-invariant baseline, ag uses (af)"
	cap label var cvp_maxvol_mi "Central Valley Project maximum volume, time-invariant baseline, M&I uses (af)"
	cap label var cvp_pctallo "Central Valley Project allocation percentage, all uses"
	cap label var cvp_pctallo_ag "Central Valley Project allocation percentage, ag uses"
	cap label var cvp_pctallo_mi "Central Valley Project allocation percentage, M&I uses"
	cap label var loco_maxvol "Lower Colorado maximum entitlement, all uses (af)"
	cap label var loco_maxvol_ag "Lower Colorado maximum entitlement, ag uses (af)"
	cap label var loco_maxvol_mi "Lower Colorado maximum entitlement, M&I uses (af)"
	cap label var loco_deliveries "Lower Colorado deliveries, all uses (af)"
	cap label var loco_deliveries_ag "Lower Colorado deliveries, ag uses (af)"
	cap label var loco_deliveries_mi "Lower Colorado deliveries, M&I uses (af)"
	cap label var rights_avgdivert "Water right diversions, time-invariant estimate, all uses (af)"
	cap label var rights_avgdivert_ag "Water right diversions, time-invariant estimate, ag uses (af)"
	cap label var rights_avgdivert_mi "Water right diversions, time-invariant estimate, M&I uses (af)"
	cap label var rights_pod_latitude "Water right latitude, point-of-diversion of largest right"
	cap label var rights_pod_longitude "Water right longitude, point-of-diversion of largest right"
	cap label var rights_min_year "Water right claim year, earliest"
	cap label var rights_max_year "Water right claim year, latest"
	cap label var rights_mean_year "Water right claim year, mean"
	cap label var rights_med_year "Water right claim year, median"
	cap label var rights_diversion_ag "Water right diversions, year-specific, ag uses (af)"
	cap label var rights_diversion_mi "Water right diversions, year-specific, M&I uses (af)"
	cap label var lat_manual "Latitude of user, manually geolocated"
	cap label var lon_manual "Longitude of user, manually geolocated"
	cap label var dauco_id "DAUCo (DAU X county) code"
	cap label var dau_code "DAU (Detailed Analysis Unit) code"
	cap label var dau_name "DAU (Detailed Analysis Unit) name"
	cap label var psa_code "PSA (Planning Sub-Area) code"
	cap label var psa_name "PSA (Planning Sub-Area) name"
	cap label var hr_code "HR (Hydrologic Region) code"
	cap label var hr_name "HR (Hydrologic Region) name"
	cap label var pa_code "PA (Planning Area) code"
	cap label var county_name "County name"
	cap label var county_code "County code"
	cap label var county_ansi "County code (ANSI)"
	cap label var dauco_area "DAUCo area, total (km^2)"
	cap label var dauco_pctcrop "Watershed cropland, proportion of total area"
	cap label var huc8 "Watershed (8-digit hydrologic unit code)"
	cap label var huc8_area "Watershed (8-digit HUC) area, total (km^2)"
	cap label var huc8_pctcrop "Watershed (8-digit HUC) cropland, proportion of total area"
	cap label var dau_area "DAU (Detailed Analysis Unit) area, total (km^2)"
	cap label var dau_cropland "DAU (Detailed Analysis Unit) cropland (km^2)"
	cap label var dau_pctcrop "DAU (Detailed Analysis Unit) cropland, proportion of total area"
	cap label var pa_area "PA (Planning Area) area, total (km^2)"
	cap label var pa_cropland "PA (Planning Area) cropland (km^2)"
	cap label var pa_pctcrop "PA (Planning Area) cropland, proportion of total area"
	cap label var county_area "County area, total (km^2)"
	cap label var county_cropland "County cropland (km^2)"
	cap label var county_pctcrop "County cropland, proportion of total area"

	describe, short
	pause
	save "$PREPPED/`fname'.dta", replace

}
