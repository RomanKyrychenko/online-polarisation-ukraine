# install.packages("devtools")
devtools::install_github("samterfa/openai")

#Sys.setenv(openai_organization_id = {your_organization_id})
Sys.setenv(openai_secret_key = "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")

Sys.setenv(openai_secret_key = "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")

library(openai)
library(purrr)

list_models() %>% 
  pluck('data') %>% 
  map_dfr(compact) %>% 
  View()


c(list(role="system", content="You are a helpful assistant."))
#[
#  {"role": "system", "content": "You are a helpful assistant."},
#  {"role": "user", "content": "Who won the world series in 2020?"},
#  {"role": "assistant", "content": "The Los Angeles Dodgers won the World Series in 2020."},
#  {"role": "user", "content": "Where was it played?"}
#]

content <- readr::read_file("input.txt")

res <- create_chat_completion(model = 'gpt-4o-mini', 
                       max_tokens = 400,
                       temperature = .8,
                       top_p = 1,
                       n = 1,
                       stream = F, 
                       messages = list(list(role="system", content=content))
                       ) 

cat(res$choices[[1]]$message$content)



for (i in c(
  "1. Social, political and technological changes as stimuli for the development of sociology in the second half of the 20th and 21st centuries.",
  "2. Discussions regarding the intellectual crisis, the academic and public status of modern sociology (P. Shtompka, M. Buravoy, I. Selenii, M. Vevyorka, I. Wallerstein)",
  "3. Strengths and weaknesses of the sociological approach in understanding social phenomena and processes",
  "4. Intellectual challenges of modern society and answers of sociologists",
  "5. Thematic directions of sociological research, actualized by modern global and local social changes",
  "6. The phenomenon of ideological and theoretical pluralism in modern sociology",
  "7. Epistemological content of the concepts paradigm of social facts and paradigm of social definitions (based on the work of J. Ritzer Modern Sociological Theories)",
  "8. Leading cognitive orientations in modern theoretical sociology: the specifics of scientific, humanitarian and technological (social engineering) orientations",
  "9. Influence of theoretical approaches and paradigms on scientific sociological research",
  "10. Comparison of the main research paradigms in sociology, their heuristic possibilities and limitations",
  "11. The role of theoretical and empirical methods in conducting sociological research",
  "12. Modern scientific ideas regarding the specifics, types and strategies of the theoretical synthesis of macrosociological paradigms",
  "13. Globalization as a cognitive stimulus for the conceptual development of sociology beyond the boundaries of societies (U. Beck, E. Giddens, J. Urry)",
  "14. B. Latour on the development of social networks as a stimulus for a radical rethinking of the ontological characteristics of sociality concept",
  "15. The phenomenon of individualized society and changes in the balance between I and We (N. Elias, Z. Bauman)"
)) {
  res <- create_chat_completion(model = 'gpt-3.5-turbo', 
                                max_tokens = 3897,
                                temperature = .5,
                                top_p = 1,
                                n = 1,
                                stream = F, 
                                messages = list(list(role="system", content=paste0("Give me a long and detailed answer on this question:\n", i)))
  ) 
  
  cat(res$choices[[1]]$message$content)
} 


for (i in c(
  "1. Basic methodological principles of scientific research in sociology.",
  "2. Strategy for overcoming threats to obtain scientifically based results of sociological research.",
  "3. Basic quality criteria of sociological research.",
  "4. Comparison of the main types of sociological research design, their cognitive capabilities and limitations.",
  "5. Cognitive possibilities and limitations of the latest methods of scientific research in modern sociology.",
  "6. Basic ethical requirements for planning and conducting sociological research.",
  "7. Methodological principles and differences of quantitative, qualitative and mixed types of sociological research",
  "8. Models and methods of quantitative sociological research",
  "9. Models and methods of qualitative sociological research",
  "10. Choosing a model and method of data analysis in quantitative, qualitative and mixed sociological research",
  "11. Multiple linear regression model. Using nominal variables as factors (independent variables) in a linear regression model.",
  "12. Binary logistic regression model: general view of the equation, interpretation of regression coefficients, comparison of the influence of individual factors, evaluation of the models conformity to empirical data.",
  "13. The model of log-linear analysis: main stages, model of independence, saturated model, assessment of conformity of the model to empirical data, effects and their interpretation, hierarchy.",
  "14. Comparison of cognitive abilities and application of exploratory and confirmatory factor analysis"
)) {
  res <- create_chat_completion(model = 'gpt-3.5-turbo', 
                                max_tokens = 3897,
                                temperature = .5,
                                top_p = 1,
                                n = 1,
                                stream = F, 
                                messages = list(list(role="system", content=paste0("Give me a long and detailed answer on this question:\n", i)))
  ) 
  cat(i)
  cat(res$choices[[1]]$message$content)
  cat("\n")
} 


create_completion(
  model = 'davinci', 
  max_tokens = 100,
  temperature = .5,
  top_p = 1,
  n = 1,
  stream = F, 
  prompt = 'Social polarization in Ukraine is') %>% 
  pluck('choices') %>% 
  map_chr(~ .x$text)

library(base64enc)

target <- "Portrait of Dr. Past Liver. he'll say when in the past data from the same user it has been mentioned again."

out <- create_image(
  #model = 'dall-e-3',
  prompt = target, 
  n = 4, 
  response_format = "b64_json")

out <- create_image(
  #model = 'dall-e-3',
  prompt = target, 
  n = 4, 
  size="256x256",
  response_format = "url")

y <- out$data %>% unlist() 

for (i in 1:length(y)){
  outconn <- file(paste0(target, i, ".webp"), "wb")
  base64decode(what=y[i], output=outconn)
  close(outconn)
}

purrr::map(1:length(y), ~download.file(y[.], destfile=paste0("polarization_in_usa", y[.], ".png"), ,method='curl'))

ellmer


library(readr)
library(jsonlite)
library(base64enc)
library(httr)

# Read system prompt from file
content <- readr::read_file("input.txt")

# Encode image (change to your image path)
image_path <- "~/Downloads/chatbot_fabric_updated-Botpress_plus_BE.drawio.png"
image_base64 <- base64enc::base64encode(image_path)
image_data_uri <- paste0("data:image/png;base64,", image_base64)

# Construct messages with image
messages <- list(
  list(role = "system", content = content),
  list(
    role = "user",
    content = list(
      list(type = "image_url", image_url = list(url = image_data_uri))
    )
  )
)

# API request
res <- httr::POST(
  url = "https://api.openai.com/v1/chat/completions",
  add_headers(Authorization = paste("Bearer", Sys.getenv("openai_secret_key"))),
  encode = "json",
  body = list(
    model = "gpt-4o-2024-05-13",
    messages = messages,
    max_tokens = 4000,
    temperature = 0.5,
    top_p = 1,
    n = 1,
    stream = FALSE
  )
)

# Parse and print response
res_content <- content(res, as = "parsed", type = "application/json")
cat(res_content$choices[[1]]$message$content)

                                       