library(tidyverse)
library(readr)
library(stringr)
library(dplyr)
library(lubridate)
library(stringi)

rm(list=ls())

##Setting_directories (Change root directory while running codes)

Root<- "/Users/shubhalakshminag/Box/CA_Surface_water/"

 #RAW_DATA#

DATA_SWP<- paste0( Root, "data/swp/")
DATA_CVP	<- paste0( Root, "data/cvp/")
DATA_LOCO<- paste0( Root, "data/colorado/")
DATA_RIGHTS<- paste0( Root, "data/rights/")
DATA_GIS<-	paste0( Root, "data/gis/")

 #TEMP_FILE#

DATA_TEMP<-	paste0( Root, "R/Temp/")

 #FINAL_OUTPUT#

OUTPUT<-paste0( Root, "R/Output/")

##Loading_the_data

ewrims_data_raw<-read_csv(paste0(DATA_RIGHTS, "ewrims/wr70_corrected.csv"),
                          col_types = cols(
                            RIPARIAN = col_character(),
                            PRE_1914 = col_character(),
                            PERMIT_TERM91 = col_double(),
                            LICENSE_TERM91 = col_double(),
                            YEAR_FIRST_USE = col_double()
                          )
)

ewrims_data_raw<-ewrims_data_raw %>%
  mutate(HUC_12=as.character(HUC_12))

ewrims_data_raw <- ewrims_data_raw %>%
  select(!c(starts_with("DD_BEG_"), starts_with("DD_END_"), 
            starts_with("STORE_BEG_"), starts_with("STORE_END_"), "POD_NBR"))

#Establishing whether right has any storage 

ewrims_data_raw <-ewrims_data_raw%>%
  mutate(storage=as.integer(str_detect(DIVERSION_TYPE, "Storage")))

ewrims_data_raw$storage[is.na(ewrims_data_raw$storage)]<-0

ewrims_data_raw <-ewrims_data_raw%>%
  group_by(WR_WATER_RIGHT_ID)%>%
  mutate(anystorage=max(storage))%>%
  ungroup()%>%
  select(!("storage"))%>%
  select(1:7, anystorage, everything())

#Establishing unique ID

ewrims_data_raw <-ewrims_data_raw%>%
  distinct()%>%
  arrange(WR_WATER_RIGHT_ID, POD_ID, BENEFICIAL_USE)%>%
  group_by(WR_WATER_RIGHT_ID, POD_ID, BENEFICIAL_USE)%>%
  mutate(dups=cumsum(count=n()-1))%>%
  ungroup()

#Taking the largest value in case of duplicates

ewrims_data_raw <-ewrims_data_raw%>%
  arrange(WR_WATER_RIGHT_ID, POD_ID, BENEFICIAL_USE,
          desc(DIRECT_DIVERSION_AMOUNT))%>%
  group_by(WR_WATER_RIGHT_ID, POD_ID, BENEFICIAL_USE)%>%
  mutate(DIRECT_DIVERSION_AMOUNT=ifelse((dups>0 & row_number()>1), 
                                        DIRECT_DIVERSION_AMOUNT[1], DIRECT_DIVERSION_AMOUNT))

ewrims_data_raw <-ewrims_data_raw%>%
  arrange(WR_WATER_RIGHT_ID, POD_ID, BENEFICIAL_USE, desc(STORAGE_AMOUNT))%>%
  group_by(WR_WATER_RIGHT_ID, POD_ID, BENEFICIAL_USE)%>%
  mutate(STORAGE_AMOUNT=ifelse((dups>0 & row_number()>1), STORAGE_AMOUNT[1], STORAGE_AMOUNT))

ewrims_data_raw <-ewrims_data_raw%>%
  arrange(WR_WATER_RIGHT_ID, POD_ID, BENEFICIAL_USE, desc(NET_ACRES))%>%
  group_by(WR_WATER_RIGHT_ID, POD_ID, BENEFICIAL_USE)%>%
  mutate(NET_ACRES=ifelse((dups>0 & row_number()>1), NET_ACRES[1], NET_ACRES))


ewrims_data_raw <-ewrims_data_raw%>%
  arrange(WR_WATER_RIGHT_ID, POD_ID, BENEFICIAL_USE, desc(GROSS_ACRES))%>%
  group_by(WR_WATER_RIGHT_ID, POD_ID, BENEFICIAL_USE)%>%
  mutate(GROSS_ACRES=ifelse((dups>0 & row_number()>1), GROSS_ACRES[1], GROSS_ACRES))%>%
  ungroup()

ewrims_data_raw <-ewrims_data_raw%>%
  select(!("dups"))%>%
  distinct()%>%
  group_by(BENEFICIAL_USE)%>%
  mutate(useid=group_indices())%>%
  mutate(useid=replace(useid, useid==20, 0))%>%
  ungroup()

#Making acreage unique within right X prod

ewrims_data_raw <-ewrims_data_raw%>%
  mutate(NET_ACRES=replace(NET_ACRES, BENEFICIAL_USE != "Irrigation", NA))%>%
  mutate(GROSS_ACRES=replace(GROSS_ACRES, BENEFICIAL_USE != "Irrigation", NA))%>%
  arrange(WR_WATER_RIGHT_ID, POD_ID, desc(NET_ACRES))%>%
  group_by(WR_WATER_RIGHT_ID, POD_ID)%>%
  mutate(NET_ACRES=replace(NET_ACRES, NET_ACRES %in% NA, NET_ACRES[1]))%>%
  ungroup()%>%
  arrange(WR_WATER_RIGHT_ID, POD_ID, desc(GROSS_ACRES))%>%
  group_by(WR_WATER_RIGHT_ID, POD_ID)%>%
  mutate(GROSS_ACRES=replace(GROSS_ACRES, GROSS_ACRES  %in% NA, GROSS_ACRES[1]))%>%
  ungroup()

#Reshape to right X pod

USE <- function(df , n){
  varname <- paste0("use", n, "_0")
  df %>%
    arrange(WR_WATER_RIGHT_ID, POD_ID, useid)%>%
    mutate(!!varname := ifelse(as.numeric(useid)==n, 1, 0))
}

USE1 <- function(df , n){
  varname <- paste0("use", n)
  df %>%
    arrange(WR_WATER_RIGHT_ID, POD_ID, useid)%>%
    group_by(WR_WATER_RIGHT_ID, POD_ID)%>%
    mutate(!!varname := sum(get(!!paste0("use", n, "_0"))))
}


for (i in 0:19){
  ewrims_data_raw <-USE(df=ewrims_data_raw, n=i)
  ewrims_data_raw <-USE1(df=ewrims_data_raw, n=i)
}

ewrims_data_raw <-ewrims_data_raw%>%
  select(!(ends_with("_0")&starts_with("use")))%>%
  select(!c("BENEFICIAL_USE", "BENEFICIAL_USE_LIST", "DIRECT_DIVERSION_AMOUNT", "DIRECT_DIVERSION_RATE_UNITS", 
            "STORAGE_AMOUNT", "STORAGE_AMOUNT_UNITS_1", "useid"))%>%
  ungroup()%>%
  distinct()

##Organising variables

ewrims_data_raw <-ewrims_data_raw%>%
  rename(APPNO=APPLICATION_NUMBER, USER=PRIMARY_OWNER, NETACRES=NET_ACRES, 
         GROSSACRES=GROSS_ACRES, FACEVALUE=FACE_VALUE_AMOUNT, HUC12=HUC_12,
         WRTYPE=WR_TYPE, STATUS=STATUS_TYPE, PRE1914=PRE_1914, FIRSTYEAR=YEAR_FIRST_USE)

##Cleaning 
##Note: Riparian and Pre1914 have no observations

ewrims_data_raw <-ewrims_data_raw%>%
  mutate(USER=str_squish(USER),
         USER=str_to_upper(USER),
         APPNO=str_squish(APPNO),
         RIPARIAN=ifelse(RIPARIAN %in% NA, 0, 1),
         PRE1914=ifelse(PRE1914 %in% NA, 0, 1),
         FACEVALUE=ifelse((RIPARIAN==1|PRE1914==1 & FACEVALUE==0), NA, FACEVALUE),
         FIRSTYEAR= ifelse(FIRSTYEAR<1500, NA, FIRSTYEAR)
        )

#Converting dates

ewrims_data_raw <-ewrims_data_raw%>%
  mutate(STATUS_DATE=mdy(STATUS_DATE))

ewrims_data_raw <-ewrims_data_raw%>%
  mutate(PERMIT_ORIGINAL_ISSUE_DATE=mdy(PERMIT_ORIGINAL_ISSUE_DATE))

ewrims_data_raw <-ewrims_data_raw%>%
  mutate(LICENSE_ORIGINAL_ISSUE_DATE=mdy(LICENSE_ORIGINAL_ISSUE_DATE))

#Dropping inactive PODs

ewrims_data_raw <-ewrims_data_raw%>%
  mutate(POD_STATUS=replace(POD_STATUS, POD_STATUS %in% NA, "Active"))%>%
  filter(str_detect(POD_STATUS, "Active"))%>%
  select(!POD_STATUS)

##Collapse rights to one POD, as per SWRCB methodology,
##but choosing the POD a bit more rationally
##tag duplicates

ewrims_data_raw <-ewrims_data_raw%>%
  group_by(WR_WATER_RIGHT_ID)%>%
  mutate(dups4=n()-1)%>%
  ungroup()%>%
  group_by(WR_WATER_RIGHT_ID, WATERSHED)%>%
  mutate(dups3=n()-1)%>%
  ungroup()%>%
  group_by(WR_WATER_RIGHT_ID, WATERSHED, SOURCE_NAME)%>%
  mutate(dups2=n()-1)%>%
  ungroup()%>%
  group_by(WR_WATER_RIGHT_ID, WATERSHED, SOURCE_NAME, HUC12)%>%
  mutate(dups1=n()-1)%>%
  ungroup()

ewrims_data_raw <-ewrims_data_raw%>%
  arrange(WR_WATER_RIGHT_ID, WATERSHED, SOURCE_NAME, HUC12, -dups1, POD_ID)%>%
  group_by(WR_WATER_RIGHT_ID, WATERSHED, SOURCE_NAME, HUC12)%>%
  slice(1)%>%
  ungroup()%>%
  arrange(WR_WATER_RIGHT_ID, WATERSHED, SOURCE_NAME, -dups1, -dups2, POD_ID)%>%
  group_by(WR_WATER_RIGHT_ID, WATERSHED, SOURCE_NAME)%>%
  slice(1)%>%
  ungroup()%>%
  arrange(WR_WATER_RIGHT_ID, WATERSHED, -dups3, -dups2, -dups1, POD_ID)%>%
  group_by(WR_WATER_RIGHT_ID, WATERSHED)%>%
  slice(1)%>%
  ungroup()%>%
  arrange(WR_WATER_RIGHT_ID, -dups4, -dups3, -dups2, -dups1, POD_ID)%>%
  group_by(WR_WATER_RIGHT_ID)%>%
  slice(1)%>%
  select(!starts_with("dups"))%>%
  ungroup()

##Construct the year when right began
  
ewrims_data_raw <-ewrims_data_raw%>%
  mutate(
    YEARSTART=FIRSTYEAR,
    YEARSTART=ifelse(YEARSTART %in% NA, year(PERMIT_ORIGINAL_ISSUE_DATE), YEARSTART),
    YEARSTART=ifelse(YEARSTART %in% NA, year(LICENSE_ORIGINAL_ISSUE_DATE), YEARSTART),
    YEARSTART=ifelse(YEARSTART %in% NA, year(STATUS_DATE), YEARSTART)
  )

##Construct the year when right ended

ewrims_data_raw <-ewrims_data_raw%>%
  mutate(Inactive=as.integer(str_detect(STATUS, "Cancelled|Closed|Inactive|Rejected|Revoked")),
         YEAREND=ifelse(Inactive==1, year(STATUS_DATE), NA)
         )

##Rename diversion & use variables

mm<-1:12

ewrims_data_raw <-ewrims_data_raw%>%
  rename_at(vars(ends_with("_diversion")), funs(paste0("div_2010_m", mm)))%>%
  rename_at(vars(ends_with("_diversion_1")), funs(paste0("div_2011_m", mm)))%>%
  rename_at(vars(ends_with("_diversion_2")), funs(paste0("div_2012_m", mm)))%>%
  rename_at(vars(ends_with("_diversion_3")), funs(paste0("div_2013_m", mm)))%>%
  rename_at(vars(ends_with("_use")), funs(paste0("use_2010_m", mm)))%>%
  rename_at(vars(ends_with("_use_1")), funs(paste0("use_2011_m", mm)))%>%
  rename_at(vars(ends_with("_use_2")), funs(paste0("use_2012_m", mm)))%>%
  rename_at(vars(ends_with("_use_3")), funs(paste0("use_2013_m", mm)))

##Round variables (eliminating likely-false levels of precision)
  
ewrims_data_raw <-ewrims_data_raw%>%
  mutate_at(vars(starts_with("div_20"), starts_with("use_20")), funs(round(.,2)))

##renaming use variables 

for (s in 0:19){
  ewrims_data_raw <-ewrims_data_raw%>%
    rename_at(vars(!!paste0("use", s)), funs(paste0("benuse", s)))
}

#Keeping required variables

ewrims_data_raw <-ewrims_data_raw%>%
  select(APPNO, LATITUDE, LONGITUDE, anystorage, SOURCE_NAME, NETACRES,
         USER, WRTYPE, RIPARIAN, PRE1914, FACEVALUE, YEARSTART, YEAREND,
         Inactive, starts_with("benuse"), starts_with("div_"), starts_with("use_")) 

ewrims_data_raw <-ewrims_data_raw%>%
  select(APPNO, everything())%>%
  arrange(APPNO)

save(ewrims_data_raw, file = paste0(DATA_TEMP, "erwims_data.RData"))  


  
  
  

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
   





    




         


  









  












