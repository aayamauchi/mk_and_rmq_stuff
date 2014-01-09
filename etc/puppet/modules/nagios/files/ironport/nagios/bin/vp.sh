#!/usr/local/bin/bash

PYDIR="/usr/local/lib/python2.6/site-packages/"

for PKG in simplejson BeautifulSoup ClientCookie MySQL_python paramiko pydns pyasn1 pycrypto
do
    if [ ! -e ${PYDIR}/${PKG}*.egg ]
    then
        /usr/local/bin/easy_install -Z ${PKG}
    fi
done

PLDIR="/usr/local/lib/perl5/site_perl/5.10.1/"
export PERL_MM_USE_DEFAULT=1
export PERL_EXTUTILS_AUTOINSTALL="--defaultdeps"

for PKG in ExtUtils::MakeMaker Net::HTTP LWP YAML XML::SAX Net::SNMP
do
    /usr/bin/perl -M${PKG} -e "#" >/dev/null 2>/dev/null
    RET=$?
    if [ "${RET}" -ne 0 ]
    then
	case "${PKG}" in
            "LWP" )
                PKG="Bundle::LWP" ;;
        esac
        /usr/bin/perl -MCPAN -e"force install '${PKG}'"
    fi
done
