#!/bin/sh
cd $PROJECT_DIR/Clutch;
make clean &> /dev/null;
if [ "$CONFIGURATION" == "Debug" ]; then
make debug;
else
make;
fi
open .;
