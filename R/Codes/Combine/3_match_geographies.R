library(readr)
library(readxl)
library(foreign)
library(sf)
library(stringi)
library(ggplot2)
library(Hmisc)
library(raster)
library(rgdal)
library(tidyverse)
library(dplyr)
library(units)
library(haven)

setwd("/Users/shubhalakshminag/Desktop/CA_surface_water/MATCH")

rm(list=ls())

##Setting_directories (Change root directory while running codes)

Root<- "/Users/shubhalakshminag/Box/CA_Surface_water/"

# MANUAL GEOLOCATING DATA

DATA_GELOC<-paste0(Root, "data/")

#GIS_DATA

DATA_GIS<-paste0(Root, "R/GIS/")

#TEMP_FILE

DATA_TEMP<-	paste0( Root, "R/Temp/")

#FINAL_OUTPUT

OUTPUT<-paste0( Root, "R/Output/")

#LOADING INPUT DATA

manual_allocations<-read_excel(paste0(DATA_GELOC, "manual_geolocating.xlsx"))
load(paste0(OUTPUT, "allocations_all.Rdata"))
load(paste0(DATA_GIS, "dauco_final.Rdata"))
load(paste0(DATA_GIS, "huc8_final.Rdata"))
load(paste0(DATA_TEMP, "polygons_district.Rdata"))
load(paste0(DATA_TEMP, "polygons_dauco.Rdata"))
load(paste0(DATA_TEMP, "polygons_pa.Rdata"))
load(paste0(DATA_TEMP, "polygons_dau.Rdata"))
load(paste0(DATA_TEMP, "polygons_huc8.Rdata"))
load(paste0(DATA_TEMP, "intersections_districtXdauco.Rdata"))
load(paste0(DATA_TEMP, "intersections_districtXdaucoXyears.Rdata"))
load(paste0(DATA_TEMP, "intersections_districtXhuc8Xyears.Rdata"))

# PREPARING LIST OF MANUAL GEOLOCATIONS

manual_allocations<-manual_allocations%>%
  dplyr::select(std_name, lat, lon)%>%
  rename(lat_manual=lat,
         lon_manual=lon)

#// 1. SEPARATE USERS INTO POLYGONS AND POINTS
#(Polygon = we know the exact service area of this water user)
#(Point = we only know a single lat/lon for the user)

#Save set of point users
pointusers<-allocations_all%>%
  anti_join(polygon_district)

polygonusers<-allocations_all%>%
  inner_join(polygon_district)%>%
  rename(user_centroid_lon=user_x,
         user_centroid_lat=user_y)

polygonusers<-polygonusers%>%
  dplyr::select(!c("shape_source", "user" ,"pwsid", "AGENCYUNIQ", "mergemaster"))

#MAKE DATASET OF POLYGON USERS
#Prepare total cropland area (from dauco pieces)

cropland<-intersections_districtXdauco%>%
  dplyr::select(std_name, user_cropland)%>%
  distinct()

#Load polygon users and merge in cropland area

allocations_subset_polygonusers<-polygonusers%>%
  inner_join(cropland)%>%
  dplyr::select(year, std_name,  user_id, user_centroid_lat,
         user_centroid_lon, user_area, user_cropland, everything())%>%
  arrange(std_name, year)

save(allocations_subset_polygonusers, file = paste0(OUTPUT,
                                                    "allocations_subset_polygonusers.RData"))


#3. MAKE DATASETS OF POLYGON USERS X GEOGRAPHIES
#(Each has N observations for each polygon user, where N is the number of
#unique geographies the user's polygon intersects with)

allocations_subset_polygonusersXdauco<-polygonusers%>%
  inner_join(intersections_districtXdaucoXyears, by=c("year", "std_name"))

#allocate district's water volumes across its DAUCo pieces
#ag water: on the basis of cropland area
#m&i water: on the basis of total land area

volvars<-vars(vol_deliv_cy, vol_deliv_wy, vol_maximum,
                   swp_deliveries, swp_maxvol, swp_basemax,
                   cvp_deliveries_cy, cvp_deliveries_wy, cvp_maxvol,
                   loco_maxvol, loco_deliveries,	rights_avgdivert)

volvars_list<-list("vol_deliv_cy", "vol_deliv_wy", "vol_maximum",
              "swp_deliveries", "swp_maxvol", "swp_basemax",
              "cvp_deliveries_cy", "cvp_deliveries_wy", "cvp_maxvol",
              "loco_maxvol", "loco_deliveries",	"rights_avgdivert")


allocations_subset_polygonusersXdauco<-allocations_subset_polygonusersXdauco%>%
  rename_at(volvars, funs(paste0("tot_", .)))%>%
  rename_at(vars(ends_with("ag")), funs(paste0("tot_", .)))%>%
  rename_at(vars(ends_with("mi")), funs(paste0("tot_", .)))

for(i in 1:12){
  allocations_subset_polygonusersXdauco<-allocations_subset_polygonusersXdauco%>%
    mutate(!!paste0(volvars_list[[i]], "_ag"):=
             get(!!paste0("tot_",volvars_list[[i]], "_ag"))*ishare_cropland,
           !!paste0(volvars_list[[i]], "_mi"):=
             get(!!paste0("tot_",volvars_list[[i]], "_mi"))*ishare_cropland)
}

for(i in 1:12){
    allocations_subset_polygonusersXdauco<-allocations_subset_polygonusersXdauco%>%
    rowwise()%>%
    mutate(!!volvars_list[[i]] := sum(c(get(!!paste0(volvars_list[[i]], "_ag")),
                                      get(!!paste0(volvars_list[[i]], "_mi"))),
                                    na.rm=TRUE))%>%
   ungroup()
}
    
for(i in 1:12){
  allocations_subset_polygonusersXdauco<-allocations_subset_polygonusersXdauco%>%
    dplyr::select(-c(paste0("tot_", volvars_list[[i]]),
              paste0("tot_", volvars_list[[i]], "_ag"),
              paste0("tot_", volvars_list[[i]], "_mi")
           ))
}

allocations_subset_polygonusersXdauco<-allocations_subset_polygonusersXdauco%>%
  dplyr::select(year, std_name, vol_deliv_cy, vol_deliv_wy, vol_maximum,
         swp_deliveries, swp_maxvol, swp_basemax,
         cvp_deliveries_cy, cvp_deliveries_wy, cvp_maxvol,
         loco_maxvol, loco_deliveries,	rights_avgdivert, everything())

# merge in DAUCo information

allocations_subset_polygonusersXdauco<-allocations_subset_polygonusersXdauco%>%
  dplyr::select(!c(user_id.y, user_area.y))%>%
  rename(user_id=user_id.x,
         user_area=user_area.x)%>%
  inner_join(polygons_dauco)%>%
  dplyr::select(c(year:user_id, dauco_id, dau_code:dauco_pctcrop))%>%
  arrange(std_name, year, dauco_id)

save(allocations_subset_polygonusersXdauco, file = paste0(OUTPUT,
                                                    "allocations_subset_polygonusersXdauco.RData"))

#Geography: HUC8

allocations_subset_polygonusersXhuc8<-polygonusers%>%
  inner_join(intersections_districtXhuc8Xyears, by=c("year", "std_name"))

#allocate district's water volumes across its DAUCo pieces
#ag water: on the basis of cropland area
#m&i water: on the basis of total land area

allocations_subset_polygonusersXhuc8<-allocations_subset_polygonusersXhuc8%>%
  rename_at(volvars, funs(paste0("tot_", .)))%>%
  rename_at(vars(ends_with("ag")), funs(paste0("tot_", .)))%>%
  rename_at(vars(ends_with("mi")), funs(paste0("tot_", .)))

for(i in 1:12){
  allocations_subset_polygonusersXhuc8<-allocations_subset_polygonusersXhuc8%>%
    mutate(!!paste0(volvars_list[[i]], "_ag"):=
             get(!!paste0("tot_",volvars_list[[i]], "_ag"))*ishare_cropland,
           !!paste0(volvars_list[[i]], "_mi"):=
             get(!!paste0("tot_",volvars_list[[i]], "_mi"))*ishare_cropland)
}

for(i in 1:12){
  allocations_subset_polygonusersXhuc8<-allocations_subset_polygonusersXhuc8%>%
    rowwise()%>%
    mutate(!!volvars_list[[i]] := sum(c(get(!!paste0(volvars_list[[i]], "_ag")),
                                        get(!!paste0(volvars_list[[i]], "_mi"))),
                                      na.rm=TRUE))%>%
    ungroup()
}

for(i in 1:12){
  allocations_subset_polygonusersXhuc8<-allocations_subset_polygonusersXhuc8%>%
    dplyr::select(-c(paste0("tot_", volvars_list[[i]]),
              paste0("tot_", volvars_list[[i]], "_ag"),
              paste0("tot_", volvars_list[[i]], "_mi")
    ))
}

allocations_subset_polygonusersXhuc8<-allocations_subset_polygonusersXhuc8%>%
  dplyr::select(year, std_name, vol_deliv_cy, vol_deliv_wy, vol_maximum,
         swp_deliveries, swp_maxvol, swp_basemax,
         cvp_deliveries_cy, cvp_deliveries_wy, cvp_maxvol,
         loco_maxvol, loco_deliveries,	rights_avgdivert, everything())

# merge in HUC8 information

allocations_subset_polygonusersXhuc8<-allocations_subset_polygonusersXhuc8%>%
  dplyr::select(!c(user_id.y, user_area.y))%>%
  rename(user_id=user_id.x,
         user_area=user_area.x)%>%
  inner_join(polygons_huc8)%>%
  dplyr::select(c(year:user_id, huc8, starts_with("huc8_")))%>%
  arrange(std_name, year, huc8)

save(allocations_subset_polygonusersXhuc8, file = paste0(OUTPUT,
                                                          "allocations_subset_polygonusersXhuc8.RData"))


#4. MAKE DATASET OF POINT USERS

pointusers<-pointusers%>%
  inner_join(manual_allocations)%>%
  mutate(#Use lat/lon of point of diversion, unless have a manual location
        lat = rights_pod_latitude,
        lon = rights_pod_longitude,
        lat=ifelse(!is.na(lat_manual), lat_manual, lat),
        lon=ifelse(!is.na(lon_manual), lon_manual, lon)
  )

# Geolocate each known lat/lon point to DAUCo that contains it

pointusers.sf <- st_as_sf(pointusers, coords = c("lon", "lat"), crs = 4326) 

pointusers.sf <-pointusers.sf%>%
  st_join(dauco_final)

#Merge in DAUCo information

pointusers.sf <-pointusers.sf%>%
  inner_join(polygons_dauco, by="dauco_id")

#Geolocate each known lat/lon point to HUC8 that contains it

pointusers.sf <-pointusers.sf%>%
  st_join(huc8_3)

#Merge in HUC8 information
allocations_subset_pointusers<-pointusers.sf%>%
  rename(huc8=HUC_8)%>%
  inner_join(polygons_huc8, by="huc8")

save(allocations_subset_pointusers, file = paste0(OUTPUT, 
                                                  "allocations_subset_pointusers.RData"))

# 5. MAKE GEOGRAPHICAL AGGREGATE ALLOCATION DATASETS

#  a. Geography: HUC8

allocations_aggregate_huc8 <-allocations_subset_pointusers%>%
  filter(!is.na(huc8))%>%
  dplyr::select(-c(dauco_id:dauco_pctcrop))

allocations_aggregate_huc8 <-allocations_aggregate_huc8%>%
  bind_rows(allocations_subset_polygonusersXhuc8)%>%
  dplyr::select(-c(user_id:user_area))

# keep only years with full data

allocations_aggregate_huc8 <-allocations_aggregate_huc8%>%
  filter(!is.na(vol_deliv_cy))

# allocations: go from percentages to volumes for aggregation

allocations_aggregate_huc8 <-allocations_aggregate_huc8%>%
  mutate(
    allocation = vol_maximum * pct_allocation,
    allocation_ag = vol_maximum_ag * pct_allocation_ag,
    allocation_mi = vol_maximum_mi * pct_allocation_mi,
    swp_allo_ag = swp_basemax_ag * swp_pctallo_ag,
    swp_allo_mi = swp_basemax_mi * swp_pctallo_mi,
    cvp_allo_ag = cvp_maxvol_ag * cvp_pctallo_ag,
    cvp_allo_mi = cvp_maxvol_mi * cvp_pctallo_mi
  )%>%
  mutate_at(vars(starts_with("allocation"), contains("p_allo_")),
            funs(replace(., is.na(.), 0)))


# Drop variables

allocations_aggregate_huc8 <-allocations_aggregate_huc8%>%
  dplyr::select(-c(contains("pct_allo"), starts_with("rights_pod_l"), 
                   starts_with("rights_m"),
            starts_with("rights_diversion"), ends_with("_manual")))

# Aggregate to HUC8 by year

allocations_aggregate_huc8 <-allocations_aggregate_huc8%>%
  group_by(huc8, year)%>%
  summarise_at(vars(vol_deliv_cy:rights_avgdivert_mi, allocation:cvp_allo_mi), 
               sum, na.rm =TRUE)

# allocations: reconstruct percentages
allocations_aggregate_huc8 <-allocations_aggregate_huc8%>%
  mutate(
    pct_allocation = allocation / vol_maximum,
    pct_allocation_ag = allocation_ag / vol_maximum_ag,
    pct_allocation_mi = allocation_mi / vol_maximum_mi,
    swp_pctallo_ag = swp_allo_ag / swp_basemax_ag,
    swp_pctallo_mi = swp_allo_mi / swp_basemax_mi,
    cvp_pctallo_ag = cvp_allo_ag / cvp_maxvol_ag,
    cvp_pctallo_mi = cvp_allo_mi / cvp_maxvol_mi
  )

save(allocations_aggregate_huc8, file = paste0(OUTPUT,
                                               "allocations_aggregate_huc8.RData"))

#  a. Geography: DAUCo / PA / county

allocations_aggregate_dauco <-allocations_subset_pointusers%>%
  filter(!is.na(dauco_id))%>%
  dplyr::select(!starts_with("huc8"))

allocations_aggregate_dauco <-allocations_aggregate_dauco%>%
  bind_rows(allocations_subset_polygonusersXdauco)%>%
  dplyr::select(-c(user_id:user_area))

# keep only years with full data

allocations_aggregate_dauco <-allocations_aggregate_dauco%>%
  filter(!is.na(vol_deliv_cy))

# allocations: go from percentages to volumes for aggregation

allocations_aggregate_dauco <-allocations_aggregate_dauco%>%
  mutate(
    allocation = vol_maximum * pct_allocation,
    allocation_ag = vol_maximum_ag * pct_allocation_ag,
    allocation_mi = vol_maximum_mi * pct_allocation_mi,
    swp_allo_ag = swp_basemax_ag * swp_pctallo_ag,
    swp_allo_mi = swp_basemax_mi * swp_pctallo_mi,
    cvp_allo_ag = cvp_maxvol_ag * cvp_pctallo_ag,
    cvp_allo_mi = cvp_maxvol_mi * cvp_pctallo_mi
  )%>%
  mutate_at(vars(starts_with("allocation"), contains("p_allo_")),
            funs(replace(., is.na(.), 0)))


# Drop variables

allocations_aggregate_dauco <-allocations_aggregate_dauco%>%
  dplyr::select(-c(contains("pct_allo"), starts_with("rights_pod_l"),
                   starts_with("rights_m"),
            starts_with("rights_diversion"), ends_with("_manual")))

# Aggregate to Dauco by year

allocations_aggregate_dauco <-allocations_aggregate_dauco%>%
  group_by(year, dauco_id, dau_code, dau_name, psa_code, psa_name,
           hr_code, hr_name, pa_code, county_name, county_code,
           county_ansi, dauco_area.y, dauco_pctcrop)%>%
  summarise_at(vars(vol_deliv_cy:rights_avgdivert_mi, allocation:cvp_allo_mi), 
               sum, na.rm =TRUE)

dauco<-allocations_aggregate_dauco

# allocations: reconstruct percentages
allocations_aggregate_dauco <-allocations_aggregate_dauco%>%
  mutate(
    pct_allocation = allocation / vol_maximum,
    pct_allocation_ag = allocation_ag / vol_maximum_ag,
    pct_allocation_mi = allocation_mi / vol_maximum_mi,
    swp_pctallo_ag = swp_allo_ag / swp_basemax_ag,
    swp_pctallo_mi = swp_allo_mi / swp_basemax_mi,
    cvp_pctallo_ag = cvp_allo_ag / cvp_maxvol_ag,
    cvp_pctallo_mi = cvp_allo_mi / cvp_maxvol_mi
  )

save(allocations_aggregate_dauco, file = paste0(OUTPUT,
                                                "allocations_aggregate_dauco.RData"))

#save datasets at other levels

allocations_aggregate_dau<-dauco%>%
  group_by(year, dau_code)%>%
  summarise_at(vars(vol_deliv_cy:rights_avgdivert_mi, allocation:cvp_allo_mi), 
               sum, na.rm =TRUE)%>%
  mutate(
    pct_allocation = allocation / vol_maximum,
    pct_allocation_ag = allocation_ag / vol_maximum_ag,
    pct_allocation_mi = allocation_mi / vol_maximum_mi,
    swp_pctallo_ag = swp_allo_ag / swp_basemax_ag,
    swp_pctallo_mi = swp_allo_mi / swp_basemax_mi,
    cvp_pctallo_ag = cvp_allo_ag / cvp_maxvol_ag,
    cvp_pctallo_mi = cvp_allo_mi / cvp_maxvol_mi
  )%>%
  dplyr::select(!c(starts_with("allocation"), contains("_p_allo_")))%>%
  inner_join(polygons_dau)

save(allocations_aggregate_dau, file = paste0(OUTPUT, "allocations_aggregate_dau.RData"))

allocations_aggregate_pa<-dauco%>%
  group_by(year, pa_code)%>%
  summarise_at(vars(vol_deliv_cy:rights_avgdivert_mi, allocation:cvp_allo_mi), 
               sum, na.rm =TRUE)%>%
  mutate(
    pct_allocation = allocation / vol_maximum,
    pct_allocation_ag = allocation_ag / vol_maximum_ag,
    pct_allocation_mi = allocation_mi / vol_maximum_mi,
    swp_pctallo_ag = swp_allo_ag / swp_basemax_ag,
    swp_pctallo_mi = swp_allo_mi / swp_basemax_mi,
    cvp_pctallo_ag = cvp_allo_ag / cvp_maxvol_ag,
    cvp_pctallo_mi = cvp_allo_mi / cvp_maxvol_mi
  )%>%
  dplyr::select(!c(starts_with("allocation"), contains("_p_allo_")))%>%
  inner_join(polygons_pa)

save(allocations_aggregate_pa, file = paste0(OUTPUT, "allocations_aggregate_pa.RData"))

allocations_aggregate_county<-dauco%>%
  group_by(year, county_code, county_name)%>%
  summarise_at(vars(vol_deliv_cy:rights_avgdivert_mi, allocation:cvp_allo_mi), 
               sum, na.rm =TRUE)%>%
  mutate(
    pct_allocation = allocation / vol_maximum,
    pct_allocation_ag = allocation_ag / vol_maximum_ag,
    pct_allocation_mi = allocation_mi / vol_maximum_mi,
    swp_pctallo_ag = swp_allo_ag / swp_basemax_ag,
    swp_pctallo_mi = swp_allo_mi / swp_basemax_mi,
    cvp_pctallo_ag = cvp_allo_ag / cvp_maxvol_ag,
    cvp_pctallo_mi = cvp_allo_mi / cvp_maxvol_mi
  )%>%
  dplyr::select(!c(starts_with("allocation"), contains("_p_allo_")))%>%
  inner_join(polygons_county)

save(allocations_aggregate_county, file = paste0(OUTPUT,
                                                 "allocations_aggregate_county.RData"))










