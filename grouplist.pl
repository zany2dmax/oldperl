#!/usr/bin/perl

# script to print out groups for use in tennessee
print <<END;

The following groups are used for the Tennessee product

GID Group	Description
400 support1	Basic Technical Support group
401 support2	Mid-tier Technical Support
402 sysadmin1	Support Sysadmin Group
403 sysadmin2	NOC
404 sysadmin3	Product/Design Engineering
405 ubersys	Product owner

Other administrative groups which allow for elevated scooby access
300 security	SOC
350 fullshell	Unrestricted shell access (non-root)
END
