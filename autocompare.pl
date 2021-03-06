use strict;
use warnings;
require LWP::UserAgent;
use Net::SMTP;

open (LOG,">res.log") or die "can't create log";

my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;

my $root_url = 'http://qa.revo.gist.symantec.com/';
my $response = $ua->get($root_url);
die $response->status_line unless ($response->is_success);
my @content = split (/build:/,$response->decoded_content);
my $first_id = $1 if($content[1] =~ /^([0-9]+)/ );
my $build_fid = $1 if($content[1] =~ /<!--<td class="build">(.*?)<\/td>-->/ );
my $second_id = $1 if($content[2] =~ /^([0-9]+)/ );
my $build_sid = $1 if($content[2] =~ /<!--<td class="build">(.*?)<\/td>-->/ );

my $url_new = "http://qa.revo.gist.symantec.com/coverage/$first_id/stf/perl/";
my $url_old = "http://qa.revo.gist.symantec.com/coverage/$second_id/stf/perl/";

#my ($url_new,$url_old) = @ARGV;

printf LOG ("Comparing\n------------ %s build_number: %s ------------\n with \n------------ %s build_number: %s ------------\n",$url_new,$build_fid,$url_old,$build_sid);

$response = $ua->get($url_new);
die $response->status_line unless ($response->is_success);
my @contents_new = split (/<\/tr>/,$response->decoded_content);

$response = $ua->get($url_old);
die $response->status_line unless ($response->is_success);
my @contents_old = split (/<\/tr>/,$response->decoded_content);



my $eachline = undef;
my %hash_new ;
foreach $eachline (@contents_new) {
     chomp $eachline;
         
   next unless ($eachline =~ /<tr><td align="left">/);
	 
	 if($eachline =~ /html">(.*?)<  
					 .*? ">\s?([0-9]+\.[0-9])<\/td> 
					 .*? >\s?([0-9]+\.[0-9]|n\/a)+< 
					 .*? >\s?([0-9]+\.[0-9]|n\/a)+<
					 .*? >\s?([0-9]+\.[0-9]|n\/a)+<
					 .*? >\s?([0-9]+\.[0-9]|n\/a)+<	
					 .*? ">(.*?)<\/td> /x)
	 {
		$hash_new{"$1"} ={
			"stmt" => $2,
			"bran" => $3,
			"cond" => $4,
			"sub"  => $5,
			"total"=> $7,
			"mark" => 0,
		};
	 }
}

my $eachline1 = undef;
my %hash_old ;
foreach $eachline1 (@contents_old) {
     chomp $eachline1;
         
	 next unless ($eachline1 =~ /<tr><td align="left">/);
	 
	 if($eachline1 =~ /html">(.*?)< 
					 .*? ">\s?([0-9]+\.[0-9])<\/td> 
					 .*? >\s?([0-9]+\.[0-9]|n\/a)+< 
					 .*? >\s?([0-9]+\.[0-9]|n\/a)+<
					 .*? >\s?([0-9]+\.[0-9]|n\/a)+<
					 .*? >\s?([0-9]+\.[0-9]|n\/a)+<	
					 .*? ">(.*?)<\/td> /x)
	 {
		$hash_old{"$1"} ={
			"stmt" => $2,
			"bran" => $3,
			"cond" => $4,
			"sub"  => $5,
			"total"=> $7,
			"mark" => 0,
		};
	 }
}

my @keys_new = keys %hash_new;
my @keys_old = keys %hash_old;
my $sub_change;
my $stmt_change;
my $total_change;

printf LOG ("%-145s\t %-4s\t%-4s\t%-5s\n","filename","stmt","sub","total");
foreach my $key_new (@keys_new)
{ 
	if($hash_old{$key_new}){
		if ($hash_new{$key_new}{sub} ==$hash_old{$key_new}{sub}&&$hash_new{$key_new}{stmt} ==$hash_old{$key_new}{stmt}&&$hash_new{$key_new}{total} ==$hash_old{$key_new}{total})
		{
			$hash_new{$key_new}{mark} = 1;
			$hash_old{$key_new}{mark} = 1;
		}
		else 
		{
			$sub_change = $hash_new{$key_new}{sub} - $hash_old{$key_new}{sub};
			$stmt_change = $hash_new{$key_new}{stmt} - $hash_old{$key_new}{stmt};
			$total_change = $hash_new{$key_new}{total} - $hash_old{$key_new}{total};
			$hash_new{$key_new}{mark} = 1;
			$hash_old{$key_new}{mark} = 1;
			printf LOG ("%-145s\t:%-3.1f\t%-3.1f\t%-3.1f\n",$key_new,$stmt_change,$sub_change,$total_change);
		}	
	}
	else
	{
		$sub_change = $hash_new{$key_new}{sub};
		$stmt_change = $hash_new{$key_new}{stmt};
		$total_change = $hash_new{$key_new}{total};
		printf LOG ("%-145s\t:%-3.1f\t%-3.1f\t%-3.1f\n",$key_new,$stmt_change,$sub_change,$total_change);
		$hash_new{$key_new}{mark} = 1;
	}

};
my $pmark = 0;

#printf LOG ("----------------  The name of modules which are disappeared  ----------------\n");

foreach my $key_old (@keys_old)
{
	next if ($hash_old{$key_old}{mark});
	$sub_change = - $hash_old{$key_old}{sub};
	$stmt_change = - $hash_old{$key_old}{stmt};
	$total_change = - $hash_old{$key_old}{total};
	if($pmark == 0)
	{
		printf LOG ("----------------  The name of modules which are disappeared  ----------------\n");
		$pmark = 1;
	}
	printf LOG ("%-145s\t:%-3.1f\t%-3.1f\t%-3.1f\n",$key_old,$stmt_change,$sub_change,$total_change);
	$hash_old{$key_old}{mark} = 1;
}
close(LOG);

open(LOGS,"<res.log") or die "can't open log";

my @logs = <LOGS>;
my $result_content;
foreach my $log (@logs)
{
	$result_content .=$log;
}
close(LOGS);
#print $result_content."***\n";

my $email_server = '';
my $email_receivers = '';
my $email_sender = '';

my $smtp = Net::SMTP->new($email_server);
$smtp->mail($email_sender);
my @receivers = split (";",$email_receivers);

$smtp->recipient(@receivers);
$smtp->data();
$smtp->datasend("To: $email_receivers\n");
$smtp->datasend("Subject: STF Change\n");
$smtp->datasend("$result_content\n");
$smtp->quit;









