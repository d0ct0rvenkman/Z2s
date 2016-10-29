#!/usr/bin/perl -w
use strict;
use warnings;
use LWP;
use JSON qw( decode_json );
use Data::Dumper;
use List::Util qw[min max];

my $runascron;
my $firstarg = shift;

if ($firstarg eq "--cron")
{
        $runascron = 1;
} else {
        $runascron = 0;
}


my @alliance_Options = ("no-items","no-attackers");
my $alliance_LastKillId = 49150241;

# Config Single Kill Query
my $kill_Endpoint = 'https://zkillboard.com/api/killID';
my $kill_ID = -1;
my @kill_Options = ("no-items");
my $kill_seen = ();

# Static Data files
my %listOfShips = ();
my %listOfSystems = ();
my $itemname_File = 'itemname.csv';
my $systems_File = 'systems.csv';


my $lastkillidfile = 'LastKillID.dat';

# Slack config
my $slack_URL = 'https://hooks.slack.com/services/AAAA/BBBB/CCCC';
my $slack_Channel = '#killmails';
my $slack_Username = 'RAMPAGING KILLBOT';
my $slack_icon = ':skull:';

my $endpointbase = "https://zkillboard.com/api/orderDirection/asc";
my @api_endpoints = (
	# "https://zkillboard.com/api/kills/10b",
	# "https://zkillboard.com/api/kills/w-space",
);

my $tracked_alliances = {
	# 1234567 => 1,
	# 2345679 => 1,
};

my $tracked_corporations = {
	# 1234567 => 1,
	# 2345678 => 1,
};

my $tracked_characters = {
	# 12343567 => 1,
	# 23456781 => 1,
};

# build our endpoints!
# it is surely possible to do all three groups in one loop,
# but alas, I suck at perl.

my $tokencount = 0;
my $endpoint;

foreach my $key (keys %$tracked_alliances) {
        if ($tokencount == 0)
        {
                $endpoint = "${endpointbase}/allianceID/";
        }

        $endpoint .= "$key";
        $tokencount++;

        # api calls fail if there are more than 10 entities per group
        if ($tokencount == 10)
        {
                push @api_endpoints, $endpoint;
                $tokencount = 0;
        }
        else
        {
                $endpoint .= ",";
        }
}
if ($tokencount > 0)
{
        $endpoint =~ s/,$//;
        push @api_endpoints, $endpoint;
}

$tokencount = 0;
foreach my $key (keys %$tracked_corporations) {
        if ($tokencount == 0)
        {
                $endpoint = "${endpointbase}/corporationID/";
        }

        $endpoint .= "$key";
        $tokencount++;

        # api calls fail if there are more than 10 entities per group
        if ($tokencount == 10)
        {
                push @api_endpoints, $endpoint;
                $tokencount = 0;
        }
        else
        {
                $endpoint .= ",";
        }
}
if ($tokencount > 0)
{
        $endpoint =~ s/,$//;
        push @api_endpoints, $endpoint;
}

$tokencount = 0;
foreach my $key (keys %$tracked_characters) {
	if ($tokencount == 0)
	{
		$endpoint = "${endpointbase}/characterID/";
	}

	$endpoint .= "$key";
	$tokencount++;

	# api calls fail if there are more than 10 entities per group
	if ($tokencount == 10) 
	{
		push @api_endpoints, $endpoint;
		$tokencount = 0;
	}
	else
	{
		$endpoint .= ",";
	}
}
if ($tokencount > 0)
{
	$endpoint =~ s/,$//;
	push @api_endpoints, $endpoint;
}




print "Built the following API endpoints for querying...\n";
for (@api_endpoints)
{
	print "  " . $_ . "\n";
}


if ( -e $lastkillidfile )
{
	open(INFILE, $lastkillidfile);
	while (<INFILE>)
	{
		if ($_ =~ /^(\d+)$/)
		{
			$alliance_LastKillId = $1;
			print "Last killID file read successfully. Resuming from killID $alliance_LastKillId.\n";
			last;
		}
	}
	close INFILE;	

}


my $timeout = 300;
while (1) {
    my $start = time;
    $kill_seen = ();
    print "checking for new mails...\n";
    checkForNewKills();
    my $end = time;
    my $lasted = $end - $start;
    if ($runascron) {
        exit;
    }

    if ($lasted < $timeout) {  
	print "sleeping...\n";
        sleep($timeout - $lasted);
    }
};


exit;


sub checkForNewKills
{
	my $input = "";
	my $return;
	my $url;
	for (@api_endpoints)
	{
		$url = buildUrlAlly();
		$return = queryZkillboard($url);
		$return =~ s/^\s*\[\s*//g;
		$return =~ s/\s*\]\s*$//g;
		if (!($return =~ /^\s*$/))
		{
			$input .= ",$return";
		}
	}
	$input =~ s/^,//;
	$input = "[    " . $input . "    ]";
	my $decondedJson = analyzeJsonAlly($input);
	
}

sub buildUrlAlly
{
	my $url;
	$url = $_;

	for (@alliance_Options)
	{
		$url = $url.'/'.$_;
	}
	if ($alliance_LastKillId != 0)
	{
		$url = $url.'/afterKillID/'.$alliance_LastKillId;
	}

	#print "generated URL: $url\n";
	return $url;
}

sub queryZkillboard
{
	my ($url) = @_;
	my $result='';

	#print "  url: $url\n";

	my $ua = LWP::UserAgent->new;
	$ua->agent("Z2s Bot - Author : Alyla By - laby \@laby.fr");

	# set custom HTTP request header fields
	my $req = HTTP::Request->new(GET => $url);
	$req->header('content-type' => 'application/json');
	$req->header('Accept-Encoding' => 'gzip ');

	# Sending the request	 
        #print "  sending request using LWP...\n";
	my $resp = $ua->request($req);
	if ($resp->is_success)
	{
		#print "  LWP request sucessful\n";
		$result = $resp->decoded_content;
	}
	else
	{
		print Dumper($resp);
	}
	return $result;
}

sub analyzeJsonAlly
{
	my ($json) = @_;
	if ($json eq 'fail')
	{
		return;
	} 
	
	#print "JSON:\n$json\n/JSON\n";

	my $struct = decode_json($json);

	my $killId = 0;
	my $killDate = '';
	my $killValue = '';

	my @aUnref = @{ $struct };

	for(@aUnref)
	{
		my %hUnref = %{ $_ };
		$killId = $hUnref{'killID'};
		$killDate = $hUnref{'killTime'};
		$killValue = $hUnref{'zkb'}{'totalValue'};
		my $tmpUrl;
		my $killJson;

		if (defined($kill_seen->{$killId}))
		{
			print "  Kill " . $killId . " has already been seen. Skipping.\n";
		}
		else
		{
			$tmpUrl = buildUrlKill($killId);
			$killJson = queryZkillboard($tmpUrl);
			$alliance_LastKillId = max($killId,$alliance_LastKillId);
			analyzeJsonKill($killJson);
			$kill_seen->{$killId} = 1;
		}


	}

	open(my $FILE, ">", $lastkillidfile);
	print $FILE "$alliance_LastKillId\n";
	close($FILE);


}

sub buildUrlKill
{
	my ($killId) = @_;
	my $url;
	$url = $kill_Endpoint.'/'.$killId;
	for (@kill_Options)
	{
		$url = $url.'/'.$_;
	}
	return $url
}

sub analyzeJsonKill
{
	my ($json) = @_;
	if ($json eq 'fail')
	{
		return;
	}
	my $struct = decode_json($json);

	my @aUnref = @{ $struct };
	for(@aUnref)
	{

		my $msg = generateSlackMessage($_);
		sendToSlack($msg);
	}
}

sub formatNumber
{
	my ($number) = @_;
	my $firstPart;
	my $secondPart;

	if (index($number,'.') != -1)
	{
		my @splitResult = split(/\./,$number);
		$firstPart = $splitResult[0];
		$secondPart = $splitResult[1];
	}
	else
	{
		$firstPart = $number;
		$secondPart = '00';
	}

	my $firstReversed = reverse($firstPart);
	$firstReversed =~ s/([0-9]{1,3})/$1,/g;
	my $isk = reverse($firstReversed).'.'.$secondPart;
	$isk =~ s/^,//g;

	return $isk; #reverse($firstReversed).'.'.$secondPart;
}

sub generateSlackMessage
{
	my ($hashRef) = @_;
	my %hUnref = %{ $hashRef };

	my $solarSystemID = $hUnref{'solarSystemID'};
	my $killId = $hUnref{'killID'};

	my @attackers = @{ $hUnref{'attackers'} };

	my $numberAttackers = 0;

	if ($numberAttackers == 0)
	{
		$numberAttackers = scalar @attackers;
	}

	my $broCount = 0;
	my $broString = "";
	for (@attackers)
	{
		
		#print "  Attacker: " . $_->{'characterName'} . "\n";
		if (defined($tracked_alliances->{$_->{'allianceID'}})
			or defined($tracked_corporations->{$_->{'corporationID'}})
			or defined($tracked_characters->{$_->{'characterID'}})
		)
		{
			$broCount++;
			$broString .= $_->{'characterName'} . ", ";
		}
	}

	if ($broCount > 0)
	{
		$broString =~ s/, $//;
		$broString = ",{ \"title\": \"Bros Involved\", \"value\": \"$broString\" }";
		
	}

	my $lossValue = $hUnref{'zkb'}{'totalValue'};
	$lossValue = formatNumber($lossValue);
	my $victimID = $hUnref{'victim'}{'characterID'};
	my $victimName = $hUnref{'victim'}{'characterName'};
	my $victimCorp = $hUnref{'victim'}{'corporationName'};
	my $victimAllyID = $hUnref{'victim'}{'allianceID'};
	my $victimAlly = $hUnref{'victim'}{'allianceName'};
	my $victimShip = $hUnref{'victim'}{'shipTypeID'};

	my $killURL = 'https://zkillboard.com/kill/'.$killId;

	my $victimURL = 'https://zkillboard.com/character/'.$victimID;

	my $msg;

	#ship name
	my $shipName = getShipName($victimShip);
	my $solarSystem = getSystemName($solarSystemID);
	if ($victimAlly eq "") { $victimAlly = "N/A"; }
	if ($victimName eq "") { $victimName = "N/A"; }
	
	if ($victimID == 0)
	{
		$msg = "$victimCorp - $shipName. Killmail value : $lossValue ISK (<$killURL|Link>)";
	}
	else
	{
		$msg = "<$victimURL|$victimName> ($victimCorp) - $shipName. Killmail value : $lossValue ISK (<$killURL|Link>)";
	}

	my $returnval;

	$returnval = "
\"attachments\": 
	[ 
		{
			\"fallback\": \"$msg\",
			\"color\": \"#777\",
			\"title\": \"$shipName destroyed in $solarSystem\", 
			\"title_link\": \"$killURL\", 
			\"fields\": [ 
				{ \"title\": \"Pilot\", \"value\": \"$victimName\", \"short\": true }, 
				{ \"title\": \"Corporation\", \"value\": \"$victimCorp\", \"short\": true  }, 
                                { \"title\": \"Alliance\", \"value\": \"$victimAlly\", \"short\": true  },			
				{ \"title\": \"Total Value\", \"value\": \"$lossValue ISK\", \"short\": true }
				$broString
			],
			\"thumb_url\": \"https://imageserver.eveonline.com/Type/${victimShip}_64.png\" 
		}
	]";

	return $returnval;



}
sub getShipName
{
	my ($shipId) = @_;
	if ( exists $listOfShips{$shipId} )
	{
		return $listOfShips{$shipId};
	}
	else
	{
		open(my $fh, '<', $itemname_File) or die "Could not open file '$itemname_File' $!";
		for(<$fh>)
		{
			my $line = $_;
			my @splitResult = split(/\t/,$line);
			if ( $splitResult[0] eq $shipId )
			{
				$splitResult[1] =~ s/\n//g;
				$listOfShips{$shipId} = $splitResult[1];
				return $listOfShips{$shipId};
			}
		}
	}
	return $shipId;
}

sub getSystemName
{
        my ($systemId) = @_;
        if ( exists $listOfSystems{$systemId} )
        {
                return $listOfSystems{$systemId};
        }
        else
        {
                open(my $fh, '<', $systems_File) or die "Could not open file '$systems_File' $!";
                for(<$fh>)
                {
                        my $line = $_;
                        my @splitResult = split(/\t/,$line);
                        if ( $splitResult[0] eq $systemId )
                        {
                                $splitResult[1] =~ s/\n//g;
                                $listOfSystems{$systemId} = $splitResult[1];
                                return $listOfSystems{$systemId};
                        }
                }
        }
        return $systemId;
}










sub sendToSlack
{
	my ($msg) = @_;
	my $ua = LWP::UserAgent->new;
	my $req = HTTP::Request->new(POST => $slack_URL);
	$ua->agent("Z2s Bot - Author : Alyla By - laby \@laby.fr");
	 
	# add POST data to HTTP request body
	#toto
	my $post_data = '{ '.$msg.', "channel": "'.$slack_Channel.'" , "username":"'.$slack_Username.'", "icon_emoji":"'.$slack_icon.'"}';
	#print $post_data . "\n";
	$req->content($post_data);
	 
	my $resp = $ua->request($req);
	if ($resp->is_success)
	{
	    my $message = $resp->decoded_content;
	    print "  " . time .": Sent message to Slack successfully\n";
	    #print "Received reply: $message\n";
	}
	else
	{
		print "Couldn't send message to Slack\n";
		print "HTTP POST error code: ", $resp->code, "\n";
		print "HTTP POST error message: ", $resp->message, "\n";
	}
}

