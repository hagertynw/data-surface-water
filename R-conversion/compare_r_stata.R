
#install.packages("arsenal")

# Libraries
library(tidyverse)
library(haven)
library(skimr)
library(janitor)
library(arsenal)
library(sf)

# Set directories
dir_root = "C:/git/data-surface-water/"
dir_r = paste0(dir_root, "R-conversion/output/")
dir_stata = "water/output/"

# Load R data
load(paste0(dir_r,"allocations_aggregate_county.RData"))
r_aggregate_county = allocations_aggregate_county %>%
  as_tibble() %>%
  select(-geometry) %>%
  arrange(county_name, year) %>%
  filter(year >= 1993)
load(paste0(dir_r,"allocations_subset_pointusers.RData"))
load(paste0(dir_r,"allocations_subset_polygonusers.RData"))
load(paste0(dir_r,"allocations_subset_polygonusersXdauco.RData"))
load(paste0(dir_r,"allocations_subset_polygonusersXhuc8.RData"))
r_subset_pointusers = allocations_subset_pointusers
r_subset_polygonusers = allocations_subset_polygonusers
r_subset_polygonusersXdauco = allocations_subset_polygonusersXdauco
r_subset_polygonusersXhuc8 = allocations_subset_polygonusersXhuc8
load(paste0(dir_root, "R-conversion/gis/users_final.RData"))

# Load shapefile data
users_final_py = st_read(paste0(dir_root, "/gis/shapefile_output/users_final.shp"))

# Load Stata data
s_aggregate_county = read_dta(paste0(dir_stata,"allocations_aggregate_county.dta"))
s_subset_polygonusers = read_dta(paste0(dir_stata,"allocations_subset_polygonusers.dta"))
s_subset_pointusers = read_dta(paste0(dir_stata,"allocations_subset_pointusers.dta"))
s_subset_polygonusersXdauco = read_dta(paste0(dir_stata,"allocations_subset_polygonusersXdauco.dta"))
s_subset_polygonusersXhuc8 = read_dta(paste0(dir_stata,"allocations_subset_polygonusersXhuc8.dta"))


# Compare

# subset_pointusers
compare_cols = all_equal(s_subset_pointusers, r_subset_pointusers, convert=T)
compare_rows = comparedf(s_subset_pointusers, r_subset_pointusers, by = c("std_name", "year"))
compare_cols
n.diffs(compare_rows)
compare_rows

# subset_polygonusers
compare_cols = all_equal(s_subset_polygonusers, r_subset_polygonusers, convert=T)
compare_rows = comparedf(s_subset_polygonusers, r_subset_polygonusers, by = c("std_name", "year"))
compare_cols
n.diffs(compare_rows)
compare_rows

# subset_polygonusersXdauco
compare_cols = all_equal(s_subset_polygonusersXdauco, r_subset_polygonusersXdauco, convert=T)
compare_rows = comparedf(s_subset_polygonusersXdauco, r_subset_polygonusersXdauco, by = c("std_name", "dauco_id", year))
compare_cols
n.diffs(compare_rows)
compare_rows






# Skim
skim(r_aggregate_county)
skim(s_aggregate_county)

skim(r_subset_polygonusers)
skim(s_subset_polygonusers)





# same!
sum(r_aggregate_county$year        != s_aggregate_county$year)
sum(r_aggregate_county$county_name != s_aggregate_county$county_name)
sum(r_aggregate_county$county_area != s_aggregate_county$county_area)
sum(r_aggregate_county$county_cropland != s_aggregate_county$county_cropland)
sum(r_aggregate_county$county_pctcrop != s_aggregate_county$county_pctcrop)
sum(r_aggregate_county$pct_allocation != s_aggregate_county$pct_allocation, na.rm=T)


# Merge
subset_polygonusers = inner_join(x = s_subset_polygonusers %>% rename_with(.fn = ~paste0(., ".s")), 
                              y = r_subset_polygonusers %>% rename_with(.fn = ~paste0(., ".r")), 
                              by = c("std_name.s" = "std_name.r", "year.s" = "year.r"),
                              )
aggregate_county = inner_join(x = s_aggregate_county %>% rename_with(.fn = ~paste0(., ".s")), 
                              y = r_aggregate_county %>% rename_with(.fn = ~paste0(., ".r")), 
                              by = c("county_name.s" = "county_name.r", "year.s" = "year.r"),
                              )
aggregate_county = aggregate_county %>%
  relocate(starts_with("county_"), .after = last_col()) %>%
  relocate(starts_with("vol_deliv_cy"), .after = last_col()) %>%
  relocate(starts_with("vol_deliv_wy"), .after = last_col()) %>%
  relocate(starts_with("vol_maximum"), .after = last_col()) %>%
  relocate(starts_with("swp_deliveries"), .after = last_col()) %>%
  relocate(starts_with("swp_maxvol"), .after = last_col()) %>%
  relocate(starts_with("swp_basemax"), .after = last_col()) %>%
  relocate(starts_with("cvp_deliveries_cy"), .after = last_col()) %>%
  relocate(starts_with("cvp_deliveries_wy"), .after = last_col()) %>%
  relocate(starts_with("cvp_maxvol"), .after = last_col()) %>%
  relocate(starts_with("loco_maxvol"), .after = last_col()) %>%
  relocate(starts_with("loco_deliveries"), .after = last_col()) %>%
  relocate(starts_with("rights"), .after = last_col()) %>%
  relocate(starts_with("pct_allocation"), .after = last_col()) %>%
  relocate(starts_with("swp_pctallo"), .after = last_col()) %>%
  relocate(starts_with("cvp_pctallo"), .after = last_col()) %>%
  relocate(starts_with("swp_allo_"), .after = last_col()) %>%
  relocate(starts_with("cvp_allo_"), .after = last_col())
skim(aggregate_county)
skim(subset_polygonusers)


# Compare
sum(aggregate_county$swp_deliveries.s != aggregate_county$swp_deliveries.r)
sum(aggregate_county$swp_maxvol.s != aggregate_county$swp_maxvol.r)
View(filter(aggregate_county, swp_deliveries.s != swp_deliveries.r))








