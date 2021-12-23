
# California Surface Water Data

Maintained by [Nick Hagerty](https://www.nickhagerty.com/), Montana State University

This repository contains data on reported deliveries, diversions, and allocations of surface water in California, along with all scripts and raw data used to produce it. 

The data cover all users in the state at the highest level of distribution (i.e., the wholesale level), by user, sector and year, from 1993 through 2016. It is assembled entirely from other publicly available sources. This database is the only publicly available source I am aware of that:

* covers the entire state of California
* is reported, not estimated
* is non-anonymous (links water use to the specific identities of the water users)
* is spatially explicit (links water use to the place it is used, as granularly as possible)

This dataset embeds many decisions made for particular purposes. **Before using it for your own purposes, please read the documentation and understand how it was constructed** (and ask me if I've left something out). There is a good chance you will want to make decisions that are different from mine. Generally, this data is constructed in ways that are well-suited to economics research and causal inference. It focuses on clearly attributing and accounting for changes in water supplies over time and differences across well-defined geographical areas (in order, for example, to minimize bias in fixed effect regressions). It is not constructed for the purpose of estimating or predicting water use at a given time and place as accurately as possible. If this is your goal, you may want to either use other data sources, or use this data as an input to further analysis.

**Use:** You are welcome to modify and use this data and code as you like. If you do, please acknowledge the source and cite the paper for which I assembled it, ["Adaptation to Water Scarcity in Irrigated Agriculture."](https://hagertynw.github.io/webfiles/Surface_Water_Adaptation.pdf) Please also send me a note and let me know how you're using it - I would love to hear. My contact information is [here](https://www.nickhagerty.com/).

**Contributions:** I would love to see this database grow into a more useful resource for the water research community. If you would like to help, just open a pull request or contact me to discuss. Here are some useful tasks I see:

* Update with the most recent year(s) of data.
* Finish converting the code to R (from Stata).
* Update the water rights data with the newly available eWRIMS database.
* Add and document other output formats you find useful for your own work.
* Digitize Central Valley Project deliveries for 1985-92 in order to extend the database further back in time.
* Add data from other states (toward creating a unified surface water database for the entire American West).

**More info:** [Brief guide to the data](#brief-guide-to-the-data)
| [Output files](#output-files)
| [Codebook (description of variables)](#further-documentation)
| [Details of data construction](#further-documentation)


## Brief guide to the data

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


## Further documentation

Codebook (definitions of variables in each dataset)

Notes: ag = agricultural, M&I = municipal and industrial, af = acre-feet, water year = October 1 of previous year through September 30 of stated year.

Details of data sources and processing choices

