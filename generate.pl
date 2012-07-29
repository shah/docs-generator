#!/usr/bin/perl

use strict;
use Getopt::Long qw(:config auto_help);
use Pod::Usage;
use File::Find;
use File::Basename;
use File::Path qw(make_path remove_tree);
use Data::Dumper;
use Cwd qw(realpath);

sub getScriptOptions
{
	# if any parameters are passed in, they are the defaults
	my $numberOfFilesToGenerate    = shift;
	my $randomizableDataDir        = shift;
	my $destinationDir             = shift;
	my $dataFilesContainHeader     = shift;
	my $useDataFileHeaderAsSrcName = shift || 0;
	my $verbose                    = shift || 0;

	GetOptions(
    	'numberOfFilesToGenerate=i' => \$numberOfFilesToGenerate,
    	'randomizableDataDir:s' => \$randomizableDataDir,
    	'destinationDir:s' => \$destinationDir,
    	'dataFilesContainHeader!' => \$dataFilesContainHeader,
    	'useDataFileHeaderAsSrcName!'  => \$useDataFileHeaderAsSrcName,
    	'verbose!'  => \$verbose
	);

	return
	{
		'randomizableDataDir' => realpath($randomizableDataDir),
		'destinationDir' => realpath($destinationDir),
		'numberOfFilesToGenerate' => $numberOfFilesToGenerate,
    	'dataFilesContainHeader'  => $dataFilesContainHeader,
    	'useDataFileHeaderAsSrcName'  => $useDataFileHeaderAsSrcName,
		'verbose' => $verbose
	};
}

sub createRandomizableDataSource
{
	my ($scriptOptions, $index, $fileNameWithPath, $dataSourceName) = @_;

	my @data = ();
	my @messages = ();

	if(open (FILE, $fileNameWithPath))
	{
		# read the entire file and then split it into items but automatically 
		# automatically account for CRLF or LF formats

		my $contents = <FILE>;
		#print "\n====\n$fileNameWithPath\n" . $contents . "\n====\n" if $dataSourceName eq 'document-type';
		@data = split(/\r\n|\r|\n/, $contents) if $contents;
		close FILE;
	}
	else
	{
		push(@messages, "Unable to open file $fileNameWithPath: $!");
	}

	my $header = $scriptOptions->{dataFilesContainHeader} ? shift(@data) : undef;
	my $name = ($scriptOptions->{useDataFileHeaderAsSrcName} && $header) ? $header : $dataSourceName;

	return
	{
		'index'    => $index,
		'name'     => $name,
		'data'     => \@data,
		'messages' => \@messages,
		'srcFile'  => $fileNameWithPath
	};
}

sub discoverRandomizableDataSources
{
	my ($scriptOptions) = @_;
	my $result = {
		'byName' => {},
		'all' => []
	};
	my $index = 0;

	find(sub
	{
		# See http://perldoc.perl.org/File/Find.html for information about how this method works
		# $File::Find::dir is the current directory name,
		# $_ is the current filename within that directory
		# $File::Find::name is the complete pathname to the file.

		# if it's not a text file, we don't care about it
		return unless -T $_;

		my ($filename, $directories, $suffix) = fileparse($File::Find::name, qr/\.[^.]*/);
		my $dataSource = createRandomizableDataSource($scriptOptions, $index, $File::Find::name, $filename, $suffix);
		$result->{byName}->{$dataSource->{name}} = $dataSource;
		push(@{$result->{all}}, $dataSource);

	}, $scriptOptions->{randomizableDataDir});

	return $result;
}

sub summarize
{
	my ($scriptOptions, $randomizableDataSources) = @_;	

	print "Options:\n";
	foreach(sort keys %{$scriptOptions})
	{
		print "    $_ = $scriptOptions->{$_}\n";
	}

	print "\nData Sources:\n";
	foreach(sort keys %{$randomizableDataSources->{byName}})
	{
		my $dataSource = $randomizableDataSources->{byName}->{$_};
		my $data = $dataSource->{data};
		my $items = scalar(@{$data});
		print "    $_ ($items)\n";
	}
}

sub getRandomElementFromDataSource
{
	my ($scriptOptions, $randomizableDataSources, $dataSourceName) = @_;

	if(exists $randomizableDataSources->{byName}->{$dataSourceName})
	{
		my $dataSource = $randomizableDataSources->{byName}->{$dataSourceName};
		my $data = $dataSource->{data};
		my $items = scalar(@{$data});
		my $index = int(rand($items));
	    my $result = $data->[$index];
	    return $result ? $result : "Unable to find index $index for '$dataSourceName' ($items items)";
	}
	else
	{
		return "Data source '$dataSourceName' does not exist in: " . Dumper(keys %{$randomizableDataSources->{byName}});
	}
}

sub isRandomlyTrue
{
	return rand(1) > 0.5 ? 1 : 0;
}

sub generateValidRandomFileInfo
{
	my ($scriptOptions, $randomizableDataSources, $index) = @_;
	my $result = 
	{
		directory => [],
		fileName => '',
		extension => '',
		templateFile => undef,
		hasMiddleName => isRandomlyTrue(),
		isMiddledInitial => isRandomlyTrue(),
		hasWatcherEmail => isRandomlyTrue(),
		hasOptionalField => isRandomlyTrue()
	};


	my ($agency, $component) = split(/,/, getRandomElementFromDataSource($scriptOptions, $randomizableDataSources, 'Agency,Component'));	
	my $lastName = getRandomElementFromDataSource($scriptOptions, $randomizableDataSources, 'Last Name');
	my $firstName = getRandomElementFromDataSource($scriptOptions, $randomizableDataSources, 'First Name');

	# randomly create a middle name using the first name dataset and sometimes just use the middle initial instead of the whole name
	my $middleName = $result->{hasMiddleName} ? getRandomElementFromDataSource($scriptOptions, $randomizableDataSources, 'First Name') : '';
	$middleName = $result->{isMiddledInitial} && $middleName ? substr($middleName, 0, 1) : $middleName;

	my $positionTitle = getRandomElementFromDataSource($scriptOptions, $randomizableDataSources, 'Position Title');	
	my $year = getRandomElementFromDataSource($scriptOptions, $randomizableDataSources, 'Year');	
	my $documentType = getRandomElementFromDataSource($scriptOptions, $randomizableDataSources, 'Document Type');	
	my $watcherEmail = $result->{hasWatcherEmail} ? "$firstName.$lastName\@$agency.gov" : '';
	my $optionalField = $result->{hasOptionalField} ? ';' . getRandomElementFromDataSource($scriptOptions, $randomizableDataSources, 'Optional Field') : '';	

	# this is the random template that we will copy when copying the file
	$result->{templateFile} = getRandomElementFromDataSource($scriptOptions, $randomizableDataSources, 'File Template');
	my ($tmplF, $tmplD, $tmplExtn) =  fileparse($result->{templateFile}, qr/\.[^.]*/);

	$result->{directory} = File::Spec->catdir($scriptOptions->{destinationDir}, $agency, $component);	
	$result->{relativeDir} = File::Spec->catdir($agency, $component);	
	$result->{fileName} = "$lastName;$firstName;$middleName;$positionTitle;$year;$documentType;$watcherEmail$optionalField";
	$result->{extension} = $tmplExtn;
	$result->{agency} = $agency;
	$result->{component} = $component;
	$result->{firstName} = $firstName;
	$result->{lastName} = $lastName;
	$result->{middleName} = $middleName;
	$result->{positionTitle} = $positionTitle;
	$result->{year} = $year;
	$result->{documentType} = $documentType;
	$result->{watcherEmail} = $watcherEmail;
	$result->{optionalField} = $optionalField;

	return $result;
}

sub createFile
{
	my ($scriptOptions, $randomizableDataSources, $fileInfo) = @_;

	make_path($fileInfo->{directory}, { verbose => $scriptOptions->{verbose} });

	my $fullPath = File::Spec->catfile($fileInfo->{directory}, "$fileInfo->{fileName}$fileInfo->{extension}");

	if(open(FILE, ">$fullPath"))
	{
		print FILE Data::Dumper->Dump([$fileInfo]);
		close(FILE);
	}

	print "$fullPath\n";
}

sub main
{
	my $scriptOptions = getScriptOptions(10, "./randomizable-data", "./generated-files", 1, 1);
	my $randomizableDataSources = discoverRandomizableDataSources($scriptOptions);

	summarize($scriptOptions, $randomizableDataSources);

	for my $index (1..$scriptOptions->{numberOfFilesToGenerate})
	{
		my $fileInfo = generateValidRandomFileInfo($scriptOptions, $randomizableDataSources, $index);
		createFile($scriptOptions, $randomizableDataSources, $fileInfo);
	}
}

main();