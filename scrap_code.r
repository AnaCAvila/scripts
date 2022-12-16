
################################## TESTING ZONE  ######################################################


head(agb_forest_age)

biomass[biomass$agbd == 49 & biomass$x == 213210 & biomass$y == 9663510,]

regrowth[rownames(regrowth) == 505845282, ] 
biomass[biomass$xy == 228090109643800, ] 


ggplot(agb_forest_age, aes(x=forest_age)) + 
  geom_histogram(binwidth=1)


# lots of low biomasses at all ages... why? Biomass is showing as lower than expected.
# could be misalignment - showing nearby patches of low biomass.
# could be misclassification
#remove all cases of 305
#remove all cases with 300-500-300
#remove all cases of less than 4 consecutive years of 100-class before regrowth (seem to be accounting for high biomass, low age)
# GEDI is showing some suspiciously low AGBD readings.


tst = subset(agb_forest_age, agbd < 50)
tst = subset(tst, agbd > 13)
tst = subset(tst, forest_age == 29)


hist(biomass$agbd, breaks=20)


biomass |>
  subset(abs(N00W060_agb - 67) < 1e-3)


biomass |>
  subset(abs(Lon - -100.7) < 1e-5 & abs(Lat - 59.6) < 1e-5)

Q <- quantile(biomass$agbd, probs=c(.1, .9), na.rm = FALSE)
iqr <- IQR(biomass$agbd)
up <-  Q[2]+1.5*iqr # Upper Range  
eliminated<- subset(biomass, biomass$agbd < (Q[2]+1.5*iqr))

##################

extent_list = lapply(tmp_dfs, extent)
# make a matrix out of it, each column represents a raster, rows the values
extent_list<-lapply(extent_list, as.matrix)
matrix_extent<-matrix(unlist(extent_list), ncol=length(extent_list))
rownames(matrix_extent)<-c("xmin", "ymin", "xmax", "ymax")

best_extent = extent(min(matrix_extent[1,]), max(matrix_extent[3,]),
min(matrix_extent[2,]), max(matrix_extent[4,]))

# the range of your extent in degrees
ranges<-apply(as.matrix(best_extent), 1, diff)
# the resolution of your raster (pick one) or add a desired resolution
reso<-res(tmp_dfs[[1]])
# deviding the range by your desired resolution gives you the number of rows and columns
nrow_ncol<-ranges/reso

# create your raster with the following
s<-raster(best_extent, nrows=nrow_ncol[2], ncols=nrow_ncol[1], crs=tmp_dfs[[1]]@crs)

##########

results <- list()

for(i in 1:length(tmp_dfs)) {
  print(i)
  e <- extent(s)
  r <-tmp_dfs[[i]] # raster(files[i])
  rc <- crop(tmp_dfs[[i]], e)
  if(sum(as.matrix(extent(rc))!= as.matrix(e)) == 0){ # edited
    rc <- mask(rc, a) # You can't mask with extent, only with a Raster layer, RStack or RBrick
  }else{
    rc <- extend(rc,s)
    rc<- mask(rc, s)
  }

  # commented for reproducible example      
  results[[i]] <- rc # rw <- writeRaster(rc, outfiles[i], overwrite=TRUE)
  # print(outfiles[i])
}



for (i in 1988:2019){
  tmp = raster::stack(list.files(path = './mapbiomas/regrowth_amazon', pattern='2016', full.names=TRUE))
  }




cores <- 50
cl <- makeCluster(cores) #output should make it spit errors
registerDoParallel(cl)

############ Splitting a raster for easier handling

# The function spatially aggregates the original raster
# it turns each aggregated cell into a polygon
# then the extent of each polygon is used to crop
# the original raster.
# The function returns a list with all the pieces
# in case you want to keep them in the memory. 
# it saves and plots each piece
# The arguments are:
# raster = raster to be chopped            (raster object)
# ppside = pieces per side                 (integer)
SplitRas <- function(raster,ppside){
  h        <- ceiling(ncol(raster)/ppside)
  v        <- ceiling(nrow(raster)/ppside)
  agg      <- aggregate(raster,fact=c(h,v))
  agg[]    <- 1:ncell(agg)
  agg_poly <- rasterToPolygons(agg)
  names(agg_poly) <- "polis"
  r_list <- list()
  for(i in 1:ncell(agg)){
    e1          <- extent(agg_poly[agg_poly$polis==i,])
    r_list[[i]] <- crop(raster,e1)
  }
  return(r_list)
}

split_list = SplitRas(r2, 4)

foreach(i=1:length(split_list)) %dopar% {
  writeRaster(mask(split_list[i], Brazil))
}



############ Creating one unified dataframe from multiple raw Mapbiomas .tif files


# It intakes:
# file = the path to the directory (string)
# crop = whether we are subsetting the data into our region of interest or maintaining it whole (Boolean)
# It outputs:
# Converts into dataframes with the year as column
making_df = function(file, crop){

  files = list.files(path = file, pattern='\\.tif$', full.names=TRUE)   # obtain paths for all files 

  tmp_rasters = lapply(files, raster)

  # if we are subsetting the data into our region of interest
  coord_oi = c(xmin, xmax, ymin, ymax) #this specifies the coordinates of Paragominas.
  if(crop == T){
    e = as(extent(coord_oi), 'SpatialPolygons')
    crs(e) = "+proj=longlat +datum=WGS84 +no_defs"
    tmp_rasters = lapply(tmp_rasters, crop, e) # subsects all rasters to area of interest
  }

  tmp_dfs = lapply(tmp_rasters, as.data.frame, xy=T)

  merged_df = df_merge(tmp_dfs)

  colnames(merged_df) = str_sub(colnames(merged_df), start= -4)   # makes column names only "yyyy"

  merged_df = merged_df[order(merged_df$x),]   #order by longitude, so the pixels are separated by UTM zones.

  merged_df = cbind(merged_df, LongLatToUTM(merged_df$x, merged_df$y))   # converts lat, long coordinates to UTM

  return(merged_df)
}


############ DIAGNOSE CORRUPTED FILES

for (i in 1:12){
  location = locations[i]
  # the Amazon is divided in 12 parts, each with their own identifier
  # each location is an identifier.
  #for (location in locations){
    files_tmp <- list.files(path = './mapbiomas/regrowth_amazon', pattern=location, full.names=TRUE)   # obtain paths for all files for that location
    files_tmp <- sort(files_tmp)

    #dir.create(paste0('./regrowth_dataframes/', location))

    # obtain the raster file for all years within that location

    raster2 <- function(file, ...) {
    tryCatch(raster(file, ...), error = function(c) {
      c$message <- paste0(c$message, " (in ", file, ")")
      print(c)
    })
    }

    for (j in 1:length(files_tmp)){
      tmp <- raster2(files_tmp[j])
    }
}



