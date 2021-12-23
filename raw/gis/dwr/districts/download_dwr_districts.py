#Name: Export ArcGIS Server Map Service Layer to Shapefile with Iterate
#Author: Bryan McIntosh
#Description: Python script that connects to an ArcGIS Server Map Service and downloads a single vector layer
#             to shapefiles. If there are more features than AGS max allowed, it will iterate to extract all features.

import urllib2,json,os,arcpy,itertools
os.chdir("H:/data/GIS/ca/dwr/districts")
ws = os.getcwd() + os.sep

#Set connection to ArcGIS Server, map service, layer ID, and server max requests (1000 is AGS default if not known).
serviceURL = "https://gis.water.ca.gov/arcgis/rest/services"
serviceMap = "/Public/BBMRS/MapServer"
serviceLayerID = 4
serviceMaxRequest = 1500
dataOutputName = "water_agencies"

def defServiceGetIDs():
    IDsRequest = serviceURL + serviceMap + "/" + str(serviceLayerID) + "/query?where=1%3D1&text=&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&relationParam=&outFields=&returnGeometry=true&returnTrueCurves=false&maxAllowableOffset=&geometryPrecision=&outSR=&returnIdsOnly=true&returnCountOnly=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&returnZ=false&returnM=false&gdbVersion=&returnDistinctValues=false&resultOffset=&resultRecordCount=&f=pjson"
    IDsResponse = urllib2.urlopen(IDsRequest)
    IDsJSON = json.loads(IDsResponse.read())
    IDsSorted = sorted(IDsJSON['objectIds'])
    return IDsSorted

def defGroupList(n, iterable):
    args = [iter(iterable)] * n
    return ([e for e in t if e != None] for t in itertools.izip_longest(*args))
    
def defQueryExtractRequests(idMin, idMax):
    myQuery = "&where=objectid+>%3D+" + idMin + "+and+objectid+<%3D+" + idMax
    myParams = "query?geometryType=esriGeometryEnvelope&spatialRel=esriSpatialRelIntersects&relationParam=&outFields=*&returnGeometry=true&geometryPrecision=&outSR=&returnIdsOnly=false&returnCountOnly=false&orderByFields=&groupByFieldsForStatistics=&returnZ=false&returnM=false&returnDistinctValues=false&returnTrueCurves=false&f=pjson"
    myRequest = serviceURL + serviceMap + "/" + str(serviceLayerID) + "/" + myParams + myQuery
    response = urllib2.urlopen(myRequest)
    myJSON = response.read()
    # Write response to json text file
    foo = open(dataOutputName + idMin + ".json", "w+")
    foo.write(myJSON);
    foo.close()
    # Create Feature Class
    arcpy.JSONToFeatures_conversion(dataOutputName + idMin + ".json", ws + dataOutputName + idMin + ".shp")
    
#**MAIN**#
#Get all objectIDs (OIDs) for the layer (there is no server limit for this request)
AllObjectIDs = defServiceGetIDs()
#Divide the OIDs into chunks since there is a limit to map queries (assumed limit stored in serviceMaxRequest variable)
ObjectID_Groups = list(defGroupList(serviceMaxRequest, AllObjectIDs))
#Create a shapefile for each chunk
for ObjectID_Group in ObjectID_Groups:
    idMin = str(ObjectID_Group[0])
    idMax = str(ObjectID_Group[-1])
    defQueryExtractRequests(idMin, idMax)
#Append all shapefiles if desired


