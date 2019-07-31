## --------------------------------
##
## Script name: server.R
##
## Purpose of script: server stuff for the Select app
##
## Author: Shanaa Modchalingam
##
## Date created: 2019-07-15
##
## Email: s.modcha@gmail.com
##
## --------------------------------

server <- function(input, output) {
  

  source("analysisFunctions.R")
  
  ## Reactive stuff: We will use these later, like functions
  currentTrial <- reactiveValues(counterValue = 1, fitDF = NULL) 
  currentFile <- reactiveValues(filePath = NULL,  fileNum = 1,
                                df = NULL, dataList = list())
  allFiles <- reactiveValues(inFile = NULL)
  volumes <- c(Home = fs::path_home(), WD = '.', getVolumes()())
  
  # read in df
  loadFilePaths <- reactive({
    allFiles$inFile <- parseFilePaths(roots=c(volumes), input$files)
  })
  
  storeCurrentData <- reactive({
    
    currentFile$filePath <- as.character(allFiles$inFile$datapath[currentFile$fileNum])
    
    df <- fread(currentFile$filePath, stringsAsFactors = FALSE)
    
    # print(currentFile$filePath)
    
    #reset the counterValue
    currentTrial$counterValue <- 1
    
    #reset the fitDF
    currentTrial$fitDF <- NULL
    
    #reset dataList
    currentFile$dataList <- list()
    
    currentFile$df <- df
    })
  
  # df containing only the current trial
  currentTrialDF <- reactive({
    df <- currentFile$df %>%
      filter(trial_num == uniqueTrials()[currentTrial$counterValue])
    
    df
  })
  
  # returns a vector of the unique trial_num in current file
  uniqueTrials <- reactive({
    uniqueTrials <- currentFile$df$trial_num %>%
      unique()
    
    uniqueTrials
  })
  
  # a tibble with time, mousex, mousey, spline, speed, seleted, maxV column
  fitDF <- reactive({
    
    fitDF <- currentTrialDF() %>%
      select(time_s, mousex_px, mousey_px)
    
    # add a distance row
    fitDF$distance <- currentTrialDF() %>% 
      transmute(mousex_px = mousex_px - homex_px, mousey_px + homey_px) %>%
      apply(1, vector_norm)
    
    # fit a spline to the distance data
    fit_fun <- smooth.spline(x = fitDF$time_s, y = fitDF$distance, df = 7)
    
    # add a spline column
    fitDF$spline <- predict(fit_fun, fitDF$time_s)$y
    
    # add a speed column
    fitDF$speed <- predict(fit_fun, fitDF$time_s, deriv = 1)$y
    
    fitDF$selected <- 1
    fitDF$maxV <- 0
    
    fitDF$maxV[fitDF$time_s == filter(fitDF, speed == max(speed))[1, ]$time_s] <- 1
    
    
    currentTrial$fitDF <- fitDF
  })
  
  
  mergeAndSave <- reactive({
    pathToSave <- currentFile$filePath %>%
      str_sub(1, -5)
    
    pathToSave <- paste(pathToSave, "selected.csv", sep = "_")
    
    # concatenate the selected columns
    selected_df <- do.call(rbind, currentFile$dataList)
    
    # add the selected_df columns to df
    selected_df <- cbind2(currentFile$df, selected_df)
    
    # print(pathToSave)
    
    fwrite(selected_df, file = pathToSave)
  })
  
  
  ## ----
  ## Other backend stuff 
  
  # loading in a file
  shinyFileChoose(input, 'files', roots = volumes) # can do filetypes = c('', '.csv') here
  
  # the "Next" button
  # this will also add the current trial to the list
  observeEvent(input$nextButton, {
    
    validate(
      need(!is.null(currentFile$df), "Please load some data to select.")
    )
    
    ## add the df to list
    # print(currentTrial$counterValue)
    
    currentFile$dataList[[currentTrial$counterValue]] <- select(currentTrial$fitDF, selected, maxV)
    
    ## move to next trial
    
    if(currentTrial$counterValue == length(uniqueTrials())){
      currentTrial$counterValue <- 1
    }
    
    else {
      currentTrial$counterValue <- currentTrial$counterValue + 1
    }
    
  })
  
  # The "Previous" button
  observeEvent(input$prevButton, {
    
    validate(
      need(!is.null(currentFile$df), "Please load some data to select.")
    )

    # print(currentFile$dataList)
    
    # go to the last trial if the current trisl is "1"
    if(currentTrial$counterValue == 1){
      currentTrial$counterValue <- length(uniqueTrials())
    }
    
    else {
      currentTrial$counterValue <- currentTrial$counterValue - 1
    }
    
    # print(currentTrial$counterValue)
    
  })
  
  # The "Next File" button
  observeEvent(input$nextFileButton, {
    
    validate(
      need(!is.null(currentFile$df), "Please load some data to select.")
    )
    
    ## move to next file
    
    if(currentFile$fileNum == length(allFiles$inFile$datapath)){
      currentFile$fileNum <- 1
    }
    
    else {
      currentFile$fileNum <- currentFile$fileNum + 1
    }
    
    # print(currentFile$fileNum)
    
    # start selecting the new data
    storeCurrentData()
    
  })
  
  # The "Previous File" button
  observeEvent(input$prevFileButton, {
    
    validate(
      need(!is.null(currentFile$df), "Please load some data to select.")
    )
    
    
    # go to the last trial if the current trisl is "1"
    if(currentFile$fileNum == 1){
      currentFile$fileNum <- length(allFiles$inFile$datapath)
    }
    
    else {
      currentFile$fileNum <- currentFile$fileNum - 1
    }
    
    # print(currentFile$fileNum)
    
    # start selecting the new data
    storeCurrentData()
    
  })
  
  
  # After file is chosen, clicking this sets the currentFile$df to something
  observeEvent(input$runSelectButton, {
    validate(
      need(length(input$files) != 1,
           message = "Please load some data to select."))
    
    loadFilePaths()
    storeCurrentData()
  })
  
  observeEvent(input$saveButton, {
    validate(
      need(!is.null(currentFile$df), 
           message = "Please load some data to select."),
      need(length(currentFile$dataList) == length(uniqueTrials()), 
           message = "Finish selecting all data.")
    )
    
    mergeAndSave()
  })
  
  ## ----
  
  # output$contents <- renderTable({
  #   inFile <- parseFilePaths(roots=volumes, input$files)
  #   
  #   print(inFile)
  #   
  #   if(NROW(inFile)){
  #     df <- fread(as.character(inFile$datapath))
  #     head(df)
  #   }
  # })
  # 
  
  
  
  ## plots
  
  output$reachPlot <- renderPlot( {
    if(!is.null(currentFile$df)) {  
      # read in df
      df <- fitDF()
      
      p <- df %>%
        ggplot(aes(x = mousex_px, y = mousey_px)) +
        geom_point(size = 4, colour = "#337ab7", alpha = 0.5) +
        geom_point(data = filter(df, speed == max(speed))[1, ], 
                   size = 6, colour = "#8c3331", shape = 10, 
                   stroke = 2, alpha = .8) +
        scale_y_continuous(limits = c(-100, 1000),
                           name = "y-position") +
        scale_x_continuous(limits = c(-800, 800),
                           name = "x-position") +
        coord_fixed() +
        # annotate("text", x = -500, y = 900, size = 8,
        #          label = paste("Trial: ", currentTrial$counterValue)) +
        theme_minimal() +
        theme(text = element_text(size=20))
      
      p
    }
  })
    
  output$distPlot <- renderPlot( {
    if(!is.null(currentFile$df)) {  
      # read in df
      df <- fitDF()
      
      p <- df %>%
        ggplot(aes(x = time_s, y = distance)) +
        geom_point(size = 4, colour = "#337ab7", alpha = 0.5) +
        geom_line(aes(y = spline), alpha = 0.5, size = 2) + 
        geom_point(data = filter(df, speed == max(speed))[1, ], 
                   size = 8, colour = "#8c3331", shape = 10, 
                   stroke = 2, alpha = .8) +
        scale_y_continuous(name = "distance from home") +
        scale_x_continuous(name = "time") +
        theme_minimal() +
        theme(text = element_text(size=20))
      
      p
    }
  })
  
  output$velPlot <- renderPlot( {
    if(!is.null(currentFile$df)) {  
        
      # read in df
      df <- fitDF()
      
      p <- df %>%
        ggplot(aes(x = time_s, y = speed)) +
        geom_line(size = 3, alpha = .5) +
        geom_point(data = filter(df, speed == max(speed))[1, ], 
                   size = 8, colour = "#8c3331", shape = 10, 
                   stroke = 2, alpha = .8) +
        scale_y_continuous(name = "speed") +
        scale_x_continuous(name = "time") +
        theme_minimal() +
        theme(text = element_text(size=20))
      
      p
    }
  })
  
  
  
  ##  Text
  
  output$currentFileTxt <- renderText( {
    if(!is.null(currentFile$df)) {  
      paste("<font size=4>", currentFile$filePath, "  ", "<b>", currentFile$fileNum, 
            "/", length(allFiles$inFile$datapath), "</font> </b>",
            sep = "")
    }
    else {
      paste("Please choose files to select, and run selection.")
    }
  })
  
  output$currentTrialTxt <- renderText( {
    if(!is.null(currentFile$df)) {  
      paste("<b> <font size=4>", currentTrial$counterValue, "/", 
            length(uniqueTrials()), "</font> </b>",
            sep = "")
    }
  })
  
  output$trialsSelectedTxt <- renderText( {
    if(!is.null(currentFile$df)) {  
      
      numSelected <- length(Filter(Negate(is.null), currentFile$dataList))
      
      if(numSelected == length(uniqueTrials())) {
        paste("<b> <font color=\"#269148\" size=4>", numSelected, "/", 
              length(uniqueTrials()), "</font> </b>",
              sep = "")
      }
      else {
        paste("<b> <font size=4>", numSelected, "/", 
              length(uniqueTrials()), "</font> </b>",
              sep = "")
      }
    }
  })
  
}


##---- 
## Testing
# currentTrialDF <- fread("sampleData/stepwiseExp/1/1_aligned_traning_1.txt", stringsAsFactors = FALSE) %>%
#   filter(trial_num == 1)
# df <- currentTrialDF