#!/bin/bash

usage="$(basename "$0") [-p <pair or single>] -- SampleCreate version 0.2.4
where:
    -p  Specify if files are pair ou single-end, and create a samples file using these files"
#Specify if files are pair ou single-end, and create a samples file using these files

unset OPTARG
unset OPTIND




# VERSION="v1.5"
while getopts ':hs:p' option; do
  case "$option" in
    h) echo "$usage"
       exit
       ;;
    p) $endFile
       ;;
   \?) printf "illegal option: -%s\n" "$OPTARG" >&2
       echo "$usage" >&2
       exit 1
       ;;
  esac
done
#exit 0
shift $((OPTIND-1))

# check if command line argument is empty or not present
# if [ "$1" == "" ];
# then
#     echo "Parameter -p is empty"
#     echo "Please enter at a valid argument"
#     echo "Example: create_samples -p pair"
#     echo "Example: create_samples -p single"
#     exit 0
# fi


pair=$1
#single=$1
if [ "$pair" == "pair" ]
then
    ENDFILE="pair"
    #echo $ENDFILE
elif [ "$pair" == "single" ]
then
    ENDFILE="single"
    #echo $ENDFILE
fi

#echo $ENDFILE

#echo
#INFILE=$1
#
#
#
# if [[ $1 == "-h" ]];
#     then
#         echo "#Use this script to create a sample file from 00-Fastq folder"
#         exit 0
# elif [[ $# > 0 ]];
#     then
#         echo "It is not a valid argment. Try ./install.sh -h"
#         exit 1
# fi



#Creating samples_file.txt
file="samples.txt"
rm -f $file

dir="00-Fastq"

if [ "$ENDFILE" == "pair" ];
then
    if [ -d "$dir" ]
    #if [ -d "$(ls -A "$dir")" ]
    then
        if [ "$(ls -A $dir)" ]
        then
                cd $dir
                echo -e 'SAMPLE_ID\tRead_1\tRead_2' > ../samples.txt
                paste <(ls *_R1_001.fastq.gz | cut -d "_" -f1) <(ls *_R1_001.fastq.gz) <(ls *_R2_001.fastq.gz) >> ../samples.txt
                cd -
                echo -e "\033[1;31m Samples_File ($file) successfully created"
                echo -e "\033[0m"
        else
                echo -e "\033[1;31m $dir exist and is empty"
                echo -e "\033[0m"
        fi
    else
            echo -e "\033[1;31m $dir not found"
            echo -e "\033[0m"
    fi
elif [ "$ENDFILE" == "single" ]
then
    echo "running create_samples with single-end files"
fi
