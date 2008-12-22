#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Data::Dumper;

use CouchDB::Client qw();

my $cdb = CouchDB::Client->new( uri => $ENV{COUCHDB_CLIENT_URI} || 'http://localhost:5984/' );

# CONFIG
my $dbName = 'test-perl-couchdb-client/';
my $dbNameNot = 'test-perl-couchdb-client-NOT-EXISTS/';
my $baseDocName = 'TEST-DOC';

if($cdb->testConnection) {
    my $v = $cdb->serverInfo->{version};
    my ($maj, $min) = ($v =~ m/^(\d+)\.(\d+)\./);
    if ($maj == 0 and $min < 8) {
        plan skip_all => "Requires CouchDB version 0.8.0 or better; running $v";
    }
    else {
        plan tests => 63;
    }
}
else {
    plan skip_all => 'Could not connect to CouchDB, skipping.';
    warn <<EOMSG;
You can specify how these tests can connect to CouchDB by setting the 
COUCHDB_CLIENT_URI environment variable to the address of your server.
EOMSG
    exit;
}

### COMMON
my $docName;
my $cnt = 0;
sub docName {
    $cnt++;
    return "${baseDocName}-$cnt";
}


### --- CLIENT TESTS ----------------------------------------------------------- ###

# server info
{
    my $si = $cdb->serverInfo;
    ok $si->{couchdb} eq 'Welcome' && exists $si->{version}, 'serverInfo works';    
}

# list DBs
{
    my $dbs = $cdb->listDBs;
    ok ref($dbs) eq 'ARRAY', 'listDBs at least returns a list of something';
    my $dbs2 = $cdb->listDBNames;
    ok ref($dbs2) eq 'ARRAY', 'listDBNames at least returns a list of something';
    ok @$dbs == @$dbs2, 'listDBNames and listDBs return the same number of items';
}

# new DB & exists
{
    my $db = $cdb->newDB($dbName);
    ok $db->isa('CouchDB::Client::DB'), 'newDB creates DBs';
    eval { $db->delete; };
    eval { $db->create; };
    SKIP: {
        skip("Issue creating a DB: $@", 2) if $@;
        ok $cdb->dbExists($dbName), 'dbExists sees an existing DB';
        ok !$cdb->dbExists($dbNameNot), 'dbExists does not see a non-extant DB';        
    }
    eval { $db->delete; };
}



### --- DB TESTS --------------------------------------------------------------- ###

my $DB;
eval {
    $DB = $cdb->newDB($dbName)->create();
};
ok $DB, 'DB create';

# name validation
{
    my $goodName = '';
    $goodName .= $_ for ('a'..'z');
    $goodName .= '_$()+-/';
    $goodName .= $_ for (0..9);
    $goodName .= '/';
    ok $DB->validName($goodName), 'Valid names accepted';

    my $badName1 = $goodName;
    $badName1 =~ s{\/$}{};
    ok not($DB->validName($badName1)), 'Trailing slash required';

    my $badName2 = $goodName;
    $badName2 = uc($badName2);
    ok not($DB->validName($badName2)), 'Uppercase rejected';

    my $badName3 = $goodName;
    $badName3 =~ s{_\$}{\&};
    ok not($DB->validName($badName3)), 'Invalid character rejected';
}

# create & delete, more proper
{
    eval { $DB->create; };
    ok $@, "Database could not be created twice";

    ok $DB->delete, "Database could be deleted after creation";
    eval { $DB->delete; };
    ok $@, "Database cannot be deleted twice";

    # recreate
    ok $DB->create, "Database re-created";
}

# dbInfo
{
    my $info = $DB->dbInfo;
    ok $info, "dbInfo available";
    ok $info->{db_name} . '/' eq $dbName, "Data in dbInfo";
    
}

# list Docs
{
    my $docs = $DB->listDocs;
    ok ref($docs) eq 'ARRAY', 'listDocs at least returns a list of something';
    my $docs2 = $DB->listDocIdRevs;
    ok ref($docs2) eq 'ARRAY', 'listDocIdRevs at least returns a list of something';
    ok @$docs == @$docs2, 'listDocIdRevs and listDocs return the same number of items';
}

# new Doc & exists
{
    $docName = docName();
    my $doc = $DB->newDoc($docName);
    ok $doc->isa('CouchDB::Client::Doc'), 'newDoc creates Docs';
    eval { $doc->delete; };
    eval { $doc->create; };
    SKIP: {
        skip("Issue creating a Doc: $@", 2) if $@;
        ok $DB->docExists($docName), 'docExists sees an existing Doc';
        ok !$DB->docExists($docName . '-NOT-EXISTS'), 'docExists does not see a non-extant Doc';
    }
    eval { $doc->delete; };
}

# list Design Docs
{
    my $docs = $DB->listDesignDocs;
    ok ref($docs) eq 'ARRAY', 'listDesignDocs at least returns a list of something';
    my $docs2 = $DB->listDesignDocIdRevs;
    ok ref($docs2) eq 'ARRAY', 'listDesignDocIdRevs at least returns a list of something';
    ok @$docs == @$docs2, 'listDesignDocIdRevs and listDesignDocs return the same number of items';
}

# new Design Doc & exists
{
    $docName = docName();
    $docName = "_design/$docName";
    my $doc = $DB->newDesignDoc($docName);
    ok $doc->isa('CouchDB::Client::DesignDoc'), 'newDesignDoc creates DesignDocs';
    eval { $doc->delete; };
    eval { $doc->create; };
    SKIP: {
        skip("Issue creating a DesignDoc: $@", 2) if $@;
        ok $DB->designDocExists($docName), 'designDocExists sees an existing DesignDoc';
        ok !$DB->designDocExists($docName . '-NOT-EXISTS'), 'designDocExists does not see a non-extant DesignDoc';
    }
    eval { $doc->delete; };
}


### --- DOC TESTS --------------------------------------------------------------- ###

# create
$docName = docName();
my $DOC = $DB->newDoc($docName);
eval { $DOC->retrieve && $DOC->delete; };
eval { $DOC = $DOC->create; };
ok $DOC && !$@, 'Doc created';

# fields
{
    ok $DOC->id eq $docName, 'ID is good';
    ok $DOC->rev, 'there is a rev';
    $DOC->data({ foo => 'bar' });
    ok $DOC->data->{foo} eq 'bar', 'data works';
}

# update
{
    my $oldRev = $DOC->rev;
    $DOC->update;
    ok $DOC->id eq $docName, 'ID is stable after update';
    ok $DOC->rev != $oldRev, 'Rev changes on update';
    ok $DOC->data->{foo} eq 'bar', 'Update maintains data';
}

# delete
{
    $docName = docName();
    my $d = $DB->newDoc($docName)->create->delete;
    ok $d->{deletion_stub_rev}, 'Added deletion_stub_rev';
}

# attach
{
    $DOC->addAttachment('dahut.txt', 'text/plain', "Dahuts will rule the world!");
    $DOC->addAttachment('page.html', 'application/xhtml+xml', "<p>Dahuts will rule the world!</p>");
    ok keys %{$DOC->attachments} && keys %{$DOC->attachments} == 2, 'Attachments were added';
    $DOC->update;
    ok $DOC->fetchAttachment('dahut.txt') eq 'Dahuts will rule the world!', "Attachment 1 worked";
    ok $DOC->fetchAttachment('page.html') eq '<p>Dahuts will rule the world!</p>', "Attachment 2 worked";
    eval { $DOC->fetchAttachment('NOT-THERE'); };
    ok $@, 'Non-extant attachments are not returned';
}

### --- DESIGN DOC TESTS --------------------------------------------------------- ###

# create
$docName = '_design/' . docName();
my $DD = $DB->newDesignDoc($docName);
eval { $DD->retrieve && $DD->delete; };
eval { $DD = $DD->create; };
ok $DD && !$@, 'DesignDoc created';

# fields
{
    ok $DD->id eq $docName, 'ID is good';
    ok $DD->rev, 'there is a rev';
    $DD->views({ all => { map => 'function (doc) {}'} });
    ok $DD->views->{all}->{map} eq 'function (doc) {}', 'views works';
}

# update
{
    $DD->update;
    ok $DD->views->{all}->{map} eq 'function (doc) {}', 'Update maintains views';
}

# list
{
    my @ls = $DD->listViews;
    ok @ls == 1 && $ls[0] eq 'all', 'listViews works';
}

# query
{
    $DD->views({
        all => {
            map => 'function (doc) { emit(null, doc); }'
        },
        foo => {
            map => 'function (doc) { if (doc.foo == "bar") emit(doc.foo, doc); }'
        },
    });
    $DD->update;
    my @ls = $DD->listViews;
    ok @ls == 2, 'multiple listViews works';
    my $res;
    $res = $DD->queryView('all');
    ok $res && @{$res->{rows}} == 1, "queryView for all works";
    $res = $DD->queryView('foo', key => 'bar');
    ok $res && @{$res->{rows}} == 1, "queryView for foo?key=bar works";
    $res = $DD->queryView('foo', key => 'bar', descending => 1);
    ok $res && @{$res->{rows}} == 1, "queryView for foo?key=bar descending works";
    $res = $DD->queryView('foo', key => 'bar', count => 0);
    ok $res && @{$res->{rows}} == 0, "queryView for foo?key=bar count=0 works";
    $res = $DD->queryView('foo', key => 'not-there');
    ok $res && @{$res->{rows}} == 0, "queryView for foo?key=not-there works";
    eval { $DD->queryView('not-there'); };
    ok $@, "Non-extant view doesn't work";
}


### --- BULK TESTS --------------------------------------------------------- ###
my @docs;
for my $n (1..10) {
    push @docs, $DB->newDoc("foo-$n", undef, { bulky => 1 });
}
ok $DB->bulkStore(\@docs), 'bulk store';
my $res = $DD->queryView('all');
ok $res && @{$res->{rows}} == 11, "bulk was inserted";
ok $DB->bulkDelete(\@docs), 'bulk delete';
$res = $DD->queryView('all');
ok $res && @{$res->{rows}} == 1, "bulk was deleted";


### --- TEMP VIEWS --------------------------------------------------------- ###
{
    my $res = $DB->tempView({ map => 'function (doc) { if (doc.foo == "bar") emit(doc.foo, doc); }' });
    ok $res && @{$res->{rows}} == 1, "temp view works";
}


### --- DOC REVISIONS --------------------------------------------------------- ###
{
    my $ri = $DOC->revisionsInfo;
    ok $ri && @$ri == 3, "Revision info ok";
    ok $ri->[0]->{status} eq 'available' && $ri->[0]->{rev} == $DOC->rev, "revisions are good";
    ok $DOC->retrieveFromRev($ri->[1]->{rev}), "old version ok";
}


### --- THE CLEANUP AT THE END

$DD->delete;
$DOC->delete;
$DB->delete;

