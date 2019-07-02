#!/bin/bash

usage="$(basename "$0") [ <pair or single> <folder_name>] -- SampleCreate version 0.2.4
where:
    Specify if files are pair ou single-end, and create a samples file using these files. [default: pair-end]
    Specify the folder which is storage the fastq files. [default: 00-Fastq]
    "
#Specify if files are pair ou single-end, and create a samples file using these files

unset OPTARG
unset OPTIND


while getopts ':hs:p' option; do
  case "$option" in
    h) echo "$usage"
       exit
       ;;
    # p) $endFile
    #    ;;
   \?) printf "illegal option: -%s\n" "$OPTARG" >&2
       echo "$usage" >&2
       exit 1
       ;;
  esac
done
#exit 0
shift $((OPTIND-1))




filetype=${1:-pair}
dir=${2:-00-Fastq}
#check if command line argument is empty or not present
if [ "$1" != ""  ] && [ "$1" != "pair"  ] && [ "$1" != "single" ];
then
    #echo "Parameter -p is empty or a invalid argument"
    echo "Please enter a valid argument"
    echo "Example: create_samples.sh -p pair"
    echo "Example: create_samples.sh -p single"
    exit 0
fi


# file=$1
# if [ "$file" == "pair" ]
# then
#     ENDFILE="pair"
# elif [ "$file" == "single" ]
# then
#     ENDFILE="single"
# fi




#Creating samples_file.txt
file="samples.txt"
rm -f $file

#dir="00-Fastq"

pair.end.function() {
echo "Creating samples file using Pair-End files"
if [ -d "$dir" ]
then
    if [ "$(ls -A $dir)" ]
    then
            cd $dir
            echo -e 'SAMPLE_ID\tRead_1\tRead_2' > ../samples.txt
            paste <(ls *_R1_001.fastq.gz | cut -d "_" -f1) <(ls *_R1_001.fastq.gz) <(ls *_R2_001.fastq.gz) >> ../samples.txt
            cd ..
            echo -e "\033[1;31m Samples_File ($file) successfully created"
            echo -e "\033[0m"
    else
            echo -e "\033[1;31m $dir exist but is empty"
            echo -e "\033[0m"
    fi
else
        echo -e "\033[1;31m $dir not found. Make sure that $dir exist"
        echo -e "\033[0m"
fi
}

single.end.function() {
echo "Creating samples file using single-end files"
if [ -d "$dir" ]
#if [ -d "$(ls -A "$dir")" ]
then
    if [ "$(ls -A $dir)" ]
    then
            cd $dir
            echo -e 'SAMPLE_ID\tRead_1' > ../samples.txt
            paste <(ls *_R1_001.fastq.gz | cut -d "_" -f1) <(ls *_R1_001.fastq.gz) >> ../samples.txt
            cd ..
            echo -e "\033[1;31m Samples_File ($file) successfully created"
            echo -e "\033[0m"
    else
            echo -e "\033[1;31m $dir exist but is empty"
            echo -e "\033[0m"
    fi
else
        echo -e "\033[1;31m $dir not found. Make sure that $dir exist"
        echo -e "\033[0m"
fi
}



if [ "$filetype" == "pair" ];
then
    pair.end.function
elif [ "$filetype" == "single" ];
then
    single.end.function
fi
