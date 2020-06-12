# Libelula
# Copyright (c) Jorge Casas Hernán

%global major_version 0
%global minor_version 0
%global micro_version 0
%define debug_package %{nil}

Summary:	Libelula
Name:		libelula
Version:	%{major_version}.%{minor_version}.%{micro_version}
Release:	1
BuildArch:	x86_64
License:	GPLv3
Group:		System Environment/Base
Vendor:		Jorge Casas
Packager:	Jorge Casas
URL:		https://www.linkedin.com/in/jorgecasashernan
Source0:	%{name}-%{version}.tar.gz

Requires:       coreutils
Requires:       rpm-build
Requires:       rpmrebuild
Requires:       subversion

%description
Tool for the automation of Company RPMs generations.

# -----------------------------------------------------------------------
%build
exit 0

# -----------------------------------------------------------------------
%install
install -Dpm 755 libelula.bash \
    $RPM_BUILD_ROOT/usr/bin/libelula

install -Dpm 644 conf/libelula.conf \
    $RPM_BUILD_ROOT/etc/libelula/libelula.conf
install -Dpm 644 conf/rpm-params.json \
    $RPM_BUILD_ROOT/etc/libelula/rpm-params.json

install -Dpm 644 exc/phrases.txt \
    $RPM_BUILD_ROOT/opt/libelula/phrases.txt
install -Dpm 755 exc/parsejson.py \
    $RPM_BUILD_ROOT/opt/libelula/parsejson.py
install -Dpm 644 exc/mail/template-global.html \
    $RPM_BUILD_ROOT/opt/libelula/mail/template-global.html
install -Dpm 644 exc/mail/template-pkg.html \
    $RPM_BUILD_ROOT/opt/libelula/mail/template-pkg.html

exit 0

# -----------------------------------------------------------------------
%clean
rm -rf $RPM_BUILD_ROOT
exit 0


# -----------------------------------------------------------------------
%files
%defattr(-,root,root)
/usr/bin/libelula
/opt/libelula/phrases.txt
/opt/libelula/parsejson.py
/opt/libelula/mail/template-global.html
/opt/libelula/mail/template-pkg.html
%config(noreplace) /etc/libelula/libelula.conf
%config(noreplace) /etc/libelula/rpm-params.json

# -----------------------------------------------------------------------
%pre
exit 0

# -----------------------------------------------------------------------
%post
if [ $1 = 1 ]; then
	echo -e "\nLibelula needs your Company email and password to perform actions such as tag SVN versions or send emails. This information will be stored in the libelula configuration file located in /etc/libelula/libelula.conf (password encrypted on base64).\n"
	
	echo -n "Enter your Company corporate email (eg example@company.es): "
	if exec </dev/tty; then
		read COMPANY_USER_MAIL
	else
		echo "Input not supported. Add the email on /etc/libelula/libelula.conf"
	fi
	echo -n "Enter your password: "
	if exec </dev/tty; then
		read -s COMPANY_USER_PASS
		COMPANY_USER_PASS=`echo $COMPANY_USER_PASS | base64`
	else
		echo "Input not supported. Add the password on /etc/libelula/libelula.conf using base64"
	fi
	
	sed -i "s/COMPANY_USER_MAIL=/COMPANY_USER_MAIL=$COMPANY_USER_MAIL/g" /etc/libelula/libelula.conf
	sed -i "s/COMPANY_USER_PASS=/COMPANY_USER_PASS=$COMPANY_USER_PASS/g" /etc/libelula/libelula.conf
	
	echo -e "\n\nLibelula has been installed correctly and is ready to be used. Take a look at the /etc/libelula/rpm-params.json file and feel free to adapt it to your needs.\n"
fi
	
exit 0

# -----------------------------------------------------------------------
%postun
if [ $1 = 0 ]; then
	rm -rf /opt/libelula
fi
exit 0

#-----------------------------------------------------------------------
%changelog
