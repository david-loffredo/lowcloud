require ["vnd.dovecot.pipe", "copy", "fileinto"];

# Into the junk folder if flagged.  No training needed because we
# already see it as spam.
if header :contains "X-Spam-Flag" "YES" {
    fileinto "Junk";
    stop;
}

if header :is "X-Spam" "Yes" {
    fileinto "Junk";
    stop;
}

# implicit keep and train copy as ham 
pipe :copy "rspamc" ["learn_ham"];
