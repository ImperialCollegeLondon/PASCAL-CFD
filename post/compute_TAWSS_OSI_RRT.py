start_step = 5
end_step = 1000
wall_part_ID = 9
ensight.part.select_begin(wall_part_ID)
ensight.variables.activate("Wall_Shear")
ensight.variables.evaluate("RMS_WSS = RMS(Wall_Shear)")
ensight.part.select_begin(wall_part_ID)
ensight.variables.evaluate("TAWSS = TempMean(plist,RMS_WSS," + str(start_step) + "," + str(end_step) + ")")
ensight.part.select_begin(wall_part_ID)
ensight.variables.evaluate("TMEAN_WSS = TempMean(plist,Wall_Shear," + str(start_step) + "," + str(end_step) + ")")
ensight.part.select_begin(wall_part_ID)
ensight.variables.evaluate("RMS_TMEAN_WSS = RMS(TMEAN_WSS)")
ensight.part.select_begin(wall_part_ID)
ensight.variables.evaluate("OSI = 0.5*(1-(RMS_TMEAN_WSS/TAWSS))")
ensight.part.select_begin(wall_part_ID)
ensight.variables.evaluate("RRT = 1/((1-2*OSI)*TAWSS)")