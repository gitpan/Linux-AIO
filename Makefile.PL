use ExtUtils::MakeMaker;

use Config;

$Config{ccsymbols} =~ /__i386=1/ or print <<EOF;

WARNING: This module is architecture-dependent and currently only works on
         little-endian 32-bit architectures. If the module (esp. aio_read
         and aio_write) doesn't work, please report this and I'll fix it
         for you. I promise ;)

EOF

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
	\$(PERL) -pi -e 's/^(\\s*\\\$\$VERSION\\s*=\\s*).*\$\$/\$\${1}\$(VERSION);/' *.pm

EOF
}

# now get rid of -fpic, because gcc can't use syscall'ed closures
# from within pic code.
for ($mm->{CCDLFLAGS}, $mm->{CCCDLFLAGS}, @{$mm->{RESULT}}) {
   s/\B-f(pic|PIC)\b//g
}

$mm->flush;

