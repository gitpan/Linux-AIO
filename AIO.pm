=head1 NAME

Linux::AIO - linux-specific aio implemented using clone

=head1 SYNOPSIS

 use Linux::AIO;

=head1 DESCRIPTION

This module implements asynchroneous i/o using the means available to
linux - clone. It does not hook into the POSIX aio_* functions because
linux does not yet support these in the kernel. Instead, a number of
threads are started that execute your read/writes and signal their
completion.

=over 4

=cut

package Linux::AIO;

use base 'Exporter';

BEGIN {
   $VERSION = 0.001;

   @EXPORT = qw(aio_read aio_write);
   @EXPORT_OK = qw(poll_fileno poll_cb min_parallel max_parallel nreqs);

   require XSLoader;
   XSLoader::load Linux::AIO, $VERSION;
}

=item Linux::AIO::min_parallel($nthreads)

Set the minimum number of AIO threads to $nthreads. You I<have> to call
this function with a positive number at leats once, otherwise no threads
will be started and you aio-operations will seem to hang.

=cut

=item aio_read($fh,$offset,$length, $data,$dataoffset,$callback)
aio_write($fh,$offset,$length, $data,$dataoffset,$callback)

Reads or writes C<length> bytes from the specified C<fh> and C<offset>
into the scalar given by C<data> and offset C<dataoffset> and calls the
callback without the actual number of bytes read (or undef on error).

=item $fileno = Linux::AIO::poll_fileno

Return the request result pipe filehandle. This filehandle must be polled
for reading. If the pipe becomes readable you have to call C<poll_cb>.

=item Linux::AIO::poll_cb

Process all outstanding events on the result pipe. You have to call this
regularly. Returns the number of events processed.

You can use Event to multiplex, e.g.:

   Event->io(fd => Linux::AIO::poll_fileno,
             poll => 'r', async => 1,
             cb => \&Linux::AIO::poll_cb );


=item Linux::AIO::nreqs

Returns the number of requests currently outstanding.

=cut

END {
   max_parallel 0;
}

1;

=back

=head1 BUGS

This module has not yet been extensively tested. Watch out!

=head1 SEE ALSO

L<Coro>.

=head1 AUTHOR

 Marc Lehmann <pcg@goof.com>
 http://www.goof.com/pcg/marc/

=cut

