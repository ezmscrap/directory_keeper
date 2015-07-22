#!/user/bin/perl

use strict;
use warnings;
use Digest::MD5;
use IO::File;
use IO::Dir;
use YAML::XS;
use Archive::Zip;
use File::Basename;

my %info=(	config => "config.cfg");

&main(\%info);
exit;

# ■主処理
sub main {
	my $info=shift;
	&get_directorys($info);
	&duplicate_file_exclusion($info);
}

# ■指定した設定ファイルから処理対象ディレクトリを取得
sub get_directorys{
	my $info=shift;
	$info->{'config'} = YAML::XS::LoadFile($info->{'config'});
	test_print_directorys($info);
}

# ■処理対象ディレクトリすべてに対して再帰的に子ディレクトリを呼び出して処理
sub duplicate_file_exclusion{
	my $info=shift;
	my $directorys=$info->{'config'}->{'directorys'};
	foreach my $directory (@$directorys){
		recursive_directory_loop($info,\$directory);
	}
}

# ■再帰的にディレクトリをたどる
sub recursive_directory_loop{
	my ($info,$dir)=@_;
	return unless -d ${$dir};
	&find_overlap_file_in_directory($info,$dir);
	my $dir_handle= IO::Dir->new(${$dir}) or die $!;
	while( defined ( my $path = $dir_handle->read)){
		next if(("." eq $path)||(".." eq $path));
		my $next_dir=${$dir}."\\".$path;
		next unless -d $next_dir;
		recursive_directory_loop($info,\$next_dir);
	}
	$dir_handle->close;
}

# ■処理対象ディレクトリの中のファイルに対して重複判定
sub find_overlap_file_in_directory{
	my ($info,$dir)=@_;
	my $dir_handle= IO::Dir->new(${$dir}) or die $!;
	while( defined ( my $file = $dir_handle->read)){
		my $path = ${$dir}."\\".$file;
		next unless -f $path;
		&check_overlap($info,\$path);
	}
	$dir_handle->close;
}

# ■処理対象ファイルに対して重複判定して処理呼び出し
sub check_overlap{
	my ($info,$file)=@_;
	my $file_handle= IO::File->new(${$file}) or die $!;
	my $md5=Digest::MD5->new->addfile($file_handle)->hexdigest;
	$file_handle->close;
	if(exists($info->{$md5})){
		find_overlap($info,$file);
	}else{
		unfind_overlap($info,$file,\$md5);
	}
}

# ■処理対象ファイルが重複ファイルだった時の動き
sub find_overlap{
	my ($info,$file)=@_;
	do_remove($file);
}

# ■処理対象ファイルが未重複ファイルだった時の動き
sub unfind_overlap{
	my ($info,$file,$md5)=@_;
	$info->{${$md5}}=${$file};
	&zip_rename($info,$file) if(${$file} =~ /\.zip$/);
}

# ■zipファイルを必要なら名前変更する
sub zip_rename{
	my ($info,$file)=@_;
#print "in zip_rename\n";
	my $dir_name_in_zip = &get_dir_name_in_zip($file);
	return if("" eq $dir_name_in_zip);
#print "get dir_name_in_zip: $dir_name_in_zip\n";
	my $new_file_name = &get_new_file_name ($file, \$dir_name_in_zip);
	return if(-e $new_file_name);
#print "get new_file_name: $new_file_name\n";
	&do_rename(\$new_file_name,$file);
}

# ■zipの中からディレクトリ名を取得
sub get_dir_name_in_zip(){
	my $file=shift;
	my $zip_first_menber = &get_first_menber_in_zip($file);
	if($zip_first_menber =~ m|(?:.+/+)*(.+)(/[^/]*)$|){
		return $1;
	}
	return "";
}

# ■zipの先頭要素取り出し
sub get_first_menber_in_zip{
	my $file=shift;
	my $zip = Archive::Zip->new(${$file});
	my @zip_menbers=$zip->memberNames();
	return $zip_menbers[0];
}

# ■今のファイル名から変更後のファイル名を生成
sub get_new_file_name{
	my ($file,$dir_name_in_zip)=@_;
	return File::Basename::dirname(${$file})."\\".${$dir_name_in_zip}."\.zip";
}

# ■変更先ファイル名と同じファイルがなければ、ファイル名を変更
sub do_rename{
	my ($newfile,$file)=@_;
	rename(${$file},${$newfile}) or die "It failed to change the name.\n";
	&test_print_renamefile($newfile,$file);
}

# ■変更したファイルを出力
sub test_print_renamefile{
	my ($newfile,$file)=@_;
	print "rename,",${$file},",",${$newfile},"\n";
}

# ■変更先ファイル名と同じファイルがなければ、ファイル名を変更
sub do_remove{
	my ($file)=@_;
	unlink(${$file}) or die "It failed to remove file.\n";
	&test_print_remove($file);
}

# ■削除したファイルを出力
sub test_print_remove{
	my ($file)=@_;
	print "remove,",${$file},"\n";
}

# ■コンフィグファイルから取得したディレクトリリスト表示
sub test_print_directorys{
	my $info=shift;
	my $directorys=$info->{'config'}->{'directorys'};
	print "<<Test Print Directorys>>\n";
	foreach my $dir (@$directorys){
		print $dir,"\n";
	}
	print "#----------------------------------------------------------------------\n";
}
1;
