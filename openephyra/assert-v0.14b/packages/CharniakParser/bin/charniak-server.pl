#!/bin/perl
$| = 1;

use IO::Socket;
use Net::hostent; 
use FileHandle;
use IPC::Open2;
#use IPC::Open3;

my $parser_exec_dir="$ENV{\"CHARNIAK_PARSER\"}/bin";
my $parser_exec="./parseStdin -l399 $ENV{\"CHARNIAK_PARSER\"}/DATA/";

$TRUE = 1;
$FALSE = 0;
$WEB = $TRUE;

#$pid = open3( \*Writer, \*Reader, \*ERReader, "cd $parser_exec_dir;$parser_exec" );
$pid = open2( \*Reader, \*Writer, "cd $parser_exec_dir; $parser_exec" );
Writer->autoflush();

my $read = '';
vec($read, fileno(Reader), 1) = 1;
#vec($read, fileno(ERReader), 1) = 1;

$PORT = 15000;

$server = IO::Socket::INET->new( Proto => 'tcp', LocalPort => $PORT, Listen => SOMAXCONN, 
Reuse => 1);

die "Can't setup server" unless $server;
print "[Server $0 accepting clients]\n";

while ($client = $server->accept()) 
{
    $client->autoflush(1);
    $hostinfo = gethostbyaddr($client->peeraddr);
    printf "[Connect from %s]\n", $hostinfo->name || $client->peerhost;

    while ( <$client>) 
	{
		#print $client $_;
		next unless /\S/;       # blank line
		if (/END_OF_FILE/i)    
		{ 
			last;
		} 
		
		print Writer $_;

		my $nfound = select($read, undef, undef, 100);

		if( $nfound )
		{
			if( vec($read, fileno(Reader), 1))
			{
				$got=<Reader>;
				print $got;
			}
		}
		else
		{
			flush STDOUT;
			kill(HUP, -$$);
		}

		if( $WEB == $TRUE )
		{
			$got =~ s/</&lt;/g;
			$got =~ s/>/&gt;/g;
		}

		print $client $got;
    }
    Writer->autoflush(1);                                                                                                                                                            
    $client->autoflush(1);
    close $client;
}
