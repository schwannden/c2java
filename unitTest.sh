sedFlag='-i '
sedfile=lex.l
#####################################################
# detect operating system                           #
#####################################################
function detectOS
{
  if [ "$OSTYPE" == "linux-gnu" ]
  then
    sedFlag='-i '
    echo "operating system: linux"
  elif [[ $OSTYPE == darwin* ]]
  then
    sedFlag="-i '' "
    echo "operating system: darwin"
  else
    echo "un-recognized operating system"
    exit
  fi
}

if [ "$1" == "clean" ]
then
  rm -f test/output/*
  exit
fi

detectOS

make
for testFile in `ls test/correct`
do
  printf  "testing %-30s \n" "$testFile...."
  ./parser test/correct/$testFile 
  status=$?
  if [ $status -eq 0 ]
  then
    echo "Done testing $testFile"......
  else
    echo Error in $testFile!!
    exit;
  fi
done

for testFile in `ls test/wrong`
do
  printf  "testing %-30s \n" "$testFile...."
  ./parser test/wrong/$testFile 
  status=$?
  if [ $status -eq 0 ]
  then
    echo Error in $testFile!!
    exit;
  else
    echo "Done testing $testFile"......
  fi
done

echo "\n|-------------------------|"
echo   "| Done testing all files! |"
echo   "|-------------------------|"

