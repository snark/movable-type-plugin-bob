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
# $Id: Job.pm 17557 2009-03-30 00:20:05Z steve $
package Bob::Job;
use strict;
use constant WORKER_PRIORITY    => 1;
use constant SECONDS_PER_MINUTE => 60;

use base qw( MT::Object );
__PACKAGE__->install_properties(
    {   column_defs => {
            'id'          => 'integer not null auto_increment',
            'blog_id'     => 'integer not null',
            'is_active'   => 'integer not null default 1',
            'frequency'   => 'integer not null',
            'target_time' => 'string(4)',
            'type'        => 'string(10)',
            'identifier'  => 'string(255)',
            'last_run'    => 'datetime',
            'next_run'    => 'datetime'
        },
        indexes     => { blog_id => 1, is_active => 1 },
        audit       => 1,
        datasource  => 'bob_job',
        primary_key => 'id',
    }
);

sub class_type {
    'bob_job';
}

sub class_label {
    MT->translate("Rebuilder Job");
}

sub class_label_plural {
    MT->translate("Rebuilder Jobs");
}

sub inject_worker {
    my $self = shift;
    require MT::TheSchwartz;
    require MT::Util;
    require TheSchwartz::Job;
	require MT::Blog;
	my $blog = MT::Blog->load( $self->blog_id );
	return unless ( $blog );
    my $debug     = MT->config('BobDebug');
    my $frequency = $self->frequency;
    my $last_run  = $self->last_run;
    my $time      = time();
    if ($last_run) {    # turn it into an epoch - convert it to GMT first
        $last_run = MT::Util::ts2epoch( $blog, $last_run );
    }
    else {
        $last_run = $time;
    }
    # We must never insert a job with a next_run in the past
    my $next_epoch = $last_run + ( $frequency * SECONDS_PER_MINUTE );
    if ( $next_epoch < $time ) {
        if ($debug && $self && $self->id ) {
            MT->log(  'Bob job #'
                    . $self->id
                    . 'attempted to insert a job into the past with epoch '
                    . $next_epoch );
        }
        $next_epoch = time() + SECONDS_PER_MINUTE;
    }
    my $job = TheSchwartz::Job->new();
    $job->funcname('Bob::Worker::Rebuilder');
    $job->uniqkey( $self->id );
    $job->priority(WORKER_PRIORITY);
    $job->coalesce( $self->id );
    $job->run_after($next_epoch);
    MT::TheSchwartz->insert($job);
    $self->next_run( MT::Util::epoch2ts( $blog, $next_epoch ) );
    $self->save;
}

1;
