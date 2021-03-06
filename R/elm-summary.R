#' @export
#' @noRd
summary.elm <- function(object, correlation = FALSE, symbolic.cor = FALSE, ...) {
  z <- object
  p <- z$rank
  rdf <- z$df.residual
  if (p == 0) {
    r <- z$residuals
    n <- length(r)
    w <- z$weights
    if (is.null(w)) {
      rss <- sum(r^2)
    } else {
      rss <- sum(w * r^2)
      r <- sqrt(w) * r
    }
    resvar <- rss / rdf
    ans <- z[c("call", "terms", if (!is.null(z$weights)) "weights")]
    class(ans) <- "summary.elm"
    ans$aliased <- is.na(coef(object)) # used in print method
    ans$residuals <- r
    ans$df <- c(0L, n, length(ans$aliased))
    ans$coefficients <- matrix(NA_real_, 0L, 4L,
      dimnames =
        list(NULL, c("Estimate", "Std. Error", "t value", "Pr(>|t|)"))
    )
    ans$sigma <- sqrt(resvar)
    ans$r.squared <- ans$adj.r.squared <- 0
    ans$cov.unscaled <- matrix(NA_real_, 0L, 0L)
    if (correlation) ans$correlation <- ans$cov.unscaled
    return(ans)
  }
  if (is.null(z$terms)) {
    stop("invalid 'elm' object:  no 'terms' component")
  }
  if (!inherits(object, "elm")) {
    warning("calling summary.elm(<fake-elm-object>) ...")
  }
  Qr <- qr(object)
  n <- if (isTRUE(object$reduce)) {
    Qr$original.dimensions[1]
  } else {
    NROW(Qr$qr)
  }
  if (is.na(z$df.residual) || n - p != z$df.residual) {
    warning("residual degrees of freedom in object suggest this is not an \"elm\" fit")
  }
  ## do not want missing values substituted here
  r <- z$residuals
  f <- z$fitted.values
  w <- z$weights
  if (is.null(w)) {
    mss <- if (attr(z$terms, "intercept")) {
      sum((f - mean(f))^2)
    } else {
      sum(f^2)
    }
    rss <- sum(r^2)
  } else {
    mss <- if (attr(z$terms, "intercept")) {
      m <- sum(w * f / sum(w))
      sum(w * (f - m)^2)
    } else {
      sum(w * f^2)
    }
    rss <- sum(w * r^2)
    r <- sqrt(w) * r
  }
  resvar <- rss / rdf
  ## see thread at https://stat.ethz.ch/pipermail/r-help/2014-March/367585.html
  if (is.finite(resvar) &&
    resvar < (mean(f)^2 + var(c(f))) * 1e-30) { # a few times .Machine$double.eps^2
    warning("essentially perfect fit: summary may be unreliable")
  }
  p1 <- 1L:p
  # R is obtained with a bypass in case the fitting includes reduction=TRUE
  R <- if (isTRUE(z$reduce)) {
    solve.qr(qr(z$xtx, LAPACK = T))
  } else {
    chol2inv(Qr$qr[p1, p1, drop = FALSE])
  }
  se <- sqrt(diag(R) * resvar)
  est <- z$coefficients[Qr$pivot[p1]]
  tval <- est / se
  ans <- z[c("call", "terms", if (!is.null(z$weights)) "weights")]
  ans$residuals <- r
  ans$coefficients <-
    cbind(
      Estimate = est, "Std. Error" = se, "t value" = tval,
      "Pr(>|t|)" = 2 * pt(abs(tval), rdf, lower.tail = FALSE)
    )
  ans$aliased <- is.na(z$coefficients) # used in print method
  ans$sigma <- sqrt(resvar)
  ans$df <- c(p, rdf, NCOL(Qr$qr))
  if (p != attr(z$terms, "intercept")) {
    df.int <- if (attr(z$terms, "intercept")) 1L else 0L
    ans$r.squared <- mss / (mss + rss)
    ans$adj.r.squared <- 1 - (1 - ans$r.squared) * ((n - df.int) / rdf)
    ans$fstatistic <- c(
      value = (mss / (p - df.int)) / resvar,
      numdf = p - df.int, dendf = rdf
    )
  } else {
    ans$r.squared <- ans$adj.r.squared <- 0
  }
  ans$cov.unscaled <- R
  dimnames(ans$cov.unscaled) <- dimnames(ans$coefficients)[c(1, 1)]
  if (correlation) {
    ans$correlation <- (R * resvar) / outer(se, se)
    dimnames(ans$correlation) <- dimnames(ans$cov.unscaled)
    ans$symbolic.cor <- symbolic.cor
  }
  if (!is.null(z$na.action)) ans$na.action <- z$na.action
  class(ans) <- c("summary.elm", "summary.lm")
  return(ans)
}
