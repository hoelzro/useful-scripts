#!/usr/bin/env perl

use autodie;
use strict;
use warnings;
use feature qw(say);
use experimental qw(signatures);

use POSIX qw(WEXITSTATUS);

my %OPTION_ARITY = (
    as                      => 1,
    'as-group'              => 1,
    'cache-dir'             => 1,
    'certificate-authority' => 1,
    'client-certificate'    => 1,
    'client-key'            => 1,
    cluster                 => 1,
    context                 => 1,
    kubeconfig              => 1,
    'log-backtrace-at'      => 1,
    'log-dir'               => 1,
    'log-file'              => 1,
    'log-file-max-size'     => 1,
    'log-flush-frequency'   => 1,
    n                       => 1,
    namespace               => 1,
    password                => 1,
    profile                 => 1,
    'profile-output'        => 1,
    'request-timeout'       => 1,
    s                       => 1,
    server                  => 1,
    stderrthreshold         => 1,
    'tls-server-name'       => 1,
    token                   => 1,
    user                    => 1,
    username                => 1,
    vmodule                 => 1,
);

my @global_options;

while(@ARGV) {
    if($ARGV[0] =~ /^-/) {
        my $option = shift @ARGV;
        push @global_options, $option;

        my $no_dash = $option =~ s/^-{1,2}//r;
        my $arity;
        if($no_dash =~ /=/) {
            # if it's --option=value, the option argument is embedded within
            # current token - thus it's not in the subsequent token
            $arity = 0;
        } else {
            $arity = $OPTION_ARITY{$no_dash} // 0;
        }
        push @global_options, splice(@ARGV, 0, $arity);
    } else {
        last;
    }
}

my $subcommand = $ARGV[0] // '';

my @kubectl_args;

push @kubectl_args, $subcommand if $subcommand;
push @kubectl_args, @global_options;
push @kubectl_args, @ARGV[1..$#ARGV];

my $pager_write;

# if running k logs and we're not redirecting output already, redirect to my pager
if($subcommand eq 'logs' && -t STDOUT) {
    my $pager_read;

    pipe($pager_read, $pager_write);
    my $pager_pid = fork;

    if($pager_pid) {
        close $pager_read;
    } else {
        close $pager_write;
        open STDIN, '<&', $pager_read;

        my $kubectl_logs_pager = $ENV{'KUBECTL_LOGS_PAGER'} // $ENV{'PAGER'} // 'less';
        exec 'sh', '-c', $kubectl_logs_pager;
    }
}

my $pid = fork;

if($pid) {
    if($pager_write) {
        close $pager_write;
    }

    waitpid $pid, 0;
    my $exit_status = $?;

    my $kid = waitpid(-1, 0);
    while($kid >= 0) {
        $kid = waitpid(-1, 0);
    }

    exit WEXITSTATUS($exit_status);
} else {
    if($pager_write) {
        open STDOUT, '>&', $pager_write;
    }
    exec 'kubectl', @kubectl_args;
}

# k logs should do the right thing if there's more than one container (kubectl.kubernetes.io/default-container)
# k get -o custom-columns=... -o custom-columns should compose the custom-columns options
# k wait should wait for a selector match too
# k exec - some sort of history mechanism (even across different pods), tab completion using the pod's context, persistent tunnel (akin to ssh's ControlPersist and friends)
# do the right thing if there's a single pod in a namespace
# show certain labels by default?
# better rendering of --show-labels
# k get pod - group by labels/ownerReference/something
# colors?
# if there are "no resources in a namespace", verify I didn't goof up the namespace's name
