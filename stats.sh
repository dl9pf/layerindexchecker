#!/bin/bash

echo -n "Failed:"
cat failed | wc -l
echo -n "Working:"
cat working | wc -l
#echo -n "Skipped due to meta-oe / spice:"
#cat spice-skip | wc -l
echo ""
echo ""
echo "Failed list:
"
cat failed
echo ""
echo ""
echo "Working list:"
cat working
echo ""
echo ""
#echo "Skipped due to meta-oe / spice list:"
#cat spice-skip

