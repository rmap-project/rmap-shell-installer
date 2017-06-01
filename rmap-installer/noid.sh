#!/bin/bash
echo "Content Type: text/html\n"
NOIDPATH/noid -f NOIDPATH/noiddb mint `echo $1 | sed 's/[ = ]*$//'`
