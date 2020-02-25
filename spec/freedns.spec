Name: freedns
Version: 1.1.1
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
# rpmbuild --target noarch -bb freedns.spec --define "_topdir $(pwd)/rpmbuild" --define "_app_dir ~/git/freedns"

%description
Service to automatically update A type DNS records of domains hosted in servers
with dynamic public IPs.

In the config files you define which hostnames are bind to the local server and
if the local server's public IP changes, it will fire the corresponding update
requests to your DNS provider so that your type A records are up to date.

%prep
echo "BUILDROOT = $RPM_BUILD_ROOT"
mkdir -p $RPM_BUILD_ROOT/etc/freedns
mkdir -p $RPM_BUILD_ROOT/opt/freedns
mkdir -p $RPM_BUILD_ROOT/usr/lib/systemd/system
mkdir -p $RPM_BUILD_ROOT/var/lib/freedns
mkdir -p $RPM_BUILD_ROOT/var/log/freedns

cp %{_app_dir}/config/* $RPM_BUILD_ROOT/etc/freedns
cp %{_app_dir}/scripts/* $RPM_BUILD_ROOT/opt/freedns
cp %{_app_dir}/service/freedns.service $RPM_BUILD_ROOT/usr/lib/systemd/system
cp %{_app_dir}/LICENSE $RPM_BUILD_ROOT/opt/freedns

exit

%files
%dir %attr(755,root,root) /etc/freedns
%attr(0644, root, root) /etc/freedns/*
%attr(0600, root, root) /etc/freedns/credentials-example.conf
%dir %attr(755,root,root) /opt/freedns
%attr(0644, root, root) /opt/freedns/*
%attr(0755, root, root) /opt/freedns/main.sh
%attr(0744, root, root) /usr/lib/systemd/system/freedns.service
%dir %attr(700,root,root) /var/lib/freedns
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
ln -s /opt/freedns/main.sh /usr/bin/freedns
systemctl daemon-reload
systemctl condrestart freedns.service

%preun
rm -f /usr/bin/freedns
systemctl stop freedns.service >/dev/null 2>&1
systemctl disable freedns.service >/dev/null 2>&1

%postun
# if user is deleted then we should delete all files it owns, otherwise a new
# user with the same UID could read remaining sensitive data
#if [ "$1" = "0" ]; then
#   userdel --force freedns 2> /dev/null; true
#fi

%clean
echo "Clean: $RPM_BUILD_ROOT"
rm -rf $RPM_BUILD_ROOT

%changelog
* Mon Feb 25 2020 Ibai Usubiaga <admin@ibai.eus>
  - Fixed executable path in service file
  - Added macro to allow setting source directory
