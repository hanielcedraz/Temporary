#!/usr/bin/env Rscript

suppressPackageStartupMessages(library("tools"))
suppressPackageStartupMessages(library("parallel"))
suppressPackageStartupMessages(library("optparse"))

option_list <- list(
  make_option(c("-f", "--file"), type = "character", default = "samples.txt",
              help = "The filename of the sample file [default %default]",
              dest = "samplesFile"),
  make_option(c("-c", "--column"), type = "character", default = "SAMPLE_ID",
              help = "Column name from the sample sheet to use as read folder names [default %default]",
              dest = "samplesColumn"),
  make_option(c("-r", "--inputFolder"), type = "character", default = "01-CleanedReads",
              help = "Directory where the sequence data is stored [default %default]",
              dest = "inputFolder"),
  make_option(c("-b", "--mappingFolder"), type = "character", default = '02-MappedReadsSTAR',
              help = "Directory where to store the mapping results [default %default]",
              dest = "mappingFolder"),
  make_option(c("-e", "--extractFolder"), type = "character", default = "03-UnmappedReadsSTAR",
              help = "Save Unmapped reads to this folder [default %default]",
              dest = "extractedFolder"),
  make_option(c('-E', '--countFolder'), type  =  'character', default  =  '04-GeneCountsSTAR',
              help = 'Folder that contains fasta file genome [default %default]',
              dest = 'countsFolder'),
  make_option(c("-m", "--multiqc"), action = 'store_true', type = "logical", default = FALSE,
              help = "Use this option if you would like to run multiqc analysis..  [default %default]",
              dest = "multiqc"),
  make_option(c("-t", "--mappingTargets"), type = "character", default = "mapping_targets.fa",
              help = "Path to a fasta file, or tab delimeted file with [target fasta] to run mapping against (default %default); or path to the directory where the genome indices are stored (path to the genoma_file/index_STAR.",
              dest = "mappingTarget"),
  make_option(c("-g", "--gtfTargets"), type = "character", default = "gtf_targets.gtf",
              help = "Path to a gtf file, or tab delimeted file with [target gtf] to run mapping against. If would like to run without gtf file, -g option is not required [default %default]",
              dest = "gtfTarget"),
  make_option(c("-p", "--processors"), type = "integer", default = 8,
              help = "number of processors to use [defaults %default]",
              dest = "procs"),
  make_option(c("-q", "--sampleprocs"), type = "integer", default = 2,
              help = "number of samples to process at time [default %default]",
              dest = "mprocs"),
  make_option(c("-a", "--sjdboverhang"), type = "integer", default = 100,
              help = "Specify the length of the genomic sequence around the annotated junction to be used in constructing the splice junctions database [default %default]",
              dest = "annoJunction"),
  make_option(c('-s', '--stranded'), type  =  'character', default  =  'no',
              help = 'Select the output according to the strandedness of your data. options: no, yes and reverse [default %default]',
              dest = 'stranded'),
  make_option(c("-x", "--external"), action  =  'store', type  =  "character", default = 'FALSE',
              help = "A space delimeted file with a single line contain several external parameters from STAR [default %default]",
              dest = "externalParameters"),
  make_option(c("-i", "--index"), action = "store_true", default = FALSE,
              help = "This option directs STAR to re-run genome indices generation job. [%default]",
              dest = "indexBuild"),
  make_option(c("-z", "--single"), action = "store_true", default = FALSE,
              help = "Use this option if you have single-end files[doesn't need an argument]. [%default]",
              dest = "singleEnd"),
  make_option(c("-o", "--outSAMtype"), type = "character", default = "SortedByCoordinate",
              help = "Output sorted by coordinate Aligned.sortedByCoord.out.bam file (default: %default); Output unsorted Aligned.out.bam file (Unsorted); Output both unsorted and sorted files (UnsortedSortedByCoordinate).",
              dest = "outSAMtype"),
  make_option(c("-u", "--quantMode"), type = "character", default = "GeneCounts",
              help = "Types of quantifcation requested: Output SAM/BAM alignments to transcriptome into a separate file (TranscriptomeSAM); Count reads per gene (default: %default); Output both transcriptome and reads per gene files (TranscriptomeSAMGeneCounts).",
              dest = "quantMode")
  # make_option(c("-z", "--readfilesCommand"), type = "character", default = "gunzip",
  #             help = "UncompressionCommandoption, whereUncompressionCommandis theun-compression command that takes the file name as input parameter, and sends the uncom-pressed output to stdout.",
  #             dest = "Uncompress"),

)
# get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults,
opt <- parse_args(OptionParser(option_list = option_list, description =  paste('Authors: OLIVEIRA, H.C. & CANTAO, M.E.', 'Version: 0.3.0', 'E-mail: hanielcedraz@gmail.com', sep = "\n", collapse = '\n'), usage = paste('baqcomSTARmapping.R', '-t', 'reference genome', '[options]')))



multiqc <- system('which multiqc > /dev/null', ignore.stdout = TRUE, ignore.stderr = TRUE)
if (casefold(opt$multiqc, upper = FALSE) == 'yes') {
  if (multiqc != 0) {
    write(paste("Multiqc is not installed. If you would like to use multiqc analysis, please install it or remove -r parameter"), stderr())
    stop()
  }
}



if (!(opt$stranded %in% c("reverse", "yes", "no"))) {
  cat('\n')
  write(paste('May have a mistake with the argument in -s parameter. Please verify if the argument is written in the right way'), stderr())
  stop()
}


#cat('\n')
######################################################################
## loadSampleFile
loadSamplesFile <- function(file, reads_folder, column) {
  ## debug
  file = opt$samplesFile; reads_folder = opt$inputFolder; column = opt$samplesColumn
  ##
  if (!file.exists(file) ) {
    write(paste("Sample file",file,"does not exist\n"), stderr())
    stop()
  }
  ### column SAMPLE_ID should be the sample name
  ### rows can be commented out with #
  targets <- read.table(file, header = TRUE, as.is = TRUE)
  if (!opt$singleEnd) {
    if (!all(c("SAMPLE_ID", "Read_1", "Read_2") %in% colnames(targets))) {
      write(paste("Expecting the three columns SAMPLE_ID, Read_1 and Read_2 in samples file (tab-delimited)\n"), stderr())
      stop()
    }
  }
  for (i in seq.int(nrow(targets$SAMPLE_ID))) {
    if (targets[i, column]) {
      ext <- unique(file_ext(dir(file.path(reads_folder,targets[i,column]),pattern = "gz")))
      if (length(ext) == 0) {
        write(paste("Cannot locate fastq or sff file in folder",targets[i,column],"\n"), stderr())
        stop()
      }
      # targets$type[i] <- paste(ext,sep="/")
    }
    else {
      ext <- file_ext(grep("gz", dir(file.path(reads_folder,targets[i, column])), value = TRUE))
      if (length(ext) == 0) {
        write(paste(targets[i,column],"is not a gz file\n"), stderr())
        stop()
      }

    }
  }
  write(paste("samples sheet contains", nrow(targets), "samples to process"),stdout())
  return(targets)
}

#pigz <- system('which pigz 2> /dev/null')
if (system('which pigz 2> /dev/null', ignore.stdout = TRUE, ignore.stderr = TRUE) == 0) {
  uncompress <- paste('unpigz', '-p', opt$procs)
}else{
  uncompress <- 'gunzip'
}

######################################################################
## prepareCore
##    Set up the numer of processors to use
##
## Parameters
##    opt_procs: processors given on the option line
##    samples: number of samples
##    targets: number of targets
# if opt_procs set to 0 then expand to samples by targets
prepareCore <- function(opt_procs){
  if (detectCores() < opt$procs) {
    write(paste("number of cores specified (", opt$procs,") is greater than the number of cores available (",detectCores(),")"),stdout())
    paste('Using ', detectCores(), 'threads')
  }
}




######################
mappingList <- function(samples, reads_folder, column){
  mapping_list <- list()
  for (i in 1:nrow(samples)) {
    reads <- dir(path = file.path(reads_folder), pattern = "fastq.gz$", full.names = TRUE)
    # for (i in seq.int(to=nrow(samples))){
    #     reads <- dir(path=file.path(reads_folder,samples[i,column]),pattern="gz$",full.names=TRUE)
    map <- lapply(c("_PE1", "_PE2", "_SE1", "_SE2"), grep, x = reads, value = TRUE)
    names(map) <- c("PE1", "PE2", "SE1", "SE2")
    map$sampleName <-  samples[i,column]
    map$PE1 <- map$PE1[i]
    map$PE2 <- map$PE2[i]
    map$SE1 <- map$SE1[i]
    map$SE2 <- map$SE2[i]
      mapping_list[[paste(map$sampleName)]] <- map
      mapping_list[[paste(map$sampleName, sep = "_")]]
  }
  write(paste("Setting up", length(mapping_list), "jobs"),stdout())
  return(mapping_list)
}


star_parameters <- opt$externalParameters
if (file.exists(star_parameters)) {
  con = file(star_parameters, open = "r")
  line = readLines(con, warn = FALSE, ok = TRUE)
}

samples <- loadSamplesFile(opt$samplesFile, opt$inputFolder, opt$samplesColumn)
procs <- prepareCore(opt$procs)
mapping <- mappingList(samples, opt$inputFolder, opt$samplesColumn)

cat('\n')

####################
### GENOME GENERATE
####################

#gtf <- if(file.exists(opt$gtfTarget)){paste('--sjdbGTFfile', opt$gtfTarget)}
index_Folder <- paste(dirname(opt$mappingTarget), '/', 'index_STAR', '/', sep = '')
if (!file.exists(file.path(paste(index_Folder, '/', 'Genome', sep = '')))) { dir.create(file.path(index_Folder), recursive = TRUE, showWarnings = FALSE)}

star.index.function <- function(){
  try({
    system(paste('STAR',
                 '--runMode',
                 'genomeGenerate',
                 '--runThreadN',
                 ifelse(detectCores() < opt$procs, detectCores(), paste(opt$procs)),
                 '--genomeDir',
                 index_Folder,
                 '--genomeFastaFiles',
                 opt$mappingTarget,
                 if (!file.exists(opt$gtfTarget)) {
                   write(paste('Running genomeGenerate without gtf file'), stderr())}
                 else{
                   paste(paste('--sjdbGTFfile', opt$gtfTarget, paste(' --sjdbOverhang', opt$annoJunction - 1)))},
                 if (file.exists(star_parameters)) line
    ))})
}

#index_genom <- star.index.function()

if (!file.exists(file.path(paste(index_Folder, '/', 'Genome', sep = '')))) {
  index_genom <- star.index.function()
}

userInput <- function(question) {
  cat(question)
  con <- file("stdin")
  on.exit(close(con))
  n <- readLines(con, n = 1)
  return(n)
}


# if (!(userInput("Would you like to delete and re-run index generation? (yes or no) ") %in% c("yes", "no"))) {
#   cat('\n')
#   write(paste('May have a mistake with the argument in -s parameter. Please verify if the argument is written in the right way'), stderr())
#   stop()
# }

if (opt$indexBuild) {
  if (!file.exists(file.path(paste(index_Folder, '/', 'Genome', sep = '')))) {
    index_genom <- star.index.function()
  }else{
    write(paste("Index genome files already exists."), stderr())
    repeat {
      inp <- userInput("Would you like to delete and re-run index generation? (yes or no) ")
      if (inp %in% c("yes", "no")) {break()
      }else {write("Specify 'yes' or 'no'", stderr())
        }
    }
    if (inp == "yes") {index_genom <- star.index.function()
    }
  }

}





if (opt$outSAMtype == casefold(paste('UnsortedSortedByCoordinate'), upper = FALSE)) {
      opt$outSAMtype <- paste('Unsorted SortedByCoordinate')
}

if (opt$quantMode == casefold(paste('TranscriptomeSAMGeneCounts'), upper = FALSE)) {
      opt$quantMode <- paste('TranscriptomeSAM GeneCounts')
}


## create output folder
mapping_Folder <- opt$mappingFolder
if (!file.exists(file.path(mapping_Folder))) dir.create(file.path(mapping_Folder), recursive = TRUE, showWarnings = FALSE)


# creating extracted_Folder
extracted_Folder <- opt$extractedFolder
if (!file.exists(file.path(extracted_Folder))) dir.create(file.path(extracted_Folder), recursive = TRUE, showWarnings = FALSE)

cat('\n')
#Mapping


if (!opt$singleEnd) {
  star.pair.mapping <- mclapply(mapping, function(index){
    write(paste('Starting Mapping sample', index$sampleName), stderr())
    try({
      system(paste('STAR',
                   '--genomeDir',
                   paste(dirname(opt$mappingTarget), '/', 'index_STAR', '/', sep = ''),
                   '--runThreadN',
                   ifelse(detectCores() < opt$procs, detectCores(), paste(opt$procs)),
                   '--readFilesCommand',
                   paste(uncompress, '-c'),
                   '--readFilesIn',
                     index$PE1,
                     index$PE2,
                   '--outFileNamePrefix',
                   paste0(opt$mappingFolder, '/', index$sampleName, '_STAR_'),
                   '--outReadsUnmapped Fastx',
                   if (file.exists(paste0(index_Folder, 'sjdbList.fromGTF.out.tab'))) {
                     paste('--outSAMtype BAM', opt$outSAMtype, '--quantMode', opt$quantMode, '--sjdbOverhang', opt$annoJunction - 1)
                   }
                   else{
                     if (file.exists(opt$gtfTarget)) {
                       paste('--outSAMtype BAM', opt$outSAMtype, '--quantMode', opt$quantMode, '--sjdbGTFfile', opt$gtfTarget, '--sjdbOverhang', opt$annoJunction - 1)
                     }else{
                       write(paste('The index was built without the gtf file. Please specify the gtf file if you would like to count reads'), stderr())
                     }
                   },
                   if (file.exists(star_parameters)) line))})
  }, mc.cores = opt$mprocs
  )


  if (!all(sapply(star.pair.mapping, "==", 0L))) {
    write(paste("Something went wrong with STAR mapping some jobs failed"),stderr())
    stop()
  }
}else if (opt$singleEnd) {
  star.single.mapping <- mclapply(mapping, function(index){
    write(paste('Starting Mapping'), stderr())
    try({
      system(paste('STAR',
                   '--genomeDir',
                   paste(dirname(opt$mappingTarget), '/', 'index_STAR', '/', sep = ''),
                   '--runThreadN',
                   ifelse(detectCores() < opt$procs, detectCores(), paste(opt$procs)),
                   '--readFilesCommand',
                   paste(uncompress, '-c'),
                   '--readFilesIn',
                   index$PE1,
                   '--outFileNamePrefix',
                   paste0(opt$mappingFolder, '/', index$sampleName, '_STAR_'),
                   '--outReadsUnmapped Fastx',
                   if (file.exists(paste0(index_Folder, 'sjdbList.fromGTF.out.tab'))) {
                     paste('--outSAMtype BAM', opt$outSAMtype, '--quantMode', opt$quantMode, '--sjdbOverhang', opt$annoJunction - 1)
                   }
                   else{
                     if (file.exists(opt$gtfTarget)) {
                       paste('--outSAMtype BAM', opt$outSAMtype, '--quantMode', opt$quantMode, '--sjdbGTFfile', opt$gtfTarget, '--sjdbOverhang', opt$annoJunction - 1)
                     }else{
                       write(paste('The index was built without the gtf file. Please specify the gtf file if you would like to count reads'), stderr())
                     }
                   },
                   if (file.exists(star_parameters)) line))})
  }, mc.cores = opt$mprocs
  )


  if (!all(sapply(star.single.mapping, "==", 0L))) {
    write(paste("Something went wrong with STAR mapping some jobs failed"),stderr())
    stop()
  }
}



# Moving all unmapped files from 02-mappingSTAR folder to 03-Unmapped folder
system(paste0('mv ', opt$mappingFolder, '/*Unmapped.out.mate* ', opt$extractedFolder, '/'))

#Creating mapping report
reportsall <- '05-Reports'
if (!file.exists(file.path(reportsall))) dir.create(file.path(reportsall), recursive = TRUE, showWarnings = FALSE)
# Final_Folder <- opt$mappingFolder
# samples <- read.table(opt$samplesFile, header = T, as.is = T)


TidyTable <- function(x) {
  final <- data.frame('Number_Input_reads' = x[1,2],
                      'Number_Uniquely_Mapped' = x[4,2],
                      'Percent_Uniquely_Mapped' = x[5,2],
                      'Number_Mapped_multiLoci' = x[19,2],
                      'Percent_Mapped_multiLoci' = x[20,2],
                      'Number_Mapped_manyLoci' = x[21,2],
                      'Percent_Mapped_manyLoci' = x[22,2],
                      'Number_Reads_unmapped:short' = x[26,2],
                      'Percent_reads_unmapped:short' = x[27,2],
                      'Number_reads_unmapped:other' = x[28,2],
                      'Percent_reads_unmapped:other' = x[29,2])
  return(final)
}
report_sample <- list()
for (i in samples[,1]) { # change this to your "samples"
  report_sample[[i]] <- read.table(paste0(mapping_Folder, '/', i,"_STAR_Log.final.out"),
                                   header = F, as.is = T, fill = TRUE, sep = c('\t', '|', ' '),
                                   skip = 4, blank.lines.skip = TRUE, text = TRUE)
}

df <- lapply(report_sample, FUN = function(x) TidyTable(x))
final_df <- do.call("rbind", df)

write.table(final_df, file = paste0(reportsall, '/', 'STARMappingReportSummary.txt'), sep = "\t", row.names = TRUE, col.names = TRUE, quote = F)





#MultiQC analysis
report_02 <- '02-Reports'
fastqcbefore <- 'FastQCBefore'
fastqcafter <- 'FastQCAfter'
multiqc_data <- 'multiqc_data'
baqcomqcreport <- 'reportBaqcomQC'
if (opt$multiqc) {
  if (file.exists(paste0(report_02,'/',fastqcafter)) & file.exists(paste0(report_02,'/',fastqcbefore)) & file.exists(paste0(report_02,'/', multiqc_data))) {
    system2('multiqc', paste(opt$mappingFolder, paste0(report_02,'/',fastqcbefore), paste0(report_02,'/',fastqcafter), paste0(report_02,'/',baqcomqcreport), '-o',  reportsall, '-f'))
    unlink(paste0(report_02, '/', 'multiqc*'), recursive = TRUE)
    system(paste('cp -r', paste0(report_02, '/*'), paste0(reportsall,'/')))
  }else{
    system(paste('cp -r', paste0(report_02, '/*'), paste0(reportsall,'/')))
    system2('multiqc', paste(opt$mappingFolder, '-o', reportsall, '-f'))

  }
}
cat('\n')


# if (file.exists(report_02)) {
#   unlink(report_02, recursive = TRUE)
# }

# Creating GeneCounts folder and preparing files
if (casefold(opt$stranded, upper = FALSE) == 'no') {
  opt$stranded <- 2
}else if (casefold(opt$stranded, upper = FALSE) == 'yes') {
  opt$stranded  <- 3
}else if (casefold(opt$stranded, upper = FALSE) == 'reverse') {
  opt$stranded  <- 4
}



if (!file.exists(paste0(mapping_Folder, '/', samples[1,1],'_STAR_ReadsPerGene.out.tab'))) {
  write(paste('Counts file was not generated because mapping step is running without gtf files'), stderr())
} else{
  counts_Folder <- opt$countsFolder
  if (!file.exists(file.path(counts_Folder))) { dir.create(file.path(counts_Folder), recursive = TRUE, showWarnings = FALSE)}
  system(paste('for i in $(ls ', opt$mappingFolder, '/); ', 'do a=`basename $i`;  b=`echo $a | cut -d "_" -f1`; cat ', opt$mappingFolder, '/', '$b"_STAR_ReadsPerGene.out.tab" ', '| ', 'awk ','\'','{', 'print $1"\t"', '$', opt$stranded, '}','\'', ' >', ' ', counts_Folder, '/', '"$b"_ReadsPerGene.counts; done', sep = ''), intern = FALSE)
}

# if (file.exists(report_02) || file.exists(paste0(report_02,'/',fastqcbefore)) || file.exists(paste0(report_02,'/',fastqcafter)) || file.exists(paste0(report_02, '/', baqcomqcreport))) {
#   system(paste('mv', paste0(report_02, '/', baqcomqcreport), paste0(report_02, '/', 'QualityControlReportSummary.txt'), paste0(report_02, '/', 'Fast*'), reportsall))
# }

if (file.exists(report_02)) {
  system(paste('cp -r', paste0(report_02, '/*'), paste0(reportsall,'/')))
  unlink(report_02, recursive = TRUE)
}


system2('cat', paste0(reportsall, '/', 'STARMappingReportSummary.txt'))

cat('\n')
write(paste('How to cite:', sep = '\n', collapse = '\n', "Please, visit https://github.com/hanielcedraz/BAQCOM/blob/master/how_to_cite.txt", "or see the file 'how_to_cite.txt'"), stderr())
