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
library(exactextractr)

rm(list=ls())

##Setting_directories (Change root directory while running codes)

Root<- "/Users/shubhalakshminag/Box/CA_Surface_water/"

##GIS_DATA

DATA_GIS<-paste0(Root, "data/gis/")

##FINAL_OUTPUT

OUTPUT_GIS<-paste0( Root, "R/GIS/")

#IMPORTING SHAPE FILES

RAW_COUNTY<-st_read(paste0(DATA_GIS, "ca_atlas/counties/cnty24k09_1_multipart.shp"))
RAW_DAU<-st_read(paste0(DATA_GIS, "dwr/dau/dau_v2_105.shp"))
RAW_DWR_AGENCIES<-st_read(paste0(DATA_GIS, "dwr/districts/combined/water_agencies.shp"))
RAW_ATLAS_FEDERAL<-st_read(paste0(DATA_GIS, "ca_atlas/districts/federal/FederalWaterUsers.shp"))
RAW_ATLAS_STATE<-st_read(paste0(DATA_GIS, "ca_atlas/districts/state/wdst24.shp"))
RAW_ATLAS_PRIVATE<-st_read(paste0(DATA_GIS, "ca_atlas/districts/private/wdpr24.shp"))
RAW_MOJAVE<-st_read(paste0(DATA_GIS, 
                           "ca_atlas/mojave/Mojave_Water_Agency_Service_Area_Water_Companies_2012.shp"))
RAW_CEHTP<-st_read(paste0(DATA_GIS, "cehtp/service_areas.shp"))
RAW_CROPMASK<-raster(paste0(DATA_GIS, "nass_cdl/CMASK_2015_06.tif"))
RAW_ATLAS_FEDERAL_TABLE<-mdb.get("WD-WaterUsers.mdb", "Master")
huc8_1<-st_read(paste0(DATA_GIS, "dwr/watersheds/huc8_1.shp"))

#Dissolve within layer, into multipart features

agencies_1<-RAW_DWR_AGENCIES%>%
  st_buffer(0)%>%
  group_by(AGENCYUNIQ)%>%
  summarise(AGENCYNAME=first(AGENCYNAME))%>%
  ungroup()

federal_1<-RAW_ATLAS_FEDERAL%>%
  st_buffer(0)%>%
  group_by(WDNAME)%>%
  summarise()%>%
  ungroup()%>%
  st_cast(., "MULTIPOLYGON")

swp_1<-RAW_ATLAS_STATE%>%
  group_by(WDNAME)%>%
  summarise()%>%
  ungroup()

private_1<-RAW_ATLAS_PRIVATE%>%
  group_by(WDNAME)%>%
  summarise()%>%
  ungroup()

mojave_1<-RAW_MOJAVE%>%
  group_by(Name)%>%
  summarise()%>%
  ungroup()

cehtp_1<-RAW_CEHTP%>%
  group_by(pwsid)%>%
  summarise(pwsname=first(pwsname))%>%
  ungroup()

RAW_DAU<-st_transform(RAW_DAU, 3310)

dau_1<-RAW_DAU%>%
  group_by(DAU_CODE)%>%
  summarise(DAU_NAME=first(DAU_NAME),
            PSA_CODE=first(PSA_CODE),
            PSA_NAME=first(PSA_NAME),
            HR_CODE=first(HR_CODE),
            HR_NAME=first(HR_NAME),
            PA_NO=first(PA_NO))%>%
  ungroup()

#Intersect DAU and county

dauco_1<-dau_1%>%
  st_buffer(-215)%>%
  st_intersection(RAW_COUNTY)

#Deleting unnecessary features

dauco_1<-dauco_1%>%
  dplyr::select(-c(NAME_UCASE, FMNAME_PC, FMNAME_UC, ABBREV, ABCODE))%>%
  arrange(DAU_CODE)

#Renaming features

agencies_1<-agencies_1%>%
  rename(username=AGENCYNAME)

federal_1<-federal_1%>%
  rename(username=WDNAME)

private_1<-private_1%>%
  rename(username=WDNAME)

mojave_1<-mojave_1%>%
  rename(username=Name)

cehtp_1<-cehtp_1%>%
  rename(username=pwsname)

swp_1<-swp_1%>%
  rename(username=WDNAME)

dauco_1<-dauco_1%>%
  rename(COUNTY_NAME=NAME_PCASE,
         COUNTY_CODE=NUM,
         COUNTY_ANSI=ANSI)

#Adding a source variable 

agencies_1<-agencies_1%>%
  mutate(source="agencies")

federal_1<-federal_1%>%
  mutate(source="federal")

swp_1<-swp_1%>%
  mutate(source="swp")

private_1<-private_1%>%
  mutate(source="private")

mojave_1<-mojave_1%>%
  mutate(source="mojave")

cehtp_1<-cehtp_1%>%
  mutate(source="cehtp")

#Add a field identifying DAUCOid

dauco_1<-dauco_1%>%
  mutate(dauco_id=sub("^0+", "",DAU_CODE ),
         dauco_id=as.numeric(dauco_id)*100 + COUNTY_CODE)

#Merge users together (projecting into WGS84, the first input's coordinate system)  
#Transform all other datasets to crs=4326 (projecting into WGS84)

cehtp_1<-st_transform(cehtp_1, 4326)
agencies_1<-st_transform(agencies_1, 4326)
st_crs(federal_1)<-26911
federal_1<-st_transform(federal_1, 4326)
swp_1<-st_transform(swp_1, 4326)
private_1<-st_transform(private_1, 4326)
mojave_1<-st_transform(mojave_1, 4326)

## Add centroid for mojave

mojave_1<-mojave_1%>%
  st_buffer(0)%>%
  st_zm()

mojave_1$centroid<-mojave_1%>%
  st_point_on_surface()%>%
  st_geometry()

mojave_1<-mojave_1%>%
  mutate(user_x=sf::st_coordinates(centroid)[,1],
         user_y=sf::st_coordinates(centroid)[,2])

# Merging users

users_2<-bind_rows(cehtp_1, agencies_1, federal_1, swp_1, private_1)

#Adding centroids (restricting to points within the polygons)

users_2$centroid<-users_2%>%
  st_point_on_surface()%>%
  st_geometry()

users_3<-users_2%>%
  mutate(user_x=sf::st_coordinates(centroid)[,1],
         user_y=sf::st_coordinates(centroid)[,2])

# Add user unique id

users_3<-users_3%>%
  bind_rows(mojave_1)%>%
  mutate(user_id=row_number())%>%
  filter(!st_is_empty(.))

# Project to meters and calculate area-change crs to 26919 ('NAD 1983 UTM Zone 10N')

users_3<-st_transform(users_3, crs=26911 )
huc8_2<-st_transform(huc8_1, crs=26911 )
dauco_2<-st_transform(dauco_1, crs=26911 )

# Adding Shape Areas

users_3<-users_3%>%
  mutate(totarea=sf::st_area(.),
         totarea=set_units(totarea, km^2))

huc8_2<-huc8_2%>%
  mutate(huc8area=sf::st_area(.),
         huc8area=set_units(huc8area, km^2))

dauco_2<-dauco_2%>%
  mutate(daucoarea=sf::st_area(.),
         daucoarea=set_units(daucoarea, km^2))

# Calculate zonal statistics on cropmask and join back

huc8_pctcrop<-as.data.frame(exact_extract(RAW_CROPMASK, huc8_2, 'mean'))
huc8_pctcrop$HUC_8=huc8_2$HUC_8

huc8_2<-huc8_2%>%
  inner_join(huc8_pctcrop)%>%
  rename("huc8_pctc"="exact_extract(RAW_CROPMASK, huc8_2, \"mean\")")

dauco_pctcrop<-as.data.frame(exact_extract(RAW_CROPMASK, dauco_2, 'mean'))
dauco_pctcrop$dauco_id=dauco_2$dauco_id

dauco_2<-dauco_2%>%
  inner_join(dauco_pctcrop)%>%
  rename("dauco_pctc"="exact_extract(RAW_CROPMASK, dauco_2, \"mean\")")

users_final<-st_transform(users_3, 4326)%>%
  dplyr::select(-centroid)%>%
  mutate(AGENCYUNIQ=ifelse(is.na(AGENCYUNIQ), 0, AGENCYUNIQ))
huc8_final<-st_transform(huc8_2, 4326)
dauco_final<-st_transform(dauco_2, 4326)

save(huc8_final, file = paste0(OUTPUT_GIS, "huc8_final.RData"))
save(dauco_final, file = paste0(OUTPUT_GIS, "dauco_final.RData"))
save(users_final, file = paste0(OUTPUT_GIS, "users_final.RData"))

# Intersect users with DAUCo and HUC8

users_huc8_4<-users_3%>%
  st_buffer(440)%>%
  st_intersection(huc8_2)

users_dauco_4<-users_3%>%
  st_buffer(393)%>%
  st_intersection(dauco_2)

#Dissolving polygons

users_huc8_5<-users_huc8_4%>%
  group_by(user_id, HUC_8)%>%
  summarise(pwsid=first(pwsid),
            username=first(username),
            source=first(source),
            AGENCYUNIQ=first(AGENCYUNIQ),
            user_x=first(user_x),
            user_y=first(user_y),
            totarea=first(totarea),
            huc8_area=first(huc8area),
            huc8_pctc=first(huc8_pctc))%>%
  ungroup()

users_dauco_5<-users_dauco_4%>%
  group_by(user_id, dauco_id)%>%
  summarise(pwsid=first(pwsid),
            username=first(username),
            source=first(source),
            AGENCYUNIQ=first(AGENCYUNIQ),
            user_x=first(user_x),
            user_y=first(user_y),
            totarea=first(totarea),
            daucoarea=first(daucoarea),
            dauco_pctc=first(dauco_pctc),
            DAU_CODE=first(DAU_CODE),
            DAU_NAME=first(DAU_NAME),
            PSA_CODE=first(PSA_CODE),
            PSA_NAME=first(PSA_NAME),
            HR_CODE=first(HR_CODE),
            HR_NAME=first(HR_NAME),
            PA_NO=first(PA_NO),
            COUNTY_NAME=first(COUNTY_NAME),
            COUNTY_CODE=first(COUNTY_CODE),
            COUNTY_ANSI=first(COUNTY_ANSI))%>%
  ungroup()

#Adding unique ID

users_huc8_5<-users_huc8_5%>%
  mutate(iuser_id=row_number())

users_dauco_5<-users_dauco_5%>%
  mutate(iuser_id=row_number())

# Add centroids within intersected users (restricting to within shape)

users_huc8_5<-st_transform(users_huc8_5,4326)
users_huc8_5$centroid<-users_huc8_5%>%
  st_buffer(0)%>%
  st_point_on_surface()%>%
  st_geometry()
users_huc8_5<-users_huc8_5%>%
  mutate(iuser_x=sf::st_coordinates(centroid)[,1],
         iuser_y=sf::st_coordinates(centroid)[,2])

users_dauco_5<-st_transform(users_dauco_5,4326)
users_dauco_5$centroid<-users_dauco_5%>%
  st_buffer(0)%>%
  st_point_on_surface()%>%
  st_geometry()
users_dauco_5<-users_dauco_5%>%
  mutate(iuser_x=sf::st_coordinates(centroid)[,1],
         iuser_y=sf::st_coordinates(centroid)[,2])

# Add shape areas for intersected users

users_dauco_5<-st_transform(users_dauco_5,26911)
users_dauco_5<-users_dauco_5%>%
  mutate(iuser_area=sf::st_area(.),
         iuser_area=set_units(iuser_area, km^2))

users_huc8_5<-st_transform(users_huc8_5,26911)
users_huc8_5<-users_huc8_5%>%
  mutate(iuser_area=sf::st_area(.),
         iuser_area=set_units(totarea, km^2))

# Calculate zonal statistics on cropmask and join back

user_huc8_pctcrop<-as.data.frame(exact_extract(RAW_CROPMASK, users_huc8_5, 'mean'))
user_huc8_pctcrop$iuser_id=users_huc8_5$iuser_id

users_huc8_5<-users_huc8_5%>%
  inner_join(user_huc8_pctcrop)%>%
  rename("iuser_pctc"="exact_extract(RAW_CROPMASK, users_huc8_5, \"mean\")")

user_dauco_pctcrop<-as.data.frame(exact_extract(RAW_CROPMASK, users_dauco_5, 'mean'))
user_dauco_pctcrop$iuser_id=users_dauco_5$iuser_id

users_dauco_5<-users_dauco_5%>%
  inner_join(user_dauco_pctcrop)%>%
  rename("iuser_pctc"="exact_extract(RAW_CROPMASK, users_dauco_5, \"mean\")")

# Saving final data

save(users_dauco_5, file = paste0(OUTPUT_GIS, "users_dauco.RData"))
save(users_huc8_5, file = paste0(OUTPUT_GIS, "users_huc8.RData"))
save(RAW_ATLAS_FEDERAL_TABLE, file = paste0(OUTPUT_GIS, "federal_table.xlsx"))






