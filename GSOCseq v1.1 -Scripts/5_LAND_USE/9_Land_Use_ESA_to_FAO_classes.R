#DATE: 12-11-2020

# MSc Ing Agr Luciano E Di Paolo
# Dr Ing Agr Guillermo E Peralta

#### Prepare Land Use layer 

rm(list = ls())

library(raster)
library(rgdal)

WD_AOI<-("D:/TRAINING_MATERIALS_GSOCseq_MAPS_12-11-2020/INPUTS/AOI_POLYGON")

WD_LU<-("D:/TRAINING_MATERIALS_GSOCseq_MAPS_12-11-2020/INPUTS/LAND_USE")

WD_SOC<-("D:/TRAINING_MATERIALS_GSOCseq_MAPS_12-11-2020/INPUTS/SOC_MAP")

# Open the shapefile of the region/country

#setwd(WD_AOI)
#AOI<-readOGR(".shp")

# Open Land Use Layer (ESA)

setwd(WD_LU)
ESA_LU<-raster("ESA_Land_Cover_12clases_FAO_AOI_World.tif")
plot(ESA_LU)

# Cut the LU layer by the country polygon

#ESA_LU_AOI<-crop(ESA_LU,AOI)

#plot(ESA_LU_AOI)

# Reclassify ESA LAND USE to FAO LAND USE classes

#   0 = 0	  No Data
#	190 = 1 Artificial
#	10 11 30 40 = 2 Croplands
#	130 = 3 Grassland
#	50 60 61 62 70 71 72 80 81 82 90 100 110 = 4 Tree Covered
#	120 121 122= 5 Shrubs Covered
#	160 180 = 6 Herbaceous vegetation flooded
#	170 = 7 Mangroves
#	150 151 152 153= 8 Sparse Vegetation
#	200 201 202 = 9 Baresoil
#	220 = 10 Snow and Glaciers
#	210 = 11 Waterbodies
#	12  = 12 Treecrops
# 20 = 13 Paddy fields(rice/ flooded crops)

# Create a reclassification matrix. "Is" to "become"

#is<-c(0,190,10,11,30,40,130,50,60,61,62,70,71,72,80,81,82,90,100,110,120,121,122,160,180,
#170,150,151,152,153,200,201,202,220,210,12,20)

#become<-c(0,1,2,2,2,2,3,4,4,4,4,4,4,4,4,4,4,4,4,4,5,5,5,6,6,7,8,8,8,8,9,9,9,10,11,12,13)

#recMat<-matrix(c(is,become),ncol=2,nrow=37)

# Reclassify

#ESA_FAO <- reclassify(ESA_LU, recMat)

# Resample to SOC map layer extent and resolution
setwd(WD_SOC)
SOC_MAP_AOI<-raster("SOC_MAP_AOI_World.tif")

ESA_FAO_res<-resample(ESA_LU,SOC_MAP_AOI,method='ngb') 
#ESA_FAO_mask<-mask(ESA_FAO_res,SOC_MAP_AOI) 

# Save Land Use raster
setwd(WD_LU)
writeRaster(ESA_FAO_res,filename="ESA_Land_Cover_12clases_FAO_AOI_res_World.tif",format='GTiff',overwrite=TRUE)



