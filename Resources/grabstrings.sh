cat ../Classes/*.m | grep VERBOSE | sed -e 's/VERBOSE("//g' | sed -e 's/");//g' | sed -e 's/^ *//g' -e 's/ *$//g'
