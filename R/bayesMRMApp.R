#' @title Shiny App for exploring the results of Bayesian multivariate receptor modeling
#'
#' @description Call Shiny to show the results of Bayesian analysis of
#' multivariate receptor modeling in a web-based application.
#' This object contains
#'  \itemize{
#'  \item plots of the posterior means and 95\% posterior intervals of parameters in
#' an object of class \code{bmrm}.
#'\item tables of the posterior means of parameters in
#' an object of class \code{bmrm}.
#'  \item tables of the posterior quantiles of parameters in
#' an object of class \code{bmrm}, for prob=(0.025, 0.05, 0.25, 0.5, 0.75, 0.95, 0.975).
#' \item  tables of convergence diagnostics of parameters in
#' an object of class \code{bmrm}.
#'  \item 3-dimensional dynamic principal component plots of data (Y) and
#' source profiles (rows of the estimated source composition matrix P)
#' in an object of class \code{bmrm}. The plot can be rotated by moving the cursor.
#'  \item trace plots and ACF plots of the first 6 elements of a parameter in an
#'  object of class \code{bmrm}.
#'  }
#' @usage bayesMRMApp(x)
#' @param x an object of class \code{bmrm}, the output of the \code{bmrm} function
#' @return shiny App
#' @export

bayesMRMApp<-function(x){

   EMSaov.env<-new.env()
  varchoice<-1:x$nvar
  names(varchoice)<-colnames(x$Y)
  varchoice<-as.list(varchoice)
  server<-NULL
  EMS_app=shiny::shinyApp(
    ui=shiny::fluidPage(
      theme=shinythemes::shinytheme("cerulean"),
      # Application title
      shiny::titlePanel(shiny::h1(shiny::strong("Explore bayesMRM output"))),

      # Sidebar with a slider input for number of bins
      shiny::sidebarLayout(
        shiny::sidebarPanel(
          shiny::radioButtons("type",
                              label = shiny::h3((shiny::strong("Parameter"))),
                              choices=list("P","A","Sigma"),selected="P"),

          shiny::br(),
          shiny::h4(shiny::strong("Conv Diag")),
          shiny::radioButtons("convdiag",
                              label = shiny::h4(" "),
                              choices=list("geweke","heidel","raftery"),
                              selected="geweke"),

        width=3),


        shiny::mainPanel(
          shiny::tabsetPanel(
            shiny::tabPanel(shiny::h4(shiny::strong("Plots")),
                            shiny::plotOutput("plot")),
            shiny::tabPanel(shiny::h4(shiny::strong("Estimates")),
                            shiny::tableOutput("showest")),
            shiny::tabPanel(shiny::h4(shiny::strong("Quantiles")),
                            shiny::tableOutput("showquant")),
            shiny::tabPanel(shiny::h4(shiny::strong("ConvDiag")),
                            shiny::tableOutput("showconv")),
          shiny::tabPanel(shiny::h4(shiny::strong("PC Plot")),
                          rgl::rglwidgetOutput("pcplot")),
          shiny::tabPanel(shiny::h4(shiny::strong("Trace_ACF Plot")),
                            shiny::plotOutput("showMCMC"))
          )
        )
      )), #end ui

    server<-function(input,output,session){

      output$plot <- shiny::renderPlot({
        plot.bmrm(x,type=input$type)
      })
      output$showest <- shiny::renderTable({
        if(input$type=="A"){
          T <- x$A.hat
          T <- data.frame(obs=1:x$nobs,T)
          colnames(T)[-1]<-paste0("source",1:x$nsource)
          T
        }else if(input$type=="P"){
          T<-x$P.hat
          colnames(T)<-colnames(x$Y)
          T <- data.frame(source=paste("source",1:x$nsource),T)
          T
        }else if(input$type=="Sigma"){
          T<-x$Sigma.hat
          T <- data.frame(variable=colnames(x$Y),T)
          T
        }
      },digits=4)
      output$showquant <- shiny::renderTable({
        if(input$type=="A"){
          T<-x$A.quantiles
          keep.colname<-colnames(T)
          T <- data.frame(source=rep(paste("source",1:x$nsource),x$nobs),
                          obs=rep(1:x$nobs,each=x$nsource),T)
          colnames(T)[-(1:2)]<-keep.colname
          T
        } else if(input$type=="P"){
          T<-x$P.quantiles
          keep.colname<-colnames(T)
          T <- data.frame(source=rep(paste("source",1:x$nsource),x$nvar),
                          variable=rep(colnames(x$Y),each=x$nsource),T)
          colnames(T)[-(1:2)]<-keep.colname
          T
        } else if(input$type=="Sigma"){
          T<-x$Sigma.quantiles
          keep.colname<-colnames(T)
          T<-data.frame(variable=colnames(x$Y),T)
          colnames(T)[-1]<-keep.colname
          T
        }
      },digits=4)

      output$pcplot <- rgl::renderRglwidget({
        #pcplot(x,g3D=TRUE)
        rgl::rgl.open(useNULL=T)
        Y <- x$Y
        Yn <- t(apply(Y,1,function(x) x/sum(x)) )

        Phat <- x$P.hat
        Pn <- t(apply(Phat,1,function(x) x/sum(x)) )
        Y.svd <- svd(stats::cor(Y))
        Z <- Yn %*%Y.svd$v
        S <- Pn %*%Y.svd$v
        G3D.data<-rbind(Z[,1:3],S[,1:3])
        G3D.color<-c(rep("lightblue",nrow(Z)),rep("red",3))
        G3D.pch<-c(rep(16,nrow(Z)),c(2,3,4))
        G3D.text<-paste0("S",1:nrow(S))
        rgl::plot3d(G3D.data[,1:3],col=G3D.color,
                    xlab="z1",ylab="z2",zlab="z3",
         main="3D 'dynamic' principal component plot of data and the estimate of P.",
                    radius=0.005,type="s",family=2)
        rgl::text3d(G3D.data[-(1:nrow(Y)),1:3],text=G3D.text,pos=1,font=2)
        rgl::bg3d("white")
        rgl::rglwidget()
      })

      output$showconv <- shiny::renderTable({
        #print(input$convdiag)
        #print(input$type)
        TempT<-convdiag_bmrm(x,var=input$type,convdiag=input$convdiag,
                         print=FALSE)
        #print(TempT)
        if(input$convdiag == "geweke"){
          TT <- TempT$geweke
        } else if(input$convdiag == "heidel"){
          TT <- TempT$heidel
        } else if(input$convdiag == "raftery"){
          TT <- TempT$raftery
        }
        keep.colname<-colnames(TT)
        if(input$type=="A"){
          TTT<-data.frame(source=rep(paste0("source",1:x$nsource),each=x$nobs),
                        obs=rep(1:x$nobs,x$nsource),TT)
          colnames(TTT)[-(1:2)]<-keep.colname
          TTT
        } else if(input$type=="P"){
          TTT<-data.frame(source=rep(paste0("source",1:x$nsource),x$nvar),
                        variable=rep(colnames(x$Y),each=x$nsource),TT)
          colnames(TTT)[-(1:2)]<-keep.colname
          TTT
        } else if(input$type=="Sigma"){
          TTT=data.frame(variable=colnames(x$Y),TT)
          colnames(TTT)[-1]<-keep.colname
          TTT
        }
      })

        output$showMCMC <- shiny::renderPlot({
          #print(input$type)
                trace_ACF_plot(x,var=input$type, ACF=T, nplot=6)
      })

    }#end server
  )#end App
  shiny::runApp(EMS_app,launch.browser=TRUE)
}





