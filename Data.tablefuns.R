'%notin%'<-Negate('%in%')

####Converts lists and named vectors to data.tables with column names###
listrep2datatable_fn<-function(X,left_varname=NULL,right_varname=NULL){
  require(data.table)
  if(is.null(left_varname)){left_varname="V1"} else{left_varname=left_varname}
  if(is.null(right_varname)){right_varname="V2"} else{right_varname=right_varname}
  if(!is.list(X)) {
    if(is.vector(X)&&!is.null(names(X))){
      New_item_vector<-setnames(data.table(data.frame(X),keep.rownames = T),c(left_varname,right_varname))
    } else {stop("Need to enter a list of named vectors")}
  } else {
    X<-lapply(lapply(X,function(i) t(t(i))),data.table)
    New_item_vector<-rbindlist(lapply(seq_along(X),function(i) setnames(X[[i]][,V2:=rep(names(X)[i],sapply(X,nrow)[i])],c(right_varname,left_varname))))
  } 
  return(New_item_vector)
}

numeric_converter<-function(X){
  X<-ifelse(sum(is.na(suppressWarnings(as.numeric(X))))==length(X),0,1)
 return(X)
}

Proper_Name_fn<-function(X){
  X<-ifelse(is.na(X),NA,paste0(toupper(substring(X,1,1)),tolower(substring(X,2,nchar(X)))))
  return(X)
}

Inconsistency_check<-function(X){
  #X is a melted data.table of two merged data.tables that have the same "variables" and "values" column names from defaults assumes you melted by the ID variable.
  IDvar<-colnames(X)[1]
  uniquevar<-unique(gsub("^i.","",grep("^i",X$variable,value = T)))
  melted_lists<-setattr(lapply(lapply(uniquevar,function(i) X[grep(i,variable),]),function(j) dcast(j,paste(IDvar,"~","variable"))),"names",uniquevar)
  test_results<-lapply(melted_lists,function(i) all.equal(i[,2,with=F],i[,3,with=F],check.attributes=F))
  print(test_results)
  return(melted_lists)
}

Create_excel_fn<-function(datatlists,sheetnames,filename){
  require(openxlsx)
  if(is.list(datatlists)==F){stop("Need to enter as lists")}
  if(is.list(sheetnames)==F){sheetnames=as.list(sheetnames)}
  if(grepl(".xlsx$",filename)==F){stop("Enter proper filename *.xlsx")}
  wb<-createWorkbook()
  invisible(lapply(unlist(sheetnames),function(i) addWorksheet(wb,i)))
  invisible(lapply(seq_along(sheetnames),function(i) writeData(wb,unlist(sheetnames)[i],datatlists[[i]])))
  saveWorkbook(wb,filename,overwrite = T)
  
}

Missingness_fn<-function(datatable,IDname,numvarspergraph=20){
  require(ggplot2)
  ID=IDname
  if(is.null(ID)){stop("Please input ID column")}
  IDcol<-unname(unlist(copy(datatable)[,ID,with=F]))
  y=numvarspergraph
  X<-copy(datatable)[,-ID,with=F]
  X<-copy(X)[,colnames(X):=lapply(.SD,function(i) as.numeric(is.na(i))),.SDcols=colnames(X)]
  Percent_missing<-setorder(setkey(setnames(data.table(round(data.frame(t(X[,lapply(.SD,function(i) mean(i)*100)])),4),keep.rownames = "Variable"),2,"Percent.Missing"),Percent.Missing),-Percent.Missing)
  Graphs_plot_ind<-suppressWarnings(copy(Percent_missing)[,Var_subset:=rep(paste0("Graph",seq_along(seq(1,nrow(copy(Percent_missing)),y))),rep(y,length(seq_along(seq(1,nrow(copy(Percent_missing)),y)))))])
  Miss_patterns<-data.table(t(X[,colnames(X):=lapply(.SD,function(i) car::recode(i,"1='X'"))]))[,lapply(.SD,function(i) paste0(i,collapse = ""))]
  Pattern<-setnames(data.table(sort(table(unlist(Miss_patterns)),decreasing = T)),"V1","Pattern")
  Percent_plot<-lapply(split(Graphs_plot_ind,Graphs_plot_ind$Var_subset), function(i) ggplot(data=i,aes(x=Variable,y=Percent.Missing))+geom_point()+coord_flip()+theme_bw())
  Miss_pat_tmp<-copy(datatable)[,Miss_patterns:=c(t(Miss_patterns))][,Miss_patterns:=factor(Miss_patterns,levels=names(sort(table(Miss_patterns),decreasing = T)))]

  Missing_names_sum<-lapply(lapply(lapply(seq_along(levels(Miss_pat_tmp$Miss_patterns)),function(i) unlist(strsplit(levels(Miss_pat_tmp$Miss_patterns)[i],""))),function(j) setNames(j,colnames(X))),function(k) names(which(k=="X")))
  
  return(list(Percent_missing=Percent_missing[,Percent.Missing:=paste0(Percent.Missing,"%")],Missing_counts=Pattern,Percent_plot=Percent_plot,datatable=Miss_pat_tmp,Miss_pat_labels=Missing_names_sum))
}

Odds_ratio_fn<-function(glmmodel){
  est<-exp(coef(glmmodel))
  var.diag<-diag(vcov(glmmodel))
  std.error=sqrt(est^2 * var.diag)
  results<-data.table(summary(glmmodel)$coef,keep.rownames = "Parameters")[,Estimate:=est][,`Std. Error`:=std.error][,c(2:5):=lapply(.SD,function(i) round(i,4)),.SDcols=c(2:5)]
  return(results)
}


char_quote_fn<-function(X,sep_char=","){
  options(useFancyQuotes = F)
  X<-cat(dQuote(unlist(lapply(unlist(strsplit(X,sep_char)),function(i) list(trimws(i))),recursive = F)),sep=",")
  
}

indicator_converter<-function(X,IDvars=NULL,verbose=T){
  require(data.table)
  X<-data.table(X)
  if(!is.null(IDvars)){
    X_noid<-copy(X)[,-IDvars,with=F][,lapply(copy(.SD),function(i) if(is.character(i)|is.factor(i)){as.factor(i)} else{as.numeric(i)})]
    } else {
      X_noid<-copy(X)[,lapply(copy(.SD),function(i) if(is.character(i)|is.factor(i)){as.factor(i)} else{as.numeric(i)})]
      }
  categorical_vars<-names(which(sapply(X_noid,is.factor)))
  if(length(categorical_vars)>0){
    if(verbose){
      cat("Assuming the following are the only factors you need to convert:")
      char_quote_fn(categorical_vars)
      cat("\n")
      }
    cat_ref<-paste0(categorical_vars,unlist(lapply(categorical_vars,function(i) levels(copy(X_noid)[[i]])[1])))
    
    categorical_list<-lapply(categorical_vars,function(i) data.table(data.frame(model.matrix(as.formula(paste("~",i)),model.frame(X_noid,na.action = na.pass)))))
categorical_expand<-Reduce(cbind,lapply(seq_along(categorical_list),function(i) categorical_list[[i]][,cat_ref[i]:=1*(rowSums(copy(.SD))==1)][,-"X.Intercept.",with=F]))
  if(!is.null(IDvars)){
    if(length(X_noid[,-categorical_vars,with=F])>0){
Comb_data<-cbind(X[,IDvars,with=F],X_noid[,-categorical_vars,with=F],categorical_expand)
    } else {
      Comb_data<-cbind(X[,IDvars,with=F],categorical_expand)
      }
    } else {
      if(length(X_noid[,-categorical_vars,with=F])>0){
        Comb_data<-cbind(X_noid[,-categorical_vars,with=F],categorical_expand)
        } else {
          Comb_data<-categorical_expand
        }
    }

  return(Comb_data)
  } else {
  warning("No categorical variables detected. You need to convert the variables of interest to factors before the indicator_converter function can be used.",call. = F)
    return(X)
  }
}


###Used to extract name of the dataframe in match.call() if it is complicated (i.e., removing certain column names on the fly without having to store it first) Case 1: X[["Hi"]]; Case 2: data.table(X[["Hi"]]); Case 3: data.table(data.frame(X)); Case 4: data.table(X["Hi"]["Hey"])

pairlist_converter<-function(X){
  if(tryCatch(as.name(X),error=function(e) 1)==1){
    if(grepl("^c\\(",deparse(X)[1])){##If call is entered as a character vector it retrieves elements
      X<-as.character(trimws(gsub("\\)","",gsub('\\"',"",gsub("^c\\(","",unlist(strsplit(deparse(X),split=",")))))))
      } else {##More complex entry
        X_tmp<-unlist(strsplit(gsub("\\(|\\)"," ",as.list(X))," "))#First Split by parenthesis
        X_tmp2<-unlist(lapply(X_tmp,function(i) strsplit(i,'\\"')))#Second by quotes
        X_tmp3<-unlist(lapply(X_tmp2,function(i) strsplit(i,"\\]")))#Third by brackets
        if(sum(grepl("\\[",X_tmp3))>0){##If there is subsetting
          X_tmp3_brack<-X_tmp3[c(which(grepl("\\[",X_tmp3)))]
          if(sum(grepl("^\\w",X_tmp3_brack))==0&&grepl("\\[",X_tmp)[1]==F){##Case where data is wrapped by another function before subsetting
            X_tmp4<-X_tmp3[c(which(grepl("\\[",X_tmp3)))[1]-1]
            } else {##Case where it is not wrapped first(i.e., "X[," exists)
              if(sum(grepl("^\\w",X_tmp3_brack))==0){
                X_tmp4<-tryCatch(X_tmp3[max(which(grepl("data.table|data.frame|tbl_df",X_tmp3)))+1],warning=function(w) 1) ##Subsetting but no wrapping
                if(X_tmp4==1){ ##In case the user enters one subsetting
                  X_tmp4<-X_tmp3[2]
                  }
                } else{
                  X_tmp3_brack_words<-X_tmp3_brack[which(grepl("^\\w",X_tmp3_brack))]
                  X_tmp4<-unlist(strsplit(X_tmp3_brack_words,"\\["))[1]
                }##Subsetting and wrapping around subsetting and multiple subsetting
              }
          X<-X_tmp4
          } else{##No subsetting but function wrapping
            X<-X_tmp[length(X_tmp)]
          }
        }
    } else {
      X<-X
      }##Allows for sloppy data.table syntax while still being able to detect the name of the data table.
  return(X)
}

orig_call_fn<-function(X){##X needs to be a specific element of the current function's match.call()
  X<-as.list(match.call(sys.function(which=1),call = sys.call(which=1)))[[X]]
}

text_print<-function(X,filename=NULL,verbose=T){
  if(is.null(filename)){
    tablename<-pairlist_converter(as.list(match.call())$X)
    } else tablename<-filename
    
    write.table(X,paste0(tablename,".txt"),sep=",",row.names = F,quote = F)
    if(verbose){
      print(paste0("Writing ",sQuote(tablename)," to",getwd()))
    }
}


rev_indicator_converter<-function(X,ind_name,IDvars=NULL){
  #X is data.table and Ind_name is a char vector of stems for recombining cat variables
  Bin_names<-colnames(X)
  if(is.null(IDvars)){
    Bin_names_list<-Reduce(cbind,lapply(seq_along(ind_name),function(i) suppressWarnings(melt(data.table(X)[,grep(ind_name[i],Bin_names,value = T),with=F],variable.name=ind_name[i],variable.factor=F))[,ind_name[i]:=gsub(eval(ind_name[i]),"",eval(as.name(ind_name[i])))][value==1][,-c("value"),with=F]))
  } else {
    Bin_names_list<-Reduce(function(...) merge(...,by=IDvars),lapply(seq_along(ind_name),function(i) melt(X[,c(IDvars,grep(ind_name[i],Bin_names,value = T)),with=F],id.vars=IDvars,variable.name=ind_name[i],variable.factor=F)[,ind_name[i]:=gsub(ind_name[i],"",eval(as.name(ind_name[i])),fixed=T)][value==1][,-c("value"),with=F]))
  }
  return(Bin_names_list)
}

Global_name_gen<-function(namevector,dataframe_name){
  if(is.list(namevector)){
      namevector<-as.character(unlist(namevector))
  }
  count=0
  repeat{
    base_names<-lapply(seq_along(namevector),function(i) paste(namevector[i],count+1,as.character(dataframe_name),sep="_"))
    count=count+1
    if(exists(base_names[[1]],envir=.GlobalEnv)==F){break}
  }
  return(base_names)
}

#####This function controls the conversion of categorical variables to numeric variables####18:02 
cat2facNum_converter_fn<-function(varname,ref="default",verbose=T){
  ll<-substitute(varname)
  ll_name<-as.name(pairlist_converter(ll))
  ##Processing how varname was entered.
  if(sys.nframe()==1){##If called from Global Environment
    ll_name_check<-tryCatch(sum(grepl("data",class(eval(ll_name)))),error=function(e) -1)
    if(ll_name_check>0){##Dataframe notation
      ll_name<-as.character(ll)[which(as.character(ll)%notin%c(as.character(ll_name),"[["))]
      if(length(ll_name)>1){##Case where it is a data.frame notation (i.e., X[,"var"])
        blank_elements<-which(as.character(ll)%in%c(""))
        ll_name<-as.name(as.character(ll)[-c(which(grepl("\\W",as.character(ll))),blank_elements)])}
    } else if(ll_name_check==-1){##Atomic vector notation
      ll_name<-pairlist_converter(ll)
    } else{##Current environment variable call (not in a data frame)
      ll_name<-as.name(ll_name)
    }
  } else{##If called within another function
    ll<-varname
  }
  if(is.numeric(eval(ll))){
    ll_val<-factor(eval(ll))
    if(ref!="default"){
      ll_val<-factor(ll_val,levels=c(ref,levels(eval(ll_val))[-match(ref,levels(eval(ll_val)))]))
    }
    if(verbose){
      print(paste(sQuote(ll_name),"is not a factor.  Assuming",levels(ll_val)[1],"will be the reference group."))
    }###End of numeric loop
  } else if(is.factor(eval(ll))){
    if(ref!="default"){
      ll_val<-factor(eval(ll),levels=c(ref,levels(eval(ll))[-match(ref,levels(eval(ll)))]))
      if(verbose){
        print(paste0(sQuote(ll_name)," was already a factor. Set reference variable to ",sQuote(ref)," as requested."))
      }
    } else{
      ll_val<-eval(ll)
      if(verbose){
        print(paste0(sQuote(ll_name)," was already a factor. No changes made."))
      }
    }####End of factor loop
  } else{
    ll_val<-factor(eval(ll))
    if(ref!="default"){
      ll_val<-factor(ll_val,levels=c(ref,levels(eval(ll_val))[-match(ref,levels(eval(ll_val)))]))
    }
    if(verbose){
      print(paste0("Converted ",sQuote(ll_name)," to class factor with reference category ",sQuote(levels(ll_val)[1]),"."))
    }
  }
  if(sum(is.na(ll_val))!=0){
    warning(paste0("The reference variable you specified is not found in ",sQuote(ll_name),". Conversion resulted in NAs."),call. = F)
  }
  
  return(ll_val)
}
