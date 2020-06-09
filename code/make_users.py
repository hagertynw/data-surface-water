# Purpose:

# Import modules
import arcpy
from arcpy.sa import *

# Settings
arcpy.env.overwriteOutput = True
OUTPUT = "H:/analysis/ca/gis/calwaterusers.gdb/"
FINAL_SHAPEFILES = "H:/analysis/ca/gis/shapefile_output/"
FINAL_TABLES = "H:/analysis/ca/gis/table_output/"

# Input files
RAW_HUC12 = "H:/data/GIS/ca/dwr/CAWBD_Certified/CA_SDE_Extraction_17Dec2008.mdb/WBD/HU12_polygon"
RAW_COUNTY = "H:\data\GIS\ca\ca_atlas\counties\shapefiles\cnty24k09_1_multipart.shp"
RAW_DAU = "H:/data/GIS/ca/dwr/dau_v2_CA105/dau_v2_105.shp"
RAW_DWR_AGENCIES = "H:/data/GIS/ca/dwr/districts/combined/water_agencies.shp"
RAW_ATLAS_FEDERAL = "H:/data/GIS/ca/ca_atlas/water_district_boundaries/federal/WD-WaterUsers.mdb/FederalWaterUsers"
RAW_ATLAS_STATE = "H:/data/GIS/ca/ca_atlas/water_district_boundaries/state/wdst24.shp"
RAW_ATLAS_PRIVATE = "H:/data/GIS/ca/ca_atlas/water_district_boundaries/private/wdpr24.shp"
RAW_MOJAVE = "H:/data/GIS/ca/mojave/Mojave_Water_Agency_Service_Area_Water_Companies_2012.shp"
RAW_CEHTP ="H:/data/GIS/ca/cehtp/all_mod/service_areas.shp"
RAW_CROPMASK = "H:/data/CA/usda_cdl/tif/CMASK_2015_06.tif"
RAW_ATLAS_FEDERAL_TABLE ="H:/data/GIS/ca/ca_atlas/water_district_boundaries/federal/WD-WaterUsers.mdb/Master"

# Set some initial Arc stuff
coordsys_geog = arcpy.SpatialReference('WGS 1984')
coordsys_proj = arcpy.SpatialReference('NAD 1983 UTM Zone 10N')
arcpy.CheckOutExtension("Spatial")

# Program
try:

# Dissolve within layer, into multipart features
print "Dissolving..."
arcpy.Dissolve_management(in_features=RAW_DWR_AGENCIES,
                          out_feature_class=OUTPUT+"agencies_1",
                          dissolve_field="AGENCYUNIQ", statistics_fields="AGENCYNAME FIRST",
                          multi_part="MULTI_PART", unsplit_lines="DISSOLVE_LINES")
arcpy.Dissolve_management(in_features=RAW_ATLAS_FEDERAL,
                          out_feature_class=OUTPUT+"federal_1",
                          dissolve_field="WDNAME",
                          multi_part="MULTI_PART", unsplit_lines="DISSOLVE_LINES")
arcpy.Dissolve_management(in_features=RAW_ATLAS_STATE,
                          out_feature_class=OUTPUT+"swp_1",
                          dissolve_field="WDNAME",
                          multi_part="MULTI_PART", unsplit_lines="DISSOLVE_LINES")
arcpy.Dissolve_management(in_features=RAW_ATLAS_PRIVATE,
                          out_feature_class=OUTPUT+"private_1",
                          dissolve_field="WDNAME",
                          multi_part="MULTI_PART", unsplit_lines="DISSOLVE_LINES")
arcpy.Dissolve_management(in_features=RAW_MOJAVE
                          out_feature_class=OUTPUT+"mojave_1",
                          dissolve_field="Name",
                          multi_part="MULTI_PART", unsplit_lines="DISSOLVE_LINES")
arcpy.Dissolve_management(in_features=RAW_CEHTP,
                          out_feature_class=OUTPUT+"cehtp_1",
                          dissolve_field="pwsid", statistics_fields="pwsname FIRST",
                          multi_part="MULTI_PART", unsplit_lines="DISSOLVE_LINES")
arcpy.Dissolve_management(in_features=RAW_DAU,
                          out_feature_class=OUTPUT+"dau_1",
                          dissolve_field="DAU_CODE", statistics_fields="DAU_NAME FIRST; PSA_CODE FIRST; PSA_NAME FIRST; HR_CODE FIRST; HR_NAME FIRST; PA_NO FIRST",
                          multi_part="MULTI_PART", unsplit_lines="DISSOLVE_LINES")
arcpy.Dissolve_management(in_features=RAW_HUC12,
                          out_feature_class=OUTPUT+"huc8_1",
                          dissolve_field="HUC_8", statistics_fields="",
                          multi_part="MULTI_PART", unsplit_lines="DISSOLVE_LINES")

# Intersect DAU and county
print "Intersecting..."
arcpy.Intersect_analysis(in_features=[OUTPUT+"dau_1", RAW_COUNTY],
                         out_feature_class=OUTPUT+"dauco_1",
                         join_attributes="NO_FID",
                         cluster_tolerance=100)

# Delete unneeded fields
print "Deleting fields..."
arcpy.DeleteField_management(OUTPUT+"dauco_1", "NAME_UCASE")
arcpy.DeleteField_management(OUTPUT+"dauco_1", "FMNAME_PC")
arcpy.DeleteField_management(OUTPUT+"dauco_1", "FMNAME_UC")
arcpy.DeleteField_management(OUTPUT+"dauco_1", "ABBREV")
arcpy.DeleteField_management(OUTPUT+"dauco_1", "ABCODE")
arcpy.DeleteField_management(OUTPUT+"dauco_1", "Shape_Leng")

# Rename fields
print "Renaming fields..."
arcpy.AlterField_management(in_table=OUTPUT+"agencies_1", field="FIRST_AGENCYNAME", new_field_name="username")
arcpy.AlterField_management(in_table=OUTPUT+"federal_1", field="WDNAME", new_field_name="username")
arcpy.AlterField_management(in_table=OUTPUT+"swp_1", field="WDNAME", new_field_name="username")
arcpy.AlterField_management(in_table=OUTPUT+"private_1", field="WDNAME", new_field_name="username")
arcpy.AlterField_management(in_table=OUTPUT+"mojave_1", field="Name", new_field_name="username")
arcpy.AlterField_management(in_table=OUTPUT+"cehtp_1", field="FIRST_pwsNAME", new_field_name="username")
arcpy.AlterField_management(in_table=OUTPUT+"dauco_1", field="FIRST_DAU_NAME", new_field_name="DAU_NAME")
arcpy.AlterField_management(in_table=OUTPUT+"dauco_1", field="FIRST_PSA_CODE", new_field_name="PSA_CODE")
arcpy.AlterField_management(in_table=OUTPUT+"dauco_1", field="FIRST_PSA_NAME", new_field_name="PSA_NAME")
arcpy.AlterField_management(in_table=OUTPUT+"dauco_1", field="FIRST_HR_CODE", new_field_name="HR_CODE")
arcpy.AlterField_management(in_table=OUTPUT+"dauco_1", field="FIRST_HR_NAME", new_field_name="HR_NAME")
arcpy.AlterField_management(in_table=OUTPUT+"dauco_1", field="FIRST_PA_NO", new_field_name="PA_NO")
arcpy.AlterField_management(in_table=OUTPUT+"dauco_1", field="NAME_PCASE", new_field_name="COUNTY_NAME")
arcpy.AlterField_management(in_table=OUTPUT+"dauco_1", field="NUM", new_field_name="COUNTY_CODE")
arcpy.AlterField_management(in_table=OUTPUT+"dauco_1", field="ANSI", new_field_name="COUNTY_ANSI")

# Add a field identifying source file
print "Adding fields..."
arcpy.AddField_management(in_table=OUTPUT+"agencies_1", field_name="source", field_type="TEXT")
arcpy.AddField_management(in_table=OUTPUT+"federal_1", field_name="source", field_type="TEXT")
arcpy.AddField_management(in_table=OUTPUT+"swp_1", field_name="source", field_type="TEXT")
arcpy.AddField_management(in_table=OUTPUT+"private_1", field_name="source", field_type="TEXT")
arcpy.AddField_management(in_table=OUTPUT+"mojave_1", field_name="source", field_type="TEXT")
arcpy.AddField_management(in_table=OUTPUT+"cehtp_1", field_name="source", field_type="TEXT")
arcpy.CalculateField_management(in_table=OUTPUT+"agencies_1", field="source", expression="'agencies'", expression_type="PYTHON_9.3")
arcpy.CalculateField_management(in_table=OUTPUT+"federal_1", field="source", expression="'federal'", expression_type="PYTHON_9.3")
arcpy.CalculateField_management(in_table=OUTPUT+"swp_1", field="source", expression="'swp'", expression_type="PYTHON_9.3")
arcpy.CalculateField_management(in_table=OUTPUT+"private_1", field="source", expression="'private'", expression_type="PYTHON_9.3")
arcpy.CalculateField_management(in_table=OUTPUT+"mojave_1", field="source", expression="'mojave'", expression_type="PYTHON_9.3")
arcpy.CalculateField_management(in_table=OUTPUT+"cehtp_1", field="source", expression="'cehtp'", expression_type="PYTHON_9.3")

# Add a field identifying DAUCOid
arcpy.AddField_management(in_table=OUTPUT+"dauco_1", field_name="dauco_id", field_type="LONG")
arcpy.CalculateField_management(in_table=OUTPUT+"dauco_1", field="dauco_id", expression="!DAU_CODE!.encode()", expression_type="PYTHON_9.3")
arcpy.CalculateField_management(in_table=OUTPUT+"dauco_1", field="dauco_id", expression="!dauco_id!*100 + !COUNTY_CODE!", expression_type="PYTHON_9.3")

# Merge users together (projecting into WGS84, the first input's coordinate system)
print "Merging..."
arcpy.Merge_management([OUTPUT+"cehtp_1",   OUTPUT+"agencies_1",    OUTPUT+"federal_1",
                        OUTPUT+"swp_1",    OUTPUT+"private_1",     OUTPUT+"mojave_1", ],
                       OUTPUT+"users_2")

# Add user unique id
arcpy.AddField_management(in_table=OUTPUT+"users_2", field_name="user_id", field_type="LONG")
arcpy.CalculateField_management(in_table=OUTPUT+"users_2", field="user_id", expression="!OBJECTID!", expression_type="PYTHON_9.3")

# Add centroid (restricting to within shape)
print "Calculating centroids..."
arcpy.AddGeometryAttributes_management(OUTPUT+"users_2", "CENTROID_INSIDE")
arcpy.DeleteField_management(OUTPUT+"users_2", "INSIDE_Z")
arcpy.DeleteField_management(OUTPUT+"users_2", "INSIDE_M")
arcpy.AlterField_management(in_table=OUTPUT+"users_3", field="INSIDE_X", new_field_name="user_x")
arcpy.AlterField_management(in_table=OUTPUT+"users_3", field="INSIDE_Y", new_field_name="user_y")

# Project to meters and calculate area
print "Projecting..."
arcpy.Project_management(in_dataset=OUTPUT+"users_2",
                         out_dataset=OUTPUT+"users_3",
                         out_coor_system=coordsys_proj)
arcpy.Project_management(in_dataset=OUTPUT+"huc8_1",
                         out_dataset=OUTPUT+"huc8_2",
                         out_coor_system=coordsys_proj)
arcpy.Project_management(in_dataset=OUTPUT+"dauco_1",
                         out_dataset=OUTPUT+"dauco_2",
                         out_coor_system=coordsys_proj)

# Add shape areas
print "Calculating areas..."
arcpy.AddGeometryAttributes_management(OUTPUT+"users_3", "AREA", "", "SQUARE_KILOMETERS")
arcpy.AlterField_management(in_table=OUTPUT+"users_3", field="POLY_AREA", new_field_name="totarea")
arcpy.AddGeometryAttributes_management(OUTPUT+"huc8_2", "AREA", "", "SQUARE_KILOMETERS")
arcpy.AlterField_management(in_table=OUTPUT+"huc8_2", field="POLY_AREA", new_field_name="huc8_area")
arcpy.AddGeometryAttributes_management(OUTPUT+"dauco_2", "AREA", "", "SQUARE_KILOMETERS")
arcpy.AlterField_management(in_table=OUTPUT+"dauco_2", field="POLY_AREA", new_field_name="dauco_area")

# Calculate zonal statistics on cropmask and join back
print "Calculating cropmask..."
arcpy.gp.ZonalStatisticsAsTable_sa(OUTPUT+"huc8_2", "HUC_8", RAW_CROPMASK, OUTPUT+"huc8_cropmask", "DATA", "MEAN")
arcpy.gp.ZonalStatisticsAsTable_sa(OUTPUT+"dauco_2", "dauco_id", RAW_CROPMASK, OUTPUT+"dauco_cropmask", "DATA", "MEAN")
arcpy.JoinField_management(in_data=OUTPUT+"huc8_2", in_field="HUC_8",
                           join_table=OUTPUT+"huc8_cropmask", join_field="HUC_8", fields="MEAN")
arcpy.JoinField_management(in_data=OUTPUT+"dauco_2", in_field="dauco_id",
                           join_table=OUTPUT+"dauco_cropmask", join_field="dauco_id", fields="MEAN")
arcpy.AlterField_management(in_table=OUTPUT+"huc8_2", field="MEAN", new_field_name="huc8_pctcrop")
arcpy.AlterField_management(in_table=OUTPUT+"dauco_2", field="MEAN", new_field_name="dauco_pctcrop")

# Project to DD
print "Projecting..."
arcpy.Project_management(in_dataset=OUTPUT+"users_3",
                         out_dataset=OUTPUT+"users_4",
                         out_coor_system=coordsys_geog)
arcpy.Project_management(in_dataset=OUTPUT+"huc8_2",
                         out_dataset=OUTPUT+"huc8_3",
                         out_coor_system=coordsys_geog)
arcpy.Project_management(in_dataset=OUTPUT+"dauco_2",
                         out_dataset=OUTPUT+"dauco_3",
                         out_coor_system=coordsys_geog)

# Export shapefiles
print "Exporting..."
arcpy.FeatureClassToFeatureClass_conversion(in_features=OUTPUT+"huc8_3", out_path=FINAL_SHAPEFILES, out_name="huc8_final")
arcpy.FeatureClassToFeatureClass_conversion(in_features=OUTPUT+"dauco_3", out_path=FINAL_SHAPEFILES, out_name="dauco_final")
arcpy.FeatureClassToFeatureClass_conversion(in_features=OUTPUT+"users_4", out_path=FINAL_SHAPEFILES, out_name="users_final")




# Intersect users with DAUCo and HUC8
print "Intersecting (1/2)..."
arcpy.Intersect_analysis(in_features=[OUTPUT+"users_3", OUTPUT+"huc8_2"],
                         out_feature_class=OUTPUT+"users_huc8_4",
                         join_attributes="NO_FID",
                         cluster_tolerance=1)
print "Intersecting (2/2)..."
arcpy.Intersect_analysis(in_features=[OUTPUT+"users_3", OUTPUT+"dauco_2"],
                         out_feature_class=OUTPUT+"users_dauco_4",
                         join_attributes="NO_FID",
                         cluster_tolerance=1)
print "Dissolving (1/2)..."
arcpy.Dissolve_management(in_features=OUTPUT+"users_huc8_4",
                          out_feature_class=OUTPUT+"users_huc8_5",
                          dissolve_field=["user_id", "HUC_8"], statistics_fields="pwsid FIRST; username FIRST; source FIRST; AGENCYUNIQ FIRST; user_x FIRST; user_y FIRST; totarea FIRST; huc8_area FIRST; huc8_pctcrop FIRST",
                          multi_part="MULTI_PART", unsplit_lines="DISSOLVE_LINES")
print "Dissolving (2/2)..."
arcpy.Dissolve_management(in_features=OUTPUT+"users_dauco_4",
                          out_feature_class=OUTPUT+"users_dauco_5",
                          dissolve_field=["user_id", "dauco_id"], statistics_fields="pwsid FIRST; username FIRST; source FIRST; AGENCYUNIQ FIRST; user_x FIRST; user_y FIRST; totarea FIRST; DAU_CODE FIRST; DAU_NAME FIRST; PSA_CODE FIRST; PSA_NAME FIRST; HR_CODE FIRST; HR_NAME FIRST; PA_NO FIRST; COUNTY_NAME FIRST; COUNTY_CODE FIRST; COUNTY_ANSI FIRST; dauco_area FIRST; dauco_pctcrop FIRST",
                          multi_part="MULTI_PART", unsplit_lines="DISSOLVE_LINES")
print "Renaming variables..."
huc8_vars = ["pwsid", "username", "source", "AGENCYUNIQ", "user_x", "user_y", "totarea", "huc8_area", "huc8_pctcrop"]
dauco_vars  = ["pwsid", "username", "source", "AGENCYUNIQ", "user_x", "user_y", "totarea", "DAU_CODE", "DAU_NAME", "PSA_CODE", "PSA_NAME", "HR_CODE", "HR_NAME", "PA_NO", "COUNTY_NAME", "COUNTY_CODE", "COUNTY_ANSI", "dauco_area", "dauco_pctcrop"]
for col in huc8_vars:
    arcpy.AlterField_management(in_table=OUTPUT+"users_huc8_5", field="FIRST_"+col, new_field_name=col)
for col in dauco_vars:
    arcpy.AlterField_management(in_table=OUTPUT+"users_dauco_5", field="FIRST_"+col, new_field_name=col)

# Add unique id
arcpy.AddField_management(in_table=OUTPUT+"users_huc8_5", field_name="iuser_id", field_type="LONG")
arcpy.CalculateField_management(in_table=OUTPUT+"users_huc8_5", field="iuser_id", expression="!OBJECTID!", expression_type="PYTHON_9.3")
arcpy.AddField_management(in_table=OUTPUT+"users_dauco_5", field_name="iuser_id", field_type="LONG")
arcpy.CalculateField_management(in_table=OUTPUT+"users_dauco_5", field="iuser_id", expression="!OBJECTID!", expression_type="PYTHON_9.3")

# Add centroids within intersected users (restricting to within shape)
print "Calculating centroids..."
arcpy.AddGeometryAttributes_management(OUTPUT+"users_huc8_5", "CENTROID_INSIDE", "", "", coordsys_geog)
arcpy.AddGeometryAttributes_management(OUTPUT+"users_dauco_5", "CENTROID_INSIDE", "", "", coordsys_geog)
arcpy.AlterField_management(in_table=OUTPUT+"users_huc8_5", field="INSIDE_X", new_field_name="iuser_x")
arcpy.AlterField_management(in_table=OUTPUT+"users_huc8_5", field="INSIDE_Y", new_field_name="iuser_y")
arcpy.AlterField_management(in_table=OUTPUT+"users_dauco_5", field="INSIDE_X", new_field_name="iuser_x")
arcpy.AlterField_management(in_table=OUTPUT+"users_dauco_5", field="INSIDE_Y", new_field_name="iuser_y")
arcpy.DeleteField_management(OUTPUT+"users_huc8_5", "INSIDE_Z")
arcpy.DeleteField_management(OUTPUT+"users_huc8_5", "INSIDE_M")
arcpy.DeleteField_management(OUTPUT+"users_dauco_5", "INSIDE_Z")
arcpy.DeleteField_management(OUTPUT+"users_dauco_5", "INSIDE_M")

# Add shape areas for intersected users
print "Calculating areas..."
arcpy.AddGeometryAttributes_management(OUTPUT+"users_huc8_5", "AREA", "", "SQUARE_KILOMETERS")
arcpy.AlterField_management(in_table=OUTPUT+"users_huc8_5", field="POLY_AREA", new_field_name="iuser_area")
arcpy.AddGeometryAttributes_management(OUTPUT+"users_dauco_5", "AREA", "", "SQUARE_KILOMETERS")
arcpy.AlterField_management(in_table=OUTPUT+"users_dauco_5", field="POLY_AREA", new_field_name="iuser_area")

# Calculate zonal statistics on cropmask and join back
print "Calculating cropmask (1/2 - may take up to an hour)..."
arcpy.ZonesWOverlap(Zonal_Feature_Class="users_huc8_5",
                    Zone_Field="iuser_id",
                    Value_Raster=RAW_CROPMASK,
                    Workspace="H:/analysis/ca/gis/scratch",
                    Zonal_Statistics_Table=OUTPUT+"users_huc8_cropmask",
                    Feature_Class_Divides="10")
print "Calculating cropmask (2/2 - may take up to an hour)..."
arcpy.ZonesWOverlap(Zonal_Feature_Class="users_dauco_5",
                    Zone_Field="iuser_id",
                    Value_Raster=RAW_CROPMASK,
                    Workspace="H:/analysis/ca/gis/scratch",
                    Zonal_Statistics_Table=OUTPUT+"users_dauco_cropmask",
                    Feature_Class_Divides="10")
arcpy.JoinField_management(in_data=OUTPUT+"users_huc8_5", in_field="iuser_id",
                           join_table=OUTPUT+"users_huc8_cropmask", join_field="IUSER_ID", fields="MEAN")
arcpy.JoinField_management(in_data=OUTPUT+"users_dauco_5", in_field="iuser_id",
                           join_table=OUTPUT+"users_dauco_cropmask", join_field="IUSER_ID", fields="MEAN")
arcpy.AlterField_management(in_table=OUTPUT+"users_huc8_5", field="MEAN", new_field_name="iuser_pctcrop")
arcpy.AlterField_management(in_table=OUTPUT+"users_dauco_5", field="MEAN", new_field_name="iuser_pctcrop")

# Export tables
arcpy.TableToExcel_conversion(Input_Table=OUTPUT+"users_huc8_5", Output_Excel_File=FINAL_TABLES+"users_huc8.xls")
arcpy.TableToExcel_conversion(Input_Table=OUTPUT+"users_dauco_5", Output_Excel_File=FINAL_TABLES+"users_dauco.xls")
arcpy.TableToExcel_conversion(Input_Table=RAW_ATLAS_FEDERAL_TABLE, Output_Excel_File=FINAL_TABLES+"federal_table.xls")


except:
    print arcpy.GetMessages()
    raise    


