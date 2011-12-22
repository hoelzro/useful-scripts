#!/usr/bin/env perl

# see xmpp-notify.pl --help for details

use strict;
use warnings;
use feature 'say';

use AnyEvent::Handle;
use AnyEvent::XMPP::IM::Connection;
use AnyEvent::XMPP::IM::Message;
use AnyEvent::XMPP::Util qw(split_jid);
use Getopt::Long;
use Readonly;
use Term::ANSIColor;
use Try::Tiny;
use YAML ();
use XML::Tidy;

Readonly::Scalar my $IS_DEBUGGING          => 0;
Readonly::Scalar my $WAIT_FOR_SEND_SECONDS => 3;

sub usage {
    print <<"END_USAGE";
usage: $0 [-c config_file] [-l] [-i] [-f file] [message...]

$0 is a tool for sending XMPP notifications to a destination.

--config|-c filename - Read configuration from filename.
--input|-i           - Read the message from standard input.
--file|-f filename   - Read the message from filename.
--lines              - Read the message from standard input, and send each
                       line as an individual message.

If -i, -l, or -f is not provided, the remaining command line arguments are
joined together with spaces as used as the message to send.

The configuration file is required and should be a YAML file that contains
XMPP connection information.  It should look something like this:

---
jid: my.jid\@domain.com
password: ******
destination: my.other.jid\@domain.com
END_USAGE

    exit 0;
}

sub get_xmpp_options {
    my ( $config_file ) = @_;

    my @xmpp_config_keys = qw(
        username
        domain
        resource
        host
        password
        port
        destination
    );

    my $config = YAML::LoadFile($config_file);
    my %options;

    if(my $jid = $config->{'jid'}) {
        @{$config}{qw/username domain resource/} = split_jid($jid);
    }

    unless(exists $config->{'google_talk'}) {
        $config->{'google_talk'} = $config->{'domain'} eq 'gmail.com';
    }

    if($config->{'google_talk'}) {
        @options{qw/host old_style_ssl port/} = ( 'talk.google.com', 1, 5223 );
    }

    my @missing_keys = grep { !exists $options{$_} } @xmpp_config_keys;

    @options{@missing_keys} = @{$config}{@missing_keys};

    return \%options;
}

sub process_command_line {
    my %options = (
        from_stdin   => 0,
        from_file    => 0,
        line_by_line => 0,
    );

    my $help;

    my $success = GetOptions(
        input      => \$options{'from_stdin'},
        'file=s'   => \$options{'from_file'},
        lines      => \$options{'line_by_line'},
        'config=s' => \$options{'config_file'},
        help       => \$help,
    );
    usage() unless !$help && $success && $options{'config_file'};

    $options{'xmpp'} = get_xmpp_options(delete $options{'config_file'});

    if($options{'line_by_line'}) {
        $options{'from_stdin'} = 1;
        # XXX complain if $options{'from_file'}?
        $options{'from_file'} = 0;
    }

    unless($options{'from_stdin'} || $options{'from_file'} || @ARGV) {
        usage();
        die "usage: $0 [-l] [-i] [-f file] [message...]\n";
    }

    return \%options;
}

sub load_body {
    my ( $options ) = @_;

    my $body;

    my ( $from_stdin, $from_file ) = @{$options}{qw/from_stdin from_file/};

    if($from_stdin || $from_file) {
        my $fh;

        if($from_stdin) {
            $fh = \*STDIN;
        } else {
            open $fh, '<', $from_file or die "Unable to open $from_file: $!\n";
        }

        $body = do {
            local $/;

            <$fh>;
        };

        close $fh;
    } elsif(@ARGV) {
        $body = join(' ', @ARGV);
    }

    return $body;
}

sub send_msg {
    my ( $conn, $body, $options ) = @_;

    my $msg = AnyEvent::XMPP::IM::Message->new(
        to   => $options->{'xmpp'}{'destination'},
        type => 'chat',
        body => $body,
    );
    $msg->send($conn);
}

sub send_line_by_line {
    my ( $options, $conn ) = @_;

    my $h = AnyEvent::Handle->new(
        fh   => \*STDIN,
        poll => 'r',
    );

    $h->on_read(sub {
        my ( $h ) = @_;

        $h->push_read(line => sub {
            my ( undef, $line ) = @_;
            send_msg($conn, $line, $options);
        });
    });

    $h->on_eof(sub {
        my $timer;
        $timer = AnyEvent->timer(
            after => $WAIT_FOR_SEND_SECONDS,
            cb    => sub {
                undef $timer;
                $conn->disconnect;
            },
        );
        $h->destroy;
        undef $h;
    });
}

sub send_single {
    my ( $options, $conn ) = @_;

    send_msg($conn, load_body($options), $options);

    my $timer;
    $timer = AnyEvent->timer(
        after => $WAIT_FOR_SEND_SECONDS,
        cb    => sub {
            undef $timer;
            $conn->disconnect;
        },
    );
}

sub handle_error {
    my ( undef, $conn, $error ) = @_;

    say $error->string;
    $conn->disconnect;
}

sub option_wrap {
    my ( $fn, $options ) = @_;

    return sub {
        return $fn->($options, @_);
    };
}

sub tidy_xml {
    my ( $xml ) = @_;

    try {
        my $tidy = XML::Tidy->new(xml => $xml);
        $tidy->tidy();
        $xml = $tidy->toString();
    };

    return $xml;
}

sub debug_send {
    my ( undef, $data ) = @_;

    say colored(['bold red'], tidy_xml($data));
}

sub debug_recv {
    my ( undef, $data ) = @_;

    say colored(['bold green'], tidy_xml($data));
}

sub get_connection {
    my ( $options, $cond ) = @_;

    my $xmpp_options = $options->{'xmpp'};

    my $conn = AnyEvent::XMPP::IM::Connection->new(
        %{$xmpp_options},
        initial_presence => undef,
    );

    my $is_line_by_line = $options->{'line_by_line'};

    my %event_handlers = (
        error         => \&handle_error,
        session_ready => $is_line_by_line
            ? \&send_line_by_line
            : \&send_single,
    );

    foreach my $handler (values %event_handlers) {
        $handler = option_wrap($handler, $options);
    }

    if($IS_DEBUGGING) {
        @event_handlers{qw/debug_send debug_recv/}
            = ( \&debug_send, \&debug_recv );
    }

    $conn->reg_cb(
        %event_handlers,
        disconnect => sub {
            $cond->send;
        },
    );

    $conn->connect;

    return $conn;
}

my $cond       = AnyEvent->condvar;
my $options    = process_command_line();
my $connection = get_connection($options, $cond);

$cond->recv;
