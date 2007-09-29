package MT::Plugin::EntryRevisions;
use strict;
#  EntryRevisions - 
#           Original Copyright (c) 2007 Piroli YUKARINOMIYA (MagicVox)
#           Open MagicVox.net - http://www.magicvox.net/
#           @see http://www.magicvox.net/archive/2007/09292314/

use MT;
use MT::Entry;
use MT::Author;
use MT::Permission;
use MT::PluginData;
use MT::Util qw( encode_html format_ts );

use vars qw( $MYNAME $VERSION $VERBOSE );
$MYNAME = 'EntryRevisions';
$VERSION = '1.00';
$VERBOSE = 0;

# The user specified by DEFAULT_ADMIN_AUTHOR_ID posts the versions
# author_id 0 means that the super-user is specified automatically
use constant DEFAULT_ADMIN_AUTHOR_ID => 0;
# Specify the numbers of the past versions stored.
use constant DFAULT_REVISIONS_STORED => 5;
use constant REVISIONS_STORED_MIN =>    3;
use constant REVISIONS_STORED_MAX =>    100;

use base qw( MT::Plugin );
my $plugin = new MT::Plugin ({
        name => $MYNAME,
        version => $VERSION,
        author_name => '<MT_TRANS phrase="Piroli YUKARINOMIYA">',
        author_link => "http://www.magicvox.net/?$MYNAME",
        doc_link => "http://www.magicvox.net/archive/2007/09292314/?$MYNAME",
        l10n_class => 'EntryRevisions::L10N',
        blog_config_template => \&config_template,
        settings => new MT::PluginSettings ([
            ['storage_blog_id', { Default => 0 }],
            ['admin_author_id', { Default => DEFAULT_ADMIN_AUTHOR_ID }],
            ['stored_versions_number', { Default => DFAULT_REVISIONS_STORED }],
        ]),
        description => '<MT_TRANS phrase="Automatically storing the version copies of entry when it saved, and you can revert the contents of entry from the stored version copies.">',
});
MT->add_plugin ($plugin);

sub instance { $plugin; }



### HTML Template for configurations
sub config_template {
    my ( $plugin, $param, undef ) = @_;
    my $blog_id = MT->instance->{query}->param('blog_id');
    my $storage_blog_id = $param->{storage_blog_id};

    my $blogs = [];
    push @$blogs, {
        name => '<MT_TRANS phrase="Disable">',
        value => 0,
        selected => ($storage_blog_id != 0),
    };
    my $iter = MT::Blog->load_iter();
    while (my $blog = $iter->()) {
        if ($blog->id != $blog_id) { # skip myself
            push @$blogs, {
                name => encode_html( $blog->name ),
                value => $blog->id,
                selected => ($storage_blog_id == $blog->id),
            };
        }
    }
    $param->{version_stored_blogs} = $blogs;

    $plugin->load_tmpl ('config.tmpl');
}



### Regist callbacks
my $_tmpl_sufix;
SWITCH_VERSION_CALLBACKS: {
    4.0 <= $MT::VERSION_ID && do {
        $_tmpl_sufix = qw( 4 );
        last SWITCH_VERSION_CALLBACKS;
    };
    3.3 <= $MT::VERSION_ID && do {
        $_tmpl_sufix = qw( 33 );
        MT->add_callback ('MT::Entry::post_save', 9, $plugin, \&store_entry_revisions);
        MT->add_callback ('MT::Entry::post_remove', 9, $plugin, \&remove_entry_revisions);
        MT->add_callback ('MT::App::CMS::AppTemplateParam.edit_entry', 9, $plugin, \&versions_param);
        MT->add_callback ('MT::App::CMS::AppTemplateSource.edit_entry', 9, $plugin, \&versions_tmpl);
        last SWITCH_VERSION_CALLBACKS;
    };
    3.2 <= $MT::VERSION_ID && do {
        $_tmpl_sufix = qw( 32 );
        last SWITCH_VERSION_CALLBACKS;
    };
}



### Callback - Store the versions of saved entry
sub store_entry_revisions {
    my ($eh, $entry) = @_;

    # Retrieve plugin setting of this entry's blog
    my $cfg_data = &instance->get_config_obj ('blog:'. $entry->blog_id)
        or return; # not yet configurated
    my $cfg_hash = $cfg_data->data
        or return; # not yet configurated

    # Retrieve blog for versions
    my $versions_blog_id = $cfg_hash->{storage_blog_id}
        or return; # not in use

    # Retrieve author in versions blog
    my $versions_author_id = $cfg_hash->{admin_author_id}
        || DEFAULT_ADMIN_AUTHOR_ID;
    if (DEFAULT_ADMIN_AUTHOR_ID == $versions_author_id) {
        my $iter = MT::Author->load_iter ({ is_superuser => 1 })
            or return; # not found superuser
        my $superuser = $iter->()
            or return;
                $versions_author_id = $superuser->id;
    }

    # Check author's permission for blog
    my $permission = MT::Permission->load ({
            blog_id => $versions_blog_id,
            author_id => $versions_author_id })
        or return; # not found permission
    $permission->can_post
        or return; # no permission

    # Make sure that parameters are safe
    my $stored_versions_number = int ($cfg_hash->{stored_versions_number} || 0);
    $stored_versions_number = REVISIONS_STORED_MIN
        if $stored_versions_number < REVISIONS_STORED_MIN;
    $stored_versions_number = REVISIONS_STORED_MAX
        if $stored_versions_number > REVISIONS_STORED_MAX;

    # Retrieve plugin data of this entry's versions
    my $version_data = get_plugin_data ('versions:'. $entry->id);
    my $versions = $version_data->data || [];
    # Do like as a ring buffer
    my $revised_entry = undef;
    if ($stored_versions_number <= scalar @$versions) {
        my $old_eid = shift @$versions;
        $revised_entry = MT::Entry->load ({ id => $old_eid }); # maybe undef in error
    }
    # Add newly if needs
    $revised_entry ||= MT::Entry->new;
    # Update version entry
    $revised_entry->blog_id ($versions_blog_id);
    $revised_entry->status (MT::Entry::HOLD());
    $revised_entry->author_id ($versions_author_id);
    # Copy properties
    $revised_entry->title ($entry->title);
    $revised_entry->excerpt ($entry->excerpt);
    $revised_entry->text ($entry->text);
    $revised_entry->text_more ($entry->text_more);
    $revised_entry->convert_breaks ($entry->convert_breaks);
    $revised_entry->keywords ($entry->keywords);
    $revised_entry->created_on ($entry->modified_on);
    $revised_entry->save
        or return $eh->error ($revised_entry->errstr);

    # Update PluginData
    push @$versions, $revised_entry->id;
    # Trim versions up to number to store
    while ($stored_versions_number < scalar @$versions) {
        my $version_eid = shift @$versions;
        my $revised_entry = MT::Entry->load ({ id => $version_eid })
            or next;
        $revised_entry->remove;
    }
    # Save
    $version_data->data ($versions);
    $version_data->save
        or return $eh->error ($version_data->errstr);

    MT->instance->log ("$MYNAME: "
            . MT->translate ("Your new entry has been saved to [_1]", "Revision Repository")
            . " (eid = ". $revised_entry->id. ")") if $VERBOSE;
}

### Callback - Remove all versions of removed entry
sub remove_entry_revisions {
    my ($eh, $entry) = @_;

    # Retrieve plugin setting of this entry's blog
    my $version_data = get_plugin_data ('versions:'. $entry->id);
    my $versions = $version_data->data || [];
    scalar @$versions
        or return; # no versions

    # Remove all versions chained to the removed entry
    my @deleted_eid = ();
    foreach my $version_eid (@$versions) {
        my $revised_entry = MT::Entry->load ({ id => $version_eid })
            or next;
        $revised_entry->remove; # not recursive called-back fortunately (^o^)
        push @deleted_eid, $version_eid;
    }

    # Remove also PluginData myself
    $version_data->remove
        or return $eh->error ($version_data->errstr);

    MT->instance->log ("$MYNAME: "
            . MT->translate ("Your entry has been deleted from the database.")
            . " (eid = ". join (',', @deleted_eid). ")") if $VERBOSE;
}



### Template parameters
sub versions_param {
    my ($cb, $app, $param, $template) = @_;
    my $q = $app->{query};
    my $entry_id = $param->{id};

    my $version_data = get_plugin_data ('versions:'. $entry_id);
    my $versions = $version_data->data || [];
    $param->{versions} = [];
    my $count = scalar @$versions;
    foreach my $revised_eid (@$versions) {
        my $revised_entry = MT::Entry->load ({ id => $revised_eid })
            or next;
        my $row_param = {
            entry_id => $revised_entry->id,
            selected => $count == 1 && ! defined $q->param('revised_id'),
            count => --$count,
            created_on => format_ts ("%Y-%m-%d %H:%M:%S", $revised_entry->created_on),
            text_bytes => length $revised_entry->text,
            text_more_bytes => length $revised_entry->text_more,
            excerpt_bytes => length $revised_entry->excerpt,
            keywords_bytes => length $revised_entry->keywords,
            __odd__ => $count % 2,
        };
        # Revised entry is specified. replace the current contents
        if (defined $q->param('revised_id') && $revised_entry->id == $q->param('revised_id')) {
            $param->{title} = $revised_entry->title;
            $param->{excerpt} = $revised_entry->excerpt;
            $param->{text} = $revised_entry->text;
            $param->{text_more} = $revised_entry->text_more;
            $param->{convert_breaks} = $revised_entry->convert_breaks;
            $param->{keywords} = $revised_entry->keywords;
            $param->{revised_created_on} = $row_param->{created_on};
            $row_param->{selected} |= 1;
        }
        unshift @{$param->{versions}}, $row_param;
    }
    $param->{num_versions} = scalar @{$param->{versions}};

    if (0 && open (FH, ">". MT->instance->mt_dir. "/test.txt")) {
        print FH Dumper (MT->instance);
        close FH;
    }

}

### Templates
sub versions_tmpl {
    my ($cb, $app, $template) = @_;

    my %Replaces = (
        'javascript' => sub { my ($t,$o,$n) = @_; $$t =~ s/($o)/$1$n/ },
        'versions-tab' => sub { my ($t,$o,$n) = @_; $$t =~ s/($o)/$n$1/ },
        'versions-panel' => sub { my ($t,$o,$n) = @_; $$t =~ s/($o)/$n$1/ },
        'message' => sub { my ($t,$o,$n) = @_; $$t =~ s/($o)/$n$1/ },
    );
    for my $tmpl (keys %Replaces) {
        my $old_tmpl = quotemeta (load_tmpl ($tmpl, 'old')) or next;
        my $new_tmpl = load_tmpl ($tmpl, 'new') or next;
        $Replaces{$tmpl} ($template, $old_tmpl, $new_tmpl);
    }
    # Translate by my lexicon
    $$template = &instance->translate_templatized ($$template);
}



### Load template piece for handling the templates
sub load_tmpl {
    my ( $file, $type ) = @_;

    my $tmpl = undef;
    my $filepath = MT->instance->mt_dir. '/'. &instance->envelope. "/tmpl/${_tmpl_sufix}/${file}_${type}.tmpl";
    if (open (TMPL_FH, "<$filepath")) {
        do { local $/; $tmpl = <TMPL_FH> };
        close TMPL_FH;
    }
    $tmpl;
}

### Revisions informations are stored in MT::PluginData
sub get_plugin_data {
    my ( $key ) = @_;
    my $plugin_data = MT::PluginData->load ({ plugin => &instance->name, key => $key });
    unless ($plugin_data) {
        $plugin_data = MT::PluginData->new;
        $plugin_data->plugin (&instance->name);
        $plugin_data->key ($key);
    }
    $plugin_data;
}

1;
__END__
