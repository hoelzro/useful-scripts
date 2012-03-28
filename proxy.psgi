#!/usr/bin/env twiggy

use strict;
use warnings;

use Data::Dumper;
use Plack::App::Proxy;
use Plack::Builder;

my $proxy = Plack::App::Proxy->new(preserve_host_header => 1)->to_app;

builder {
    enable sub {
        my ( $app ) = @_;

        return sub {
            my ( $env ) = @_;

            $env->{'plack.proxy.url'} = $env->{'REQUEST_URI'};

            return $app->($env);
        };
    };
    $proxy;
};
