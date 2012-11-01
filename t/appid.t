#!/usr/pkg/bin/perl

use Test::More;

use Krb5Admin::ForkClient;

use Data::Dumper;

use strict;
use warnings;

sub testObjC {
	my ($testname, $obj, $result, $method, @args) = @_;

	my @ret;
	eval {
		my $code = $obj->can($method) or die "no method $method.";
		@ret = &$code($obj, @args);
	};

	if ($@) {
		ok(0, $testname);
		diag(Dumper($@));
	} else {
		is_deeply(\@ret, $result, $testname);
	}
}

$ENV{'KRB5_CONFIG'} = './t/krb5.conf';

my $kmdb = Krb5Admin::ForkClient->new({
    dbname	=> 'db:t/test-hdb',
    sqlite	=> 't/sqlite.db',
}, CREDS => 'admin_user@TEST.REALM');

#
# First, we create a few ACLs.  They must be created before the appids
# because appids will always reference at least one ACL.

our $acls = {
	'admin_user@TEST.REALM'	=> { type => 'krb5' },
	'elric@IMRRYR.ORG'	=> { type => 'krb5' },
	'yyrkoon@IMRRYR.ORG'	=> { type => 'krb5' },
	'cymoril@IMRRYR.ORG'	=> { type => 'krb5' },
	'sadric@IMRRYR.ORG'	=> { type => 'krb5' },
	'group1'		=> { type => 'group' },
	'group2'		=> { type => 'group' },
	'master_group'		=> { type => 'group' },
    };

my $i;
for $i (keys %$acls) {
	my $type = $acls->{$i}->{type};

	next if $i eq 'admin_user@TEST.REALM';	# now create in 00prepare.t.

	testObjC("Create ACL: $i", $kmdb, [undef], 'add_acl', $i, $type);
}

testObjC("Query ACLs", $kmdb, [$acls], 'query_acl');

#
# We then create a few appids and query them.

for $i (0..3) {
	testObjC("Create appid$i", $kmdb, [undef], 'create_appid', "appid$i");

	my $ret;
	eval { $ret = $kmdb->query("appid$i"); };

	ok(!$@, "query of appid$i");

	ok($ret->{principal}	eq "appid$i\@TEST.REALM", "appid$i princ true");
	is_deeply($ret->{owner}, ['admin_user@TEST.REALM'],
	    "appid$i owned correctly");
	ok(!defined($ret->{desc}), "appid$i desc is undef");
	is_deeply($ret->{cstraint}, [], "appid$i cstraint is empty");
}

#
# And let's populate the groups with some users and groups.

our $groups = {
	'group1'	=> [ 'elric@IMRRYR.ORG', 'yyrkoon@IMRRYR.ORG' ],
	'group2'	=> [ 'cymoril@IMRRYR.ORG', 'sadric@IMRRYR.ORG' ],
	'master_group'	=> [ 'group1', 'group2' ],
    };

for $i (keys %$groups) {
	for my $j (@{$groups->{$i}}) {
		testObjC("insert_aclgroup", $kmdb, [undef], 'insert_aclgroup',
		    $i, $j);
	}
}

testObjC("Query ACL groups", $kmdb, [$groups], 'query_aclgroup');

#
# And finally, we assign ACLs to our appids and test them in various ways.
# XXXrcd: in these tests, the owner array is not necessary sorted in the
#         order that we have here.  It's an implementation detail and so
#         these tests may eventually fail with a working implementation.

testObjC("Assign ACL: assign owner", $kmdb, [undef], 'modify',
    'appid0', owner => ['elric@IMRRYR.ORG']);
#testObjC("Query appid0", $kmdb, [{owner=>['elric@IMRRYR.ORG'], desc=>undef,
#    cstraint=>[]}], 'query', 'appid0');

testObjC("Assign ACL: add_owner", $kmdb, [undef], 'modify',
    'appid0', add_owner => ['yyrkoon@IMRRYR.ORG']);
#testObjC("Query appid0", $kmdb,
#    [{owner=>['elric@IMRRYR.ORG','yyrkoon@IMRRYR.ORG'], desc=>undef,
#      cstraint=>[]}], 'query', 'appid0');

testObjC("Assign ACL: del_owner", $kmdb, [undef], 'modify',
    'appid0', del_owner => ['elric@IMRRYR.ORG']);
#testObjC("Query appid0", $kmdb,
#    [{owner=>['yyrkoon@IMRRYR.ORG'], desc=>undef, cstraint=>[]}],
#    'query', 'appid0');

testObjC("Assign Group ACL", $kmdb, [undef], 'modify',
    'appid1', add_owner => ['group1']);
testObjC("Assign Group ACL", $kmdb, [undef], 'modify',
    'appid2', owner => ['group2']);
testObjC("Assign Group ACL", $kmdb, [undef], 'modify',
    'appid3', add_owner => ['master_group']);

testObjC("Is owner #0?", $kmdb, [0], 'is_appid_owner', 'elric@IMRRYR.ORG',
    'appid0');
testObjC("Is owner #1?", $kmdb, [1], 'is_appid_owner', 'yyrkoon@IMRRYR.ORG',
    'appid0');
testObjC("Is owner #2?", $kmdb, [1], 'is_appid_owner', 'elric@IMRRYR.ORG',
    'appid1');
testObjC("Is owner #3?", $kmdb, [0], 'is_appid_owner', 'sadric@IMRRYR.ORG',
    'appid1');
testObjC("Is owner #4?", $kmdb, [0], 'is_appid_owner', 'elric@IMRRYR.ORG',
    'appid2');
testObjC("Is owner #5?", $kmdb, [1], 'is_appid_owner', 'sadric@IMRRYR.ORG',
    'appid2');
testObjC("Is owner #6?", $kmdb, [1], 'is_appid_owner', 'elric@IMRRYR.ORG',
    'appid3');
testObjC("Is owner #7?", $kmdb, [1], 'is_appid_owner', 'sadric@IMRRYR.ORG',
    'appid3');

for $i (0..3) {
	$kmdb->remove("appid$i");
}

undef $kmdb;

done_testing();

exit(0);