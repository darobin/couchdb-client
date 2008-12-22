#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Data::Dumper;

use CouchDB::Client             qw();
use CouchDB::Client::DB         qw();
use CouchDB::Client::Doc        qw();
use CouchDB::Client::DesignDoc  qw();

use JSON::Any;
use LWP::UserAgent;

my $cdb = CouchDB::Client->new( uri => $ENV{COUCHDB_CLIENT_URI} || 'http://localhost:5984/' );
if($cdb->testConnection) {
    plan tests => 10;
}
else {
    plan skip_all => 'Could not connect to CouchDB, skipping.';
    warn <<EOMSG;
You can specify how these tests can connect to CouchDB by setting the 
COUCHDB_CLIENT_URI environment variable to the address of your server.
EOMSG
    exit;
}

my $C = $cdb;
my $DB = $C->newDB('blah');

### DESIGN DOC
{
    my $dd;
    eval { $dd = CouchDB::Client::DesignDoc->new({
                    id => '_design/foo', 
                    data => {
                        language => 'perl',
                        views   => {
                            all => { map => 'function (doc) {}'},
                        },
                    },
                    db => $DB}); };
    ok !$@, 'different ctor works';
    eval { CouchDB::Client::DesignDoc->new({ id => 'foo', db => $DB }); };
    ok $@, "bad id blows: $@";
    eval { $dd->queryView('all'); };
    ok $@, "no connection blows: $@";
}

# CLIENT
{
    my $c;
    $c = CouchDB::Client->new({uri => 'http://test'});
    ok $c && $c->{uri} =~ m{/$}, "Trailing / added";
    $c = CouchDB::Client->new();
    ok $c && $c->{uri} eq 'http://localhost:5984/', 'Default URI';
    $c = CouchDB::Client->new(scheme => 'https', host => 'example.org', port => '9000');
    ok $c && $c->{uri} eq 'https://example.org:9000/', 'URI by fragments';
    $c = CouchDB::Client->new(json => JSON::Any->new, ua => LWP::UserAgent->new);
    ok $c && $c->{json} && $c->{ua}, 'helper objects';
    
    # bad address
    $c = CouchDB::Client->new(scheme => 'https');
    ok !$c->testConnection, "no connection";
    eval { $c->serverInfo };
    ok $@, "Could not connect for serverInfo: $@";
    eval { $c->listDBNames };
    ok $@, "Could not connect for listDBNames: $@";
}

