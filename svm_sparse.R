library(readr)
library(Metrics)
library(tm)
library(SnowballC)
library(e1071)
library(Matrix)
library(SparseM)

# Get the data
train = read_csv("Data/train.csv")
test  = read_csv("Data/test.csv")

ids = test$id
rtrain = nrow(train)
rtest =nrow(test)

relevance = as.factor(train$median_relevance)
variance = train$relevance_variance

# We don't need you anymoreeee
train$median_relevance = NULL
train$relevance_variance = NULL

# Combine train and test set for the dragons
combi=rbind(train,test)


# clean up the data
clean_data = function(string){
  garbage = c("<.*?>", "http", "www",
    "[.#@][a-zA-Z0-9_,. \\-\\s#,:>]*[\\s]*\\{.*?\\}",
    "[a-zA-Z0-9_, \\s]*[\\s]*\\{.*?\\}",
    "text-decoration:.*?;","text-align:.*?;",
    "font-family:.*?;","font-size:.*?;","color:.*?;","margin:.*?;",
    "padding:.*?;","width:.*?;","height:.*?;","display:.*?;","float:.*?;",
    "font-weight:.*?;","list-style:.*?;","list-style-type:.*?;",
    "border:.*?;",
    "Seller assumes all responsibility for this listing.",
    "Last updated on",
    "html, body, div, span, applet, object,.*?HTML5 display-role reset for older browsers",
    "This translation tool is for your convenience only.*?Note: The accuracy and accessibility of the resulting translation is not guaranteed")
  for (i in 1:length(garbage)){
    string = gsub(garbage[i], "", string)
  }
  return (string)
}

combi$product_description = lapply(combi$product_description,clean_data)

#-------------------------------------------------------------------------------------
# Feature Engineering
# Here be Dragons

# Create Vector Space Model for query, product_title and product_description
all_text <- Corpus(VectorSource(combi$query))
dtm<-DocumentTermMatrix(all_text,control=list(tolower=TRUE,removePunctuation=TRUE,
                                              removeNumbers=TRUE,stopwords=TRUE,
                                              stemming=TRUE,weighting=function(x) weightTfIdf(x,normalize=T)))
dtm <- removeSparseTerms(dtm,0.999)
df_q<-Matrix(as.matrix(dtm),sparse=T)
df_q<-as.data.frame(as.matrix(dtm))
colnames(df_q)=paste("q_",colnames(df_q),sep="")

all_text <- Corpus(VectorSource(combi$product_title))
dtm<-DocumentTermMatrix(all_text,control=list(tolower=TRUE,removePunctuation=TRUE,
                                              removeNumbers=TRUE,stopwords=TRUE,
                                              stemming=TRUE,weighting=function(x) weightTfIdf(x,normalize=T)))
dtm <- removeSparseTerms(dtm,0.999)
df_pt<-Matrix(as.matrix(dtm),sparse=T)
df_pt<-as.data.frame(as.matrix(dtm))
colnames(df_pt)=paste("pt_",colnames(df_pt),sep="")

all_text <- Corpus(VectorSource(combi$product_description))
dtm<-DocumentTermMatrix(all_text,control=list(tolower=TRUE,removePunctuation=TRUE,
                                              removeNumbers=TRUE,stopwords=TRUE,
                                              stemming=TRUE,weighting=function(x) weightTfIdf(x,normalize=T)))
dtm <- removeSparseTerms(dtm,0.9995)
df_pd<-as.data.frame(as.matrix(dtm))
colnames(df_pd)=paste("pd_",colnames(df_pd),sep="")

# Combine all columns into a single dataframe
combi=cbind(df_q,df_pt,df_pd)

# Get rid of the garbage
#rm(df_q)
#rm(df_pt)
#rm(df_pd)
#rm(all_text)
#rm(corpus)
#rm(dtm)

# Create sparse matrix
combi<-Matrix(as.matrix(combi),sparse=T)

#-------------------------------------------------------------------------------------
# Apply model and predict
train = combi[1:10158,]
test = combi[10159:32671,]

rm(combi)

# - use cross-validation to pick the cost parameter (default: 10-folds)
#   > scaling leads to much better results??? w/out=38, w/
#df_train <- data.frame()
#tune_svm <- tune(svm, relevance~., data=as.matrix(train), kernal="linear", ranges=list(gamma = 2^(-1:1), cost = 2^(0:2)))
# - print the cross-validation errors for each model
#summary(tune_svm)
# - tune fxn stores the best model obtained
#fit_svm_tune <- tune_svm$best.model
#summary(fit_svm_tune)

model <- svm(train,relevance, kernel="linear", cost=.75)

tpred = as.data.frame(ids)
pred <- predict(model,test)
tpred$prediction  <- pred
colnames(tpred)=c("id","prediction")
write.csv(tpred,"Output/svm_sparse_model_9.csv",row.names=F)

print("Everthing done and your coffee is cold")
