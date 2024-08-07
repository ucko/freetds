#!/usr/bin/perl

use strict;
open(IN, $ARGV[0]) or die;

my @types = split(',',
'SQLHANDLE,SQLHENV,SQLHDBC,SQLHSTMT,SQLHDESC,SQLHWND,SQLSMALLINT,SQLUSMALLINT,SQLINTEGER,SQLSMALLINT *,SQLLEN *,SQLULEN *,SQLINTEGER *,SQLPOINTER');
my @fmt=split(/,\s*/,
'p,        p,      p,      p,       p,       p,      d,          u,           d,         p,            p,       p,        p,           p');
my %fmt;
@fmt{@types} = @fmt;

print "#undef tdsdump_log\n\n";

while(<IN>) {
	chomp;
	while(/ODBC_FUNC/) {
		my $open = $_;
		$open =~ s/[^(]//g;
		$open = length($open);
		my $close = $_;
		$close =~ s/[^)]//g;
		$close = length($close);
		last if $open <= $close;
		$_ .= <IN>;
		chomp;
	}
	s/\s+/ /g;
	s/ $//;
	s/^ //;
	if (/ODBC_FUNC\(([^\)]+), \((.*)\)$/) {
		my $func = $1;
		my $args = $2;
		my $wide = 0;
		my $params_all = '';
		my $pass_aw = '';
		my $sep = '';
		my $log = "tdsdump_log(TDS_DBG_FUNC, \"$func(";
		my $log_p = '';
		$wide = 1 if $args =~ / WIDE ?$/;
		$args =~ s/ WIDE ?$//;
#		print "$1 - $2\n";
		while ($args =~ /(P.*?)\(([^\,)]+),?([^\,)]+)\)/g) {
			my ($type, $a, $b) = ($1,$2,$3);
#			print "--- $1 -- $2 -- $3\n";
			if ($type eq 'P') {
				$a =~ s/ FAR \*$/ */;
				die $a if !grep { $_ eq $a } @types;
				die if !exists($fmt{$a});
				$params_all .= "$sep$a $b";
				$pass_aw    .= "$sep$b";
				$log   .= "$sep%$fmt{$a}";
				if ($fmt{$a} eq 'u') {
					$log_p .= "$sep(unsigned int) $b";
				} elsif ($fmt{$a} eq 'd') {
					$log_p .= "$sep(int) $b";
				} else {
					$log_p .= "$sep$b";
				}
			} elsif ($type eq 'PCHARIN' || $type eq 'PCHAROUT') {
				die $b if $b ne 'SQLSMALLINT' && $b ne 'SQLINTEGER';
				if ($type eq 'PCHARIN') {
					$params_all .= "${sep}ODBC_CHAR * sz$a, $b cb$a";
					$pass_aw    .= "$sep(ODBC_CHAR*) sz$a, cb$a";
					$log   .= "$sep%ls, %d";
					$log_p .= "${sep}STRING(sz$a,cb$a), (int) cb$a";
				} else {
					$params_all .= "${sep}ODBC_CHAR * sz$a, $b cb${a}Max, $b FAR* pcb$a";
					$pass_aw    .= "${sep}(ODBC_CHAR*) sz$a, cb${a}Max, pcb$a";
					$log   .= "$sep%p, %d, %p";
					$log_p .= "${sep}sz$a, (int) cb${a}Max, pcb$a";
				}
			} elsif ($type eq 'PCHAR') {
				$params_all .= "${sep}ODBC_CHAR * $a";
				$pass_aw    .= "$sep(ODBC_CHAR*) $a";
				$log   .= "$sep%p";
				$log_p .= "$sep$a";
			} else {
				die $type;
			}
			$sep = "\t\t\t";
		}
		$params_all =~ s/\t\t\t/,\n    /g;
		$pass_aw  =~ s/\t\t\t/,\n\t\t/g;
		$log        =~ s/\t\t\t/, /g;
		$log_p      =~ s/\t\t\t/,\n\t\t\t/g;
		$log .= ")\\n\",\n\t\t\t".$log_p.");";

		my $params_a = $params_all;
		$params_a =~ s/ODBC_CHAR \*/SQLCHAR */g;
		my $params_w = $params_all;
		$params_w =~ s/ODBC_CHAR \*/SQLWCHAR */g;
		my $pass_all = $pass_aw;
		$pass_all =~ s/\(ODBC_CHAR\*\) ?//g;

		my $log_w = $log;
		my $n = 0;
		$log_w =~ s/STRING\((.*?),(.*?)\)/sprintf("SQLWSTR($1)",$n++)/ge;
		$log_w =~ s/\"$func/"${func}W/;
		if ($n) {
			$log_w = "if (TDS_UNLIKELY(tds_write_dump)) {
		SQLWSTR_BUFS($n);
		$log_w
		SQLWSTR_FREE();
	}";
		} else {
			$log_w =~ s/\btdsdump_log\b/TDSDUMP_LOG_FAST/g;
		}

		$log =~ s/%ls/%s/g;
		$log =~ s/STRING\((.*?),(.*?)\)/(const char*) $1/g;

		$log =~ s/\btdsdump_log\b/TDSDUMP_LOG_FAST/g;

		print "#ifdef ENABLE_ODBC_WIDE
static SQLRETURN odbc_$func($params_all, int wide);

SQLRETURN ODBC_PUBLIC ODBC_API ${func}W(
    $params_w)
{
	$log_w
	return odbc_$func($pass_aw, 1);
}
#endif

SQLRETURN ODBC_PUBLIC ODBC_API $func(
    $params_a)
{
	$log
#ifdef ENABLE_ODBC_WIDE
	return odbc_$func($pass_aw, 0);
#else
	return odbc_$func($pass_all);
#endif
}

";
	}
}
close(IN);

print "#define tdsdump_log TDSDUMP_LOG_FAST\n";

exit 0;

__END__
static SQLRETURN odbc_SQLPrepare (SQLHSTMT hstmt, ODBC_CHAR* szSqlStr, SQLINTEGER cbSqlStr , int wide);
SQLRETURN __attribute__((externally_visible)) SQLPrepare (SQLHSTMT hstmt, SQLCHAR* szSqlStr, SQLINTEGER cbSqlStr ) {
 return _SQLPrepare (hstmt, (ODBC_CHAR*) szSqlStr, cbSqlStr ,0);
}
SQLRETURN __attribute__((externally_visible)) SQLPrepareW (SQLHSTMT hstmt, SQLWCHAR * szSqlStr, SQLINTEGER cbSqlStr ) {
 return _SQLPrepare (hstmt, (ODBC_CHAR*) szSqlStr, cbSqlStr ,1);
}
static SQLRETURN odbc_SQLPrepare (SQLHSTMT hstmt, ODBC_CHAR* szSqlStr, SQLINTEGER cbSqlStr , int wide)

