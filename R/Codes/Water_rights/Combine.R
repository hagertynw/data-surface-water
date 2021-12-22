library(tidyverse)
library(readr)
library(stringr)
library(dplyr)
library(lubridate)
library(readxl)
library(labelled)
library(grid)
library(matrixStats)

rm(list=ls())

##Setting_directories (Change root directory while running codes)

Root<- "/Users/shubhalakshminag/Box/CA_Surface_water/"

#TEMP_FILE#

DATA_TEMP<-	paste0( Root, "R/Temp/")

#FINAL_OUTPUT#

OUTPUT<-paste0( Root, "R/Output/")

#Load data

load(paste0(DATA_TEMP, "wruds_data.RData"))
load(paste0(DATA_TEMP, "erwims_data.RData"))

colnames(wruds_data_raw) <- paste('w', colnames(wruds_data_raw), sep='_')
wruds_data_raw<-rename(wruds_data_raw, "APPNO"="w_APPNO")

#Start with full set of water rights and 2010-13 reported diversions 
#(from eWRIMS/Exhibit WR-70)
#Merge with WRUDS data

Combine<-ewrims_data_raw%>%
  inner_join(wruds_data_raw, by="APPNO")

ewrims_unmatched<-ewrims_data_raw%>%
  anti_join(wruds_data_raw, by="APPNO")


Combine<-Combine%>%
  select(APPNO, USER, FACEVALUE, NETACRES, SOURCE_NAME,
         LATITUDE, LONGITUDE, Inactive, YEARSTART, YEAREND, everything())


#Use diversion numbers from WRUDS dataset where available & different (it's been corrected by SWRCB)

WR_1 <- function(df , n, m){
  varname <- paste0("div_", n, "_m", m)
  df %>%
    mutate(!!varname := ifelse(!is.na(get(!!paste0("w_div_", n, "_m", m))), 
                               get(!!paste0("w_div_", n, "_m", m)) , 
                               get(!!paste0("div_", n, "_m", m)) )
    )
}

WR_2 <- function(df , n, m){
  varname <- paste0("use_", n, "_m", m)
  df %>%
    mutate(!!varname := ifelse(!is.na(get(!!paste0("w_use_", n, "_m", m))), 
                               get(!!paste0("w_use_", n, "_m", m)) , 
                               get(!!paste0("use_", n, "_m", m)) )
    )
}

for (l in 2010:2013){
  for(j in 1:12){
    Combine<-WR_1(df=Combine, n=l, m=j)
    Combine<-WR_2(df=Combine, n=l, m=j)
  }
}

Combine<-Combine%>%
  bind_rows(ewrims_unmatched)%>%
  mutate(mergeW=case_when(
    row_number() %in% c(1:15320) ~ 3,
    row_number() %in% c(15321:41867) ~ 1
  ))

#Keep only non-minor surface water rights (except for groundwater recordations, no others have reported diversions)

Combine<-Combine%>%
  rename_at(vars(starts_with("w_div_2014_m")), funs(str_remove(.,"w_")))%>%
  filter(WRTYPE=="Appropriative"| WRTYPE=="Statement of Div and Use")%>%
  select(!WRTYPE)

#1. CORRECT OUTLIERS (likely errors in unit selection) (SWRCB did not separately do this)
#i.e., high outliers. There are also likely low outliers, but I don't have a good way to detect them.)

#Initialize outlier factors
Combine<-Combine%>%
  mutate(factorA_div_2010 = 1,
         factorA_div_2011 = 1,
         factorA_div_2012 = 1,
         factorA_div_2013 = 1,
         factorA_div_2014 = 1,
         factorA_use_2010 = 1,
         factorA_use_2011 = 1,
         factorA_use_2012 = 1,
         factorA_use_2013 = 1,
         factorA_use_2014 = 1)

#Calculating annual totals

Combine<-Combine%>%
  mutate(use_2010_tot=rowSums(select(.,starts_with("use_2010_m")), na.rm = TRUE),
         use_2011_tot=rowSums(select(.,starts_with("use_2011_m")), na.rm = TRUE),
         use_2012_tot=rowSums(select(.,starts_with("use_2012_m")), na.rm = TRUE),
         use_2013_tot=rowSums(select(.,starts_with("use_2013_m")), na.rm = TRUE),
         div_2010_tot=rowSums(select(.,starts_with("div_2010_m")), na.rm = TRUE),
         div_2011_tot=rowSums(select(.,starts_with("div_2011_m")), na.rm = TRUE),
         div_2012_tot=rowSums(select(.,starts_with("div_2012_m")), na.rm = TRUE),
         div_2013_tot=rowSums(select(.,starts_with("div_2013_m")), na.rm = TRUE),
         div_2014_tot=rowSums(select(.,starts_with("div_2014_m")), na.rm = TRUE)
         )

Combine<-Combine%>%
  mutate(use_2010_tot=ifelse(use_2010_tot==0, NA, use_2010_tot),
         use_2011_tot=ifelse(use_2011_tot==0, NA, use_2011_tot),
         use_2012_tot=ifelse(use_2012_tot==0, NA, use_2012_tot),
         use_2013_tot=ifelse(use_2013_tot==0, NA, use_2013_tot),
         div_2010_tot=ifelse(div_2010_tot==0, NA, div_2010_tot),
         div_2011_tot=ifelse(div_2011_tot==0, NA, div_2011_tot),
         div_2012_tot=ifelse(div_2012_tot==0, NA, div_2012_tot),
         div_2013_tot=ifelse(div_2013_tot==0, NA, div_2013_tot),
         div_2014_tot=ifelse(div_2014_tot==0, NA, div_2014_tot)
  )

Combine<-Combine%>%
  rowwise()%>%
  mutate(
    div_avg_tot=mean(c_across(div_2010_tot:div_2014_tot), na.rm = T),
    use_avg_tot=mean(c_across(use_2010_tot:use_2013_tot), na.rm = T)
  )%>%
  ungroup()

Combine<-Combine%>%
  mutate(div_avg_tot=na_if(div_avg_tot, "NaN"),
         use_avg_tot=na_if(use_avg_tot, "NaN"))

#Flag outliers

for (l in 2010:2014){
  for(i in 1:12){
    Combine<-Combine%>%
      mutate(!!paste0("ms","div_", l, "_m", i) := 
               ifelse(get(!!paste0("div_", l, "_m", i))>0,
                      round(get(!!paste0("div_", l, "_m", i)),0),
                      NA),
             !!paste0("ln","div_", l, "_m", i) := 
               ifelse(get(!!paste0("ms", "div_", l, "_m", i))>0,
                      log(get(!!paste0("ms", "div_", l, "_m", i))),
                      NA
               )
             )
  }
}

for (l in 2010:2013){
  for(i in 1:12){
    Combine<-Combine%>%
      mutate(!!paste0("ms","use_", l, "_m", i) := 
               ifelse(get(!!paste0("use_", l, "_m", i))>0,
                      round(get(!!paste0("use_", l, "_m", i)),0),
                      NA),
             !!paste0("ln","use_", l, "_m", i) := 
               ifelse(get(!!paste0("ms", "use_", l, "_m", i))>0,
                      log(get(!!paste0("ms", "use_", l, "_m", i))),
                      NA
               )
      )
  }
}

for (l in 2010:2014){
    Combine<-Combine%>%
      mutate(!!paste0("ms","div_", l, "_tot") := 
               ifelse(get(!!paste0("div_", l, "_tot"))>0,
                      round(get(!!paste0("div_", l, "_tot")),0 ),
                      NA),
             !!paste0("ln","div_", l, "_tot") :=
               ifelse(get(!!paste0("ms", "div_", l, "_tot"))>0,
               log(get(!!paste0("ms", "div_", l, "_tot"))),
               NA
               )
      )
}

for (l in 2010:2013){
  Combine<-Combine%>%
    mutate(!!paste0("ms","use_", l, "_tot") := 
             ifelse(get(!!paste0("use_", l, "_tot"))>0,
                    round(get(!!paste0("use_", l, "_tot")),0 ),
                    NA),
           !!paste0("ln","use_", l, "_tot") :=
             ifelse(get(!!paste0("ms", "use_", l, "_tot"))>0,
                    log(get(!!paste0("ms", "use_", l, "_tot"))),
                    NA
             )
    )
}

Combine<-Combine%>%
  rowwise()%>%
  mutate(
    sd_div=sd(c_across(starts_with("msdiv_20")), na.rm=T),
    sd_use=sd(c_across(starts_with("msuse_20")), na.rm=T),
    sd_lndiv=sd(c_across(starts_with("lndiv_20")), na.rm=T),
    sd_lnuse=sd(c_across(starts_with("lnuse_20")), na.rm=T),
  )%>%
  ungroup()

Combine<-Combine%>%
  mutate(
    flag_div=0,
    flag_use=0
  )

Combine<-Combine%>%
  mutate(flag_use=ifelse(sd_lnuse>2 & !is.na(sd_lnuse) & 
                           !is.na(FACEVALUE) &
                           (use_avg_tot-FACEVALUE>100), 1, flag_use),
         flag_use=ifelse(sd_lnuse>4 & !is.na(sd_lnuse) & 
                           !is.na(FACEVALUE) &
                           (use_avg_tot-FACEVALUE>100), 2, flag_use),
         flag_div=ifelse(sd_lndiv>2 & !is.na(sd_lndiv) & 
                           !is.na(FACEVALUE) &
                           (div_avg_tot-FACEVALUE>100), 1, flag_div),
         flag_div=ifelse(sd_lndiv>4 & !is.na(sd_lndiv) & 
                           !is.na(FACEVALUE) &
                           (div_avg_tot-FACEVALUE>100), 2, flag_div)
         )

Combine<-Combine%>%
  rowwise()%>%
  mutate(
    min_div_ann=ifelse(flag_div>0, min(div_2010_tot,
                                       div_2011_tot, div_2012_tot, 
                                       div_2013_tot, div_2014_tot, 
                                       na.rm = TRUE), NA)
  )%>%
  ungroup()

Combine<-Combine%>%
  rowwise()%>%
  mutate(
    min_use_ann=ifelse(flag_use>0, min(use_2010_tot, use_2011_tot, 
                                       use_2012_tot, use_2013_tot, 
                                       na.rm = TRUE), NA)
  )%>%
  ungroup()


#Generate new diversion/use data, with outliers corrected (scaled down to smallest reported annual diversion)

for(l in 2010:2014){
    Combine<-Combine%>%
      mutate(
        !!paste0("Ex", l):= ifelse(min_div_ann>0, 
                                   get(!!paste0("div_", l, "_tot"))/min_div_ann, NA)
      )
}

for(l in 2010:2014){
    Combine<-Combine%>%
      rowwise()%>%
      mutate(
        !!paste0("factorA_div_", l):=ifelse((flag_div>0 & min_div_ann>0
                                            & get(!!paste0("Ex", l))>100),
                                           max(1, get(!!paste0("Ex", l)), na.rm = TRUE),
                                           get(!!paste0("factorA_div_", l)))
      )%>%
      ungroup()
}

for(l in 2010:2014){
    Combine<-Combine%>%
    mutate(
      !!paste0("factorA_div_", l):=ifelse((!is.na(div_avg_tot) & div_avg_tot>1000^3), 0, 
                                          get(!!paste0("factorA_div_", l)))
    )
}

for(l in 2010:2014){
  for(i in 1:12){
    Combine<-Combine%>%
    mutate(
      !!paste0("div2_", l, "_m", i ):=ifelse(get(!!paste0("factorA_div_", l))>0,
        get(!!paste0("div_", l, "_m", i ))/get(!!paste0("factorA_div_", l)),
    NA
    )
    )
  }
}

Combine<-Combine%>%
  ungroup()%>%
    mutate(
      div2_2010_tot=rowSums(select(., starts_with("div2_2010_m")),na.rm = TRUE),
      div2_2011_tot=rowSums(select(., starts_with("div2_2011_m")),na.rm = TRUE),
      div2_2012_tot=rowSums(select(., starts_with("div2_2012_m")),na.rm = TRUE),
      div2_2013_tot=rowSums(select(., starts_with("div2_2013_m")),na.rm = TRUE),
      div2_2014_tot=rowSums(select(., starts_with("div2_2014_m")),na.rm = TRUE),
    )


for(l in 2010:2014){
    Combine<-Combine%>%
    mutate(
      !!paste0("div2_", l, "_tot"):=ifelse(get(!!paste0("div2_", l, "_tot"))==0,
                                            NA, get(!!paste0("div2_", l, "_tot")))
    )
}

for(l in 2010:2013){
  Combine<-Combine%>%
    mutate(
      !!paste0("Exu", l):= ifelse(min_use_ann>0, 
                                  get(!!paste0("use_", l, "_tot"))/min_use_ann, NA)
    )
}

for(l in 2010:2013){
  Combine<-Combine%>%
    rowwise()%>%
    mutate(
      !!paste0("factorA_use_", l):=ifelse((flag_use>0 & min_use_ann>0
                                           & get(!!paste0("Exu", l))>100),
                                          max(1, get(!!paste0("Exu", l))),
                                          get(!!paste0("factorA_use_", l)))
    )%>%
    ungroup()
}


for(l in 2010:2013){
  Combine<-Combine%>%
    mutate(
      !!paste0("factorA_use_", l):=ifelse((!is.na(use_avg_tot) & use_avg_tot>1000^3), 0, 
                                          get(!!paste0("factorA_use_", l)))
    )
}

for(l in 2010:2013){
  for(i in 1:12){
    Combine<-Combine%>%
      mutate(
        !!paste0("use2_", l, "_m", i ):=ifelse(get(!!paste0("factorA_use_", l))>0,
          get(!!paste0("use_", l, "_m", i ))/get(!!paste0("factorA_use_", l)),
          NA
      )
    )
  }
}

Combine<-Combine%>%
  ungroup()%>%
  mutate(
    use2_2010_tot=rowSums(select(., starts_with("use2_2010_m")),na.rm = TRUE),
    use2_2011_tot=rowSums(select(., starts_with("use2_2011_m")),na.rm = TRUE),
    use2_2012_tot=rowSums(select(., starts_with("use2_2012_m")),na.rm = TRUE),
    use2_2013_tot=rowSums(select(., starts_with("use2_2013_m")),na.rm = TRUE)
  )


for(l in 2010:2013){
  Combine<-Combine%>%
    mutate(
      !!paste0("use2_", l, "_tot"):=ifelse(get(!!paste0("use2_", l, "_tot"))==0,
                                           NA,
                                           get(!!paste0("use2_", l, "_tot")))
    )
}

Combine<-Combine%>%
  select(!starts_with("Ex"))

Combine<-Combine%>%
  mutate(
    div2_avg_tot=rowMeans(select(., (starts_with("div2_20") & ends_with("_tot"))),
                          na.rm = TRUE),
    use2_avg_tot=rowMeans(select(., (starts_with("use2_20") & ends_with("_tot"))),
                          na.rm = TRUE)
  )

Combine<-Combine%>%
  mutate(div2_avg_tot=na_if(div2_avg_tot, "NaN"),
         use2_avg_tot=na_if(use2_avg_tot, "NaN"))

#2. CORRECT POWER- & AQUACULTURE-ONLY DIVERSIONS (as per SWRCB)

#Identify power-only diversions

Combine<-Combine%>%
  rowwise()%>%
  mutate(
    defnotpower=sum(benuse1,benuse2,benuse3, benuse4, benuse5, benuse7,
                    benuse8,benuse9,benuse10, benuse11, benuse12, benuse13,
                    benuse14,benuse15,benuse18, benuse19)
  )%>%
  rename(power=w_POWER,
         div_factor=w_DIV_FACTOR)%>%
  ungroup()

Combine<-Combine%>%
  mutate(
    power=ifelse(benuse16==1 & defnotpower==0 & mergeW==1,1, 0),
    div_factor=ifelse(power==1 & anystorage==0 & mergeW==1, "NONE", div_factor),
    div_factor=ifelse(power==1 & anystorage==1 & mergeW==1, "NET", div_factor)
  )

# Identify aquaculture-only diversions

Combine<-Combine%>%
  rowwise()%>%
  mutate(
    notaquaculture=sum(benuse1,benuse3, benuse4, benuse5, benuse6, benuse7,
                      benuse8,benuse9,benuse10, benuse11, benuse12, benuse13,
                      benuse14,benuse15, benuse16, benuse17, benuse18, benuse19)
  )%>%
  ungroup()

Combine<-Combine%>%
  mutate(aquaculture=ifelse(benuse2==1 & notaquaculture==0 & mergeW==1, 1, 0))%>%
  mutate(div_factor=ifelse(aquaculture==1 & mergeW==1, "NONE", div_factor))

#Calculate net use (diversion minus use)

for(l in 2010:2013){
  for(j in 1:12){
    Combine<-Combine%>%
    rowwise()%>%
    mutate(!!paste0("net2_", l, "_m", j):=ifelse(div_factor=="NET", 
                                        max(0, get(!!paste0("div2_", l, "_m", j))
                                              -get(!!paste0("use2_", l, "_m", j)),
                                            na.rm = TRUE),
                                        NA)
    )%>%
    ungroup()
  }
}

Combine<-Combine%>%
    mutate(
      net2_2010_tot=rowSums(select(., starts_with("net2_2010_m")), na.rm = TRUE),
      net2_2011_tot=rowSums(select(., starts_with("net2_2011_m")), na.rm = TRUE),
      net2_2012_tot=rowSums(select(., starts_with("net2_2012_m")), na.rm = TRUE),
      net2_2013_tot=rowSums(select(., starts_with("net2_2013_m")), na.rm = TRUE),
    )

for(l in 2010:2013){
  Combine<-Combine%>%
  rowwise()%>%
  mutate(
    !!paste0("net2_", l, "_tot"):=ifelse((is.na(get(!!paste0("div2_", l, "_tot"))) |
                                           is.na(get(!!paste0("use2_", l, "_tot")))),
                                           NA,
                                           get(!!paste0("net2_", l, "_tot"))
                                          )
  )
}

Combine<-Combine%>%
  rowwise()%>%
  mutate(
    net2_avg_tot=ifelse(!is.na(sum(c_across(net2_2010_tot:net2_2013_tot), na.rm = TRUE)),
                        mean(c_across(net2_2010_tot:net2_2013_tot), na.rm = TRUE), NA)
  )%>%
  ungroup()%>%
  mutate(net2_avg_tot=na_if(net2_avg_tot, "NaN"))%>%
  arrange(-net2_avg_tot)

#Generate new diversion data, corrected for power/aquaculture, 
#as well as SWRCB-determined duplicates

for(l in 2010:2013){
  for(j in 1:12){
    Combine<-Combine%>%
      mutate(!!paste0("div3_", l, "_m", j):= get(!!paste0("div2_", l, "_m", j))
      )
  }
}

for(l in 2014){
  for(j in 1:12){
    Combine<-Combine%>%
      mutate(!!paste0("div3_", l, "_m", j):= get(!!paste0("div2_", l, "_m", j))
      )
  }
}

for(l in 2010:2013){
  for(j in 1:12){
    Combine<-Combine%>%
      mutate(!!paste0("div3_", l, "_m", j):= case_when(
        div_factor=="NET" ~ get(!!paste0("net2_", l, "_m", j)),
        TRUE~ get(!!paste0("div3_", l, "_m", j))),
      !!paste0("div3_", l, "_m", j):= case_when(
       div_factor=="NONE" ~0,
       TRUE ~ get(!!paste0("div3_", l, "_m", j)))
             )
  }
}


Combine<-Combine%>%
  mutate(
    div3_2010_tot=rowSums(select(., starts_with("div3_2010_m")), na.rm = TRUE),
    div3_2011_tot=rowSums(select(., starts_with("div3_2011_m")), na.rm = TRUE),
    div3_2012_tot=rowSums(select(., starts_with("div3_2012_m")), na.rm = TRUE),
    div3_2013_tot=rowSums(select(., starts_with("div3_2013_m")), na.rm = TRUE)
  )

Combine<-Combine%>%
  mutate(
    div3_2010_tot=ifelse(div3_2010_tot==0 & is.na(net2_2010_tot), NA, div3_2010_tot),
    div3_2011_tot=ifelse(div3_2011_tot==0 & is.na(net2_2011_tot), NA, div3_2011_tot),
    div3_2012_tot=ifelse(div3_2012_tot==0 & is.na(net2_2012_tot), NA, div3_2012_tot),
    div3_2013_tot=ifelse(div3_2013_tot==0 & is.na(net2_2013_tot), NA, div3_2013_tot)
  )


Combine<-Combine%>%
  mutate(
    div3_2014_tot=div2_2014_tot
  )%>%
  mutate(
    div3_avg_tot=rowMeans(select(.,(starts_with("div3_20") & ends_with("tot"))), 
                          na.rm = TRUE),
    div3_avg_tot=na_if(div3_avg_tot, "NaN")
  )

# 3. CORRECT OVER-REPORTING
# Mostly following SWRCB, but year-wise rather than averages, and with more checks

#Initialize over-reporting factors

Combine<-Combine%>%
  mutate(
    factorB_2010=1,
    factorB_2011=1,
    factorB_2012=1,
    factorB_2013=1,
    factorB_2014=1,
  )

# Post-1914, reporting facevalue: if diversion > face value, limit to face value

Combine<-Combine%>%
  rowwise()%>%
  mutate(
    factorB_2010=ifelse((PRE1914==0 & RIPARIAN==0 & FACEVALUE>0 & !is.na(FACEVALUE)),
                        max(1,div3_2010_tot/FACEVALUE, na.rm = TRUE),
                        1
                        ),
    factorB_2011=ifelse((PRE1914==0 & RIPARIAN==0 & FACEVALUE>0 & !is.na(FACEVALUE)),
                        max(1,div3_2011_tot/FACEVALUE, na.rm = TRUE),
                        1
    ),
    factorB_2012=ifelse((PRE1914==0 & RIPARIAN==0 & FACEVALUE>0 & !is.na(FACEVALUE)),
                        max(1,div3_2012_tot/FACEVALUE, na.rm = TRUE),
                        1
    ),
    factorB_2013=ifelse((PRE1914==0 & RIPARIAN==0 & FACEVALUE>0 & !is.na(FACEVALUE)),
                        max(1,div3_2013_tot/FACEVALUE, na.rm = TRUE),
                        1
    ),
    factorB_2014=ifelse((PRE1914==0 & RIPARIAN==0 & FACEVALUE>0 & !is.na(FACEVALUE)),
                        max(1,div3_2014_tot/FACEVALUE, na.rm = TRUE),
                        1
    )
  )%>%
  ungroup()

# Riparian/Pre-1914, reporting irrigated acres: if diversion > 8 af/acre, limit to this level

Combine<-Combine%>%
  mutate(
    FACEVALUE=replace(FACEVALUE, ((RIPARIAN==1|PRE1914==1) & FACEVALUE==0), NA)
  )


Combine<-Combine%>%
  rowwise()%>%
  mutate(
    factorB_2010=replace(factorB_2010, ((PRE1914==1|RIPARIAN==1) & benuse11==1 &
                                          !is.na(NETACRES) & NETACRES>0),
                        max(1,div3_2010_tot/(NETACRES*8), na.rm = TRUE)
    ),
    factorB_2011=replace(factorB_2011, ((PRE1914==1|RIPARIAN==1) & benuse11==1 &
                                          !is.na(NETACRES) & NETACRES>0),
                         max(1,div3_2011_tot/(NETACRES*8), na.rm = TRUE)
    ),
    factorB_2012=replace(factorB_2012, ((PRE1914==1|RIPARIAN==1) & benuse11==1 &
                                          !is.na(NETACRES) & NETACRES>0),
                         max(1,div3_2012_tot/(NETACRES*8), na.rm = TRUE)
    ),
    factorB_2013=replace(factorB_2013, ((PRE1914==1|RIPARIAN==1) & benuse11==1 &
                                          !is.na(NETACRES) & NETACRES>0),
                         max(1,div3_2013_tot/(NETACRES*8), na.rm = TRUE)
    ),
    factorB_2014=replace(factorB_2014, ((PRE1914==1|RIPARIAN==1) & benuse11==1 &
                                          !is.na(NETACRES) & NETACRES>0),
                         max(1,div3_2014_tot/(NETACRES*8), na.rm = TRUE)
    )
  )%>%
  ungroup()

# Post-1914, reporting acres but not facevalue: acres-based correction as above (but only egregious ones)

Combine%>%
  filter(PRE1914==0 & RIPARIAN==0 & (FACEVALUE==0|is.na(FACEVALUE)) &
           benuse11==1 & !is.na(NETACRES) & NETACRES>0)

Combine<-Combine%>%
  rowwise()%>%
  mutate(
    factorB_2010=replace(factorB_2010, 
                         (div3_2010_tot/(NETACRES*8)>10 & PRE1914==0 & RIPARIAN==0
                          & (FACEVALUE==0|is.na(FACEVALUE)) & benuse11==1 &
                            NETACRES>0 & !is.na(NETACRES) ),
                         max(1,div3_2010_tot/(NETACRES*8), na.rm = TRUE)
    ),
    factorB_2011=replace(factorB_2011, 
                         (div3_2011_tot/(NETACRES*8)>10 & PRE1914==0 & RIPARIAN==0
                          & (FACEVALUE==0|is.na(FACEVALUE)) & benuse11==1 & 
                            NETACRES>0 & !is.na(NETACRES) ),
                         max(1,div3_2011_tot/(NETACRES*8), na.rm = TRUE)
    ),
    factorB_2012=replace(factorB_2012, 
                         (div3_2012_tot/(NETACRES*8)>10 & PRE1914==0 & RIPARIAN==0
                          & (FACEVALUE==0|is.na(FACEVALUE)) & benuse11==1 &
                            NETACRES>0 & !is.na(NETACRES) ),
                         max(1,div3_2012_tot/(NETACRES*8), na.rm = TRUE)
    ),
    factorB_2013=replace(factorB_2013, 
                         (div3_2013_tot/(NETACRES*8)>10 & PRE1914==0 & RIPARIAN==0
                          & (FACEVALUE==0|is.na(FACEVALUE)) & benuse11==1 &
                            NETACRES>0 & !is.na(NETACRES) ),
                         max(1,div3_2013_tot/(NETACRES*8), na.rm = TRUE)
    ),
    factorB_2014=replace(factorB_2014, 
                         (div3_2014_tot/(NETACRES*8)>10 & PRE1914==0 & RIPARIAN==0
                          & (FACEVALUE==0|is.na(FACEVALUE)) & benuse11==1 & 
                            NETACRES>0 & !is.na(NETACRES) ),
                         max(1,div3_2014_tot/(NETACRES*8), na.rm = TRUE)
    )
  )%>%
  ungroup()

Combine<-Combine%>%
  arrange(desc(div3_avg_tot))

Combine%>%
  filter(!str_detect(USER,"DISTRICT|COMPANY|BUREAU|CITY|DITCH|COMMITTEE|WATER CO|
                    CORP|AUTHORITY|DEPARTMENT|ASSOCIATION|INDUSTRIES|AUTHORITY|NATL|
                    CO|AGENCY|CLUB|ASSOC|US ") & NETACRES==0 & (RIPARIAN==1|PRE1914==1)&
             div3_avg_tot>100000 & !is.na(div3_avg_tot) & power!=1 & aquaculture!=1)%>%
  select(APPNO) # Drop this

Combine<-Combine%>%
  filter(APPNO!="S018523")

# Generate new diversion data, corrected for over-reporting

for(l in 2010: 2014){
  for( i in 1:12){
    Combine<-Combine%>%
      mutate(
        !!paste0("div4_", l, "_m", i):=
          get(!!paste0("div3_", l, "_m", i))/get(!!paste0("factorB_", l))
      )
   }
}

## 4. FINISH UP

# Calculate yearly totals

Combine<-Combine%>%
  mutate(
    div4_2010_tot=rowSums(select(., starts_with("div4_2010_m")), na.rm=T),
    div4_2011_tot=rowSums(select(., starts_with("div4_2011_m")), na.rm=T),
    div4_2012_tot=rowSums(select(., starts_with("div4_2012_m")), na.rm=T),
    div4_2013_tot=rowSums(select(., starts_with("div4_2013_m")), na.rm=T),
    div4_2014_tot=rowSums(select(., starts_with("div4_2014_m")), na.rm=T)
  )

Combine<-Combine%>%
  mutate(
    div4_2010_data=rowSums(!is.na(select(., starts_with("div4_2010_m"))), na.rm=T),
    div4_2011_data=rowSums(!is.na(select(., starts_with("div4_2011_m"))), na.rm=T),
    div4_2012_data=rowSums(!is.na(select(., starts_with("div4_2012_m"))), na.rm=T),
    div4_2013_data=rowSums(!is.na(select(., starts_with("div4_2013_m"))), na.rm=T),
    div4_2014_data=rowSums(!is.na(select(., starts_with("div4_2014_m"))), na.rm=T)
  )

Combine<-Combine%>%
  mutate(
    div4_2010_tot=ifelse(div4_2010_data==0 , NA, div4_2010_tot),
    div4_2011_tot=ifelse(div4_2011_data==0, NA, div4_2011_tot),
    div4_2012_tot=ifelse(div4_2012_data==0, NA, div4_2012_tot),
    div4_2013_tot=ifelse(div4_2013_data==0, NA, div4_2013_tot),
    div4_2014_tot=ifelse(div4_2014_data==0 , NA, div4_2014_tot)
  )

Combine<-Combine%>%
  mutate(
    div4_avg_tot=rowMeans(select(.,(starts_with("div4_20") & ends_with("tot"))), 
                          na.rm = TRUE),
    div4_avg_tot=na_if(div4_avg_tot, "NaN")
  )

# Calculating monthly averages

Combine<-Combine%>%
  mutate(
    div4_avg_m1=rowMeans(select(., starts_with("div4_") & ends_with("m1")), na.rm=TRUE),
    div4_avg_m2=rowMeans(select(., starts_with("div4_") & ends_with("m2")), na.rm=TRUE),
    div4_avg_m3=rowMeans(select(., starts_with("div4_") & ends_with("m3")), na.rm=TRUE),
    div4_avg_m4=rowMeans(select(., starts_with("div4_") & ends_with("m4")), na.rm=TRUE),
    div4_avg_m5=rowMeans(select(., starts_with("div4_") & ends_with("m5")), na.rm=TRUE),
    div4_avg_m6=rowMeans(select(., starts_with("div4_") & ends_with("m6")), na.rm=TRUE),
    div4_avg_m7=rowMeans(select(., starts_with("div4_") & ends_with("m7")), na.rm=TRUE),
    div4_avg_m8=rowMeans(select(., starts_with("div4_") & ends_with("m8")), na.rm=TRUE),
    div4_avg_m9=rowMeans(select(., starts_with("div4_") & ends_with("m9")), na.rm=TRUE),
    div4_avg_m10=rowMeans(select(., starts_with("div4_") & ends_with("m10")), na.rm=TRUE),
    div4_avg_m11=rowMeans(select(., starts_with("div4_") & ends_with("m11")), na.rm=TRUE),
    div4_avg_m12=rowMeans(select(., starts_with("div4_") & ends_with("m12")), na.rm=TRUE)
  )

for(i in 1:12){
  Combine<-Combine%>%
  mutate(
    !!paste0("div4_avg_m", i):=na_if(get(!!paste0("div4_avg_m", i)), "NaN")
  )
}

Combine<-Combine%>%
  mutate(
    div4_avg_tot2=rowSums(select(., starts_with("div4_avg_m")), na.rm=T),
    div4_avg_tot2=na_if(div4_avg_tot2, "NaN"),
    div4_avg_data=rowSums(!is.na(select(., starts_with("div4_avg_m"))), na.rm=T),
    div4_avg_tot2=ifelse(div4_avg_data==0, NA, div4_avg_tot2)
  )

# Investigate differences between my processing and SWRCB's

Combine<-Combine%>%
  mutate(
    demand_tot=rowSums(select(., starts_with("w_demand_m")), na.rm=T),
    diff=abs(div4_avg_tot2-demand_tot),
    pctdiff=abs((div4_avg_tot2-demand_tot)/div4_avg_tot2)
  )

# Clean up 

Combine<-Combine%>%
  select( APPNO, USER, FACEVALUE, SOURCE_NAME, LATITUDE, LONGITUDE, Inactive, YEARSTART,
          YEAREND, RIPARIAN, PRE1914, starts_with("benuse"), (starts_with("div4_") & 
                                                                ends_with("tot")),
          starts_with("div4_avg_m")
  )%>%
  rename(avgdiversion=div4_avg_tot)

m<-2010:2014
mm<-1:12
Combine<-Combine%>%
  rename_at(vars(starts_with("div4_20")), funs(paste0("diversion", m)))%>%
  rename_at(vars(starts_with("div4_avg_m")), funs(paste0("anydiversion_m", mm)))

Combine<-Combine%>%
  mutate_at(vars(starts_with("anydiversion_m"), avgdiversion), funs(round(.,2)))

save(Combine, file = paste0(DATA_TEMP, "waterrights_diversions.RData"))  


