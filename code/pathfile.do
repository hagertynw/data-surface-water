
clear all
set more off
pause on


// Set root directory
if "`c(os)'"=="Windows" {
	global ROOT "H:/git/CA_surface_water"
}
else {
	global ROOT "/bbkinghome/nhagerty/git/CA-surface-water"
}


* raw data
global DATA_SWP		"$ROOT/data/swp"
global DATA_CVP		"$ROOT/data/cvp"
global DATA_LOCO	"$ROOT/data/colorado"
global DATA_RIGHTS	"$ROOT/data/rights"
global DATA_GIS		"$ROOT/data/gis"

* reference materials
global REF_NAMES	"$ROOT/data"
global REF_KINGS	"$ROOT/data/conglomerates/kings"
global REF_KERN		"$ROOT/data/conglomerates/kern"
global REF_GEOLOC	"$ROOT/data"

* GIS materials
global GIS_SHP		"$ROOT/gis/shapefile_output"
global GIS_TAB		"$ROOT/gis/table_output"

* programs
global CODE			"$ROOT/code"

* intermediate datasets
global DATA_TEMP	"$ROOT/temp"

* final processed datasets
global PREPPED		"$ROOT/output"







