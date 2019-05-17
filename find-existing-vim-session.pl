#!/usr/bin/env perl

use 5.14.0;
use warnings;
use autodie;

use File::Spec;
use Getopt::Long;

sub expand_tilde {
    my ( $path ) = @_;

    return $path =~ s{
        [~](?<user>[^/]*)
    }{
        if(my $user = $+{'user'}) {
            (getpwnam($user))[7]
        } else {
            (getpwuid($<))[7]
        }
    }rxe;
}

sub find_owner_pid {
    my ( $filename ) = @_;

    my $pipe;
    open $pipe, 'vim -r 2>&1 |';
    binmode $pipe, ':crlf';

    my %filename_to_pid;
    my $current_filename;

    while(<$pipe>) {
        chomp;

        if(/^\d+[.]/) {
            undef $current_filename;
        } elsif(/^\s*file\s+name:\s*(?<filename>.*)/) {
            $current_filename = expand_tilde($+{'filename'});
        } elsif(/^\s*process\s+ID:\s*(?<pid>\d+)\s+\(still running\)/i) {
            $filename_to_pid{$current_filename} = $+{'pid'};
        }
    }

    close $pipe;

    return $filename_to_pid{$filename};
}

sub get_environment {
    my ( $pid ) = @_;

    open my $fh, '<', "/proc/$pid/environ";
    my $contents = do {
        local $/;
        <$fh>
    };
    close $fh;

    return {
        map {
            split /=/, $_, 2
        } split /\0/, $contents
    };
}

sub awesome_do {
    my ( $lua ) = @_;

    open my $pipe, '| awesome-client';
    print { $pipe } $lua;
    close $pipe;
}

sub goto_window {
    my ( $id ) = @_;

    awesome_do <<"END_LUA";
local awful = require 'awful'
local clients = client.get()
for _, c in ipairs(clients) do
    if c.window == $id then
        local tags = c:tags()
        awful.tag.viewonly(tags[1])
        client.focus = c
        c:raise()
        break
    end
end
END_LUA
}

sub bring_window_here {
    my ( $id ) = @_;

    # XXX also make it the master window?
    awesome_do <<"END_LUA";
local awful = require 'awful'
local clients = client.get()
for _, c in ipairs(clients) do
    if c.window == $id then
        local current_tag = awful.tag.selected()
        c:tags { current_tag }
        client.focus = c
        c:raise()
        break
    end
end
END_LUA
}

sub find_tmux_info_by_pane {
    my ( $pane ) = @_;

    open my $pipe, q{tmux list-panes -a -F '#{pane_id} #{session_name} #{window_index} #{pane_index}' |};
    while(<$pipe>) {
        chomp;

        my ( $pane_id, $session_name, $window_index, $pane_index ) = split;

        if($pane_id eq $pane) {
            return ( $session_name, $window_index, $pane_index );
        }
    }
    close $pipe;
    return;
}

sub attach_tmux_pane {
    my ( $session, $window, $pane ) = @_;

    my $pid = fork();

    if($pid) {
        system 'tmux', 'select-window', '-t', $window;
        system 'tmux', 'select-pane', '-t', $pane;
        waitpid $pid, 0;
    } else {
        exec 'tmux', 'attach-session', '-t', $session;
    }
}

sub goto_tmux_pane {
    my ( $session, $window, $pane ) = @_;

    system 'tmux', 'switch-client', '-t', $session;
    system 'tmux', 'select-window', '-t', $window;
    system 'tmux', 'select-pane', '-t', $pane;
}

sub bring_tmux_pane_here {
    my ( $session, $window, $pane ) = @_;

    system 'tmux', 'link-window', '-s', "$session:$window";
    system 'tmux', 'select-pane', '-t', $pane;
}

sub show_help {
    print <<"END_USAGE";
usage: $0 [options] filename

Options:
    -b --bring	Bring the window to your session/workspace.
    -g --goto	Go to the session/workspace with the window.
    -h --help	Display this help.
END_USAGE
    exit;
}

my $bring;
my $goto;
my $help;

GetOptions(
    'b|bring' => \$bring,
    'g|goto'  => \$goto,
    'h|help'  => \$help,
);

show_help if $help;
show_help unless @ARGV;

if($bring && $goto) {
    die "--bring and --goto are mutually exclusive\n";
} elsif(!$bring && !$goto) {
    $goto = 1;
}

my ( $filename ) = @ARGV;
$filename = File::Spec->rel2abs($filename);

my $owner = find_owner_pid($filename);
exit 1 unless $owner; # if there's no-one editing it, just exit

my $env = get_environment($owner);
my ( $tmux, $tmux_pane, $windowid ) = @{$env}{qw/TMUX TMUX_PANE WINDOWID/};

if($tmux) {
    my ( $session, $window, $pane ) = find_tmux_info_by_pane($tmux_pane);

    if($ENV{'TMUX'}) {
        if($goto) {
            goto_tmux_pane($session, $window, $pane);
        } else {
            bring_tmux_pane_here($session, $window, $pane);
        }
    } else {
        attach_tmux_pane($session, $window, $pane);
    }
} elsif($windowid) {
    if($goto) {
        goto_window($windowid);
    } else {
        bring_window_here($windowid);
    }
} else {
    say STDERR q{Can't find TMUX or WINDOWID; I don't know what to do!};
    exit 2;
}

__END__

=for PossibleImprovements

=over

=item *

Detect when vim is running under a tmux session I<not> connected to the default socket

=item *

Handle the situation where a pane is associated with two sessions

=back

=cut
