library(rhandsontable)
library(shiny)
library(shinyjs)
library(plyr)
library(dplyr)
library(data.table)
library(ggplot2)
library(reshape2)
library(plotrix)
library(stats)

server <- function(input, output, session) {
  
  #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  #+++++++++++++++++    Initialize TAB     +++++++++++++++++++
  #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  init_table <- function(input) {
    
    col_names <-
      input$CF %>% strsplit(., ",") %>% 
      lapply(., trimws) %>% 
      unlist() %>% 
      rep(., each = input$rep)
    
    row_names <-
      input$RF %>% 
      strsplit(., ",") %>% 
      lapply(., trimws) %>% 
      unlist()
    
    data <-
      matrix(
        data = 0,
        nrow = length(row_names),
        ncol = length(col_names),
        dimnames = list(row_names, col_names)
      )
  }
  
  #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  #+++++++++++++++    Capture curr TAB     +++++++++++++++++++
  #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  capture_curr_df <- function(input) {
    live_table <- isolate(input$mytable)
    row_names <-
      input$RF %>% strsplit(., ",") %>% lapply(., trimws) %>% unlist()
    if (!is.null(live_table)) {
      dfin <- hot_to_r(input$mytable) %>% 
        as.data.frame(., row.names = row_names) %>% 
        t(.) %>% 
        melt(data = .)
      names(dfin) <- c("CF", "RF", "value")
      return(dfin)
    }
    
  }
  
  #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  #++++++++++++++++   Freeze/Unfreeze     ++++++++++++++++++++
  #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  observeEvent(input$freeBtn, {
    disable("CF")
    disable("RF")
    disable("rep")
  })
  
  observeEvent(input$unfBtn, {
    enable("CF")
    enable("RF")
    enable("rep")
  })
  
  #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  #+++++++++++++++    Compute modules     ++++++++++++++++++++
  #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  
  getaovmodel <- function(dfin) {
    return(aov(value ~ CF * RF, data=dfin))
  }
  
  get_pairwise_t_test_values <- function(dfin) {
    fdata<-dfin
    fdata$CFRF <- with(dfin, interaction(RF,  CF))
    return(pairwise.t.test(fdata$value, fdata$CFRF, p.adjust.method = "none"))
  }
  
  #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  #+++++++++++++++    Reactive ANOVA     +++++++++++++++++++++
  #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  
  text_aov_reactive <- eventReactive(input$goBtn, {
    dfin <- capture_curr_df(input)
    aov.model<-getaovmodel(dfin)
    print(aov.model)
    br()
    br()
    cat("++++++++++++++++++++++++++++++++++++++++++++++++++++\n")
    print(summary(aov.model))
    br()
    br()
    cat("++++++++++++++++++++++++++++++++++++++++++++++++++++\n")
    cat("\n"); cat("Coefficients"); cat("\n")
    print(aov.model$coefficients)
  })
  
  #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  #+++++++++++++++    Reactive Fisher     ++++++++++++++++++++
  #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  
  text_fisher_reactive <- eventReactive(input$goBtn, {
    dfin <- capture_curr_df(input)
    get_fisher<-get_pairwise_t_test_values(dfin)
    print(get_fisher)
  })
  
  #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  #+++++++++++++++    Reactive barPlot     +++++++++++++++++++
  #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  
  data_summary <- function(data, varname, groupnames){
    summary_func <- function(x, col){
      c(mean = mean(x[[col]], na.rm=TRUE),
        sd = sd(x[[col]], na.rm=TRUE))
    }
    data_sum<-ddply(data, groupnames, .fun=summary_func,
                    varname)
    data_sum <- rename(data_sum, c("mean" = varname))
    return(data_sum)
  }
  
  bar_plot_reactive <- eventReactive(input$goBtn, {
    dfin <- capture_curr_df(input)
    df3 <- data_summary(dfin, varname="value", 
                        groupnames=c("CF", "RF"))
    
    # Standard deviation of the mean as error bar
    p <- ggplot(df3, aes(x=RF, y=value, fill=CF)) + 
      geom_bar(stat="identity", position=position_dodge()) +
      # geom_text(aes(label=round(value,1)), vjust=1.6, color="white",
      #           position = position_dodge(0.9), size=3.5) +
      geom_errorbar(aes(ymin=value-sd, ymax=value+sd), width=.2,
                    position=position_dodge(.9))
    
    p + scale_fill_brewer(palette="Paired") + theme_minimal()
  })
  
  #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  #+++++++++++++++    Outputs to UI     ++++++++++++++++++++++
  #+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  # Output table
  output$mytable <- renderRHandsontable({
    rhandsontable(
      reactive(init_table(input))(),
      useTypes = T,
      stretchH = "all",
      rowHeaderWidth = 200
    )
  })
  
  output$anovatable <- renderPrint({
    text_aov_reactive()
  })
  
  output$barPlot <- renderPlot({
    bar_plot_reactive()
  }) 
  
  output$fischertable <- renderPrint({
    text_fisher_reactive()
  })
  
}

ui <- fluidPage(
  useShinyjs(),
  titlePanel("Two-way ANOVA analysis"),
  tags$head(tags$script(src = "message-handler.js")),
  sidebarLayout(
    sidebarPanel(
      textInput("CF", "Column factors separated by comma", "Control, Group A"),
      numericInput(
        "rep",
        "# observations per column factor",
        value = 2,
        min = 2,
        max = 1000
      ),
      textInput("RF", "Row factors separated by comma", "Analysis 1, Analysis 2"),
      actionButton("freeBtn", "Freeze"),
      actionButton("unfBtn", "Unfreeze"),
      actionButton("goBtn", "Calculate")
    ),
    mainPanel(
      tabsetPanel(
        tabPanel("Input Dataset", rHandsontableOutput("mytable")),
        tabPanel("ANOVA Table",verbatimTextOutput("anovatable")),
        tabPanel("Fisher Table",verbatimTextOutput("fischertable")),
        tabPanel("Bar charts",plotOutput("barPlot"))
      )
    )
    
  )
)

shinyApp(ui = ui, server = server)