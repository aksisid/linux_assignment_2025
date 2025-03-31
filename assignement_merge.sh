#!/usr/bin/bash

#load configuration yaml file
config_file="/config.yaml"

# Extract paths and tools from YAML using Python
INPUT_PATH=$(python3 -c "import yaml; print(yaml.safe_load(open('$config_file'))['data_paths']['input'])")
OUTPUT_PATH=$(python3 -c "import yaml; print(yaml.safe_load(open('$config_file'))['data_paths']['output'])")
PYTHON_SCRIPT=$(python3 -c "import yaml; print(yaml.safe_load(open('$config_file'))['scripts']['merge_python'])")
R_SCRIPT=$(python3 -c "import yaml; print(yaml.safe_load(open('$config_file'))['scripts']['compare_trees_r'])")


#SCRIPT START


#assigning exon counter and pattern (with related values in parentheses) for later use
counter=1
pattern1='^>([^_]+)_(hg38)_.*'
pattern2='^>([^_]+)_([^_]+)_.*'


echo "Start reading file"

$INPUT_PATH/"assignement_merge.sh"
while read line; do #starting a file reading loop

	if [[ $line =~ $pattern1 ]]; then #if line similar to pattern1
		new_line=">${BASH_REMATCH[2]}" #store in new line the name hg38
		block=$new_line #add new line to block value
	else
		if [[ ! "$line" =~ ^[[:space:]]*$ ]]; then #if line is NOT similar to space (i.e. empty line)
			if [[ $line =~ $pattern2 ]]; then #if line similar to pattern2
				new_line=">${BASH_REMATCH[2]}" #catch species name (starts with >)
				block=$block"\n"$new_line #add to block the species name
			else
				block=$block"\n"$line #add to block a whole line that does not start with > (i.e. sequence)
			fi
		else
			if [[ $block =~ ">" ]]; then #if block value similar to > (helps to skip empty lines)
				echo -e $block > $OUTPUT_PATH/"exon_trimmed$counter.fa" #write block value in fasta file
				iqtree2 -s $OUTPUT_PATH/exon_trimmed$counter.fa #use iqtree2 command on aforementioned fasta file
				block="" #empty block value
				counter=$(($counter+1)) #increase counter by 1
				echo "-----Parsed exon number "$counter

				#break when counter is greater than 500 (i.e do it only for 500 exons)
				if [[ $counter -gt 500 ]]; then
					break
				fi
			fi
		fi
	fi
done

echo "-----Creating firt 500 exon names list"
#create list with first 500 exon file names
for i in $(seq 500); do
	echo -e $OUTPUT_PATH/exon_trimmed$i.fa;
done > $OUTPUT_PATH/exon.list

echo "-----Merge sequences into one fasta file-----"
#merge the sequences of first 500 exons using python script which uses the created exon list
python 3 $PYTHON_SCRIPT < $OUTPUT_PATH/exon.list > $OUTPUT_PATH/exon500_merged.fa

echo "-----Creating merge sequences tree-----"
#create tree for merged sequence
iqtree2 -s $OUTPUT_PATH/exon500_merged.fa

echo "-----Compare each one of 500 unique trees with the merged tree-----"
#compare each exon tree with the merged sequence tree
for i in $(seq 500); do
	#use R script to fild trees disatnce
	Rscript $R_SCRIPT $OUTPUT_PATH/exon500_merged.fa.treefile $OUTPUT_PATH/exon_trimmed$i.fa.treefile;
done > $OUTPUT_PATH/disctances.txt

echo "-----The exons with the smallest tree distances compared to the merged 500-exon alignment are-----"
#sort numerically based on second value to see the 10 smallest values
sort -k2,2n $OUTPUT_PATH/distances.txt | head -n 10 > $OUTPUT_PATH/10small_distances.txt

echo "-----End of script-----"
