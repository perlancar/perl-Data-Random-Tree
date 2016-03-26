package Data::Random::Tree;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Exporter::Rinci qw(import);

our %SPEC;

$SPEC{create_random_tree} = {
    v => 1.1,
    summary => 'Create random tree',
    description => <<'_',

This routine creates a random tree object. You need to supply at least one node
class. A node class is a class that at least must have these attributes:
`parent`, `children`. See `Role::TinyCommons::Tree::Node` if you want to use a
role to enforce this for your class.

TODO: allow specifying minimum/maximum number of objects (per-level).

TODO: allow specifying minimum/maximum level.

TODO: allow varying the number of children of each node.

TODO: allow customize distribution of class instances (e.g. root node up until
level 3 should only be C1 nodes, and so on).

TODO: Allow setting node attributes with random values (without having the user
use `code_instantiate_node`).

_
    args => {
        num_objects_per_level => {
            schema => ['array*', of=>['int*', min=>1], min_len=>0],
            req => 1,
            summary => 'Number of objects per level',
            description => <<'_',

This argument specifies number of objects per level and should be an array. The
first element of the array corresponds to the total number of children nodes
below the root node (i.e. the total number of objects at level 1), the second
element of the array corresponds to the total number of all that children's
children (i.e. the total number of objects at level 2, *not* the number of
children for each children), and so on.

_
        },
        classes => {
            schema => ['array*', of=>['str*'], min_len=>1],
            req => 1,
            summary => 'Class(es) to use to instantiate node objects',
            description => <<'_',

Node will be created from a random pick of this list of classes. If you only
supply one class, then all nodes will be of that class.

_
        },
        code_instantiate_node => {
            schema => 'code*',
            description => <<'_',

By default, node object will be created with:

    $class->new()

you can customize this by providing a routine to instantiate the node. The code will receive:

    ($class, $level, $parent)

where `$class` is the class name (your code can of course create node using any
class you want), `$level` is the current level (0 for root node, 1 for its
children, and so on), `$parent` is the parent node object. The code should
return the node object.

Your code need not set the node's `parent()`, connecting parent and children
nodes will be performed by this routine.

Example:

    sub {
        ($class, $level, $parent) = @_;
        $class->new( attr => 10*rand );
    }

_
        },
        # XXX {min,max}_objects, {min,max}_objects_per_level
        # XXX {min,max}_levels
    },
    result_naked => 1,
};
sub create_random_tree {
    my %args = @_;

    my $nobj_per_level = $args{num_objects_per_level}
        or die "Please specify 'num_objects_per_level'";

    my $classes    = $args{classes} or die "Please specify 'classes'";
    my $code_class = sub { $classes->[@$classes * rand()] };

    my $code_inst0 = $args{code_instantiate_node};
    my $code_inst  = sub {
        my ($level, $parent) = @_;
        my $node;
        if ($code_inst0) {
            $node = $code_inst0->($code_class->(), $level);
        } else {
            $node = $code_class->()->new();
        }
        # connect node with its parent
        $node->parent($parent) if $parent;
        $node;
    };

    my $root = $code_inst->(0, undef);

    my @parents = ($root);
    for my $level (1 .. @$nobj_per_level) {
        my $nobj = $nobj_per_level->[$level-1];
        my @children; # key = index parent, val = [child, ...]
        for my $i (1..$nobj) {
            my $parent_idx = int(($i-1)/$nobj * @parents);
            my $parent = $parents[$parent_idx];
            $children[$parent_idx] //= [];
            my $child = $code_inst->($level, $parent);
            push @{ $children[$parent_idx] }, $child;
        }
        # connect parent with its children
        for my $i (0..$#parents) {
            $parents[$i]->children($children[$i]);
        }

        @parents = map { @{ $children[$_] // [] } } 0..$#parents;
    }

    $root;
}

1;
# ABSTRACT:

=head1 SYNOPSIS

 use Data::Random::Tree qw(create_random_tree);
 use MyNode;
 use MyOtherNode;

 my $tree = create_random_tree(
     num_objects_per_level => [100, 3000, 5000, 8000, 3000, 1000, 300],
     classes => ['MyNode', 'MyOtherNode'],
     # optional
     #code_instantiate_node => sub {
     #    my ($class, $level, $parent) = @_;
     #    $class->new(...);
     #},
 );


=head1 SEE ALSO

L<Role::TinyCommons::Tree::Node>

Other C<Data::Random::*> modules.

L<Tree::FromStruct>
