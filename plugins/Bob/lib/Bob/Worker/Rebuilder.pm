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
# $Id: Rebuilder.pm 17557 2009-03-30 00:20:05Z steve $
package Bob::Worker::Rebuilder;

use strict;
use warnings;
use base qw( TheSchwartz::Worker );

use TheSchwartz::Job;
use MT::Blog;
use Bob::Job;
use Bob::Util;

sub work {
    my $class = shift;
    my TheSchwartz::Job $job = shift;

    my $mt = MT->instance;

    my @jobs;
    push @jobs, $job;
    my $debug = MT->config('BobDebug');

    if ( my $key = $job->coalesce ) {
        while (
            my $job
            = MT::TheSchwartz->instance->find_job_with_coalescing_value(
                $class, $key
            )
            )
        {
            push @jobs, $job;
        }
    }

    foreach $job (@jobs) {
        my $hash   = $job->arg;
        my $job_id = $job->uniqkey;
        my $bobjob = Bob::Job->load($job_id);
        MT::TheSchwartz->debug("Parsing rebuild job #${job_id}...");
        if ($debug) {
            MT->log( 'Bob::Worker::Rebuilder called for job #' . $job_id );
        }
        if ($bobjob) {
            Bob::Util::rebuild_for_job($job);
            $job->completed();

            if ( $bobjob->is_active ) {
                $bobjob->inject_worker()
                    ;    # Reinject a new job to run in the future
            }
        }
        else {
            use MT::Log;
            $job->failed( 'Error rebuilding for Bob job #' . $bobjob->id );
        }
    }
}

sub grab_for    {60}
sub max_retries {100000}
sub retry_delay {60}

1;
