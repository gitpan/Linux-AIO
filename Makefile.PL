use ExtUtils::MakeMaker;

my $mm = MM->new({
    dist         => {
       PREOP	=> 'pod2text AIO.pm | tee README >$(DISTVNAME)/README; chmod -R u=rwX,go=rX . ;',
       COMPRESS	=> 'gzip -9v',
       SUFFIX	=> '.gz',
	            },
    NAME         => "Linux::AIO",
    VERSION_FROM => "AIO.pm",
});

sub MY::postamble {
   <<EOF;

# set \$VERSION in all modules
setver:
	\$(PERL) -pi -e 's/^(\\s*\\\$\$VERSION\\s*=\\s*).*\$\$/\$\${1}\$(VERSION);/' *.pm Coro/*.pm

EOF
}

# now get rid of -fpic, because gcc can't use syscall'ed closures
# from within pic code.
for ($mm->{CCDLFLAGS}, $mm->{CCCDLFLAGS}, @{$mm->{RESULT}}) {
   s/\B-f(pic|PIC)\b//g
}

$mm->flush;

