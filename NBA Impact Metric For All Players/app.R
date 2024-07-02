# Load necessary libraries
library(tidyverse)
library(nbastatR)
library(dplyr)
library(shiny)


# Collecting 2023 season data from nbastatR and putting it into a dataframe called main_data
main_data <- nbastatR::game_logs(
  seasons = 2024, 
  league = "NBA", 
  result_types = "player", 
  season_types = "Regular Season", 
  nest_data = FALSE, 
  assign_to_environment = TRUE, 
  return_message = TRUE
)

# Aggregating the player statistics
player_stats <- main_data %>%
  group_by(namePlayer) %>%
  summarize(
    AvgPoints = mean(pts, na.rm = TRUE),
    AvgFieldGoalAttempts = mean(fga, na.rm = TRUE),
    AvgFreeThrowAttempts = mean(fta, na.rm = TRUE),
    AvgAssists = mean(ast, na.rm = TRUE), 
    AvgTurnovers = mean(tov, na.rm = TRUE), 
    AvgOffensiveRebounds = mean(oreb, na.rm = TRUE),
    AvgDefensiveRebounds = mean(dreb, na.rm = TRUE),
    AvgSteals = mean(stl, na.rm = TRUE),
    AvgBlocks = mean(blk, na.rm = TRUE),
    AvgMinutesPlayed = mean(minutes, na.rm = TRUE)
  )

# Define the UI
ui <- fluidPage(
  titlePanel("NBA Player Composite Impact Rating"),
  tags$h3("See how much your favorite NBA player impacts the game!"),
  sidebarLayout(
    sidebarPanel(
      selectInput("player", "Select a Player:", choices = unique(player_stats$namePlayer)),
      sliderInput("alpha", "Weight for Scoring Efficiency (SE):", min = 0, max = 2, value = 1, step = 0.1),
      sliderInput("beta", "Weight for Playmaking Ability (PA):", min = 0, max = 2, value = 1, step = 0.1),
      sliderInput("gamma", "Weight for Rebounding Impact (RI):", min = 0, max = 2, value = 1, step = 0.1),
      sliderInput("delta", "Weight for Defensive Presence (DP):", min = 0, max = 2, value = 1, step = 0.1),
      sliderInput("epsilon", "Weight for Versatility Index (VI):", min = 0, max = 2, value = 1, step = 0.1)
    ),
    mainPanel(
      tableOutput("playerTable"),
      plotOutput("cirPlot"),
      tags$h5("Note: CIR below 4 means low impact, CIR above 4 means high impact.")
    )
  )
)



# Define the server logic
server <- function(input, output) {
  player_data <- reactive({
    player_stats %>%
      filter(namePlayer == input$player) %>%
      mutate(
        SE = AvgPoints / (AvgFieldGoalAttempts + 0.44 * AvgFreeThrowAttempts),
        PA = AvgAssists / AvgTurnovers,
        RI = (AvgOffensiveRebounds + AvgDefensiveRebounds) / AvgMinutesPlayed,
        DP = (AvgSteals + AvgBlocks) / AvgMinutesPlayed,
        VI = (AvgPoints + AvgAssists + AvgOffensiveRebounds + AvgDefensiveRebounds + AvgSteals + AvgBlocks) / AvgMinutesPlayed,
        CIR = input$alpha * SE + input$beta * PA + input$gamma * RI + input$delta * DP + input$epsilon * VI
      )
  })
  
  output$playerTable <- renderTable({
    player_data() %>% select(namePlayer, SE, PA, RI, DP, VI, CIR) %>%
    rename("Player Name" = namePlayer) 
  })
  
  output$cirPlot <- renderPlot({
    selected_player <- player_data()
    
    # Reshape data into long format
    cir_components <- selected_player %>%
      select(SE, PA, RI, DP, VI) %>%
      pivot_longer(cols = everything(), names_to = "Component", values_to = "Value")
    
    # Create ggplot bar plot
    ggplot(cir_components, aes(x = Component, y = Value, fill = Component)) +
      geom_bar(stat = "identity") +
      labs(
        title = paste("CIR Components for", input$player),
        y = "Value",
        x = "Component"
      ) +
      theme_minimal() +
      theme(legend.position = "none")
  })
}

# Run the application
shinyApp(ui = ui, server = server)


          