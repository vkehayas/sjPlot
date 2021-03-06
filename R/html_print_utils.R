#' @importFrom sjmisc is_empty str_start
check_css_param <- function(CSS) {
  if (sjmisc::is_empty(CSS)) return(CSS)

  n <- names(CSS)
  nocss <-
    unlist(lapply(sjmisc::str_start(x = n, pattern = "css."), sjmisc::is_empty))

  if (any(nocss)) {
    n[nocss] <- paste0("css.", n[nocss])
    names(CSS) <- n
  }

  CSS
}


# This functions creates the body of the HTML page, i.e. it puts
# the content of a data frame into a HTML table that is returned.

#' @importFrom sjmisc is_empty var_type is_even trim
#' @importFrom tibble has_rownames has_name rownames_to_column
tab_df_content <- function(mydf, title, footnote, col.header, show.type, show.rownames, show.footnote, altr.row.col, sort.column, include.table.tag = TRUE, ...) {

  # save no of rows and columns

  rowcnt <- nrow(mydf)
  colcnt <- ncol(mydf)


  # check if data frame has CSS-attribute. must be a 2x2 matrix with same
  # dimension as data frame. CSS attributes are than mapped for each
  # value in the data frame.

  own.css <- attr(mydf, "CSS", exact = TRUE)
  if (!identical(dim(own.css), dim(mydf))) own.css <- NULL


  # check sorting

  if (!is.null(sort.column)) {
    sc <- abs(sort.column)
    if (sc < 1 || sc > colcnt)
      message("Column index in `sort.column` for sorting columns out of bounds. No sorting applied.")
    else {
      rows <- order(mydf[[sc]])
      if (sort.column < 0) rows <- rev(rows)
      mydf <- mydf[rows, ]
    }
  }


  cnames <- colnames(mydf)


  # if user supplied own column header, which also has the same length
  # as no. columns, replace column names with user header

  if (!sjmisc::is_empty(col.header) && length(col.header) == length(cnames))
    cnames <- col.header


  # check if rownames should be shown and data has any rownames at all
  # if so, we need to update our information on column names

  if (show.rownames && tibble::has_rownames(mydf)) {
    mydf <- tibble::rownames_to_column(mydf)
    colcnt <- colcnt + 1
    cnames <- c("Row", cnames)
  }


  # start table tag
  page.content <- "<table>\n"

  # table caption, variable label
  if (!sjmisc::is_empty(title))
    page.content <- paste0(page.content, sprintf("  <caption>%s</caption>\n", title))


  # header row ----

  page.content <- paste0(page.content, "  <tr>\n")

  for (i in 1:colcnt) {

    # separate CSS for first column
    ftc <- dplyr::if_else(i == 1, " firsttablecol", "", "")
    oc <- ifelse(is.null(own.css), "", sprintf(" %s", sjmisc::trim(own.css[1, i])))

    # column names and variable type as table headline
    vartype <- sjmisc::var_type(mydf[[i]])
    page.content <- paste0(
      page.content, sprintf("    <th class=\"thead firsttablerow%s%s col%i\">%s", ftc, oc, i, cnames[i])
    )

    if (show.type)
      page.content <- paste0(page.content, sprintf("<br>(%s)", vartype))

    page.content <- paste0(page.content, "</th>\n")
  }

  page.content <- paste0(page.content, "  </tr>\n")


  # subsequent rows ----

  for (rcnt in 1:rowcnt) {

    # if we have alternating row colors, set css

    arcstring <- ""

    if (altr.row.col)
      arcstring <- ifelse(sjmisc::is_even(rcnt), " arc", "")

    ltr <- dplyr::if_else(rcnt == rowcnt, " lasttablerow", "", "")

    page.content <- paste0(page.content, "  <tr>\n")

    # all columns of a row
    for (ccnt in 1:colcnt) {

      # separate CSS for first column

      ftc <- dplyr::if_else(ccnt == 1, " firsttablecol", " centeralign", "")
      oc <- ifelse(is.null(own.css), "", sprintf(" %s", sjmisc::trim(own.css[rcnt, ccnt])))


      page.content <- paste0(page.content, sprintf(
        "    <td class=\"tdata%s%s%s%s col%i\">%s</td>\n",
        ftc,
        oc,
        ltr,
        arcstring,
        ccnt,
        mydf[rcnt, ccnt])
      )
    }

    page.content <- paste0(page.content, "</tr>\n")
  }


  # add optional "footnote" row ----

  if (show.footnote) {
    page.content <- paste0(page.content, "  <tr>\n")
    page.content <- paste0(page.content, sprintf("    <td colspan=\"%i\" class=\"footnote\">%s</td>\n", colcnt + 1, footnote))
    page.content <- paste0(page.content, "</tr>\n")
  }


  # finish html page ----
  paste0(page.content, "</table>\n")
}


rmspc <- function(html.table) {
  cleaned <- gsub("      <", "<", html.table, fixed = TRUE, useBytes = TRUE)
  cleaned <- gsub("    <", "<", cleaned, fixed = TRUE, useBytes = TRUE)
  cleaned <- gsub("  <", "<", cleaned, fixed = TRUE, useBytes = TRUE)

  cleaned
}


# This function creates the CSS style sheet for HTML-output

tab_df_style <- function(CSS = NULL, ...) {
  tab_df_prepare_style(CSS = CSS, content = NULL, task = 1, ...)
}


# This function creates the CSS style sheet for HTML-output, but
# converts the style-definition into inline-CSS, which is required
# for knitr documents, i.e. when HTML tables should be included in
# knitr documents.

tab_df_knitr <- function(CSS = NULL, content = NULL, ...) {
  tab_df_prepare_style(CSS = CSS, content = content, task = 2, ...)
}


# This functions creates the complete HTML page, include head and meta
# section of the final HTML page. Required for display in the browser.

tab_create_page <- function(style, content, encoding = "UTF-8") {

  if (is.null(encoding)) encoding <- "UTF-8"

  # first, save table header
  sprintf(
    "<html>\n<head>\n<meta http-equiv=\"Content-type\" content=\"text/html;charset=%s\">\n%s\n</head>\n<body>\n%s\n</body></html>",
    encoding,
    style,
    content
  )
}


# This function does the actual preparation and transformation of
# the HTML style sheets, used by \code{tab_df_style()} and
# \code{tab_df_knitr()}

tab_df_prepare_style <- function(CSS = NULL, content = NULL, task, ...) {

  # init style sheet and tags used for css-definitions
  # we can use these variables for string-replacement
  # later for return value

  tag.table <- "table"
  tag.caption <- "caption"
  tag.thead <- "thead"
  tag.tdata <- "tdata"
  tag.arc <- "arc"
  tag.footnote <- "footnote"
  tag.subtitle <- "subtitle"
  tag.firsttablerow <- "firsttablerow"
  tag.lasttablerow <- "lasttablerow"
  tag.firsttablecol <- "firsttablecol"
  tag.leftalign <- "leftalign"
  tag.centeralign <- "centeralign"
  tag.col1 <- "col1"
  tag.col2 <- "col2"
  tag.col3 <- "col3"
  tag.col4 <- "col4"
  tag.col5 <- "col5"
  tag.col6 <- "col6"
  css.table <- "border-collapse:collapse; border:none;"
  css.caption <- "font-weight: bold; text-align:left;"
  css.thead <- "border-top: double; text-align:center; font-style:italic; font-weight:normal; padding:0.2cm;"
  css.tdata <- "padding:0.2cm; text-align:left; vertical-align:top;"
  css.arc <- "background-color:#f2f2f2;"
  css.lasttablerow <- "border-bottom: double;"
  css.firsttablerow <- "border-bottom:1px solid black;"
  css.firsttablecol <- ""
  css.leftalign <- "text-align:left;"
  css.centeralign <- "text-align:center;"
  css.footnote <- "font-style:italic; border-top:double black; text-align:right;"
  css.subtitle <- "font-weight: normal;"
  css.col1 <- ""
  css.col2 <- ""
  css.col3 <- ""
  css.col4 <- ""
  css.col5 <- ""
  css.col6 <- ""


  # check user defined style sheets

  if (!is.null(CSS)) {
    if (!is.null(CSS[['css.table']])) css.table <- ifelse(substring(CSS[['css.table']], 1, 1) == '+', paste0(css.table, substring(CSS[['css.table']], 2)), CSS[['css.table']])
    if (!is.null(CSS[['css.caption']])) css.caption <- ifelse(substring(CSS[['css.caption']], 1, 1) == '+', paste0(css.caption, substring(CSS[['css.caption']], 2)), CSS[['css.caption']])
    if (!is.null(CSS[['css.thead']])) css.thead <- ifelse(substring(CSS[['css.thead']], 1, 1) == '+', paste0(css.thead, substring(CSS[['css.thead']], 2)), CSS[['css.thead']])
    if (!is.null(CSS[['css.tdata']])) css.tdata <- ifelse(substring(CSS[['css.tdata']], 1, 1) == '+', paste0(css.tdata, substring(CSS[['css.tdata']], 2)), CSS[['css.tdata']])
    if (!is.null(CSS[['css.arc']])) css.arc <- ifelse(substring(CSS[['css.arc']], 1, 1) == '+', paste0(css.arc, substring(CSS[['css.arc']], 2)), CSS[['css.arc']])
    if (!is.null(CSS[['css.lasttablerow']])) css.lasttablerow <- ifelse(substring(CSS[['css.lasttablerow']], 1, 1) == '+', paste0(css.lasttablerow, substring(CSS[['css.lasttablerow']], 2)), CSS[['css.lasttablerow']])
    if (!is.null(CSS[['css.firsttablerow']])) css.firsttablerow <- ifelse(substring(CSS[['css.firsttablerow']], 1, 1) == '+', paste0(css.firsttablerow, substring(CSS[['css.firsttablerow']], 2)), CSS[['css.firsttablerow']])
    if (!is.null(CSS[['css.leftalign']])) css.leftalign <- ifelse(substring(CSS[['css.leftalign']], 1, 1) == '+', paste0(css.leftalign, substring(CSS[['css.leftalign']], 2)), CSS[['css.leftalign']])
    if (!is.null(CSS[['css.centeralign']])) css.centeralign <- ifelse(substring(CSS[['css.centeralign']], 1, 1) == '+', paste0(css.centeralign, substring(CSS[['css.centeralign']], 2)), CSS[['css.centeralign']])
    if (!is.null(CSS[['css.firsttablecol']])) css.firsttablecol <- ifelse(substring(CSS[['css.firsttablecol']], 1, 1) == '+', paste0(css.firsttablecol, substring(CSS[['css.firsttablecol']], 2)), CSS[['css.firsttablecol']])
    if (!is.null(CSS[['css.footnote']])) css.footnote <- ifelse(substring(CSS[['css.footnote']], 1, 1) == '+', paste0(css.footnote, substring(CSS[['css.footnote']], 2)), CSS[['css.footnote']])
    if (!is.null(CSS[['css.subtitle']])) css.subtitle <- ifelse(substring(CSS[['css.subtitle']], 1, 1) == '+', paste0(css.subtitle, substring(CSS[['css.subtitle']], 2)), CSS[['css.subtitle']])
    if (!is.null(CSS[['css.col1']])) css.col1 <- ifelse(substring(CSS[['css.col1']], 1, 1) == '+', paste0(css.col1, substring(CSS[['css.col1']], 2)), CSS[['css.col1']])
    if (!is.null(CSS[['css.col2']])) css.col2 <- ifelse(substring(CSS[['css.col2']], 1, 1) == '+', paste0(css.col2, substring(CSS[['css.col2']], 2)), CSS[['css.col2']])
    if (!is.null(CSS[['css.col3']])) css.col3 <- ifelse(substring(CSS[['css.col3']], 1, 1) == '+', paste0(css.col3, substring(CSS[['css.col3']], 2)), CSS[['css.col3']])
    if (!is.null(CSS[['css.col4']])) css.col4 <- ifelse(substring(CSS[['css.col4']], 1, 1) == '+', paste0(css.col4, substring(CSS[['css.col4']], 2)), CSS[['css.col4']])
    if (!is.null(CSS[['css.col5']])) css.col5 <- ifelse(substring(CSS[['css.col5']], 1, 1) == '+', paste0(css.col5, substring(CSS[['css.col5']], 2)), CSS[['css.col5']])
    if (!is.null(CSS[['css.col6']])) css.col6 <- ifelse(substring(CSS[['css.col6']], 1, 1) == '+', paste0(css.col6, substring(CSS[['css.col6']], 2)), CSS[['css.col6']])
  }


  # set style sheet

  if (task == 1) {
    content <- sprintf(
      "<style>\nhtml, body { background-color: white; }\n%s { %s }\n%s { %s }\n.%s { %s }\n.%s { %s }\n.%s { %s }\n.%s { %s }\n.%s { %s }\n.%s { %s }\n.%s { %s }\n.%s { %s }\n.%s { %s }\n.%s { %s }\n.%s { %s }\n.%s { %s }\n.%s { %s }\n.%s { %s }\n.%s { %s }\n.%s { %s }\n</style>",
      tag.table,
      css.table,
      tag.caption,
      css.caption,
      tag.thead,
      css.thead,
      tag.tdata,
      css.tdata,
      tag.arc,
      css.arc,
      tag.lasttablerow,
      css.lasttablerow,
      tag.firsttablerow,
      css.firsttablerow,
      tag.leftalign,
      css.leftalign,
      tag.centeralign,
      css.centeralign,
      tag.firsttablecol,
      css.firsttablecol,
      tag.footnote,
      css.footnote,
      tag.subtitle,
      css.subtitle,
      tag.col1,
      css.col1,
      tag.col2,
      css.col2,
      tag.col3,
      css.col3,
      tag.col4,
      css.col4,
      tag.col5,
      css.col5,
      tag.col6,
      css.col6
    )

  } else if (task == 2) {
    # set style attributes for main table tags
    content <- gsub("class=", "style=", content, fixed = TRUE, useBytes = TRUE)
    content <- gsub("<table", sprintf("<table style=\"%s\"", css.table), content, fixed = TRUE, useBytes = TRUE)
    content <- gsub("<caption", sprintf("<caption style=\"%s\"", css.caption), content, fixed = TRUE, useBytes = TRUE)

    # replace class-attributes with inline-style-definitions
    content <- gsub(tag.tdata, css.tdata, content, fixed = TRUE, useBytes = TRUE)
    content <- gsub(tag.thead, css.thead, content, fixed = TRUE, useBytes = TRUE)
    content <- gsub(tag.arc, css.arc, content, fixed = TRUE, useBytes = TRUE)
    content <- gsub(tag.footnote, css.footnote, content, fixed = TRUE, useBytes = TRUE)
    content <- gsub(tag.subtitle, css.subtitle, content, fixed = TRUE, useBytes = TRUE)
    content <- gsub(tag.lasttablerow, css.lasttablerow, content, fixed = TRUE, useBytes = TRUE)
    content <- gsub(tag.firsttablerow, css.firsttablerow, content, fixed = TRUE, useBytes = TRUE)
    content <- gsub(tag.firsttablecol, css.firsttablecol, content, fixed = TRUE, useBytes = TRUE)
    content <- gsub(tag.leftalign, css.leftalign, content, fixed = TRUE, useBytes = TRUE)
    content <- gsub(tag.centeralign, css.centeralign, content, fixed = TRUE, useBytes = TRUE)

    content <- gsub(tag.col1, css.col1, content, fixed = TRUE, useBytes = TRUE)
    content <- gsub(tag.col2, css.col2, content, fixed = TRUE, useBytes = TRUE)
    content <- gsub(tag.col3, css.col3, content, fixed = TRUE, useBytes = TRUE)
    content <- gsub(tag.col4, css.col4, content, fixed = TRUE, useBytes = TRUE)
    content <- gsub(tag.col5, css.col5, content, fixed = TRUE, useBytes = TRUE)
    content <- gsub(tag.col6, css.col6, content, fixed = TRUE, useBytes = TRUE)
  }

  content
}
