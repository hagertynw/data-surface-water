library(readr)
library(tidyverse)
library(dplyr)
library(readxl)
library(sf)
library(stringi)
library(ggplot2)

rm(list=ls())

##Setting_directories (Change root directory while running codes)

Root<- "/Users/shubhalakshminag/Box/CA_Surface_water/"

#RAW_DATA#

DATA_GIS<- paste0( Root, "data/gis/")
GIS_SHP<-paste0(Root, "gis/shapefile_output/")
GIS_TAB<-paste0(Root, "gis/table_output/")

#TEMP_FILE#

DATA_TEMP<-	paste0( Root, "R/Temp/")

#FINAL_OUTPUT#

OUTPUT<-paste0( Root, "R/Output/")

#Prepare master names list

masternames_1<-read_excel(paste0(Root, "data/names_crosswalk_all.xlsx"))

masternames_2<-masternames_1%>%
  distinct()

masternames<-masternames_1%>%
  distinct()%>%
  mutate(
    same=ifelse(user==std_name, 1, 0)
  )%>%
  group_by(std_name)%>%
  mutate(totsame=sum(same))%>%
  ungroup()%>%
  filter(totsame==0)%>%
  select(std_name)%>%
  distinct()%>%
  mutate(user=std_name)%>%
  select(user, std_name)

masternames<-bind_rows(masternames, masternames_2)

#Prepare HUC8 shapefile table

polygons_huc8<-st_read(paste0(GIS_SHP, "huc8_final.shp"))

polygons_huc8<-polygons_huc8%>%
  select(HUC_8, huc8_area, huc8_pctcr, geometry)%>%
  rename(huc8=HUC_8,
         huc8_pctcrop=huc8_pctcr
  )%>%
  mutate(huc8_pctcrop=ifelse(huc8_pctcrop==0, NA, huc8_pctcrop),
         huc8_pctcrop=huc8_pctcrop-1)

save(polygons_huc8, file = paste0(DATA_TEMP, "polygons_huc8.RData"))


#Prepare DAUCO shapefile table

polygons_dauco<-st_read(paste0(GIS_SHP, "dauco_final.shp"))

polygons_dauco<-polygons_dauco%>%
  select(dauco_id, DAU_CODE, DAU_NAME, PSA_CODE, PSA_NAME,
         HR_CODE, HR_NAME, PA_NO, COUNTY_NAM, COUNTY_COD,
         COUNTY_ANS, dauco_area, dauco_pctc, geometry )%>%
  rename_all(tolower)%>%
  rename(dauco_pctcrop=dauco_pctc,
         pa_code=pa_no, 
         county_name=county_nam,
         county_code=county_cod,
         county_ansi=county_ans)%>%
  mutate(dauco_pctcrop=ifelse(dauco_pctcrop==0, NA, dauco_pctcrop),
         dauco_pctcrop=dauco_pctcrop-1)

save(polygons_dauco, file = paste0(DATA_TEMP, "polygons_dauco.RData"))

#Prepare tables for more aggregated geographies

#DAU

polygons_dau<-as.data.frame(polygons_dauco)%>%
  select(-geometry)%>%
  mutate(dauco_cropland = dauco_area * dauco_pctcrop)%>%
  group_by(dau_code)%>%
  summarise_at(c("dauco_area", "dauco_cropland"), sum, na.rm=TRUE)%>%
  ungroup()%>%
  rename(dau_area=dauco_area,
         dau_cropland=dauco_cropland)%>%
  mutate(dau_pctcrop = dau_cropland/dau_area)

save(polygons_dau, file = paste0(DATA_TEMP, "polygons_dau.RData"))

#PA

polygons_pa<- as.data.frame(polygons_dauco)%>%
  select(-geometry)%>%
  mutate(dauco_cropland = dauco_area * dauco_pctcrop)%>%
  group_by(pa_code)%>%
  summarise_at(c("dauco_area", "dauco_cropland"), sum, na.rm=TRUE)%>%
  ungroup()%>%
  rename(pa_area=dauco_area,
         pa_cropland=dauco_cropland)%>%
  mutate(pa_pctcrop = pa_cropland/pa_area)

save(polygons_pa, file = paste0(DATA_TEMP, "polygons_pa.RData"))

#COUNTY

polygons_county<- as.data.frame(polygons_dauco)%>%
  select(-geometry)%>%
  mutate(dauco_cropland = dauco_area * dauco_pctcrop)%>%
  group_by(county_name)%>%
  summarise_at(c("dauco_area", "dauco_cropland"), sum, na.rm=TRUE)%>%
  ungroup()%>%
  rename(county_area=dauco_area,
         county_cropland=dauco_cropland)%>%
  mutate(county_pctcrop = county_cropland/county_area)

save(polygons_county, file = paste0(DATA_TEMP, "polygons_county.RData"))

#Prepare districts shapefile table

polygons_district<-st_read(paste0(GIS_SHP, "users_final.shp"))

polygons_district<-as.data.frame(polygons_district)%>%
  select(user_id, source, username, pwsid, AGENCYUNIQ, 
         user_x, user_y, totarea)%>%
  rename(user=username,
         user_area=totarea)%>%
  mutate(user=toupper(user))%>%
  mutate(AGENCYUNIQ=ifelse(AGENCYUNIQ==0, NA, AGENCYUNIQ))

#Merge standardized names

polygons_district<-polygons_district%>%
  inner_join(masternames)

#Drop duplicates within sources (keep largest shape)  
  
polygons_district<-polygons_district%>%
  arrange(std_name, source, desc(user_area))%>%
  group_by(std_name, source)%>%
  slice(1)%>%
  ungroup()

#apply information to all obs within name  
  
polygons_district<-polygons_district%>%
  arrange(std_name, desc(pwsid))%>%
  group_by(std_name)%>%
  mutate(pwsid=ifelse(is.na(pwsid), pwsid[1], pwsid))%>%
  ungroup()%>%
  arrange(std_name, AGENCYUNIQ)%>%
  group_by(std_name)%>%
  mutate(AGENCYUNIQ=ifelse(is.na(AGENCYUNIQ), AGENCYUNIQ[1], AGENCYUNIQ))%>%
  ungroup()

#drop duplicates across sources (in priority order; keep information from all)

polygons_district<-polygons_district%>%
  mutate(priority=case_when(
    source=="agencies" ~ 1, 
    source=="federal" ~ 2,
    source=="swp" ~ 3,
    source=="private" ~ 4,
    source=="mojave" ~ 5,
    source=="cehtp" ~ 6
  ))%>%
  arrange(std_name, priority)%>%
  group_by(std_name)%>%
  slice(1)%>%
  select(-priority)%>%
  rename(shape_source=source)%>%
  arrange(std_name)%>%
  select(std_name, user_x, user_y, user_area, everything())

save(polygons_district, file = paste0(DATA_TEMP, "polygons_district.RData"))

#Prepare list of intersections between districts and HUC8

intersections_districtXhuc8<-read_excel(paste0(GIS_TAB, "users_huc8.xls"))

intersections_districtXhuc8<-intersections_districtXhuc8%>%
  select(user_id, HUC_8, starts_with("iuser"))%>%
  rename(huc8=HUC_8)%>%
  mutate(iuser_pctcrop=ifelse(iuser_pctcrop==0, NA, iuser_pctcrop),
         iuser_pctcrop=iuser_pctcrop-1)


#merge district shapes

intersections_districtXhuc8<-intersections_districtXhuc8%>%
  inner_join(polygons_district)%>%
  select(user_id, std_name:AGENCYUNIQ, everything())

#calculate cropland in each shape
#calculate total & proportions of area and cropland in district belonging to each piece

intersections_districtXhuc8<-intersections_districtXhuc8%>%
  mutate(iuser_cropland = iuser_area * iuser_pctcrop)%>%
  group_by(std_name)%>%
  mutate(user_cropland = sum(iuser_cropland, na.rm = TRUE),
         user_totarea = sum(iuser_area, na.rm = TRUE))%>%
  ungroup()%>%
  mutate(ishare_cropland = iuser_cropland/user_cropland,
         ishare_area = iuser_area/user_totarea)%>%
  arrange(std_name, huc8)

save(intersections_districtXhuc8, file = paste0(DATA_TEMP, "intersections_districtXhuc8.RData"))

#expand to year, for merging

intersections_districtXhuc8Xyears<-intersections_districtXhuc8%>%
  slice(rep(1:n(), each=40))%>%
  group_by(std_name)%>%
  mutate(year = 1980+ row_number())%>%
  ungroup()

save(intersections_districtXhuc8Xyears, file = paste0(DATA_TEMP, 
                                                      "intersections_districtXhuc8Xyears.RData"))

#Prepare list of intersections between districts and DAU-counties

intersections_districtXdauco<-read_excel(paste0(GIS_TAB, "users_dauco.xls"))

intersections_districtXdauco<-intersections_districtXdauco%>%
  select(user_id, dauco_id, starts_with("iuser"))%>%
  mutate(iuser_pctcrop=ifelse(iuser_pctcrop==0, NA, iuser_pctcrop),
         iuser_pctcrop=iuser_pctcrop-1)

#Merge district shapes

intersections_districtXdauco<-intersections_districtXdauco%>%
  inner_join(polygons_district)%>%
  select(user_id, std_name:AGENCYUNIQ, everything())

intersections_districtXdauco<-intersections_districtXdauco%>%
  mutate(iuser_cropland = iuser_area * iuser_pctcrop)%>%
  group_by(std_name)%>%
  mutate(user_cropland = sum(iuser_cropland, na.rm = TRUE),
         user_totarea = sum(iuser_area, na.rm = TRUE))%>%
  ungroup()%>%
  mutate(ishare_cropland = iuser_cropland/user_cropland,
         ishare_area = iuser_area/user_totarea)%>%
  arrange(std_name, dauco_id)

save(intersections_districtXdauco, file = paste0(DATA_TEMP, "intersections_districtXdauco.RData"))


#expand to year, for merging

intersections_districtXdaucoXyears<-intersections_districtXdauco%>%
  slice(rep(1:n(), each=40))%>%
  group_by(std_name)%>%
  mutate(year = 1980+ row_number())%>%
  ungroup()

save(intersections_districtXdaucoXyears, file = paste0(DATA_TEMP, "intersections_districtXdaucoXyears.RData"))






  
  




