#! /usr/bin/perl
use strict;

use Expect;
$Expect::Log_Stdout = 0;

#my $prg = debian_stable_check('mirror.yandex.ru');
my $prg = mplayer_ctrl('ctrl');

eval {
    print "Current Debian STABLE is ",
        $prg->(shell()
            or die "Can`t spawn shell: $!"),
        "\n";
};
print "Error: $@"
    if $@;

#################################################################


sub mplayer_ctrl {
    my $ctrl_file = shift;
    my $env = { TIMEOUT => 1 };
    runsh($env, "cat >/tmp/pppp",
            __TIMEOUT   => sub {
                    my $sh = shift @{$_[0]};
                    print $sh;
                    print $sh "PPP\n";
                    'exp_continue'
                },
        )
}


sub debian_stable_check {
    my $mirror = shift;
    my $env = { RVAL => '!!!UNKNOWN!!!' };
    runsh($env, "lftp",
        __READY =>
            runsh($env, "open ".$mirror,
                    __READY =>
                        runsh($env, 'ls /debian/dists/',
                            qr"[^n]stable[^-]+\-\>[^\w]+(\w+)" =>
                                f_setenv('RVAL', f_getmatch()),

                            __READY =>
                                f_die('No symlink to stable'),
                            __TIMEOUT =>
                                f_die('Network error: timeout'),
                        ),

            ),

        __END => f_return(f_getenv('RVAL'))
        )
}




#my $cc1 = ping('ya.ru');
#my $cc2 = ping('google.com');
#pinfo("Exe 1: ", exe($sh, $cc1, 'Hi', 'boss!'));
#pinfo("Exe 2: ", exe($sh, $cc2, 'Hi', 'boss!'));

# sub ping {
#     my $host = shift
#         || '127.0.0.1';
#     sh({ }, "ping -c 1 ".$host, $SHELLPROMPT,
#         '64 bytes from' => setrval("OK"),
#         'Unreachable' => setrval('Unreach'),
# #        timeout => setrval('Timeout'),
# #        'packets transmitted' => debug(),
#         );
# }

#################################################################
#################################################################
#################################################################

sub shell { Expect->spawn('/bin/sh') }

sub exe { $_[1]->( @_) }

sub runsh {
    my ($env, $cmd, %args) = @_;
    die "Env must be hash ref, but not ".ref $env
        unless ref $env eq 'HASH';
    $env->{PROMPT} = qr'[\$\>\#]\s$'
        unless exists $env->{PROMPT};
    my $promptc =
        ref $args{__READY} eq 'CODE'
            ? sub { $args{__READY}->(@_) }
            : sub { undef };
    pre($env->{TIMEOUT} || 5, $env, $cmd."\n",
            $env->{PROMPT} => $promptc,
           %args,
        )
}

sub f_setenv {
    my ($key, $val, %flags) = @_;
    my $type = ref $val;
    sub {
        my (undef, $env) = @_;
        $env->{$key} = $type
            ? $type eq 'CODE'
                ? $val->(@_)
                : $type eq 'ARRAY'
                    ? [ @{$val} ]
                    : $type eq 'HASH'
                        ? { %{$val} }
                        : $type eq 'SCALAR'
                            ? \${$$val}
                            : die "Unwanted value type $type"
            : $val;
        $flags{'CONTINUE'}
            ? 'exp_continue'
            : undef
    }
}

sub f_getenv {
    my ($key) = @_;
    sub {
        my (undef, $env) = @_;
        $env->{$key}
    }
}


#################################################################
#################################################################

sub f_getmatchlist { sub { shift->matchlist() } }

sub f_getmatch { sub { shift->matchlist()->[0] } }

sub f_die {
    my @args = @_;
    sub { die @args }
}

sub f_return {
    my $val = shift;
    my $type = ref $val;
    sub {
        $type
            ? $type eq 'CODE'
                ? $val->(@_)
                : $type eq 'ARRAY'
                    ? [ @{$val} ]
                    : $type eq 'HASH'
                        ? { %{$val} }
                        : $type eq 'SCALAR'
                            ? \${$$val}
                            : die "Unwanted value type $type"
            : $val
    }
}


sub debug {
    my %flags = @_;
    sub {
        my ($sh, $ctx, @args) = @_;
        pinfo("args: ", join(", ", @_));
        pinfo("ctx: ", join(", ", map { $_."=".$ctx->{$_} } keys %{$ctx}));
#        pinfo("matchs: ", join(", ", $sh->matchlist()));
        $flags{'CONTINUE'}
            ? 'exp_continue'
            : undef
    }
}
sub pinfo { p("INFO", @_) };
sub p { print STDERR "\n\t[", shift, "] ", @_, "\n" };

#################################################################

sub pre {
    my ($timeout, $_ctx, $cmd, %args) = @_;
    my $beginc = $args{__BEGIN}
        if $args{__BEGIN};
    my $endinc = $args{__END}
        if $args{__END};
    my $ttlinc = ref $args{__TIMEOUT} eq 'CODE'
        ? sub { $args{__TIMEOUT}->(@_) }
        : sub { die "Timeout on cmd $cmd" };
    my %hooks =
        map { $_ => $args{$_} }
            grep { $_ !~ /\_\_/ }
                keys %args;
    sub {
        $_[1] = $_ctx # Fix CTX (for first run)
            unless ref $_[1];
        my ($sh, @myargs) = @_;
        die "Where mr. Expect? $sh"
            unless ref($sh) eq 'Expect';
        $beginc->($sh, @myargs)
            if ref $beginc eq 'CODE';
        print $sh $cmd
            if $cmd;
        my $rval = $sh->expect($timeout,
                [ 'timeout', $ttlinc, @myargs],
                map { [ $_, $hooks{$_}, @myargs] }
                    keys %hooks
            );
        ref $endinc eq 'CODE'
            ? $endinc->($sh, @myargs, $rval)
            : defined $rval
                ? $rval
                : undef
    }
}

