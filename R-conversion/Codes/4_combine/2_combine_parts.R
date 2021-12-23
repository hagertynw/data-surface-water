library(readr)
library(tidyverse)
library(dplyr)
library(readxl)
library(sf)
library(stringi)
library(ggplot2)
library(haven)

rm(list=ls())

##Setting_directories (Change root directory while running codes)

Root<- "/Users/shubhalakshminag/Box/CA_Surface_water/"

#RAW_DATA#

DATA_SWP<- paste0( Root, "data/swp/")
REF_KERN<-paste0(Root, "data/conglomerates/kern/")

#TEMP_FILE#

DATA_TEMP<-	paste0( Root, "R/Temp/")

#FINAL_OUTPUT#

OUTPUT<-paste0( Root, "R/Output/")

load(paste0(OUTPUT, "allocations_source_cvp.RData"))
load(paste0(OUTPUT, "allocations_source_loco.RData"))
load(paste0(OUTPUT, "allocations_source_swp.RData"))
load(paste0(OUTPUT, "allocations_source_rights_yearly.RData"))
load(paste0(OUTPUT, "allocations_source_rights_means.RData"))

allocations_source_cvp<-CONTRACTORS
allocations_source_swp<-deliveries
allocations_source_loco<-Diversion

#Starting with cvp data and merging swp data 

cvp_extra<-allocations_source_cvp%>%
  anti_join(allocations_source_swp)

swp_extra<-allocations_source_swp%>%
  anti_join(allocations_source_cvp)

allocations_source_cvp<-allocations_source_cvp%>%
  inner_join(allocations_source_swp)

allocations_source_cvp<-allocations_source_cvp%>%
  bind_rows(cvp_extra)%>%
  bind_rows(swp_extra)
 
allocations_source_cvp<-allocations_source_cvp%>%
  mutate(merge_swp=case_when(
    row_number() %in% c(1:63) ~ 3,
    row_number() %in% c(6463:8850) ~ 2,
    row_number() %in% c(64:6462) ~ 1
  ))  

#Merge with Lower Colorado data

allocations_source_loco$year=as.numeric(allocations_source_loco$year)

cvp_extra_1<-allocations_source_cvp%>%
  anti_join(allocations_source_loco)

loco_extra<-allocations_source_loco%>%
  anti_join(allocations_source_cvp)

allocations_source_cvp<-allocations_source_cvp%>%
  inner_join(allocations_source_loco)

allocations_source_cvp<-allocations_source_cvp%>%
  bind_rows(cvp_extra_1)%>%
  bind_rows(loco_extra)
 

allocations_source_cvp<-allocations_source_cvp%>%
  mutate(merge_loco=case_when(
    row_number() %in% c(1:78) ~ 3,
    row_number() %in% c(8851:9318) ~ 2,
    row_number() %in% c(79:8850) ~ 1
  ))  

#Keep only years after 1980

allocations_source_cvp<-allocations_source_cvp%>%
  filter(year>=1981)

#Make a balanced panel of average diversions to match project data

firstyear=1981
lastyear=max(allocations_source_cvp$year)

rights_means<-as.data.frame(matrix(0, nrow =lastyear- firstyear +1))

rights_means<-rights_means%>%
  rename(year=V1)%>%
  mutate(year=firstyear - 1 + row_number())

rights_means<-crossing(rights_means, allocations_source_rights_means)

#Merge in water rights (average diversions)

cvp_extra_2<-allocations_source_cvp%>%
  anti_join(rights_means)

means_extra<-rights_means%>%
  anti_join(allocations_source_cvp)

allocations_source_cvp<-allocations_source_cvp%>%
  inner_join(rights_means)

allocations_source_cvp<-allocations_source_cvp%>%
  bind_rows(cvp_extra_2)%>%
  bind_rows(means_extra)

allocations_source_cvp<-allocations_source_cvp%>%
  mutate(merge_rights1=case_when(
    row_number() %in% c(1:3177) ~ 3,
    row_number() %in% c(8490:270590) ~ 2,
    row_number() %in% c(3178:8489) ~ 1
  ))  


#Merge in water rights (yearly diversions)

cvp_extra_3<-allocations_source_cvp%>%
  anti_join(allocations_source_rights_yearly)

allocations_source_cvp<-allocations_source_cvp%>%
  inner_join(allocations_source_rights_yearly)

allocations_source_cvp<-allocations_source_cvp%>%
  bind_rows(cvp_extra_3)

allocations_source_cvp<-allocations_source_cvp%>%
  mutate(merge_rights2=case_when(
    row_number() %in% c(1:21739) ~ 3,
    row_number() %in% c(21740:270590) ~ 1
  ))  

#Expand to create a balanced panel

allocations_all<-allocations_source_cvp%>%
  complete(std_name, nesting(year))
  
#Fill in zeroes to clarify data. After this point:
#Zeros: no deliveries were received in that year (known zero) 
#Missing values: no data was available for that year (unknown)

allocations_all<-allocations_all%>%
  rename(cvp_deliveries=cvp_deliveries_cy)

cvp_yearlast<-with(allocations_all, max(year[!is.na(cvp_deliveries)]))
cvp_yearfirst<-with(allocations_all, min(year[!is.na(cvp_deliveries)]))
swp_yearlast<-with(allocations_all, max(year[!is.na(swp_deliveries)]))
swp_yearfirst<-with(allocations_all, min(year[!is.na(swp_deliveries)]))
loco_yearlast<-with(allocations_all, max(year[!is.na(loco_deliveries)]))
loco_yearfirst<-with(allocations_all, min(year[!is.na(loco_deliveries)]))

allocations_all<-allocations_all%>%
  mutate_at(vars(starts_with("cvp_")), funs(ifelse(is.na(.) & between(year, cvp_yearfirst,
                                                                    cvp_yearlast),
                                                 0, .)))%>%
  mutate_at(vars(starts_with("swp_")), funs(ifelse(is.na(.) & between(year, swp_yearfirst,
                                                                      swp_yearlast),
                                                   0, .)))%>%
  mutate_at(vars(starts_with("loco_")), funs(ifelse(is.na(.) & between(year, loco_yearfirst,
                                                                    loco_yearlast),
                                                 0, .)))

allocations_all<-allocations_all%>%
    rename(cvp_deliveries_cy=cvp_deliveries)%>%
    mutate_at(vars(starts_with("rights_avgdivert")), 
              funs(ifelse(is.na(.), 0, .)))

#Correct duplicate reporting for CVP settlement/exchange contractors
#These users hold water rights but receive their water as CVP deliveries, so the same water
#likely appears in the data twice: as water rights diversions and as CVP deliveries.)
#To correct this, I subtract CVP maximum entitlements from average rights diversions.
#An alternative would be to subtract CVP actual deliveries. But we don't know whether rights-
#holders are reporting diversions net of cutbacks or not. To err on the side of not 
#introducing more noise, I assume none are cutbacks.
#This may mean I am underestimating rights for some users that hold rights both converted
#under USBR settlement/exchange agreements and not (still directly diverting).
#I also subtract CVP actual deliveries from year-specific reported rights diversions.

allocations_all<-allocations_all%>%
  mutate(corr_rights_avgdivert = rights_avgdivert,
         corr_rights_avgdivert_ag = rights_avgdivert_ag,
         corr_rights_diversion_ag = rights_diversion_ag)%>%
  rowwise()%>%
  mutate(corr_rights_avgdivert = 
           ifelse(cvp_maxvol_base>0 & !is.na(cvp_maxvol_base) & 
                    rights_avgdivert>0 & !is.na(rights_avgdivert),
                    max(0, rights_avgdivert - cvp_maxvol_base) ,
                    corr_rights_avgdivert),
         corr_rights_avgdivert_ag =
           ifelse(cvp_maxvol_base>0 & !is.na(cvp_maxvol_base) &
                    rights_avgdivert_ag>0 & !is.na(rights_avgdivert_ag),
                  max(0, rights_avgdivert_ag - cvp_maxvol_base) ,
                  corr_rights_avgdivert_ag ),
         corr_rights_diversion_ag =
           ifelse(cvp_deliveries_cy_ag>0 & !is.na(cvp_deliveries_cy_ag) & 
                    rights_diversion_ag>0 & !is.na(rights_diversion_ag),
                  max(0, rights_diversion_ag - cvp_deliveries_cy_ag),
                  corr_rights_diversion_ag)
         )%>%
  ungroup()%>%
  mutate(corr_rights_avgdivert_mi = corr_rights_avgdivert - corr_rights_avgdivert_ag,
         corr_rights_diversion_mi = corr_rights_diversion_ag - corr_rights_diversion_ag
         )

allocations_all<-allocations_all%>%
  mutate(rights_avgdivert=corr_rights_avgdivert,
            rights_avgdivert_mi=corr_rights_avgdivert_mi,
            rights_avgdivert_ag=corr_rights_avgdivert_ag,
            rights_diversion_mi=corr_rights_diversion_mi,
            rights_diversion_ag=corr_rights_diversion_ag)%>%
  select(-c(starts_with("corr_")))

#Construct sums across water sources

#deliveries & diversions, including CVP deliveries for the calendar year

allocations_all<-allocations_all%>%
  mutate(vol_deliv_cy=cvp_deliveries_cy+swp_deliveries+loco_deliveries+rights_avgdivert,
         vol_deliv_cy_ag=cvp_deliveries_cy_ag+swp_deliveries_ag+loco_deliveries_ag+rights_avgdivert_ag,
         vol_deliv_cy_mi=cvp_deliveries_cy_mi+swp_deliveries_mi+loco_deliveries_mi+rights_avgdivert_mi,
         #deliveries & diversions, including CVP deliveries for the water year
         vol_deliv_wy=cvp_deliveries_wy+swp_deliveries+loco_deliveries  
         + rights_avgdivert,
         vol_deliv_wy_ag=cvp_deliveries_wy_ag+swp_deliveries_ag+loco_deliveries_ag
         + rights_avgdivert_ag,
         vol_deliv_wy_mi=cvp_deliveries_wy_mi+swp_deliveries_mi+loco_deliveries_mi 
         + rights_avgdivert_mi,
         #maximum entitlements
         vol_maximum=cvp_maxvolume+swp_basemax+loco_maxvol+rights_avgdivert,
         vol_maximum_ag=cvp_maxvol_ag+swp_basemax_ag+loco_maxvol_ag+rights_avgdivert_ag,
         vol_maximum_mi=cvp_maxvol_mi+swp_basemax_mi+loco_maxvol_mi+rights_avgdivert_mi)

#overall allocation percentage (average of allocation percentages 
#weighted by maximum entitlement)

allocations_all<-allocations_all%>%
  mutate(allo_cvp_ag = cvp_maxvol_ag * cvp_pctallo_ag,
         allo_cvp_mi = cvp_maxvol_mi * cvp_pctallo_mi,
         allo_swp_ag = swp_basemax_ag * swp_pctallo_ag,
         allo_swp_mi = swp_basemax_mi * swp_pctallo_mi,
         allo_tot_ag = allo_cvp_ag + allo_swp_ag + loco_maxvol_ag + rights_avgdivert_ag,
         allo_tot_mi = allo_cvp_mi + allo_swp_mi + loco_maxvol_mi + rights_avgdivert_mi,
         pct_allocation_ag = allo_tot_ag / vol_maximum_ag,
         pct_allocation_mi = allo_tot_mi / vol_maximum_mi)%>%
  mutate(allo_tot = rowSums(select(., starts_with("allo_tot_")), na.rm=TRUE),
         pct_allocation = allo_tot/vol_maximum)%>%
  select(!starts_with("allo_"))

#Drop false levels of precision
           
allocations_all<-allocations_all%>%
  mutate_at(vars(starts_with("vol_")), funs(round(., 1)))

#Clean up

allocations_all<-allocations_all%>%
  select(year, std_name, starts_with("vol_deliv"), starts_with("vol_maximum"),
         pct_allocation, starts_with("pct_allocation_"), starts_with("swp_deliveries") ,
         starts_with("swp_maxvol"), starts_with("swp_basemax"), starts_with("swp_pctallo"),
         starts_with("cvp_deliveries"), starts_with("cvp_maxvol"), cvp_maxvolume,
         starts_with("cvp_pctallo"),
         starts_with("loco_maxvol"), starts_with("loco_deliveries"), starts_with("rights_"),
         everything())%>%
  select(-c(cvp_maxvol_base, cvp_maxvol_project))%>%
  select(-c(parent, starts_with("merge")))

save(allocations_all, file = paste0(OUTPUT, "allocations_all.RData"))









  
  

