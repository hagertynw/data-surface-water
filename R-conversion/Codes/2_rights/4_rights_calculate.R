library(tidyverse)
library(readr)
library(stringr)
library(dplyr)
library(lubridate)
library(readxl)
library(labelled)
library(grid)
library(matrixStats)
library(haven)

rm(list=ls())

# Setting_directories (Change root directory while running codes)

Root<- "/Users/shubhalakshminag/Box/CA_Surface_water/"

# TEMP_FILE

DATA_TEMP<-	paste0( Root, "R/Temp/")

# FINAL_OUTPUT

OUTPUT<-paste0( Root, "R/Output/")

# Load master names list

masternames_1<-read_excel(paste0(Root, "data/names_crosswalk_all.xlsx"))

masternames_2<-masternames_1%>%
  distinct()%>%
  rename(USER=user)

masternames<-masternames_1%>%
  distinct()%>%
  mutate(
    same=as.numeric(user==std_name)
  )%>%
  group_by(std_name)%>%
  mutate(totsame=sum(same))%>%
  ungroup()%>%
  filter(totsame==0)%>%
  select(std_name)%>%
  distinct()%>%
  mutate(USER=std_name)%>%
  select(USER, std_name)
  
masternames<-bind_rows(masternames, masternames_2)

#Load Kings River district areas (for reallocation of association)
#load list of members

king_members<-read_excel(paste0(Root,"data/conglomerates/kings/kings_members.xlsx"))

king_members<-king_members%>%
  filter(notes!="Doesn't use Kings River. Operates Reclamation District 1606." &
         notes!="Doesn't use Kings River" | is.na(notes))%>%
  filter(!is.na(std_name))%>%
  select(std_name)%>%
  rename(USER=std_name)

king_members<-king_members%>%
  inner_join(masternames)%>%
  select(std_name)

#load district areas
userXdauco<-read_dta(paste0(Root, "temp/intersections_districtXdauco.dta"))

userXdauco<-userXdauco%>%
  select(c(user_id: user_area, user_cropland))%>%
  distinct()

Kings_areas<-userXdauco%>%
  inner_join(king_members)%>%
  mutate(tot_cropland = sum(user_cropland),
         kings_pct_cropland = user_cropland/tot_cropland)%>%
  select(std_name, user_cropland, kings_pct_cropland)%>%
  rename(std_name2=std_name)

#Rights data (combined)
load(paste0(DATA_TEMP, "waterrights_diversions.RData"))
WR_diversion<-Combine

Master_extra<-WR_diversion%>%
  anti_join(masternames)

Diversion<-WR_diversion%>%
  inner_join(masternames)

Diversion<-bind_rows(Diversion, Master_extra)

#Note observations 1:25,496 correspond to matched data (corresponding to merge==3 in stata)

Diversion<-Diversion%>%
  select(!USER)%>%
  select(APPNO, std_name, everything())

#Drop obs SWRCB has determined are not using rights or are duplicates

Diversion<-Diversion%>%
  filter(avgdiversion!=0|is.na(avgdiversion))

#Drop obs not reporting usage data to SWRCB (their face value is small so this should not be a problem)
#(more specifically, face value of users who don't report any volumes is small)

Diversion<-Diversion%>%
  filter(!is.na(avgdiversion))

#Drop water rights reported as part of federal & state projects

Diversion<-Diversion%>%
  rename(SOURCE_NAME=source_name)%>%
  filter(std_name!="U.S. BUREAU OF RECLAMATION")%>%
  filter(std_name!="CALIFORNIA DEPT. OF WATER RESOURCES")%>%
  filter(SOURCE_NAME!="COLORADO RIVER")

#Categorize beneficial uses

Diversion<-Diversion%>%
  mutate(
    use_agriculture = 0,
    use_municipal = 0,
    use_nonconsumptive = 0,
    use_other = 0
  )

#Agriculture use

Diversion<-Diversion%>%
  mutate(
    use_agriculture = replace(use_agriculture, benuse11==1, 1), #Irrigation
    use_agriculture = replace(use_agriculture, benuse19==1, 1), #Stockwatering
    use_municipal = replace(use_municipal, benuse3==1, 1), #Domestic
    use_municipal = replace(use_municipal, benuse10==1, 1), #Industrial
    use_municipal = replace(use_municipal, benuse14==1, 1), #Municipal
    use_nonconsumptive = replace(use_nonconsumptive, benuse1==1, 1), #Aesthetic
    use_nonconsumptive = replace(use_nonconsumptive, benuse2==1, 1), #Aquaculture
    use_nonconsumptive = replace(use_nonconsumptive, benuse6==1, 1), #Fish & wildlife
    use_nonconsumptive = replace(use_nonconsumptive, benuse9==1, 1), #Incidental power
    use_nonconsumptive = replace(use_nonconsumptive, benuse16==1, 1), #Power
    use_nonconsumptive = replace(use_nonconsumptive, benuse17==1, 1), #Recreational
    use_nonconsumptive = replace(use_nonconsumptive, benuse18==1, 1), #Snow-making
    use_other = replace(use_other, benuse0==1, 1), 
    use_other = replace(use_other, benuse4==1, 1), #Dustcontrol
    use_other = replace(use_other, benuse5==1, 1), #Fire protection
    use_other = replace(use_other, benuse7==1, 1), #Frost protection
    use_other = replace(use_other, benuse8==1, 1), #Heat control
    use_other = replace(use_other, benuse12==1, 1), #Milling
    use_other = replace(use_other, benuse13==1, 1), #Mining
    use_other = replace(use_other, benuse15==1, 1) #Other
  )

#Drop nonconsumptive uses

Diversion<-Diversion%>%
  filter(!(use_nonconsumptive==1 & use_agriculture==0 & use_municipal==0 & use_other==0))

####Assumed environmental/recreational based on name

Diversion<-Diversion%>%
  filter(std_name!="WHITE MALLARD, INC.")%>%
  filter(std_name!="PINE MOUNTAIN LAKE ASSOCIATION")%>%
  filter(std_name!="NATURE CONSERVANCY")%>%
  filter(std_name!="WOODY'S ON THE RIVER, LLC")%>%
  filter(!str_detect(std_name, "DUCK CLUB|GUN CLUB|SHOOTING CLUB"))%>%
  filter(!str_detect(std_name, "FISH & WILDLIFE"))%>%
  filter(!str_detect(std_name, "FOREST SERVICE"))%>%
  filter(!str_detect(std_name, "BUREAU OF LAND MANAGEMENT"))%>%
  filter(!str_detect(std_name, "NATIONAL PARK SERVICE"))%>%
  filter(!str_detect(std_name, "PARKS & RECREATION"))%>%
  filter(!str_detect(std_name, "FORESTRY & FIRE PREVENTION"))%>%
  filter(!str_detect(std_name, "WATERFOWL|PRESERVATION|WETLANDS|TUSCANY RESEARCH"))

####Assumed electricity generation based on name

Diversion<-Diversion%>%
  filter(!(use_agriculture==0 & std_name=="SOUTHERN CALIFORNIA EDISON COMPANY"))%>%
  filter(!(use_agriculture==0 & std_name=="PACIFIC GAS & ELECTRIC CO."))%>%
  filter(!(use_agriculture==0 & str_detect(std_name, "POWER ")
           & !str_detect(std_name, "WATER")))

#Designate right as Ag or MI (municipal/industrial), based on whether it lists
#irrigation or stockwatering as a beneficial use.

Diversion<-Diversion%>%
  rename(ag=use_agriculture)%>%
  mutate(
    ag=ifelse(str_detect(std_name, "CITY OF"), 0, ag), #Cities to MI
    ag=ifelse(str_detect(std_name, " GOLF "), 0, ag), #Gold courses to MI
    ag=ifelse(std_name=="ORANGE COUNTY W.D.", 0, ag), #Manually verified in Orange County
    ag=ifelse(std_name=="SERRANO W.D.", 0, ag),
    ag=ifelse(std_name=="IRVINE RANCH W.D.", 0, ag),
    ag=ifelse(std_name=="SANTA MARGARITA W.D.", 0, ag)
  )

#Reallocate jointly-held rights to member districts

Diversion<-Diversion%>%
  mutate(parent=NA)

#    Joint Water Districts Board
#    reference: Joint Water Districts.xlsx

Diversion<-Diversion%>%
  mutate(joint=as.numeric(std_name=="JOINT WATER DISTRICTS BOARD"))%>%
  mutate(parent=ifelse(joint==1, std_name, parent))

Diversion<-bind_rows(Diversion, 
                     Diversion%>%
                       filter(joint==1))

Diversion<-bind_rows(Diversion, 
                     Diversion%>%
                       filter(joint==1))

Diversion<-bind_rows(Diversion, 
                     Diversion%>%
                       filter(joint==1))


Diversion<-Diversion%>%
  group_by(std_name, APPNO)%>%
  mutate(member=ifelse(joint==1, row_number(), NA))%>%
  ungroup()%>%
  mutate(
    std_name=ifelse(joint==1 & member==1, "BUTTE W.D.", std_name),
    std_name=ifelse(joint==1 & member==2, "BIGGS-WEST GRIDLEY W.D.", std_name),
    std_name=ifelse(joint==1 & member==3, "RICHVALE I.D.", std_name),
    std_name=ifelse(joint==1 & member==4, "SUTTER EXTENSION W.D.", std_name)
  )

Diversion<-Diversion%>%
  mutate_at(vars(avgdiversion, starts_with("avgdiversion_m"), starts_with("diversion")),
            funs(ifelse((joint==1 & std_name=="BUTTE W.D."), .*0.24, .))
            )%>%
  mutate_at(vars(avgdiversion, starts_with("avgdiversion_m"), starts_with("diversion")),
            funs(ifelse((joint==1 & std_name=="BIGGS-WEST GRIDLEY W.D."), .*0.29, .))
  )%>%
  mutate_at(vars(avgdiversion, starts_with("avgdiversion_m"), starts_with("diversion")),
            funs(ifelse((joint==1 & std_name=="RICHVALE I.D."), .*0.27, .))
  )%>%
  mutate_at(vars(avgdiversion, starts_with("avgdiversion_m"), starts_with("diversion")),
            funs(ifelse((joint==1 & std_name=="SUTTER EXTENSION W.D."), .*0.20, .))
  )%>%
  select(!c(joint, member))

# Kings River Water Association

Diversion<-Diversion%>%
  mutate(kings=as.numeric(std_name=="KINGS RIVER WATER ASSOCIATION"))

Kings_realo<-Diversion%>%
  filter(kings==1)%>%
  mutate(parent=std_name)

Kings_realo<-Kings_realo%>%
  merge(Kings_areas)%>%
  mutate(std_name=std_name2)%>%
  mutate_at(vars(avgdiversion, starts_with("avgdiversion_m"), starts_with("diversion")),
            funs(.*kings_pct_cropland))%>%
  select(!c(std_name2, user_cropland, kings_pct_cropland))

Diversion<-Diversion%>%
  filter(kings!=1)%>%
  bind_rows(Kings_realo)

## Sum to user X sector (ag/mi)

Diversion<-Diversion%>%
  arrange(std_name, ag, APPNO)%>%
  group_by(std_name)%>%
  mutate(tot_avgdiversion=sum(avgdiversion))%>%
  group_by(std_name, ag)%>%
  mutate(
    tot_avgdiversion_mi=ifelse(ag==0, sum(avgdiversion), NA),
    tot_avgdiversion_ag=ifelse(ag==1, sum(avgdiversion), NA),
  )%>%
  group_by(std_name)%>%
  mutate(
    tot_avgdiversion_mi=tot_avgdiversion_mi[1],
    tot_avgdiversion_ag=tot_avgdiversion_mi[n()],
    )%>%
  ungroup()%>%
  mutate(
    tot_avgdiversion_mi=ifelse(is.na(tot_avgdiversion_mi), 0, tot_avgdiversion_mi),
    tot_avgdiversion_ag=ifelse(is.na(tot_avgdiversion_ag), 0, tot_avgdiversion_ag)
  )

#each year: show sum only if every right has a report

for(l in 2010:2014){
  Diversion<-Diversion%>%
    group_by(std_name, ag)%>%
    mutate(
      !!paste0("tot_mi_diversion", l):=ifelse(ag==0, sum(get(!!paste0("diversion_", l))), NA),
      !!paste0("tot_ag_diversion", l):=ifelse(ag==1, sum(get(!!paste0("diversion_", l))), NA),
      !!paste0("rpt_diversion", l, "_mi"):=ifelse(ag==0, 
                                                  count(!is.na(get(!!paste0("diversion_", l)))),
                                                  NA),
      !!paste0("rpt_diversion", l, "_ag"):=ifelse(ag==1, 
                                                  count(!is.na(get(!!paste0("diversion_", l)))),
                                                  NA),
      !!paste0("obs_diversion", l, "_mi"):=ifelse(ag==0, n(), NA),
      !!paste0("obs_diversion", l, "_ag"):=ifelse(ag==1, n(), NA))%>%
    ungroup()%>%
    mutate(
      !!paste0("tot_mi_diversion", l):=ifelse(get( !!paste0("rpt_diversion", l, "_mi"))!=
                                                 get( !!paste0("obs_diversion", l, "_mi")),
                                               NA,
                                               get(!!paste0("tot_mi_diversion", l))
                                               ),
      !!paste0("tot_ag_diversion", l):=ifelse(get( !!paste0("rpt_diversion", l, "_ag"))!=
                                                 get( !!paste0("obs_diversion", l, "_ag")),
                                               NA,
                                               get(!!paste0("tot_ag_diversion", l)))
    )%>%
    group_by(std_name)%>%
    mutate(
      !!paste0("tot_mi_diversion", l):=get(!!paste0("tot_mi_diversion", l))[1],
      !!paste0("tot_ag_diversion", l):=get(!!paste0("tot_ag_diversion", l))[n()]
    )
}

Diversion<-Diversion%>%
  select(!c(starts_with("rpt"), starts_with("obs_")))

# Find min, max, median, and mean start years

Diversion<-Diversion%>%
  arrange(std_name)%>%
  group_by(std_name)%>%
  mutate(
    min_year=min(yearstart),
    max_year=max(yearstart)
  )%>%
  ungroup()%>%
  mutate(
    yearXvol = yearstart*avgdiversion
  )%>%
  group_by(std_name)%>%
  mutate(tot_yearXvol = sum(yearXvol, na.rm = TRUE))%>%
  ungroup()%>%
  mutate(mean_year = tot_yearXvol / tot_avgdiversion)%>%
  select(!c(yearXvol,tot_yearXvol))

#Drop rights with no location information (drops 151 obs & 42k af)

Diversion<-Diversion%>%
  filter(!(is.na(latitude)|is.na(longitude)))

#Collapse to user, keeping location information for one representative POD (of largest volume)

Diversion<-Diversion%>%
  arrange(std_name, desc(avgdiversion))%>%
  group_by(std_name)%>%
  filter(row_number()==1)%>%
  ungroup()%>%
  select(c(std_name, parent, latitude, longitude, starts_with("tot"), ends_with("year")))%>%
  arrange(desc(tot_avgdiversion))%>%
  distinct()

#Drop false levels of precision

Diversion<-Diversion%>%
  mutate_at(vars(contains("diversion")), funs(round(.,1)))

#Reshape to user X year

Diversion<-Diversion%>%
  gather(year, total_diversion, tot_mi_diversion2010: tot_ag_diversion2014)%>%
  separate(year, c("TOT", "ag_mi", "Div"), sep = "\\_")%>%
  mutate(Div=str_remove(Div, "diversion"))%>%
  rename(year=Div)%>%
  select(!TOT)%>%
  spread(ag_mi, total_diversion)%>%
  rename(tot_diversion_mi=mi,
         tot_diversion_ag=ag)

# Rename and order variables

Diversion<-Diversion%>%
  rename(rights_avgdivert=tot_avgdiversion,
         rights_avgdivert_mi=tot_avgdiversion_mi,
         rights_avgdivert_ag=tot_avgdiversion_ag,
         rights_diversion_mi=tot_diversion_mi,
         rights_diversion_ag=tot_diversion_ag,
         rights_pod_latitude=latitude,
         rights_pod_longitude=longitude,
         rights_mean_year=mean_year,
         rights_min_year=min_year,
         rights_max_year=max_year)%>%
  select(std_name, year, parent, rights_avgdivert, rights_avgdivert_ag, rights_avgdivert_mi,
           rights_diversion_ag, rights_diversion_mi, rights_pod_latitude, rights_pod_longitude)

allocations_source_rights_means<-Diversion%>%
  select(!c(year, rights_diversion_ag, rights_diversion_mi))%>%
  distinct()

allocations_source_rights_yearly<-Diversion%>%
  select(!starts_with("rights_avgdivert"))%>%
  filter(!(is.na(rights_diversion_ag) & is.na(rights_diversion_mi)))%>%
  arrange(std_name, year)

save(allocations_source_rights_means, file = paste0(OUTPUT,
                                                    "allocations_source_rights_means.RData"))  
save(allocations_source_rights_yearly, file = paste0(OUTPUT, 
                                                     "allocations_source_rights_yearly.RData"))  



















  


















