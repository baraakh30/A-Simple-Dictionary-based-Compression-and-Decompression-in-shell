#!/bin/bash


declare -A dictionary #  compression dictionary
declare -A dictionary2 # decomprission dictionary 

# function to handle file checks
check_file() {
    local file_path="$1"
    if [ ! -e "$file_path" ]; then
        echo "File doesn't exist: $file_path. returning...."
        return 0
    elif [ ! -r "$file_path" ]; then
        echo "File isn't readable: $file_path. returning...."
        return 0
    elif [ ! -w "$file_path" ]; then
        echo "File isn't writeable: $file_path. returning...."
        return 0

    else
        return 1
    fi
}

# function to read and load the dictionary
load_dictionary() {
    code_counter=0
    local dict_file="$1"
    while read -r line; do
        code="${line%% *}"
        word="${line#* }"
        dictionary2["$code"]="$word"
        dictionary["$word"]="$code"
        if ((code > code_counter)); then
            code_counter=$code
        fi
    done <"$dict_file"

    if [ $code_counter != "0" ]; then
        ((code_counter++))
    else
        echo "The selected dictionary is empty..."
        yes=1
    fi
}

#check if character is a special character
is_special_char() {
    local char="$1"
    if [[ ! "$char" =~ [[:alnum:]] ]] && [ "$char" != $'\n' -a "$char" != "" -a "$char" != " " ]; then
        # echo $char
        return 0
    else
        return 1
    fi
}

# function to compress a word 
compress_word() {
    local input_word="$1"
    local end="$2"
    if [ "${dictionary["$input_word"]}" ]; then #if its already exist in the dictionary , add its
            compressed_data+="${dictionary["$input_word"]}\n" 
    else 
        code="0x$(printf '%04X' "$code_counter")" #convert the counter to hexa decimal
        dictionary2["$code"]="$input_word" #the reveresed dictionary thats used to decompressS 
        dictionary["$input_word"]="$code" #the original compression dictionary
        echo "$code $input_word" >>"$dictionary_file"
        if [ "$input_word" != "\n" -o "$end" == 1 ]; then

            compressed_data+="$code\n"
            ((code_counter++))
        else
            compressed_data+="$code"
            ((code_counter++))
        fi
    fi
}

# Function to compress a string
compress_string() {
    # Compress the input string
    read -p "Enter the path of the file containing words: " words_file
    if check_file "$words_file"; then #checking the file
        return
    fi
    compressed_data=""
    word=""
    last_char=""
    char=""
#reading character by character from the file
    while IFS= read -r -n1 char; do
   
        if [ "$char" == $'\n' -o "$char" == $'\r' ]; then 
        
            if [ -n "$word" ]; then
            
                if [ -n "$last_char" ]; then
                
                    compress_word "\\n" 1
                fi
                last_char=""
            
                compress_word "$word"
                word=""
                compress_word "\\n" 1

            else
            
                compress_word "\\n" 1
            fi
            
        elif [ "$char" == " " ]; then
        
            if [ -n "$word" ]; then
            
                if [ -n "$last_char" ]; then
                
                    compress_word "Space ' '"
                fi
                
                last_char=""
                compress_word "$word"
                word=""
              
                compress_word "Space ' '"

            else
                compress_word "Space ' '"
                
            fi

        else
            if is_special_char "$char"; then
            
                last_char=$char
                if [ -n "$word" ]; then
                    compress_word "$word"
                    word=""
                fi
              
                compress_word "$char"
                #compress_word "Space ' '"
                
            else
              if [ "$char" != "" ]; then
                 last_char=""
              fi
              word+="$char" #adding characters to the word until it counters a space then it compresses it
            fi
        fi
    done <"$words_file"

    # check if there's a non-empty word at the end and compress it
    if [ -n "$word" ]; then
        compress_word "$word"
    fi

    compress_word "\\n"
    # calculate compression ratio
    uncompressed_size="$(cat "$words_file" | wc -c)"
    ((uncompressed_size--))
  
    compressed_data=$(echo -ne "$compressed_data")
    compressed_size=$(echo "$compressed_data" | wc -l)

    compression_ratio=$(bc -l <<<"scale=3; $uncompressed_size / $compressed_size")

    echo "Compression complete."
    echo
    echo "Compression Ratio: $compression_ratio"
    echo
    echo "Compressed data : "
    echo "$compressed_data"
    echo "$compressed_data" >>compressed_data.txt
    echo
    echo "compressed data has been saved to compressed_data.txt"
    yes=0
}

decompress_data() {

    if [ "$yes" -eq 1 ]; then
        read -p "Since you have selected an empty dictionary file, you have to enter a path of another dictionary file: " dictionary_file
        if check_file "$dictionary_file"; then
            return
        fi
        # read the content of dictionary.txt and store it in an array
        declare -A dictionary2

        while read -r line; do
            code="${line%% *}"
            word="${line#* }"
            dictionary2["$code"]="$word"
        done <"$dictionary_file"
    fi
    read -p "Enter the path of the compressed data file: " compressed_data_file
    if check_file "$compressed_data_file"; then
        return
    fi
    # decompress the data
    decompressed_data=""
    while IFS= read -r code; do
        word="${dictionary2["$code"]}"
        if [ "$word" ] && [ "$word" != "Space ' '" ] && [ "$word" != "\n" ]; then
            decompressed_data+="$word"
        elif [ "$word" == "Space ' '" ]; then
            decompressed_data+=" "
        elif [ "$word" == "\n" ]; then
            decompressed_data+="\n"
        else
            echo "Error: Code $code not found in the dictionary."
            return
        fi
    done <"$compressed_data_file"
    echo
    echo "Decompression complete."
    echo
    echo "Decompressed data:"
    echo ==========================
    echo -ne "$decompressed_data"
    echo ==========================
    echo -ne "$decompressed_data" >>decompressed_data.txt
    echo
    echo "compressed data has been saved to decompressed_data.txt"
}

# Load dictionary if available
yes=0
echo
echo "Do you have a dictionary file? "
select yn in "Yes" "No"; do
    case $yn in
    Yes)

        read -p "Enter the path of the dictionary file: " dictionary_file
        if [ -d "$dictionary_file" ]; then
            dict_file="$dictionary_file/dictionary.txt"
            if check_file "$dict_file"; then
                exit 1
            fi
            load_dictionary "$dict_file"
        else
            if check_file "$dictionary_file"; then
                exit 1
            fi
            load_dictionary "$dictionary_file"
        fi
        break
        ;;
    No)
        yes=1
        if [ -e "dictionary.txt" -a -w "dictionary.txt" ]; then
            echo "dictionary.txt already exists and is writeable"
            select zx in "Replace it" "Use it"; do
                case $zx in
                "Replace it")
                    rm "dictionary.txt"
                    touch dictionary.txt
                    dictionary_file=dictionary.txt
                    break
                    ;;
                "Use it")
                    if check_file "dictionary.txt"; then
                        exit 1
                    fi
                    load_dictionary "dictionary.txt"
                    dictionary_file=dictionary.txt
                    yes=0
                    break
                    ;;
                esac
            done
        else
            touch dictionary.txt
            dictionary_file=dictionary.txt
        fi
        break
        ;;
    esac
done

while [[ ! "$choice" =~ [[qQ]] ]]; do
    echo
    echo "Program Menu:"
    echo "c - Compress"
    echo "d - Decompress"
    echo "q - Exit"
    read -p "Enter your choice: " choice

    echo
    case "$choice" in
    [cC])
        compress_string
        ;;
    [dD])
        decompress_data
        ;;

    [qQ])
        echo "Good bye..."
        exit 0
        ;;
    *)
        echo "Enter a valid option or press q to exit. "
        ;;
    esac
done
