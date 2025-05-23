use Mail::Sendmail qw(sendmail %mailcfg);

$LINE[0] = "this is line 1\n";
$LINE[1] = "this is line 2\n";
$LINE[2] = "this is line 3\n";
# print @LINE;

$mail{To}= 'securityengineering@interland.com';
$mail{From}= 'patchlink1@patchlink1.interland.net',
$mail{Message} = "@LINE";

$mailcfg{smtp} = [qw(mailhub.registeredsite.com)];

sendmail (%mail) or die $Mail::Sendmail::error;
print "OK.  Log says:\n", $Mail::Sendmail::log;
