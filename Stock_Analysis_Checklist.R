# From this source
# http://www.winninginvesting.com/stock_analysis_checklist.htm

library(quantmod)
#library(tidyquant)
library(tidyverse)
library(rvest)
library(xml2)
library(glue)
library(tibble)
library(data.table)
library(scales)

# tidyquant: https://cran.r-project.org/web/packages/tidyquant/vignettes/TQ01-core-functions-in-tidyquant.html

## Part 1: Basic Research ##

# 0. Get company name and description
company <- c("TWTR")

# Company name
cmpny.name <- paste0("https://www.marketwatch.com/investing/Stock/", stck,"/profile") %>% 
  read_html() %>%
  html_nodes(xpath='//*[(@id = "instrumentname")]') %>%
  html_text() %>% 
  enframe(name = NULL)

# Company description
cmpny.desc <- paste0("https://www.marketwatch.com/investing/Stock/", stck,"/profile") %>% 
  read_html() %>%
  html_nodes(xpath='//*[contains(concat( " ", @class, " " ), concat( " ", "limited", " " ))]') %>%
  html_text() %>% 
  enframe(name = NULL)  

# Bind name and description
cmpy <- cbind(cmpny.name,cmpny.desc)

## OUTPUT 1##
# Rename column names from above table 
names(cmpy) <- c('Company Name','Description')


# 1. One-year Price chart with 50-day moving average
# List all available metrics from Yahoo finance
# O.K. to buy if stock price is above its 50-day moving average.


# use getsymbols() to convert a char
stck <- getSymbols(company)

# charting
stockEnv <- new.env()
symbols <- getSymbols(stck, src='yahoo', env=stockEnv)

# O.K. to buy if stock price is above its 50-day moving average.

## OUTPUT 1 A##

for (stock in ls(stockEnv)){
chartSeries(stockEnv[[stock]], theme="white", name=stock,
TA="addVo(); addSMA(50, col='black')", subset='last 365 days')
}

# 2. Price/Sales ratio (P/S)
# O.K. to buy if P/S is less than 10. 
# P/S ratios between 3 and 5 are best for growth stocks.
# Ratios below 2 reflect value priced stocks.  

key.statistics <- paste0("https://finance.yahoo.com/quote/", stck, "/key-statistics?p=", stck) %>%
  read_html() %>%
  html_table() %>%
  map_df(bind_cols) %>%
  # Transpose
  t() %>%
  as_tibble()

# Set first row as column names
colnames(key.statistics) <- key.statistics[1,]
# Remove first row
key.statistics <- key.statistics[-1,]
# Add Stock Ticker as a column
key.statistics$'Stock Ticker' <- stck
key.statistics[6]

# 3. Cash Flow
# O.K. to buy if Cash Flow is a positive number.

cash.flow <- glue("https://www.marketwatch.com/investing/Stock/",{company},"/profile/") %>%
  read_html() %>%
  html_nodes(xpath='//*[@class="sixwide addgutter"]') %>%
  html_nodes(xpath='//*[@class="section"]') %>%
#   html_nodes(xpath='//*[@class="column"]') %>% .[[10]] %>%
#  html_text() %>%
  html_nodes(xpath='//*[@class="data lastcolumn"]') %>% .[[8]] %>%
  html_text() %>% 
  enframe(name = NULL)


names(cash.flow) <- c('Cash Flow') 

# 4. Average Daily Volume (shares)
# O.K. to buy if Average Daily Volume is 150,000 shares or higher, and above one million shares is best.
key.statistics[17]


# 5. Fundamental Health Grade
# www.Investorplace.com

stock.health  <- paste("https://investorplace.com/stock-quotes/", stck, "-stock-quote/") %>%
  read_html() %>%
  html_nodes(xpath='//*[@class="stock-aside"]') %>%
  html_nodes(xpath='//*[@class="grade grade-color"]') %>%
  html_nodes(xpath='//*[@class="grade-color stock-grade-rating"]') %>%
  html_text() %>% 
  enframe(name = NULL)

names(stock.health) <- c('Stock Health') 

# 6. Got Growth?
# Best case is when year-over-year (YoY) growth is accelerating.
key.statistics[46]

# 7.Institutional Ownership
# O.K. to buy if percent held by institutions is at least 30% of shares outstanding.
key.statistics[22]

# 8. Number of Analysts Making Buy/Hold/Sell Recs.
# O.K. to buy if a total of at least 4 analysts are listed 
# as currently making strong buy, buy, hold, underperform, or sell recommendations. 
# Look only at the total number of analysts making recommendations, 
# not whether there are more buys than holds, etc. 

# Extract and transform data
recs <- paste0("https://www.marketwatch.com/investing/Stock/", stck, "/analystestimates") %>%
  read_html() %>%
  html_table() %>%
  map_df(bind_cols) %>%
  # Transpose
  t() %>%
  as_tibble()

recs <- recs[1:2,1:5]
# Set first row as column names
colnames(recs) <- recs[1,]
# Remove first row
recs <- recs[-1,]
# Add stock name column
recs$Stock_Name <- stock
recs[2]
recs[1]

## Create the Analytics Base Table (ABT), to be published on a dashboard ##
################
################

# Append parts

abt <- cbind(key.statistics[60],key.statistics[6],cash.flow,
           key.statistics[17], stock.health, key.statistics[46],
           key.statistics[22],recs[2])

names(abt) <- c('Stock Ticker',
              'Price/Sales ratio (P/S)', 
              'Cash Flow', 
              'Average daily volume (shares)',
              'Fundamental Health Grade',
              'Got Growth?',
              'Institutional Ownership',
              'Number of Analysts making recommendations'
              )
# Create a row with reasons per metric
row.why <- c('Stock Ticker',
             'Valuation check. A stock with a P/S above 10 is momentum priced. Buying momentum priced stocks is only recommended in a strong market',
             'Companies with positive operating cash flow are safer investments than cash burners (negative cash flow).', 
             'Institutional buying is an important catalyst for share price growth.
             Institutions buy hundreds of thousands of shares and prefer stocks with
             large daily trading volumes so they can easily move in and out of positions.',
             'Invest, don’t gamble! Stick with companies with solid fundamentals.',
             'Consistent strong sales growth over extended periods translates to long term stock price appreciation.',
             'Lack of institutional ownership means mutual funds, pension plans and other institutional
             buyers don’t think they will make money owning the stock.
             Why would you want to own it?',
             'A company’s performance will go unrewarded if nobody knows about it.
             Sufficient analyst coverage is essential to create investor interest,
             especially from institutions.'
             )

# Create a row with actions per metric

row.action <- c('Stock Ticker',
                'O.K. to buy if P/S is less than 10. P/S ratios between 3 and 5 are best for growth stocks.
                Ratios below 2 reflect value priced stocks.',
                'O.K. to buy if Cash Flow is a positive number.', 
                'O.K. to buy if Average Daily Volume is 150,000 shares or higher, and above one million shares is best.',
                'O.K. to buy if Fundamental Grade = A, B or C',
                'O.K. to buy if recent quarterly growth numbers are 8% min. (higher is better). Best case is when year-over-year
                (YoY) growth is accelerating.',
                'O.K. to buy if percent held by institutions is at least 30% of shares outstanding.',
                'O.K. to buy if a total of at least 4 analysts are listed as currently making strong buy, buy, hold,
                underperform, or sell recommendations. Look only at the total number of analysts making recommendations,
                not whether there are more buys than holds, etc.'
                )
# Bind together abt to the action and reason per metric
abt <- rbind(abt, row.why, row.action)

# ABT column names as DF
n <- as.data.frame(colnames(abt))

# Transpose ABT
t.abt <- as.data.frame(t(abt))

#Bind column nameas a 1st column and transposed ABT
part1.abt <- cbind(n,t.abt)

## OUTPUT 2##
# Final ABT
# Rename column names from above table 
names(part1.abt) <- c('What is the metric','Values','Reason', 'Action')

## Part 2: Advanced Research & Analysis ##

# 1. Gross Margin Trend
# Increasing gross margins signal an improving competitive position, and
# declining margins warn of increasing competition.
# O.K. to buy if the trend is flat or increasing (best).
# Ignore variations of less than 1%, e.g. from 41% to 40.5%.

# Quarterly Income Statement
incstat.qtr <- paste0("https://www.marketwatch.com/investing/Stock/", stck, "/financials/income/quarter") %>%
  read_html() %>%
  html_table() %>%
  map_df(bind_cols)

#Subsetting the table into 2 tables
incstat.qtr10 <-   incstat.qtr[is.na(incstat.qtr[,1]),]
incstat.qtr20 <-   incstat.qtr[!is.na(incstat.qtr[,1]),1:6]

#table 1, rearranging columns
incstat.qtr11 <- cbind(incstat.qtr10[8],incstat.qtr10[2:6])

# renaming 1st column
names(incstat.qtr20)[1] <- "account_name"
names(incstat.qtr11)[1] <- "account_name"

# appending the 2 tables from above section
incstat.qtr <- rbind(incstat.qtr20,incstat.qtr11)

# Select account name "Gross Income Growth"
part2.1.gig <- incstat.qtr[grep("Gross Income Growth", incstat.qtr[,1]),]

# 2.Revenue (sales) Growth Rate Latest Quarter compared
# to previous quarter & most recent year.
# Compare the most recent quarter's (MRQ) year-overyear sales growth rate to previous
# quarters and to the most recent year.
# Ideally, revenue growth would be accelerating or at least equal to earlier numbers.
# But, it's O.K. to buy if MRQ growth is at least 75% of recent growth numbers

# Yearly income statement
incstat.yr <- paste0("https://www.marketwatch.com/investing/Stock/", stck, "/financials") %>%
  read_html() %>%
  html_table() %>%
  map_df(bind_cols)

#Subsetting the table into 2 tables
incstat.yr10 <-   incstat.yr[is.na(incstat.yr[,1]),]
incstat.yr20 <-   incstat.yr[!is.na(incstat.yr[,1]),1:6]

#table 1, rearranging columns
incstat.yr11 <- cbind(incstat.yr10[8],incstat.yr10[2:6])

# renaming 1st column
names(incstat.yr20)[1] <- "account_name"
names(incstat.yr11)[1] <- "account_name"

# appending the 2 tables from above section
incstat.yr <- rbind(incstat.yr20,incstat.yr11)

# Quarterly sales growth
part2.2.qtr.revg <- incstat.qtr[grep("Sales Growth", incstat.qtr[,1]),]

# Yearly sales growth
part2.2.yr.revg <- incstat.yr[grep("Sales Growth", incstat.yr[,1]),]

#3. Forecast Revenue Growth Rate
# Compare consensus revenue growth forecasts to historical numbers.

key.analysis <- paste0("https://finance.yahoo.com/quote/", stck, "/analysis?p=", stck) %>%
  read_html() %>%
  html_table()


# Revenue Estimate data frame
rev.est <- data.frame(key.analysis[2])

# revenue estimate growth
part2.3.rev.est.grw <- rev.est[grep("Growth", rev.est[,1]),]

#4. Accounts receivables growth vs sales growth
# Accounts Receivables Ratio (ratio) is the total receivables 
# divided by the revenue for the same quarter
# ratio for the most recent and the year-ago quarters
# Ideally the most recent ratio would be less than yearago, but it's O.K. to
# buy if the ratio is the same or lower than year-ago. 
# Ignore increases that are less than 5%, e.g. from 60% to 64%

################  Extraction + Transformation section ################  
################
################

# Balance Sheet - yearly
bs.yr <- paste0("https://www.marketwatch.com/investing/Stock/", stck, "/financials/balance-sheet") %>% 
  read_html() %>% 
  html_table() %>% 
  map_df(bind_cols)

#Subsetting the table into 2 tables
bs.yr10 <-   bs.yr[is.na(bs.yr[,1]),]
bs.yr20 <-   bs.yr[!is.na(bs.yr[,1]),1:6]

#table 1, rearranging columns
bs.yr11 <- cbind(bs.yr10[8],bs.yr10[2:6])

# renaming 1st column on both tables
names(bs.yr20)[1] <- "account_name"
names(bs.yr11)[1] <- "account_name"

## appending the 2 tables from above subsetting section 
bs.yr <- rbind(bs.yr20,bs.yr11)

# Select account name "accounts receivable"
bs.yr.ar <- bs.yr[grep("Total Accounts Receivable", bs.yr[,1]),]

# select revenue from Income Statement yearly
rev.yr <- incstat.yr[grep("Revenue", incstat.yr[,1]),]

# Balance Sheet quarterly
bs.qtr <- paste0("https://www.marketwatch.com/investing/Stock/", stck, "/financials/balance-sheet/quarter") %>% 
  read_html() %>% 
  html_table() %>% 
  map_df(bind_cols)

#Subsetting the table into 2 tables
bs.qtr10 <-   bs.qtr[is.na(bs.qtr[,1]),]
bs.qtr20 <-   bs.qtr[!is.na(bs.qtr[,1]),1:6]

#table 1, rearranging columns
bs.qtr11 <- cbind(bs.qtr10[8],bs.qtr10[2:6])

# renaming 1st column on both tables
names(bs.qtr20)[1] <- "account_name"
names(bs.qtr11)[1] <- "account_name"

## appending the 2 tables from section row 146
bs.qtr <- rbind(bs.qtr20,bs.qtr11)

# Select account name "accounts receivable"
bs.qtr.ar <- bs.qtr[grep("Total Accounts Receivable", bs.qtr[,1]),]

# select revenue from Inc Statement yearly
rev.qtr <- incstat.qtr[grep("Revenue", incstat.qtr[,1]),]

################  Calculation section ################  

################ accounts receivable ################
################
################

# Transpose data
bs.qtr.ar.t <- as.data.frame(t(bs.qtr.ar))

#move rowname to be 1st column
setDT(bs.qtr.ar.t, keep.rownames = TRUE)[]

#set AR column to be character
bs.qtr.ar.t[]<- lapply(bs.qtr.ar.t, as.character)
bs.qtr.ar.t <- cbind(rownames(bs.qtr.ar.t), data.frame(bs.qtr.ar.t, row.names=NULL))
colnames(bs.qtr.ar.t) <- bs.qtr.ar.t[1,]

#move row1 to be column name
bs.qtr.ar.t <- bs.qtr.ar.t[-1, ] 

#remove first column
bs.qtr.ar.t <- bs.qtr.ar.t[-1]

#remove character within numbers
bs.qtr.ar.t[2] <- as.numeric(gsub("\\M", "", bs.qtr.ar.t$`Total Accounts Receivable`)) 

################ Sales ################
################
################
# Transpose data
rev.qtr.t <- as.data.frame(t(rev.qtr))

#move rowname to be 1st column
setDT(rev.qtr.t, keep.rownames = TRUE)[]

#set AR column to be character
rev.qtr.t[]<- lapply(rev.qtr.t, as.character)
rev.qtr.t <- cbind(rownames(rev.qtr.t), data.frame(rev.qtr.t, row.names=NULL))
colnames(rev.qtr.t) <- rev.qtr.t[1,]

#move row1 to be column name
rev.qtr.t <- rev.qtr.t[-1, ] 

#remove first column
rev.qtr.t <- rev.qtr.t[-1]

#remove character within numbers
rev.qtr.t[2] <- as.numeric(gsub("\\M", "", rev.qtr.t$`Sales/Revenue`)) 

#Join AR to Sales
ar.sales <- inner_join(bs.qtr.ar.t,rev.qtr.t, by="account_name")
ar.sales$ratio <- percent(round(ar.sales$`Total Accounts Receivable`/ar.sales$`Sales/Revenue`, digits = 3))
ar.sales <- ar.sales %>% select("account_name","ratio")

# ABT column names as DF
n <- as.data.frame(colnames(ar.sales))

# Transpose ABT
t.ar.sales <- as.data.frame(t(ar.sales))

#Bind column nameas a 1st column and transposed ABT
part2.4.ar.sales <- cbind(n,t.ar.sales)

#convert from factor to character
part2.4.ar.sales[] <- lapply(part2.4.ar.sales, as.character)
names(part2.4.ar.sales) <- lapply(part2.4.ar.sales[1,], as.character)

#move row1 to be column name
part2.4.ar.sales <- part2.4.ar.sales[-1, ] 

#rename cell title 
part2.4.ar.sales[1,1] <- "Ratio AR to Sales"

## Create the Analytics Base Table (ABT), to be published on a dashboard ##
################
################

# Append parts 1,2,3,4 

part2.abt <- rbind(part2.1.gig
                   , part2.2.qtr.revg
                  # , part2.3.rev.est.grw
                  , part2.4.ar.sales)
