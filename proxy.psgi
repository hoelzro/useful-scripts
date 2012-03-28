#!/usr/bin/env plackup

use strict;
use warnings;

use Data::Dumper;
use Plack::App::Proxy;

my $proxy = Plack::App::Proxy->new(preserve_host_header => 1)->to_app;

sub {
    my ( $env ) = @_;

    $env->{'plack.proxy.url'} = $env->{'REQUEST_URI'};

    return $proxy->($env);
}
