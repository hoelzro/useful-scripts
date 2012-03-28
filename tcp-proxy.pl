#!/usr/bin/env perl

use strict;
use warnings;

use AnyEvent::Handle;
use AnyEvent::Socket;

sub logmsg {
    print STDERR @_;
    print STDERR "\n";
}

sub create_proxy {
    my ( $port, $remote_host, $remote_port ) = @_;

    my %handles;

    return tcp_server '127.0.0.1', $port, sub {
        my ( $client_fh, undef, $client_port ) = @_;

        logmsg("received connection from :$client_port");

        my $client_h = AnyEvent::Handle->new(
            fh => $client_fh,
        );

        $handles{$client_h} = $client_h;

        tcp_connect $remote_host, $remote_port, sub {
            unless(@_) {
                logmsg("connection failed: $!");
                $client_h->destroy;
                return;
            }
            my ( $host_fh ) = @_;

            my $host_h = AnyEvent::Handle->new(
                fh => $host_fh,
            );

            $handles{$host_h} = $host_h;

            $client_h->on_read(sub {
                my $buffer      = $client_h->rbuf;
                $client_h->rbuf = '';

                $host_h->push_write($buffer);
            });

            $client_h->on_error(sub {
                my ( undef, undef, $msg ) = @_;
                logmsg("transmission error: $msg");
                $client_h->destroy;
                $host_h->destroy;

                delete @handles{$client_h, $host_h};
            });

            $client_h->on_eof(sub {
                logmsg("client closed connection");
                $client_h->destroy;
                $host_h->destroy;
                delete @handles{$client_h, $host_h};
            });

            $host_h->on_read(sub {
                my $buffer    = $host_h->rbuf;
                $host_h->rbuf = '';

                $client_h->push_write($buffer);
            });

            $host_h->on_error(sub {
                my ( undef, undef, $msg ) = @_;
                logmsg("transmission error: $msg");

                $host_h->destroy;
                $client_h->destroy;
                delete @handles{$client_h, $host_h};
            });

            $host_h->on_eof(sub {
                logmsg("host closed connection");
                $host_h->destroy;
                $client_h->destroy;
                delete @handles{$client_h, $host_h};
            });
        };
    };
}

unless(@ARGV >= 3) {
    print <<"END_USAGE";
usage: $0 [listen port] [remote host] [remote port]

$0 sets up a TCP proxy that listens on [listen port].
When a connection is made on that port, a connection is
made to [remote host]:[remote port] and data are moved
back and forth.
END_USAGE
}

my ( $port, $remote_host, $remote_port ) = @ARGV;

my $cond = AnyEvent->condvar;

my $proxy = create_proxy($port, $remote_host, $remote_port);

$cond->recv;
