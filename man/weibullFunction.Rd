% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/weibullFunction.R
\name{weibullFunction}
\alias{weibullFunction}
\title{Modeling height-diameter relationship with Weibull function}
\usage{
weibullFunction(data, weight = NULL)
}
\arguments{
\item{data}{Dataset with the informations of height (H) and diameter (D)}

\item{weight}{(optional) Vector indicating observation weights in the model.}
}
\value{
This function give an output similar to the one given by \code{\link{lm}}, obtained for \code{weibullFunction} from \code{\link[minpack.lm]{nlsLM}}).
}
\description{
This function model the relationship between tree height (H) and diameter (D).
Construct a three parameter Weibull model of the form: \deqn{H = a*(1-exp(-(D/b)^c))} (a, b, c are the model parameters to be estimated)
}
\references{
Weibull, W. (1951). \emph{Wide applicability}. Journal of applied mechanics, 103.
}
\seealso{
\code{\link{modelHD}}, \code{\link[lmfor]{HDmodels}}
}
\author{
Maxime REJOU-MECHAIN, Ariane TANGUY
}
