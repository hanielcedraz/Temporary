#!/bin/bash


grep "$PWD" ~/.bash_profile ~/.bashrc > /dev/null
if [ $? -ne 0 ];
    then
      if [ "$(uname)" == "Linux" ]; then
          echo -e "\n#Added by BAQCOM\nPATH=\$PATH:$PWD/bin/hisat2-
  2.1.0_linux:\n" >> ~/.bashrc;
        bash;
        echo "Path" $PWD "added in ~/.bashrc successfully"
      else
          echo -e "\n#Added by BAQCOM\nPATH=\$PATH:$PWD/bin/hisat2-
  2.1.0_linux:\n" >> ~/.bash_profile;
        source ~/.bash_profile;
        echo "Path" $PWD "added in ~/.bash_profile successfully"
    fi
      else
        if [ "$(uname)" == "Linux" ]; then
        echo "Path" $PWD "It is already in ~/.bashrc"
      else
        echo "Path" $PWD "It is already in ~/.bash_profile"
      fi
fi
