package Protobuf::Attribute::Field::Repeated;
use Moose::Role;

use Moose::Util::TypeConstraints;
use Protobuf::Types;

# 5.8 doesn't have this: -brad
#use namespace::clean -except => 'meta';

with q(Protobuf::Attribute::Field);

before _process_options => sub {
    my ( $class, $name, $options ) = @_;

    $options->{reader}    ||= "${name}s";
    $options->{predicate} ||= "set_$name";
    $options->{default}   ||= sub { [] };

    my $type_constraint = $options->{type_constraint} || $class->field_to_type_constraint($options->{field});

    $options->{type_constraint} = Moose::Meta::TypeConstraint::Parameterized->new(
        name           => 'ArrayRef[' . $type_constraint->name . ']',
        parent         => find_type_constraint('ArrayRef'),
        type_parameter => $type_constraint,
    );
};

after 'install_accessors' => sub {
    my $self = shift;

    my $name = $self->name;

    $self->install_method( "add_$name"    => $self->generate_add_method );
    $self->install_method( "${name}_size" => $self->generate_size_method );
};

sub install_method {
    my ( $self, $name, $body ) = @_;

    my $class = $self->associated_class;

    my $method = Moose::Meta::Method->wrap( $body,
        name         => $name,
        package_name => $class->name,
    );

    $self->associate_method($method);

    $class->add_method($name => $method);
}

sub generate_size_method {
    my $self = shift;
    my $reader = $self->get_read_method_ref->body;
    return sub {
        my $self = shift;
        return scalar @{ $self->$reader() };
    };
}

sub generate_add_method {
    my $self = shift;

    if ( $self->field->is_aggregate ) {
        return $self->generate_aggregate_add_method;
    } else {
        return $self->generate_simple_add_method;
    }
}

sub generate_aggregate_add_method {
    my $self = shift;

    my $reader = $self->get_read_method_ref->body;
    my $item_class = $self->field->message_type->class_name;

    return sub {
        my $self = shift;
        die "not expecting any arguments" if scalar @_;

        my $list = $self->$reader();
        my $instance = $item_class->new;
        push @$list, $instance;
        return $instance;
    };
}

sub generate_simple_add_method {
    my $self = shift;

    my $reader = $self->get_read_method_ref->body;

    return sub {
        my ( $self, $value ) = @_;
        push @{ $self->$reader }, $value;
        return;
    }
}

sub protobuf_emit {
    my ( $self, $instance, $emit ) = @_;

    my $field = $self->field;

    foreach my $value ( @{ $self->get_value($instance) } ) {
        $emit->($field, $value);
    }
}

sub Moose::Meta::Attribute::Custom::Trait::Protobuf::Field::Repeated::register_implementation { __PACKAGE__ }

__PACKAGE__

__END__
