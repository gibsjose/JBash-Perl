#!/usr/bin/perl
use strict;
use File::Temp qw(tempfile);
use File::stat;
use Fcntl;
use Env;
use Cwd;

# |jbash.pl|: Implements a rudimentary shell in Perl

### Initial Setup

# Get user env variable
my $user = $ENV{USER};

# Complete input string
my $input_line;

# Parsed input array (first index is base command)
my @command;

# Obtain the start time
my $start_time = time;

# Create a temp file for storing history
my $fh = tempfile();

# Next command if !n is used
my $next_command = "NULL";

# Alias array
my %aliases;

### Main Loop
while(1) {

	# Get a line of input (could be from the history temp file)
	if(($next_command ne "NULL") && $next_command !~ /^!.*/) {

		$input_line = $next_command;
		$next_command = "NULL";

	} else{

		# Print a prompt
		print "\n[jbash] \$ ";

		# Get user input
		$input_line = <STDIN>;

	}

	# Save the command to the command history (if it doesn't begin with '!' or is an empty line)
	if($input_line !~ /^!.*/ && $input_line !~ /^\s+/) {
		$fh->write($input_line);
	}

	# Remove the newline character
	chomp $input_line;

	# Parse input line into command array
	@command = split / /, $input_line;

	# Expand aliases 
	my @alias_exp;
	foreach my $i (0..(@command - 1)) {
		if(exists $aliases{$command[$i]}) {
			$command[$i] = $aliases{$command[$i]};

			$input_line = "";

			# Rebuild expanded input string
			foreach my $c (@command) {
				chomp $c;
				$input_line = "$input_line"."$c ";
			}

			# Re-tokenize
			@command = split / /, $input_line;
		}
	}

	# Expand any arguments with ~user to /Users/user, or expand ~ to $ENV{HOME}
	foreach my $i (1..(@command - 1)) {
		if($command[$i] =~ /~[[:alpha:]]+/) {
			my $username = substr $command[$i], 1;
			$command[$i] = "/Users/$username";
		}

		if($command[$i] =~ /~/) {
			$command[$i] = $ENV{HOME};
		}
	}

	# Parse command and execute it
	if($command[0] =~ /exit\s*/) {

		exit;

	} elsif($command[0] =~ /times\s*/) {

		my $cur_time = time - $start_time;
		print "Elapsed time: $cur_time seconds\n";

	} elsif($command[0] =~ /history\s*/) {

		print "\nHistory\n";

		my $index = 0;

		# Rewind
		seek $fh, 0, 0;

		while(<$fh>) {
			$index++;
			print "\t$index:\t$_";
		}

		# End of file
		seek $fh, 0, 2;

	} elsif($command[0] =~ /![[:digit:]]+\s*/) {

		# Remove the ! and interpret as a number
		my $line_num = substr($command[0], 1);
		my $index = 0;

		# Rewind
		seek $fh, 0, 0;

		# Seek to desired line
		do {
			$next_command = <$fh>;
			chomp $next_command;
			$index++;
		} until($index == $line_num or eof);

		print "\nExecuting \"$next_command\"\n\n";

		# End of file
		seek($fh, 0, 2);

	} elsif($command[0] =~ /size\s*/) {

		if(@command == 2) {

			my $sb;

			eval{$sb = stat($command[1])};
			
			if($@) {
				print "$command[1] not found\n";
			} else {
				printf "\"$command[1]\" Size: %s bytes\n", $sb->size;
			}
		}

	} elsif($command[0] =~ /alias\s*/) {

		# Implement 'alias': 'alias <keyword> = <alias string>'
		my $alias;

		# Create alias after the '='
		foreach my $i (3..(@command - 1)) {
			$alias = "$alias"."$command[$i] ";
		}

		#print "Aliasing $command[1] with $alias\n";

		$aliases{$command[1]} = $alias;

	} elsif($command[0] =~ /echo\s*/) {

		print "\nEcho:\n";

		foreach my $i (1..(@command - 1)) {
			print "$command[$i] ";
		}

		print "\n";

	} elsif($command[0] =~ /pwd\s*/) {

		my $pwd = getcwd;
		print "$pwd\n";
	
	} elsif($command[0] =~ /cd\s*/) {

		if(@command == 1) {
			chdir $ENV{HOME};
		} else {
			chdir $command[1] or print "$command[1] not found\n";
		}

	} else {

		unless(fork) {
			exec($input_line);
			exit;
		}
		wait;
	}
}
