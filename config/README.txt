You can find some configuration examples in /etc/freedns.
Notice that files xxxx-example.conf files represent examples of files that are called xxxx.conf.
You can copy the contents of these example files to their corresponding files and edit them at your will.

e.g.
==> Credentials file
sudo cp /etc/freedns/credentials-example.conf /etc/freedns/credentials.conf
sudo chmod 600 /etc/freedns/credentials.conf
sudo nano /etc/freedns/credentials.conf

==> Master file (# prefix disables the check of the domain)
sudo cp /etc/freedns/master-example.conf /etc/freedns/master.conf
sudo nano /etc/freedns/master.conf

==> Shadow file (# prefix disables the check of the domain)
sudo cp /etc/freedns/shadow-example.conf /etc/freedns/shadow.conf
sudo nano /etc/freedns/shadow.conf
