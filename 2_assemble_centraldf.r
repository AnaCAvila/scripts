

xmin <- min(df_tst$lon)
xmax <- max(df_tst$lon)
ymin <- min(df_tst$lat)
ymax = max(df_tst$lat)

  lulc = making_df('./mapbiomas/lulc', crop=T)
#  lulc = lulc[rownames(regrowth),] # subset only the coordinates that have some history of regrowth.
  saveRDS(lulc, "lulc_tst.rds")

e <- extent(xmin, xmax, ymin, ymax)

biomass_cropped <- crop(biomass,e)
biomass_df <- as.data.frame(biomass_cropped, xy=T)
biomass = cbind(biomass_df, LongLatToUTM(biomass_df$x, biomass_df$y))




####################################################################
########## ASSEMBLING THE DATASET ##########
####################################################################

########## REGROWTH ##########
# VARIABLES OBTAINED
# forest_age (time of last observed regrowth)

# INDEX #
# 100 anthropic
# 200 mature
# 300 secondary
# 400 deforestation
# 500 regrowth
# 600 secondary suppression


if (import_santoro == T){
  regrowth = cbind(regrowth[,1:25], regrowth[,(ncol(regrowth)-2):ncol(regrowth)])
  fire = cbind(fire[,1:28], fire[,(ncol(fire)-2):ncol(fire)])
  lulc = cbind(lulc[,1:28], lulc[,(ncol(lulc)-2):ncol(lulc)])
}

# select only years that have regrowth that hasn't been suppressed.
regrowth = df_tst

regrowth_last_instance = find_last_instance(regrowth, function(x) which(x == 503))
colnames(regrowth_last_instance) = "last_regrowth"

suppression_last_instance = find_last_instance(regrowth, function(x) which(600 <= x & x < 700))
colnames(suppression_last_instance) = "last_suppression"

regrowth_unsuppressed = cbind(regrowth[(ncol(regrowth)-2):ncol(regrowth)],regrowth_last_instance)
regrowth_unsuppressed = subset(regrowth_unsuppressed, regrowth_unsuppressed$last_regrowth-suppression_last_instance > 0)
regrowth_unsuppressed = cbind(regrowth_unsuppressed[,(ncol(regrowth_unsuppressed)-2):ncol(regrowth_unsuppressed)], 'forest_age' = max(regrowth_unsuppressed$last_regrowth)-regrowth_unsuppressed$last_regrowth)

#############################


# this removes any instance of -600 coming after -500
regrowth2 = regrowth[rownames(regrowth) %in% rownames(regrowth_unsuppressed), ] 
regrowth2[regrowth2 < 400 & regrowth2 >= 300] = 0 #secondary
regrowth2[100 <= regrowth2 & regrowth2 < 200] = 1 #anthropic
regrowth2[regrowth2 == 515] = 1 #anthropic - fixing typos
regrowth2[regrowth2 == 215] = 1 #anthropic - fixing typos

regrowth2[regrowth2 > 700 & regrowth2 < 800] <- NA # remove values that account for misclassification
regrowth2[regrowth2 > 400 & regrowth2 < 500] <- NA # remove values that account for urban areas/misclassification
regrowth2 = regrowth2[complete.cases(regrowth2),]

# now, we remove pixels that show unflagged moments of regrowth or repression.
tmp = cbind(NA, regrowth2[,3:(ncol(regrowth)-3)])
tmp2 = cbind(regrowth2[,3:(ncol(regrowth)-3)],NA)
tmp3 = tmp-tmp2

# -1 is evidence of unflagged repression
# 1 is unflagged regrowth
tmp3[tmp3 == 1] <- NA
tmp3[tmp3 == -1] <- NA
tmp3 = tmp3[,2:(ncol(tmp)-1)]
tmp3 = tmp3[complete.cases(tmp3),]


#selects for cleaned rows
regrowth = regrowth[rownames(regrowth) %in% rownames(tmp3), ] 



regrowth_last_instance = find_last_instance(regrowth, function(x) which(x == 503))
colnames(regrowth_last_instance) = "last_regrowth"

regrowth_cleaned = cbind(regrowth[(ncol(regrowth)-2):ncol(regrowth)],regrowth_last_instance)
regrowth_cleaned = cbind(regrowth_cleaned[,1:3], 'forest_age' = max(regrowth_cleaned$last_regrowth)-regrowth_cleaned$last_regrowth)

regrowth_cleaned$xy = paste0(regrowth_cleaned$zone, regrowth_cleaned$x, regrowth_cleaned$y)
biomass$xy = paste0(biomass$zone, biomass$x, biomass$y)

agb_forest_age = cbind(regrowth_cleaned, agbd = biomass[match(regrowth_cleaned$xy,biomass$xy),c("agbd")])
agb_forest_age = agb_forest_age[complete.cases(agb_forest_age[, ncol(agb_forest_age)]), ]

plot(agb_forest_age$forest_age, agb_forest_age$agbd)

# how to add distance to nearest mature forest?

sds = aggregate(agbd ~ forest_age, agb_forest_age, sd)
means = aggregate(agbd ~ forest_age, agb_forest_age, mean)
sum_stats = cbind(means, sds[,2])
colnames(sum_stats) = c('age', 'mean', 'sd')

ggplot(sum_stats,                               # ggplot2 plot with means & standard deviation
       aes(x = age,
           y = mean)) + 
  geom_errorbar(aes(ymin = mean - sd,
                    ymax = mean + sd)) +
  geom_point()




########## LAND USE ##########
# VARIABLES OBTAINED
# number of years under each land use tnrype
# time since last observation of each land use type

# INDEX ## 3 = forest
# 15 = pasture
# 39 = soy
# 46 = coffee
# 20 = sugar cane
# 41 = other annual crop
# 48 = other perennial crop

# total years under each land use type
lulc$pasture = rowSums(lulc == 15)
lulc$soy = rowSums(lulc == 39)
lulc$coffee = rowSums(lulc == 46)
lulc$sugar = rowSums(lulc == 20)
lulc$other_perennial = rowSums(lulc == 48)
lulc$other_annual = rowSums(lulc == 41)


# time since last observation of each land use type
ts_pasture = find_last_instance(lulc, function(x) which(x == 15))
lulc$ts_pasture = max(ts_pasture)-ts_pasture

ts_soy = find_last_instance(lulc, function(x) which(x == 39))
lulc$ts_soy = max(ts_soy)-ts_soy

#ts_coffee = find_last_instance(lulc, function(x) which(x == 46))
#ts_sugar = find_last_instance(lulc, function(x) which(x == 20))

ts_other_perennial = rowSums(lulc == 48)
lulc$ts_other_perennial = max(ts_other_perennial)-ts_other_perennial

ts_other_annual = rowSums(lulc == 41)
lulc$ts_other_annual = max(ts_other_annual)-ts_other_annual

lulc$xy = paste0(lulc$zone, lulc$x, lulc$y)

########## FIRE ##########

#count number of total fires
fire$num_fires = rowSums(fire[3:(ncol(fire)-3)])
fire_last_instance = find_last_instance(fire, function(x) which(x == 1))
colnames(fire_last_instance) = "last_burn"
fire = cbind(fire,fire_last_instance)
fire$last_burn = max(fire$last_burn) - fire$last_burn
fire$last_burn[fire$last_burn == max(fire$last_burn)] = NA
fire$xy = paste0(fire$zone, fire$x, fire$y)

central_df = cbind(agb_forest_age, last_burn = fire[match(agb_forest_age$xy,fire$xy),c("last_burn")])
central_df = cbind(central_df, num_fires = fire[match(central_df$xy,fire$xy),c("num_fires")])
central_df = cbind(central_df, pasture = lulc[match(central_df$xy,lulc$xy),c("pasture")])
central_df = cbind(central_df, soy = lulc[match(central_df$xy,lulc$xy),c("soy")])
central_df = cbind(central_df, other_perennial = lulc[match(central_df$xy,lulc$xy),c("other_perennial")])
central_df = cbind(central_df, other_annual = lulc[match(central_df$xy,lulc$xy),c("other_annual")])
central_df = cbind(central_df, tavg = temp[match(central_df$xy,temp$xy),c("mean")])
central_df = cbind(central_df, prec = prec[match(central_df$xy,prec$xy),c("mean")])
central_df$last_burn[is.na(central_df$last_burn)] = 1

central_df = lapply(central_df, as.numeric)

