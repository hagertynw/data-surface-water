
# California Surface Water Data

Maintained by [Nick Hagerty](https://www.nickhagerty.com/), Montana State University

This repository contains data on volumes of reported deliveries, diversions, and allocations of surface water in California, along with all scripts and raw data used to produce it. 

The data cover all users in the state at the highest level of distribution (i.e., the wholesale level), by user, sector and year, from 1993 through 2021. It is assembled entirely from other publicly available sources. This database is the only publicly available source I am aware of that:

* covers the entire state of California
* is reported, not estimated
* is non-anonymous (links water use to the specific identities of the water users)
* is spatially explicit (links water use to the place it is used, as granularly as possible)

This dataset embeds many decisions made for particular purposes. **Before using it for your own purposes, please read the documentation and understand how it was constructed** (and ask me if I've left something out). There is a good chance you will want to make decisions that are different from mine. Generally, this data is constructed in ways that are well-suited to economics research and causal inference. It focuses on clearly attributing and accounting for changes in water supplies over time and differences across well-defined geographical areas (in order, for example, to minimize bias in fixed effect regressions). It is *not* constructed for the purpose of estimating or predicting water use at a given time and place as accurately as possible. If this is your goal, other data sources may fit your needs better (such as the [water balance data](https://data.cnra.ca.gov/dataset/water-plan-water-balance-data) from the California Water Plan, or [OpenET](https://openetdata.org/)) or alternatively you might use this data as an input to further analysis.

**Use:** You are welcome to modify and use this data and code as you like. If you do, please acknowledge the source and cite the paper for which I assembled it, ["Adaptation to Water Scarcity in Irrigated Agriculture."](https://hagertynw.github.io/webfiles/Surface_Water_Adaptation.pdf) Please also send me a note and let me know how you're using it - I would love to hear. My contact information is [here](https://www.nickhagerty.com/).

**Contributions:** I would love to see this database grow into a more useful resource for the water research community. If you would like to help, just open a pull request or contact me to discuss. Here are some useful tasks I see:

* Update with the most recent year(s) of data.
* Finish converting the code to R.
* Update the water rights data with the newly available eWRIMS database.
* Add and document other output formats you find useful for your own work.
* Digitize Central Valley Project deliveries for 1985-92 in order to extend the database further back in time.
* Add data from other states (toward creating a unified surface water database for the entire American West).

**More info:** [Brief overview](#brief-guide-to-the-data)
| [Output files](#output-files)
| [Using the data](#using-the-data)
| [Code](#about-the-code)
| [Codebook](#further-documentation)
| [Construction details](#further-documentation)


## Brief overview of the data

**Deliveries and diversions, or supplies,** are the quantities of water actually received by water users. They come from four sources: deliveries from the Central Valley Project (CVP), the State Water Project (SWP), and the Lower Colorado Project, and diversions on the basis of surface water rights. For water rights, historical user-specific data is unavailable, so fixed quantities are created from the most reliable data available and imputed for all years in the dataset. (This is a reasonable approximation for many purposes, since rights have changed little since 1980 and beneficial-use requirements discourage under-consumption. Diversions on the basis of water rights likely fall in drought years, but no systematic data is available, and the year-to-year variation is likely much smaller than for the projects, which themselves hold more junior rights.)

**Allocations** are the quantities of surface water assigned to users each year. They are calculated by multiplying maximum entitlements by allocation percentages. Maximum entitlements, set in long-term project contracts or permanent water rights, are set to be time-invariant in this dataset despite minor changes over time. Allocation percentages, set by annual regulatory determinations, are determined yearly for each of 14 separate contract types in the federal and state water projects. For water rights, allocation percentages are set to 100% since they have essentially never been curtailed directly by the state.

**Water user polygons** link users to specific geographical areas whenever possible. By volume, the vast majority of water use is linked to spatial boundary information. Nearly all other water users are spatially identified by the point of diversion.

A **crosswalk file** matches users across different datasets. It corrects for variations and errors in names as well as mergers and name changes across time.


## Output files

Filename | Primary key (unique ID) | Description
--- | --- | ---
allocations_subset_polygonusers.csv	| year X user	| Water volumes for all polygon users (exact service area is known from a shapefile)
allocations_subset_pointusers.csv	| year X user	| Water volumes for all point users (no shapefile available; only individual coordinates known)
allocations_subset_polygonusersXdauco.csv |	year X user X DAU-County |	Fractional water volumes by geographical area (DAUCo), polygon users only
allocations_subset_polygonusersXhuc8.csv | year X user X HUC8	| Fractional water volumes by geographical area (HUC8), polygon users only
allocations_aggregate_dauco.csv |	year X DAU-County	| Aggregate water volumes per DAU-County, all users
allocations_aggregate_dau.csv |	year X Detailed Analysis Unit |	Aggregate water volumes per detailed analysis unit (DAU), all users
allocations_aggregate_pa.csv |	year X Planning Area |	Aggregate water volumes per planning area (PA), all users
allocations_aggregate_county.csv |	year X county	| Aggregate water volumes per county, all users
allocations_aggregate_huc8.csv |	year X watershed (8-digit HUC) |	Aggregate water volumes per watershed (8-digit hydrologic unit code), all users

*Detailed analysis unit (DAU), planning area (PA), and DAU-County (DAUCo) are spatial units defined by the California Department of Water Resources (DWR). Hydrologic unit codes are defined by the U.S. Geological Survey (USGS).*


## Using the data

There are two main ways to use the data, depending on how you intend to aggregate it spatially:

1. **Use an aggregated dataset.** For certain geographical divisions, I've already done the aggregation (county, PA, DAU, DAUxCounty, HUC8 or lower). If one of these works for your purposes, you can simply merge in the corresponding `allocations_aggregate_*.csv` dataset.

2. **Aggregate the data yourself.** If you need to aggregate to a different geography, you have to merge in 2 types of data: polygon users and point users.
    * **Polygon users** (the most by volume) are users for which spatial boundary information is available (in `shapefile_output/users_final.shp`). Intersect this shapefile with your preferred geography, merge in `allocations_subset_polygonusers.csv`, and decide how you want to apportion the water quantities across the intersection pieces.
    * **Point users** (the most by count) are users for which we only know the point of diversion. Perform a spatial join of `allocations_subset_pointusers.csv` to your preferred geography. Keep in mind that the point of diversion is not the same as the place of use, which is unobserved.

**Choice of geographical division:** For point users, the resulting data is highly sensitive to the choice of geographical division, due to the unobserved distance between the point of diversion and place of use. Aggregation to finer spatial units results in noisy and nonsensical values due to the imprecise locations, while aggregation to coarser units gives up accuracy. I find planning areas to be a reasonable intermediate choice. I also prefer management-based geographical divisions (e.g., planning areas) to watersheds (e.g., HUC8) because watershed boundaries split at rivers, whereas points of diversion are located on rivers and may have places of use on either side of the river.

**Example:** In my paper on adaptation to surface water scarcity (linked above), I wanted to compare land use outcomes across water districts that have different levels of agricultural water supplies. District-specific supplies are given in the polygon users data subset, but I also needed a way to incorporate the point users despite the unobserved place of use. I chose to use a spatial unit of analysis I call zones, defined by the intersection of district (i.e., user) boundaries with each other and also with planning areas. I spread all polygon-user water volumes evenly across the cropland within a district, all point-user water volumes evenly across the cropland within a planning area, and summed the per-acre water volumes across the district and planning area of each zone.

**Fractional volumes:** Either of these datasets (`allocations_subset_polygonusersXdauco.csv` and `allocations_subset_polygonusersXhuc8.csv`) can substitute for the polygon users dataset. They are intended to make it easier to spatially aggregate the polygon users, by skipping the intersection and apportionment steps. Summing volumes to year X user across geographies in either of these datasets will recover `allocations_subset_polygonusers.csv`. (M&I water volumes are apportioned evenly over area, according to the fraction of the user polygon that falls within each of the DAUCo or HUC8 geographical divisions. Ag water volumes are apportioned evenly over cropland area, according to the fraction of cropland within the user polygon that falls within each geographical division, using the 2015 cropland mask from the USDA's Cropland Data Layer.)


## About the code

The code to produce the data is currently written mostly in Stata. One script is written in Python but relies on an ArcGIS license. My goal is to convert all code to open-source languages so that everyone can use and modify the code.

The `R-conversion` subfolder contains significant progress toward converting the code to R. (This effort so far has been generously supported by Fiona Burlig, Louis Preonas, and Matt Woerman.) However, the R code currently does not generate output identical to the Stata code, and the differences are not yet documented. Any help with this effort would be greatly appreciated.

The `code/run_all.do` script lists all other scripts necessary to reproduce the data, along with their inputs and outputs. Most file paths are defined in `code/pathfile.do`. To run the code on your own computer, the only thing you should need to change is the definition of the project root directory in two places: `code/run_all.do` and `code/1_users/make_users.py`.


## Further documentation

[Codebook](https://github.com/hagertynw/data-surface-water/blob/master/codebook.xlsx?raw=true) (definitions of variables in each dataset). Notes: ag = agricultural, M&I = municipal and industrial, af = acre-feet (a unit of volume). The water year runs from October 1 of the previous year through September 30 of the stated year.

[Details of data sources and processing choices](https://github.com/hagertynw/data-surface-water/blob/master/construction-details.pdf?raw=true).

