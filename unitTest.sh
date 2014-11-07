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

sed $sedFlag 's/fprintf(stderr/fprintf(stdout/g' $sedfile
make
for testFile in `ls test/input`
do
  printf  "testing %-30s" "$testFile...."
  ./scanner test/input/$testFile > test/output/$testFile
  diff test/output/$testFile test/answer/$testFile
  diffStatus=$?
  if [ $diffStatus -eq 0 ]
  then
    echo "Done testing $testFile"......
  else
    echo Error in $testFile!!
    exit;
  fi
done

sed $sedFlag 's/fprintf(stdout/fprintf(stderr/g' $sedfile
rm -f lex.l\'\'

