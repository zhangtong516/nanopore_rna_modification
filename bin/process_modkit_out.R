library(data.table)
library(stringr)
library(argparse)

parser <- ArgumentParser()

# specify our desired options 
# by default ArgumentParser will add an help option 
parser$add_argument("input_file", nargs=1, help="Bed file produced by ModKit.")
parser$add_argument("output_file", nargs=1, help="Processed bed file")
parser$add_argument("-c", "--cov", type="integer", default=1,help="Minimum coverage for modification calling.")
parser$add_argument("-r", "--rate", type="double", default=0.0, help="Minimum modification rate in percentage for modification calling.")

args <- parser$parse_args()

modkit_out = fread(args$input_file)
names(modkit_out)= c("chrom", "start", "end" ,"mod_motif", "cov", "strand",
    "start2", "end2", "color", "N_valid_cov", "modified_rate", "N_mod", 
    "N_canonical", "N_other_mod", "N_delete", "N_fail", "N_diff", "N_nocall")


modkit_out[,c("code", "motif", "offset"):=tstrsplit(mod_motif, ",")]
modkit_out[, modification:=fcase(
    code == "a", "m6A",
    code == "m", "m5C",
    code == "17802", "pseU",
    code == "17596", "inosine",
    code == "69426", "2_Ome_A",
    code == "19228", "2_Ome_C",
    code == "19229", "2_Ome_G",
    code == "19227", "2_Ome_U",
    default = "other")]
modkit_out_filtered = modkit_out[cov >= args$cov & modified_rate >= args$rate, ]
fwrite(modkit_out_filtered, args$output, sep="\t")
