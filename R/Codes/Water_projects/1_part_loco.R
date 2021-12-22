library(tidyverse)
library(readr)
library(stringr)
library(dplyr)
library(lubridate)
library(readxl)
library(labelled)
library(grid)
library(matrixStats)
library(reshape2)

rm(list=ls())

##Setting_directories (Change root directory while running codes)

Root<- "/Users/shubhalakshminag/Box/CA_Surface_water/"

#RAW_DATA#

DATA_LOCO<- paste0( Root, "data/colorado/")

#TEMP_FILE#

DATA_TEMP<-	paste0( Root, "R/Temp/")

#FINAL_OUTPUT#

OUTPUT<-paste0( Root, "R/Output/")

#Load master names list

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

#Import entitlements

entitlements<-read_excel(paste0(DATA_LOCO, "accounting_reports.xlsx"), sheet = 1)

#Import quantity diverted

Diversion<-read_excel(paste0(DATA_LOCO, "accounting_reports.xlsx"), sheet = 2)

Diversion<-Diversion%>%
  rename(user="Diversions (acre-feet)")

Diversion<-Diversion%>%
  gather("year", "diversion", -user)%>%
  mutate(
    user=ifelse(user=="Transfer from SDCWA to MWD (originally from IID)", 
                "Metropolitan Water District of Southern California", user),
    user=ifelse(user=="Transfer to San Diego County Water Authority", 
                "San Diego County Water Authority", user),
    user=ifelse(str_detect(user,"Yuma Project Reservation Division"), 
                "Yuma Project Reservation Division", user),
  )

Diversion<-Diversion%>%
  group_by(user, year)%>%
  summarise(diversion=sum(diversion))%>%
  ungroup()

#Combine all datasets

Diversion<-Diversion%>%
  inner_join(entitlements)%>%
  mutate(diversion=ifelse(is.na(diversion), 0, diversion),
         user=toupper(user))

# Merge in standardized names

Diversion<-Diversion%>%
  inner_join(masternames)%>%
  select(-user)%>%
  select(year, std_name, everything())%>%
  rename(
    loco_maxvol=entitlement,
    loco_deliveries=diversion
  )

#Manually classify into municipal/agricultural

Diversion<-Diversion%>%
  mutate(
    loco_maxvol_mi=ifelse(str_detect(std_name,"GOVERNMENT CAMP|METROPOLITAN|CITY OF|SAN DIEGO"),
                          loco_maxvol, NA),
    loco_maxvol_ag=ifelse(str_detect(std_name, "COACHELLA|I[.]D[.]|INDIAN RESERVATION|OTHER USERS|YUMA PROJECT"),
                          loco_maxvol, NA),
    loco_deliveries_mi=ifelse(str_detect(std_name, "GOVERNMENT CAMP|METROPOLITAN|CITY OF|SAN DIEGO"),
                              loco_deliveries, NA),
    loco_deliveries_ag=ifelse(str_detect(std_name, "COACHELLA|I[.]D[.]|INDIAN RESERVATION|OTHER USERS|YUMA PROJECT"),
                              loco_deliveries, NA)
  )%>%
  mutate_at(vars(ends_with("_ag"), ends_with("_mi")), funs(ifelse(is.na(.), 0 , .)))

#Organising

Diversion<-Diversion%>%
  select(year, std_name, loco_maxvol, loco_maxvol_ag,
         loco_maxvol_mi, loco_deliveries,
         loco_deliveries_ag, loco_deliveries_mi)%>%
  arrange(std_name, year)

save(Diversion, file = paste0(OUTPUT, "allocations_source_loco.RData"))






















