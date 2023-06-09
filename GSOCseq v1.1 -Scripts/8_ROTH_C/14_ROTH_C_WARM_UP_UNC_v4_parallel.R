#12/11/2020
#
# SPATIAL SOIL R  for VECTORS
#
# ROTH C phase 3: WARM UP
#
# MSc Ing Agr Luciano E Di Paolo
# Dr Ing Agr Guillermo E Peralta
###################################
#SoilR from Sierra, C.A., M. Mueller, S.E. Trumbore (2012). 
#Models of soil organic matter decomposition: the SoilR package, 
#version 1.0 Geoscientific Model Development, 5(4), 
#1045--1060. 
#URL http://www.geosci-model-dev.net/5/1045/2012/gmd-5-1045-2012.html.
#####################################

#Empty global environment
rm(list=ls()) 

#Load packages
library(SoilR)
library(raster)
library(rgdal)
library(soilassessment)
library(foreach)
library(doParallel)


#Define a path to the working directory
wd <-"D:/TRAINING_MATERIALS_GSOCseq_MAPS_12-11-2020"
#Set the working directory
setwd(wd)

#Open empty vector
Vector<-readOGR("INPUTS/TARGET_POINTS/target_points_sub.shp")


#Open Warm Up Stack
Stack_Set_warmup<- stack("INPUTS/STACK/Stack_Set_WARM_UP_AOI.tif")

# Open Result from the spin up phase
#A vector with 5 columns, one for each pool
Spin_up<-readOGR("D:/TRAINING_MATERIALS_GSOCseq_MAPS_12-11-2020/OUTPUTS/1_SPIN_UP/SPIN_UP_County_AOI.shp")


# Open Precipitation , temperature, and Evapotranspiration file 
# 216 layers stack
PREC<-stack("INPUTS/CRU_LAYERS/Prec_Stack_216_01-18_CRU.tif")
TEMP<-stack("INPUTS/CRU_LAYERS/Temp_Stack_216_01-18_CRU.tif")
PET<-stack("INPUTS/CRU_LAYERS/PET_Stack_216_01-18_CRU.tif")

# TERRA CLIMATE LAYERS . Use the layers downloaded from GEE and a scaling factors of 0.1
#PREC<-stack("INPUTS/TERRA_CLIME/Precipitation_2001-2021_Pergamino.tif")
#TEMP<-stack("INPUTS/TERRA_CLIME/AverageTemperature_2001-2021_Pergamino.tif")*0.1
#PET<-stack("INPUTS/TERRA_CLIME/PET_2001-2021_Pergamino.tif")*0.1

#Also check that the number of layers of DR and Land use are the same as the years of climate data. 

#Open Mean NPP MIAMI 1981 - 2000
NPP<-raster("INPUTS/NPP/NPP_MIAMI_MEAN_81-00_AOI.tif")

NPP_MEAN_MIN<-raster("INPUTS/NPP/NPP_MIAMI_MEAN_81-00_AOI_MIN.tif")

NPP_MEAN_MAX<-raster("INPUTS/NPP/NPP_MIAMI_MEAN_81-00_AOI_MAX.tif")

#Open the land use layer (year 2000).
LU_AOI<-raster("INPUTS/LAND_USE/ESA_Land_Cover_12clases_FAO_AOI.tif")

NPP<-resample(NPP,LU_AOI,method='bilinear')
NPP_MEAN_MIN<-resample(NPP_MEAN_MIN,LU_AOI,method='bilinear')
NPP_MEAN_MAX<-resample(NPP_MEAN_MAX,LU_AOI, method='bilinear')

#Apply NPP coefficientes
NPP<-(LU_AOI==2 | LU_AOI==12 | LU_AOI==13)*NPP*0.53+ (LU_AOI==4)*NPP*0.88 + (LU_AOI==3 | LU_AOI==5 | LU_AOI==6 | LU_AOI==8)*NPP*0.72
NPP_MEAN_MIN<-(LU_AOI==2 | LU_AOI==12 | LU_AOI==13)*NPP_MEAN_MIN*0.53+ (LU_AOI==4)*NPP_MEAN_MIN*0.88 + (LU_AOI==3 | LU_AOI==5 | LU_AOI==6 | LU_AOI==8)*NPP_MEAN_MIN*0.72
NPP_MEAN_MAX<-(LU_AOI==2 | LU_AOI==12 | LU_AOI==13)*NPP_MEAN_MAX*0.53+ (LU_AOI==4)*NPP_MEAN_MAX*0.88 + (LU_AOI==3 | LU_AOI==5 | LU_AOI==6 | LU_AOI==8)*NPP_MEAN_MAX*0.72


# Extract variables to points
Vector_points<-extract(Stack_Set_warmup,Vector,sp=TRUE)
Vector_points<-extract(TEMP,Vector_points,sp=TRUE)
Vector_points<-extract(PREC,Vector_points,sp=TRUE)
Vector_points<-extract(PET,Vector_points,sp=TRUE)
Vector_points<-extract(NPP,Vector_points,sp=TRUE)
Vector_points<-extract(NPP_MEAN_MIN,Vector_points,sp=TRUE)
Vector_points<-extract(NPP_MEAN_MAX,Vector_points,sp=TRUE)

WARM_UP<-Vector


# Warm Up number of years simulation 
yearsSimulation<-dim(TEMP)[3]/12

clim_layers<-yearsSimulation*12

nppBand<-nlayers(Stack_Set_warmup)+clim_layers*3+2

firstClimLayer<-nlayers(Stack_Set_warmup)+2

nppBand_min<-nppBand+1

nppBand_max<-nppBand+2

nDR_beg<-(16+yearsSimulation)
nDR_end<-nDR_beg+(yearsSimulation-1)

# Extract the layers from the Vector

#SOC_im<-Vector_points[[2]] 

#clay_im<-Vector_points[[3]] 

#LU_im<-Vector_points[[16]]

#NPP_im<-Vector_points[[nppBand]]

#NPP_im_MIN<-Vector_points[[nppBand_min]]

#NPP_im_MAX<-Vector_points[[nppBand_max]]

# Define Years

years=seq(1/12,1,by=1/12)


# ROTH C MODEL FUNCTION . 

###########function set up starts################
Roth_C<-function(Cinputs,years,DPMptf, RPMptf, BIOptf, HUMptf, FallIOM,Temp,Precip,Evp,Cov,Cov1,Cov2,soil.thick,SOC,clay,DR,bare1,LU)
  
{
  
  # Paddy fields coefficent fPR = 0.4 if the target point is class = 13 , else fPR=1
  # From Shirato and Yukozawa 2004
  
  fPR=(LU == 13)*0.4 + (LU!=13)*1
  
  #Temperature effects per month
  fT=fT.RothC(Temp[,2]) 
  
  #Moisture effects per month . Si se usa evapotranspiracion pE=1
  
  fw1func<-function(P, E, S.Thick = 30, pClay = 32.0213, pE = 1, bare) 
  {
    
    M = P - E * pE
    Acc.TSMD = NULL
    for (i in 2:length(M)) {
      B = ifelse(bare[i] == FALSE, 1, 1.8)
      Max.TSMD = -(20 + 1.3 * pClay - 0.01 * (pClay^2)) * (S.Thick/23) * (1/B)
      Acc.TSMD[1] = ifelse(M[1] > 0, 0, M[1])
      if (Acc.TSMD[i - 1] + M[i] < 0) {
        Acc.TSMD[i] = Acc.TSMD[i - 1] + M[i]
      }
      else (Acc.TSMD[i] = 0)
      if (Acc.TSMD[i] <= Max.TSMD) {
        Acc.TSMD[i] = Max.TSMD
      }
    }
    b = ifelse(Acc.TSMD > 0.444 * Max.TSMD, 1, (0.2 + 0.8 * ((Max.TSMD - 
                                                                Acc.TSMD)/(Max.TSMD - 0.444 * Max.TSMD))))
    b<-clamp(b,lower=0.2)
    return(data.frame(b))
  }
  
  
  fW_2<- fw1func(P=(Precip[,2]), E=(Evp[,2]), S.Thick = soil.thick, pClay = clay, pE = 1, bare=bare1)$b 
  
  #Vegetation Cover effects  C1: No till Agriculture, C2: Conventional Agriculture, C3: Grasslands and Forests, C4 bareland and Urban
  
  fC<-Cov2[,2]
  
  # Set the factors frame for Model calculations
  
  xi.frame=data.frame(years,rep(fT*fW_2*fC*fPR,length.out=length(years)))
  
  # RUN THE MODEL from SoilR
  #Loads the model Si pass=TRUE genera calcula el modelo aunque sea invalido. 
  #Model3_spin=RothCModel(t=years,C0=c(DPMptf, RPMptf, BIOptf, HUMptf, FallIOM),In=Cinputs,DR=DR,clay=clay,xi=xi.frame, pass=TRUE) 
  #Calculates stocks for each pool per month
  #Ct3_spin=getC(Model3_spin)
  
  # RUN THE MODEL from soilassesment
  
  Model3_spin=carbonTurnover(tt=years,C0=c(DPMptf, RPMptf, BIOptf, HUMptf, FallIOM),In=Cinputs,Dr=DR,clay=clay,effcts=xi.frame, "euler") 
  
  Ct3_spin=Model3_spin[,2:6]
  
  # Get the final pools of the time series
  
  poolSize3_spin=as.numeric(tail(Ct3_spin,1))
  
  return(poolSize3_spin)
  
}
##############funtion set up ends##########

# Iterates over the area of interest and over 18 years 

Cinputs<-c()
Cinputs_min<-c()
Cinputs_max<-c()
NPP_M_MIN<-c()
NPP_M_MAX<-c()
NPP_M<-c()

##################################################################

n_cores <- detectCores() - 1
n_cores

# Create a Cluster
parallelCluster <- makeCluster(n_cores, type = "SOCK", methods = FALSE)
setDefaultCluster(parallelCluster)
registerDoParallel(parallelCluster)

#listOfRows <- split(Vector_variables, sample(1:4, nrow(Vector_variables), replace=T))
WARM_UP<-Vector

blocks<-round(length(Vector_points)/n_cores)

listOfRows<- split(Vector_points, (seq(nrow(Vector_points))-1) %/% blocks) 
listOfCin<-  split(WARM_UP, (seq(nrow(WARM_UP))-1) %/% blocks)   
listofSp<- split(Spin_up, (seq(nrow(Spin_up))-1) %/% blocks) 

listOfRows<-listOfRows[1:n_cores]
listOfCin<-listOfCin[1:n_cores] 
listofSp<-listofSp[1:n_cores]

# Before continuing check that the lists have the same number of elements than the cores.
x<-list()
results<-c()
system.time({
results <- foreach(j=1:length(listOfRows),.inorder = FALSE,.combine = rbind,.packages= c('raster','rgdal',"SoilR","soilassessment")) %dopar% {
  
  iteration<-function(Vector_variables2,WARM_UP2,Spin_up2)
  {
    Cinputs<-c()
    Cinputs_min<-c()
    Cinputs_max<-c()
    NPP_M_MIN<-c()
    NPP_M_MAX<-c()
    NPP_M<-c()
    for (i in 1:nrow(Vector_variables2@data)) 
    {
      # Extract the variables 1
      
      gt<-firstClimLayer
      gp<-gt+clim_layers
      gevp<-gp+clim_layers
      
      for (w in 1:(dim(TEMP)[3]/12)) {
        
        print(c("year:",w))
        # Extract the variables 
        
        Vect<-as.data.frame(Vector_variables2@data[i,])
        
        Temp<-as.data.frame(t(Vect[gt:(gt+11)]))
        Temp<-data.frame(Month=1:12, Temp=Temp[,1])
        
        Precip<-as.data.frame(t(Vect[gp:(gp+11)]))
        Precip<-data.frame(Month=1:12, Precip=Precip[,1])
        
        Evp<-as.data.frame(t(Vect[gevp:(gevp+11)]))
        Evp<-data.frame(Month=1:12, Evp=Evp[,1])
        
        Cov<-as.data.frame(t(Vect[4:15]))
        Cov1<-data.frame(Cov=Cov[,1])
        Cov2<-data.frame(Month=1:12, Cov=Cov[,1])
        
        DR_im<-as.data.frame(t(Vect[nDR_beg:nDR_end])) # DR one per year according to LU
        DR_im<-data.frame(DR_im=DR_im[,1])
        
        gt<-gt+12
        gp<-gp+12
        gevp<-gevp+12
        
        SOC_im<-Vector_variables2@data[[i,2]] 
          
        clay_im<-Vector_variables2@data[[i,3]] 
          
        LU_im<-Vector_variables2@data[[i,16]]
        
        NPP_im<-Vector_variables2@data[[i,nppBand]]
        
        NPP_im_MIN<-Vector_variables2@data[[i,nppBand_min]]
        
        NPP_im_MAX<-Vector_variables2@data[[i,nppBand_max]]
        
        #Avoid calculus over Na values 
        
        if (any(is.na(Evp[,2])) | any(is.na(Temp[,2])) | any(is.na(SOC_im)) | any(is.na(clay_im)) | any(is.na(Spin_up@data[i,3]))  | any(is.na(NPP_im)) | any(is.na(Precip[,2]))  |  any(is.na(Cov2[,2]))  |  any(is.na(Cov1[,1]))  | any(is.na(DR_im[,1]))    |  (SOC_im<0) | (clay_im<0) | (Spin_up@data[i,3]<=0) ) {WARM_UP2[i,2]<-0}else{
          
          # Get the variables from the vector
          
          
          
          soil.thick=30  #Soil thickness (organic layer topsoil), in cm
          SOC<-SOC_im      #Soil organic carbon in t/ha 
          clay<-clay_im        #Percent clay %
          
          DR<-DR_im[w,1]              # DPM/RPM (decomposable vs resistant plant material)
          bare1<-(Cov1>0.8)           # If the surface is bare or vegetated
          NPP_81_00<-NPP_im
          NPP_81_00_MIN<-NPP_im_MIN
          NPP_81_00_MAX<-NPP_im_MAX
          
          # PHASE 2  : WARM UP .  years (w)
          
          # Cinputs 
          T<-mean(Temp[,2])
          P<-sum(Precip[,2])
          NPP_M[w]<-NPPmodel(P,T,"miami")*(1/100)*0.5
          NPP_M[w]<-(LU_im==2 | LU_im==12 | LU_im==13)*NPP_M[w]*0.53+ (LU_im==4)*NPP_M[w]*0.88 + (LU_im==3 | LU_im==5 | LU_im==6 | LU_im==8)*NPP_M[w]*0.72
          
          if (w==1) {Cinputs[w]<-(Spin_up2@data[i,3]/NPP_81_00)*NPP_M[w]} else {Cinputs[w]<-(Cinputs[[w-1]]/ NPP_M[w-1]) * NPP_M[w]} 
          
          # Cinputs MIN
          
          Tmin<-mean(Temp[,2]*1.02)
          Pmin<-sum(Precip[,2]*0.95)
          NPP_M_MIN[w]<-NPPmodel(Pmin,Tmin,"miami")*(1/100)*0.5
          NPP_M_MIN[w]<-(LU_im==2 | LU_im==12 | LU_im==13)*NPP_M_MIN[w]*0.53+ (LU_im==4)*NPP_M_MIN[w]*0.88 + (LU_im==3 | LU_im==5 | LU_im==6 | LU_im==8)*NPP_M_MIN[w]*0.72
          
          if (w==1) {Cinputs_min[w]<-(Spin_up2@data[i,10]/NPP_81_00)*NPP_M_MIN[w]} else {Cinputs_min[w]<-(Cinputs_min[[w-1]]/ NPP_M_MIN[w-1]) * NPP_M_MIN[w]} 
          
          # Cinputs MAX
          
          Tmax<-mean(Temp[,2]*0.98)
          Pmax<-sum(Precip[,2]*1.05)
          NPP_M_MAX[w]<-NPPmodel(Pmax,Tmax,"miami")*(1/100)*0.5
          NPP_M_MAX[w]<-(LU_im==2 | LU_im==12 | LU_im==13)*NPP_M_MAX[w]*0.53+ (LU_im==4)*NPP_M_MAX[w]*0.88 + (LU_im==3 | LU_im==5 | LU_im==6 | LU_im==8)*NPP_M_MAX[w]*0.72
          
          if (w==1) {Cinputs_max[w]<-(Spin_up2@data[i,11]/NPP_81_00)*NPP_M_MAX[w]} else {Cinputs_max[w]<-(Cinputs_max[[w-1]]/ NPP_M_MAX[w-1]) * NPP_M_MAX[w]} 
          
          # Run the model for 2001-2018 
          
          if (w==1) {
            f_wp<-Roth_C(Cinputs=Cinputs[1],years=years,DPMptf=Spin_up2@data[i,5], RPMptf=Spin_up2@data[i,6], BIOptf=Spin_up2@data[i,7], HUMptf=Spin_up2@data[i,8], FallIOM=Spin_up2@data[i,9],Temp=Temp,Precip=Precip,Evp=Evp,Cov=Cov,Cov1=Cov1,Cov2=Cov2,soil.thick=soil.thick,SOC=SOC,clay=clay,DR=DR,bare1=bare1,LU=LU_im)
          } else {
            f_wp<-Roth_C(Cinputs=Cinputs[w],years=years,DPMptf=f_wp[1], RPMptf=f_wp[2], BIOptf=f_wp[3], HUMptf=f_wp[4], FallIOM=f_wp[5],Temp=Temp,Precip=Precip,Evp=Evp,Cov=Cov,Cov1=Cov1,Cov2=Cov2,soil.thick=soil.thick,SOC=SOC,clay=clay,DR=DR,bare1=bare1,LU=LU_im)
          }
          
          f_wp_t<-f_wp[1]+f_wp[2]+f_wp[3]+f_wp[4]+f_wp[5]
          
          # Run the model for minimum values
          
          if (w==1) {
            f_wp_min<-Roth_C(Cinputs=Cinputs_min[1],years=years,DPMptf=Spin_up2@data[i,13], RPMptf=Spin_up2@data[i,14], BIOptf=Spin_up2@data[i,15], HUMptf=Spin_up2@data[i,16], FallIOM=Spin_up2@data[i,17],Temp=Temp*1.02,Precip=Precip*0.95,Evp=Evp,Cov=Cov,Cov1=Cov1,Cov2=Cov2,soil.thick=soil.thick,SOC=SOC*0.8,clay=clay*0.9,DR=DR,bare1=bare1,LU=LU_im)
          } else {
            f_wp_min<-Roth_C(Cinputs=Cinputs_min[w],years=years,DPMptf=f_wp_min[1], RPMptf=f_wp_min[2], BIOptf=f_wp_min[3], HUMptf=f_wp_min[4], FallIOM=f_wp_min[5],Temp=Temp*1.02,Precip=Precip*0.95,Evp=Evp,Cov=Cov,Cov1=Cov1,Cov2=Cov2,soil.thick=soil.thick,SOC=SOC*0.8,clay=clay*0.9,DR=DR,bare1=bare1,LU=LU_im)
          }
          
          f_wp_t_min<-f_wp_min[1]+f_wp_min[2]+f_wp_min[3]+f_wp_min[4]+f_wp_min[5]
          
          # Run the model for maximum values
          
          if (w==1) {
            f_wp_max<-Roth_C(Cinputs=Cinputs_max[1],years=years,DPMptf=Spin_up2@data[i,19], RPMptf=Spin_up2@data[i,20], BIOptf=Spin_up2@data[i,21], HUMptf=Spin_up2@data[i,22], FallIOM=Spin_up2@data[i,23],Temp=Temp*0.98,Precip=Precip*1.05,Evp=Evp,Cov=Cov,Cov1=Cov1,Cov2=Cov2,soil.thick=soil.thick,SOC=SOC*1.2,clay=clay*1.1,DR=DR,bare1=bare1,LU=LU_im)
          } else {
            f_wp_max<-Roth_C(Cinputs=Cinputs_max[w],years=years,DPMptf=f_wp_max[1], RPMptf=f_wp_max[2], BIOptf=f_wp_max[3], HUMptf=f_wp_max[4], FallIOM=f_wp_max[5],Temp=Temp*0.98,Precip=Precip*1.05,Evp=Evp,Cov=Cov,Cov1=Cov1,Cov2=Cov2,soil.thick=soil.thick,SOC=SOC*1.2,clay=clay*1.1,DR=DR,bare1=bare1,LU=LU_im)
          }
          
          f_wp_t_max<-f_wp_max[1]+f_wp_max[2]+f_wp_max[3]+f_wp_max[4]+f_wp_max[5]
          
          #print(w)
          #print(c(i,SOC,Spin_up[i,3],NPP_81_00,Cinputs[w],f_wp_t))
          ##print(c(NPP_M[w],Cinputs[w]))
        }
      }
      if (is.na(mean(Cinputs))){CinputFOWARD<-NA} else { 
        
        CinputFOWARD<-mean(Cinputs)
        
        CinputFOWARD_min<-mean(Cinputs_min)
        
        CinputFOWARD_max<-mean(Cinputs_max)
        
        WARM_UP2[i,2]<-SOC
        WARM_UP2[i,3]<-Cinputs[18]
        WARM_UP2[i,4]<-f_wp_t
        WARM_UP2[i,5]<-f_wp[1]
        WARM_UP2[i,6]<-f_wp[2]
        WARM_UP2[i,7]<-f_wp[3]
        WARM_UP2[i,8]<-f_wp[4]
        WARM_UP2[i,9]<-f_wp[5]
        WARM_UP2[i,10]<-CinputFOWARD
        WARM_UP2[i,11]<-f_wp_t_min
        WARM_UP2[i,12]<-f_wp_min[1]
        WARM_UP2[i,13]<-f_wp_min[2]
        WARM_UP2[i,14]<-f_wp_min[3]
        WARM_UP2[i,15]<-f_wp_min[4]
        WARM_UP2[i,16]<-f_wp_min[5]
        WARM_UP2[i,17]<-f_wp_t_max
        WARM_UP2[i,18]<-f_wp_max[1]
        WARM_UP2[i,19]<-f_wp_max[2]
        WARM_UP2[i,20]<-f_wp_max[3]
        WARM_UP2[i,21]<-f_wp_max[4]
        WARM_UP2[i,22]<-f_wp_max[5]
        WARM_UP2[i,23]<-CinputFOWARD_min
        WARM_UP2[i,24]<-CinputFOWARD_max
        
        Cinputs<-c()
        Cinputs_min<-c()
        Cinputs_max<-c()
        
        
      }
      
  
    }
    return(WARM_UP2)}
  
  x<- iteration(Vector_variables2=listOfRows[[j]],WARM_UP2=listOfCin[[j]],Spin_up2=listofSp[[j]])
  x
}

})
# Stop the clusters
stopCluster(parallelCluster)


WARM_UP<-results

################for loop ends#############

colnames(WARM_UP@data)[2]="SOC_FAO"
colnames(WARM_UP@data)[3]="Cin_t0"
colnames(WARM_UP@data)[4]="SOC_t0"
colnames(WARM_UP@data)[5]="DPM_w_up"
colnames(WARM_UP@data)[6]="RPM_w_up"
colnames(WARM_UP@data)[7]="BIO_w_up"
colnames(WARM_UP@data)[8]="HUM_w_up"
colnames(WARM_UP@data)[9]="IOM_w_up"
colnames(WARM_UP@data)[10]="Cin_mean"
colnames(WARM_UP@data)[11]="SOC_t0min"
colnames(WARM_UP@data)[12]="DPM_w_min"
colnames(WARM_UP@data)[13]="RPM_w_min"
colnames(WARM_UP@data)[14]="BIO_w_min"
colnames(WARM_UP@data)[15]="HUM_w_min"
colnames(WARM_UP@data)[16]="IOM_w_min"
colnames(WARM_UP@data)[17]="SOC_t0max"
colnames(WARM_UP@data)[18]="DPM_w_max"
colnames(WARM_UP@data)[19]="RPM_w_max"
colnames(WARM_UP@data)[20]="BIO_w_max"
colnames(WARM_UP@data)[21]="HUM_w_max"
colnames(WARM_UP@data)[22]="IOM_w_max"
colnames(WARM_UP@data)[23]="Cin_min"
colnames(WARM_UP@data)[24]="Cin_max"


# SAVE the Points (shapefile)
setwd("D:/TRAINING_MATERIALS_GSOCseq_MAPS_12-11-2020/OUTPUTS/2_WARM_UP")
writeOGR(WARM_UP,".", "WARM_UP_Country_AOI", driver="ESRI Shapefile",overwrite=TRUE)





