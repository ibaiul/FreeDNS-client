Name: freedns
Version: 1.0.0
Release: 2
License: MIT
URL: https://github.com/ibaiul/FreeDNS-client.git
Group: System
Packager: Ibai Usubiaga
BuildArch: noarch
Requires: bash
Requires: curl
Requires: bind-utils
Summary: freedns client
BuildRoot: ~/rpmbuild

# Build with the following command:
# rpmbuild --target noarch -bb freedns.spec

%description
Service to automatically update FreeDNS records of domains hosted in servers 
with dynamic public IPs.

In the config files you define which FreeDNS subdomains are bind to the local 
server.

If the local server's public IP changes it will fire the corresponding update 
requests so that your DNS entries are up to date.

%prep
echo "BUILDROOT = $RPM_BUILD_ROOT"
mkdir -p $RPM_BUILD_ROOT/etc/freedns
mkdir -p $RPM_BUILD_ROOT/opt/freedns
mkdir -p $RPM_BUILD_ROOT/usr/lib/systemd/system
mkdir -p $RPM_BUILD_ROOT/var/log/freedns

cp ~/git/freedns/config/* $RPM_BUILD_ROOT/etc/freedns
cp ~/git/freedns/scripts/* $RPM_BUILD_ROOT/opt/freedns
cp ~/git/freedns/service/freedns.service $RPM_BUILD_ROOT/usr/lib/systemd/system
cp ~/git/freedns/LICENSE $RPM_BUILD_ROOT/opt/freedns

exit

%files
%dir %attr(755,root,root) /etc/freedns
%attr(0600, root, root) /etc/freedns/credentials-example.conf
%attr(0644, root, root) /etc/freedns/master-example.conf
%attr(0644, root, root) /etc/freedns/shadow-example.conf
%attr(0644, root, root) /etc/freedns/README.txt
%dir %attr(755,root,root) /opt/freedns
%attr(0744, root, root) /opt/freedns/*
%attr(0744, root, root) /usr/lib/systemd/system/freedns.service
%dir %attr(755,root,root) /var/log/freedns

%pre
#if ! getent group freedns >/dev/null; then
#        groupadd -r freedns
#fi

#if ! getent passwd freedns >/dev/null; then
#        useradd -r -g freedns freedns
#fi

%post
sudo touch /etc/freedns/master.conf
sudo touch /etc/freedns/shadow.conf	
#sudo chown freedns: /etc/freedns/master.conf
#sudo chown freedns: /etc/freedns/shadow.conf
systemctl daemon-reload
systemctl condrestart freedns.service

%preun
systemctl stop freedns.service >/dev/null 2>&1
systemctl disable freedns.service >/dev/null 2>&1

%postun


%clean
echo "Clean: $RPM_BUILD_ROOT"
rm -rf $RPM_BUILD_ROOT

%changelog
* Sun Mar 17 2019 Ibai Usubiaga <admin@ibai.eus>
  - Improved initial version of my old script.

