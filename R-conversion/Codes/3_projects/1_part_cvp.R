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

DATA_CVP	<- paste0( Root, "data/cvp/")

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

#LOAD DELIVERIES DATA

#Import & append data

sheets_9397<-excel_sheets(paste0(DATA_CVP, "deliveries/deliveries 1993-1997.xlsx"))
sheets_9810<-excel_sheets(paste0(DATA_CVP, "deliveries/deliveries 1998-2010.xlsx"))
sheets_1118<-excel_sheets(paste0(DATA_CVP, "deliveries/deliveries 2011-2018.xlsx"))

list_9397<-lapply(sheets_9397, function(x) read_excel(paste0(DATA_CVP, "deliveries/deliveries 1993-1997.xlsx"), sheet=x))
list_9810<-lapply(sheets_9810, function(x) read_excel(paste0(DATA_CVP, "deliveries/deliveries 1998-2010.xlsx"), sheet=x))
list_1118<-lapply(sheets_1118, function(x) read_excel(paste0(DATA_CVP, "deliveries/deliveries 2011-2018.xlsx"), sheet=x))

appendfile<-bind_rows(list_9397, list_9810, list_1118)

#Clean up

appendfile<-appendfile%>%
  select(-Total)%>%
  rename(user="Water User")%>%
  mutate(user=toupper(user))


#drop totals and lines that aren't real water users

appendfile<-appendfile%>%
  filter(is.na(category) | !str_detect(category, "Refuges"))%>%
  filter(!str_detect(user, "TOTAL"))%>%
  filter(!str_detect(user, "DMC PLUS O|TOT DMC DELIVERIES|215 WATER|DWR INTERTIE"))%>%
  filter(!str_detect(user, "PHASE|FLOOD RELEASES|FISH FACILITIES|CONSTRUCTION WATER"))%>%
  filter(!str_detect(user, "CHINA ISLAND|WASTEWAY|OPERATIONAL WATER"))%>%
  filter(!str_detect(user, "SAN JOAQUIN DRAIN|USBR|WARREN CONTRACTS"))%>%
  filter(!str_detect(user, "NEILL PUMP|NEILL NET"))

#Merge in standardized names

appendfile<-appendfile%>%
  inner_join(masternames)%>%
  select(year, std_name, branch, category, everything())

#rename columns

appendfile<-appendfile%>%
  rename_at(vars(Jan:Dec), funs(paste0("deliv_", .)))
  
#Get list of branch/category with greatest historical volume

branchcat<-appendfile%>%
  rowwise()%>%
  mutate(deliv_tot=sum(select(., starts_with("deliv_")), na.rm=TRUE))%>%
  ungroup()

branchcat<-branchcat%>%
  group_by(std_name, branch, category)%>%
  summarise(deliv_tot=sum(deliv_tot))%>%
  ungroup()%>%
  arrange(std_name, desc(deliv_tot))%>%
  group_by(std_name)%>%
  filter(row_number()==1)%>%
  ungroup()%>%
  select(std_name, branch, category)

#set aside locations

loc_deliveries<-appendfile%>%
  select(std_name, branch, category)%>%
  distinct()

#sum within user X year

appendfile<-appendfile%>%
  group_by(std_name, year)%>%
  summarise(
    deliv_Jan=sum(deliv_Jan, na.rm = TRUE),
    deliv_Feb=sum(deliv_Feb, na.rm = TRUE),
    deliv_Mar=sum(deliv_Mar, na.rm = TRUE),
    deliv_Apr=sum(deliv_Apr, na.rm = TRUE),
    deliv_May=sum(deliv_May, na.rm = TRUE),
    deliv_Jun=sum(deliv_Jun, na.rm = TRUE),
    deliv_Jul=sum(deliv_Jul, na.rm = TRUE),
    deliv_Aug=sum(deliv_Aug, na.rm = TRUE),
    deliv_Sep=sum(deliv_Sep, na.rm = TRUE),
    deliv_Oct=sum(deliv_Oct, na.rm = TRUE),
    deliv_Nov=sum(deliv_Nov, na.rm = TRUE),
    deliv_Dec=sum(deliv_Dec, na.rm = TRUE)
  )%>%
  ungroup()

#reattach branch/category

appendfile<-appendfile%>%
  inner_join(branchcat)

#Set aside

yearfirst=min(appendfile$year)
yearlast=max(appendfile$year)

deliveries<-appendfile%>%
  arrange(std_name, year)

#LOAD & CLEAN ALLOCATION PERCENTAGES

pctallocations<-read_excel(paste0(DATA_CVP, "allocations.xlsx"))

#Renaming the columns

pctallocations<-pctallocations%>%
  rename(usertype="...1")

#Impute where missing or not a percentage

pctallocations<-pctallocations%>%
  #impute "North of Delta Urban Contractors"
  mutate_at(vars("2019": "1977"), funs(replace(., is.na(.) & 
                                                      usertype=="American River M&I Contractors",
                                                    .[2])))%>%
  mutate_at(vars("2019": "1977"), funs(replace(., is.na(.) & 
                                                     usertype=="In Delta - Contra Costa",
                                                   .[2])))%>%
  rowwise()%>%
  #convert volumes to percentages (by dividing by total maximum contract volume)
  mutate_at(vars("2019": "1977"), funs(replace(., !is.na(.) & .>100 & 
                                                      usertype=="Eastside Division Contractors",
                                                    ./155000*100 )))%>%
  mutate_at(vars("2019": "1977"), funs(replace(., !is.na(.) & .>100 & 
                                                      usertype=="Friant - Class 2",
                                                    ./1401475*100)))%>%
  ungroup()%>%
  #category did not exist prior to appearing in dataset
  mutate_at(vars("2019": "1977"), funs(replace(., is.na(.) & 
                                                     usertype=="Eastside Division Contractors",
                                                    0))
            )

#Abbreviate categories

pctallocations<-pctallocations%>%
  mutate(type=case_when(
    usertype=="American River M&I Contractors" ~ "american",
    usertype=="Eastside Division Contractors" ~ "eastside",
    usertype=="Friant - Class 1"  ~ "friant1",
    usertype=="Friant - Class 2"  ~ "friant2",
    usertype=="Friant - Hidden & Buchanan Units" ~ "friant0",
    usertype=="In Delta - Contra Costa" ~ "indelta",
    usertype=="North of Delta Agricultural Contractors (Ag)" ~ "nag",
    usertype=="North of Delta Urban Contractors (M&I)" ~ "nmi",
    usertype=="North of Delta Settlement Contractors/Water Rights" ~ "nrights",
    usertype=="North of Delta Wildlife Refuges (Level 2)" ~ "nrefuges",
    usertype=="South of Delta Agricultural Contractors (Ag)" ~ "sag",
    usertype=="South of Delta Urban Contractors (M&I)" ~ "smi",
    usertype=="South of Delta Settlement Contractors/Water Rights" ~ "srights",
    usertype=="South of Delta Wildlife Refuges (Level 2)" ~ "srefuges")
  )%>%
  select(-usertype)
  
#Reshape

pctallocations<-pctallocations%>%
  gather(year, "_pct", "2019": "1977")%>%
  arrange(type, year)%>%
  mutate(type=paste0("pct_", type))%>%
  spread(type, "_pct")%>%
  mutate(year= as.numeric(year))%>%
  arrange(year)


#LOAD & CLEAN LIST OF MAXIMUM CONTRACT VOLUMES

Contractors<-read_excel(paste0(DATA_CVP, "cvp_contractors.xlsx"))

Contractors<-Contractors%>%
  mutate(user=toupper(contractor))%>%
  rename(
    mi="M&I",
    ag=AG,
    division="CVP Division",
    unit=Unit,
    maxvolume="Maximum Contract Quantity",
    maxvolume_mi="M&I Historical Use",
    maxvolume_base="Base Supply",
    maxvolume_project="Project Water"
  )%>%
  select(-"Contract Amount for Ag")%>%
  mutate(
    mi=replace(mi,  mi=="X", 1),
    mi=replace(mi,  is.na(mi), 0),
    ag=replace(ag,  ag=="X", 1),
    ag=replace(ag,  is.na(ag), 0),
    ag=as.numeric(ag),
    mi=as.numeric(mi)
  )

#merge standardized names

Contractors<-Contractors%>%
  inner_join(masternames)%>%
  select(std_name, maxvolume, category, division, unit, everything())%>%
  rename(ContractNo="Contract No.")

#for shared contracts, split by apparent ratios from delivery data (calculated separately)

Contractors<-Contractors%>%
  mutate(
    maxvolume=replace(maxvolume, ContractNo=="Ilr 1144 (1)", "560000"),
    maxvolume=replace(maxvolume, ContractNo=="Ilr 1144 (2)", "56000"),
    maxvolume=replace(maxvolume, ContractNo=="Ilr 1144 (3)", "168000"),
    maxvolume=replace(maxvolume, ContractNo=="Ilr 1144 (4)", "56000")
  )

#For shared contracts, split evenly (when delivery data does not help)

Contractors<-Contractors%>%
  mutate(
    maxvolume=replace(maxvolume, ContractNo=="14-06-200-3365A-IR13-B (SCV)", "3130"),
    maxvolume=replace(maxvolume, ContractNo=="14-06-200-3365A-IR13-B (WWD)", "3130"),
    maxvolume=replace(maxvolume, contractor=="Oakdale Irrigation District", "600000"),
    maxvolume=replace(maxvolume, contractor=="Oakdale Irrigation District", "300000"),
    maxvolume=replace(maxvolume, contractor=="South San Joaquin Irrigation District", "300000")
  )

#clean up maxvolume

Contractors<-Contractors%>%
  mutate(
    maxvolume_mi=replace(maxvolume_mi, maxvolume_mi=="-", NA),
    maxvolume_mi=as.numeric(maxvolume_mi),
    maxvolume=as.numeric(maxvolume),
    maxvolume_mi=replace(maxvolume_mi, is.na(maxvolume_mi), 0),
  )

#For two related contracts, consolidate (so that maxvolume = maxvolume_project + maxvolume_base)

Contractors<-Contractors%>%
  mutate(maxvolume=replace(maxvolume, std_name=="ANDERSON-COTTONWOOD I.D." & maxvolume==125000, 
                           128000))%>%
  filter(!(std_name=="ANDERSON-COTTONWOOD I.D." & maxvolume==3000))

#Specify max volume by base or project
Contractors<-Contractors%>%
  mutate(maxvolume=round(maxvolume, 0))

Contractors<-Contractors%>%
  mutate(
    maxvolume_base=replace(maxvolume_base, (project==0 & base==1 & is.na(maxvolume_base)),
                           maxvolume[project==0 & base==1 & is.na(maxvolume_base)]),
    maxvolume_project=replace(maxvolume_project, (project==0 & base==1 & 
                                                    is.na(maxvolume_project)), 0),
    maxvolume_project=replace(maxvolume_project, (project==1 & base==0 & 
                                                    is.na(maxvolume_project)), 
                              maxvolume[project==1 & base==0 & is.na(maxvolume_project)]),
    maxvolume_base=replace(maxvolume_base, (project==1 & base==0 & is.na(maxvolume_base)),0)
  )

Contractors<-Contractors%>%
  mutate(
    maxvolume_base=ifelse(project==0 & base==1 & is.na(maxvolume_base),
                          maxvolume, maxvolume_base),
    maxvolume_project=ifelse(project==0 & base==1 & is.na(maxvolume_project),
                             0, maxvolume_project),
    maxvolume_project=ifelse(project==1 & base==0 & is.na(maxvolume_project),
                             maxvolume, maxvolume_project),
    maxvolume_base=ifelse(project==1 & base==0 & is.na(maxvolume_base),
                          0, maxvolume_base),
  )


#for one Sac R Settl. Contr. holder without base/project split, assume it's just project

Contractors<-Contractors%>%
  mutate(
    maxvolume_base=replace(maxvolume_base, is.na(maxvolume_base), 0),
    maxvolume_project=ifelse(is.na(maxvolume_project), maxvolume, maxvolume_project )
  )

#For 2 obs whose M&I volume exceeds max contract volume, adjust M&I vol to equal contract vol

Contractors<-Contractors%>%
  mutate(
    maxvolume_mi=ifelse(maxvolume_mi>maxvolume, maxvolume, maxvolume_mi )
  )

#Set up max volume variables for each contract type X sector

Contractors<-Contractors%>%
  mutate(
    mvcat_mi_american=ifelse(category=="American River M&I Contracts", maxvolume_mi, NA),
    mvcat_ag_american=ifelse(category=="American River M&I Contracts", maxvolume-maxvolume_mi , NA),
    mvcat_mi_friant1=ifelse(category=="Friant Division" & class==1, maxvolume_mi, NA),
    mvcat_ag_friant1=ifelse(category=="Friant Division" & class==1, maxvolume-maxvolume_mi, NA),
    mvcat_mi_friant2=ifelse(category=="Friant Division" & class==2, maxvolume_mi, NA),
    mvcat_ag_friant2=ifelse(category=="Friant Division" & class==2, maxvolume-maxvolume_mi, NA),
    mvcat_mi_friant0=ifelse(category=="Friant Division" & is.na(class), maxvolume_mi, NA),
    mvcat_ag_friant0=ifelse(category=="Friant Division" & is.na(class), maxvolume-maxvolume_mi, NA),
    mvcat_mi_indelta=ifelse(category=="In Delta - Contra Costa", maxvolume_mi, NA),
    mvcat_ag_indelta=ifelse(category=="In Delta - Contra Costa", maxvolume-maxvolume_mi, NA),
    mvcat_mi_north=ifelse(category=="Sacramento River Water Service Contracts", maxvolume_mi, NA),
    mvcat_ag_north=ifelse(category=="Sacramento River Water Service Contracts", maxvolume-maxvolume_mi, NA),
    mvcat_mi_srights=ifelse(category=="South of Delta Water Rights Contracts", maxvolume_mi, NA),
    mvcat_ag_srights=ifelse(category=="South of Delta Water Rights Contracts", maxvolume-maxvolume_mi, NA),
    mvcat_mi_south=ifelse(category=="South of Delta Water Service Contracts", maxvolume_mi, NA),
    mvcat_ag_south=ifelse(category=="South of Delta Water Service Contracts", maxvolume-maxvolume_mi, NA),
    mvcat_mi_eastside=ifelse(category=="Stanislaus East Side", maxvolume_mi, NA),
    mvcat_ag_eastside=ifelse(category=="Stanislaus East Side", maxvolume-maxvolume_mi, NA),
    mvcat_mi_nrights=NA,
    mvcat_ag_nrights=ifelse(category=="Sacramento River Water Rights Settlement Contractors",
                            maxvolume_base, NA),
    mvcat_ag_north=ifelse( category=="Sacramento River Water Rights Settlement Contractors",
                           maxvolume_project, mvcat_ag_north
                           )
  )


#note: this is the only category that has both base and project water
#though not 100% is ag, it's pretty close. cannot simultaneously 
#differentiate base/project & MI/ag

Contractors<-Contractors%>%
  mutate(
    mvcat_nrefuges=ifelse(category=="Refuges" & str_detect(std_name,"NORTH"), maxvolume, NA),
    mvcat_srefuges=ifelse(category=="Refuges" & str_detect(std_name,"SOUTH"), maxvolume, NA)
  )%>%
  rowwise()%>%
  mutate(mvcat_total=sum(select(.,starts_with("mvcat_"))))%>%
  ungroup()%>%
  select(-mvcat_total)

#collapse to unique user

Contractors<-Contractors%>%
  arrange(std_name, category, division, unit)%>%
  arrange(std_name, desc(maxvolume))%>%
  group_by(std_name)%>%
  mutate(
    category=category[1],
    division=division[1],
    unit=unit[1]
  )%>%
  ungroup()%>%
  mutate(n=row_number())
    
Contractors_1<-Contractors%>%
    group_by(std_name, category, division, unit)%>%
    summarise_at(vars(maxvolume, maxvolume_mi,  maxvolume_base, maxvolume_project, starts_with("mvcat_")),
               sum, na.rm=TRUE )%>%
  ungroup()

Contractors_2<-Contractors%>%
  group_by(std_name, category, division, unit)%>%
  summarise_at(vars( mi, ag, project, base),
                    max, na.rm=TRUE )%>%
  ungroup()


Contractors_3<-Contractors%>%
  group_by(std_name, category, division, unit)%>%
  summarise(n=count(n))%>%
  ungroup()

CONTRACTORS<-Contractors_1%>%
  inner_join(Contractors_2)%>%
  inner_join(Contractors_3)%>%
  select(-n)

#Organising 

CONTRACTORS<-CONTRACTORS%>%
  rename(cvpcategory=category)%>%
  mutate(maxvolume_ag = maxvolume - maxvolume_mi)%>%
  select(std_name, maxvolume, maxvolume_mi, maxvolume_ag, everything())

#COMBINE DATA

CONTRACTORS<-CONTRACTORS%>%
  filter(!(std_name=="OAKDALE I.D." | std_name=="SOUTH SAN JOAQUIN I.D."))%>%
  filter(!(std_name== "U.S. FISH & WILDLIFE SERVICE - NORTH OF DELTA REFUGES" | 
            std_name=="U.S. FISH & WILDLIFE SERVICE - SOUTH OF DELTA REFUGES"))%>%
  slice(rep(1:n(), each=26))%>%
  group_by(std_name)%>%
  mutate(year=yearfirst - 1 + row_number())%>%
  ungroup()


#Merge in deliveries

Contract_delivery_3<-CONTRACTORS%>%
  inner_join(deliveries)

Contract_delivery_2<-deliveries%>%
  anti_join(CONTRACTORS)

Contract_delivery_1<-CONTRACTORS%>%
  anti_join(deliveries)

CONTRACTORS<-Contract_delivery_3%>%
  bind_rows(Contract_delivery_2)%>%
  bind_rows(Contract_delivery_1)

CONTRACTORS<-CONTRACTORS%>%
  mutate(merge=case_when(
    row_number() %in% c(1:3206) ~ 3,
    row_number() %in% c(3207:4020) ~ 2,
    row_number() %in% c(4021:6872) ~ 1
  ))

#Note: 1:3206 correspond to all matched data, 3207:4020 correspond do extra rows from 
#deliveries data and 4021:6872 correspond to extra rows from the CONTRACTS data

#Merge in percent allocations

CONTRACTORS<-CONTRACTORS%>%
  inner_join(pctallocations)

#Calculate calendar-year and water-year totals

CONTRACTORS<-CONTRACTORS%>%
  arrange(std_name, year)%>%
  mutate(
    deliv_nextJan=ifelse((lead(year) == year+1), lead(deliv_Jan), NA),
    deliv_nextFeb=ifelse((lead(year) == year+1), lead(deliv_Feb), NA)
  )
  
CONTRACTORS<-CONTRACTORS%>%
  mutate(
    deliveries_cy=ifelse(year>=1993, rowSums(select(., deliv_Jan, deliv_Feb,deliv_Mar, deliv_Apr,
                                                    deliv_May, deliv_Jun,
                                                    deliv_Jul, deliv_Aug, deliv_Sep, deliv_Oct,
                                                    deliv_Nov, deliv_Dec), na.rm = TRUE), NA),
    deliveries_wy=ifelse(year>=1993, rowSums(select(.,deliv_Mar, deliv_Apr, deliv_May, deliv_Jun,
                                               deliv_Jul, deliv_Aug, deliv_Sep, deliv_Oct,
                                               deliv_Nov, deliv_Dec, deliv_nextJan, 
                                               deliv_nextFeb),
                                         na.rm = TRUE), NA)
  )%>%
  select(std_name, starts_with("deliveries"), everything())


#Calculate deliveries by sector (when user is in both sectors, assume deliveries
#are allocated in the same ratio as the maximum contract volume)

CONTRACTORS<-CONTRACTORS%>%
  mutate(
     deliveries_cy_ag=ifelse(!is.na(deliveries_cy), 0, NA),
     deliveries_wy_ag=ifelse(!is.na(deliveries_wy), 0, NA),
     deliveries_cy_mi=ifelse(!is.na(deliveries_cy), 0, NA),
     deliveries_wy_mi=ifelse(!is.na(deliveries_wy), 0, NA),
     deliveries_cy_ag=ifelse(!is.na(maxvolume), round(deliveries_cy * (maxvolume_ag / maxvolume),0),
                                                      deliveries_cy_ag),
     deliveries_wy_ag=ifelse(!is.na(maxvolume), round(deliveries_wy * (maxvolume_ag / maxvolume),0),
                                                      deliveries_wy_ag),
     deliveries_cy_mi=ifelse(!is.na(maxvolume), deliveries_cy - deliveries_cy_ag, deliveries_cy_ag),
     deliveries_wy_mi=ifelse(!is.na(maxvolume), deliveries_wy - deliveries_wy_ag, deliveries_cy_ag)
  )%>%
  select(std_name, starts_with("deliveries"), everything())

#For delivery recipients not appearing in list of contracts:
#(note missing(maxvolume) is the same as mergedeliveries==2)

#drop environmental users
#drop if not delivered anything
CONTRACTORS<-CONTRACTORS%>%
  filter(!(merge==2 & str_detect(std_name,"GUN CLUB|WATERFOWL|GRASSLAND|WILDLIFE|FOREST SERVICE|MILLERTON LK")))%>%
  filter(!(merge==2 & deliveries_cy==0 & deliveries_wy==0))

#classify sector (provided in contract list but not in deliveries data)

CONTRACTORS<-CONTRACTORS%>%
  mutate(sector=case_when(
    (merge==2 & str_detect(std_name," I[.]D[.]")) ~ 0,
    (merge==2 & str_detect(std_name,"FARM|RANCH|IRRIGATION|VINEYARD| LAND")) ~ 0,
    (merge==2 & str_detect(std_name,"CITY OF|PROPERTIES|CONSTRUCTION|GOLF|UNIVERSITY|INC[.]|LOS BANOS GRAVEL")) ~1,
    (merge==2 & str_detect(std_name," P[.]U[.]D[.]")) ~ 1,
    (merge==2 & std_name=="KINGS COUNTY W.D.") ~ 0,
    (merge==2 & std_name=="LA GRANGE W.D.") ~ 1,
    (merge==2 & std_name=="LAKESIDE W.D.") ~ 1
  )
  )

CONTRACTORS<-CONTRACTORS%>%
  mutate(sector=ifelse(merge==2 & is.na(sector), 0, sector))

# allocate deliveries by sector

CONTRACTORS<-CONTRACTORS%>%
  mutate(
    deliveries_cy_ag=ifelse(merge==2 & sector==0, deliveries_cy, deliveries_cy_ag),
    deliveries_wy_ag=ifelse(merge==2 & sector==0, deliveries_wy, deliveries_wy_ag),
    deliveries_cy_mi=ifelse(merge==2 & sector==1, deliveries_cy, deliveries_cy_mi),
    deliveries_wy_mi=ifelse(merge==2 & sector==1, deliveries_wy, deliveries_wy_mi),
  )

#Calculate allocation volumes & overall allocation percentage

CONTRACTORS<-CONTRACTORS%>%
  mutate(
    allo_ag_american=mvcat_ag_american * pct_american / 100,
    allo_mi_american=mvcat_mi_american * pct_american / 100,
    allo_ag_friant1=mvcat_ag_friant1 * pct_friant1 / 100,
    allo_mi_friant1=mvcat_mi_friant1 * pct_friant1 / 100,
    allo_ag_friant2=mvcat_ag_friant2 * pct_friant2 / 100,
    allo_mi_friant2=mvcat_mi_friant2 * pct_friant2 / 100,
    allo_ag_friant0=mvcat_ag_friant0 * pct_friant0 / 100,
    allo_mi_friant0=mvcat_mi_friant0 * pct_friant0 / 100,
    allo_ag_indelta=mvcat_ag_indelta  * pct_indelta / 100,
    allo_mi_indelta=mvcat_mi_indelta  * pct_indelta / 100,
    allo_ag_nrights=mvcat_ag_nrights * pct_nrights / 100,
    allo_mi_nrights=mvcat_mi_nrights * pct_nrights / 100,
    allo_ag_srights=mvcat_ag_srights * pct_srights / 100,
    allo_mi_srights=mvcat_mi_srights * pct_srights / 100,
    allo_ag_eastside=mvcat_ag_eastside * pct_eastside / 100,
    allo_mi_eastside=mvcat_mi_eastside * pct_eastside / 100
  )

CONTRACTORS<-CONTRACTORS%>%
  mutate(
    allo_ag_north = mvcat_ag_north * pct_nag / 100,
    allo_mi_north = mvcat_mi_north * pct_nmi / 100,
    allo_ag_south = mvcat_ag_south * pct_sag / 100,
    allo_mi_south = mvcat_mi_south * pct_smi / 100,
    totallo_ag = rowSums(select(. , starts_with("allo_ag_"))),
    totallo_mi = rowSums(select(. , starts_with("allo_mi_"))),
    totallo = rowSums(select(. , starts_with("totallo_"))),
    pctallo = totallo / maxvolume,
    pctallo_ag = totallo_ag / maxvolume_ag,
    pctallo_mi = totallo_mi / maxvolume_mi,
    pctallo=ifelse(maxvolume==0, 0, pctallo),
    pctallo_ag=ifelse(maxvolume_ag==0, 0, pctallo_ag),
    pctallo_mi=ifelse(maxvolume_mi==0, 0, pctallo_mi)
  )

#Organize, remove variables no longer needed, rename

CONTRACTORS<-CONTRACTORS%>%
  select(year, std_name, deliveries_cy, deliveries_cy_ag, deliveries_cy_mi, deliveries_wy,
         deliveries_wy_ag, deliveries_wy_mi, maxvolume, maxvolume_ag, maxvolume_mi, 
         maxvolume_base, maxvolume_project, pctallo, pctallo_ag, pctallo_mi)%>%
         rename_at(vars(starts_with("maxvolume_")), funs(str_remove_all(., "ume")))%>%
         rename_at(vars(deliveries_cy: pctallo_mi), funs(paste0("cvp_", .)))

save(CONTRACTORS, file = paste0(OUTPUT, "allocations_source_cvp.RData"))
         
         
  







