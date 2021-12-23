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

DATA_SWP<- paste0( Root, "data/swp/")
REF_KERN<-paste0(Root, "data/conglomerates/kern/")

#TEMP_FILE#

DATA_TEMP<-	paste0( Root, "R/Temp/")

#FINAL_OUTPUT#

OUTPUT<-paste0( Root, "R/Output/")

##LOAD EACH COMPONENT DATASET

#Load contractor names

swp_names<-read_excel(paste0(DATA_SWP, "bulletin_132/B132-18 Tables.xlsx"))

swp_names<-swp_names%>%
  rename(user_long=Contractor,
         user="Short name")%>%
  mutate(user_long=toupper(user_long))

#Load list of sectors

miag<-read_csv(paste0(DATA_SWP,"swp_contractors.csv"))

miag<-miag%>%
  mutate(user=toupper(contractor))%>%
  select(c(user, ag, mi))

#Load percentage allocations
pctallo<-read_excel(paste0(DATA_SWP, "pct_allocations.xlsx"))

pctallo<-pctallo%>%
  rename(pctallo_mi=mi,
         pctallo_ag=ag)%>%
  mutate(
    pctallo_mi=pctallo_mi/100,
    pctallo_ag = pctallo_ag / 100
  )

#Load maximum contract amounts (Table B-4)

contract_amounts<-read_excel(paste0(DATA_SWP, "bulletin_132/B132-18 Tables.xlsx"),
                             col_names=FALSE, sheet = 2, skip=2)

contract_amounts<-contract_amounts[-c(2,78, 79), ]
colnames(contract_amounts) <- paste('v', colnames(contract_amounts))

contract_amounts<-contract_amounts%>%
  gather(col, v, "v ...2":"v ...40" )%>%
  separate(col, c("A", "B"))%>%
  select(!A)%>%
  rename(year="v ...1")%>%
  mutate(user=ifelse(year=="Calendar Year", v, NA))%>%
  mutate(B=as.numeric(B))%>%
  arrange(B, desc(user),  year)%>%
  group_by(B)%>%
  mutate(user=replace(user, is.na(user), user[1]))%>%
  ungroup()%>%
  filter(year!="Calendar Year")%>%
  filter(year!="TOTAL")%>%
  filter(user!="Total")%>%
  mutate(year=as.numeric(year),
         v=as.numeric(v))%>%
  select(-B)%>%
  rename(maxcontract=v)%>%
  arrange(user, year)


# Load deliveries (Table B-5B)

deliveries<-read_excel(paste0(DATA_SWP, "bulletin_132/B132-18 Tables.xlsx"), 
                       col_names=FALSE, sheet = 3, skip=2)

deliveries<-deliveries[-c(2,78, 79, 80), ]
colnames(deliveries) <- paste('v', colnames(deliveries))

deliveries<-deliveries%>%
  gather(col, v, "v ...2":"v ...40" )%>%
  separate(col, c("A", "B"))%>%
  select(!A)%>%
  rename(year="v ...1")%>%
  mutate(user=ifelse(year=="Calendar Year", v, NA))%>%
  mutate(B=as.numeric(B))%>%
  arrange(B, desc(user),  year)%>%
  group_by(B)%>%
  mutate(user=replace(user, is.na(user), user[1]))%>%
  ungroup()%>%
  filter(year!="Calendar Year")%>%
  filter(year!="TOTAL")%>%
  filter(user!="Total")%>%
  mutate(year=as.numeric(year),
         v=as.numeric(v))%>%
  select(-B)%>%
  rename(deliveries=v)%>%
  arrange(user, year)

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

#Load subcontracts data

subcontracts_kern<-read_excel(paste0(REF_KERN, "swp-contracts-in-kern-county.xlsx"), skip=3)

subcontracts_kern<-subcontracts_kern%>%
  select(std_name:mi)%>%
  filter(!is.na(std_name))%>%
  mutate(
    tot_ag=sum(ag, na.rm=TRUE),
    tot_mi=sum(mi, na.rm=TRUE),
    pct_ag_sub = (ag/tot_ag),
    pct_mi_sub = mi/tot_mi
  )%>%
  select(!starts_with("tot_"))%>%
  rename(std_name2=std_name)

#MERGE AND PROCESS

#Merge data together

#start with deliveries data

deliveries<-deliveries%>%
  inner_join(contract_amounts)%>% #merge in maximum contract amounts
  left_join(pctallo)%>% #merge in percentage allocations
  mutate(
    user=replace(user, user=="Alameda- Zone 7", "Alameda-Zone 7"),
    user1=user,
    user=replace(user, str_detect(user, "Kern: "), "Kern")
  )%>%
  filter(user!="Grand Total")%>%
  filter(user!="South Bay Area Future Contractor")%>%
  inner_join(swp_names)%>% #merge in full names
  select(-user)%>%
  rename(user=user_long)%>%
  select(year, user, everything())%>%
  inner_join(miag)%>% #merge in mi/ag status
  filter(year<=2018) #Drop future projections (not real data)

#Reshaping to sector 
  
deliveries<-deliveries%>%
  mutate(
    sector=NA,
    sector=replace(sector, mi==1 & ag==0, "mi"),
    sector=replace(sector, mi==0 & ag==1, "ag"),
    sector=replace(sector, user1=="Kern: Municipal and Industrial", "mi"),
    sector=replace(sector, user1=="Kern: Agricultural", "ag"),
    sector=replace(sector, user1=="Kern: Total", "tot"),
  )%>%
  select(-c(user1, mi, ag))

deliveries<-deliveries%>%
  gather(del_contract, amount, deliveries:maxcontract)%>%
  unite("A", c("del_contract", "sector"))%>%
  spread(A, amount)
  
deliveries<-deliveries%>%
  arrange(user, year)%>%
  select(year, user, starts_with("deliveries"), starts_with("maxcontract_"), everything())%>%
  rowwise()%>%
  mutate(
    deltot=sum(deliveries_ag, deliveries_mi, na.rm = TRUE),
    deliveries_tot=replace(deliveries_tot, is.na(deliveries_tot), deltot),
    maxcontot = sum(maxcontract_ag , maxcontract_mi, na.rm = TRUE),
    maxcontract_tot=replace(maxcontract_tot, is.na(maxcontract_tot), maxcontot),
  )%>%
  ungroup()%>%
  select(-c("maxcontot", "deltot"))%>%
  rename(
    maxcontract=maxcontract_tot,
    deliveries=deliveries_tot
  )%>%
  select(year, user, deliveries, deliveries_ag,
         deliveries_mi, maxcontract, maxcontract_ag,
         maxcontract_mi, pctallo_ag, pctallo_mi)

#Standardize names

deliveries<-deliveries%>%
  inner_join(masternames)%>%
  select(-user)%>%
  select(year, std_name, everything())%>%
  arrange(std_name, year)
  
#Reallocate subcontracts

deliveries<-deliveries%>%
  mutate(kern=ifelse(std_name=="KERN COUNTY W.A.",1, 0))

subcontracts_kern<-subcontracts_kern%>%
  mutate(std_name="KERN COUNTY W.A.")

kern_reallo<-deliveries%>%
  filter(kern==1)%>%
  mutate(parent=std_name)%>%
  full_join(subcontracts_kern)%>%
  mutate(
    new_maxcontract_ag = maxcontract_ag*pct_ag_sub,
    new_maxcontract_mi = maxcontract_mi*pct_mi_sub,
    new_deliveries_ag = deliveries_ag*pct_ag_sub,
    new_deliveries_mi = deliveries_mi*pct_mi_sub,
  )%>%
  rowwise()%>%
  mutate(
    new_maxcontract=sum(new_maxcontract_ag,  new_maxcontract_mi, na.rm = TRUE),
    new_deliveries=sum(new_deliveries_ag,  new_deliveries_mi, na.rm = TRUE),
  )%>%
  ungroup()%>%
  group_by(year)%>%
  mutate(
    grtot_deliv = sum(new_deliveries, na.rm=TRUE),
    grtot_maxcon = sum(new_maxcontract, na.rm = TRUE)
  )%>%
  ungroup()%>%
  select(-c( grtot_deliv, grtot_maxcon))

kern_reallo<-kern_reallo%>%
  select(-c(deliveries:maxcontract_mi))%>%
  rename_at(vars(starts_with("new_")), funs(str_remove(.,"new_")))%>%
  select(year, std_name2, deliveries, deliveries_ag, deliveries_mi,
         maxcontract, maxcontract_ag, maxcontract_mi, pctallo_ag, pctallo_mi, parent)%>%
  rename(std_name=std_name2)

deliveries<-deliveries%>%
  filter(kern!=1)%>%
  bind_rows(kern_reallo)%>%
  select(-kern)%>%
  arrange(std_name, year)

#Define 1990 maximum volumes as the time-invariant baseline

deliveries<-deliveries%>%
  group_by(std_name)%>%
  mutate(
    swp_basemax_ag=ifelse(year==1990, maxcontract_ag, NA),
    swp_basemax_mi=ifelse(year==1990, maxcontract_mi, NA)
  )%>%
  ungroup()%>%
  arrange(std_name, swp_basemax_ag)%>%
  group_by(std_name)%>%
  mutate(swp_basemax_ag=swp_basemax_ag[1])%>%
  ungroup()%>%
  arrange(std_name, swp_basemax_mi)%>%
  group_by(std_name)%>%
  mutate(swp_basemax_mi=swp_basemax_mi[1])%>%
  ungroup()%>%
  mutate(
    swp_basemax_ag=replace(swp_basemax_ag, is.na(swp_basemax_ag), 0),
    swp_basemax_mi=replace(swp_basemax_mi, is.na(swp_basemax_mi), 0),
    swp_basemax = swp_basemax_ag + swp_basemax_mi
  )

#Set to 0 when missing

deliveries<-deliveries%>%
  mutate_at(vars(starts_with("deliveries"), starts_with("maxcontract")),
            funs(replace(., is.na(.), 0)))%>%
  rename(
    swp_deliveries=deliveries,
    swp_deliveries_ag=deliveries_ag,
    swp_deliveries_mi=deliveries_mi,
    swp_maxvol=maxcontract,
    swp_maxvol_ag=maxcontract_ag,
    swp_maxvol_mi=maxcontract_mi,
    swp_pctallo_ag=pctallo_ag,
    swp_pctallo_mi=pctallo_mi
  )%>%
  select(-parent)

save(deliveries, file = paste0(OUTPUT, "allocations_source_swp.RData"))
  




