#
# $Id: //sysops/main/puppet/test/modules/demo/lib/facter/myhome.rb#2 $
# $DateTime: 2012/01/20 23:09:31 $
# $Change: 457624 $
# $Author: mhoskins $
#
# Perforce history:
# https://perforce.sfo.ironport.com/sysops/main/puppet/test/modules/demo/lib/facter/myhome.rb?ac=22
# 
# Custom "myhome" fact used by demo module
#######################################################################

# This could get quite creative...
Facter.add('myhome') do
  setcode do
     Facter::Util::Resolution.exec('/bin/echo $HOME')
  end
end

# eof
