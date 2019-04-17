Server Configuration
--------------------

These are Ansible roles that I have built for my own use.  Most
of them started as part of sovereign or frjo's ansible roles.
They assume that you are using Debian 9.


Baseline ---

Common configurations including things like firewall, dns and ntp. I
add this role to all my playbooks, hence the name.

Do initial config by running the first.yml script.  Must have sshpass
installed on the local machine and do this before adding the key entry
to the local ssh config file.

$ export ANSIBLE_HOST_KEY_CHECKING=False
$ ansible-playbook first.yml --ask-pass -i hosts


The public key needs to be in single
line openssh form; to convert a verbose key from putty, do:

     $ ssh-keygen -i -f yourputtypubkeyfile > openssh.key



RUN NORMAL PLAYBOOK

This runs the site playbook on all machines in the 'hosts' inventory
file.  It runs as the deploy user and asks passwords for sudo on the
deploy user and the vault password.  Both are the stpbuild passwords.
The -K flag is a shorthand for --ask-become-pass

    $ ansible-playbook -K --ask-vault-pass -i hosts site.yml




FIREWALL (iptable.yml)

This uses raw iptables.  Some people install the ufw front end, which
makes it easier to block everything and open up a few ports.  Since we
might eventually geoblock china, russia, etc. we stick to raw iptables
so that we can use includes.  We use iptables-persistent to reload our
config on boot.

The playbook writes our IPv4 and IPv6 rules to the following,

    /etc/iptables/testrules.v4
    /etc/iptables/testrules.v6

It then runs iptables-restore/iptables-save to cycle them into the
corresponding rules.v* files, which are what is loaded on boot.  To
change rules, edit etc/iptables/testrules.v* in the templates dir and
rerun the playbook.

We run fail2ban to scan the logs for repeated intrusion attempts and
temporarily ban IPs.  The debian package is not the latest so we add a
few of our own custom rules.

    /etc/fail2ban/filter.d/*-extra.conf

APT NOTES --

To completely uninstall and reinstall a package.

apt-get --purge remove <pkg>
apt-get install <pkg>
