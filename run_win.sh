#!/usr/bin/env bash

PROJECT=game
CONFIG=desktop
BUILD=debug
COMPILER=dmd

if [ "$#" -eq  "1" ]
    then
    echo "missing argument"
    exit
fi

if [ "$#" -eq  "2" ]
  then
   PROJECT=$1
   CONFIG=$2
fi

echo "Running: $PROJECT with config: $CONFIG in $BUILD mode built with: $COMPILER"
cd dasm/$PROJECT
dub run -c $CONFIG -b $BUILD --compiler=$COMPILER
cd ..
