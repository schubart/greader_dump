#!/opt/local/bin/perl

# TODO: polish
# timestamp of most recent entry in atom view
# inline fixing of $id
# inline getting first entry
# usage string
# inline binmode
# nicer anchors
# PASSWORD via command line not good

use strict;
use warnings;
use Data::Dump;
use Digest::MD5;
use Getopt::Long;
use Inline::Files;
use Template;
use WebService::Google::Reader;

$XML::Atom::ForceUnicode = 1;

sub WebService::Google::Reader::ListElement::filename {
    my ($self) = @_;
    return Digest::MD5::md5_hex($self->id) . '.html';
}

my ($username, $password, $maxfeeds);
my $outdir = '.';
GetOptions('username=s' => \$username,
	   'password=s' => \$password,
	   'outdir=s'   => \$outdir,
	   'maxfeeds=i' => \$maxfeeds) or die;

my $reader = WebService::Google::Reader->new(username => $username,
					     password => $password,
					     secure   => 1);

my $tt = Template->new();
my %labels;
my @feeds = ($reader->feeds);
@feeds = @feeds[0 .. $maxfeeds - 1] if defined $maxfeeds;
foreach my $feed (@feeds) {
    if (@{$feed->categories}) {
        foreach my $category (@{$feed->categories}) {
            my $label = $category->label;
            next if $label =~ /^zzz_/;

            push @{$labels{$label}}, $feed;
        }
    }
    else {
        push @{$labels{'bbb_unclassified'}}, $feed;
    }

    my $id = $feed->id;
    $id =~ s/\?/%3F/g;
    my $atom = $reader->feed($id);

    if (! defined $atom) {
	print STDERR 'Error: ' . $feed->title . "\n";
	next;
    }

    my @entries = $atom->entries;
    $feed->{first_title} = @entries ? $entries[0]->title : '(No items)';

    seek ATOM, 0, 0;
    $tt->process(\*ATOM,
		 { atom => $atom },
		 $outdir . '/' . $feed->filename,
		 { binmode => ':utf8' });
}

$tt->process(\*INDEX,
	     { labels => \%labels, },
	     $outdir . '/' . 'index.html',
	     { binmode => 'utf8'} );

__INDEX__
[% USE date %]
<html>
  <head>
    <meta http-equiv="Content-type" content="text/html; charset=utf-8"/>
    <title>Feeds</title>
  </head>

  <body>
    <p>[% date.format %]</p>

    <ul>
      [% FOREACH label IN labels.keys.sort %]
      <li>
	<a href="#[% label %]">[% label %]</a>
      </li>
      [% END %]
    </ul>

    [% FOREACH label IN labels.keys.sort %]
    <p id="[% label %]">[% label %]</p>
    <ul>
      [% FOREACH feed IN labels.$label %]
      <li>
	<a href="[% feed.filename %]">[% feed.title %]</a>
	[% feed.first_title %]
      </li>
      [% END %]
    </ul>
    [% END %]
  </body>
</html>

__ATOM__
<html>
  <head>
    <meta http-equiv="Content-type" content="text/html; charset=utf-8"/>
    <title>[% atom.title %]</title>
  </head>

  <body>
    <p>[% atom.title %]</p>

    <ul>
      [% FOREACH entry IN atom.entries %]
      <li><a href="#a[% loop.index %]">[% entry.title %]</a></li>
      [% END %]
    </ul>

    [% FOREACH entry IN atom.entries %]
    <hr/>
    <a name="a[% loop.index %]"/>
    <p><b><a href="[% entry.link.href %]">[% entry.title %]</a></b></p>
    <p>[% entry.summary %][% entry.content.body %]</p>
    [% END %]
  </body>
</html>
