% Generated by roxygen2 (4.1.0): do not edit by hand
% Please edit documentation in R/ddo_addTransform.R
\name{applyTransform}
\alias{applyTransform}
\title{Applies the transformation function(s)}
\usage{
applyTransform(transFns, x, env = NULL)
}
\arguments{
\item{transFns}{from the "transforms" attribute of a ddo object}

\item{x}{a subset of the object}

\item{env}{the environment in which to evaluate the function (should be instantiated from calling \code{\link{setupTransformEnv}}) - if \code{NULL}, the environment will be set up for you}
}
\description{
This is called internally in the map phase of datadr MapReduce jobs.  It is not meant for use outside of there, but is exported for convenience.
}

