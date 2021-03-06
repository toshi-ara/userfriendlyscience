###########################################################
###
### R file with the function meanDiff, which is partly
### a wrapper for the basic t-test function, but which
### also computes Cohen's d and g and the respective
### confidence intervals.
###
### File created by Gjalt-Jorn Peters. Questions? You can
### contact me through http://behaviorchange.eu. Additional
### functions can be found at http://github.com/matherion
###
###########################################################

###########################################################
### Define functions
###########################################################



#' meanDiff
#' 
#' The meanDiff function compares the means between two groups. It computes
#' Cohen's d, the unbiased estimate of Cohen's d (Hedges' g), and performs a
#' t-test. It also shows the achieved power, and, more usefully, the power to
#' detect small, medium, and large effects.
#' 
#' This function uses the formulae from Borenstein, Hedges, Higgins & Rothstein
#' (2009) (pages 25-32).
#' 
#' @param x Dichotomous factor: variable 1; can also be a formula of the form y
#' ~ x, where x must be a factor with two levels (i.e. dichotomous).
#' @param y Numeric vector: variable 2; can be empty if x is a formula.
#' @param paired Boolean; are x & y independent or dependent? Note that if x &
#' y are dependent, they need to have the same length.
#' @param r.prepost Correlation between the pre- and post-test in the case of a
#' paired samples t-test. This is required to compute Cohen's d using the
#' formula on page 29 of Borenstein et al. (2009). If NULL, the correlation is
#' simply computed from the provided scores (but of course it will then be
#' lower if these is an effect - this will lead to an underestimate of the
#' within-groups variance, and therefore, of the standard error of Cohen's d,
#' and therefore, to confidence intervals that are too narrow (too liberal).
#' Also, of course, when using this data to compute the within-groups
#' correlation, random variations will also impact that correlation, which
#' means that confidence intervals may in practice deviate from the null
#' hypothesis significance testing p-value in either direction (i.e. the
#' p-value may indicate a significant association while the confidence interval
#' contains 0, or the other way around). Therefore, if the test-retest
#' correlation of the relevant measure is known, please provide this here to
#' enable computation of accurate confidence intervals.
#' @param var.equal String; only relevant if x & y are independent; can be
#' "test" (default; test whether x & y have different variances), "no" (assume
#' x & y have different variances; see the Warning below!), or "yes" (assume x
#' & y have the same variance)
#' @param conf.level Confidence of confidence intervals you want.
#' @param plot Whether to print a dlvPlot.
#' @param digits With what precision you want the results to print.
#' @param envir The environment where to search for the variables (useful when
#' calling meanDiff from a function where the vectors are defined in that
#' functions environment).
#' @return An object is returned with the following elements:
#' \item{variables}{Input variables} \item{groups}{Levels of the x variable,
#' the dichotomous factor} \item{ci.confidence}{Confidence of confidence
#' intervals} \item{digits}{Number of digits for output} \item{x}{Values of
#' dependent variable in first group} \item{y}{Values of dependent variable in
#' second group} \item{type}{Type of t-test (independent or dependent, equal
#' variances or not)} \item{n}{Sample sizes of the two groups}
#' \item{mean}{Means of the two groups} \item{sd}{Standard deviations of the
#' two groups} \item{objects}{Objects used; the t-test and optionally the test
#' for equal variances} \item{variance}{Variance of the difference score}
#' \item{meanDiff}{Difference between the means} \item{meanDiff.d}{Cohen's d}
#' \item{meanDiff.d.var}{Variance of Cohen's d} \item{meanDiff.d.se}{Standard
#' error of Cohen's d} \item{meanDiff.J}{Correction for Cohen's d to get to the
#' unbiased Hedges g} \item{power}{Achieved power with current effect size and
#' sample size} \item{power.small}{Power to detect small effects with current
#' sample size} \item{power.medium}{Power to detect medium effects with current
#' sample size} \item{power.largel}{Power to detect large effects with current
#' sample size} \item{meanDiff.g}{Hedges' g} \item{meanDiff.g.var}{Variance of
#' Hedges' g} \item{meanDiff.g.se}{Standard error of Hedges' g}
#' \item{ci.usedZ}{Z value used to compute confidence intervals}
#' \item{meanDiff.d.ci.lower}{Lower bound of confidence interval around Cohen's
#' d} \item{meanDiff.d.ci.upper}{Upper bound of confidence interval around
#' Cohen's d} \item{meanDiff.g.ci.lower}{Lower bound of confidence interval
#' around Hedges' g} \item{meanDiff.g.ci.upper}{Upper bound of confidence
#' interval around Hedges' g} \item{meanDiff.ci.lower}{Lower bound of
#' confidence interval around raw mean} \item{meanDiff.ci.upper}{Upper bound of
#' confidence interval around raw mean} \item{t}{Student t value for Null
#' Hypothesis Significance Testing} \item{df}{Degrees of freedom for t value}
#' \item{p}{p-value corresponding to t value}
#' @section Warning: Note that when different variances are assumed for the
#' t-test (i.e. the null-hypothesis test), the values of Cohen's d are still
#' based on the assumption that the variance is equal. In this case, the
#' confidence interval might, for example, not contain zero even though the
#' NHST has a non-significant p-value (the reverse can probably happen, too).
#' @references Borenstein, M., Hedges, L. V., Higgins, J. P., & Rothstein, H.
#' R. (2011). Introduction to meta-analysis. John Wiley & Sons.
#' @keywords utilities
#' @examples
#' 
#' ### Create simple dataset
#' dat <- PlantGrowth[1:20,];
#' ### Remove third level from group factor
#' dat$group <- factor(dat$group);
#' ### Compute mean difference and show it
#' meanDiff(dat$weight ~ dat$group);
#' 
#' ### Look at second treatment
#' dat <- rbind(PlantGrowth[1:10,], PlantGrowth[21:30,]);
#' ### Remove third level from group factor
#' dat$group <- factor(dat$group);
#' ### Compute mean difference and show it
#' meanDiff(x=dat$group, y=dat$weight);
#' 
#' @export meanDiff
meanDiff <- function(x, y=NULL, paired = FALSE, r.prepost = NULL,
                     var.equal = "test", conf.level = .95, plot = FALSE,
                     digits = 2, envir = parent.frame()) {
  
  ### Check basic arguments
  if (!is.logical(paired) || length(paired) != 1) {
    stop("Argument 'paired' must be a boolean (i.e. TRUE or FALSE)!");
  }

  if (!is.character(var.equal) || length(var.equal) != 1) {
    stop("Argument 'var.equal' must be either 'test', 'yes', or 'no'!");
  }
  var.equal <- tolower(var.equal);
  if (!(var.equal %in% c('yes', 'no', 'test'))) {
    stop("Argument 'var.equal' must be either 'test', 'yes', or 'no'!");
  }
  
  if (!is.numeric(conf.level) || length(conf.level) != 1 || conf.level < 0 || conf.level > 1) {
    stop("Argument 'conf.level' must be a number between 0 and 1!");
  }

  if (!is.numeric(digits) || length(digits) != 1 || digits < 0 || (round(digits) != digits)) {
    stop("Argument 'digits' must be a whole, positive number!");
  }
  
  ### Check whether we need to extract the variables from a formula
  if (is.null(y)) {
    if (length(x) != 3) {
      stop(paste0("Error: if no y vector is specified,\nthe x parameter must be a formula of the form y ~ x,\nwhere x is dichotomous. The formula contains more than three elements (", length(x)," elements)."));
    }
    else if (as.character(x[1]) != '~') {
      stop(paste0("Error: if no y vector is specified,\nthe x parameter must be a formula of the form y ~ x,\nwhere x is dichotomous. The formula lacks a tilde ('~'; the first three elements are '",x[1],"', '",x[2],"' and '",x[3],"')."));
    }
    if (paired) {
      stop("Error: when doing a paired t-test, you have to provide both variables as vectors (of the same length), instead of using the formula specification!");
    }
    ############################################################
    ### Note: change on 2013-10-11: now using  eval and parse
    ### to simply get the vector directly. This enables more
    ### flexibility, as it becomes possible to just provide
    ### vectors, rather than columns in a dataframe.
    ############################################################
    ### Get data from vectors or dataframe columns
    depVar <- as.character(x[2]);
    groupingVar <- as.character(x[3]);
    ### Create temporary dataframe to select relevant datapoints
    temp <- data.frame(dv = eval(parse(text = as.character(x[2])), envir=envir),
                       group = eval(parse(text = as.character(x[3])), envir=envir));
    temp$group <- as.factor(temp$group);
    ############################################################
    
    ### Check number of levels of grouping variable
    if (length(levels(temp[['group']])) != 2) {
      stop(paste0("Error: if no y vector is specified, the x parameter must be a formula of the form y ~ x, where x is dichotomous. However, x has more than two levels: x (", groupingVar,") has ", length(levels(temp[['group']])), " levels."));
    }
    varNames <- c(paste(extractVarName(x[2]),"(dependent variable)"),
                  paste(extractVarName(x[3]),"(grouping variable)"));
    ### Get values for one level and for the other level and store in x and y
    x <- temp[['dv']][temp[['group']] == levels(temp[['group']])[1]];
    y <- temp[['dv']][temp[['group']] == levels(temp[['group']])[2]];
    groupNames <- c(as.character(levels(temp[['group']])[1]),
                    as.character(levels(temp[['group']])[2]));
  }
  else {
    ### x and y can be numeric vectors, but it's also possible
    ### one of the two is a dichotomous vector indicating group
    ### membership.
    if (is.numeric(x) && (length(unique(na.omit(x))) > 2) &&
        is.numeric(y) && (length(unique(na.omit(y))) > 2)) {
      varNames <- c(extractVarName(deparse(substitute(x))),
                    extractVarName(deparse(substitute(y))));
      groupNames <- varNames;
    }     else if (is.numeric(x) && (length(unique(na.omit(y))) == 2)) {
      depVar <- x;
      groupingVar <- y;
      temp <- data.frame(dv = x,
                         group = y);
      temp$group <- as.factor(temp$group);
      varNames <- c(paste(extractVarName(deparse(substitute(x))), "(dependent variable)"),
                    paste(extractVarName(deparse(substitute(y))), "(grouping variable)"));
      x <- temp[['dv']][temp[['group']] == levels(temp[['group']])[1]];
      y <- temp[['dv']][temp[['group']] == levels(temp[['group']])[2]];
      groupNames <- c(as.character(levels(temp[['group']])[1]),
                      as.character(levels(temp[['group']])[2]));
    }
    else if (is.numeric(y) && (length(unique(na.omit(x))) == 2)) {
      depVar <- y;
      groupingVar <- x;
      temp <- data.frame(dv = y,
                         group = x);
      temp$group <- as.factor(temp$group);
      varNames <- c(paste(extractVarName(deparse(substitute(y))), "(dependent variable)"),
                    paste(extractVarName(deparse(substitute(x))), "(grouping variable)"));
      x <- temp[['dv']][temp[['group']] == levels(temp[['group']])[1]];
      y <- temp[['dv']][temp[['group']] == levels(temp[['group']])[2]];
      groupNames <- c(as.character(levels(temp[['group']])[1]),
                      as.character(levels(temp[['group']])[2]));
    }
    else {
      stop('x and y are in the wrong format. They either have to both ',
           'be numeric vectors, or one of them has to be a dichotomous ',
           'factor that indicates group membership.');
    }
  }

  ### Create object to return, and store variable names, confidence of
  ### confidence interval, and digits
  res <- list();
  res$variables <- varNames;
  res$groups <- groupNames;
  res$ci.confidence <- conf.level;
  res$digits <- digits;
  res$x <- x;
  res$y <- y;
  
  if (paired) {
    ### Matched pairs t-test
    res$type <- "Matched pairs t-test";
    
    if (length(x) != length(y)) {
      stop(paste0("Error: for a paired sample t-test, both variables must have the same number of cases!\n",
                  res$variables[1], " has ", length(x), " cases, ", res$variables[2], " has ", length(y), " cases."));
    }
  
    ### Remove missing values
    completeCases <- complete.cases(x, y);
    x <- x[completeCases];
    y <- y[completeCases];
    
    ### Store sample size, means and standard deviations
    res$n    <- c(length(x));
    res$mean <- c(mean(x), mean(y));
    res$sd   <- c(sqrt(var(x)), sqrt(var(y)));

    ### Variance of difference
    res$variance <- var(x - y);
    
    ### Paired samples t-test
    res$objects$t_test <- t.test(x, y, paired = TRUE);
    
    ### Correlation between both variables; we'll need it
    ### for Cohen's d (see Borenstein et al., p. 29). If provided, use that
    ### estimate; otherwise, compute it.
    if (is.null(r.prepost)) {
      res$correlation <- cor(x, y);
    } else {
      res$correlation <- r.prepost;
    }
    
    ### Standard deviation of the difference (again, see p. 29)
    res$diff.sd <- sqrt(var(x - y));
        
    ### Standard deviation within groups (see p. 29)
    res$sd.withingroups <- res$diff.sd / (sqrt(2*(1-res$correlation)));
    
    ### Compute raw difference between means
    res$meanDiff <- res$mean[1] - res$mean[2];
    ### Compute Cohen's d (formula from p. 29 of Borenstein et al.)
    res$meanDiff.d <- res$meanDiff/res$diff.sd;
    ### Compute variance of Cohen's d (formula from p. 29 of Borenstein et al.)
    res$meanDiff.d.var <-
      ((1/res$n) + (res$meanDiff.d ^2 / (2*res$n))) * 2 * (1 - res$correlation);
    ### Compute standard error of Cohen's d (formula from p. 29 of Borenstein et al.)
    res$meanDiff.d.se <- sqrt(res$meanDiff.d.var);
    ### Compute J (to compute g, the unbiased d; formula from p. 27 & 29 of Borenstein et al.)
    res$meanDiff.J <- 1 - (3 / (4 * (res$n - 1) - 1));
    
    ### Compute power estimates
    res$power <- pwr.t.test(d=res$meanDiff.d, n=res$n,
                            sig.level=1-conf.level,
                            type="paired",alternative="two.sided");
    ### Also for small, medium, large effects
    res$power.small <- pwr.t.test(d=.2, n=res$n, sig.level=1-conf.level,
                                  type="paired",alternative="two.sided");
    res$power.medium <- pwr.t.test(d=.5, n=res$n, sig.level=1-conf.level,
                                   type="paired",alternative="two.sided");
    res$power.large <- pwr.t.test(d=.8, n=res$n, sig.level=1-conf.level,
                                  type="paired",alternative="two.sided");
    
  }
  else {
    ### Independent samples t-test
    res$type <- "Independent samples t-test (";

    ### Remove missing values
    x <- na.omit(x);
    y <- na.omit(y);

    ### Store sample size, means and standard deviations
    res$n    <- c(length(x), length(y));
    res$mean <- c(mean(x), mean(y));
    res$sd   <- c(sqrt(var(x)), sqrt(var(y)));
    
    ### Test for equal variances if necessary
    if (!paired & (var.equal == "test")) {
      res$objects$equal.var_test <- var.test(x, y);
      res$type = paste0(res$type, "tested for equal variances, ", formatPvalue(res$objects$equal.var_test$p.value, digits=3), ", so ");
      if (res$objects$equal.var_test$p.value < .05) {
        var.equal <- "no";
      }
      else {
        var.equal <- "yes";
      }
    }
    
    ### Which variance we use and which t-test we use
    ### depends on whether we have equal variances
    if (var.equal == "no") {
      res$type = paste0(res$type, "unequal variances)");
      ### Welch's t-test
      res$objects$t_test <- t.test(x, y, var.equal = FALSE);
      ### Use variance from largest sample
      if (res$n[1]> res$n[2]) {
        res$variance <- var(x);
      }
      else {
        res$variance <- var(y);
      }
    }
    else if (var.equal == "yes") {
      res$type = paste0(res$type, "equal variances)");
      ### Student t-test
      res$objects$t_test <- t.test(x, y, var.equal = TRUE);
      ### Compute pooled variance
      x.ss <- var(x) * (res$n[1] - 1);
      y.ss <- var(y) * (res$n[2] - 1);
      res$variance <- (x.ss + y.ss) / (res$n[1] + res$n[2] - 2);
    }

    ### Compute raw difference between means
    res$meanDiff <- res$mean[1] - res$mean[2];
    ### Compute Cohen's d
    res$meanDiff.d <- res$meanDiff/sqrt(res$variance);
    ### Compute variance of Cohen's d (formula from p. 27 of Borenstein et al.)
    res$meanDiff.d.var <-
      ((res$n[1] + res$n[2]) / (res$n[1] * res$n[2])) +
      ((res$meanDiff.d^2) / (2 * (res$n[1] + res$n[2])));
    ### Compute standard error of Cohen's d (formula from p. 27 of Borenstein et al.)
    res$meanDiff.d.se <- sqrt(res$meanDiff.d.var);
    ### Compute J (to compute g, the unbiased d; formula from p. 27 of Borenstein et al.)
    res$meanDiff.J <- 1 - (3 / (4 * (res$n[1] + res$n[2] - 2) - 1));

    ### Compute power estimates
    res$power <- pwr.t.test(d=res$meanDiff.d, n=mean(res$n),
                            sig.level=1-conf.level,
                            type="two.sample",alternative="two.sided");
    ### Also for small, medium, large effects
    res$power.small <- pwr.t.test(d=.2, n=mean(res$n), sig.level=1-conf.level,
                                  type="two.sample",alternative="two.sided");
    res$power.medium <- pwr.t.test(d=.5, n=mean(res$n), sig.level=1-conf.level,
                                   type="two.sample",alternative="two.sided");
    res$power.large <- pwr.t.test(d=.8, n=mean(res$n), sig.level=1-conf.level,
                                  type="two.sample",alternative="two.sided");
    
  }

  ### Compute g and variance & standard error of g (formulae from p. 27 of Borenstein et al.)
  res$meanDiff.g     <- res$meanDiff.J * res$meanDiff.d;
  res$meanDiff.g.var <- res$meanDiff.J^2 * res$meanDiff.d.var;
  res$meanDiff.g.se  <- sqrt(res$meanDiff.g.var);

  ### Find z for calculating confidence intervals
  res$ci.usedZ <- abs(qnorm((1-conf.level)/2));
  
  ### Compute confidence interval for d
  res$meanDiff.d.ci.lower <- res$meanDiff.d - res$ci.usedZ * res$meanDiff.d.se;
  res$meanDiff.d.ci.upper <- res$meanDiff.d + res$ci.usedZ * res$meanDiff.d.se;

  ### Compute confidence interval for g
  res$meanDiff.g.ci.lower <- res$meanDiff.g - res$ci.usedZ * res$meanDiff.g.se;
  res$meanDiff.g.ci.upper <- res$meanDiff.g + res$ci.usedZ * res$meanDiff.g.se;
  
  ### Store confidence interval for meanDiff
  res$meanDiff.ci.lower  <- res$objects$t_test$conf.int[1];
  res$meanDiff.ci.upper  <- res$objects$t_test$conf.int[2];
  
  ### Store secondary (NHST) information
  res$t  <- res$objects$t_test$statistic;
  res$df <- res$objects$t_test$parameter;
  res$p  <- res$objects$t_test$p.value;
  
  ### Generate plot, if requested
  if (plot) {
    tmpDat <- data.frame(dependent = c(x, y),
                         groups = c(rep(groupNames[1], length(x)),
                                    rep(groupNames[2], length(y))));
    res$dlvPlot <- dlvPlot(tmpDat, x="groups", y="dependent");
  }
  
  ### Set class & return result
  class(res) <- c("meanDiff");
  return(res);
}

print.meanDiff <- function (x, digits=x$digits, powerDigits=x$digits + 2, ...) {
  powerInfo <- paste0('Achieved power for d=', round(x$meanDiff.d, digits),
                      ': ', round(x$power$power, powerDigits), ' (for small: ',
                      round(x$power.small$power, powerDigits), '; medium: ',
                      round(x$power.medium$power, powerDigits), '; large: ',
                      round(x$power.large$power, powerDigits), ')');
  if (regexpr("Matched pairs", x$type) > -1) {
    variableInfo <- paste0("\n  ", x$variables[1], " (mean = ", round(x$mean[1], digits), ", sd = ", round(x$sd[1], digits), ", n = ", x$n, ")",
                           "\n  ", x$variables[2], " (mean = ", round(x$mean[2], digits), ", sd = ", round(x$sd[2], digits), ", n = ", x$n, ")");
    varianceInfo <- paste0(x$type, "\n  (standard deviation of the difference: ", round(sqrt(x$variance), digits), ")");
  }
  else if (regexpr("Independent samples", x$type) > -1) {
    variableInfo <- paste0("\n  ", x$variables[2],
                           "\n  ", x$variables[1],
                           "\n  Mean 1 (", x$groups[1], ") = ", round(x$mean[1], digits), ", sd = ", round(x$sd[1], digits), ", n = ", x$n[1],
                           "\n  Mean 2 (", x$groups[2], ")= ", round(x$mean[2], digits), ", sd = ", round(x$sd[2], digits), ", n = ", x$n[2]);
    if (regexpr("unequal variances", x$type) > -1) {
      varianceInfo <- paste0(x$type, "\n  (standard deviation used of largest sample, ", round(sqrt(x$variance), digits), ")");
    }
    else if (regexpr("equal variances", x$type) > -1) {
      varianceInfo <- paste0(x$type, "\n  (pooled standard deviation used, ", round(sqrt(x$variance), digits), ")");
    }
  }
  cat(paste0("Input variables:\n",
           variableInfo,
           "\n\n", varianceInfo,
           "\n\n", round(x$ci.confidence * 100, digits), "% confidence intervals:",
           "\n  Absolute mean difference: [", round(x$meanDiff.ci.lower, digits), ", ", round(x$meanDiff.ci.upper, digits), "]",
             " (Absolute mean difference: ", round(x$meanDiff, digits), ")",
           "\n  Cohen's d for difference: [", round(x$meanDiff.d.ci.lower, digits), ", ", round(x$meanDiff.d.ci.upper, digits), "]",
             " (Cohen's d point estimate: ", round(x$meanDiff.d, digits), ")",
           "\n  Hedges g for difference:  [", round(x$meanDiff.g.ci.lower, digits), ", ", round(x$meanDiff.g.ci.upper, digits), "]",
             " (Hedges g point estimate:  ", round(x$meanDiff.g, digits), ")",
           "\n\n",
           powerInfo,
           "\n\n(secondary information (NHST): t[", round(x$df, digits), "] = ", round(x$t, digits), ", ", formatPvalue(x$p, digits=digits+1), ")\n"));
  if (regexpr("unequal variances", x$type) > -1) {
    cat(paste0("\n\nNOTE: because the t-test is based on unequal variances, the ",
               "NHST p-value may be inconsistent with the confidence interval. ",
               "Although this is not a problem, if you wish to ensure consistency, ",
               "you can use parameter \"var.equal = 'yes'\" to force equal variances.\n\n"));
  }
  
  if (!is.null(x$dlvPlot)) {
    print(x$dlvPlot);
  }
  
  invisible();
}


pander.meanDiff <- function (x, digits=x$digits, powerDigits=x$digits + 2, ...) {
  powerInfo <- paste0('Achieved power for d=', round(x$meanDiff.d, digits),
                      ': ', round(x$power$power, powerDigits), ' (for small: ',
                      round(x$power.small$power, powerDigits), '; medium: ',
                      round(x$power.medium$power, powerDigits), '; large: ',
                      round(x$power.large$power, powerDigits), ')');
  if (regexpr("Matched pairs", x$type) > -1) {
    variableInfo <- paste0(x$variables[1], " (mean = ", round(x$mean[1], digits), ", sd = ", round(x$sd[1], digits), ", n = ", x$n, ")  \n",
                           x$variables[2], " (mean = ", round(x$mean[2], digits), ", sd = ", round(x$sd[2], digits), ", n = ", x$n, ")");
    varianceInfo <- paste0("**", x$type, "**  \n(standard deviation of the difference: ", round(sqrt(x$variance), digits), ")");
  }
  else if (regexpr("Independent samples", x$type) > -1) {
    variableInfo <- paste0(x$variables[2],
                           " & ", x$variables[1],
                           "  \nMean 1 (", x$groups[1], ") = ", round(x$mean[1], digits), ", sd = ", round(x$sd[1], digits), ", n = ", x$n[1],
                           "  \nMean 2 (", x$groups[2], ") = ", round(x$mean[2], digits), ", sd = ", round(x$sd[2], digits), ", n = ", x$n[2]);
    if (regexpr("unequal variances", x$type) > -1) {
      varianceInfo <- paste0("**", x$type, "**  \n(standard deviation used of largest sample, ", round(sqrt(x$variance), digits), ")");
    }
    else if (regexpr("equal variances", x$type) > -1) {
      varianceInfo <- paste0("**", x$type, "**  \n(pooled standard deviation used, ", round(sqrt(x$variance), digits), ")");
    }
  }
  
  
  if (!is.null(x$dlvPlot)) {
    print(x$dlvPlot);
  }
  
  cat(paste0("\n\n**Input variables:**  \n",
             variableInfo,
             "\n\n", varianceInfo,
             "\n\n**", round(x$ci.confidence * 100, digits), "% confidence intervals:**",
             "  \nAbsolute mean difference: [", round(x$meanDiff.ci.lower, digits), ", ", round(x$meanDiff.ci.upper, digits), "]",
             " (Absolute mean difference: ", round(x$meanDiff, digits), ")",
             "  \nCohen's d for difference: [", round(x$meanDiff.d.ci.lower, digits), ", ", round(x$meanDiff.d.ci.upper, digits), "]",
             " (Cohen's d point estimate: ", round(x$meanDiff.d, digits), ")",
             "  \nHedges g for difference:  [", round(x$meanDiff.g.ci.lower, digits), ", ", round(x$meanDiff.g.ci.upper, digits), "]",
             " (Hedges g point estimate:  ", round(x$meanDiff.g, digits), ")",
             "\n\n",
             powerInfo,
             "\n\n*(secondary information (NHST): t[", round(x$df, digits), "] = ", round(x$t, digits), ", ", formatPvalue(x$p, digits=digits+1), ")*\n"));
  if (regexpr("unequal variances", x$type) > -1) {
    cat(paste0("\n\nNOTE: because the t-test is based on unequal variances, the ",
               "NHST p-value may be inconsistent with the confidence interval. ",
               "Although this is not a problem, if you wish to ensure consistency, ",
               "you can use parameter \"var.equal = 'yes'\" to force equal variances.\n\n"));
  }
  
  invisible();
}
