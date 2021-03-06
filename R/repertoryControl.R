#' Check if we have the file or repertory
#' 
#' Create a repertory if needed of it, control all of the file which needed to be downloaded and 
#' place in the specifique repertory
#'
#' @param nameFile the name of the file or repertory
#' @param correctTaxo (binary) if we are in the correctTaxo function
#'
#' @return the path to the repertory, and the separator if correctTaxo is False
#'
#' @importFrom rappdirs user_data_dir
#' @importFrom utils download.file unzip

repertoryControl = function(nameFile = "", correctTaxo = FALSE){
  
  sep = ifelse(length(grep( "win", Sys.info()["sysname"], ignore.case = T )) != 0, "\\", "/")
  path = user_data_dir("BIOMASS")
  
  if( !dir.exists( path ) ){
    dir.create( path, recursive = T )
  }
  
  if( correctTaxo )
    return(paste(path, "correctTaxo.log", sep = sep))
  
  
  
  path1 = paste(path, nameFile, sep = sep)
  file_exists = F
  ############# if the repertory exists in the working directory
  if (file.exists(nameFile)){
    
    if (!file.exists(path1)){
      file.rename(nameFile, path1)
      message("Your repertory \"", nameFile, "\" has been moved in this repertory : ", path)
    } else {
      message("Your repertory \"", nameFile,"\" already exists in this path : ", path, " and in working directory. ",
              "You can delete the repertory ", nameFile, ".")
    }
    file_exists = T
    
  }
  
  
  ############# if the repertory exists in the designed repertory
  if (file.exists(path1))
    file_exists = T
  
  
  if (file_exists){
    ## If the file isn't a zip but exist
    if (length(grep("zip", nameFile)) == 0)
      return(list("path" = path1, "sep" = sep))
    
    
    ## If the file is a zip and exist and if it's a good size so it won't download again the file
    size = switch (nameFile,
      "E_zip" = 31202482,
      "CWD_zip" = 15765207
    )
    if ( file.info(path1)$size >= size ){
      unzip(path1, exdir = paste(path, strsplit(nameFile, "_")[[1]][1], sep = sep))
      return()
    }
  }
    
  
  
  ############# if the repertory doesn't exists anywhere
  ###### if the repertory asked is the World Climate
  if (nameFile == "wc2-5"){
    ### Get the BioClim param from the http://www.worldclim.org website
    bioData <- getData('worldclim', var='bio', res=2.5, path = path)
    unzip(paste(path1, "bio_2-5m_bil.zip", sep = sep), exdir = paste(path, "wc2-5", sep = sep), files = c("bio4.bil", "bio15.bil"))
    
    return(list("path" = path1, "sep" = sep))
  }
  
  
  
  ###### If nameFile isn't a zip file
  if (length(grep("zip", nameFile)) == 0){
    repertoryControl(nameFile = paste(nameFile, "zip", sep = "_"))
    return(list("path" = path1, "sep" = sep))
  }
  
  
  zip_url = switch (nameFile,
                    "CWD_zip" = "http://chave.ups-tlse.fr/pantropical_allometry/CWD.bil.zip",
                    "E_zip" = "http://chave.ups-tlse.fr/pantropical_allometry/E.bil.zip"
  )
  
  DEMzip <- download.file(zip_url, destfile = path1)
  unzip(path1, exdir = paste(path, strsplit(nameFile, "_")[[1]][1], sep = sep))
  return()
}