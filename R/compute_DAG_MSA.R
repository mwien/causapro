library(pcalg)
library(Rgraphviz)
library(grid)
library(seqinr)
library(bnlearn)

# setwd("~/Documents/Uni/Viren/R/Code")
source("~/.configuration_code.R")

source("functions_causal_effects.R")
source("functions_ci_tests.R")
source("functions_compute_DAG_categorical.R")
# source("functions_compute_DAG_numerical.R")
source("functions_conversions.R")
source("functions_evaluate_DAG.R")
source("functions_general.R")
source("functions_i_o.R")
source("functions_linkcommunities.R")
source("functions_pymol.R")
source("functions_tools.R")

source("configuration_data.R")

# source_of_data should be string giving the path to the file (without the extension), 
# if there exists an ".RData"-file, which needs to contain the matrix MSA, it is loaded from this file.
# Otherwise there should be a file with the extension ".fasta", which the MSA is then read from. 
# Subsequently, the according ".RData"-file is created.  

# read_from_fasta_file = FALSE
# source_of_data = "GII_org_out_nr-aligned"  #"outaln_norwalk"   # ".fasta" is appended automatically later
# source_of_data = "outaln_norwalk"
protein = "PDZ"
## our data is directly the alignment
type_of_data = "MSA"
source_of_data = "al_pdz"

## pool aminoacids in groups (vectors) given in a list "cluster"
map_AS <- FALSE
## specify clusters below

# regard only the columns from "chop_MSA_from" to "chop_MSA_to" (inclusively)
chop_MSA_from <- 80 # 98 #NULL # 0, 1 or NULL if from the beginning
chop_MSA_to <- 101 # 101 #NULL # NULL if to the end

# remove all positions in the alignment where the fraction of gaps is more than "remove_cols_gaps_threshold"
# (set to 1 or NULL to avoid this behaviour)
remove_cols_gaps_threshold <- 0.2
if (is.null(remove_cols_gaps_threshold)) {
  remove_cols_gaps_threshold <- 1
}

# remove columns that have the same value in all observations
remove_singular_columns <- TRUE

# shorten the rownames to the first 10 characters
chop_rownames <- FALSE

# ci_test is given to the Function pc in the parameter indepTest
## independence test: G^2 statistic
# indepTest = disCItest_nmin
## independence test: Chi-square statistic
# NULL=jt? finds least edges
# "x2" more
# "sp-x2" most
# furthermore mi, mi-adf, mc-mi, smc-mi, sp-mi (all categorical)
# discrete case: jt, mc-jt, smc-jt

#
# if the value is numerical, it is assumed to be the forced min of values that the G^2-test in disCItest needs 
# in order not to assume independence right away;
# has never found any edges yet.
test_for_ci <- "sp-x2"
# number_of_permutations <- 1

# level of significance
# sign_niv_removal <- 0.5
# alpha <- 1 - sign_niv_removal # Level of Singnificance for KEEPING edges
alpha <- 0.01 # Level of Singnificance for KEEPING edges

# Spcify Clusters, if any
# mit folgenden Clustern; Rest erstmal einzeln:
hydrophob_aliph <- c("I", "L", "M", "V")
arom <- c("F", "W", "Y")
lys_arg <- c("K", "R")
asn_asp_glu_gln <- c("N", "D", "E", "Q", "B")  # B = Asx = Asn/Asp (N/D)
cluster_13 <- list(ILMV=hydrophob_aliph, FWY=arom, KR=lys_arg, DENQ=asn_asp_glu_gln, H="H", A="A", C="C", G="G", P="P", S="S", "T"="T", UNKNOWN="X", "GAP"="-")

hydrophob_aliph <- c("I", "L", "M", "V")
arom <- c("F", "W", "Y")
pos <- c("H", "K", "R")
polar_I <- c("S", "T")
polar_II <- c("D", "E", "N", "Q", "B") #B = N or D
small <- c("A", "C", "G", "P")
cluster_8 <- list(ILMV=hydrophob_aliph, FWY=arom, HKR=pos, ST=polar_I, DENQ=polar_II, ACGP = small, UNKNOWN="X", "GAP"="-")

hydrophob_aliph <- c("I", "L", "M", "V")
arom <- c("F", "W", "Y")
pos <- c("H", "K", "R")
polar_II <- c("D", "E", "N", "Q", "B") #B = N or D
small_polar <- c("A", "C", "G", "P", "S", "T")
other <- c("X", "-")
cluster_6 <- list(ILMV=hydrophob_aliph, FWY=arom, HKR=pos, DENQ=polar_II, ACGPST = small_polar, X_GAP=other)

ILMV <- c("I", "L", "M", "V")
ASTN <- c("A", "S", "T", "N")
DE <- c("D", "E")
FHWY <- c("F", "H", "W", "Y")
KQR <- c("K", "R", "Q")
cluster_BLOSUM_62 <- list(ILMV=ILMV, ASTN=ASTN, DE=DE, FHWY=FHWY, KQR=KQR, C="C", G="G", P="P", UNKNOWN="X", GAP="-")
# scheint nicht so gut zu sein

ILMV <- c("I", "L", "M", "V")
STN <- c("S", "T", "N")
FWY <- c("F", "W", "Y")
ACGP <- c("A", "C", "G", "P")
cluster_HKRDE <- list(ILMV=ILMV, STN=STN, FWY=FWY, ACGP=ACGP, H="H", K="K", R="R", D="D", E="E", Q="Q", UNKNOWN="X", GAP="-")
# berücksichtigt die besondere Bedeutung von Histidin und KRDE



## choose clustering 
cluster <- cluster_HKRDE
# cluster <- cluster_8

if (!map_AS) {
  cluster = NULL
}


# Construct conclusive filename for the outputs, put in the subdirectory "Outputs".
output_dir <- paste("../Outputs/", protein, "/", type_of_data, "/", sep = "")
# output_dir <- "../Outputs/input"
#if (read_from_fasta_file) {
#output_dir <- paste(output_dir, "_file", sep = "")
#}
output_dir <- paste(output_dir, source_of_data, sep = "")
if ((map_AS)) {
  output_dir <- paste(output_dir, "-", print.cluster(cluster), sep = "")
}
output_dir <- paste(output_dir, "/test=", test_for_ci, "-alpha=", alpha, sep = "")
# output_dir <- paste(output_dir, "-alpha=", alpha, sep = "")



if (!dir.exists(output_dir)) {
  dir.create(output_dir, showWarnings = TRUE, recursive = TRUE, mode = "0777")
}
# setwd(outpath_dir)

output_name <-"";

if (map_AS) {
  output_name <- paste(length(cluster), "clusters-", sep = "_")
}

if (is.null(chop_MSA_from) || chop_MSA_from == 0) {
  chop_MSA_from <- 1
}

chop_MSA_from_print <- chop_MSA_from
if (chop_MSA_from == 1) {
  chop_MSA_from_print <- "start"
}
chop_MSA_to_print <- chop_MSA_to
if (is.null(chop_MSA_to)) {
  chop_MSA_to_print <- "end"
}

if ((chop_MSA_from_print == "start") && (chop_MSA_to_print == "end")) {
  output_name <- paste(output_name, "all_pos", sep = "")
} else { 
  output_name <- paste(output_name, "pos", sep = "")
  if (chop_MSA_from_print == "start") {
    output_name <- paste(output_name, "_0-", chop_MSA_to_print, sep = "")
  } else if (chop_MSA_to_print == "end") {
    output_name <- paste(output_name, "_", chop_MSA_from_print, "-end", sep = "")
  } else {
    output_name <- paste(output_name, "_", chop_MSA_from_print, "-", chop_MSA_to_print, sep = "")
  }
}
if (is.null(test_for_ci)) {
  output_name <- paste(output_name, "-def_test", sep = "")
} else {
  output_name <- paste(output_name, "-test=", test_for_ci, sep = "")
  # if (grepl("mc", test_for_ci)) {
  #   output_name <- paste(output_name, "-", number_of_permutations, "_permut", sep = "")
  # }
}
if (!(remove_cols_gaps_threshold==1)) {
  output_name <- paste(output_name, "-gap_th=", remove_cols_gaps_threshold, sep = "")
}

output_name <- paste(output_name, "-alpha=", alpha, sep = "")
# if (map_AS) {
#   output_name <- paste(output_name, "-MAP", sep = "")
# }

outpath <- paste(output_dir, output_name, sep = "/")
 
# if (grepl("mc", test_for_ci)) {
#   if (is.null(number_of_permutations)) {
#     number_of_permutations <- "def"
#   }
#   ci_test_param <- c("ci-test", "#permutations")
#   ci_test_param_short <- c("ci-test", "#permut")
#   ci_test_value <- c(test_for_ci, number_of_permutations)
# } else {
  ci_test_param <- "ci-test"
  ci_test_param_short <- "ci-test"
  ci_test_value <- test_for_ci
# }


# if read_from_file, source_of_data should be string giving the path to the file, 
# otherwise source_of_data should be a matrix containing the alignment
pc <- estimate_DAG(source_of_data = source_of_data, map_AS = map_AS, cluster = cluster, 
                  chop_MSA_from = chop_MSA_from, chop_MSA_to = chop_MSA_to, chop_rownames = chop_rownames, remove_singular_columns = remove_singular_columns,
                  remove_cols_gaps_threshold= remove_cols_gaps_threshold, test_for_ci= test_for_ci, outpath = outpath, alpha = alpha)
save(pc, file = paste(output_dir, "/", output_name, ".RData", sep = ""))

# dag <- pcalg::pdag2dag(pc@graph)
# dag <- pdag2dag(pc@graph)

# Fehler in data.frame(data, check.names = FALSE) : 
#   Objekt 'MSA' nicht gefunden
analysis_after_pc(pc, MSA, outpath, protein, position_numbering, layout = graph_layout, coloring = coloring, colors = colors, stages = c("orig", "anc"), plot_types = c("localTests", "graphs"), unabbrev_r_to_info, print_r_to_console, lines_in_abbr_of_r, compute_localTests_anew = FALSE, print = TRUE, plot = TRUE)

# evaluate_DAG(MSA, dag$graph)

# print_results_to_info_file(outpath, pc)
