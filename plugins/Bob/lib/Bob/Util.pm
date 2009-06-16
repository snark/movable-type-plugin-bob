#############################################################################
# Copyright © 2008-2009 Six Apart Ltd.
# This program is free software: you can redistribute it and/or modify it 
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation, or (at your option) any later version.  
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License 
# version 2 for more details.  You should have received a copy of the GNU 
# General Public License version 2 along with this program. If not, see 
# <http://www.gnu.org/licenses/>.
# $Id: Util.pm 17557 2009-03-30 00:20:05Z steve $
package Bob::Util;

use strict;
use warnings;

use constant FREQUENCIES => [
    { 1    => '1 minute' },
    { 2    => '2 minutes' },
    { 5    => '5 minutes' },
    { 10   => '10 minutes' },
    { 15   => '15 minutes' },
    { 20   => '20 minutes' },
    { 30   => '30 minutes' },
    { 45   => '45 minutes' },
    { 60   => '60 minutes' },
    { 90   => '90 minutes' },
    { 120  => '2 hours' },
    { 240  => '4 hours' },
    { 360  => '6 hours' },
    { 480  => '8 hours' },
    { 720  => '12 hours' },
    { 1440 => '24 hours' },
];

use constant TYPES => [
    { 'all'      => 'Entire Blog' },
    { 'indexes'  => 'All Indices' },
    { 'archives' => 'All Archives' },
];

sub constant_to_template_loop {
    my ( $constant, $key_name, $val_name, $selected_val ) = @_;
    my @loop;
    my $data;
    if ( $constant eq 'frequencies' ) {
        $data = FREQUENCIES;
    }
    elsif ( $constant eq 'types' ) {
        $data = TYPES;
    }
    else {
        return;
    }
    foreach my $pair (@$data) {
        my $row;
        my @pair = %$pair;
        $row->{$key_name} = $pair[0];
        $row->{$val_name} = $pair[1];
        if ( $selected_val eq $pair[0] ) {
            $row->{selected} = 1;
        }
        push @loop, $row;
    }
    return \@loop;
}

sub constant_to_hashref {
    my ($constant) = @_;
    my %hash;
    my $data;
    if ( $constant eq 'frequencies' ) {
        $data = FREQUENCIES;
    }
    elsif ( $constant eq 'types' ) {
        $data = TYPES;
    }
    else {
        return;
    }
    foreach my $hashref (@$data) {
        my ( $k, $v ) = each %$hashref;
        $hash{$k} = $v;
    }
    return \%hash;
}

sub rebuild_for_job {
    my $job = shift; # Schwartz job
    use MT::WeblogPublisher;
    use MT::Util;
    use MT;
    use Bob::Job;
    my $bobjob = Bob::Job->load( $job->uniqkey );
    return 1 unless $bobjob;
    my $debug   = MT->config('BobDebug');
    my $blog_id = $bobjob->blog_id;

    if ( $bobjob->is_active ) {
        my $types = constant_to_hashref('types');
        use MT::WeblogPublisher;
        my $pub = MT::WeblogPublisher->new;
        if ( $bobjob->type eq 'all' ) {
            $pub->rebuild( BlogID => $blog_id );
            if ($debug) {
                MT->log( 'Bob rebuilding all for blog ' . $blog_id );
            }
        }
        elsif ( $bobjob->type eq 'indexes' ) {
            if ($debug) {
                MT->log( 'Bob rebuilding indexes for blog ' . $blog_id );
            }
            $pub->rebuild_indexes( BlogID => $blog_id );
        }
        elsif ( $bobjob->type eq 'archives' ) {
            if ($debug) {
                MT->log( 'Bob rebuilding archives for blog ' . $blog_id );
            }
            $pub->rebuild( BlogID => $blog_id, NoIndexes => 1 );
        }
        $bobjob->last_run( MT::Util::epoch2ts( $bobjob->blog_id, time ) );
        $bobjob->save;
		return 1;
    }
}

sub job_preremove {
    my ( $cb, $bobjob ) = @_;
    use MT::TheSchwartz::Job;
    my $key = $bobjob->id;
    my @jobs = MT::TheSchwartz::Job->load( { uniqkey => $key } );
    foreach my $job (@jobs) {
        $job->remove;
    }
	return 1;
}

1;
