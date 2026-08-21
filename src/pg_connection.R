# -----------------------------------------------------------------------------
# pg_connection.R — Postgres connection helper.
# Credentials are read from environment variables (see .env.example at repo root).
# -----------------------------------------------------------------------------
library(RPostgres)

db_host     <- Sys.getenv("PGHOST", "localhost")
db_port     <- Sys.getenv("PGPORT", "5432")
db_name     <- Sys.getenv("PGDATABASE", "twitter")
db_user     <- Sys.getenv("PGUSER", "postgres")
db_password <- Sys.getenv("PGPASSWORD", "")

con <- dbConnect(
  RPostgres::Postgres(),
  host     = db_host,
  port     = db_port,
  dbname   = db_name,
  user     = db_user,
  password = db_password
)
