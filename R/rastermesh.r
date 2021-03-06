


#' @export
#' @importFrom nabor WKNNF
rastermesh <- function(x, varname) {
  if (!file.exists(x)) return("no file")
  if (missing(varname)) {
    dimnums <- .ndims(x)
    ## first one with the highest dimension
    varname <- names(dimnums)[which.max(dimnums)]
  }
  d <- brick(x, varname = varname, lvar = 4)
  gl <- new("GeolocationCurvilinear", x = raster(x, varname = "lon_u"), y = raster(x, varname = "lat_u"))
  ## why does this give a different answer??
##  print(head(cbind(values(gl@x), range(values(gl@y)))))
  new("RasterMesh", brick(d[[1]]), geolocation = gl, knnQuery = nabor:::WKNNF(coordinates(gl)))
}


boundary <- function(x) {
  left <- cellFromCol(x, 1)
  bottom <- cellFromRow(x, nrow(x))
  right <- rev(cellFromCol(x, ncol(x)))
  top <- rev(cellFromRow(x, 1))
  ## need XYFromCell method
  coordinates(r)[unique(c(left, bottom, right, top)), ]
}



setMethod("extent", "RasterMesh",
          function(x) {
            warning("bounding box extent from geocation values")
            extent(coordinates(x))
          })
setMethod("coordinates", "GeolocationCurvilinear",
          function(obj, ...) {
            cbind(values(obj@x), values(obj@y))
          })
setMethod("coordinates", "RasterMesh",
          function(obj, ...) {
            coordinates(obj@geolocation)
          }
          )

if (!isGeneric("cellFromXY")) {
  setGeneric("cellFromXY", function(object, xy, ...)
    standardGeneric("cellFromXY"))
}
#setMethod("cellFromXY", signature(object='RasterLayer', xy='matrix'), raster::cellFromXY)
#' @export
setMethod("cellFromXY", signature(object='RasterMesh', xy='matrix'),
          function(object, xy, ...) {
            kn <- object@knnQuery$query(xy, k = 1, eps = 0)
            cell <- as.vector(kn$nn.idx)
            bdy <- boundary(object)
            ## TODO test for distance from the edge
            ## could use distance from knn object
            ## need som pre-analysis of the coordinates and their spacing
            outside <- sp::point.in.polygon(xy[,1], xy[, 2], bdy[,1], bdy[,2], mode.checked = TRUE) < 1
            if (any(outside)) {
              #dist <- rep(0, nrow(xy))
              #dist[outside] <- geosphere::dist2Line(xy[outside, , drop = FALSE], bdy)
              #cell[dist > 1e3] <- NA_integer_
              cell[outside] <- NA_integer_
            }
            cell
          }
)

# r <- rastermesh:::rastermesh()
# y <-  cbind(c(146, 147, 145), c(-65, -64, -60))
setMethod("extract", signature(x='RasterMesh', y='matrix'),
          function(x, y, ...){
            cells <- cellFromXY(x, y)
            bad <- is.na(cells)
            vals <- rep(NA_real_, length(cells))
            if (any(!bad)) {
              vals[!bad] <- extract(x, cells[!bad])
            }
            vals
          }
          )


#
# scl <- function(x) (x - na.omit(min(x)))/diff(range(na.omit(x)))
# setMethod("plot", signature(x = 'RasterMesh', y = "ANY"),
#           function(x, y, ...) {
#             #x <- rasterize(coordinates(x), raster(extent(x), nrow = nrow(x) - 30, ncol = ncol(x) - 30), field = values(x[[1]]),
#             #               fun = mean, na.rm = TRUE)
#            # prj <- "+proj=omerc +lonc=147 +lat_0=-65 +alpha=58 +gamma=58"
#           #  plot(project(coordinates(x), prj), col = rainbow(256)[scl(values(x[[1]])) * 255 + 1], pch = 16, cex = 0.3)
#             g <- graticule(seq(xmin(x), xmax(x), length = 55), seq(ymin(x), ymax(x), length = 35))
#             #g1 <- gris(crop(countriesHigh, extent(x)))
#             g1 <- gris(subset(wrld_simpl, NAME == "Antarctica"))
#             g1$v$x1 <- g1$v$x
#             g1$v$y1 <- g1$v$y
#
#
#             qu <- x@knnQuery$query(g1$v %>% dplyr::select(x, y) %>% as.matrix, k = 1, eps = 0)
#             xx <- coordinates(x@geolocation@x)[qu$nn.idx[,1], ]
#             g1$v$x <- xx[,1]
#             g1$v$y <- xx[,2]
#
#
#             #plot(x)
#           })
# plot(r)



