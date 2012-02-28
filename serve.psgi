#!/usr/bin/env plackup

use strict;
use warnings;

use Plack::App::Directory;

Plack::App::Directory->new({
    root => '.',
})->to_app;
