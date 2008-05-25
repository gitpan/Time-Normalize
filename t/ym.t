use Test::More tests => 68;

sub begins_with
{
    my ($got, $exp) = @_;
    my $ok = substr($got,0,length $exp) eq $exp;
    if (!$ok)
    {
        diag "expected '$exp...'\n",
             "     got '$got'\n";
    }
    return $ok;
}

use_ok ('Time::Normalize');

# YM export okay?
ok (defined &normalize_ym, 'normalize_ym sub imported');


# Figure out the month and day names in this locale
my ($JANUARY, $FEBRUARY, $MARCH, $APRIL, $MAY_FULL, $JUNE, $JULY, $AUGUST, $SEPTEMBER, $OCTOBER, $NOVEMBER, $DECEMBER);
my ($JAN, $FEB, $MAR, $APR, $MAY, $JUN, $JUL, $AUG, $SEP, $OCT, $NOV, $DEC);
my ($SUNDAY, $MONDAY, $TUESDAY, $WEDNESDAY, $THURSDAY, $FRIDAY, $SATURDAY);
my ($SUN, $MON, $TUE, $WED, $THU, $FRI, $SAT);
eval
{
    require I18N::Langinfo;
    I18N::Langinfo->import qw(langinfo);
    ($JANUARY, $FEBRUARY, $MARCH, $APRIL, $MAY_FULL, $JUNE, $JULY, $AUGUST, $SEPTEMBER, $OCTOBER, $NOVEMBER, $DECEMBER)
        = map langinfo($_), I18N::Langinfo::MON_1(), I18N::Langinfo::MON_2(), I18N::Langinfo::MON_3(), I18N::Langinfo::MON_4(), I18N::Langinfo::MON_5(), I18N::Langinfo::MON_6(), I18N::Langinfo::MON_7(), I18N::Langinfo::MON_8(), I18N::Langinfo::MON_9(), I18N::Langinfo::MON_10(), I18N::Langinfo::MON_11(), I18N::Langinfo::MON_12();
    ($JAN, $FEB, $MAR, $APR, $MAY, $JUN, $JUL, $AUG, $SEP, $OCT, $NOV, $DEC)
        = map langinfo($_), I18N::Langinfo::ABMON_1(), I18N::Langinfo::ABMON_2(), I18N::Langinfo::ABMON_3(), I18N::Langinfo::ABMON_4(), I18N::Langinfo::ABMON_5(), I18N::Langinfo::ABMON_6(), I18N::Langinfo::ABMON_7(), I18N::Langinfo::ABMON_8(), I18N::Langinfo::ABMON_9(), I18N::Langinfo::ABMON_10(), I18N::Langinfo::ABMON_11(), I18N::Langinfo::ABMON_12();
    ($SUNDAY, $MONDAY, $TUESDAY, $WEDNESDAY, $THURSDAY, $FRIDAY, $SATURDAY)
        = map langinfo($_), I18N::Langinfo::DAY_1(), I18N::Langinfo::DAY_2(), I18N::Langinfo::DAY_3(), I18N::Langinfo::DAY_4(), I18N::Langinfo::DAY_5(), I18N::Langinfo::DAY_6(), I18N::Langinfo::DAY_7();
    ($SUN, $MON, $TUE, $WED, $THU, $FRI, $SAT)
        = map langinfo($_), I18N::Langinfo::ABDAY_1(), I18N::Langinfo::ABDAY_2(), I18N::Langinfo::ABDAY_3(), I18N::Langinfo::ABDAY_4(), I18N::Langinfo::ABDAY_5(), I18N::Langinfo::ABDAY_6(), I18N::Langinfo::ABDAY_7();
};
if ($@)
{
    ($JANUARY, $FEBRUARY, $MARCH, $APRIL, $MAY_FULL, $JUNE, $JULY, $AUGUST, $SEPTEMBER, $OCTOBER, $NOVEMBER, $DECEMBER)
        = qw(January February March April May June July August September October November December);
    ($JAN, $FEB, $MAR, $APR, $MAY, $JUN, $JUL, $AUG, $SEP, $OCT, $NOV, $DEC)
        = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    ($SUNDAY, $MONDAY, $TUESDAY, $WEDNESDAY, $THURSDAY, $FRIDAY, $SATURDAY)
        = qw(Sunday Monday Tuesday Wednesday Thursday Friday Saturday);
    ($SUN, $MON, $TUE, $WED, $THU, $FRI, $SAT)
        = qw(Sun Mon Tue Wed Thu Fri Sat);
}


my ($year, $mon, $day, $dow, $dname, $dab, $mname, $mab, $hash);
my $nov30_2005 = [2005, 11, 30, 3, $WEDNESDAY, $WED, $NOVEMBER, $NOV];


# Simple basic case
eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2005, 11) };
is ($@,    '', q{basic test: no error});
is_deeply ([$year, $mon, $day, $dow, $dname, $dab, $mname, $mab],
           $nov30_2005, 'basic test');

# Too many args
eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2005, 11, 8) };
ok (begins_with ($@, 'Too many arguments to normalize_ym'), q{too many ym args});

# Too few args
eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2005) };
ok (begins_with ($@, 'Too few arguments to normalize_ym'), q{too few ym args});

# Hash output
eval {$hash = normalize_ym(2005, 11) };
is ($@,    '', q{basic hash: no error});
is_deeply ([@$hash{qw(year mon day dow dow_name dow_abbr mon_name mon_abbr)}],
           $nov30_2005, 'basic hash');

# Year tests
my ($cur_cc, $cur_yy) = ((localtime)[5]+1900) =~ /^(\d\d)(\d\d)$/;
my @cases;
if ($cur_yy <= 50)   # e.g. 2005
{
    my $prv_cc = sprintf '%02d', $cur_cc - 1;
    my $c75 = $cur_yy > 25? $cur_cc : $prv_cc;
    @cases = (
              ['00' => "${cur_cc}00"],
              ['25' => "${cur_cc}25"],
              ['50' => "${cur_cc}50"],
              ['75' => "${c75}75"],
              ['99' => "${prv_cc}99"],
              [$cur_yy => "$cur_cc$cur_yy"]
             );

}
else   # As if this module will be around in 2050.. :-P
{
    my $nxt_cc = sprintf '%02d', $cur_cc + 1;
    my $c25 = $cur_yy < 75? $cur_cc : $nxt_cc;
    @cases = (
              ['00' => "${nxt_cc}00"],
              ['25' => "${c25}25"],
              ['50' => "${cur_cc}50"],
              ['75' => "${cur_cc}75"],
              ['99' => "${cur_cc}99"],
              [$cur_yy => "$cur_cc$cur_yy"]
             );

}

for my $case (@cases)
{
    ($year, $mon, $day) = ();
    my ($y2, $y4) = @$case;
    eval {($year, $mon, $day) = normalize_ym($y2, 11) };
    is ($@,    '', qq{y2 test: no error});
    is_deeply ([$year, $mon, $day],
               [$y4, 11, 30], 'y2 test: values');
}

eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(5, 11) };
ok (begins_with ($@, 'Time::Normalize: Invalid year: "5"'), q{bad year (1 digit)});

eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(205, 11) };
ok (begins_with ($@, 'Time::Normalize: Invalid year: "205"'), q{bad year (3 digits)});

eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(20005, 11) };
ok (begins_with ($@, 'Time::Normalize: Invalid year: "20005"'), q{bad year (5 digits)});


# Month tests
($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = ();
eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2005, $NOVEMBER) };
is ($@,    '', q{Month name: no error});
is_deeply ([$year, $mon, $day, $dow, $dname, $dab, $mname, $mab],
           $nov30_2005, 'Month name values');

($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = ();
eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2005, $NOV) };
is ($@,    '', q{Month abbr: no error});
is_deeply ([$year, $mon, $day, $dow, $dname, $dab, $mname, $mab],
           $nov30_2005, 'Month abbr values');

($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = ();
eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2005, lc $NOVEMBER) };
is ($@,    '', q{lc Month name: no error});
is_deeply ([$year, $mon, $day, $dow, $dname, $dab, $mname, $mab],
           $nov30_2005, 'lc Month name values');

($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = ();
eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2005, lc $NOV) };
is ($@,    '', q{lc Month abbr: no error});
is_deeply ([$year, $mon, $day, $dow, $dname, $dab, $mname, $mab],
           $nov30_2005, 'lc Month abbr values');

($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = ();
eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2005, uc $NOVEMBER) };
is ($@,    '', q{uc Month name: no error});
is_deeply ([$year, $mon, $day, $dow, $dname, $dab, $mname, $mab],
           $nov30_2005, 'uc Month name values');

($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = ();
eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2005, uc $NOV) };
is ($@,    '', q{uc Month abbr: no error});
is_deeply ([$year, $mon, $day, $dow, $dname, $dab, $mname, $mab],
           $nov30_2005, 'uc Month abbr values');

# Test each of the  twelve months at least once
($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = ();
eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2005, 1) };
is ($@,    '', q{Month 1: no error});
is_deeply ([$year, $mon, $day, $dow, $dname, $dab, $mname, $mab],
           [2005, '01', 31, 1, $MONDAY, $MON, $JANUARY, $JAN], 'Month 1 values');

($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = ();
eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2005, 2) };
is ($@,    '', q{Month 2: no error});
is_deeply ([$year, $mon, $day, $dow, $dname, $dab, $mname, $mab],
           [2005, '02', 28, 1, $MONDAY, $MON, $FEBRUARY, $FEB], 'Month 2 values');

($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = ();
eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2024, 2) };
is ($@,    '', q{Month 2 leap: no error});
is_deeply ([$year, $mon, $day, $dow, $dname, $dab, $mname, $mab],
           [2024, '02', 29, 4, $THURSDAY, $THU, $FEBRUARY, $FEB], 'Month 2 leap values');

($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = ();
eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2000, 2) };
is ($@,    '', q{Month 2 y2k: no error});
is_deeply ([$year, $mon, $day, $dow, $dname, $dab, $mname, $mab],
           [2000, '02', 29, 2, $TUESDAY, $TUE, $FEBRUARY, $FEB], 'Month 2 y2k values');

($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = ();
eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2005, 3) };
is ($@,    '', q{Month 3: no error});
is_deeply ([$year, $mon, $day, $dow, $dname, $dab, $mname, $mab],
           [2005, '03', 31, 4, $THURSDAY, $THU, $MARCH, $MAR], 'Month 3 values');

($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = ();
eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2005, 4) };
is ($@,    '', q{Month 4: no error});
is_deeply ([$year, $mon, $day, $dow, $dname, $dab, $mname, $mab],
           [2005, '04', 30, 6, $SATURDAY, $SAT, $APRIL, $APR], 'Month 4 values');

($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = ();
eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2005, 5) };
is ($@,    '', q{Month 5: no error});
is_deeply ([$year, $mon, $day, $dow, $dname, $dab, $mname, $mab],
           [2005, '05', 31, 2, $TUESDAY, $TUE, $MAY_FULL, $MAY], 'Month 5 values');

($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = ();
eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2005, 6) };
is ($@,    '', q{Month 6: no error});
is_deeply ([$year, $mon, $day, $dow, $dname, $dab, $mname, $mab],
           [2005, '06', 30, 4, $THURSDAY, $THU, $JUNE, $JUN], 'Month 6 values');

($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = ();
eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2005, 7) };
is ($@,    '', q{Month 7: no error});
is_deeply ([$year, $mon, $day, $dow, $dname, $dab, $mname, $mab],
           [2005, '07', 31, 0, $SUNDAY, $SUN, $JULY, $JUL], 'Month 7 values');

($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = ();
eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2005, 8) };
is ($@,    '', q{Month 8: no error});
is_deeply ([$year, $mon, $day, $dow, $dname, $dab, $mname, $mab],
           [2005, '08', 31, 3, $WEDNESDAY, $WED, $AUGUST, $AUG], 'Month 8 values');

($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = ();
eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2005, 9) };
is ($@,    '', q{Month 9: no error});
is_deeply ([$year, $mon, $day, $dow, $dname, $dab, $mname, $mab],
           [2005, '09', 30, 5, $FRIDAY, $FRI, $SEPTEMBER, $SEP], 'Month 9 values');

($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = ();
eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2005, 10) };
is ($@,    '', q{Month 10: no error});
is_deeply ([$year, $mon, $day, $dow, $dname, $dab, $mname, $mab],
           [2005, '10', 31, 1, $MONDAY, $MON, $OCTOBER, $OCT], 'Month 10 values');

($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = ();
eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2005, 11) };
is ($@,    '', q{Month 11: no error});
is_deeply ([$year, $mon, $day, $dow, $dname, $dab, $mname, $mab],
           [2005, '11', 30, 3, $WEDNESDAY, $WED, $NOVEMBER, $NOV], 'Month 11 values');

($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = ();
eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2005, 12) };
is ($@,    '', q{Month 12: no error});
is_deeply ([$year, $mon, $day, $dow, $dname, $dab, $mname, $mab],
           [2005, '12', 31, 6, $SATURDAY, $SAT, $DECEMBER, $DEC], 'Month 12 values');

# Bogus months
eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2005, 0) };
ok (begins_with ($@, 'Time::Normalize: Invalid month: "0"'), q{bad month 0});

eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2005, 13) };
ok (begins_with ($@, 'Time::Normalize: Invalid month: "13"'), q{bad month 13});

eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2005, -1) };
ok (begins_with ($@, 'Time::Normalize: Invalid month: "-1"'), q{bad month -1});

eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2005, '') };
ok (begins_with ($@, 'Time::Normalize: Invalid month: ""'), q{bad month ''});

eval {($year, $mon, $day, $dow, $dname, $dab, $mname, $mab) = normalize_ym(2005, 'abc') };
ok (begins_with ($@, 'Time::Normalize: Invalid month: "abc"'), q{bad month abc});
