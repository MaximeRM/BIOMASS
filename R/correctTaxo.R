#' Checking typos in names
#' 
#' This function corrects typos for a given taxonomic name using the Taxonomic 
#' Name Resolution Service (TNRS) via the Taxosaurus interface. 
#' This function has been adapted from the \code{tnrs} function from the taxize package (\code{\link[taxize]{tnrs}}).
#' 
#' @param genus Vector of genus to be checked. Alternatively, the whole species name (genus + species) or (genus + species + author) may be given (see example).
#' @param species Vector of species to be checked (same size as the genus vector).
#' @param Score Score of the matching (see http://tnrs.iplantcollaborative.org/instructions.html#match).
#' 
#' @return The function returns a dataframe with the corrected (or not) genera and species.
#' 
#' @references Boyle, B. et al. (2013). \emph{The taxonomic name resolution service: An online tool for automated standardization of plant names}. BMC bioinformatics, 14, 1.
#' @references Chamberlain, S. A. and Szocs, E. (2013). \emph{taxize: taxonomic search and retrieval in R}. F1000Research, 2.
#' 
#' @author Ariane TANGUY
#' @author Maxime REJOU-MECHAIN
#' 
#' @examples 
#' \dontrun{correctTaxo(genus = "Astrocarium", species="standleanum")}
#' \dontrun{correctTaxo(genus = "Astrocarium standleanum")}
#' 
#' @export
#' @importFrom data.table tstrsplit := data.table setkey chmatch fread fwrite setDF
#' @importFrom rappdirs user_data_dir
#' @importFrom httr content GET upload_file POST config
#' @importFrom jsonlite fromJSON
#' 


correctTaxo = function( genus, species = NULL, score = 0.5 ){
  
  ######## sub-function definition
  
  strsplit_NA = function(x, patern = " "){
    split = tstrsplit(x, patern)
    if (length( split ) == 1)
      return(list(split[[1]], as.character(NA)))
    return(split)
  }
  
  # if we have just the genus in input and in the query we already treated we have genus and species
  just_genus = function(out, taxo_already_have){
    Na_name = which(is.na(out$nameModified))
    index_genus = chmatch(out$genus, taxo_already_have$genus)[Na_name]
    
    out[Na_name, genusCorrected := taxo_already_have[index_genus, genusCorrected]]
    out[Na_name, nameModified := as.character(genus!=genusCorrected)]
    
    out[which( Na_name & taxo_already_have[index_genus, nameModified] == "TaxaNotFound" ), 
        nameModified := "TaxaNotFound"]
    return(out)
  }
  
  ########### preparation of log file
  
  path = repertoryControl(correctTaxo = T)
  
  if( !file.exists(path) ){
    file_exist = F
  } else {
    taxo_already_have = fread(file = path, colClasses = list(character=1:3))
    if (nrow(taxo_already_have) != 0){
      taxo_already_have[, c("genus", "species") := strsplit_NA(query)]
      taxo_already_have[, c("genusCorrected", "speciesCorrected") := strsplit_NA(outName)]
      setkey(taxo_already_have, query)
      file_exist = T
    } else { 
      del(taxo_already_have) 
      file_exist = F
    }
  }
  
  ########### Data preparation
  
  options(stringsAsFactors = F)
  
  genus = as.character(genus) 
  
  if(!is.null(species)){
    species = as.character(species)
    
    if (all(is.na(species)) & all(is.na(genus)))
        stop("Please supply at least one name", call. = FALSE)
    
    # Check the length of the inputs
    if(length(genus) != length(species))
      stop("You should provide two vectors of genus and species of the same length")
    
    # Create a dataframe with the original values
    oriData <- data.table(genus = genus, species = species, 
                          query = paste(genus, species), id = 1:length(genus))
    
  }else{
    
    if(all(is.na(genus)))
      stop("Please supply at least one name", call. = FALSE)
    
    # Create a dataframe with the original values
    oriData <- data.table(genus = sapply(strsplit(genus," "),"[",1), 
                          species = sapply(strsplit(genus," "),"[",2),
                          query = genus, id = 1:length(genus))
  }
  setkey(oriData, query)
  
  # Regroup unique query and filter the column species and genus if they are NA in the same time
  query = oriData[!(is.na(genus)&is.na(species)), query, by = query][, 2]
  query[, c("genus", "species") := strsplit_NA(query)]
  
  # Comparison between the taxo we already have and the taxo we want. We would have the unique taxo between the two.
  if(file_exist){
    if (exists("taxo_already_have")){
      query = query[!taxo_already_have, on = "query"]
      query = query[! ( is.na(species) & genus %in% taxo_already_have$genus) ]
    }
  }
  
  # End the function if we already have all the data needed
  if ( nrow(query) == 0 ){
    out = merge(oriData, 
                taxo_already_have[, .(query, nameModified, genusCorrected, speciesCorrected)], 
                all.x = T, by = "query")
    
    just_genus(out, taxo_already_have)
    return(setDF(out[order(id), c("genusCorrected", "speciesCorrected", "nameModified")]))
  }
  
  
  getpost <- "get"
  if(nrow(query) > 50)
    getpost <- "post"
  
  
  
  # If there is too much data, better submit it in separated queries
  splitby <- 30
  query[, slicedQu := rep(1:ceiling(length(query) / splitby), each = splitby)[1:length(query)] ]
  
  
  ########### sending and retrive the data from taxosaurus
  
  tc <- function(l) Filter(Negate(is.null), l)
  con_utf8 <- function(x) content(x, "text", encoding = "UTF-8")
  
  url <- "http://taxosaurus.org/submit"
  
  setkey(query, query)
  query[, c("matchedName", "score1") := list(as.character(NA), as.double(0))]
  
  for(s in query[, unique(slicedQu)])
  {
    x <- query[slicedQu == s, query]
    
    if(getpost == "get")
    {
      query2 <- paste(gsub(" ", "+", x, fixed = T), collapse = "%0A")
      args <- tc(list(query = query2))
      out <- GET(url, query = args)
      retrieve <- out$url
      
    } else {
      
      loc <- tempfile(fileext = ".txt")
      write.table(data.frame(x), file = loc, col.names = FALSE, row.names = FALSE)
      args <- tc(list(file = upload_file(loc), source = "iPlant_TNRS"))
      out <- POST(url, body = args, config(followlocation = 0))
      tt <- con_utf8(out)
      message <- fromJSON(tt, FALSE)[["message"]]
      retrieve <- fromJSON(tt, FALSE)[["uri"]]
    }
    
    print(paste("Calling", retrieve))
    
    timeout <- "wait"
    while (timeout == "wait") 
    {
      ss <- GET(retrieve)
      output <- fromJSON(con_utf8(ss), FALSE)
      if(!grepl("is still being processed", output["message"]) == TRUE) 
        timeout <- "done"
    }
    
    out <- tc(output$names)
    
    if(length(out)>0){
      submittedName = sapply(out, function(x) x$submittedName)
      receiveData = t( sapply(out, function(x) c( x[[2]][[1]]$matchedName, x[[2]][[1]]$score) ) )
      
      # Remove some parasite characters
      submittedName <- gsub("\"", "", submittedName)
      submittedName <- gsub("\r", "", submittedName)
      receiveData[,1] <- gsub("\"", "", receiveData[,1])
      receiveData[,1] <- gsub("\r", "", receiveData[,1])
      
      
      query[submittedName, ':='(matchedName = receiveData[,1], score1 = as.double(receiveData[, 2]))]
    }
  }
  
  ########### data analysis
  
  query[ , c( "nameModified", "outName" ) := list(as.character(TRUE), as.character(NA) )]
  query[, slicedQu := NULL]
  
  # If score ok
  query[score1 >= score, outName := matchedName]
  
  # If score non ok
  query[score1 < score, c("outName", "nameModified") := list(query, "NoMatch(low_score)")]
  
  # If no modified name value of nameModified as False
  query[!is.na(outName) & outName == query & nameModified != "NoMatch(low_score)", nameModified := as.character(FALSE)]
  
  
  
  
  query[, c("genusCorrected", "speciesCorrected") := strsplit_NA(outName)]
  
  # # If genera or species not found by TNRS
  # Genera
  filt <- query$nameModified==TRUE & is.na(query$genusCorrected) & !is.na(query$genus)
  query[filt, c("genusCorrected", "nameModified") := list(genus, "TaxaNotFound")]
  
  # Species
  filt <- (query$nameModified==TRUE | query$nameModified=="TaxaNotFound") & is.na(query$speciesCorrected) & !is.na(query$species)
  query[filt, speciesCorrected := species]
  query[filt & nameModified != "TaxaNotFound", nameModified := "SpNotFound"]
  
  
  
  
  
  
  
  ########## merge the data for the return
  out = merge(oriData, query, all.x = T)[ order(id), .(id, genus, nameModified, query, genusCorrected, speciesCorrected)]
  
  if(exists("taxo_already_have")){
    setkey(out, query)
    out[taxo_already_have, 
        ':='(nameModified = i.nameModified, genusCorrected = i.genusCorrected, speciesCorrected = i.speciesCorrected), on = "query"]
    just_genus(out, taxo_already_have)
  }
  
  
  ########### write all the new data on the log file created
  if (exists("taxo_already_have")){
    out1 = merge(taxo_already_have[, .(query, outName, nameModified, genus)], 
                 query[, .(query, genus, outName, nameModified)], by = "genus", all = T)
    
    out1[is.na(query.x), query.x := "a"][is.na(query.y), query.y := "a"]
    nchr = nchar( out1[, query.x] ) > nchar( out1[, query.y] )
    out1[nchr, ':='("query" = query.x, "outName" = outName.x, "nameModified" = nameModified.x)]
    out1[!nchr, ':='("query" = query.y, "outName" = outName.y, "nameModified" = nameModified.y)]
  } else {out1 = query}
  
  fwrite(out1[, .(outName, nameModified), by=query], file = path)
  
  
  return(setDF(out[order(id), .(genusCorrected, speciesCorrected, nameModified)]))
  
}