#!/usr/pkg/bin/perl
#

use Test::More tests => 2;

use Krb5Admin::C;

use strict;
use warnings;

$ENV{KRB5_CONFIG} = 'FILE:./t/krb5.conf';

my  $ctx   = Krb5Admin::C::krb5_init_context();
our $hndl  = Krb5Admin::C::krb5_get_kadm5_hndl($ctx, undef);
our $realm = Krb5Admin::C::krb5_get_realm($ctx);

#
# XXXrcd: these tests do not actually validate the ticket properly.
#         This will require that we run a KDC and all that.

my $ret;

eval {
	$ret = Krb5Admin::C::mint_ticket($ctx, $hndl, 'elric', 3600, 7200);
};

ok(!$@) or diag("$@");

eval {
	if (!defined($ret)) {
		# We did not get valid creds from the last operation.
		# Well...  for now, construct them.

		$ret = {
			client   => 'user@EXAMPLE.COM',
			server   => 'krbtgt/EXAMPLE.COM@EXAMPLE.COM',
			keyblock => { enctype => 17, key => '0123456789abcdef'},
			ticket   => 'This is my ticket!!!',
			flags    => 0x00400000,
			starttime=> time(),
			endtime  => time() + 3600 * 24,
		};
	}
	Krb5Admin::C::init_store_creds($ctx, undef, $ret);
};

ok(!$@) or diag("$@");

exit 0;