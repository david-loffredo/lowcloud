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

DNS

Add an A record,
SPF roles/apache/tasks/
    v=spf1 ip4:45.79.180.69 -all
    v=spf1 mx -all   # recursively includes the MX

CERTBOT ------------------------------------------------------------

We use certbot to acquire LetsEncrypt SSL certificates.  We generate
one certificate per root domain.  Each certificate matches all of the
aliases that we use for that domain (www., mail., etc).  This should
make it easier to move domains to separate machines if needed.

The "certbot_certs" is a list of structs, one for each root domain,
which themselves contains a list of all the machine names that cert
should support.

Default permissions for the letsencrypt directory are 755.  We switch
it to 750 and make it part of the ssl-cert group.  Postfix and dovecot
run as root, but if other apps need access, they can be added to the
ssl-cert group.

Certificate renewal is done using cron.  Services that depend on them
are stopped and started by adding small shell scripts to the pre and
post renewal directories.  Some can just be bounced by adding a reload
or restart action to the post-renewal directory.


MAIL ------------------------------------------------------------

The email configuration is handled by the "mail" role.  Postfix is
used as the MTA and Dovecot for the LDA and IMAP server.  Rspamd is
the only milter used.

All accounts are virtual mailboxes.  The machine only has system unix
accounts and no mail is delivered to them.  The virtual user database
holds the account details in a set of SQL tables.  Some background can
be found at:

   http://www.postfix.org/VIRTUAL_README.html

We use SQLite for the database because this is small, simple, and
relatively static, but you can use MySQL, Maria, or Postgres if you
prefer.  I've written the mailcfg perl utility to manage the database.
It uses DBI and might just need minor changes to the connect statement
and SQL for use with other RDBs.  The utility is in /etc/postfix, and
is run as "mailcfg <command>".   The following commands are available:

 help		Print this message

 addalias <src> <dst>	Adds alias if missing
 adddom <dom>		Add domain if missing
 adduser <email> <pw>	Adds user if missing

 lsalias [<dom>]	List aliases, all or for a domain
 lsdom			List known domain
 lsuser [<dom>]		List users, all or for a domain

 rmalias <src>		Remove alias
 rmalias -id <num>	Remove alias with given id
 rmdom <dom>		Remove domain
 rmuser <email> 	Removes user

 passwd <email> <pw>	Changes user password 
 disable <email>	Marks user as inactive
 enable <email>		Marks user as active

On Debian, smtpd normally runs chrooted to /var/spool/postfix, so the
maildb.sqlite3 database is kept there so the postfix can authenticate
against it.  If you also run dovecot chrooted, you may have to switch
to mysql so that you can access via network port rather than file.

Mail is stored in maildir format and encrypted using EncFS.  The
encrypted directory is /var/mail_crypt and mounted as cleartext in
/var/mail_clear.  All mail is owned by the vmail user.

Postfix is not started automatically at boot because the encrypted
spool must first be mounted manually.  Log in and run the "mailboot"
script to decrypt the mail spool and start postfix.


Postfix is started in init.d, so you can use update-rc.d to disable it on startup:

sudo update-rc.d postfix disable

When you want to enable it again:

sudo update-rc.d postfix enable

Even if it's disabled you can still start it manually with sudo service postfix start.

If update-rc.d is not in your system, you'll have to install the package sysvinit-utils or sysv-rc, or similar (those are for 12.04, I don't remember if 10.04 use the same names).



Mail delivery looks like this:

  Remote MTA -> Rspamd (milter) -> Postfix -> Rspamd (rspamc) -> Dovecot -> user mailbox

Mail from the remote MTA is received by Postfix and run through
Rspamd.  Greylisting and rejects happen in this pipeline.  Once
Postfix receives the message, it is sent to Dovecot over LMTP.
Dovecot uses the antispam module to run rspamc (employing Rspamd).
The sieve module is finally used to process headers added by Rspamd or
any other milters.

## Mail filters

The only mail filter (milter) used is [Rspamd](https://rspamd.com),
which runs on port 11332.  Rspamd is hooked into postfix with the
`smtpd_milters` variable.  See `etc_postfix_main.cf`.

## Debugging

### Rspamd

A few tips:

- Rspam's console listens on `127.0.0.1:11334`.  As above, you can use
  ssh to port forward (e.g., -L 8080:localhost:11334).  The password is `d1`.
- Use `rspamadm` to look at the configuration.
- Use `rspamc` or the web-based console to scan problematic messages
  and see how rspamd scores them.

### DMARC

For verifying DMARC operation, read the rpsamd log in
`/var/log/rspamd` to verify the report generator is running.

For receiving reports, you will get an email if a message comes from
your server that fails authentication (although by configuring
`p=none`, any such email should not be rejected by the other
server).
