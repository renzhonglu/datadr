#' Recombine
#'
#' Apply an analytic recombination method to a ddo/ddf object and combine the results
#'
#' @param data an object of class "ddo" of "ddf"
#' @param apply a function specifying the analytic method to apply to each subset, or a pre-defined apply function (see \code{\link{drBLB}}, \code{\link{drGLM}}, for example)
#' @param combine the method to combine the results
#' @param output a "kvConnection" object indicating where the output data should reside (see \code{\link{localDiskConn}}, \code{\link{hdfsConn}}).  If \code{NULL} (default), output will be an in-memory "ddo" object.
#' @param overwrite logical; should existing output location be overwritten? (also can specify \code{overwrite = "backup"} to move the existing output to _bak)
#' @param params a named list of parameters external to the input data that are needed in the distributed computing (most should be taken care of automatically such that this is rarely necessary to specify)
#' @param packages a vector of R package names that contain functions used in \code{fn} (most should be taken care of automatically such that this is rarely necessary to specify)
#' @param control parameters specifying how the backend should handle things (most-likely parameters to \code{rhwatch} in RHIPE) - see \code{\link{rhipeControl}} and \code{\link{localDiskControl}}
#' @param verbose logical - print messages about what is being done
#'
#' @return depends on \code{combine}
#'
#' @references
#' \itemize{
#'  \item \url{http://www.datadr.org}
#'  \item \href{http://onlinelibrary.wiley.com/doi/10.1002/sta4.7/full}{Guha, S., Hafen, R., Rounds, J., Xia, J., Li, J., Xi, B., & Cleveland, W. S. (2012). Large complex data: divide and recombine (D&R) with RHIPE. \emph{Stat}, 1(1), 53-67.}
#' }
#'
#' @author Ryan Hafen
#' @seealso \code{\link{divide}}, \code{\link{ddo}}, \code{\link{ddf}}, \code{\link{drGLM}}, \code{\link{drBLB}}, \code{\link{combMeanCoef}}, \code{\link{combMean}}, \code{\link{combCollect}}, \code{\link{combRbind}}, \code{\link{drLapply}}
#' @export
recombine <- function(data, combine = NULL, apply = NULL, output = NULL, overwrite = FALSE, params = NULL, packages = NULL, control = NULL, verbose = TRUE) {
  # apply <- function(x) {
  #   mean(x$Sepal.Length)
  # }
  # apply <- function(k, v) {
  #   list(mean(v$Sepal.Length)
  # }
  # apply <- drBLB(statistic = function(x, w) mean(x$Sepal.Length), metric = function(x) mean(x), R = 100, n = 300)
  # apply <- drGLM(Sepal.Length ~ Petal.Length)
  # combine <- combCollect()

  if(is.null(combine)) {
    if(is.null(output)) {
      combine <- combCollect()
    } else {
      combine <- combDdo()
    }
  } else if(is.function(combine)) {
    combine <- combine()
  }

  if(!is.null(apply)) {
    message("** note **: 'apply' argument is deprecated - please apply this transformation using 'addTransform()' to your input data prior to calling 'recombine()'")
    data <- addTransform(data, apply)
  }

  if(verbose)
    message("* Verifying suitability of 'output' for specified 'combine'...")

  outClass <- ifelse(is.null(output), "nullConn", class(output)[1])
  if(!is.null(combine$validateOutput))
    if(!outClass %in% combine$validateOutput)
      stop("'output' of type ", outClass, " is not compatible with specified 'combine'")

  if(verbose)
    message("* Applying recombination...")

  map <- expression({
    for(i in seq_along(map.keys)) {
      if(combine$group) {
        key <- "1"
      } else {
        key <- map.keys[[i]]
      }
      if(is.function(combine$mapHook)) {
        map.values[[i]] <- combine$mapHook(map.keys[[i]], map.values[[i]])
      }
      collect(key, map.values[[i]])
    }
  })

  reduce <- combine$reduce

  parList <- list(combine = combine)

  # should only need this when datadr is not loaded
  # but for some reason, it can't find these functions, so always send them
  # this does not happen in divide
  parList <- c(parList, list(
    applyTransform = applyTransform,
    setupTransformEnv = setupTransformEnv,
    kvApply = kvApply
  ))

  if(! "package:datadr" %in% search()) {
    if(verbose)
      message("* ---- running dev version - sending datadr functions to mr job")
  } else {
    packages <- c(packages, "datadr")
  }

  globalVarList <- drGetGlobals(apply)
  if(length(globalVarList$vars) > 0)
    parList <- c(parList, globalVarList$vars)

  # if the user supplies output as an unevaluated connection
  # the verbosity can be misleading
  suppressMessages(output <- output)

  res <- mrExec(data,
    map = map,
    reduce = reduce,
    output = output,
    overwrite = overwrite,
    params = c(parList, params),
    packages = c(globalVarList$packages, packages),
    control = control
  )

  if(is.null(output)) {
    return(combine$final(res))
  } else {
    return(res)
  }
}


