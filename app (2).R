
################################################################################
## setup 
################################################################################

library(quantreg)
library(scales)
library(ggbeeswarm)
library("shinydashboard")
library(rnaturalearthdata)
library(rnaturalearth)
library("tidyverse")
library("shiny")
library("haven")
library("ggplot2")
library("plotly")
library("lubridate")
library("DT")
library("fontawesome")
library("htmlwidgets")
library("stringr")
library("ggbeeswarm")
library("bslib")
library("readxl")
library("countrycode")
library("shinyWidgets")
library("zoo")
library("flexdashboard")
library("reshape2")
library("ggpubr")
library("car")
library("DBI")
library("odbc")
library("openxlsx")
library("zoo")
library("shinyjs")
library("shinycssloaders")
library("shinyalert")
library("writexl")
library(jsonlite)

# setwd("C:/Users/l.taylor/OneDrive - Medpace/Documents/Github/Siteengine")

myconn <- DBI::dbConnect(odbc::odbc(),
                         "FeasibilityRead",
                         Warehouse = "CLINOPS_ADHOC",
                         Database = "SOURCE")

aiconn <- DBI::dbConnect(odbc::odbc(),
                         "AIrole",
                         Warehouse = "INFORMATICS_AI")






################################################################################
## data 
################################################################################

load('environment.RData')
world <- ne_countries(scale = "medium", returnclass = "sf")
medidata_disease_bridge = read_excel('medidata_disease_bridge.xlsx'
                                     ,sheet='therapeutic')
medidata_indication_bridge = read_excel('medidata_disease_bridge.xlsx'
                                     ,sheet='indication')
defaultstartup = read_excel('drug start up timelines_30jan2025.xlsx') %>% 
  select(iso3c = ISO3C
         ,default = Default_Startup) %>% 
  distinct() %>% 
  filter(!is.na(iso3c)
         ,!is.na(default)) %>% 
  group_by(iso3c) %>% 
  summarize(default = median(default, na.rm=T)) %>% 
  ungroup()




################################################################################
## ui
################################################################################


ui = dashboardPage(
  dashboardHeader(title = tags$div(
    style = 'line-height: 0.75;'
    ,HTML(paste0(
      "<span style='color: #66ca98; font-size: 18px; font-family: Arial; font-weight: bold;'>in</span><span style='color: #ffffff; font-size: 18px; font-family: Arial; font-weight: bold;'>SitE<br></span>"
      ,"<span style='color: #66ca98; font-size: 18px; font-family: Arial;font-weight: bold;'>in</span><span style='color: #6cca98; font-size: 18px; font-family: Arial; '>formatics </span>"
      ,"<span style='color: #ffffff; font-size: 18px; font-family: Arial; font-weight: bold;'>Sit</span><span style='color: #ffffff; font-size: 18px; font-family: Arial;'>e </span>"
      ,"<span style='color: #ffffff; font-size: 18px; font-family: Arial; font-weight: bold;'>E</span><span style='color: #ffffff; font-size: 18px; font-family: Arial;'>ngine</span>"
    ))
  ))
  

  ###########################
  ## navbar options
  ###########################
  ,dashboardSidebar(
    sidebarMenu(
      id='tabs'
      ,menuItem("Algorithm Settings"
               ,tabName="algotab"
               ,icon=icon("brain"))
      
      ,menuItem("Site Selection"
               ,tabName="siteselecttab"
               ,icon=icon("filter"))
      
      ,menuItem("Projections"
                ,tabName="projectionstab"
                ,icon=icon("chart-line")))
    ,div(
      style = 'position: absolute; bottom: 20px; width: 100%;'
      ,actionButton("save_session_btn"
                    , "Save Session"
                    , class = "load-btn-primary"
                    , style = "width: 90%; margin-left: 5%; margin-bottom: 10px;")
      ,actionButton("load_session_btn"
                    , "Load Session"
                    , class = "load-btn-primary"
                    , style = "width: 90%; margin-left: 5%;")))
  
  
  
  
  
  ###########################
  ## body
  ###########################
  ,dashboardBody(
    
    ###########################
    ## css formatting
    ###########################
    tags$head(
      tags$style(HTML("
      .checkbox label{color:#002554; font-family: Arial;}
      .control-label{color:#002554; font-family: Arial;}
      .box-title{font-weight:bold;}
      .box.box-solid.box-primary>.box-header{color: #002554; background: #d9d8d6;}
      .box.box-solid.box-primary{border: none !important;}
      .box-body{color: #002554;}
      .nav-tabs-custom{font-weight:bold; color: #002554; font-family: Arial;}
      .tab-content{color: #002554; font-weight:normal; font-family: Arial;}
      .skin-blue .main-header .navbar{background-color: #002554;}
      .skin-blue .main-header .logo{background-color: #002554;}
      .skin-blue .main-sidebar {background-color: #002554; !important;}
      .skin-blue .main-sidebar .sidebar .sidebar-menu > li > a {color: #ffffff;}
      .skin-blue .main-sidebar .sidebar .sidebar-menu > li.active > a {background-color: #6cca98; color: #002554;}
      .skin-blue .sidebar .shiny-download-link {color: #002554;}
      .main-header .logo {height: auto !important; padding: 10px; border-bottom: 3px solid #002554 !important;}
      
      .btn-primary {
        background-color: #88898b !important;
        border-color: #88898b !important;
        color: white !important;
      }
      
      .btn-primary:hover {
        background-color: #002554 !important;
        border-color: #002554 !important;
        color: white !important;
      }
      
      .btn-primary.active {
        background-color: #6cca98 !important;
        border-color: #6cca98 !important;
        color: white !important;
      }
      
      .btn-outline-primary {
        background-color: #ecf0f1 !important;
        border-color: #bdc3c7 !important;
        color: white !important;
      }
      
      .btn-outline-primary:hover {
        background-color: #d5dbdb !important;
        border-color: #95a5a6 !important;
        color: white !important;
      }
      
      .load-btn-primary {
        background-color: #d8d9d6 !important;
        border-color: #d8d9d6 !important;
        color: #002554 !important;
      }
      
      .load-btn-primary:hover {
        background-color: #6cca98 !important;
        border-color: #6cca98 !important;
        color: #002554 !important;
      }
      
      .load-btn-primary.active {
        background-color: #6cca98 !important;
        border-color: #6cca98 !important;
        color: #002554 !important;
      }
      
      .load-btn-outline-primary {
        background-color: #ecf0f1 !important;
        border-color: #bdc3c7 !important;
        color: #002554 !important;
      }
      
      .load-btn-outline-primary:hover {
        background-color: #ffffff !important;
        border-color: #ffffff !important;
        color: #002554 !important;
      }
      
      .shiny-notification {
        position: fixed !important;
        top: 50% !important;
        left: 50% !important;
        transform: translate(-50%, -50%) !important;
        width: 300px !important;
      }
      
      #hospital_selector {
        height: 125px !important;
        overflow-y: auto;
      }
                      ")))
    
    
    
    
    
    ###########################
    ## tabs
    ###########################
    ,tabItems(
      
      ###########################
      ## site search
      ###########################
      tabItem(tabName="algotab"
              ,fluidRow(style='height: 60vh;'
                        ,column(
                        width = 4
                        
                        , selectInput(
                          'selectedcountry'
                          ,'Country(ies):'
                          ,choices = c('', sort(unique(world$admin)))
                          ,selected = ''
                          ,width = '100%'
                          ,multiple = T)
                        
                        , selectizeInput(
                          'selecteddiseases'
                          , 'Indication(s):'
                          , choices = diseaselist
                          , multiple = T
                          ,width = '100%')
                        
                        , fluidRow(tabBox(
                          id = 'custombox'
                          , title = HTML('<i>Optional</i>')
                          
                          , tabPanel(title = 'Medpace'
                                     ,textAreaInput('internalcodes'
                                                    ,HTML('Custom MEDP Studycodes:<br><i>..line separated</i>')
                                                    )
                                     ,textInput('medpcustomdescription'
                                                ,label = 'Plain English Description of these studies'
                                                ,value = 'benchmarking'))
                          
                          , tabPanel(title = 'Citeline'
                                     ,textAreaInput('citelinecodes'
                                                    ,HTML('Custom Citeline TrialIDs:<br><i>..line separated</i>')
                                                    )
                                     ,textInput('citelinecustomdescription'
                                                ,label = 'Plain English Description of these studies'
                                                ,value = 'external benchmarking'))
                          
                          , tabPanel(title = 'Competition'
                                     ,textAreaInput('competitioncodes'
                                                    ,HTML('Competing Citeline TrialIDs:<br><i>..line separated</i>')
                                     ))
                          
                          , tabPanel(title = 'Medidata'
                                   , fileInput(
                                     'medidataindication'
                                     , 'Medidata Upload:'
                                     , accept=c("xlsx")
                                     , multiple = F)
                                   
                                   ,textInput('medidatacustomdescription'
                                              ,label = 'Plain English Description of these studies'
                                              ,value = 'semi-specific benchmarking'))
                          
                          , width = 12))
                          ,box(
                              HTML("<u>After</u> finishing any custom entries, please click this button:<br><i>If you do not have any custom entries, ignore this button</i>")
                            ,br()
                              ,actionButton('submit_custom', 'Submit Custom Entries')
                            ,width = 12)
                        
                        , actionButton('collate', 'Collate Data', width='80%'))
                        
                        ,column(
                          width = 3
                          ,withSpinner(uiOutput('show_voiselect')
                                         ,type = 7
                                         ,color = '#6cca98'))
                        ,column(
                          width = 3
                          ,uiOutput('voi_sliders'))
                        
                        ,column(
                          width = 2
                          ,uiOutput('showcalculatebutton')))

              )
      
      ###########################
      ## site analysis & select
      ###########################
      ,tabItem('siteselecttab'
               ,layout_sidebar(
                 sidebar = sidebar(
                   width = '25%'
                   ,position = 'left'
                   ,uiOutput('clusteroptions')
                   ,prettyRadioButtons('indicationrequire'
                                       ,'Is indication experience required?'
                                       ,choices = c('Not required'
                                                    ,'Required'
                                                    ,'Required with MEDP')
                                       ,selected = 'Not required'
                                       ,shape = 'curve'
                                       ,inline = T)
                   ,prettyCheckboxGroup('phaserequire'
                                   ,'Are there specific phase(s) experience required?'
                                   ,choices = c('I','II','III','IV')
                                   ,shape = 'curve'
                                   ,inline = T)
                   ,conditionalPanel(condition = "input.phaserequire.length > 0"
                                     ,prettyRadioButtons('phasesourcerequire'
                                                         ,'Where is phase experience required?'
                                                         ,choices = c('Any source'
                                                                      ,'Medpace')
                                                         ,selected = 'Any source'
                                                         ,shape = 'curve'
                                                         ,inline = T))
                   ,box(
                         width = 12
                         ,status = 'primary'
                         ,title="Pending Sites"
                         ,div(style = "height: 150px; overflow-y: auto; border: 1px solid #ccc; padding: 10px; width: 100%;"
                           ,uiOutput('TempSelectedSites'))
                            ,br()
                            ,actionButton('submitsites', 'Submit Sites'))
                       ,div(style = "height: 250px; overflow-y: auto; border: 1px solid #ccc; padding: 10px; width: 100%;"
                              ,uiOutput("scrollable_list"))
                       ,plotOutput('siteTotal', height='10vh', width='100%')
                       ,actionButton('help_btn'
                                              ,icon = icon('question-circle')
                                              ,label = 'Definitions'
                                              ,class = 'btn-link btn-sm'
                                              ,width = '100%'))
                 
                 ,layout_sidebar(
                 sidebar = sidebar(
                   position = 'right'
                   ,collapsible = T
                   ,width = '20%'
                   ,uiOutput('voifiltering')
                   ,uiOutput('voislider_ui'))
                 
               ,column(width = 12
                       ,fluidRow(
                         column(width = 2
                                         ,div(style = 'height: 5vh;', plotOutput('medp_experience_avg', height='5vh', width='100%'))
                                         ,div(style = 'height: 20vh;', card(full_screen = T
                                                                            ,card_body(plotlyOutput('medp_experience', height='20vh', width='100%')))))
                                 ,column(width = 2
                                         ,div(style = 'height: 5vh;', plotOutput('ind_percentile_avg', height='5vh', width='100%'))
                                         ,div(style = 'height: 20vh;', card(full_screen = T
                                                                            ,card_body(plotlyOutput('ind_percentile', height='20vh', width='100%')))))
                                 ,column(width = 2
                                         ,div(style = 'height: 5vh;', plotOutput('medp_startup_avg', height='5vh', width='100%'))
                                         ,div(style = 'height: 20vh;', card(full_screen = T
                                                                            ,card_body(plotlyOutput('medp_startup', height='20vh', width='100%')))))
                                ,column(width = 2
                                        ,div(style = 'height: 5vh;', plotOutput('ind_studies_avg', height='5vh', width='100%'))
                                        ,div(style = 'height: 20vh;', card(full_screen = T
                                                                           ,card_body(plotlyOutput('ind_studies', height='20vh', width='100%')))))
                                 ,column(width = 2
                                         ,div(style = 'height: 5vh;', plotOutput('customlabel', height='5vh', width='100%'))
                                         ,div(style = 'height: 20vh;', card(full_screen = T
                                                                            ,card_body(plotlyOutput('custom_plot', height='20vh', width='100%')))))
                                ,column(width = 2
                                        ,div(style = 'height: 25vh;', uiOutput('customplotvoi', height='25vh', width='100%')))
                                )
                       ,br()
                       ,fluidRow(tabBox(
                         id = 'sitesbox'
                         ,width = 12
                         ,tabPanel(
                           title = 'Sites'
                           ,DTOutput('clustertable'))
                         ,tabPanel(
                           title = 'Map')))
                       ))))
      
      ###########################
      ## projections
      ###########################
      ,tabItem('projectionstab'
               ,layout_sidebar(
                 sidebar = sidebar(
                   width = '25%'
                   ,position = 'left'
                   ,fluidRow(htmlOutput('warningtext'))
                   ,uiOutput('studypsm_output')
                   ,uiOutput('psm_input')
                   ,numericInput('goal'
                                 ,label = 'Target Enrolled for this country'
                                 ,value = 1
                                 ,min = 1
                                 ,max = NA
                                 ,step = 1)
                   ,actionButton('prepsimulation', 'Prepare Simulation')
                   ,uiOutput('rangecountry')
                   ,uiOutput('simulationranges')
                   ,uiOutput('iterationinput')
                   ,uiOutput('simulatebutton'))
               ,fluidRow(column(
                                width=12
                                ,plotOutput('enrollmentcurve')))
               ,fluidRow(DTOutput('assumptionstable'))))

    )))





################################################################################
## server
################################################################################

server = function(input, output, session){
  
  
##########################
## saving / loading
##########################
  
  ## holding spot to save reactive vals
  app_data <- reactiveVal(list())
  
  ## Get list of saved sessions
  get_saved_sessions <- reactive({
    files <- list.files(pattern = "^session_.*\\.RData$")
    if(length(files) > 0) {
      # Extract session names (remove "session_" prefix and ".RData" suffix)
      session_names <- gsub("^session_", "", gsub("\\.RData$", "", files))
      return(session_names)
    }
    return(character(0))
  })
  
  ## saving and loading past app data
  # Save data whenever any reactiveVal changes
  observe({
    current_data <- list(
      studysites = if(!is.null(studysites())) studysites() else NULL,
      selected_hospitals = if(!is.null(selected_hospitals())) selected_hospitals() else NULL,
      medpcustom = if(!is.null(medpcustom())) medpcustom() else NULL,
      citelinecustom = if(!is.null(citelinecustom())) citelinecustom() else NULL,
      citelinecompetition = if(!is.null(citelinecompetition())) citelinecompetition() else NULL,
      medidataindication = if(!is.null(medidataindication())) medidataindication() else NULL,
      clusterresults = if(!is.null(clusterresults())) clusterresults() else NULL,
      clustersummary = if(!is.null(clustersummary())) clustersummary() else NULL,
      interpretation = if(!is.null(interpretation())) interpretation() else NULL,
      enrollprojections = if(!is.null(enrollprojections())) enrollprojections() else NULL,
      siteassumptions = if(!is.null(siteassumptions())) siteassumptions() else NULL,
      voi = if(!is.null(voi())) voi() else NULL,
      euclidean_data = if(!is.null(euclidean())) euclidean() else NULL,
      # Add input values that should be preserved
      input_data = list(
        selectedcountry = input$selectedcountry,
        selecteddiseases = input$selecteddiseases,
        voiselection = input$voiselection,
        selectedclusters = input$selectedclusters,
        filteredcountries = input$filteredcountries,
        indicationrequire = input$indicationrequire,
        phaserequire = input$phaserequire,
        phasesourcerequire = input$phasesourcerequire,
        goal = input$goal,
        internalcodes = input$internalcodes,
        citelinecodes = input$citelinecodes,
        competitioncodes = input$competitioncodes,
        medpcustomdescription = input$medpcustomdescription,
        citelinecustomdescription = input$citelinecustomdescription,
        medidatacustomdescription = input$medidatacustomdescription
      ),
      # Add status flags
      status_flags = list(
        voiselectorappear = voiselectorappear(),
        interpretationready = interpretationready(),
        simulationready = simulationready()
      ),
      timestamp = Sys.time()
    )
    
    app_data(current_data)
  })
  
##########################
## save session with name
##########################
  
  # Add text input for session name in sidebar
  observeEvent(input$save_session_btn, {
    showModal(modalDialog(
      title = "Save Session",
      textInput("session_name", "Enter session name:", 
                value = paste0("session_", format(Sys.time(), "%Y%m%d_%H%M%S"))),
      footer = tagList(
        modalButton("Close"),
        actionButton("confirm_save", "Save", class = "load-btn-primary")
      )
    ))
  })
  
  # Handle save confirmation
  observeEvent(input$confirm_save, {
    req(input$session_name)
    
    # Clean the session name (remove invalid characters)
    clean_name <- gsub("[^A-Za-z0-9_-]", "_", input$session_name)
    filename <- paste0("session_", clean_name, ".RData")
    
    tryCatch({
      current_data <- app_data()
      save(current_data, file = filename)
      showNotification(paste("Session saved as:", clean_name), type = "success")
      removeModal()
    }, error = function(e) {
    })
  })
  
##########################
## load session from list
##########################
  
  # Load session handler
  observeEvent(input$load_session_btn, {
    sessions <- get_saved_sessions()
    
    if(length(sessions) == 0) {
      showNotification("No saved sessions found", type = "warning")
      return()
    }
    
    showModal(modalDialog(
      title = "Load Session",
      selectInput("session_to_load", "Select session to load:", 
                  choices = sessions, selected = NULL),
      footer = tagList(
        modalButton("Close"),
        actionButton("confirm_load", "Load", class = "load-btn-primary")
      )
    ))
  })
  
  # Handle load confirmation
  observeEvent(input$confirm_load, {
    req(input$session_to_load)
    
    filename <- paste0("session_", input$session_to_load, ".RData")
    
    tryCatch({
      load(filename, envir = environment())
      
      # Restore all data (same as before)
      if(!is.null(current_data$studysites)) studysites(current_data$studysites)
      if(!is.null(current_data$selected_hospitals)) selected_hospitals(current_data$selected_hospitals)
      if(!is.null(current_data$medpcustom)) medpcustom(current_data$medpcustom)
      if(!is.null(current_data$citelinecustom)) citelinecustom(current_data$citelinecustom)
      if(!is.null(current_data$citelinecompetition)) citelinecompetition(current_data$citelinecompetition)
      if(!is.null(current_data$medidataindication)) medidataindication(current_data$medidataindication)
      if(!is.null(current_data$clusterresults)) clusterresults(current_data$clusterresults)
      if(!is.null(current_data$clustersummary)) clustersummary(current_data$clustersummary)
      if(!is.null(current_data$interpretation)) interpretation(current_data$interpretation)
      if(!is.null(current_data$enrollprojections)) enrollprojections(current_data$enrollprojections)
      if(!is.null(current_data$siteassumptions)) siteassumptions(current_data$siteassumptions)
      if(!is.null(current_data$voi)) voi(current_data$voi)
      
      # Restore status flags
      if(!is.null(current_data$status_flags$voiselectorappear)) voiselectorappear(current_data$status_flags$voiselectorappear)
      if(!is.null(current_data$status_flags$interpretationready)) interpretationready(current_data$status_flags$interpretationready)
      if(!is.null(current_data$status_flags$simulationready)) simulationready(current_data$status_flags$simulationready)
      
      # Restore input values
      if(!is.null(current_data$input_data)) {
        input_data <- current_data$input_data
        if(!is.null(input_data$selectedcountry)) {
          updateSelectInput(session, "selectedcountry", selected = input_data$selectedcountry)
        }
        if(!is.null(input_data$selecteddiseases)) {
          updateSelectizeInput(session, "selecteddiseases", selected = input_data$selecteddiseases)
        }
        if(!is.null(input_data$voiselection)) {
          updateSelectInput(session, "voiselection", selected = input_data$voiselection)
        }
        if(!is.null(input_data$selectedclusters)) {
          updatePickerInput(session, "selectedclusters", selected = input_data$selectedclusters)
        }
        if(!is.null(input_data$filteredcountries)) {
          updateSelectInput(session, 'filteredcountries', selected = input_data$filteredcountries)
        }
        if(!is.null(input_data$indicationrequire)) {
          updatePrettyRadioButtons(session, "indicationrequire", selected = input_data$indicationrequire)
        }
        if(!is.null(input_data$phaserequire)) {
          updatePrettyCheckboxGroup(session, "phaserequire", selected = input_data$phaserequire)
        }
        if(!is.null(input_data$phasesourcerequire)) {
          updatePrettyRadioButtons(session, "phasesourcerequire", selected = input_data$phasesourcerequire)
        }
        if(!is.null(input_data$goal)) {
          updateNumericInput(session, "goal", value = input_data$goal)
        }
        if(!is.null(input_data$internalcodes)) {
          updateTextAreaInput(session, "internalcodes", value = input_data$internalcodes)
        }
        if(!is.null(input_data$citelinecodes)) {
          updateTextAreaInput(session, "citelinecodes", value = input_data$citelinecodes)
        }
        if(!is.null(input_data$competitioncodes)) {
          updateTextAreaInput(session, "competitioncodes", value = input_data$competitioncodes)
        }
        if(!is.null(input_data$medpcustomdescription)) {
          updateTextInput(session, "medpcustomdescription", value = input_data$medpcustomdescription)
        }
        if(!is.null(input_data$citelinecustomdescription)) {
          updateTextInput(session, "citelinecustomdescription", value = input_data$citelinecustomdescription)
        }
        if(!is.null(input_data$medidatacustomdescription)) {
          updateTextInput(session, "medidatacustomdescription", value = input_data$medidatacustomdescription)
        }
      }
      
      showNotification("Session loaded successfully!", type = "success")
      removeModal()
      
    }, error = function(e) {
    })
  })

##########################
## navigation
##########################

## when user selects interpret, navigate to other tab
observeEvent(input$calculate, updateTabItems(session, "tabs", "siteselecttab"))

##########################
## indication filter
##########################
  
## filter disease to selected indication
filteredstudydisease = reactive({
  studydisease %>% 
    filter(INDICATION %in% input$selecteddiseases)
})




##########################
## therapeutic filter
##########################

## filter disease to therapeutic of selected indication
filteredstudytherapeutic = reactive({
  
  therapeutic = unique(subset(studydisease$CATEGORY
                              ,studydisease$INDICATION %in% input$selecteddiseases))
  studydisease %>% 
    filter(CATEGORY %in% therapeutic)
})




##########################
## medidata indication auto
##########################

medidataindication_auto = reactive({
  req(input$selecteddiseases
      ,input$selectedcountry)
  
  selectedcountry = countrycode(input$selectedcountry
                                ,origin='country.name'
                                ,destination='iso3c')
  
  diseasebridge = 
    medidata_indication_bridge %>% 
    filter(Medpace_Indication %in% input$selecteddiseases)
  
  medidatafullindication %>% 
    filter(group == 'indication'
           ,subgroup %in% diseasebridge$Medidata_Indication
           ,iso %in% selectedcountry) %>% 
    group_by(FINAL_NAME
             ,iso) %>% 
    summarize(percentile = max(percentile, na.rm=T)
              ,studies = max(studies, na.rm=T)) %>% 
    ungroup()
  
})


##########################
## medidata therapeutic auto
##########################

medidatatherapeutic_auto = reactive({
  req(input$selecteddiseases
      ,input$selectedcountry)
  
  selectedcountry = countrycode(input$selectedcountry
                                ,origin='country.name'
                                ,destination='iso3c')
  
  therapeutic = unique(subset(studydisease$CATEGORY
                              ,studydisease$INDICATION %in% input$selecteddiseases))
  
  diseasebridge = 
    medidata_disease_bridge %>% 
    filter(CATEGORY %in% therapeutic)
  
  medidatafulltherapeutic %>% 
    filter(group == 'therapeutic'
           ,subgroup %in% diseasebridge$`Medidata Therapeutic`
           ,iso %in% selectedcountry) %>% 
    group_by(FINAL_NAME
             ,iso) %>% 
    summarize(percentile = max(percentile, na.rm=T)
              ,studies = max(studies, na.rm=T)) %>% 
    ungroup()
  
})




##########################
## medidata indication
##########################

## placeholder
medidataindication = reactiveVal(
  data.frame(FINAL_NAME = NA
             ,ISO = NA
             ,percentile = NA
             ,studies = NA
             ,stringsAsFactors = F)
)

## medidata uploads
observeEvent(input$submit_custom, {
  
  if(!is.null(input$medidataindication)){
  selectedcountry = countrycode(input$selectedcountry
                                ,origin='country.name'
                                ,destination='iso3c')
  
  df = read_excel(input$medidataindication$datapath
                  ,sheet = 'Site Metrics'
                  ,skip = 2) %>% 
    select(`Site ID`
           ,`Site Name`
           ,`Country`
           ,percentile = `Industry Enrollment Percentile (%)`
           ,studies = `Industry Studies`) %>% 
    mutate(ISO = countrycode(Country
                             ,origin = 'country.name'
                             ,destination = 'iso3c')
           ,percentile = as.numeric(percentile)
           ,studies = as.integer(studies)) %>% 
    left_join(medidatabridge 
              ,by="Site ID") %>% 
    mutate(FINAL_NAME = coalesce(FINAL_NAME, `Site Name`)) %>% 
    arrange(FINAL_NAME
            ,ISO
            ,desc(percentile)) %>% 
    group_by(FINAL_NAME
             ,ISO) %>% 
    slice_head(n=1) %>% 
    ungroup() %>% 
    select(-c(`Site Name`
              ,`Site ID`
              ,Country))%>% 
    filter(!is.na(percentile)
           ,ISO %in% selectedcountry)
  
  
  medidataindication(df)
  }else{}
  
})

##########################
## medp custom codes
##########################

medpcustom = reactiveVal(
  data.frame(UNIQUEKEY = NA
             ,stringsAsFactors = F)
)

observeEvent(input$submit_custom, {
  
  if(is.null(input$internalcodes) | nchar(trimws(input$internalcodes)) == 0){
  }else{
  
    ids = strsplit(input$internalcodes, '\n')[[1]]
    ids = trimws(ids)
    ids = ids[nzchar(ids)]
    
    df = data.frame(UNIQUEKEY = ids, stringsAsFactors = F)
    
    medpcustom(df)
  }
    
  })



##########################
## citline custom codes
##########################

citelinecustom = reactiveVal(
  data.frame(TRIALID = NA
             ,stringsAsFactors = F)
)

observeEvent(input$submit_custom, {
  
  if(is.null(input$citelinecodes) | nchar(trimws(input$citelinecodes)) == 0){
  }else{
  
  ids = strsplit(input$citelinecodes, '\n')[[1]]
  ids = trimws(ids)
  ids = ids[nzchar(ids)]
  
  df = data.frame(TRIALID = ids, stringsAsFactors = F)
  
  citelinecustom(df)
  
  }
  
})

##########################
## citeline competition codes
##########################

citelinecompetition = reactiveVal(
  data.frame(TRIALID = NA
             ,stringsAsFactors = F)
)

observeEvent(input$submit_custom, {
  
  if(is.null(input$competitioncodes) | nchar(trimws(input$competitioncodes)) == 0){
  }else{
  
  ids = strsplit(input$competitioncodes, '\n')[[1]]
  ids = trimws(ids)
  ids = ids[nzchar(ids)]
  
  df = data.frame(TRIALID = ids, stringsAsFactors = F)
  
  citelinecompetition(df)
  
  }
  
})

## update custom submit button
observeEvent(input$submit_custom, {
  
  updateActionButton(session
                     ,"submit_custom"
                     ,label = "Submitted"
                     ,icon = icon("square-check"))
  
})


##########################
## studysites
##########################

## based on selected disease, pull indication & THERAPEUTIC studies & enr performance
studysites = reactiveVal()

## placeholder for not showing voi selector
voiselectorappear = reactiveVal(FALSE)

observeEvent(input$collate, {
  if(is.null(input$selectedcountry) | is.null(input$selecteddiseases)){
    studysites(data.frame(Message = "Please select a country and at least 1 indication and press 'Collate' button again"))
  }else{
    
    # Show progress bar
    shinyWidgets::progressSweetAlert(
      session = session, 
      id = "collateprogress",
      title = "Processing data...",
      display_pct = TRUE, 
      value = 0
    )
  
    
  studysites(NULL)
  
  # Update progress at key points
  shinyWidgets::updateProgressBar(
    session = session, 
    id = "collateprogress", 
    value = 10, 
    title = "Accepting user inputs..."
  )
    
  iso = countrycode(input$selectedcountry
                    ,origin = 'country.name'
                    ,destination = 'iso3c')
  
  ## consolidate for naming purposes
  if(length(input$selecteddiseases)==1){
  ind = input$selecteddiseases
  }else{
    ind = paste(input$selecteddiseases, collapse=' & ')
    }
  
  ther = unique(subset(studydisease$CATEGORY
                       ,studydisease$INDICATION %in% input$selecteddiseases))
  
  if(length(ther)==1){
    ther = ther
  }else{
    ther = paste(ther, collapse=" & ")
  }
  
  # Update progress
  shinyWidgets::updateProgressBar(
    session = session, 
    id = "collateprogress", 
    value = 25, 
    title = "Processing indication data..."
  )
  
## indication SM
  indicationdf = 
    hierarchy  %>% 
    filter(NBDPID %in% subset(filteredstudydisease()$STUDYCODE, filteredstudydisease()$SOURCE == 'Medpace')
           ,ISO %in% iso) %>% 
    left_join(sitelist %>% 
                filter(SOURCE == 'ClinTrakSM') %>% 
                select(SITEID
                       ,FINAL_NAME) %>% 
                mutate(SITEID = as.integer(SITEID))
              ,by='SITEID') %>% 
    mutate(FINAL_NAME = coalesce(FINAL_NAME
                                 ,CENTER_NAME)) %>% 
    group_by(FINAL_NAME
             ,ISO) %>% 
    summarize(ind_studies = n_distinct(NBDPID)
              ,ind_enr_perc = round(mean(STUDY_PERCENTILE, na.rm=T)*100, 0)) %>% 
    ungroup()
  
  ## make column names more logical to help with LLM interpretation
  colnames(indicationdf) = c('FINAL_NAME'
                             ,'ISO'
                             ,paste(ind, 'studies with Medpace')
                             ,paste(ind, 'enrollment percentile in Medpace trials'))
  
  ## indication Citeline
  indicationciteline =
    organizationtrials %>%
    filter(as.integer(TRIALID) %in% as.integer(gsub("CL-", "", subset(filteredstudydisease()$STUDYCODE, grepl('Citeline', filteredstudydisease()$SOURCE))))) %>% 
    mutate(ORGANIZATIONID = as.integer(ORGANIZATIONID)) %>% 
    left_join(sitelist %>% 
                filter(SOURCE == 'Citeline') %>% 
                select(ORGANIZATIONID = SITEID
                       ,ISO
                       ,FINAL_NAME) %>% 
                mutate(ORGANIZATIONID = as.integer(ORGANIZATIONID))
              ,by='ORGANIZATIONID') %>% 
    filter(ISO %in% iso) %>% 
    group_by(FINAL_NAME
             ,ISO) %>% 
    summarize(ind_ext_studies = n_distinct(TRIALID)) %>% 
    ungroup()
  
  ## make column names more logical to help with LLM interpretation
  colnames(indicationciteline) = c('FINAL_NAME'
                                   ,'ISO'
                                   ,paste(ind, 'studies with other companies'))
  
  
  # Update progress
  shinyWidgets::updateProgressBar(
    session = session, 
    id = "collateprogress", 
    value = 40, 
    title = "Processing therapeutic data..."
  )
  
## therapeutic SM
  therapeuticdf = 
    hierarchy  %>% 
    filter(NBDPID %in% subset(filteredstudytherapeutic()$STUDYCODE, filteredstudytherapeutic()$SOURCE == 'Medpace')
           ,ISO %in% iso) %>% 
    left_join(sitelist %>% 
                filter(SOURCE == 'ClinTrakSM') %>% 
                select(SITEID
                       ,FINAL_NAME) %>% 
                mutate(SITEID = as.integer(SITEID))
              ,by='SITEID') %>% 
    mutate(FINAL_NAME = coalesce(FINAL_NAME
                                 ,CENTER_NAME)) %>% 
    group_by(FINAL_NAME
             ,ISO) %>% 
    summarize(ther_studies = n_distinct(NBDPID)
              ,ther_enr_perc = round(mean(STUDY_PERCENTILE, na.rm=T)*100,0)) %>% 
    ungroup()
  
  ## make column names more logical to help with LLM interpretation
  colnames(therapeuticdf) = c('FINAL_NAME'
                              ,'ISO'
                              ,paste(ther, 'studies with Medpace')
                             ,paste(ther, 'enrollment percentile in Medpace trials'))

  ## therapeutic Citeline
  therapeuticciteline =
    organizationtrials %>%
    filter(as.integer(TRIALID) %in% as.integer(gsub("CL-", "", subset(filteredstudytherapeutic()$STUDYCODE, grepl('Citeline', filteredstudytherapeutic()$SOURCE))))) %>% 
    mutate(ORGANIZATIONID = as.integer(ORGANIZATIONID)) %>% 
    left_join(sitelist %>% 
                filter(SOURCE == 'Citeline') %>% 
                select(ORGANIZATIONID = SITEID
                       ,ISO
                       ,FINAL_NAME) %>% 
                mutate(ORGANIZATIONID = as.integer(ORGANIZATIONID))
              ,by='ORGANIZATIONID') %>% 
    filter(ISO %in% iso) %>% 
    group_by(FINAL_NAME
             ,ISO) %>% 
    summarize(ther_ext_studies = n_distinct(TRIALID)) %>% 
    ungroup()
  
  ## make column names more logical to help with LLM interpretation
  colnames(therapeuticciteline) = c('FINAL_NAME'
                                    ,'ISO'
                                    ,paste(ther, 'studies with other companies'))
  
  shinyWidgets::updateProgressBar(
    session = session, 
    id = "collateprogress", 
    value = 60, 
    title = "Combining internal & external data..."
  )
  
  ## combine
    build = 
    indicationdf %>% 
    full_join(therapeuticdf
              ,by=c("FINAL_NAME","ISO")) %>% 
    full_join(indicationciteline
              ,by=c("FINAL_NAME","ISO")) %>% 
    full_join(medidataindication_auto() %>%
                rename(ISO = iso
                       ,medi_ind_studies = studies
                       ,medi_ind_perc = percentile)
              ,by=c("FINAL_NAME","ISO")) %>%
    full_join(therapeuticciteline
              ,by=c("FINAL_NAME","ISO")) %>% 
    full_join(medidatatherapeutic_auto() %>% 
                rename(ISO = iso
                       ,medi_ther_studies = studies
                       ,medi_ther_perc = percentile)
              ,by=c("FINAL_NAME","ISO"))
    
    ## make column names more logical to help with LLM interpretation
    colnames(build)[which(colnames(build) %in% c('medi_ind_perc'
                                                 ,'medi_ind_studies'
                                                 ,'medi_ther_perc'
                                                 ,'medi_ther_studies'))] = c(paste(ind, 'enrollment percentile in medidata studies')
                                                                             ,paste(ind, 'studies with medidata')
                                                                             ,paste(ther, 'enrollment percentile in medidata studies')
                                                                          ,paste(ther, 'studies with medidata'))
    
  
  
  ## custom SM
  if(nrow(subset(medpcustom(), !is.na(medpcustom()$UNIQUEKEY)))>0){
  customdf = 
    hierarchy  %>% 
    filter(NBDPID %in% medpcustom()$UNIQUEKEY
           ,ISO %in% iso) %>% 
    left_join(sitelist %>% 
                filter(SOURCE == 'ClinTrakSM') %>% 
                select(SITEID
                       ,FINAL_NAME) %>% 
                mutate(SITEID = as.integer(SITEID))
              ,by='SITEID') %>% 
    mutate(FINAL_NAME = coalesce(FINAL_NAME
                                 ,CENTER_NAME)) %>% 
    group_by(FINAL_NAME
             ,ISO) %>% 
    summarize(medp_custom_studies = n_distinct(NBDPID)
              ,medp_custom_enr_perc = round(mean(STUDY_PERCENTILE, na.rm=T)*100,0)) %>% 
    ungroup()
  
  colnames(customdf) = c('FINAL_NAME'
                         ,'ISO'
                         ,paste(input$medpcustomdescription, 'studies with Medpace')
                         ,paste(input$medpcustomdescription, 'enrollment percentile'))
  build = 
    build %>% 
    full_join(customdf
              ,by=c("FINAL_NAME"
                    ,"ISO"))
  
  
  }else{}
  
  ## custom Citeline
  if(nrow(subset(citelinecustom(), !is.na(citelinecustom()$TRIALID)))>0){
  customciteline =
    organizationtrials %>%
    filter(as.integer(TRIALID) %in% citelinecustom()$TRIALID) %>% 
    mutate(ORGANIZATIONID = as.integer(ORGANIZATIONID)) %>% 
    left_join(sitelist %>% 
                filter(SOURCE == 'Citeline') %>% 
                select(ORGANIZATIONID = SITEID
                       ,ISO
                       ,FINAL_NAME) %>% 
                mutate(ORGANIZATIONID = as.integer(ORGANIZATIONID))
              ,by='ORGANIZATIONID') %>% 
    filter(ISO %in% iso) %>% 
    group_by(FINAL_NAME
             ,ISO) %>% 
    summarize(ext_custom_studies = n_distinct(TRIALID)) %>% 
    ungroup()
  
  colnames(customciteline) = c('FINAL_NAME'
                               ,'ISO'
                               ,paste(input$citelinecustomdescription, 'studies with other companies'))
  
  build = 
    build %>% 
    full_join(customciteline
              ,by=c("FINAL_NAME"
                    ,"ISO"))
  }else{}
  
  ## custom competition
  if(nrow(subset(citelinecompetition(), !is.na(citelinecompetition()$TRIALID)))>0){
    competitionciteline =
      organizationtrials %>%
      filter(as.integer(TRIALID) %in% citelinecompetition()$TRIALID) %>% 
      mutate(ORGANIZATIONID = as.integer(ORGANIZATIONID)) %>% 
      left_join(sitelist %>% 
                  filter(SOURCE == 'Citeline') %>% 
                  select(ORGANIZATIONID = SITEID
                         ,ISO
                         ,FINAL_NAME) %>% 
                  mutate(ORGANIZATIONID = as.integer(ORGANIZATIONID))
                ,by='ORGANIZATIONID') %>% 
      filter(ISO %in% iso) %>% 
      group_by(FINAL_NAME
               ,ISO) %>% 
      summarize(competing_studies = n_distinct(TRIALID)) %>% 
      ungroup()
    
    colnames(competitionciteline) = c('FINAL_NAME'
                                      ,'ISO'
                                      ,'Competing studies')
    
    build = 
      build %>% 
      full_join(competitionciteline
                ,by=c("FINAL_NAME"
                      ,"ISO"))
  }else{}
    
    ## custom medidata
  if(nrow(subset(medidataindication(), !is.na(medidataindication()$FINAL_NAME))) > 0){
      build =
      build %>%
        full_join(medidataindication()
                  ,by=c("FINAL_NAME"
                        ,"ISO"))

      ## make column names more logical to help with LLM interpretation
      colnames(build)[which(colnames(build) %in% c('percentile'
                                                   ,'studies'))] = c(paste(input$medidatacustomdescription, 'enrollment percentile in medidata studies')
                                                                     ,paste(input$medidatacustomdescription, 'studies with medidata'))

    }else{}
  
    
    shinyWidgets::updateProgressBar(
      session = session, 
      id = "collateprogress", 
      value = 80, 
      title = "Evaluating available variables..."
    )
    
  build = 
  build %>% 
    left_join(hierarchy %>% 
                left_join(sitelist %>% 
                            filter(SOURCE == 'ClinTrakSM') %>% 
                            select(SITEID
                                   ,FINAL_NAME) %>% 
                            mutate(SITEID = as.integer(SITEID))
                          ,by='SITEID') %>% 
                mutate(FINAL_NAME = coalesce(FINAL_NAME
                                             ,CENTER_NAME)
                       ,yr_since_act = year(Sys.Date()) - year(as.Date(ACTIVATIONDATE))) %>% 
                group_by(FINAL_NAME
                         ,ISO) %>% 
                summarize(medp_studies = n_distinct(NBDPID)
                          ,yr_since_act = min(yr_since_act, na.rm=T)
                          ,avg_perc = round(mean(STUDY_PERCENTILE, na.rm=T)*100, 0)) %>% 
                ungroup()
              ,by=c('FINAL_NAME'
                    ,'ISO')) %>% 
    left_join(hierarchy %>% 
                left_join(sitelist %>% 
                            filter(SOURCE == 'ClinTrakSM') %>% 
                            select(SITEID
                                   ,FINAL_NAME) %>% 
                            mutate(SITEID = as.integer(SITEID))
                          ,by='SITEID') %>% 
                mutate(FINAL_NAME = coalesce(FINAL_NAME
                                             ,CENTER_NAME)
                       ,yr_since_act = year(Sys.Date()) - year(as.Date(ACTIVATIONDATE))
                       ,STARTUPWK = case_when(
                         is.na(STARTUPWK) ~ STARTUPWK
                         ,STARTUPWK < 4 ~ NA
                         ,STARTUPWK > 52 & ISO != 'BRA' & ISO != 'ROU' ~ NA
                         ,TRUE ~ STARTUPWK)) %>% 
                filter(yr_since_act <= 3) %>% 
                group_by(FINAL_NAME
                         ,ISO) %>% 
                summarize(startup_q1 = quantile(STARTUPWK, na.rm=T)[2]
                          ,startups = sum(!is.na(STARTUPWK))) %>% 
                ungroup()
              ,by=c('FINAL_NAME'
                    ,'ISO')) %>% 
    left_join(phasedf
              ,by=c('FINAL_NAME'
                    ,'ISO')) %>% 
    left_join(citelinephase
              ,by=c('FINAL_NAME'
                    ,'ISO'))
  
  colnames(build)[which(colnames(build) %in% c('medp_studies'
                                               ,'yr_since_act'
                                               ,'avg_perc'
                                               ,'startup_q1'
                                               ,'startups'))] = c('Medpace studies'
                                                                ,'Years since last Medpace study'
                                                                ,'Average enrollment percentile across all Medpace trials'
                                                                ,'Expected startup weeks'
                                                                ,'Medpace studies from 2022 onward with startup data')
  
  shinyWidgets::updateProgressBar(
    session = session, 
    id = "collateprogress", 
    value = 90, 
    title = "Cleaning data..."
  )
  
  ## convert NA to 0 for study count variables
  columnstoconvert = which(grepl('studies with', colnames(build), ignore.case=T) |
                             grepl('competing studies', colnames(build), ignore.case=T) |
                             grepl('Medpace studies', colnames(build), ignore.case=T) |
                             colnames(build) %in% c('medpphase1','medpphase2','medpphase3','medpphase4','phase1','phase2','phase3','phase4'))
  
  build[,columnstoconvert][is.na(build[,columnstoconvert])] = 0
  
  ## convert NaN to NA for consistency
  build = build %>% 
    mutate(across(everything(), ~ifelse(is.nan(.), NA, .)))
  
  studysites(build)
  
  ## trigger for voi selector to appear
  voiselectorappear(TRUE)
  
  # Close progress bar
  shinyWidgets::closeSweetAlert(session = session)
  
  ## PLACEHOLDER: REMINDER TO CALCULATE BEST INDICATION AND BEST THERAPEUTIC PERCENTILE

    }
})










##########################
## VOIs
##########################

voi = reactiveVal({
  data.frame(VOI = NA)
})

observeEvent(
  studysites(), {
    df = data.frame(VOI = colnames(studysites())) %>% 
      mutate(nonstandard = ifelse(VOI %in% c(
        'Medpace studies'
        ,'Years since last Medpace study'
        ,'Average enrollment percentile across all Medpace studies'
        ,'Expected startup weeks'
        ,'Medpace studies from 2022 onward with startup data'
        ,"FINAL_NAME"
        ,"ISO"
      ),0,1)
      ,citeline = case_when(
        grepl('studies with other companies', VOI) ~ 1
        ,VOI == 'Competing studies' ~ 1
        ,TRUE ~ 0)) %>% 
      filter(citeline  == 0
             ,!VOI %in% c('medpphase1'
                          ,'medpphase2'
                          ,'medpphase3'
                          ,'medpphase4'
                          ,'phase1'
                          ,'phase2'
                          ,'phase3'
                          ,'phase4'))
    
    ## if the sum of any columns = 0, remove so you can't cluster by it
    
    column_sums <- colSums(studysites()[3:ncol(studysites())], na.rm=T)
    if(any(column_sums == 0)){
      cols_to_remove <- names(column_sums[column_sums == 0])
      
          if(any(grepl('studies with other companies', cols_to_remove))){
            cols_to_remove = cols_to_remove[-which(grepl('studies with other companies', cols_to_remove))]
          }else{}
          
          if('Competing studies' %in% cols_to_remove){
            cols_to_remove = cols_to_remove[-which(cols_to_remove == 'Competing studies')]
          }else{}
          
          if(length(cols_to_remove)>0){
          df = df[-which(df$VOI %in% cols_to_remove),]
          }else{}
      
    }else{}
    
    voi(df)
    
  })

##########################
## voi selector
##########################


  output$show_voiselect = renderUI({
  if(voiselectorappear()){
  selectInput('voiselection'
              ,HTML('Which variables to consider?<br><i>..recommend max of 7<br>Citeline variables cannot be selected</i><br>')
              ,choices = NULL
              ,multiple = T
              ,width = '100%')
  }else{}
    })



observe({
  req(voiselectorappear())
  updateActionButton(session
                     ,"collate"
                     ,label = "Submitted"
                     ,icon = icon("square-check"))
})

observeEvent(voi(),{
  
  updateSelectInput(session
                    ,'voiselection'
                    ,choices = subset(voi()$VOI, (voi()$VOI != 'FINAL_NAME' & voi()$VOI != 'ISO')))
})

output$showcalculatebutton = renderUI({
  req(input$voiselection)
  
  actionButton('calculate', 'Rank, Cluster, & Interpret', width='100%')
})

##########################
## voi sliders
##########################

output$voi_sliders = renderUI({
  req(input$voiselection)
  
  df = data.frame(VOI = input$voiselection)
  df$label = gsub("_", " ", df$VOI)
  df$id = paste(df$VOI, "id", sep="_")
  
  slider_list = lapply(1:nrow(df), function(i){
    sliderInput(
      inputId = df$id[i]
      ,label = df$label[i]
      ,min = 0
      ,max = 1
      ,value = round(1/nrow(df), 2)
      ,step = 0.01
      ,ticks = F
    )
  })
  
  tagList(
    p('Weight importance of each variable:')
    ,do.call(tagList, slider_list))
})









##########################
## weighted euclidean distance
##########################

euclidean = eventReactive(input$calculate, {
  req(input$voiselection
      ,input$selectedcountry)
  
  iso = countrycode(input$selectedcountry
                    ,origin='country.name'
                    ,destination='iso3c')
  
  df = studysites() %>% 
    filter(ISO %in% iso)
  dfvoi = input$voiselection
  voitable = voi() %>% 
    filter(VOI %in% input$voiselection)
  # min_nonNA = floor(length(dfvoi)/2)
  
  ## rescaling
  rescaled = c()
  for(i in dfvoi){
    if(grepl('startup', i, ignore.case=T) | grepl('competing', i, ignore.case=T) | grepl('years since', i, ignore.case=T)){
      df[,ncol(df)+1] = rescale(df[,which(colnames(df) == i)][[1]]
                                ,to=c(1,0))
    }else{
    df[,ncol(df)+1] = rescale(df[,which(colnames(df) == i)][[1]]
                              ,to=c(0,1))
    }
    colnames(df)[ncol(df)] = paste0(i, '_rescale')
    rescaled = c(rescaled, paste0(i, '_rescale'))
    }

  ## weights
  weights = sapply(dfvoi, function(var){
    weight_input_name = paste0(var, '_id')
    input[[weight_input_name]]
  })
  
  ## normalize weights to sum to 1 in case user forgot
  weights = weights / sum(weights)
  
  # Filter clinics with at least 1 non-standard voi (if 1 non-standard is included in voiselection)
  if(sum(voitable$nonstandard) == 0){
    
  min_nonNA = floor(length(dfvoi)/2)
  selected_data <- df[, c("FINAL_NAME", "ISO", rescaled), drop = FALSE]
  non_na_counts <- rowSums(!is.na(selected_data[, rescaled, drop = FALSE]))
  valid_clinics <- non_na_counts >= min_nonNA
  filtered_data <- selected_data[valid_clinics, ]
  excluded_data <- selected_data[!valid_clinics, ]
  
  }else{
    nonstandard = paste0(subset(voitable$VOI, voitable$nonstandard==1), "_rescale")
    selected_data <- df[, c("FINAL_NAME", "ISO", rescaled), drop = FALSE]
    non_na_counts <- rowSums(!is.na(selected_data[, nonstandard, drop = FALSE]))
    valid_clinics <- non_na_counts >= 1
    filtered_data <- selected_data[valid_clinics, ]
    excluded_data <- selected_data[!valid_clinics, ]
    
  }
  
  if (nrow(filtered_data) == 0) {
    return(list(results = NULL, excluded = excluded_data, 
                message = "No clinics meet the minimum non-NA criteria"))
  }
  
  # Calculate weighted Euclidean distance from the best (reference point = 1 for all variables)
  distances =
    filtered_data %>% 
    select(all_of(rescaled)) %>% 
    rowwise() %>% 
    summarize(
      distance = {
        row = c_across(everything())
        
        # handle NA values by excluding them from distance calculation
        valid_indices = !is.na(row)
        if(sum(valid_indices) == 0) return(NA)
        
        # reference point is 1 for all variables (best performance)
        reference = rep(1, length(row))
        
        # calculate weighted squared differences
        squared_diffs = weights[valid_indices] * (row[valid_indices] - reference[valid_indices])^2
        
        # return weighted euclidean distance
        sqrt(sum(squared_diffs))
      }
      ,.groups = 'drop'
    ) %>% 
    pull(distance)
  
  
  # Create results dataframe
  data.frame(
    FINAL_NAME = filtered_data$FINAL_NAME,
    ISO = filtered_data$ISO,
    weighted_distance = distances,
    rank = rank(distances, na.last = TRUE),
    stringsAsFactors = FALSE
  )
  
  })

## update action button
observeEvent(input$calculate, {
  
  updateActionButton(session
                     ,"calculate"
                     ,label = "Submitted"
                     ,icon = icon("square-check"))
  
})



##########################
## clustering
##########################

## empty spot for clustering & interpretation results
clusterresults = reactiveVal(NULL)
clustersummary = reactiveVal(NULL)
interpretation = reactiveVal()

## interpretation readiness
interpretationready = reactiveVal('not ready')

observeEvent(input$calculate, {
  
  showModal(modalDialog(
    title = "Analyzing...",
    div(
      style = "text-align: center;",
      tags$i(class = "fa fa-spinner fa-spin fa-3x"),
      br(), br(),
      "We're running your data through a machine learning model. An AI tool will help interpret the results."
    ),
    footer = NULL,
    easyClose = FALSE
  ))
  
  iso = countrycode(input$selectedcountry
                    ,origin='country.name'
                    ,destination='iso3c')
  
  ## definitions
  dfvoi = input$voiselection
  data = studysites() %>% 
    mutate(index = row_number()) %>% 
    filter(ISO %in% iso)
  variables_of_interest = dfvoi
  k = 7
  max_na = ceiling(length(dfvoi)/2)
  imputation_method = 'mean'
  nstart = 25
  iter.max = 100
  seed = 123
  set.seed(seed)
  

  # Extract variables of interest
  data_subset <- data[, c('index',variables_of_interest), drop = FALSE]
  
  # Count NA values per row
  na_count <- rowSums(is.na(data_subset[,2:ncol(data_subset)]))
  
  # Filter observations based on NA tolerance
  valid_rows <- na_count <= max_na
  data_filtered <- data_subset[valid_rows, ]

  
  ## convert all to numeric
  data_filtered = as.data.frame(lapply(data_filtered, as.numeric))
  
  # Handle remaining NA values through imputation, mean
  for(col in names(data_filtered)){
    meanfill = mean(data_filtered[,col], na.rm=T)
    missingrows = which(is.na(data_filtered[,col]))
    data_filtered[missingrows,col] = meanfill
  }
  

  
  # Perform k-means clustering
  if (nrow(data_filtered) < k) {
    stop("Not enough observations for the specified number of clusters")
  }
  
  kmeans_result <- kmeans(data_filtered %>% select(-c(index))
                          , centers = k
                          , nstart = nstart
                          , iter.max = iter.max)
  
  data_filtered$cluster = kmeans_result$cluster
  

  
  clusterresults(
    data %>% 
    left_join(data_filtered %>% 
                select(index
                       ,cluster)
              ,by='index') %>% 
    select(FINAL_NAME
           ,ISO
           ,cluster))
  
  
  ## plain english names of inputs
  namedf = data.frame(variable = dfvoi
                      ,description = dfvoi)
  
  clustersummary(
    data.frame(kmeans_result$centers) %>% 
      mutate(cluster = row_number()) %>% 
      pivot_longer(!cluster
                   ,names_to = 'variable'
                   ,values_to = 'center_value') %>% 
      mutate(variable = gsub("\\."," ", variable)) %>% 
      merge(namedf
            ,by='variable') %>% 
      mutate(shortprompt = paste0(description
                                  ,": "
                                  ,round(center_value, 3)))
  )
  

  
  df = clustersummary()
  
  
  openingstatement = "SELECT SNOWFLAKE.CORTEX.COMPLETE('claude-4-sonnet','"
  statement2 = "I ran a k-means cluster to select the best clinical trial sites. Analyse each cluster based on the following characteristics of each cluster center:"
  allclusters = ""
  
  
  for(i in unique(df$cluster)){
    tempstatement = paste0("\n"
                           ,"Cluster "
                           ,i
                           ,":\n"
                           ,paste(subset(df$shortprompt, df$cluster == i), collapse="\n"))
    allclusters = paste(allclusters
                        ,tempstatement
                        ,sep="\n")}
  
  statement4 = paste0("\n\nProvide a concise interpretation of each cluster in 10 words or less")
  closingstatement = "')"
  
  
  llmreply = DBI::dbGetQuery(aiconn,
                             paste0(openingstatement
                                    ,statement2
                                    ,allclusters
                                    ,statement4
                                    ,closingstatement))
  
  
  interpretation(
    data.frame(results = strsplit(llmreply[,1], '\n')[[1]]) %>%
      rowwise() %>%
      mutate(firstword = strsplit(results, " ")[[1]][1]
             , cluster = grepl('cluster', firstword, ignore.case=T)) %>%
      filter(cluster == TRUE) %>% 
      select(Interpretation = results))
  
  
  interpretationready('ready')
  

  })


##########################
## cluster selections to filter table
##########################

output$clusteroptions = renderUI({
  req(interpretationready() == 'ready')
  req(studysites())
  req(clusterresults())

  interpretationdf = interpretation()

  ## modify names
  names = trimws(sub("^\\*\\*.*?\\*\\*\\s*", "", interpretationdf$Interpretation))
  
  tagList(
    tags$style(HTML("
      .bootstrap-select .dropdown-menu li a {
        white-space: normal !important;
        word-wrap: break-word !important;
        padding: 8px 12px !important;
        line-height: 1.3 !important;
      }
      .bootstrap-select .dropdown-menu {
        max-width: none !important;
        width: 100% !important;
      }
      .bootstrap-select button {
        white-space: normal !important;
        text-align: left !important;
        height: auto !important;
        padding: 8px 12px !important;
      }
    ")),
    pickerInput(
      inputId = "selectedclusters",
      label = "Select any clusters you'd like to filter the table for: ",
      choices = c(names, 'Unclustered (insufficient data)'),
      selected = NULL,
      multiple = T,
      width = '100%',
      options = pickerOptions(
        style = "btn-default",
        size = "auto"
      )
    )
    ,selectInput(
      'filteredcountries'
      ,label = 'Filter to view specific country(ies):'
      ,choices = sort(studysites()$ISO)
      ,selected = sort(studysites()$ISO)
      ,multiple = T
      ,width = '100%'
    )
  )
})




##########################
## result data
##########################

resultdata = reactive({
  req(interpretationready() == 'ready')
  req(studysites())
  req(clusterresults())
  
  
  interpretationdf = interpretation()
  
  ## modify names
  names = trimws(sub("^\\*\\*.*?\\*\\*\\s*", "", interpretationdf$Interpretation))
  numbers = str_extract(interpretationdf$Interpretation, '[0-9]+') 
  
  interpretationdf$cluster = as.integer(numbers)
  interpretationdf$clustername = names
  
  ssdf = studysites()
  clusterdf = clusterresults()
  euclideandf = euclidean() %>% 
    mutate(PercentRank = round((1-weighted_distance)*100,0)) %>% 
    select(FINAL_NAME
           ,ISO
           ,PercentRank)
  
  df =
    ssdf %>% 
    left_join(clusterdf
              ,by=c('FINAL_NAME'
                    ,'ISO')) %>% 
    left_join(interpretationdf %>% 
                select(-Interpretation)
              ,by='cluster') %>% 
    left_join(euclideandf
              ,by=c('FINAL_NAME'
                    ,'ISO')) %>% 
    select(-cluster) %>% 
    mutate(clustername = ifelse(is.na(clustername), 'Unclustered (insufficient data)', clustername))
    
  
  ## filter to selected clusters
    if(length(input$selectedclusters) > 0 & !is.null(input$selectedclusters)){
      df = 
        df %>% 
        filter(clustername %in% input$selectedclusters)
    }else{}
  
  ## filter to selected countries
  if(length(input$filteredcountries) > 0 & !is.null(input$filteredcountries)){
    df = 
      df %>% 
      filter(ISO %in% input$filteredcountries)
  }else{}
  
  ## confirm how indication columns will be labeled for MEDP & Medidata
  if(length(input$selecteddiseases)==1){
    ind = input$selecteddiseases
  }else{
    ind = paste(input$selecteddiseases, collapse=' & ')
  }
  
  ## which columns have indication study counts
  cols = data.frame(names = colnames(df)) %>%
    filter(grepl(ind, names, ignore.case=T) | grepl(input$medpcustomdescription, names, ignore.case=T) | grepl(input$medidatacustomdescription, names, ignore.case=T) | grepl(input$citelinecustomdescription, names, ignore.case=T)
           ,grepl('studies', names, ignore.case=T) | grepl('trials', names, ignore.case=T)
           ,!grepl('enrollment performance', names, ignore.case=T)
           ,!grepl('enrollment percentile', names, ignore.case=T))
  
  colposition = which(colnames(df) %in% cols$names)
  
  medpcols = data.frame(names = colnames(df)) %>%
    filter(grepl(ind, names, ignore.case=T) | grepl(input$medpcustomdescription, names, ignore.case=T) | grepl(input$medidatacustomdescription, names, ignore.case=T) | grepl(input$citelinecustomdescription, names, ignore.case=T)
           ,grepl('studies', names, ignore.case=T) | grepl('trials', names, ignore.case=T)
           ,!grepl('enrollment performance', names, ignore.case=T)
           ,!grepl('enrollment percentile', names, ignore.case=T)
           ,grepl('Medpace', names, ignore.case=T))
  
  medpcolposition = which(colnames(df) %in% medpcols$names)

  
  if(input$indicationrequire == 'Not required'){ 
    df = df
  }else{if(input$indicationrequire == 'Required'){
    df = df[rowSums(df[colposition] > 0) > 0, ]
  }else{
    df = df[rowSums(df[medpcolposition] > 0) > 0, ]
  }}
  
  if(length(input$phaserequire) > 0){
      if('I' %in% input$phaserequire & input$phasesourcerequire == 'Any source'){ 
        df = df[which(df$phase1 >0 | df$medpphase1 >0),]
      }else{}
    
      if('I' %in% input$phaserequire & input$phasesourcerequire == 'Medpace'){
        df = df[which(df$medpphase1 >0),]
      }else{}
    
      if('II' %in% input$phaserequire & input$phasesourcerequire == 'Any source'){ 
        df = df[which(df$phase2 >0 | df$medpphase2 >0),]
      }else{}
      
      if('II' %in% input$phaserequire & input$phasesourcerequire == 'Medpace'){
        df = df[which(df$medpphase2 >0),]
      }else{}
    
      if('III' %in% input$phaserequire & input$phasesourcerequire == 'Any source'){ 
        df = df[which(df$phase3 >0 | df$medpphase3 >0),]
        df = df[-which(df$FINAL_NAME == 'Medpace Clinical Pharmacology, LLC'),]
      }else{}
      
      if('III' %in% input$phaserequire & input$phasesourcerequire == 'Medpace'){
        df = df[which(df$medpphase3 >0),]
        df = df[-which(df$FINAL_NAME == 'Medpace Clinical Pharmacology, LLC'),]
      }else{}
    
      if('IV' %in% input$phaserequire & input$phasesourcerequire == 'Any source'){ 
        df = df[which(df$phase4 >0 | df$medpphase4 >0),]
        df = df[-which(df$FINAL_NAME == 'Medpace Clinical Pharmacology, LLC'),]
      }else{}
      
      if('IV' %in% input$phaserequire & input$phasesourcerequire == 'Medpace'){
        df = df[which(df$medpphase4 >0),]
        df = df[-which(df$FINAL_NAME == 'Medpace Clinical Pharmacology, LLC'),]
      }else{}
        
  }else{}
  
    return(df)
  
})




##########################
## result table
##########################

## table data
resultdata_table = reactive({
  df <- resultdata()
  
  # If no columns selected, return original data
  if (is.null(input$voifilterinput) || length(input$voifilterinput) == 0) {
    return(df)
  }
  
  # Apply filters for each selected column
  for (col in input$voifilterinput) {
    slider_input <- input[[paste0("slider_", col)]]
    
    if (!is.null(slider_input)) {
      df <- df[df[[col]] >= slider_input[1] & df[[col]] <= slider_input[2], ]
    }
  }
  
  return(df)
})

## table ui
output$clustertable = renderDataTable({
  req(interpretationready() == 'ready')
  req(studysites())
  req(clusterresults())
  req(resultdata_table())

    df = resultdata_table()

    df =
      df %>%
      relocate(clustername
               ,FINAL_NAME
               ,ISO
               ,PercentRank
               ,names(.)[which(colnames(df) %in% input$voiselection)])

    min = 5
    max = min + length(input$voiselection) - 1


    ##remove phase columns, unless a phase is selected
    phase = df %>% 
      select(FINAL_NAME
             ,ISO
             ,medpphase1
             ,medpphase2
             ,medpphase3
             ,medpphase4
             ,phase1
             ,phase2
             ,phase3
             ,phase4) %>% 
      rowwise() %>% 
      mutate(bestphase1 = max(medpphase1, phase1, na.rm=T)
             ,bestphase2 = max(medpphase2, phase2, na.rm=T)
             ,bestphase3 = max(medpphase3, phase3, na.rm=T)
             ,bestphase4 = max(medpphase4, phase4, na.rm=T)) %>% 
      ungroup() %>% 
      rename(`Ph1 Studies` = bestphase1
             ,`Ph2 Studies` = bestphase2
             ,`Ph3 Studies` = bestphase3
             ,`Ph4 Studies` = bestphase4
             ,`MEDP Ph1 Studies` = medpphase1
             ,`MEDP Ph2 Studies` = medpphase2
             ,`MEDP Ph3 Studies` = medpphase3
             ,`MEDP Ph4 Studies` = medpphase4)

    df = df %>% 
      select(-c(medpphase1
                ,medpphase2
                ,medpphase3
                ,medpphase4
                ,phase1
                ,phase2
                ,phase3
                ,phase4))


    if(length(input$phaserequire) == 0){
    }else{
      phasetokeep = c()
      
      if('I' %in% input$phaserequire & input$phasesourcerequire == 'Any source'){
        phasetokeep = c(phasetokeep, 'Ph1 Studies')
      }else{}
      
      if('I' %in% input$phaserequire & input$phasesourcerequire == 'Medpace'){
        phasetokeep = c(phasetokeep, 'MEDP Ph1 Studies')
      }else{}
      
      if('II' %in% input$phaserequire & input$phasesourcerequire == 'Any source'){
        phasetokeep = c(phasetokeep, 'Ph2 Studies')
      }else{}
      
      if('II' %in% input$phaserequire & input$phasesourcerequire == 'Medpace'){
        phasetokeep = c(phasetokeep, 'MEDP Ph2 Studies')
      }else{}
      
      if('III' %in% input$phaserequire & input$phasesourcerequire == 'Any source'){
        phasetokeep = c(phasetokeep, 'Ph3 Studies')
      }else{}
      
      if('III' %in% input$phaserequire & input$phasesourcerequire == 'Medpace'){
        phasetokeep = c(phasetokeep, 'MEDP Ph3 Studies')
      }else{}
      
      if('IV' %in% input$phaserequire & input$phasesourcerequire == 'Any source'){
        phasetokeep = c(phasetokeep, 'Ph4 Studies')
      }else{}
      
      if('IV' %in% input$phaserequire & input$phasesourcerequire == 'Medpace'){
        phasetokeep = c(phasetokeep, 'MEDP Ph4 Studies')
      }else{}
      
      phase = phase[,which(colnames(phase) %in% c(phasetokeep, 'FINAL_NAME', 'ISO'))]
      
      df = df %>% 
        left_join(phase
                  ,by=c('FINAL_NAME'
                        ,'ISO'))
    }
    
    colnames(df)[which(colnames(df) %in% c('clustername','FINAL_NAME','PercentRank'))] = c(
      'Cluster'
      ,'Site'
      ,'Percent Rank'
    )

    ## close 'analyzing' wait box
    removeModal()

    datatable(
      df,
      selection = 'multiple',
      options = list(
        scrollX = TRUE,
        # searching = TRUE,
        pageLength = 100,
        scrollY = '30vh',
        autoWidth = FALSE,
        initComplete = JS(
          "function(settings, json) {",
          "$(this.api().table().header()).css({'color': 'white', 'font-family': 'Arial', 'background-color': '#002554'});",
          paste0("$(this.api().table().header()).find('th:nth-child(n+", min, "):nth-child(-n+", max, ")').css({'background-color': '#6cca98'});"),
          "$(this.api().table().container()).find('th:first-child, td:first-child, th:nth-child(2), td:nth-child(2)').css({'width': '300px', 'min-width': '300px', 'max-width': '300px'});",
          "this.api().columns.adjust();",
          "}"
        ),
        columnDefs = list(
          list(className = 'dt-center', targets = "_all")
        )
      ),
      rownames = FALSE
    )
      })


# Create DataTable proxy for programmatic control
proxy <- DT::dataTableProxy("clustertable")





##########################
## voi selection for filtering
##########################
output$voifiltering = renderUI({
  req(nrow(resultdata()) > 0)
  df = resultdata()
  
  
  
  cols = data.frame(names = colnames(df)) %>% 
    filter(!names %in% c("FINAL_NAME"
                         ,"ISO"
                         ,"clustername"
                         ,'PercentRank'
                         ,'medpphase1'
                         ,'medpphase2'
                         ,'medpphase3'
                         ,'medpphase4'
                         ,'phase1'
                         ,'phase2'
                         ,'phase3'
                         ,'phase4'))
  
  
  
  selectInput('voifilterinput'
              ,label = 'Select a custom variable to filter by:'
              ,choices = cols$names
              ,multiple = T
              ,selected = NULL)
  
})

output$voislider_ui <- renderUI({
  req(input$voifilterinput)
  df <- resultdata()
  
  # Create a slider for each selected column
  slider_list <- lapply(input$voifilterinput, function(col) {
    col_data <- df[[col]]
    min_val <- min(col_data, na.rm = TRUE)
    max_val <- max(col_data, na.rm = TRUE)
    
    div(
      h5(paste("Filter", col)),
      sliderInput(
        inputId = paste0("slider_", col),
        label = paste(col, "Range:"),
        min = min_val,
        max = max_val,
        value = c(min_val, max_val),
        step = ifelse(max_val - min_val > 100, 
                      round((max_val - min_val) / 100), 
                      1)
      )
    )
  })
  
  do.call(tagList, slider_list)
})

##########################
## selected rows from results table, temp print
##########################

output$TempSelectedSites = renderUI({
  req(input$clustertable_rows_selected)
  
  
  interpretationdf = interpretation()
  names = trimws(sub("^\\*\\*.*?\\*\\*\\s*", "", interpretationdf$Interpretation))
  numbers = str_extract(interpretationdf$Interpretation, '[0-9]+') 
  interpretationdf$cluster = as.integer(numbers)
  interpretationdf$clustername = names
  
  ssdf = studysites()
  clusterdf = clusterresults()
  euclideandf = euclidean() %>% 
    mutate(PercentRank = round((1-weighted_distance)*100,0)) %>%
    select(FINAL_NAME
           ,ISO
           ,PercentRank)
  
  df =
    ssdf %>% 
    left_join(clusterdf
              ,by=c('FINAL_NAME'
                    ,'ISO')) %>% 
    left_join(interpretationdf %>% 
                select(-Interpretation)
              ,by='cluster') %>% 
    left_join(euclideandf
              ,by=c('FINAL_NAME'
                    ,'ISO')) %>% 
    select(-cluster) %>% 
    mutate(clustername = ifelse(is.na(clustername), 'Unclustered (insufficient data)', clustername))
  
  if(length(input$selectedclusters) > 0 & !is.null(input$selectedclusters)){
    df = 
      df %>% 
      filter(clustername %in% input$selectedclusters)
  }else{}
  
  ## filter to selected countries
  if(length(input$filteredcountries) > 0 & !is.null(input$filteredcountries)){
    df = 
      df %>% 
      filter(ISO %in% input$filteredcountries)
  }else{}
  
  ## any right-pane filters
  if (is.null(input$voifilterinput) || length(input$voifilterinput) == 0) {
  }else{
        # Apply filters for each selected column
        for (col in input$voifilterinput) {
          slider_input <- input[[paste0("slider_", col)]]
          
          if (!is.null(slider_input)) {
            df = df[df[[col]] >= slider_input[1] & df[[col]] <= slider_input[2], ]
          }}}
  
  printdf = df[input$clustertable_rows_selected,]
  
  # Create list items
  list_items <- lapply(1:nrow(printdf), function(i) {
    div(
      style = "margin-bottom: 10px; padding: 8px; background-color: #f8f9fa; border-radius: 4px;",
      p(printdf$FINAL_NAME[i], style = "margin: 0;")
    )
  })
  
  do.call(tagList, list_items)
})



##########################
## site selection reactive 
##########################

selected_hospitals <- reactiveVal(NULL)


##########################
## site selection submissions
##########################

observeEvent(input$submitsites, {
  req(input$clustertable_rows_selected)
  
  
  interpretationdf = interpretation()
  names = trimws(sub("^\\*\\*.*?\\*\\*\\s*", "", interpretationdf$Interpretation))
  numbers = str_extract(interpretationdf$Interpretation, '[0-9]+') 
  interpretationdf$cluster = as.integer(numbers)
  interpretationdf$clustername = names
  
  ssdf = studysites()
  clusterdf = clusterresults()
  
  df =
    ssdf %>% 
    left_join(clusterdf
              ,by=c('FINAL_NAME'
                    ,'ISO')) %>% 
    left_join(interpretationdf %>% 
                select(-Interpretation)
              ,by='cluster') %>% 
    select(-cluster) %>% 
    mutate(clustername = ifelse(is.na(clustername), 'Unclustered (insufficient data)', clustername))
  
  if(length(input$selectedclusters) > 0 & !is.null(input$selectedclusters)){
    df = 
      df %>% 
      filter(clustername %in% input$selectedclusters)
  }else{}
  
  ## filter to selected countries
  if(length(input$filteredcountries) > 0 & !is.null(input$filteredcountries)){
    df = 
      df %>% 
      filter(ISO %in% input$filteredcountries)
  }else{}
  
  ## any right-pane filters
  if (is.null(input$voifilterinput) || length(input$voifilterinput) == 0) {
  }else{
    # Apply filters for each selected column
    for (col in input$voifilterinput) {
      slider_input <- input[[paste0("slider_", col)]]
      
      if (!is.null(slider_input)) {
        df = df[df[[col]] >= slider_input[1] & df[[col]] <= slider_input[2], ]
      }}}
  
  ## selected sites based on filtered (as applicable) data
  ## apped to list of selected hospitals
  df2 = selected_hospitals()
  selected_hospitals(df2 %>% 
                       bind_rows(df[input$clustertable_rows_selected,]) %>% 
                       distinct())
  
  ## unselect the rows
  DT::selectRows(proxy, NULL)

})

##########################
## site selection total
##########################

output$siteTotal = renderPlot({
  req(length(selected_hospitals()) > 0)
  df = selected_hospitals()
  
  ggplot(data = df)+
    geom_text(aes(x=1
                  ,y=1
                  ,label=nrow(df))
              ,fontface = 'bold'
              ,color = 'white'
              ,size = 16
              ,vjust=0)+
    geom_text(aes(x=1
                  ,y=1
                  ,label='Selected Sites')
              ,color='white'
              ,size = 8
              ,vjust=1
              ,lineheight = 0.75)+
    theme_void()+
    theme(panel.background = element_rect(color = '#002554'
                                          ,fill = '#002554'))
})

##########################
## site selection medp experience
##########################
output$medp_experience = renderPlotly({
  req(length(selected_hospitals()) > 0)
  df = selected_hospitals()
  
  
  # Add jitter to create beeswarm effect
  jitter_amount <- 0.1
  df$x_jitter <- 1 + runif(nrow(df), -jitter_amount, jitter_amount)
  
  plot_ly(
    data = df,
    x = ~x_jitter,
    y = ~`Medpace studies`,
    type = 'scatter',
    mode = 'markers',
    marker = list(
      color = 'rgba(0, 37, 84, 0.5)',
      size = 8
    ),
    hovertext = ~paste(FINAL_NAME, "<br>MEDP Studies:", `Medpace studies`),
    # hovertemplate = "%{text}<extra></extra>",
    hoverinfo = 'text',
    showlegend = FALSE
  ) %>%
    layout(
      xaxis = list(
        title = "",
        showticklabels = FALSE,
        showgrid = FALSE,
        zeroline = FALSE,
        range = c(-0.5, 2.5)
      ),
      yaxis = list(
        title = "Medpace Studies",
        showgrid = FALSE,
        zeroline = FALSE
      ),
      plot_bgcolor = 'white',
      paper_bgcolor = 'white',
      font = list(family = "Arial", color = "#002554")
    )
})

## average to put ontop of plotly
output$medp_experience_avg = renderPlot({
  req(length(selected_hospitals()) > 0)
  df = selected_hospitals()
  
  ggplot(data = df)+
    geom_text(aes(x=1
                  ,y=1
                  ,label = paste('Avg', round(mean(df$`Medpace studies`, na.rm=T), 0), 'Studies'))
              ,color = 'white'
              ,size = 5)+
    theme_void()+
    theme(panel.background = element_rect(color = '#002554'
                                          ,fill = '#002554'))
})

##########################
## site selection enr perc
##########################
output$ind_percentile = renderPlotly({
  req(length(selected_hospitals()) > 0)
  df = selected_hospitals()
  
  ## best indication enrollment performance (includes benchmarked)
  
  ## confirm how indication columns will be labeled for MEDP & Medidata
  if(length(input$selecteddiseases)==1){
    ind = input$selecteddiseases
  }else{
    ind = paste(input$selecteddiseases, collapse=' & ')
  }
  
  ## which columns have percentile that isn't general
  cols = data.frame(names = colnames(df)) %>% 
    filter(grepl('enrollment percentile', names, ignore.case=T)
           ,names != 'Average enrollment percentile across all Medpace trials'
           ,grepl(ind, names, ignore.case=T) | grepl(input$medpcustomdescription, names, ignore.case=T) | grepl(input$medidatacustomdescription, names, ignore.case=T))
  
  colposition = which(colnames(df) %in% cols$names)
  
  ## max percentile
  df = 
    df %>% 
    rowwise() %>% 
    mutate(best_indication_percentile = max(c_across(colposition), na.rm=T)
           ,best_indication_percentile = ifelse(best_indication_percentile == '-Inf'
                                                ,NA
                                                ,as.integer(best_indication_percentile))) %>% 
    ungroup()
  
  # Add jitter to create beeswarm effect
  jitter_amount <- 0.1
  df$x_jitter <- 1 + runif(nrow(df), -jitter_amount, jitter_amount)
  
  plot_ly(
    data = df,
    x = ~x_jitter,
    y = ~best_indication_percentile,
    type = 'scatter',
    mode = 'markers',
    marker = list(
      color = 'rgba(0, 37, 84, 0.5)',
      size = 8
    ),
    text = ~paste(FINAL_NAME, "<br>", ind, "<br>Enr. Percentile:", best_indication_percentile),
    hovertemplate = "%{text}<extra></extra>",
    showlegend = FALSE
  ) %>%
    layout(
      xaxis = list(
        title = "",
        showticklabels = FALSE,
        showgrid = FALSE,
        zeroline = FALSE,
        range = c(-0.5, 2.5)
      ),
      yaxis = list(
        title = paste(ind, '<br>Enr. Percentile'),
        showgrid = FALSE,
        zeroline = FALSE
      ),
      plot_bgcolor = 'white',
      paper_bgcolor = 'white',
      font = list(family = "Arial", color = "#002554")
    )
})

## average to put ontop of plotly
output$ind_percentile_avg = renderPlot({
  req(length(selected_hospitals()) > 0)
  df = selected_hospitals()
  
  ## best indication enrollment performance (includes benchmarked)
  
  ## confirm how indication columns will be labeled for MEDP & Medidata
  if(length(input$selecteddiseases)==1){
    ind = input$selecteddiseases
  }else{
    ind = paste(input$selecteddiseases, collapse=' & ')
  }
  
  ## which columns have percentile that isn't general
  cols = data.frame(names = colnames(df)) %>% 
    filter(grepl('enrollment percentile', names, ignore.case=T)
           ,names != 'Average enrollment percentile across all Medpace trials'
           ,grepl(ind, names, ignore.case=T) | grepl(input$medpcustomdescription, names, ignore.case=T) | grepl(input$medidatacustomdescription, names, ignore.case=T))
  
  colposition = which(colnames(df) %in% cols$names)
  
  ## max percentile
  df = 
    df %>% 
    rowwise() %>% 
    mutate(best_indication_percentile = max(c_across(colposition), na.rm=T)
           ,best_indication_percentile = ifelse(best_indication_percentile == '-Inf'
                                                ,NA
                                                ,as.integer(best_indication_percentile))) %>% 
    ungroup()
  
  ending = case_when(
    substr(round(mean(df$best_indication_percentile, na.rm=T), 0)
           , nchar(round(mean(df$best_indication_percentile, na.rm=T), 0))
           , nchar(round(mean(df$best_indication_percentile, na.rm=T), 0))) %in% c('0','4','5','6','7','8','9') ~ 'th'
    ,substr(round(mean(df$best_indication_percentile, na.rm=T), 0)
            , nchar(round(mean(df$best_indication_percentile, na.rm=T), 0))
            , nchar(round(mean(df$best_indication_percentile, na.rm=T), 0))) == '1' ~ 'st'
    ,substr(round(mean(df$best_indication_percentile, na.rm=T), 0)
            , nchar(round(mean(df$best_indication_percentile, na.rm=T), 0))
            , nchar(round(mean(df$best_indication_percentile, na.rm=T), 0))) == '2' ~ 'nd'
    ,substr(round(mean(df$best_indication_percentile, na.rm=T), 0)
            , nchar(round(mean(df$best_indication_percentile, na.rm=T), 0))
            , nchar(round(mean(df$best_indication_percentile, na.rm=T), 0))) == '3' ~ 'rd'
    ,TRUE ~ ''
  )
  
  ggplot(data = df)+
    geom_text(aes(x=1
                  ,y=1
                  ,label = paste('Avg', paste0(round(mean(df$best_indication_percentile, na.rm=T), 0), ending), 'Percentile'))
              ,color = 'white'
              ,size = 5)+
    theme_void()+
    theme(panel.background = element_rect(color = '#002554'
                                          ,fill = '#002554'))
})

##########################
## site selection startup
##########################
output$medp_startup = renderPlotly({
  req(length(selected_hospitals()) > 0)
  df = selected_hospitals()
  
  
  # Add jitter to create beeswarm effect
  jitter_amount <- 0.1
  df$x_jitter <- 1 + runif(nrow(df), -jitter_amount, jitter_amount)
  
  plot_ly(
    data = df,
    x = ~x_jitter,
    y = ~`Expected startup weeks`,
    type = 'scatter',
    mode = 'markers',
    marker = list(
      color = 'rgba(0, 37, 84, 0.5)',
      size = 8
    ),
    text = ~paste(FINAL_NAME, "<br>Startup Wk:", `Expected startup weeks`),
    hovertemplate = "%{text}<extra></extra>",
    showlegend = FALSE
  ) %>%
    layout(
      xaxis = list(
        title = "",
        showticklabels = FALSE,
        showgrid = FALSE,
        zeroline = FALSE,
        range = c(-0.5, 2.5)
      ),
      yaxis = list(
        title = "Startup Wk<br><i>(Avg over last 3yr)</i>",
        showgrid = FALSE,
        zeroline = FALSE
      ),
      plot_bgcolor = 'white',
      paper_bgcolor = 'white',
      font = list(family = "Arial", color = "#002554")
    )
})


## average to put ontop of plotly
output$medp_startup_avg = renderPlot({
  req(length(selected_hospitals()) > 0)
  df = selected_hospitals()
  
  ggplot(data = df)+
    geom_text(aes(x=1
                  ,y=1
                  ,label = paste('Avg', round(mean(df$`Expected startup weeks`, na.rm=T), 0), 'Wks'))
              ,color = 'white'
              ,size = 5)+
    theme_void()+
    theme(panel.background = element_rect(color = '#002554'
                                          ,fill = '#002554'))
})

##########################
## site selection ind studies
##########################
output$ind_studies = renderPlotly({
  req(length(selected_hospitals()) > 0)
  df = selected_hospitals()
  
  ## best indication enrollment performance (includes benchmarked)
  
  ## confirm how indication columns will be labeled for MEDP & Medidata
  if(length(input$selecteddiseases)==1){
    ind = input$selecteddiseases
  }else{
    ind = paste(input$selecteddiseases, collapse=' & ')
  }
  
  ## which columns have percentile that isn't general
  cols = data.frame(names = colnames(df)) %>% 
    filter(grepl(ind, names, ignore.case=T) | grepl(input$medpcustomdescription, names, ignore.case=T) | grepl(input$medidatacustomdescription, names, ignore.case=T) | grepl(input$citelinecustomdescription, names, ignore.case=T)
           ,grepl('studies', names, ignore.case=T) | grepl('trials', names, ignore.case=T)
           ,!grepl('enrollment performance', names, ignore.case=T)
           ,!grepl('enrollment percentile', names, ignore.case=T))

    colposition = which(colnames(df) %in% cols$names)
  
  ## max percentile
  df = 
    df %>% 
    rowwise() %>% 
    mutate(best_indication_studies = max(c_across(colposition), na.rm=T)
           ,best_indication_studies = ifelse(best_indication_studies == '-Inf'
                                                ,NA
                                                ,as.integer(best_indication_studies))) %>% 
    ungroup()
  
  # Add jitter to create beeswarm effect
  jitter_amount <- 0.1
  df$x_jitter <- 1 + runif(nrow(df), -jitter_amount, jitter_amount)
  
  plot_ly(
    data = df,
    x = ~x_jitter,
    y = ~best_indication_studies,
    type = 'scatter',
    mode = 'markers',
    marker = list(
      color = 'rgba(0, 37, 84, 0.5)',
      size = 8
    ),
    text = ~paste(FINAL_NAME, "<br>", ind, "<br>Studies:", best_indication_studies),
    hovertemplate = "%{text}<extra></extra>",
    showlegend = FALSE
  ) %>%
    layout(
      xaxis = list(
        title = "",
        showticklabels = FALSE,
        showgrid = FALSE,
        zeroline = FALSE,
        range = c(-0.5, 2.5)
      ),
      yaxis = list(
        title = paste(ind, '<br>Studies'),
        showgrid = FALSE,
        zeroline = FALSE
      ),
      plot_bgcolor = 'white',
      paper_bgcolor = 'white',
      font = list(family = "Arial", color = "#002554")
    )
})

## average to put ontop of plotly
output$ind_studies_avg = renderPlot({
  req(length(selected_hospitals()) > 0)
  df = selected_hospitals()
  
  if(length(input$selecteddiseases)==1){
    ind = input$selecteddiseases
  }else{
    ind = paste(input$selecteddiseases, collapse=' & ')
  }
  
  ## which columns have percentile that isn't general
  cols = data.frame(names = colnames(df)) %>% 
    filter(grepl(ind, names, ignore.case=T) | grepl(input$medpcustomdescription, names, ignore.case=T) | grepl(input$medidatacustomdescription, names, ignore.case=T) | grepl(input$citelinecustomdescription, names, ignore.case=T)
           ,grepl('studies', names, ignore.case=T) | grepl('trials', names, ignore.case=T)
           ,!grepl('enrollment performance', names, ignore.case=T)
           ,!grepl('enrollment percentile', names, ignore.case=T))
  
  colposition = which(colnames(df) %in% cols$names)
  
  ## max percentile
  df = 
    df %>% 
    rowwise() %>% 
    mutate(best_indication_studies = max(c_across(colposition), na.rm=T)
           ,best_indication_studies = ifelse(best_indication_studies == '-Inf'
                                             ,NA
                                             ,as.integer(best_indication_studies))) %>% 
    ungroup()
  
  ggplot(data = df)+
    geom_text(aes(x=1
                  ,y=1
                  ,label = paste('Avg', round(mean(df$best_indication_studies, na.rm=T), 0), 'Studies'))
              ,color = 'white'
              ,size = 5)+
    theme_void()+
    theme(panel.background = element_rect(color = '#002554'
                                          ,fill = '#002554'))
})

##########################
## custom variable for plot
##########################

output$customplotvoi = renderUI({
  req(length(selected_hospitals()) > 0)
  df = selected_hospitals()
  
  cols = data.frame(names = colnames(df)) %>% 
    filter(!names %in% c("FINAL_NAME"
                        ,"ISO"))
  
  selectInput('voigraphinput'
              ,label = 'Select a custom variable to plot:'
              ,choices = cols$names
              ,multiple = F
              ,selected = NULL)
  
})

## plot it
output$custom_plot = renderPlotly({
  req(length(selected_hospitals()) > 0)
  req(input$voigraphinput)
  df = selected_hospitals()
  
  colname = input$voigraphinput
  colposition = which(colnames(df) == colname)
  
  df = df[,c(1, 2, colposition)]
  colnames(df)[3] = 'custom'
  
  
  # Add jitter to create beeswarm effect
  jitter_amount <- 0.1
  df$x_jitter <- 1 + runif(nrow(df), -jitter_amount, jitter_amount)
  
  ## need line break in approximate middle
  add_middle_break <- function(text) {
    # Check if input is valid
    if (is.na(text) || nchar(text) == 0) {
      return(text)
    }
    
    # Find all space positions
    space_positions <- gregexpr(" ", text)[[1]]
    
    # If no spaces found, return original string
    if (space_positions[1] == -1) {
      return(text)
    }
    
    # Find the middle position of the string
    middle_pos <- nchar(text) / 2
    
    # Find the space closest to the middle
    distances <- abs(space_positions - middle_pos)
    closest_space_idx <- which.min(distances)
    closest_space_pos <- space_positions[closest_space_idx]
    
    # Replace the closest space with <br>
    result <- paste0(
      substr(text, 1, closest_space_pos - 1),
      "<br>",
      substr(text, closest_space_pos + 1, nchar(text))
    )
    
    return(result)
  }
  
  plot_ly(
    data = df,
    x = ~x_jitter,
    y = ~custom,
    type = 'scatter',
    mode = 'markers',
    marker = list(
      color = 'rgba(0, 37, 84, 0.5)',
      size = 8
    ),
    text = ~paste(FINAL_NAME, "<br>", input$voigraphinput, custom),
    hovertemplate = "%{text}<extra></extra>",
    showlegend = FALSE
  ) %>%
    layout(
      xaxis = list(
        title = "",
        showticklabels = FALSE,
        showgrid = FALSE,
        zeroline = FALSE,
        range = c(-0.5, 2.5)
      ),
      yaxis = list(
        title = add_middle_break(input$voigraphinput),
        showgrid = FALSE,
        zeroline = FALSE
      ),
      plot_bgcolor = 'white',
      paper_bgcolor = 'white',
      font = list(family = "Arial", color = "#002554")
    )
})

## custom label ontop
output$customlabel = renderPlot({
  req(length(selected_hospitals()) > 0)
  
  ggplot(data = data.frame(x = 1
                           ,y = 1
                           ,label = 'Custom'))+
    geom_text(aes(x=x
                  ,y=y
                  ,label = label)
              ,color = 'white'
              ,size = 5)+
    theme_void()+
    theme(panel.background = element_rect(color = '#002554'
                                          ,fill = '#002554'))
})

##########################
## site selection list
##########################

current_selection <- reactiveVal()

# Initialize current_selection when selected_hospitals changes
observe({
  data <- selected_hospitals()
  if(length(data) > 0) {
    # Initialize with all hospitals selected
    current_selection(data$FINAL_NAME)
  } else {
    current_selection(character(0))
  }
})

# Replace your existing scrollable_list output with this:
output$scrollable_list <- renderUI({
  data <- selected_hospitals()
  
  if(length(data) == 0) {
    return(p(""))
  }
  
  # Create the scrollable select input
  tagList(
    selectInput(
      inputId = "hospital_selector",
      label = "Selected Sites:",
      choices = setNames(data$FINAL_NAME, data$FINAL_NAME),
      selected = current_selection(),
      multiple = TRUE,
      size = 7,  # This makes it scrollable by showing 10 items at once
      selectize = FALSE,  # Use basic HTML select for better scrolling
      width = "100%"
    ),
    br(),
    actionButton(
      inputId = "update_hospitals",
      label = "Remove un-selected",
      class = "btn-primary",
      style = "width: 100%;"
    )
  )
})

# Add this observer to handle the update button click
observeEvent(input$update_hospitals, {
  req(input$hospital_selector)
  
  # Get the original data
  original_data <- selected_hospitals()
  
  # Filter to only include selected hospitals
  updated_data <- original_data[original_data$FINAL_NAME %in% input$hospital_selector, ]
  
  # Update the selected_hospitals reactive value
  selected_hospitals(updated_data)
  
  # Update current_selection to match
  current_selection(input$hospital_selector)
})



##########################
## definitions button
##########################



observeEvent(input$help_btn, {
  showModal(modalDialog(
    title = "Definitions",
    div(
      h4("Columns in the Table:"),
      tags$ol(
        tags$li(strong("Cluster Name:"), " AI-model interpretation for groupings of sites based on your prior selections for variables of interest."),
        tags$li(strong("Percent Rank:"), " 0-100% score for how each site compares to the 'perfect' site (100%) across your prior selections for variables of interest."),
        tags$li(strong("Green Columns:"), " Your prior selections for variables of interest")
      ),
      br(),
      p(em("Need more help? Contact the team at informatics-group@medpace.com"))
    ),
    easyClose = TRUE,
    footer = modalButton("Close")
  ))
})


##########################
## enr projections
##########################

## require internal benchmarking for start
output$warningtext = renderText({
  if(nrow(subset(medpcustom(), !is.na(medpcustom()$UNIQUEKEY))) == 0){
    HTML("<p style='color: red;'>This module benefits from Medpace Custom benchmarked study codes from SM studies on the 'Algorithm Settings' tab</p>
         If you do not have Medpace Custom benchmarking, or prefer to use a list of study-level PSM estimates, please enter those below")
  }else{' '}
})

output$studypsm_output = renderUI({
    textAreaInput('studypsm'
                  ,HTML('Enter as many benchmarked study PSM as available<i>......line separated</i>'))
})

output$psm_input = renderUI({
  req(medpcustom())
  if(nrow(subset(medpcustom(), !is.na(medpcustom()$UNIQUEKEY))) == 0){
    choicelist = c('Use study-level PSMs input above')
  }else{
    choicelist = c("Use MEDP benchmarking from 'Algorithm Settings' page"
                   ,'Use study-level PSMs input above')}
  
  radioButtons('psminput'
                      ,'Select an option:'
                      ,choices =choicelist
                     ,selected = choicelist[1])
})


enrollprojections = reactiveVal(NULL)
siteassumptions = reactiveVal(NULL)
countryranges = reactiveVal(NULL)
simulationready = reactiveVal('not ready')


observeEvent(input$prepsimulation, {
  req(length(selected_hospitals()) > 0)
  df = selected_hospitals()

  
  ## best indication enrollment performance (includes benchmarked)
  
  ## confirm how indication columns will be labeled for MEDP & Medidata
  if(length(input$selecteddiseases)==1){
    ind = input$selecteddiseases
  }else{
    ind = paste(input$selecteddiseases, collapse=' & ')
  }
  
  ther = unique(subset(studydisease$CATEGORY
                       ,studydisease$INDICATION %in% input$selecteddiseases))
  
  if(length(ther)==1){
    ther = ther
  }else{
    ther = paste(ther, collapse=" & ")
  }
  
  ## which columns have percentile that is indication or benchmark
  indcols = data.frame(names = colnames(df)) %>% 
    filter(grepl('enrollment percentile', names, ignore.case=T)
           ,names != 'Average enrollment percentile across all Medpace trials'
           ,grepl(ind, names, ignore.case=T) | grepl(input$medpcustomdescription, names, ignore.case=T) | grepl(input$medidatacustomdescription, names, ignore.case=T))
  
  
  indcolposition = which(colnames(df) %in% indcols$names)
  
  thercols = data.frame(names = colnames(df)) %>% 
    filter(grepl('enrollment percentile', names, ignore.case=T)
           ,names != 'Average enrollment percentile across all Medpace trials'
           ,grepl(ther, names, ignore.case=T))
  
  
  thercolposition = which(colnames(df) %in% thercols$names)
  
  ## max percentile
  df = 
    df %>% 
    rowwise() %>% 
    mutate(best_indication_percentile = max(c_across(indcolposition), na.rm=T)
           ,best_indication_percentile = ifelse(best_indication_percentile == '-Inf'
                                                ,NA
                                                ,as.integer(best_indication_percentile))
           ,best_therapeutic_percentile = max(c_across(thercolposition), na.rm=T)
           ,best_therapeutic_percentile = ifelse(best_therapeutic_percentile == '-Inf'
                                                ,NA
                                                ,as.integer(best_therapeutic_percentile))) %>% 
    ungroup()
  

  if(input$psminput == "Use MEDP benchmarking from 'Algorithm Settings' page"){
      benchmarking = 
        hierarchy  %>% 
        filter(NBDPID %in% medpcustom()$UNIQUEKEY) %>% 
        left_join(sitelist %>% 
                    filter(SOURCE == 'ClinTrakSM') %>% 
                    select(SITEID
                           ,FINAL_NAME) %>% 
                    mutate(SITEID = as.integer(SITEID))
                  ,by='SITEID') %>% 
        mutate(FINAL_NAME = coalesce(FINAL_NAME
                                     ,CENTER_NAME)) %>% 
        select(FINAL_NAME
               ,ISO
               ,psm = ENRPERMO
               ,NBDPID) %>% 
        filter(!is.na(psm))
  }else{
    
    benchmarking = data.frame(NULL)
    
    iso = countrycode(input$selectedcountry
                      ,origin = 'country.name'
                      ,destination = 'iso3c')
    quantiledf = 
      hierarchy  %>%
      filter(NBDPID %in% subset(filteredstudydisease()$STUDYCODE, filteredstudydisease()$SOURCE == 'Medpace')
             ,ISO %in% iso) %>%  ## LBT NOTE, should this be restricted to all countries, or sites country?
      group_by(NBDPID) %>% 
      summarize(q0 = quantile(ENRPERMO, na.rm=T)[[1]]
                ,q1 = quantile(ENRPERMO, na.rm=T)[[2]]
                ,q2 = quantile(ENRPERMO, na.rm=T)[[3]]
                ,q3 = quantile(ENRPERMO, na.rm=T)[[4]]
                ,q4 = quantile(ENRPERMO, na.rm=T)[[5]]
                ,studypt = sum(ENROLLED, na.rm=T)
                ,studysites = n()
                ,studymo = max(ENRMO, na.rm=T)) %>% 
      ungroup() %>% 
      rowwise() %>% 
      mutate(studypsm = studypt / studysites / studymo) %>% 
      ungroup() %>% 
      filter(!is.na(q0)
             ,studysites >= 3) %>% 
      select(-c(studypt
                ,studysites
                ,studymo)) %>% 
      pivot_longer(cols = starts_with("q"), 
                   names_to = "quartile", 
                   values_to = "site_recruitment_rate")
    
    
    predict_quartiles_quantreg <- function(df_long, target_recruitment_rates) {
      # Fit quantile regression models
      tau_values <- c(0, 0.25, 0.5, 0.75, 1.0)
      
      # Fit quantile regression models once
      qr_models <- lapply(tau_values, function(tau) {
        rq(site_recruitment_rate ~ studypsm, 
           data = df_long, tau = tau)
      })
      
      # Create predictions for all target rates
      predictions_list <- lapply(target_recruitment_rates, function(rate) {
        predictions <- sapply(qr_models, function(model) {
          predict(model, newdata = data.frame(studypsm = rate))
        })
        names(predictions) <- paste0("q", 0:4)
        return(predictions)
      })
      
      # Convert to dataframe
      predictions_df <- do.call(rbind, predictions_list)
      predictions_df <- as.data.frame(predictions_df)
      predictions_df$target_recruitment_rate <- target_recruitment_rates
      
      # Reorder columns to put target rate first, and convert any predicted quartiles <0 to 0
      predictions_df <- predictions_df[, c("target_recruitment_rate", paste0("q", 0:4))] %>% 
        mutate(across(c(q0, q1, q2, q3, q4), ~pmax(.x, 0)))
      
      return(predictions_df)
    }
    
    studypsminput = strsplit(input$studypsm, '\n')[[1]]
    studypsminput = trimws(studypsminput)
    studypsminput = studypsminput[nzchar(studypsminput)]
    
    quantileresults = predict_quartiles_quantreg(quantiledf, as.numeric(studypsminput)) %>% 
      mutate(q0_avg = mean(q0, na.rm=T)
             ,q1_avg = mean(q1, na.rm=T)
             ,q2_avg = mean(q2, na.rm=T)
             ,q3_avg = mean(q3, na.rm=T)
             ,q4_avg = mean(q4, na.rm=T)) %>% 
      select(q0_avg
             ,q1_avg
             ,q2_avg
             ,q3_avg
             ,q4_avg) %>% 
      distinct()
  }
  
  startup = 
    hierarchy %>% 
    left_join(sitelist %>% 
                filter(SOURCE == 'ClinTrakSM') %>% 
                select(SITEID
                       ,FINAL_NAME) %>% 
                mutate(SITEID = as.integer(SITEID))
              ,by='SITEID') %>% 
    mutate(FINAL_NAME = coalesce(FINAL_NAME
                                 ,CENTER_NAME)
           ,yr_since_act = year(Sys.Date()) - year(as.Date(ACTIVATIONDATE))
           ,STARTUPWK = case_when(
             is.na(STARTUPWK) ~ STARTUPWK
             ,STARTUPWK < 4 ~ NA
             ,STARTUPWK > 52 & ISO != 'BRA' & ISO != 'ROU' ~ NA
             ,TRUE ~ STARTUPWK)) %>% 
    filter(yr_since_act <= 3) %>% 
    select(FINAL_NAME
           ,ISO
           ,STARTUPWK
           ,NBDPID) %>% 
    filter(!is.na(STARTUPWK))
  
  
  ## figure out PSM sample range per site and startup sample range
  df$min = NA
  df$max = NA
  df$startupearly = NA
  df$startuplate = NA
  df$benchmarkrange = NA
  
  for(i in 1:nrow(df)){
    startuptemp = startup %>% 
      filter(paste(ISO, FINAL_NAME) == paste(df$ISO[i], df$FINAL_NAME[i]))
    
    countrystartuptemp = startup %>% 
      filter(ISO == df$ISO[i])
    
    # if(nrow(subset(medpcustom(), !is.na(medpcustom()$UNIQUEKEY))) > 0){
    if(input$psminput == "Use MEDP benchmarking from 'Algorithm Settings' page"){
  temp = benchmarking %>% 
    filter(paste(ISO, FINAL_NAME) == paste(df$ISO[i], df$FINAL_NAME[i]))
  
  countrytemp = benchmarking %>% 
    filter(ISO == df$ISO[i])
  
  quantileresults = data.frame(q0_avg = NA
                               ,q1_avg = NA
                               ,q2_avg = NA
                               ,q3_avg = NA
                               ,q4_avg = NA)
  
  ## low end psm
  df$min[i] = case_when(
    
    ## LBT NOTE right side of equations are failing when using study-level PSM
    nrow(temp) >= 3 ~ min(temp$psm)
    
    ,!is.na(df$best_indication_percentile[i]) & nrow(countrytemp) >= 3 ~ 
      case_when(
        df$best_indication_percentile[i] <40 ~ quantile(countrytemp$psm)[1][[1]]
        ,df$best_indication_percentile[i] <61 ~ quantile(countrytemp$psm)[2][[1]]
        ,TRUE ~ quantile(countrytemp$psm)[3][[1]])
    
    ,!is.na(df$best_therapeutic_percentile[i]) & nrow(countrytemp) >= 3 ~
      case_when(
        df$best_therapeutic_percentile[i] <40 ~ quantile(countrytemp$psm)[1][[1]]
        ,df$best_therapeutic_percentile[i] <61 ~ quantile(countrytemp$psm)[2][[1]]
        ,TRUE ~ quantile(countrytemp$psm)[3][[1]])
    
    ,nrow(countrytemp) >= 3 ~ quantile(countrytemp$psm)[1][[1]]
    
    ,!is.na(df$best_indication_percentile[i]) & nrow(benchmarking) > 0 ~ 
      case_when(
        df$best_indication_percentile[i] <40 ~ quantile(benchmarking$psm)[1][[1]]
        ,df$best_indication_percentile[i] <61 ~ quantile(benchmarking$psm)[2][[1]]
        ,TRUE ~ quantile(benchmarking$psm)[3][[1]])
    
    ,!is.na(df$best_therapeutic_percentile[i]) & nrow(benchmarking) > 0 ~ 
      case_when(
        df$best_therapeutic_percentile[i] <40 ~ quantile(benchmarking$psm)[1][[1]]
        ,df$best_therapeutic_percentile[i] <61 ~ quantile(benchmarking$psm)[2][[1]]
        ,TRUE ~ quantile(benchmarking$psm)[3][[1]])
    
    ,TRUE ~ quantile(benchmarking$psm)[1][[1]]
  )
  
  ## high end psm
  df$max[i] = case_when(
    
    nrow(temp) >= 3 ~ max(temp$psm)
    
    ,!is.na(df$best_indication_percentile[i]) & nrow(countrytemp) >= 3 ~ 
      case_when(
        df$best_indication_percentile[i] <40 ~ quantile(countrytemp$psm)[3][[1]]
        ,df$best_indication_percentile[i] <61 ~ quantile(countrytemp$psm)[4][[1]]
        ,TRUE ~ quantile(countrytemp$psm)[5][[1]])
    
    ,!is.na(df$best_therapeutic_percentile[i]) & nrow(countrytemp) >= 3 ~ 
      case_when(
        df$best_therapeutic_percentile[i] <40 ~ quantile(countrytemp$psm)[3][[1]]
        ,df$best_therapeutic_percentile[i] <61 ~ quantile(countrytemp$psm)[4][[1]]
        ,TRUE ~ quantile(countrytemp$psm)[5][[1]])
    
    ,nrow(countrytemp) >= 3 ~ quantile(countrytemp$psm)[3][[1]]
    
    ,!is.na(df$best_indication_percentile[i]) >= 3 & nrow(benchmarking) > 0~ 
      case_when(
        df$best_indication_percentile[i] <40 ~ quantile(benchmarking$psm)[3][[1]]
        ,df$best_indication_percentile[i] <61 ~ quantile(benchmarking$psm)[4][[1]]
        ,TRUE ~ quantile(benchmarking$psm)[5][[1]])
    
    ,!is.na(df$best_therapeutic_percentile[i]) >= 3 & nrow(benchmarking) > 0~ 
      case_when(
        df$best_therapeutic_percentile[i] <40 ~ quantile(benchmarking$psm)[3][[1]]
        ,df$best_therapeutic_percentile[i] <61 ~ quantile(benchmarking$psm)[4][[1]]
        ,TRUE ~ quantile(benchmarking$psm)[5][[1]])
    
    ,nrow(benchmarking) > 0 ~ quantile(benchmarking$psm)[3][[1]]
    
    ,!is.na(df$best_indication_percentile[i]) & nrow(benchmarking) > 0 ~ 
      case_when(
        df$best_indication_percentile[i] <40 ~ quantile(benchmarking$psm)[1][[1]]
        ,df$best_indication_percentile[i] <61 ~ quantile(benchmarking$psm)[2][[1]]
        ,TRUE ~ quantile(benchmarking$psm)[3][[1]])
    
    ,!is.na(df$best_therapeutic_percentile[i]) & nrow(benchmarking) > 0 ~ 
      case_when(
        df$best_therapeutic_percentile[i] <40 ~ quantile(benchmarking$psm)[1][[1]]
        ,df$best_therapeutic_percentile[i] <61 ~ quantile(benchmarking$psm)[2][[1]]
        ,TRUE ~ quantile(benchmarking$psm)[3][[1]])
    
    ,TRUE ~ quantile(benchmarking$psm)[1][[1]]
  )
  
  df$benchmarkrange[i] = ifelse(nrow(temp) >= 3
                                ,'yes'
                                ,'no')
  
  
    }else{
      temp = data.frame(NULL)
      countrytemp = data.frame(NULL)
      
      df$min[i] = case_when(
      !is.na(df$best_indication_percentile[i]) ~
        case_when(
          df$best_indication_percentile[i] <40 ~ quantileresults$q0_avg
          ,df$best_indication_percentile[i] <61 ~ quantileresults$q1_avg
          ,TRUE ~ quantileresults$q2_avg)
      
      ,!is.na(df$best_therapeutic_percentile[i]) ~
        case_when(
          df$best_therapeutic_percentile[i] <40 ~ quantileresults$q0_avg
          ,df$best_therapeutic_percentile[i] <61 ~ quantileresults$q1_avg
          ,TRUE ~ quantileresults$q2_avg)
      
      ,TRUE ~ quantileresults$q0_avg)
      
      df$max[i] = case_when(
        !is.na(df$best_indication_percentile[i]) ~ 
          case_when(
            df$best_indication_percentile[i] <40 ~ quantileresults$q2_avg
            ,df$best_indication_percentile[i] <61 ~ quantileresults$q3_avg
            ,TRUE ~ quantileresults$q4_avg)
        
        ,!is.na(df$best_therapeutic_percentile[i]) ~ 
          case_when(
            df$best_therapeutic_percentile[i] <40 ~ quantileresults$q2_avg
            ,df$best_therapeutic_percentile[i] <61 ~ quantileresults$q3_avg
            ,TRUE ~ quantileresults$q4_avg)
        
        ,TRUE ~ quantileresults$q2_avg
      )
      
      df$benchmarkrange[i] = NA
      
    }

  ## earliest startup
  df$startupearly[i] = case_when(
    nrow(startuptemp) >= 3 ~ min(startuptemp$STARTUPWK)
    ,nrow(countrystartuptemp) >= 3 ~ min(countrystartuptemp$STARTUPWK)
    ,TRUE ~ min(startuptemp$STARTUPWK))
  
  ## latest startup
  df$startuplate[i] = case_when(
    nrow(startuptemp) >= 3 ~ max(startuptemp$STARTUPWK)
    ,nrow(countrystartuptemp) >= 3 ~ quantile(countrystartuptemp$STARTUPWK)[2][[1]]
    ,TRUE ~ quantile(startuptemp$STARTUPWK)[2][[1]])
  
  }
  
  ## if no startup data available, use default +/- 20% for country
  df =
    df %>% 
    left_join(defaultstartup
              ,by=join_by("ISO"=="iso3c")) %>% 
    mutate(startupearly = case_when(
      is.na(startupearly) ~ floor(0.8 * default)
      ,startupearly == Inf ~ floor(0.8 * default)
      ,startupearly == -Inf ~ floor(0.8 * default)
      ,TRUE ~ startupearly)
      ,startuplate = case_when(
        is.na(startuplate) ~ ceiling(1.2 * default)
        ,startuplate == Inf ~ ceiling(1.2 * default)
        ,startuplate == -Inf ~ ceiling(1.2 * default)
        ,TRUE ~ startuplate
      ))
  

  
  
  ## default settings for below, avg, and above sites
  countryrangesdf = data.frame(NULL)
  if(nrow(benchmarking) > 0){
    for(country in unique(df$ISO)){
      
      countrytemp = benchmarking %>% 
        filter(ISO == country)
      
      countryrangesdf[nrow(countryrangesdf)+1,'ISO'] = country
      
      countryrangesdf[nrow(countryrangesdf),'belowlow'] = 
        ifelse(nrow(countrytemp)>=3
               , quantile(countrytemp$psm)[1][[1]]
               , quantile(benchmarking$psm)[1][[1]])
      
      countryrangesdf[nrow(countryrangesdf),'belowhigh'] = 
        ifelse(nrow(countrytemp)>=3
               , quantile(countrytemp$psm)[3][[1]]
               , quantile(benchmarking$psm)[3][[1]])
      
      countryrangesdf[nrow(countryrangesdf),'avglow'] = 
        ifelse(nrow(countrytemp)>=3
               , quantile(countrytemp$psm)[2][[1]]
               , quantile(benchmarking$psm)[2][[1]])
      
      countryrangesdf[nrow(countryrangesdf),'avghigh'] = 
        ifelse(nrow(countrytemp)>=3
               , quantile(countrytemp$psm)[4][[1]]
               , quantile(benchmarking$psm)[4][[1]])
      
      countryrangesdf[nrow(countryrangesdf),'abovelow'] = 
        ifelse(nrow(countrytemp)>=3
               , quantile(countrytemp$psm)[3][[1]]
               , quantile(benchmarking$psm)[3][[1]])
      
      countryrangesdf[nrow(countryrangesdf),'abovehigh'] = 
        ifelse(nrow(countrytemp)>=3
               , quantile(countrytemp$psm)[5][[1]]
               , quantile(benchmarking$psm)[5][[1]])
    }
    
  }else{
    countryrangesdf[nrow(countryrangesdf)+1,'ISO'] = NA
    countryrangesdf[nrow(countryrangesdf),'belowlow'] = quantileresults$q0_avg
    countryrangesdf[nrow(countryrangesdf),'belowhigh'] = quantileresults$q2_avg
    countryrangesdf[nrow(countryrangesdf),'avglow'] = quantileresults$q1_avg
    countryrangesdf[nrow(countryrangesdf),'avghigh'] = quantileresults$q3_avg
    countryrangesdf[nrow(countryrangesdf),'abovelow'] = quantileresults$q2_avg
    countryrangesdf[nrow(countryrangesdf),'abovehigh'] = quantileresults$q4_avg
  }
  
  ## update the reactiveval
  countryranges(countryrangesdf)
  
  if(input$psminput == "Use MEDP benchmarking from 'Algorithm Settings' page"){
  output$rangecountry = renderUI({
    selectInput(
      'rangecountryselect'
      ,'Country:'
      ,choices = c('', sort(unique(df$ISO)))
      ,selected = sort(unique(df$ISO))[1]
      ,width = '100%'
      ,multiple = F)
  })
  }else{}
  
  output$simulatebutton = renderUI({
    actionButton('simulate', 'Simulate enrollment')
  })
  
  output$iterationinput = renderUI({
    numericInput('iterations'
                 ,'Iterations:'
                 ,value = 10000
                 ,min = 100
                 ,max = 10000
                 ,step = 1)
  })

  siteassumptions(df)
})

output$simulationranges = renderUI({
  req(countryranges())
  req(input$rangecountryselect)
  req(nchar(input$rangecountryselect) > 0)  # Ensure it's not just an empty string
  
  country_data = countryranges() %>% 
    filter(ISO == input$rangecountryselect)
  
  # Validate that we found matching data
  if(nrow(country_data) == 0) {
    return(div(
      h4("No data available"),
      p(paste("No simulation data found for country:", input$rangecountryselect))
    ))
  }
  
  tagList(
    h4(paste('Sliders for', input$rangecountryselect)),
    
    sliderInput(
      inputId = paste0("below_range_", input$rangecountryselect),
      label = "PSM Range for below average sites:",
      min = 0,
      max = 10,
      step = 0.01,
      value = c(country_data$belowlow, country_data$belowhigh)
    ),
    
    sliderInput(
      inputId = paste0("avg_range_", input$rangecountryselect),
      label = "PSM Range for average sites:",
      min = 0,
      max = 10,
      step = 0.01,
      value = c(country_data$avglow, country_data$avghigh)
    ),
    
    sliderInput(
      inputId = paste0("above_range_", input$rangecountryselect),
      label = "PSM Range for above average sites:",
      min = 0,
      max = 10,
      step = 0.01,
      value = c(country_data$abovelow, country_data$abovehigh)
    ),
    
    actionButton('submitcountryrange', 'Submit updated range')
  )
})

observeEvent(input$submitcountryrange, {
  df = countryranges()
  
  # Get current slider values
  below_lowval <- input[[paste0("below_range_", input$rangecountryselect)]][1]
  avg_lowval <- input[[paste0("avg_range_", input$rangecountryselect)]][1]
  above_lowval <- input[[paste0("above_range_", input$rangecountryselect)]][1]
  
  below_highval <- input[[paste0("below_range_", input$rangecountryselect)]][2]
  avg_highval <- input[[paste0("avg_range_", input$rangecountryselect)]][2]
  above_highval <- input[[paste0("above_range_", input$rangecountryselect)]][2]
  

    row_index <- which(df$ISO == input$rangecountryselect)
    
      df$belowlow[row_index] <- below_lowval
      df$belowhigh[row_index] <- below_highval
      df$avglow[row_index] <- avg_lowval
      df$avghigh[row_index] <- avg_highval
      df$abovelow[row_index] <- above_lowval
      df$abovehigh[row_index] <- above_highval
      
      # Update the reactive value
      countryranges(df)
  
})  


  

observeEvent(input$simulate, {
  
  df = siteassumptions()
  cdf = countryranges()
  # below = input$below_range
  # avg = input$avg_range
  # above = input$above_range
  
  for(i in 1:nrow(df)){
    
    country = df$ISO[i]
    
    if(is.na(cdf$ISO[1])){
      below = c(cdf$belowlow
                ,cdf$belowhigh)
      
      avg = c(cdf$avglow
              ,cdf$avghigh)
      
      above = c(cdf$abovelow
                ,cdf$abovehigh)
      
    }else{
    below = c(cdf$belowlow[which(cdf$ISO == country)]
              ,cdf$belowhigh[which(cdf$ISO == country)])
    
    avg = c(cdf$avglow[which(cdf$ISO == country)]
              ,cdf$avghigh[which(cdf$ISO == country)])
    
    above = c(cdf$abovelow[which(cdf$ISO == country)]
            ,cdf$abovehigh[which(cdf$ISO == country)])}
    
    
    ## low end psm
    df$min[i] = case_when(
      
      df$benchmarkrange[i] == 'yes' ~ df$min[i]
      
      ,!is.na(df$best_indication_percentile[i]) ~ case_when(
        df$best_indication_percentile[i] <40 ~ below[1]
        ,df$best_indication_percentile[i] <61 ~ avg[1]
        ,TRUE ~ above[1]
      )
      
      
      ,!is.na(df$best_therapeutic_percentile[i]) ~ case_when(
        df$best_therapeutic_percentile[i] <40 ~ below[1]
        ,df$best_therapeutic_percentile[i] <61 ~ avg[1]
        ,TRUE ~ above[1]
      )
      
      ,TRUE ~ below[1]
    )
    
    
    ## high end psm
    df$max[i] = case_when(
      
      df$benchmarkrange[i] == 'yes' ~ df$max[i]
      
      ,!is.na(df$best_indication_percentile[i]) ~ case_when(
        df$best_indication_percentile[i] <40 ~ below[2]
        ,df$best_indication_percentile[i] <61 ~ avg[2]
        ,TRUE ~ above[2]
      )
      
      
      ,!is.na(df$best_therapeutic_percentile[i]) ~ case_when(
        df$best_therapeutic_percentile[i] <40 ~ below[2]
        ,df$best_therapeutic_percentile[i] <61 ~ avg[2]
        ,TRUE ~ above[2]
      )
      
      ,TRUE ~ below[2]
    )
    
  }
  
  ## convert to weekly rate (psw)
  df$min = df$min*(12/52)
  df$max = df$max*(12/52)
  
  
  goal = input$goal
  
  
  ## base build for each iteration should be max 200mo
  rows = ceiling(200*(52/12))

  
  ## iterate
  iterations = data.frame(iteration = 1:(input$iterations)
                          #iteration = 1:10000
                          ,weeks = NA
                          ,patients = NA)
  
  withProgress(message = 'Running Simulations', value = 0, {
  for(n in 1:nrow(iterations)){
    montecarlo = data.frame(week = seq(1:rows))
      for(i in 1:nrow(df)){
        montecarlo[,ncol(montecarlo)+1] = sample(seq(from = df$min[i], to=df$max[i], by=0.01), 1)
        
        ## block out startup weeks
        montecarlo[1:sample(seq(from = df$startupearly[i], to=df$startuplate[i]),1),ncol(montecarlo)] = NA
      }
      
      montecarlo$total = rowSums(montecarlo[, 2:ncol(montecarlo)], na.rm=T)
      montecarlo$cumulative = cumsum(montecarlo$total)
      montecarlo = montecarlo[1:(max(which(montecarlo$cumulative <= goal))+1),]
      
      ## evaluate active weeks
      montecarlo$active = rowSums(!is.na(montecarlo[, 2:(ncol(montecarlo)-2)]))
      montecarlo$active = ifelse(montecarlo$active > 0, 1, 0)
      
      iterations$weeks[n] = sum(montecarlo$active)
      iterations$patients[n] = list(subset(montecarlo$cumulative, montecarlo$active==1))
      # print(n) ## temp for confirmation
      # Update progress bar
      if(n %% 100 == 0) {  # Update every 100 iterations to avoid too frequent updates
        incProgress(100/nrow(iterations), detail = paste("Iteration", n, "of", prettyNum(nrow(iterations))))
      }
    
  }
  })
  
  
  enrollprojections(iterations)
  
  
  simulationready('ready')
  siteassumptions(df)
  
})

############################
## iterations plot
############################

output$iterationsplot = renderPlot({
  req(enrollprojections())
  df = enrollprojections()
  
  ggplot(data = df %>% group_by(weeks) %>% summarize(simulations = n()) %>% ungroup())+
    geom_point(aes(x = weeks
                   ,y = simulations)
               ,color = '#002554')+
    theme_void()+
    theme(axis.text.x = element_text(color='#002554'
                                     ,family ='Arial'
                                     ,size = 20)
          ,axis.title.x = element_text(color='#002554'
                                      ,family ='Arial'
                                      ,size = 20)
          ,plot.caption = element_text(color='#002554'
                                       ,family ='Arial'
                                       ,hjust=0.98
                                       ,size = 20)
          ,panel.background = element_blank()
          ,plot.background = element_blank())+
    xlab('Weeks to achieve goal')+
    geom_vline(xintercept = median(df$weeks)
               ,color ='#6cca98')+
    geom_text(aes(x = median(df$weeks)+1
                  ,y = max(df %>% group_by(weeks) %>% summarize(simulations = n()) %>% ungroup() %>% select(simulations))
                  ,label = paste('Median:', median(df$weeks), 'weeks'))
              ,color = '#6cca98'
              ,hjust=0
              ,size = 10)+
    labs(caption = '\nEach dot represents the weeks it took\nto achieve the goal in its simulation.\n10K simulations were conducted')
}, bg='transparent')

###############################
## assumptions table
###############################

output$assumptionstable = renderDataTable({
  req(simulationready() == 'ready')
  df = siteassumptions() %>% 
    mutate(minpsm = round(min*(52/12),3)
           ,maxpsm = round(max*(52/12),3)) %>% 
    select(FINAL_NAME
           ,ISO
           ,`PSM Range from Benchmarking` = benchmarkrange
           ,`Min PSM` = minpsm
           ,`Max PSM` = maxpsm
           ,`Min Startup` = startupearly
           ,`Max Startup` = startuplate)
  
  datatable(df
            ,extensions = 'Buttons',
            options = list(
              dom = 'Blfrtip'
              ,buttons = c('excel')
              ,paging = F
              ,searching = F
              ,scrollY = '250px'
              ,scrollCollapse = T))
})



############################
## enr curve
############################

output$enrollmentcurve = renderPlot({
  req(enrollprojections())
  
  df = enrollprojections()
  
  q1 = quantile(df$weeks)[2][[1]]
  q2 = quantile(df$weeks)[3][[1]]
  q3 = quantile(df$weeks)[4][[1]]
  
  q2plotdf = data.frame(week = 1:q2)
  q2df = df[which(df$weeks == q2),]
  for(i in 1:nrow(q2df)){
    
    q2plotdf[,ncol(q2plotdf)+1] = unlist(q2df[i,'patients'])
  }
  q2plotdf$avg = rowMeans(q2plotdf[,2:ncol(q2plotdf)], na.rm=T)
  
  
  
  q1plotdf = data.frame(week = 1:q1)
  q1df = df[which(df$weeks == q1),]
  for(i in 1:nrow(q1df)){
    
    q1plotdf[,ncol(q1plotdf)+1] = unlist(q1df[i,'patients'])
  }
  q1plotdf$avg = rowMeans(q1plotdf[,2:ncol(q1plotdf)], na.rm=T)
  
  
  
  q3plotdf = data.frame(week = 1:q3)
  q3df = df[which(df$weeks == q3),]
  for(i in 1:nrow(q3df)){
    
    q3plotdf[,ncol(q3plotdf)+1] = unlist(q3df[i,'patients'])
  }
  q3plotdf$avg = rowMeans(q3plotdf[,2:ncol(q3plotdf)], na.rm=T)
  

  ggplot(data = q1plotdf %>%
           select(week
                  ,avg) %>%
           mutate(group = 'Aggressive') %>%
           bind_rows(q2plotdf %>%
                       select(week
                              ,avg) %>%
                       mutate(group = 'Average')) %>%
           bind_rows(q3plotdf %>%
                       select(week
                              ,avg) %>%
                       mutate(group = 'Conservative')))+
    geom_line(aes(x = week
                   ,y = avg
                   ,group = group
                  ,color = group
                  ,size = group))+
    geom_text(data = data.frame(x = c(q1, q2, q3)
                                ,y = c(Inf, Inf, Inf)
                                ,label = paste(c(q1, q2, q3))
                                ,group = c('Aggressive'
                                           ,'Average'
                                           ,'Conservative')
                                ,hjust = c(0, 0.5, 1))
              ,aes(x = x
                  ,y = y
                  ,label = label
                  ,color = group)
              ,vjust=1
              ,size=8
              ,show.legend = F)+
    scale_color_manual(values=c('Aggressive' = 'black'
                                ,'Average' = '#6cca98'
                                ,'Conservative' = '#006098'))+
    scale_size_manual(values=c('Aggressive' = 0.75
                                ,'Average' = 2
                                ,'Conservative' = 0.75))+
    theme_void()+
    theme(legend.position = 'bottom'
          ,legend.title = element_blank()
          ,legend.text = element_text(color = '#002554'
                                      ,family ='Arial'
                                      ,size = 20)
          ,axis.text = element_text(color = '#002554'
                                    ,family ='Arial'
                                    ,size = 20)
          ,axis.title = element_text(color = '#002554'
                                     ,family ='Arial'
                                     ,size = 20)
          ,axis.title.y = element_text(color = '#002554'
                                       , angle=90
                                       ,family ='Arial'
                                       ,size = 20)
          ,panel.background = element_blank()
          ,plot.background = element_blank()
          ,plot.caption = element_text(color = '#002554'
                                    ,family ='Arial'
                                    ,size = 10))+
    labs(x = 'Weeks\n'
         ,y = 'Enrolled\n'
         ,caption = 'Aggressive, Average, and Conservative curves are determined by Q1, Median, and Q3 from the 10K iterations.')
  
  
  
  
}, bg = 'transparent')

}





################################################################################
## app
################################################################################

shinyApp(ui, server)

## notes for future dev, from MCP
# grabbing feasibility responses
# sites accuracy in enrollment projection should be a future variable
# sites on a map
# naming of columns