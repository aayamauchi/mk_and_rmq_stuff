#!/bin/sh

# aflury special
# this tests the phonehome servers to make sure their data is in synch
# if it's really broken, restart the phonehome servers on vtl-app1/2
# -Peter

# 2008-05-20 -mrh-
# migrated from toc3-app* to sbnp-app*
# 2013-08-06 vkafedzh
# migrated from SOMA to VEGA
# TODO: Grab hosts dynamically from ASDB

output1=`curl -kd data=li2e32:940289309bffa4c6bfea274b33f94ea3i2ee https://prod-sbnp-app1.vega.ironport.com/phonehome 2> /dev/null`
output2=`curl -kd data=li2e32:940289309bffa4c6bfea274b33f94ea3i2ee https://prod-sbnp-app1.vega.ironport.com/phonehome 2> /dev/null`
output3=`curl -kd data=li2e32:940289309bffa4c6bfea274b33f94ea3i2ee https://prod-sbnp-app1.vega.ironport.com/phonehome 2> /dev/null`
output4=`curl -kd data=li2e32:940289309bffa4c6bfea274b33f94ea3i2ee https://prod-sbnp-app1.vega.ironport.com/phonehome 2> /dev/null`
output5=`curl -kd data=li2e32:940289309bffa4c6bfea274b33f94ea3i2ee https://prod-sbnp-app1.vega.ironport.com/phonehome 2> /dev/null`
output6=`curl -kd data=li2e32:940289309bffa4c6bfea274b33f94ea3i2ee https://prod-sbnp-app1.vega.ironport.com/phonehome 2> /dev/null`

if [ "$output1" = "$output2" -a "$output1" = "$output3" -a "$output1" = "$output4" -a "$output1" = "$output5" -a "$output1" = "$output6" ]
then
	echo "OK - Phonehome servers' data is in sync"
	exit 0 # a-ok
else
	echo "CRITICAL - Phonehome servers' data is out of sync"
	exit 2 # bad news!
fi

# If we haven't already exited, something is seriously wrong.
exit 3
