=info
    523066680/vicyang
    2018-12
=cut

use utf8;
use Encode;
use File::Path;
use File::Slurp;
use File::Copy;
use Data::Dumper;
use Storable;
$Data::Dumper::Indent = 1;
STDOUT->autoflush(1);

my $src = encode('gbk', "E:\\Company\\S烧录程序_软件");
my $spec = encode('gbk', "烧录");  # target folder name
my $dst;
my $drv;
my $hash = {};

$drv = find_target_drive( $spec );
if ( defined $drv ) {
    $dst = "${drv}:\\${spec}";
} else {
    printf "Target not found\n";
    exit;
}

my $dbfile = "${drv}:\\tree.db";

if (-e $dbfile) {
   $hash = retrieve($dbfile);
} else {
    build_tree( $dst, $hash );
    store($hash, $dbfile);
}

#print Dumper $hash;
sync_files();
update_db($hash, $dbfile);
printf "Done\n";

sub sync_files
{
    my $s = `dir /s /b $src`;
    my $src_path;
    my $hash_path;
    open my $fh, "<:raw", \$s; 
    while ($src_path = <$fh>)
    {
        $src_path =~s/\r?\n$//;
        $src_path =~/\Q${src}\E(.*)$/;
        $dst_path ="${dst}$1";
        $hash_path="Root$1";
        $res = check( $hash_path, $hash, $src_path, $dst_path );
    }
    close $fh;
}

sub check
{
    my ($path, $ref, $src_path, $dst_path) = @_;
    my @parts = split(/[\/\\]/, $path);

    for my $e ( @parts )
    {
        if ( exists $ref->{$e} ) {
            $ref = $ref->{$e};
        } else {
            if ( -d $src_path ) 
            {
                mkpath $dst_path or die "mkpath error\n";
                $ref->{$e} = {}; #create key if success
                printf "%s\n", $dst_path;
            } 
            elsif ( -f $src_path)
            {
                copy $src_path, $dst_path or die "copy file error\n";
                $ref->{$e} = {}; #create key if success
                printf "%s\n", $dst_path;
            }
            else 
            {
                printf "Something wrong? %s\n", $src_path;
            }
        }
    }
    return 1;
}

# 遍历文件列表，构建哈希树
sub build_tree
{
    my ($wdir, $ref) = @_;
    print "Loading Directory Content ...\n";
    my $s = `dir /s /b $wdir`;
    # string as file stream
    open my $fh, "<:raw", \$s; 
    while ($line = <$fh>)
    {
        $line =~s/\r?\n$//;
        $line =~s/\Q${wdir}\E/Root/;
        to_hash( $line, $ref );
    }
    close $fh;
}

# path to hash key
sub to_hash
{
    my ($path, $ref) = @_;
    my @parts = split(/[\/\\]/, $path);
    for my $e ( @parts )
    {
        $ref->{$e} = {} unless exists $ref->{$e};
        $ref = $ref->{$e};
    }
}

sub find_target_drive
{
    my ($spec) = @_;
    my $drv;
    grep { $drv = $_ if (-e "${_}:\\${spec}") } ('D'..'Z');
    return $drv;
}

sub update_db
{
    my ($hash, $dbfile) = @_;
    store($hash, $dbfile);
}