# FreeDNS-client
Linux client to update DNS type A records.

### Preface
If you are running some servers or services in a network with a dynamic public IP address this tool might be helpful to maintain their corresponding DNS entries up to date.

Supported DNS providers:
- FreeDNS (https://freedns.afraid.org)
- Dinahosting (https://dinahosting.com)

The source code is compatible with most used Linux distributions although I only maintain the package builders for RedHat derivative Linux systems such as CentOS or Fedora.

Anyway, adapting this work to other DNS providers or Linux package systems would require just a few changes.

### How it works
There is one script that does all the work - main.sh - and it can be run either manually or automatically via systemd services. There are also other smaller scripts that encapsulate the logic to update DNS records at the different compatible DNS providers.

The main idea is that you run this tool in a local server that has one or more publicly accessible services and when the dynamic IP of the server changes, the script automatically takes care of updating the type A DNS records pointing to your server. It checks for updates periodically using cron jobs.

There are some configuration files to set your credentials and the list of hostnames located in the server.

### Installation
Create the yum repository definition file at **/etc/yum.repos.d/freedns.repo**

```
[freedns-releases]
name=FreeDNS client Repository
baseurl=https://nexus.ibai.eus/repository/yum-releases-public
enabled=1
gpgcheck=1
gpgkey=https://www.ibai.eus/gpg/rpm_signing_key.pub
priority=1
```
Install the package.

```
sudo yum install freedns
```

### Configuration
##### Set your credentials
Copy credentials template to the appropriate location.

```
sudo cp -p /etc/freedns/credentials-example.conf /etc/freedns/credentials.conf
```
Ensure that the credentials file can only be read by the owner of the file or you would be exposing them to other users in the local system.

```
ls -l /etc/freedns/credentials.conf
> -rw------- 1 root root 224 20. Mär 01:16 /etc/freedns/credentials.conf
```
The content of the credentials file should look like this

```
AUTH_USER=authentication_user
AUTH_PASS=authentication_pass
```
##### Set the hostnames
Edit the master configuration file at **/etc/freedns/master.conf** and add your hostnames.

```
subdomain1.example.com
#ignored.example.com
subdomain2.example.com
subdomain3.example.com
```
Notice that you can ignore a hostname at any time by just prefixing it with the '#' character.

### Run the service
##### Automated way
Starting the systemd service creates a cron job for detecting IP changes and updating DNS entries when required.

```
systemctl start freedns
systemctl enable freedns
```
Stopping the service will remove the cron job and stop checking for IP changes.

```
systemctl stop freedns
```
##### Manual way

Run the script manually.

Currently it requires root permissions to avoid any other user in the system reading the credentials file without being the admin.

```
sudo /opt/freedns/main.sh -v -a update-dns
```
Alternatively you can pass the credentials as parameters if you plan to run the script through Jenkins or other kind of mechanism that handles the credentials in another way.

Notice that it is not recommended to write the credentials in plain text unless you can ensure that logging to history is disabled. Prefer passing environment variables.

```
/opt/freedns/main.sh -v -a update-dns -u $AUTH_USER -p $AUTH_PASS
```
##### Logs
You can check the logs at **/var/log/freedns/freedns.log**

##### Help
You can see the usage of the command with **-h** or **--help** options.

```
sudo /opt/freedns/main.sh -h
```

### DIY
The following are some simplified instructions to build your own package and do not rely on my buggy home made repository.

Check for more resources out there, you will find a bunch of good ones.

Also check the paths of the following commands and the spec file to ensure that they match your environment!!

##### Build your RPM file
Install dependencies

```
sudo yum install rpm-build
```
Create the directory structure to build RPM packages.

```
mkdir -p ~/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
```
Clone the repository and make any changes to the spec file or other files if you need to.

```
mkdir -p ~/git && cd ~/git
git clone https://github.com/ibaiul/FreeDNS-client.git
mv FreeDNS-client freedns
cd ~
```
Create a link of the spec file pointing to the file you want to build

```
ln -s ~/git/freedns/spec/freedns.spec ~/rpmbuild/SPECS/
```
Trigger the build

```
rpmbuild --target noarch -bb ~/rpmbuild/SPECS/freedns.spec
```
At this point your RPM should be ready at **~/rpmbuild/RPMS/noarch/freedns-${version}.noarch.rpm**

##### Sign the RPM
If you want to optionally sign the RPM follow this instructions

Install dependencies

```
sudo yum install rpm-sign
```
Create GPG keys

```
gpg --gen-key
```
Create a configuration file for the RPM macros at **~/.rpmmacros** and define the GPG options depending on the keys you have generated
```
%_signature gpg
# path to your GPG folder
%_gpg_path ~/.gnupg
# "Real Name" you provided when creating the GPG key
%_gpg_name real_name_of_key
%__gpg /usr/bin/gpg
```
Build and sign

```
rpmbuild --target noarch -bb ~/rpmbuild/SPECS/freedns.spec --sign
```
Sign only

```
rpm --addsign ~/rpmbuild/RPMS/noarch/freedns-${version}.noarch.rpm
```
Export your public GPG key

```
gpg --export -a 'your_key_name' > public_key.pub
```
Check the signature

```
sudo rpm --import public_key.pub
rpm --checksig ~/rpmbuild/RPMS/noarch/freedns-${version}.noarch.rpm
```
