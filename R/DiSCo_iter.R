#' @title Estimate DiSCo in a single period
#'
#' @description This function implements the DiSCo method for a single time period, as well as the mixture of distributions approach.
#' Its return values contain valuable period-specific estimation outputs.
#'
#' @details This function is part of the DiSCo method, called for each time period.
#' It calculates the optimal weights for the DiSCo method and the mixture of
#' distributions approach for a single time period. The function processes data f
#' or both the target and control units, computes the quantile functions,
#' and evaluates these on a specified grid. The function is designed to be used
#' within the broader context of the DiSCo function, which aggregates results
#' across multiple time periods.
#'
#' @param yy Integer indicating the current year being processed.
#' @inheritParams DiSCo
#' @param controls.id List of strings specifying the column names for the control units' identifiers.
#' @param evgrid A vector of grid points on which to evaluate the quantile functions.
#' @param grid.pre Pre-computed grid produced by \code{\link{getGrid}} used to evaluate the empirical CDFs.
#' @param T0 Integer indicating the last pre-treatment period starting from 1.
#'
#' @return A list with the following elements:
#' \itemize{
#'   \item \code{DiSCo_weights } Weights calculated using the DiSCo method.
#'   \item \code{mixture }
#'     \itemize{
#'       \item \code{weights } Optimal weights for the mixture approach.
#'       \item \code{distance } Value of the objective function for the mixture approach.
#'       \item \code{mean } Weighted mixture of the controls' CDFs.
#'     }
#'
#'   \item \code{target }
#'     \itemize{
#'       \item \code{cdf } Empirical CDF of the target. Only computed when `mixture=TRUE`.
#'       \item \code{grid } Grid on which the quantile and CDF functions were evaluated.
#'       \item \code{data } Original data for the target unit.
#'       \item \code{quantiles } Quantiles for the target unit, evaluated on the specified grid.
#'     }
#'
#'   \item \code{controls }
#'     \itemize{
#'       \item \code{data } Original data for the control units.
#'       \item \code{cdf } Empirical CDFs of the control units. Only computed when `mixture=TRUE`.
#'       \item \code{quantiles } Quantiles for the control units, evaluated on the specified grid.
#'.
#'   }
#'   \item \code{controls.q } Quantiles for the control units, evaluated on the specified grid.
#' }
#' @export
DiSCo_iter <- function(yy, df, evgrid, grid.pre, id_col.target, M, G, T0,
                       qmethod=NULL, qtype=7, q_min=0, q_max=1,
                       simplex=FALSE, controls.id, grid.cat, mixture) {

  # target
  target <- df[(id_col == id_col.target) & (t_col == yy)]$y_col

  # generate list where each element contains a list of all micro-level outcomes for a control unit
  controls <- list()
  j <- 1
  for (id in controls.id) {
    controls[[j]] <- df[(id_col == id) & (t_col == yy)]$y_col
    j <- j + 1
  }

  # check whether problem undetermined
  if (length(target) < length(controls)) {
    stop("Problem undetermined: number of data points is smaller than number of weights")
  }

  # evaluating the quantile functions on the grid "evgrid":
  controls.q <- matrix(0,nrow = length(evgrid), ncol=length(controls))
  for (jj in 1:length(controls)){
    controls.q[,jj] <- myQuant(controls[[jj]], evgrid, qmethod, qtype=qtype)
  }

  # sample grid
  if (is.null(grid.cat)) {
    grid <- grid.pre
  } else {
    grid <- list(grid.min = min(grid.cat), grid.max = max(grid.cat), grid.rand = grid.cat, grid.ord = grid.cat)
  }

  if (!mixture) {
  # obtaining the optimal weights for the DiSCo method
    DiSCo_res_weights <- DiSCo_weights_reg(controls, as.vector(target), M=M, qmethod=qmethod, qtype=qtype, simplex=simplex, q_min=q_min, q_max=q_max)
    mixture <- NULL
    cdf_t <- stats::ecdf(target)(grid$grid.ord)
  } else {
  # obtaining the optimal weights for the mixture of distributions method, note that this one is not restricted to q_min, q_max
    mixture <- DiSCo_mixture(controls, target, grid$grid.min, grid$grid.max, grid$grid.ord, M, simplex=simplex)
    DiSCo_res_weights <- NULL
    cdf_t <- mixture$target.order
  }
  #computing the target quantile function
  target.q <- myQuant(target, evgrid, qmethod, qtype=qtype)


  results <- list()
  results[["DiSCo"]] <- list("weights" = DiSCo_res_weights) # DiSCo estimator
  results[["mixture"]] <- list("weights" = mixture$weights.opt, "distance" = mixture$distance.opt, "mean" = mixture$mean) # mixture of distributions estimator
  results[["target"]] <- list("cdf" = cdf_t, "grid" = grid$grid.ord, "data" = as.vector(target), "quantiles" = target.q)
  results[["controls"]] <- list("cdf" = mixture$cdf, "data" = controls, "quantiles" = controls.q) # TODO: fix cdf mixture
  return(results)
}


