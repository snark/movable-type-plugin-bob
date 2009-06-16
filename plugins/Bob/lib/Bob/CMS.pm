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
# $Id: CMS.pm 17557 2009-03-30 00:20:05Z steve $
package Bob::CMS;

use strict;
use Bob::Job;
use Bob::Util;

use MT::Blog;
use MT::Util;

sub list_jobs {
    my ($app) = @_;

    my $blog   = $app->blog;
    my $plugin = MT->component('Bob');
    my %blog_names;
    my $blog_iter = MT::Blog->load_iter();
    while ( my $b = $blog_iter->() ) {
        $blog_names{ $b->id } = $b->name;
    }
    my $types_display = Bob::Util::constant_to_hashref('types');
    my $freq_display  = Bob::Util::constant_to_hashref('frequencies');

    $app->listing(
        {   type     => 'bob_job',
            template => 'list_bob_job.tmpl',

            # args  => {
            #     sort      => 'identifier',
            #     direction => 'descend'
            # },
            code => sub {
                my ( $job, $row ) = @_;
                $row->{blog_name}    = $blog_names{ $job->blog_id };
                $row->{type_display} = $types_display->{ $job->type };
                $row->{frequency_display}
                    = $freq_display->{ $job->frequency };
                if ( $job->is_active ) {
                    $row->{is_active} = 'Y';
                }
                else {
                    $row->{is_active} = 'N';
                }
                if ( $job->last_run ) {
                    $row->{formatted_last_run}
                        = MT::Util::format_ts( '%d %b %Y %H:%M',
                        $job->last_run );
                }
                else {
                    $row->{formatted_last_run} = 'N/A';
                }
            },
        }
    );
}

sub edit_job {
    my ($app)  = @_;
    my $q      = $app->param;
    my $plugin = MT->component('Bob');
    my $tmpl   = $plugin->load_tmpl('edit_bob_job.tmpl');
    my $param;
    my ( $job, $frequency, $type );
    if ( $app->param('id') ) {
        $job       = Bob::Job->load( $app->param('id') );
        $frequency = $job->frequency;
        $type      = $job->type;
        my $blog = MT::Blog->load( $job->blog_id );
        $param->{blog_name} = $blog->name;
        $param->{blog_id}   = $blog->id;
        $param->{is_active} = $job->is_active;
        $param->{id}        = $job->id;
    }
    else {
        my @blogs_loop;
        my @blogs = MT::Blog->load();
        foreach my $blog (@blogs) {
            my $row;
            $row->{blog_id}   = $blog->id;
            $row->{blog_name} = $blog->name;
            if ($job) {
                if ( $job->blog_id == $blog->id ) {
                    $row->{selected} = 1;
                }
            }
            push @blogs_loop, $row;
        }
        $param->{blogs_loop} = \@blogs_loop;
    }
    $param->{object_label}        = Bob::Job->class_label;
    $param->{object_label_plural} = Bob::Job->class_label_plural;
    $param->{object_type}         = Bob::Job->class_type;
    $param->{frequencies_loop}
        = Bob::Util::constant_to_template_loop( 'frequencies',
        'frequency_value', 'frequency_name', $frequency );
    $param->{types_loop}
        = Bob::Util::constant_to_template_loop( 'types', 'type_value',
        'type_name', $type );
    return $app->build_page( $tmpl, $param );
}

sub save_job {
    my $app = shift;
    $app->forward('save');
}

sub cms_job_presave_callback {
    my ( $cb, $app, $job, $orig ) = @_;
    unless ( $app->{query}->{is_active} ) {
        $job->is_active(0);
    }
    return 1;
}

sub cms_job_postsave_callback {
    my ( $cb, $app, $job, $orig ) = @_;
    use MT::TheSchwartz::FuncMap;
    my @funcmaps = MT::TheSchwartz::FuncMap->load(
        { funcname => 'Bob::Worker::Rebuilder' } );
    my $funcmap = pop @funcmaps;
    if ($funcmap) {
        use MT::TheSchwartz::Job;
        my @queued = MT::TheSchwartz::Job->load(
            { uniqkey => $job->id, funcid => $funcmap->funcid } );
        foreach my $qd (@queued) {
            $qd->remove;
        }
    }
    if ( $job->is_active ) {
        $job->inject_worker;
    }
    return 1;
}

1;
