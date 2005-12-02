=for gpg
-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA1

=head1 NAME

Time::Normalize - Convert time and date values into standardized components.

=head1 VERSION

This is version 0.02 of Normalize.pm, December 2, 2005.

=cut

use strict;
package Time::Normalize;
$Time::Normalize::VERSION = '0.02';
use Carp;
use POSIX;

# If exporting symbols:
use Exporter;
use vars qw/@ISA @EXPORT @EXPORT_OK/;
@ISA       = qw/Exporter/;
@EXPORT    = qw/normalize_hms normalize_time normalize_ymd normalize_gmtime/;
@EXPORT_OK = @EXPORT;

# Most error messages in this module look very similar.
# This standardizes them:
sub _bad
{
    my ($what, $value) = @_;
    croak qq{Time::Normalize: Invalid $what: "$value"};
}

# Current locale.
my $locale;

# Month names; Month names abbrs, Weekday names, Weekday name abbrs.
#  *All Mixed-Case!*
our (@Mon_Name, @Mon_Abbr, @Day_Name, @Day_Abbr);
# Lookup: string-month => numeric-month (also string-day => numeric-day)
our %number_of;

# Current year and century.  Used for guessing century of two-digit years.
my $current_year = (localtime)[5] + 1900;
my ($current_century, $current_yy) = $current_year =~ /(\d\d)(\d\d)/;

# Number of days in each (1-based) month (except February).
my @num_days_in = qw(0 31 29 31 30 31 30 31 31 30 31 30 31);

sub _days_in
{
    my ($y,$m) = @_;
    return $num_days_in[$m] if $m != 2;

    # February
    return _is_leap($y)? 29 : 28;
}

# Is a leap year?
sub _is_leap
{
    my $year = shift;
    return !($year%4) && ( ($year%100) || !($year%400) );
}

# Quickie function to pad a number with a leading 0.
sub _lead0 { $_[0] > 9? $_[0]+0 : '0'.($_[0]+0)}

# Compute day of week, using Zeller's congruence
sub _dow
{
    my ($Y, $M, $D) = @_;

    $M -= 2;
    if ($M < 1)
    {
        $M += 12;
        $Y--;
    }
    my $C = int($Y/100);
    $Y %= 100;

    return (int((26*$M - 2)/10) + $D + $Y + int($Y/4) + int($C/4) - 2*$C) % 7;
}


# Internal function to initialize locale info.
sub _setup_locale
{
    # Do nothing if locale has not changed since %names was set up.
    my $locale_in_use;
    $locale_in_use = POSIX::setlocale(POSIX::LC_TIME());
    $locale_in_use = q{} if  !defined $locale_in_use;

    # No changes needed
    return if defined $locale  &&  $locale eq $locale_in_use;

    $locale = $locale_in_use;

    eval
    {
        require I18N::Langinfo;
        I18N::Langinfo->import qw(langinfo);
        @Mon_Name  = map langinfo($_), (
                                        I18N::Langinfo::MON_1(),
                                        I18N::Langinfo::MON_2(),
                                        I18N::Langinfo::MON_3(),
                                        I18N::Langinfo::MON_4(),
                                        I18N::Langinfo::MON_5(),
                                        I18N::Langinfo::MON_6(),
                                        I18N::Langinfo::MON_7(),
                                        I18N::Langinfo::MON_8(),
                                        I18N::Langinfo::MON_9(),
                                        I18N::Langinfo::MON_10(),
                                        I18N::Langinfo::MON_11(),
                                        I18N::Langinfo::MON_12(),
                                       );
        @Mon_Abbr  = map langinfo($_), (
                                        I18N::Langinfo::ABMON_1(),
                                        I18N::Langinfo::ABMON_2(),
                                        I18N::Langinfo::ABMON_3(),
                                        I18N::Langinfo::ABMON_4(),
                                        I18N::Langinfo::ABMON_5(),
                                        I18N::Langinfo::ABMON_6(),
                                        I18N::Langinfo::ABMON_7(),
                                        I18N::Langinfo::ABMON_8(),
                                        I18N::Langinfo::ABMON_9(),
                                        I18N::Langinfo::ABMON_10(),
                                        I18N::Langinfo::ABMON_11(),
                                        I18N::Langinfo::ABMON_12(),
                                       );
        @Day_Name  = map langinfo($_), (
                                        I18N::Langinfo::DAY_1(),
                                        I18N::Langinfo::DAY_2(),
                                        I18N::Langinfo::DAY_3(),
                                        I18N::Langinfo::DAY_4(),
                                        I18N::Langinfo::DAY_5(),
                                        I18N::Langinfo::DAY_6(),
                                        I18N::Langinfo::DAY_7(),
                                       );
        @Day_Abbr  = map langinfo($_), (
                                        I18N::Langinfo::ABDAY_1(),
                                        I18N::Langinfo::ABDAY_2(),
                                        I18N::Langinfo::ABDAY_3(),
                                        I18N::Langinfo::ABDAY_4(),
                                        I18N::Langinfo::ABDAY_5(),
                                        I18N::Langinfo::ABDAY_6(),
                                        I18N::Langinfo::ABDAY_7(),
                                       );
        # make the month arrays 1-based:
        for (\@Mon_Name, \@Mon_Abbr)
        {
            unshift @$_, 'n/a';
        }
    };
    if ($@)    # Internationalization didn't work for some reason; go with English.
    {
        @Mon_Name = qw(n/a January February March April May June July August September October November December);
        @Mon_Abbr = map substr($_,0,3), @Mon_Name;
        @Day_Name = qw(Sunday Monday Tuesday Wednesday Thursday Friday Saturday);
        @Day_Abbr = map substr($_,0,3), @Day_Abbr;
    }

    %number_of = ();
    for (1..12)
    {
        $number_of{uc $Mon_Name[$_]} = $number_of{uc $Mon_Abbr[$_]} = $_;
    }
    # This module doesn't use reverse DOW lookups, but someone might want it.
    for (0..6)
    {
        $number_of{uc $Day_Name[$_]} = $number_of{uc $Day_Abbr[$_]} = $_;
    }
};

my %ap_from_ampm = (a => 'a', am => 'a', 'a.m.' => 'a', p => 'p', pm => 'p', 'p.m.' => 'p');
sub normalize_hms
{
    croak "Too few arguments to normalize_hms"  if @_ < 2;
    croak "Too many arguments to normalize_hms" if @_ > 4;
    my ($inh, $inm, $ins, $ampm) = @_;
    my ($hour24, $hour12, $minute, $second);
    my $ap;

    # First, normalize am/pm indicator
    if (defined $ampm  &&  length $ampm)
    {
        $ap = $ap_from_ampm{lc $ampm};
        _bad ('am/pm indicator', $ampm)  if !defined $ap;
    }

    # Check that the hour is in bounds
    _bad('hour', $inh) if $inh !~ /^\d+$/;
    if (defined $ap)
    {
        # Range is from 1 to 12
        _bad('hour', $inh)  if $inh < 1  ||  $inh > 12;
        $hour12 = 0 + $inh;
        $hour24 = $hour12 == 12?  0 : $hour12;
        $hour24 += 12 if $ap eq 'p';
    }
    else
    {
        # Range is from 0 to 23
        _bad('hour', $inh)  if $inh < 0  ||  $inh > 23;
        $hour24 = $inh;
        $hour12 = $hour24 > 12?  $hour24 - 12 : $hour24 == 0? 12 : $hour24;
        $ap = $hour24 < 12? 'a' : 'p';
    }
    $hour24 = _lead0($hour24);

    # Minute check:  Numeric, range 0 to 59.
    _bad('minute', $inm)  if $inm !~ /^\d+$/ ||  $inm < 0  ||  $inm > 59;
    $minute = _lead0($inm);

    # Second check: Numeric, range 0 to 59.
    if (defined $ins  &&  length $ins)    # second is optional!
    {
        _bad('second', $ins)  if $ins !~ /^\d+$/  ||  $ins < 0  ||  $ins > 59;
        $second = $ins;
    }
    else
    {
        $second = 0;
    }
    $second = _lead0($second);

    my $sec_since_midnight = $second + 60 * ($minute + 60 * $hour24);
    return wantarray? ($hour24, $minute, $second, $hour12, $ap, $sec_since_midnight)
        : {
            h12  => $hour12,
            h24  => $hour24,
            hour => $hour24,
            min  => $minute,
            sec  => $second,
            ampm => $ap,
            since_midnight => $sec_since_midnight,
        };
}

sub normalize_ymd
{
    croak "Too few arguments to normalize_ymd"  if @_ < 3;
    croak "Too many arguments to normalize_ymd" if @_ > 3;
    my ($iny, $inm, $ind) = @_;
    my ($year, $month, $day);

    _setup_locale();

    # First, check year.
    if ($iny =~ /^\d{4}$/)
    {
        # Four-digit year.  Good.
        $year = $iny;
    }
    elsif ($iny =~ /^\d{2}$/)
    {
        # Two-digit year.  Guess the century.

        # If curr yy is <= 50, current century numbers are 0 - yy+50
        if ($current_yy <= 50)
        {
            $year = $iny + 100 * ($iny <= $current_yy+50?  $current_century : $current_century-1);
        }
        # If curr yy is > 50, current century numbers are yy-50 - 99
        else
        {
            $year = $iny + 100 * ($iny <= $current_yy-50?  $current_century+1 : $current_century);
        }
    }
    else
    {
        _bad('year', $iny);
    }
    $year = sprintf '%04d', $year;

    # Decode the month.
    if ($inm =~ /^\d+$/)
    {
        # Numeric.  Simple 1-12 check.
        _bad('month', $inm)  if $inm < 1  ||  $inm > 12;
        $month = $inm;   # Add 0 to ensure numeric with no leading 0.
    }
    else
    {
        # Might be a character month name
        $month = $number_of{uc $inm};
        _bad('month', $inm)  if !defined $month;
    }
    $month = _lead0($month);

    # Day: Numeric and within range for the given month/year
    _bad('day', $ind)
        if $ind !~ /^\d+$/  ||  $ind < 1  ||  $ind > _days_in($year, $month);
    $day = _lead0($ind);

    my $dow = _dow($year, $month, $day);

    return ($year, $month, $day,
            $dow, $Day_Name[$dow], $Day_Abbr[$dow],
            $Mon_Name[$month], $Mon_Abbr[$month])
        if wantarray;

    return
        { year => $year, mon => $month, day => $day,
          dow  => $dow,
          dow_name => $Day_Name[$dow],
          dow_abbr => $Day_Abbr[$dow],
          mon_name => $Mon_Name[$month],
          mon_abbr => $Mon_Abbr[$month],
        };
}

sub normalize_time
{
    croak "Too many arguments to normalize_time" if @_ > 1;
    _bad ('time', $_[0])  if @_ == 1  &&  $_[0] !~ /^\d+$/;
    my @t = @_?  localtime($_[0]) : localtime;
    return _normalize_gm_and_local_times(@t);
}

sub normalize_gmtime
{
    croak "Too many arguments to normalize_gmtime" if @_ > 1;
    _bad ('time', $_[0])  if @_ == 1  &&  $_[0] !~ /^\d+$/;
    my @t = @_?  gmtime($_[0]) : gmtime;
    return _normalize_gm_and_local_times(@t);
}

sub _normalize_gm_and_local_times
{
    my @t = @_;

    _setup_locale();

    if (wantarray)
    {
        my ($h24, $min, $sec, $h12, $ap, $ssm) = normalize_hms ($t[2], $t[1], $t[0]);
        my ($y4, $mon, $day, $dow, $dow_name, $dow_abbr, $mon_name, $mon_abbr)
            = normalize_ymd ($t[5] + 1900, $t[4] + 1, $t[3]);

        return ($sec, $min, $h24,
                $day, $mon, $y4,
                $dow, $t[7], $t[8],
                $h12, $ap, $ssm,
                $dow_name, $dow_abbr,
                $mon_name, $mon_abbr);
    }

    # Scalar.  Return hashref.
    my $hms_href = normalize_hms ($t[2], $t[1], $t[0]);
    my $ymd_href = normalize_ymd ($t[5] + 1900, $t[4] + 1, $t[3]);
    return { %$hms_href, %$ymd_href, yday => $t[7], isdst => $t[8] };
}

1;
__END__

=head1 SYNOPSIS

 use Time::Normalize;

 $hashref = normalize_ymd ($in_yr, $in_mo, $in_d);
 ($year, $mon, $day,
  $dow, $dow_name, $dow_abbr,
  $mon_name, $mon_abbr) = normalize_ymd ($in_yr, $in_mo, $in_dy);

 $hashref = normalize_hms ($in_h, $in_m, $in_s, $in_ampm);
 ($hour, $min, $sec,
  $h12, $ampm, $since_midnight)
          = normalize_hms ($in_h, $in_m, $in_s, $in_ampm);

 $hashref = normalize_time ($time_epoch);
 ($sec, $min, $hour,
  $day, $mon, $year,
  $dow, $yday, $isdst,
  $h12, $ampm, $since_midnight,
  $dow_name, $dow_abbr,
  $mon_name, $mon_abbr) = normalize_time ($time_epoch);

 $hashref = normalize_gmtime ($time_epoch);
 @same_values_as_for_normalize_time = normalize_gmtime ($time_epoch);

=head1 DESCRIPTION

Splitting a date into its component pieces is just the beginning.

Human date conventions are quirky (and I'm not just talking about the
dates I<I've> had!)  Despite the Y2K near-disaster, some people
continue to use two-digit year numbers.  Months are sometimes
specified as a number from 1-12, sometimes as a spelled-out name,
sometimes as a abbreviation.  Some months have more days than others.
Humans sometimes use a 12-hour clock, and sometimes a 24-hour clock.

This module performs simple but tedious (and error-prone) checks on
its inputs, and returns the time and/or date components in a
sanitized, standardized manner, suitable for use in the remainder of
your program.

Even when you get your values from a time-tested library function,
such as C<localtime> or C<gmtime>, you need to do routine
transformations on the returned values.  The year returned is off by
1900 (for historical reasons); the month is in the range 0-11; you may
want the month name or day of week name instead of numbers.  The
L</normalize_time> function decodes C<localtime>'s values into
commonly-needed formats.

=head1 FUNCTIONS

=over

=item normalize_ymd

 $hashref = normalize_ymd ($in_yr, $in_mo, $in_d);

 ($year, $mon, $day,
  $dow, $dow_name, $dow_abbr,
  $mon_name, $mon_abbr) = normalize_ymd ($in_yr, $in_mo, $in_dy);

Takes an arbitrary year, month, and day as input, and returns various
data elements in a standard, consistent format.  The output may be a
hash reference or a list of values.  If a hash reference is desired,
the keys of that hash will be the same as the variable names given in
the above synopsis; that is, C<day>, C<dow>, C<dow_abbr>, C<dow_name>,
C<mon>, C<mon_abbr>, C<mon_name>, and C<year>.

I<Input:>

The input year may be either two digits or four digits.  If two
digits, the century is chosen so that the resulting four-digit year is
closest to the current calendar year (i.e., within 50 years).

The input month may either be a number from 1 to 12, or a full month
name as defined by the current locale, or a month abbreviation as
defined by the current locale.  If it's a name or abbreviation, case
is not significant.

The input day must be a number from 1 to the number of days in the
specified month and year.

If any of the input values do not meet the above criteria, an
exception will be thrown. See L</DIAGNOSTICS>.

I<Output:>

C<  year      >will always be four digits.

C<  month     >will always be two digits, 01-12.

C<  day       >will always be two digits 01-31.

C<  dow       >will be a number from 0 (Sunday) to 6 (Saturday).

C<  dow_name  >will be the name of the day of the week, as defined
by the current locale, in the locale's preferred case.

C<  dow_abbr  >will be the standard weekday name abbreviation, as
defined by the current locale, in the locale's preferred case.

C<  mon_name  >will be the month name, as defined by the current
locale, in the locale's preferred case.

C<  mon_abbr  >will be the standard month name abbreviation, as
defined by the current locale, in the locale's preferred case.

=item normalize_hms

 $hashref = normalize_hms ($in_h, $in_m, $in_s, $in_ampm);

 ($hour, $min, $sec,
  $h12, $ampm, $since_midnight)
          = normalize_hms ($in_h, $in_m, $in_s, $in_ampm);

Like L</normalize_ymd>, C<normalize_hms> takes a variety of possible
inputs and returns standardized values.  As above, the output may be a
hash reference or a list of values.  If a hash reference is desired,
the keys of that hash will be the same as the variable names given in
the above synopsis; that is, C<ampm>, C<h12>, C<hour>, C<min>, C<sec>,
and C<since_midnight>.  Also, a C<h24> key is provided as a synonym
for C<hour>.

I<Input:>

The input hour may either be a 12-hour or a 24-hour time value.  If
C<$in_ampm> is specified, C<$in_h> is assumed to be on a 12-hour
clock, and if C<$in_ampm> is absent, C<$in_h> is assumed to be on a
24-hour clock.

The input minute must be numeric, and must be in the range 0 to 59.

The input second C<$in_s> is optional.  If omitted, it defaults to 0.
If specified, it must be in the range 0 to 59.

The AM/PM indicator C<$in_ampm> is optional.  If specified, it may be
any of the following:

   a   am   a.m.  p   pm   p.m.  A   AM   A.M.  P   PM   P.M.

If any of the input values do not meet the above criteria, an
exception will be thrown. See L</DIAGNOSTICS>.

I<Output:>

C<  hour      >The first output hour will always be on a 24-hour
clock, and will always be two digits, 00-23.

C<  min       >will always be two digits, 00-59.

C<  sec       >will always be two digits, 00-59.

C<  h12       >is the 12-hour clock equivalent of C<$hour>.  It is
I<not> zero-padded.

C<  ampm      >will always be either a lowercase 'a' or a lowercase 'p',
no matter what format the input AM/PM indicator was, or even if it was
omitted.

C<  since_midnight  >is the number of seconds since midnight
represented by this time.

C<  h24       >is a key created if you request a hashref as the
output; it's a synonym for C<hour>.

=item normalize_time

 $hashref = normalize_time($time_epoch);

 ($sec, $min, $hour,
  $day, $mon, $year,
  $dow, $yday, $isdst,
  $h12, $ampm, $since_midnight,
  $dow_name, $dow_abbr,
  $mon_name, $mon_abbr) = normalize_time($time_epoch);

Takes a number in the usual perl epoch, passes it to
L<localtime|perlfunc/localtime>, and transforms the results.  If
C<$time_epoch> is omitted, the current time is used instead.

The output values (or hash values) are exactly as for
L</normalize_ymd> and L</normalize_hms>, above.

=item normalize_gmtime

Exactly the same as L<normalize_time>, but uses L<gmtime|perlfunc/gmtime>
internally instead of L<localtime|perlfunc/localtime>.

=back

=head1 DIAGNOSTICS

The functions in this module throw exceptions (that is, they C<croak>)
whenever invalid arguments are passed to them.  Therefore, it is
generally a Good Idea to trap these exceptions with an C<eval> block.

The error messages are meant to be easy to parse, if you need to.
There are two kinds of errors thrown: data errors, and programming
errors.

Data errors are caused by invalid data values; that is, values that do
not conform to the expectations listed above.  These messages all look
like:

C<   Time::Normalize: Invalid >I<thing>C<: ">I<value>C<">

Programming errors are caused by you--passing the wrong number of
parameters to a function.  These messages all look like:

C<   Too >I<{many|few}>C< arguments to >I<function_name>

=head1 EXAMPLES

 $h = normalize_ymd (2005, 'january', 4);
 #
 # Returns:
 #         $h{day}        "04"
 #         $h{dow}        2
 #         $h{dow_abbr}   "Tue"
 #         $h{dow_name}   "Tuesday"
 #         $h{mon}        "01"
 #         $h{mon_abbr}   "Jan"
 #         $h{mon_name}   "January"
 #         $h{year}       2005
 # ------------------------------------------------

 $h = normalize_ymd ('05', 12, 31);
 #
 # Returns:
 #         $h{day}        31
 #         $h{dow}        6
 #         $h{dow_abbr}   "Sat"
 #         $h{dow_name}   "Saturday"
 #         $h{mon}        12
 #         $h{mon_abbr}   "Dec"
 #         $h{mon_name}   "December"
 #         $h{year}       2005
 # ------------------------------------------------

 $h = normalize_ymd (2005, 2, 29);
 #
 # Throws an exception:
 #         Time::Normalize: Invalid day: "29"
 # ------------------------------------------------

 $h = normalize_hms (9, 10, 0, 'AM');
 #
 # Returns:
 #         $h{ampm}       "a"
 #         $h{h12}        9
 #         $h{h24}        "09"
 #         $h{hour}       "09"
 #         $h{min}        10
 #         $h{sec}        "00"
 #         $h{since_midnight}    33000
 # ------------------------------------------------

 $h = normalize_hms (9, 10, undef, 'p.m.');
 #
 # Returns:
 #         $h{ampm}       "p"
 #         $h{h12}        9
 #         $h{h24}        21
 #         $h{hour}       21
 #         $h{min}        10
 #         $h{sec}        "00"
 #         $h{since_midnight}    76200
 # ------------------------------------------------

 $h = normalize_hms (1, 10);
 #
 # Returns:
 #         $h{ampm}       "a"
 #         $h{h12}        1
 #         $h{h24}        "01"
 #         $h{hour}       "01"
 #         $h{min}        10
 #         $h{sec}        "00"
 #         $h{since_midnight}    4200
 # ------------------------------------------------

 $h = normalize_hms (13, 10);
 #
 # Returns:
 #         $h{ampm}       "p"
 #         $h{h12}        1
 #         $h{h24}        13
 #         $h{hour}       13
 #         $h{min}        10
 #         $h{sec}        "00"
 #         $h{since_midnight}    47400
 # ------------------------------------------------

 $h = normalize_hms (13, 10, undef, 'pm');
 #
 # Throws an exception:
 #         Time::Normalize: Invalid hour: "13"
 # ------------------------------------------------

 $h = normalize_gmtime(1131725587);
 #
 # Returns:
 #         $h{ampm}       "p"
 #         $h{sec}        "07",
 #         $h{min}        13,
 #         $h{hour}       16,
 #         $h{day}        11,
 #         $h{mon}        11,
 #         $h{year}       2005,
 #         $h{dow}        5,
 #         $h{yday}       314,
 #         $h{isdst}      0,
 #         $h{h12}        4
 #         $h{ampm}       "p"
 #         $h{since_midnight}        58_387,
 #         $h{dow_name}   "Friday",
 #         $h{dow_abbr}   "Fri",
 #         $h{mon_name}   "November",
 #         $h{mon_abbr}   "Nov",
 # ------------------------------------------------


=head1 EXPORTS

This module exports the following symbols into the caller's namespace:

 normalize_ymd
 normalize_hms
 normalize_time
 normalize_gmtime

=head1 REQUIREMENTS

This module requires L<POSIX>.

If L<I18N::Langinfo> is available, this module will use it; otherwise,
it will use hardcoded English values for month and weekday names.

L<Test::More> is required for the test suite.

=head1 SEE ALSO

See L<Regexp::Common::time> for a L<Regexp::Common> plugin that
matches nearly any date format imaginable.

=head1 BUGS

=over

=item *

Uses Gregorian rules for computing whether a year is a leap year, no
matter how long ago the year was.

=back

=head1 NOT A BUG

=over

=item *

By convention, noon is 12:00 pm; midnight is 12:00 am.

=back

=head1 AUTHOR / COPYRIGHT

Eric J. Roode, roode@cpan.org

Copyright (c) 2005 by Eric J. Roode.  All Rights Reserved.
This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

To avoid my spam filter, please include "Perl", "module", or this
module's name in the message's subject line, and/or GPG-sign your
message.

=cut

=begin gpg

-----BEGIN PGP SIGNATURE-----
Version: GnuPG v1.4.1 (Cygwin)

iD8DBQFDkFpMY96i4h5M0egRAlFCAKDbK+szjqQ4voZbpWRA9QXjtUCrlwCcCtmo
bG9uk5Vtp1bjbb9VEGCGUvM=
=ZvsR
-----END PGP SIGNATURE-----

=end gpg
