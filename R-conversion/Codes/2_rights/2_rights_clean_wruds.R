library(tidyverse)
library(readr)
library(stringr)
library(dplyr)
library(lubridate)
library(readxl)
library(labelled)

rm(list=ls())

##Setting_directories (Change root directory while running codes)

Root<- "/Users/shubhalakshminag/Box/CA_Surface_water/"

# RAW_DATA

DATA_RIGHTS<- paste0( Root, "data/rights/")

# TEMP_FILE

DATA_TEMP<-	paste0( Root, "R/Temp/")

# FINAL_OUTPUT

OUTPUT<-paste0( Root, "R/Output/")

##Loading_the_data

wruds_data_raw<-read_xlsx(paste0(DATA_RIGHTS, 
                                 "drought_analysis/info_order_demand/WRUDS_2015_06_15.xlsx"), guess_max = 41867)

##Renaming variables

wruds_data_raw<-wruds_data_raw%>%
  rename(
    APPNO=APP_ID,
    USER=PRIMARY_OWNER,
    ACRES=NET_ACRES,
    QUANTITY=FACE_VALUE,
    EVALAREA=AREA,
    HU_NAME=HYDROLOGIC_UNIT,
    HU_NAME_OTHERS=ADD_HU,
    HUC12=HUC_12,
    WRTYPE=WR_TYPE,
    STATUS=STATUS_TYPE,
    PRE1914=PRE_1914,
    FIRSTYEAR=YEAR_FIRST_USE,
    PRIORITY_POST1914=PRIORITY_DATE,
    PRIORITY_PRE1914=PRE_14_PRIORITY,
    POWER=POWER_ONLY,
    DEMAND_m1=DEMAND_JAN,
    DEMAND_m2=DEMAND_FEB,
    DEMAND_m3=DEMAND_MAR,
    DEMAND_m4=DEMAND_APR,
    DEMAND_m5=DEMAND_MAY,
    DEMAND_m6=DEMAND_JUN,
    DEMAND_m7=DEMAND_JUL,
    DEMAND_m8=DEMAND_AUG,
    DEMAND_m9=DEMAND_SEP,
    DEMAND_m10=DEMAND_OCT,
    DEMAND_m11=DEMAND_NOV,
    DEMAND_m12=DEMAND_DEC,
    DEMAND=DEMAND_TOTAL
  )

mm<-1:12

wruds_data_raw<-wruds_data_raw%>%
  rename_at(vars(ends_with("_DIV_2010")), funs(paste0("div_2010_m", mm)))%>%
  rename_at(vars(ends_with("_DIV_2011")), funs(paste0("div_2011_m", mm)))%>%
  rename_at(vars(ends_with("_DIV_2012")), funs(paste0("div_2012_m", mm)))%>%
  rename_at(vars(ends_with("_DIV_2013")), funs(paste0("div_2013_m", mm)))%>%
  rename_at(vars(ends_with("_USE_2010")), funs(paste0("use_2010_m", mm)))%>%
  rename_at(vars(ends_with("_USE_2011")), funs(paste0("use_2011_m", mm)))%>%
  rename_at(vars(ends_with("_USE_2012")), funs(paste0("use_2012_m", mm)))%>%
  rename_at(vars(ends_with("_USE_2013")), funs(paste0("use_2013_m", mm)))

# Trimming blank spaces from strings 

wruds_data_raw<-wruds_data_raw%>%
     mutate(
       HU_NAME=str_squish(HU_NAME),
       USER=str_squish(USER)
     )

# Recoding Binary variables

wruds_data_raw<-wruds_data_raw%>%
  mutate(
    RIPARIAN=ifelse(RIPARIAN %in% NA, 0, 1),
    PRE1914=ifelse(PRE1914 %in% NA, 0, 1),
    POWER=ifelse(POWER %in% c(NA, "N"), 0, 1),
    INFO_ORDER=ifelse(INFO_ORDER %in% NA, 0, 1),
    RESPONDED=ifelse(RESPONDED %in% NA, 0, 1),
  )

# Constructing variables corresponding to beneficial use

wruds_data_raw<-wruds_data_raw%>%
  mutate(USE_AESTHETIC=as.integer(str_detect(BENEFICIAL_USE, "Aesthetic")),
         USE_AQUACULTURE=as.integer(str_detect(BENEFICIAL_USE, "Aquaculture")),
         USE_DOMESTIC=as.integer(str_detect(BENEFICIAL_USE, "Domestic")),
         USE_DUSTCONTROL=as.integer(str_detect(BENEFICIAL_USE, "Dust Control")),
         USE_FIREPREV=as.integer(str_detect(BENEFICIAL_USE, "Fire Protection")),
         USE_FISH=as.integer(str_detect(BENEFICIAL_USE, "Fish and Wildlife Preservation and Enhancement")),
         USE_FROSTPREV=as.integer(str_detect(BENEFICIAL_USE, "Frost Protection")),
         USE_HEALTHCONTROL=as.integer(str_detect(BENEFICIAL_USE, "Heat Control")),
         USE_INCIDENTAL=as.integer(str_detect(BENEFICIAL_USE, "Incidental Power")),
         USE_INDUSTRIAL=as.integer(str_detect(BENEFICIAL_USE, "Industrial")),
         USE_IRRIGATION=as.integer(str_detect(BENEFICIAL_USE, "Irrigation")),
         USE_MILLING=as.integer(str_detect(BENEFICIAL_USE, "Milling")),
         USE_MINING=as.integer(str_detect(BENEFICIAL_USE, "Mining")),
         USE_MUNICIPAL=as.integer(str_detect(BENEFICIAL_USE, "Municipal")),
         USE_OTHER=as.integer(str_detect(BENEFICIAL_USE, "Other")),
         USE_POWER=as.integer(str_detect(BENEFICIAL_USE, "Power")),
         USE_RECREATION=as.integer(str_detect(BENEFICIAL_USE, "Recreational")),
         USE_SNOWMAKING=as.integer(str_detect(BENEFICIAL_USE, "Snow Making")),
         USE_STOCK=as.integer(str_detect(BENEFICIAL_USE, "Stockwatering"))
         )

# Tidying up/ dropping variables 

wruds_data_raw<-wruds_data_raw%>%
  dplyr::select(!c("INCLUDE", "DEMAND", "DEMAND_APR-SEP", starts_with("AVG_DIV_"),
            "AVG_DIV_TOTAL", starts_with("AVE_USE_")))%>%
  mutate_at(vars(starts_with("div_20"), starts_with("DEMAND_m"), starts_with("use_20")),
            funs(round(.,3))
            )

# Reconstruct reported diversions for 2014 
# (responses to Informational Order 2015-0002-DWR)

DEMAND_1 <- function(df , n){
  varname <- paste0("div_rip_2014_m", n)
  df %>%
    mutate(!!varname := ifelse(INFO_ORDER==1 & RESPONDED==1 & PRE1914==0
                                & RIPARIAN==1, get(!!paste0("DEMAND_m", n)), NA))
}

DEMAND_2 <- function(df , n){
  varname <- paste0("DEMAND_m", n)
  df %>%
    mutate(!!varname := ifelse((INFO_ORDER==1 & RESPONDED==1 & PRE1914==0
                                & RIPARIAN==1), NA, get(!!paste0("DEMAND_m", n)))
    )
}

DEMAND_3 <- function(df , n){
  varname <- paste0("div_pre_2014_m", n)
  df %>%
    mutate(!!varname := ifelse(INFO_ORDER==1 & RESPONDED==1 & PRE1914==1
                                & RIPARIAN==0,  get(!!paste0("DEMAND_m", n)), NA)
    )
}

DEMAND_4 <- function(df , n){
  varname <- paste0("DEMAND_m", n)
  df %>%
    mutate(!!varname := ifelse((INFO_ORDER==1 & RESPONDED==1 & PRE1914==1
                                & RIPARIAN==0), NA, get(!!paste0("DEMAND_m", n)))
    )
}

for (m in 1:12){
  wruds_data_raw<-DEMAND_1(wruds_data_raw, m)
  wruds_data_raw<-DEMAND_2(wruds_data_raw, m)
  wruds_data_raw<-DEMAND_3(wruds_data_raw, m)
  wruds_data_raw<-DEMAND_4(wruds_data_raw, m)
}

#Consolidate observations arising from multiple responses to the informational order

wruds_data_raw<-wruds_data_raw%>%
  arrange(INFO_ORDER, RESPONDED, APPNO, PRE1914, RIPARIAN)%>%
  group_by(INFO_ORDER, RESPONDED, APPNO)%>%
  mutate(
    PRE1914=ifelse(INFO_ORDER==1 & RESPONDED==1 & lead(PRE1914)==1 & PRE1914==0, 1,
                   PRE1914),
    RIPARIAN=ifelse(INFO_ORDER==1 & RESPONDED==1 & lag(RIPARIAN)==1 & RIPARIAN==0, 1,
                    RIPARIAN)
  )%>%
  ungroup()%>%
  mutate(
    PRE1914=ifelse(is.na(PRE1914), 0, PRE1914),
    RIPARIAN=ifelse(is.na(RIPARIAN), 0, RIPARIAN)
  )

wruds_data_raw<-wruds_data_raw%>%
  group_by(INFO_ORDER, RESPONDED, APPNO)%>%
  mutate_at(vars(starts_with("div_rip_2014_m")), funs(ifelse((INFO_ORDER==1 & 
                                                                RESPONDED==1 & 
                                                                is.na(.) &
                                                                row_number()>1 &
                                                                !is.na(lag(.))), 
                                                                lag(.),
                                                                .))
  )%>%
  ungroup()


wruds_data_raw<-wruds_data_raw%>%
  group_by(INFO_ORDER, RESPONDED, APPNO)%>%
  mutate_at(vars(starts_with("div_pre_2014_m"), "PRIORITY_PRE1914"), 
            funs(ifelse((INFO_ORDER==1 & RESPONDED==1 & is.na(.) &
                         !is.na(lead(.))), lead(.), .))
  )%>%
  ungroup()


wruds_data_raw<-wruds_data_raw%>%
  group_by(INFO_ORDER, RESPONDED, APPNO)%>%
  mutate(Notes=ifelse((INFO_ORDER==1 & RESPONDED==1 & is.na(Notes) & !is.na(lead(Notes))), 
                      lead(Notes),
                      Notes)
  )%>%
  ungroup()

wruds_data_raw<-wruds_data_raw%>%
  distinct()%>%
  filter(!(APPNO=="S018902" & FIRSTYEAR == 1800))%>%
  mutate(DIV_PRE_2014_TOT=ifelse(APPNO!="S004683", NA,
                                 rowSums(dplyr::select(.,starts_with("div_pre_2014_m"))
                                         , na.rm = T)
                                 )
         )


DIV_1 <- function(df , n){
  varname <- paste0("div_pre_2014_m", n, "_TOT")
  df %>%
    arrange(APPNO, -DIV_PRE_2014_TOT)%>%
    group_by(APPNO)%>%
    mutate(!!varname := ifelse(APPNO=="S004683",
                               sum(get(!!paste0("div_pre_2014_m", n)), na.rm = T),
                              NA)
    )
}

DIV_2 <- function(df , n){
  varname <- paste0("div_pre_2014_m", n)
  df %>%
    ungroup()%>%
    mutate(!!varname := ifelse(APPNO=="S004683", 
                               get(!!paste0("div_pre_2014_m", n, "_TOT")),
                               get(!!varname))
    )
}

for (j in 1:12){
  wruds_data_raw<-DIV_1(df=wruds_data_raw, n=j)
  wruds_data_raw<-DIV_2(df=wruds_data_raw, n=j)
}

wruds_data_raw<-wruds_data_raw%>%
  dplyr::select(!(starts_with("div_pre_2014_m") & ends_with("TOT")))%>%
  group_by(APPNO)%>%
  filter(!(row_number()>1 & APPNO == "S004683"))%>%
  dplyr::select(!"DIV_PRE_2014_TOT")%>%
  ungroup()

##Sum 2014 responses across riparian and pre-1914 water right types

DIV_F <- function(df , n){
  varname <- paste0("div_2014_m", n)
  df %>%
    rowwise()%>%
    mutate(!!varname := ifelse(is.na(get(!!paste0("div_pre_2014_m", n))) & 
                                is.na(get(!!paste0("div_rip_2014_m", n))),
                                NA,
                                sum(get(!!paste0("div_pre_2014_m", n)),
                                get(!!paste0("div_rip_2014_m", n)), na.rm=T)
    ))%>%
    ungroup()
}

for (j in 1:12){
  wruds_data_raw<-DIV_F(wruds_data_raw, j)
}

##Final 

wruds_data_raw<-wruds_data_raw%>%
  dplyr::select(c("APPNO", starts_with("DEMAND_m"), starts_with("div_2014_m"), 
         "POWER", "DIV_FACTOR", "RESPONDED",
         "ACRES", starts_with("div_"), starts_with("use_")))%>%
  dplyr::select(!c(starts_with("div_pre"), starts_with("div_rip")))%>%
  distinct()%>%
  arrange(APPNO)

wruds_data_raw<-wruds_data_raw[,1:126]
wruds_data_raw<-wruds_data_raw[,-78]

save(wruds_data_raw, file = paste0(DATA_TEMP, "wruds_data.RData"))  





