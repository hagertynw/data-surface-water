
args ROOT
clear all
set more off
pause on


* raw data
global DATA_SWP		"`ROOT'/raw/swp"
global DATA_CVP		"`ROOT'/raw/cvp"
global DATA_LOCO	"`ROOT'/raw/colorado"
global DATA_RIGHTS	"`ROOT'/raw/rights"
global DATA_GIS		"`ROOT'/raw/gis"

* reference materials
global REF_NAMES	"`ROOT'/raw"
global REF_KINGS	"`ROOT'/raw/conglomerates/kings"
global REF_KERN		"`ROOT'/raw/conglomerates/kern"
global REF_GEOLOC	"`ROOT'/raw"

* GIS materials
global GIS_SHP		"`ROOT'/gis/shapefile_output"
global GIS_TAB		"`ROOT'/gis/table_output"

* programs
global CODE			"`ROOT'/code"

* intermediate datasets
global DATA_TEMP	"`ROOT'/temp"

* final processed datasets
global PREPPED		"`ROOT'/output"







