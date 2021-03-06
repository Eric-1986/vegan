`adonis2` <-
    function(formula, data, permutations = 999, method = "bray",
             sqrt.dist = FALSE, add = FALSE, by = "terms",
             parallel = getOption("mc.cores"), ...)
{
    ## we accept only by = "terms", "margin" or NULL
    if (!is.null(by))
        by <- match.arg(by, c("terms", "margin"))
    ## evaluate lhs
    YVAR <- formula[[2]]
    lhs <- eval(YVAR, environment(formula), globalenv())
    environment(formula) <- environment()
    ## Take care that input lhs are dissimilarities
    if ((is.matrix(lhs) || is.data.frame(lhs)) &&
        isSymmetric(unname(as.matrix(lhs))))
        lhs <- as.dist(lhs)
    if (!inherits(lhs, "dist"))
        lhs <- vegdist(as.matrix(lhs), method=method, ...)
    ## adjust distances if requested
    if (sqrt.dist)
        lhs <- sqrt(lhs)
    if (is.logical(add) && isTRUE(add))
        add <- "lingoes"
    if (is.character(add)) {
        add <- match.arg(add, c("lingoes", "cailliez"))
        if (add == "lingoes") {
            ac <- addLingoes(as.matrix(lhs))
            lhs <- sqrt(lhs^2 + 2 * ac)
        }
        else if (add == "cailliez") {
            ac <- addCailliez(as.matrix(lhs))
            lhs <- lhs + ac
        }
    }
    ## adonis0 & anova.cca should see only dissimilarities (lhs)
    if (!missing(data)) # expand and check terms
        formula <- terms(formula, data=data)
    formula <- update(formula, lhs ~ .)
    ## no data? find variables in .GlobalEnv
    if (missing(data))
        data <- model.frame(delete.response(terms(formula)))
    sol <- adonis0(formula, data = data, method = method)
    out <- anova(sol, permutations = permutations, by = by,
                 parallel = parallel)
    ## Fix output header to show the adonis2() call instead of adonis0()
    head <- attr(out, "heading")
    head[2] <- deparse(match.call(), width.cutoff = 500L)
    attr(out, "heading") <- head
    out
}
`adonis0` <-
    function(formula, data=NULL, method="bray", ...)
{
    ## evaluate data
    if (missing(data))
        data <- .GlobalEnv
    else
        data <- eval(match.call()$data, environment(formula),
                     enclos = .GlobalEnv)
    ## First we collect info for the uppermost level of the analysed
    ## object
    Trms <- terms(delete.response(formula), data = data)
    sol <- list(call = match.call(),
                method = "adonis",
                terms = Trms,
                terminfo = list(terms = Trms))
    sol$call$formula <- formula(Trms)
    TOL <- 1e-7
    Terms <- terms(formula, data = data)
    lhs <- formula[[2]]
    lhs <- eval(lhs, environment(formula)) # to force evaluation
    formula[[2]] <- NULL                # to remove the lhs
    rhs.frame <- model.frame(formula, data, drop.unused.levels = TRUE) # to get the data frame of rhs
    rhs <- model.matrix(formula, rhs.frame) # and finally the model.matrix
    rhs <- rhs[,-1, drop=FALSE] # remove the (Intercept) to get rank right
    rhs <- scale(rhs, scale = FALSE, center = TRUE) # center
    qrhs <- qr(rhs)
    ## input lhs should always be dissimilarities
    if (!inherits(lhs, "dist"))
        stop("internal error: contact developers")
    if (any(lhs < -TOL))
        stop("dissimilarities must be non-negative")
    dmat <- as.matrix(lhs^2)
    n <- nrow(dmat)
    ## G is -dmat/2 centred
    G <- -GowerDblcen(dmat)/2
    ## preliminaries are over: start working
    Gfit <- qr.fitted(qrhs, G)
    Gres <- qr.resid(qrhs, G)
    ## collect data for the fit
    if(!is.null(qrhs$rank) && qrhs$rank > 0)
        CCA <- list(rank = qrhs$rank,
                    qrank = qrhs$rank,
                    tot.chi = sum(diag(Gfit)),
                    QR = qrhs,
                    G = G)
    else
        CCA <- NULL # empty model
    ## collect data for the residuals
    CA <- list(rank = n - max(qrhs$rank, 0) - 1,
               u = matrix(0, nrow=n),
               tot.chi = sum(diag(Gres)),
               Xbar = Gres)
    ## all together
    sol$tot.chi <- sum(diag(G))
    sol$CCA <- CCA
    sol$CA <- CA
    class(sol) <- c("adonis2", "capscale", "rda", "cca")
    sol
}
