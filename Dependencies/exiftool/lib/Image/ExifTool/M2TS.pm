#------------------------------------------------------------------------------
# File:         M2TS.pm
#
# Description:  Read M2TS (AVCHD) meta information
#
# Revisions:    2009/07/03 - P. Harvey Created
#
# References:   1) http://neuron2.net/library/mpeg2/iso13818-1.pdf
#               2) http://www.blu-raydisc.com/Assets/Downloadablefile/BD-RE_Part3_V2.1_WhitePaper_080406-15271.pdf
#               3) http://www.videohelp.com/forum/archive/reading-avchd-playlist-files-bdmv-playlist-mpl-t358888.html
#               4) http://en.wikipedia.org/wiki/MPEG_transport_stream
#               5) http://www.dunod.com/documents/9782100493463/49346_DVB.pdf
#               6) http://trac.handbrake.fr/browser/trunk/libhb/stream.c
#               7) http://ieeexplore.ieee.org/stamp/stamp.jsp?arnumber=04560141
#               8) http://www.w6rz.net/xport.zip
#
# Notes:        Variable names containing underlines are the same as in ref 1.
#
# Glossary:     PES = Packetized Elementary Stream
#               PAT = Program Association Table
#               PMT = Program Map Table
#               PCR = Program Clock Reference
#               PID = Packet Identifier
#
# To Do:        - parse PCR to obtain average bitrates?
#------------------------------------------------------------------------------

package Image::ExifTool::M2TS;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.02';

# program map table "stream_type" lookup (ref 6/1)
my %streamType = (
    0x00 => 'Reserved',
    0x01 => 'MPEG-1 Video',
    0x02 => 'MPEG-2 Video',
    0x03 => 'MPEG-1 Audio',
    0x04 => 'MPEG-2 Audio',
    0x05 => 'ISO 13818-1 private sections',
    0x06 => 'ISO 13818-1 PES private data',
    0x07 => 'ISO 13522 MHEG',
    0x08 => 'ISO 13818-1 DSM-CC',
    0x09 => 'ISO 13818-1 auxiliary',
    0x0A => 'ISO 13818-6 multi-protocol encap',
    0x0B => 'ISO 13818-6 DSM-CC U-N msgs',
    0x0C => 'ISO 13818-6 stream descriptors',
    0x0D => 'ISO 13818-6 sections',
    0x0E => 'ISO 13818-1 auxiliary',
    0x0F => 'MPEG-2 AAC Audio',
    0x10 => 'MPEG-4 Video',
    0x11 => 'MPEG-4 LATM AAC Audio',
    0x12 => 'MPEG-4 generic',
    0x13 => 'ISO 14496-1 SL-packetized',
    0x14 => 'ISO 13818-6 Synchronized Download Protocol',
  # 0x15-0x7F => 'ISO 13818-1 Reserved',
    0x1b => 'H.264 Video',
    0x80 => 'DigiCipher II Video',
    0x81 => 'A52/AC-3 Audio',
    0x82 => 'HDMV DTS Audio',
    0x83 => 'LPCM Audio',
    0x84 => 'SDDS Audio',
    0x85 => 'ATSC Program ID',
    0x86 => 'DTS-HD Audio',
    0x87 => 'E-AC-3 Audio',
    0x8a => 'DTS Audio',
    0x91 => 'A52b/AC-3 Audio',
    0x92 => 'DVD_SPU vls Subtitle',
    0x94 => 'SDDS Audio',
    0xa0 => 'MSCODEC Video',
    0xea => 'Private ES (VC-1)',
  # 0x80-0xFF => 'User Private',
);

# "table_id" values (ref 5)
my %tableID = (
    0x00 => 'Program Association',
    0x01 => 'Conditional Access',
    0x02 => 'Program Map',
    0x03 => 'Transport Stream Description',
    0x40 => 'Actual Network Information',
    0x41 => 'Other Network Information',
    0x42 => 'Actual Service Description',
    0x46 => 'Other Service Description',
    0x4a => 'Bouquet Association',
    0x4e => 'Actual Event Information - Present/Following',
    0x4f => 'Other Event Information - Present/Following',
    0x50 => 'Actual Event Information - Schedule', #(also 0x51-0x5f)
    0x60 => 'Other Event Information - Schedule', # (also 0x61-0x6f)
    0x70 => 'Time/Date',
    0x71 => 'Running Status',
    0x72 => 'Stuffing',
    0x73 => 'Time Offset',
    0x7e => 'Discontinuity Information',
    0x7f => 'Selection Information',
  # 0x80-0xfe => 'User Defined',
);

# PES stream ID's for which a syntax field does not exist
my %noSyntax = (
    0xbc => 1, # program_stream_map
    0xbe => 1, # padding_stream
    0xbf => 1, # private_stream_2
    0xf0 => 1, # ECM_stream
    0xf1 => 1, # EMM_stream
    0xf2 => 1, # DSMCC_stream
    0xf8 => 1, # ITU-T Rec. H.222.1 type E stream
    0xff => 1, # program_stream_directory
);

# information extracted from the MPEG-2 transport stream
%Image::ExifTool::M2TS::Main = (
    GROUPS => { 2 => 'Video' },
    VARS => { NO_ID => 1 },
    NOTES => q{
        The MPEG-2 transport stream is used as a container for many different
        audio/video formats (including AVCHD).  This table represents information
        extracted from the MPEG-2 transport headers.
    },
    VideoStreamType => {
        PrintHex => 1,
        PrintConv => \%streamType,
        SeparateTable => 'StreamType',
    },
    AudioStreamType => {
        PrintHex => 1,
        PrintConv => \%streamType,
        SeparateTable => 'StreamType',
    },
);

# information extracted from H.264 video streams
%Image::ExifTool::M2TS::H264 = (
    GROUPS => { 1 => 'H264', 2 => 'Video' },
    VARS => { NO_ID => 1 },
    NOTES => 'Tags extracted from H.264 video streams.',
    DateTimeOriginal => {
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    ImageWidth => { },
    ImageHeight => { },
);

# information extracted from AC-3 audio streams
%Image::ExifTool::M2TS::AC3 = (
    GROUPS => { 1 => 'AC3', 2 => 'Audio' },
    VARS => { NO_ID => 1 },
    NOTES => 'Tags extracted from AC-3 audio streams.',
    AudioSampleRate => {
        PrintConv => {
            0 => '48000',
            1 => '44100',
            2 => '32000',
        },
    },
    AudioBitrate => {
        PrintConvColumns => 2,
        PrintConv => {
            0 => 32000,
            1 => 40000,
            2 => 48000,
            3 => 56000,
            4 => 64000,
            5 => 80000,
            6 => 96000,
            7 => 112000,
            8 => 128000,
            9 => 160000,
            10 => 192000,
            11 => 224000,
            12 => 256000,
            13 => 320000,
            14 => 384000,
            15 => 448000,
            16 => 512000,
            17 => 576000,
            18 => 640000,
            32 => '32000 max',
            33 => '40000 max',
            34 => '48000 max',
            35 => '56000 max',
            36 => '64000 max',
            37 => '80000 max',
            38 => '96000 max',
            39 => '112000 max',
            40 => '128000 max',
            41 => '160000 max',
            42 => '192000 max',
            43 => '224000 max',
            44 => '256000 max',
            45 => '320000 max',
            46 => '384000 max',
            47 => '448000 max',
            48 => '512000 max',
            49 => '576000 max',
            50 => '640000 max',
        },
    },
    SurroundMode => {
        PrintConv => {
            0 => 'Not indicated',
            1 => 'Not Dolby surround',
            2 => 'Dolby surround',
        },
    },
    AudioChannels => {
        PrintConvColumns => 2,
        PrintConv => {
            0 => '1 + 1',
            1 => 1,
            2 => 2,
            3 => 3,
            4 => '2/1',
            5 => '3/1',
            6 => '2/2',
            7 => '3/2',
            8 => 1,
            9 => '2 max',
            10 => '3 max',
            11 => '4 max',
            12 => '5 max',
            13 => '6 max',
        },
    },
);

#==============================================================================
# Bitstream functions (used for H264 video)
#
# Member variables:
#   Mask    = mask for next bit to read (0 when all data has been read)
#   Pos     = byte offset of next word to read
#   Word    = current data word
#   Len     = total data length in bytes
#   DataPt  = data pointer
#..............................................................................

#------------------------------------------------------------------------------
# Read next word from bitstream
# Inputs: 0) BitStream ref
# Returns: true if there is more data (and updates
#          Mask, Pos and Word for first bit in next word)
sub ReadNextWord($)
{
    my $bstr = shift;
    my $pos = $$bstr{Pos};
    if ($pos + 4 <= $$bstr{Len}) {
        $$bstr{Word} = unpack("x$pos N", ${$$bstr{DataPt}});
        $$bstr{Mask} = 0x80000000;
        $$bstr{Pos} += 4;
    } elsif ($pos < $$bstr{Len}) {
        my @bytes = unpack("x$pos C*", ${$$bstr{DataPt}});
        my ($word, $mask) = (shift(@bytes), 0x80);
        while (@bytes) {
            $word = ($word << 8) | shift(@bytes);
            $mask <<= 8;
        }
        $$bstr{Word} = $word;
        $$bstr{Mask} = $mask;
        $$bstr{Pos} = $$bstr{Len};
    } else {
        return 0;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Create a new BitStream object
# Inputs: 0) data ref
# Returns: BitStream ref, or null if data is empty
sub NewBitStream($)
{
    my $dataPt = shift;
    my $bstr = {
        DataPt => $dataPt,
        Len    => length($$dataPt),
        Pos    => 0,
        Mask   => 0,
    };
    ReadNextWord($bstr) or undef $bstr;
    return $bstr;
}

#------------------------------------------------------------------------------
# Get integer from bitstream
# Inputs: 0) BitStream ref, 1) number of bits
# Returns: integer (and increments position in bitstream)
sub GetIntN($$)
{
    my ($bstr, $bits) = @_;
    my $val = 0;
    while ($bits--) {
        $val <<= 1;
        ++$val if $$bstr{Mask} & $$bstr{Word};
        $$bstr{Mask} >>= 1 and next;
        ReadNextWord($bstr) or last;
    }
    return $val;
}

#------------------------------------------------------------------------------
# Get Exp-Golomb integer from bitstream
# Inputs: 0) BitStream ref
# Returns: integer (and increments position in bitstream)
sub GetGolomb($)
{
    my $bstr = shift;
    # first, count the number of zero bits to get the integer bit width
    my $count = 0;
    until ($$bstr{Mask} & $$bstr{Word}) {
        ++$count;
        $$bstr{Mask} >>= 1 and next;
        ReadNextWord($bstr) or last;
    }
    # then return the adjusted integer
    return GetIntN($bstr, $count + 1) - 1;
}

#------------------------------------------------------------------------------
# Get signed Exp-Golomb integer from bitstream
# Inputs: 0) BitStream ref
# Returns: integer (and increments position in bitstream)
sub GetGolombS($)
{
    my $bstr = shift;
    my $val = GetGolomb($bstr) + 1;
    return ($val & 1) ? -($val >> 1) : ($val >> 1);
}

# end bitstream functions
#==============================================================================

#------------------------------------------------------------------------------
# Decode H.264 scaling matrices
# Inputs: 0) BitStream ref
# Reference: http://ffmpeg.org/
sub DecodeScalingMatrices($)
{
    my $bstr = shift;
    if (GetIntN($bstr, 1)) {
        my ($i, $j);
        for ($i=0; $i<8; ++$i) {
            my $size = $i<6 ? 16 : 64;
            next unless GetIntN($bstr, 1);
            my ($last, $next) = (8, 8);
            for ($j=0; $j<$size; ++$j) {
                $next = ($last + GetGolombS($bstr)) & 0xff if $next;
                last unless $j or $next;
            }
        }
    }
}

#------------------------------------------------------------------------------
# Extract information from H.264 video stream
# Inputs: 0) ExifTool ref, 1) data ref
# References:
#   a) http://www.itu.int/rec/T-REC-H.264/e (T-REC-H.264-200305-S!!PDF-E.pdf)
#   b) http://miffteevee.co.uk/documentation/development/H264Parser_8cpp-source.html
#   c) http://ffmpeg.org/
# Glossary:
#   RBSP = Raw Byte Sequence Payload
sub ParseH264Video($$)
{
    my ($exifTool, $dataPt) = @_;
    my $verbose = $exifTool->Options('Verbose');
    my $out = $exifTool->Options('TextOut');
    my $tagTablePtr = GetTagTable('Image::ExifTool::M2TS::H264');
    my %parseNalUnit = ( 0x06 => 1, 0x07 => 1 );    # NAL unit types to parse
    my $len = length $$dataPt;
    my $pos = 0;
    while ($pos < $len) {
        my ($nextPos, $end);
        # find start of next NAL unit
        if ($$dataPt =~ /(\0{2,3}\x01)/g) {
            $nextPos = pos $$dataPt;
            $end = $nextPos - length $1;
            $pos or $pos = $nextPos, next;
        } else {
            last unless $pos;
            $nextPos = $end = $len;
        }
        last if $pos >= $len;
        # parse NAL unit from $pos to $end
        my $nal_unit_type = Get8u($dataPt, $pos);
        ++$pos;
        # check forbidden_zero_bit
        $nal_unit_type & 0x80 and $exifTool->Warn('H264 forbidden bit error'), last;
        $nal_unit_type &= 0x1f;
        # ignore this NAL unit unless we will parse it
        $parseNalUnit{$nal_unit_type} or $verbose or $pos = $nextPos, next;
        # read NAL unit (and convert all 0x000003's to 0x0000 as per spec.)
        my $buff = '';
        pos($$dataPt) = $pos + 1;
        while ($$dataPt =~ /\0\0\x03/g) {
            last if pos $$dataPt > $end;
            $buff .= substr($$dataPt, $pos, pos($$dataPt)-1-$pos);
            $pos = pos $$dataPt;
        }
        $buff .= substr($$dataPt, $pos, $end - $pos);
        if ($verbose > 1) {
            printf $out "  NAL Unit Type: 0x%x (%d bytes)\n",$nal_unit_type, length $buff;
            my %parms = ( Out => $out );
            $parms{MaxLen} = 96 if $verbose < 4;
            Image::ExifTool::HexDump(\$buff, undef, %parms) if $verbose > 2;
        }
        pos($$dataPt) = $pos = $nextPos;

        if ($nal_unit_type == 0x06) {       # sei_rbsp (supplemental enhancement info)

            # brute force scan for DateTimeOriginal (for now)
            next unless $buff =~ /MDPM...(.{8})/s;
            my $val = unpack('H*', $1);
            if ($val =~ /^(\d{2})(\d{2})(\d{2})..(\d{2})(\d{2})(\d{2})(\d{2})$/s) {
                $exifTool->HandleTag($tagTablePtr, DateTimeOriginal => "$1$2:$3:$4 $5:$6:$7");
            }

        } elsif ($nal_unit_type == 0x07) {  # sequence_parameter_set_rbsp

            # initialize our bitstream object
            my $bstr = NewBitStream(\$buff) or next;
            my ($t, $i, $n);
            # the messy nature of H.264 encoding makes it difficult to use
            # data-driven structure parsing, so I code it explicitely (yuck!)
            $t = GetIntN($bstr, 8);         # profile_idc
            GetIntN($bstr, 16);             # constraints and level_idc
            GetGolomb($bstr);               # seq_parameter_set_id
            if ($t >= 100) { # (ref b)
                $t = GetGolomb($bstr);      # chroma_format_idc
                if ($t == 3) {
                    GetIntN($bstr, 1);      # separate_colour_plane_flag
                    $n = 12;
                } else {
                    $n = 8;
                }
                GetGolomb($bstr);           # bit_depth_luma_minus8
                GetGolomb($bstr);           # bit_depth_chroma_minus8
                GetIntN($bstr, 1);          # qpprime_y_zero_transform_bypass_flag
                DecodeScalingMatrices($bstr);
            }
            GetGolomb($bstr);               # log2_max_frame_num_minus4
            $t = GetGolomb($bstr);          # pic_order_cnt_type
            if ($t == 0) {
                GetGolomb($bstr);           # log2_max_pic_order_cnt_lsb_minus4
            } elsif ($t == 1) {
                GetIntN($bstr, 1);          # delta_pic_order_always_zero_flag
                GetGolomb($bstr);           # offset_for_non_ref_pic
                GetGolomb($bstr);           # offset_for_top_to_bottom_field
                $n = GetGolomb($bstr);      # num_ref_frames_in_pic_order_cnt_cycle
                for ($i=0; $i<$n; ++$i) {
                    GetGolomb($bstr);       # offset_for_ref_frame[i]
                }
            }
            GetGolomb($bstr);               # num_ref_frames
            GetIntN($bstr, 1);              # gaps_in_frame_num_value_allowed_flag
            my $w = GetGolomb($bstr);       # pic_width_in_mbs_minus1
            my $h = GetGolomb($bstr);       # pic_height_in_map_units_minus1
            my $f = GetIntN($bstr, 1);      # frame_mbs_only_flag
            $f or GetIntN($bstr, 1);        # mb_adaptive_frame_field_flag
            GetIntN($bstr, 1);              # direct_8x8_inference_flag
            # convert image size to pixels
            $w = ($w + 1) * 16;
            $h = (2 - $f) * ($h + 1) * 16;
            # account for cropping (if any)
            $t = GetIntN($bstr, 1);         # frame_cropping_flag
            if ($t) {
                my $m = 4 - $f * 2;
                $w -=  4 * GetGolomb($bstr);# frame_crop_left_offset
                $w -=  4 * GetGolomb($bstr);# frame_crop_right_offset
                $h -= $m * GetGolomb($bstr);# frame_crop_top_offset
                $h -= $m * GetGolomb($bstr);# frame_crop_bottom_offset
            }
            # quick validity check (just in case)
            if ($w>=160 and $w<=4096 and $h>=120 and $h<=3072) {
                $exifTool->HandleTag($tagTablePtr, ImageWidth => $w);
                $exifTool->HandleTag($tagTablePtr, ImageHeight => $h);
            }
            # (whew! -- so much work just to get ImageSize!!)
        }
        # we were successful, so don't parse this NAL unit type again
        delete $parseNalUnit{$nal_unit_type};
    }
}

#------------------------------------------------------------------------------
# Extract information from AC-3 audio stream
# Inputs: 0) ExifTool ref, 1) data ref
# Reference: http://www.atsc.org/standards/a_52b.pdf
sub ParseAC3Audio($$)
{
    my ($exifTool, $dataPt) = @_;
    if ($$dataPt =~ /\x0b\x77..(.)/sg) {
        my $sampleRate = ord($1) >> 6;
        my $tagTablePtr = GetTagTable('Image::ExifTool::M2TS::AC3');
        $exifTool->HandleTag($tagTablePtr, AudioSampleRate => $sampleRate);
    }
}

#------------------------------------------------------------------------------
# Extract information from AC-3 stream descriptor
# Inputs: 0) ExifTool ref, 1) data ref
# Reference: http://www.atsc.org/standards/a_52b.pdf
# Note: This information is duplicated in the Audio stream, but it
#       is somewhat easier to extract it from the descriptor instead
sub ParseAC3Descriptor($$)
{
    my ($exifTool, $dataPt) = @_;
    return if length $$dataPt < 3;
    my @v = unpack('C3', $$dataPt);
    my $tagTablePtr = GetTagTable('Image::ExifTool::M2TS::AC3');
    # $exifTool->HandleTag($tagTablePtr, 'AudioSampleRate', $v[0] >> 5);
    $exifTool->HandleTag($tagTablePtr, 'AudioBitrate', $v[1] >> 2);
    $exifTool->HandleTag($tagTablePtr, 'SurroundMode', $v[1] & 0x03);
    $exifTool->HandleTag($tagTablePtr, 'AudioChannels', ($v[2] >> 1) & 0x0f);
    # don't (yet) decode any more (language codes, etc)
}

#------------------------------------------------------------------------------
# Extract information from a M2TS file
# Inputs: 0) ExifTool object reference, 1) DirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid M2TS file
sub ProcessM2TS($$)
{
    my ($exifTool, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $plen, $i, $j, $fileType);
    my (%pmt, %pidType, %didPID, %data, %sectLen);
    my $verbose = $exifTool->Options('Verbose');
    my $out = $exifTool->Options('TextOut');

    # read first packet
    return 0 unless $raf->Read($buff, 8) == 8;
    # test for magic number (sync byte is the only thing we can safely check)
    return 0 unless $buff =~ /^(....)?\x47/s;
    unless ($1) {
        $plen = 188;        # no timecode
        $fileType = 'M2T';  # (just as a way to tell there is no timecode)
    } else {
        $plen = 192; # 188-byte transport packet + leading 4-byte timecode (ref 4)
    }
    $exifTool->SetFileType($fileType);
    SetByteOrder('MM');
    $raf->Seek(0,0);        # rewind to start
    my $tagTablePtr = GetTagTable('Image::ExifTool::M2TS::Main');

    # PID lookup strings (will add to this with entries from program map table)
    my %pidString = (
        0 => 'Program Association Table',
        1 => 'Conditional Access Table',
        2 => 'Transport Stream Description Table',
        0x1fff => 'Null Packet',
    );
    my %needPID = ( 0x00 => 1 );    # lookup for stream PID's that we still need to parse

    # parse packets from MPEG-2 Transport Stream
    for ($i=0; %needPID; ++$i) {

        # read the next packet
        last unless $raf->Read($buff, $plen) == $plen;
        # decode the packet prefix
        my $pos = length($buff) - 188;
        my $prefix = Get32u(\$buff, $pos);
        $pos += 4;
        # validate sync byte
        unless (($prefix & 0xff000000) >> 24 == 0x47) {
            $exifTool->Warn('Synchronization error');
            last;
        }
      # my $transport_error_indicator    = $prefix & 0x00800000;
        my $payload_unit_start_indicator = $prefix & 0x00400000;
      # my $transport_priority           = $prefix & 0x00200000;
        my $pid                          =($prefix & 0x001fff00) >> 8; # packet ID
      # my $transport_scrambling_control = $prefix & 0x000000c0;
        my $adaptation_field_exists      = $prefix & 0x00000020;
        my $payload_data_exists          = $prefix & 0x00000010;
      # my $continuity_counter           = $prefix & 0x0000000f;

        if ($verbose > 1) {
            print  $out "Transport packet $i:\n";
            Image::ExifTool::HexDump(\$buff, undef, Addr => $i * $plen, Out => $out) if $verbose > 2;
            my $str = $pidString{$pid} ? " ($pidString{$pid})" : '';
            printf $out "  Timecode:   0x%.4x\n", Get32u(\$buff, 0) if $plen == 192;
            printf $out "  Packet ID:  0x%.4x$str\n", $pid;
            printf $out "  Start Flag: %s\n", $payload_unit_start_indicator ? 'Yes' : 'No';
        }

        # skip adaptation field
        if ($adaptation_field_exists) {
            $pos += 1 + Get8u(\$buff, $pos);
            $pos > $plen and $exifTool->Warn('Invalid adaptation field length'), last;
        }

        # all done with this packet unless it carries a payload
        next unless $payload_data_exists;

        # decode payload data
        if ($pid == 0 or            # program association table
            defined $pmt{$pid})     # program map table(s)
        {
            # must interpret pointer field if payload_unit_start_indicator is set
            if ($payload_unit_start_indicator) {
                # skip to start of section
                my $pointer_field = Get8u(\$buff, $pos);
                $pos += 1 + $pointer_field;
                $pos >= $plen and $exifTool->Warn('Bad pointer field'), last;
            } else {
                # not the start of a section
                next unless $sectLen{$pid};
                my $more = $sectLen{$pid} - length($data{$pid});
                my $size = length($buff) - $pos;
                $size = $more if $size > $more;
                $data{$pid} .= substr($buff, $pos, $size);
                next unless $size == $more;
                # we have the complete section now, so put back into $buff for parsing
                $buff = $data{$pid};
                $pos = 0;
                delete $data{$pid};
                delete $sectLen{$pid};
            }
            my $slen = length($buff);   # section length
            $pos + 8 > $slen and $exifTool->Warn("Truncated payload"), last;
            # validate table ID
            my $table_id = Get8u(\$buff, $pos);
            my $name = ($tableID{$table_id} || sprintf('Unknown (0x%x)',$table_id)) . ' Table';
            my $expectedID = $pid ? 0x02 : 0x00;
            unless ($table_id == $expectedID) {
                $verbose > 1 and printf $out "  (skipping $name)\n";
                delete $needPID{$pid};
                $didPID{$pid} = 1;
                next;
            }
            # validate section syntax indicator for parsed tables (PAT, PMT)
            my $section_syntax_indicator = Get8u(\$buff, $pos + 1) & 0xc0;
            $section_syntax_indicator == 0x80 or $exifTool->Warn("Bad $name"), last;
            my $section_length = Get16u(\$buff, $pos + 1) & 0x0fff;
            $section_length > 1021 and $exifTool->Warn("Invalid $name length"), last;
            if ($slen < $section_length + 3) { # (3 bytes for table_id + section_length)
                # must wait until we have the full section
                $data{$pid} = substr($buff, $pos);
                $sectLen{$pid} = $section_length + 3;
                next;
            }
            my $program_number = Get16u(\$buff, $pos + 3);
            my $section_number = Get8u(\$buff, $pos + 6);
            my $last_section_number = Get8u(\$buff, $pos + 7);
            if ($verbose > 1) {
                print  $out "  $name length: $section_length\n";
                print  $out "  Program No: $program_number\n" if $pid;
                printf $out "  Stream ID:  0x%x\n", $program_number if not $pid;
                print  $out "  Section No: $section_number\n";
                print  $out "  Last Sect.: $last_section_number\n";
            }
            my $end = $pos + $section_length + 3 - 4; # (don't read 4-byte CRC)
            $pos += 8;
            if ($pid == 0) {
                # decode PAT (Program Association Table)
                while ($pos <= $end - 4) {
                    my $program_number = Get16u(\$buff, $pos);
                    my $program_map_PID = Get16u(\$buff, $pos + 2) & 0x1fff;
                    $pmt{$program_map_PID} = $program_number; # save our PMT PID's
                    if (not $pidString{$program_map_PID} or $verbose > 1) {
                        my $str = "Program $program_number Map";
                        $pidString{$program_map_PID} = $str;
                        $needPID{$program_map_PID} = 1 unless $didPID{$program_map_PID};
                        $verbose and printf $out "  PID(0x%.4x) --> $str\n", $program_map_PID;
                    }
                    $pos += 4;
                }
            } else {
                # decode PMT (Program Map Table)
                $pos + 4 > $slen and $exifTool->Warn('Truncated PMT'), last;
                my $pcr_pid = Get16u(\$buff, $pos) & 0x1fff;
                my $program_info_length = Get16u(\$buff, $pos + 2) & 0x0fff;
                if (not $pidString{$pcr_pid} or $verbose > 1) {
                    my $str = "Program $program_number Clock Reference";
                    $pidString{$pcr_pid} = $str;
                    $verbose and printf $out "  PID(0x%.4x) --> $str\n", $pcr_pid;
                }
                $pos += 4;
                $pos + $program_info_length > $slen and $exifTool->Warn('Truncated program info'), last;
                # dump program information descriptors if verbose
                if ($verbose > 1) { for ($j=0; $j<$program_info_length-2; ) {
                    my $descriptor_tag = Get8u(\$buff, $pos + $j);
                    my $descriptor_length = Get8u(\$buff, $pos + $j + 1);
                    $j += 2;
                    last if $j + $descriptor_length > $program_info_length;
                    my $desc = substr($buff, $pos+$j, $descriptor_length);
                    $j += $descriptor_length;
                    $desc =~ s/([\x00-\x1f\x80-\xff])/sprintf("\\x%.2x",ord $1)/eg;
                    printf $out "    Program Descriptor: Type=0x%.2x \"$desc\"\n", $descriptor_tag;
                }}
                $pos += $program_info_length; # skip descriptors (for now)
                while ($pos <= $end - 5) {
                    my $stream_type = Get8u(\$buff, $pos);
                    my $elementary_pid = Get16u(\$buff, $pos + 1) & 0x1fff;
                    my $es_info_length = Get16u(\$buff, $pos + 3) & 0x0fff;
                    if (not $pidString{$elementary_pid} or $verbose > 1) {
                        my $str = $streamType{$stream_type};
                        $str or $str = ($stream_type < 0x7f ? 'Reserved' : 'Private');
                        $str = sprintf('%s (0x%.2x)', $str, $stream_type);
                        $str = "Program $program_number $str";
                        $pidString{$elementary_pid} = $str;
                        $pidType{$elementary_pid} = $stream_type;
                        $verbose and printf $out "  PID(0x%.4x) --> $str\n", $elementary_pid;
                        if ($str =~ /(Audio|Video)/) {
                            $exifTool->HandleTag($tagTablePtr, $1 . 'StreamType', $stream_type);
                            # we want to parse all Audio and Video streams
                            $needPID{$elementary_pid} = 1 unless $didPID{$elementary_pid};
                        }
                    }
                    $pos += 5;
                    $pos + $es_info_length > $slen and $exifTool->Warn('Trunacted ES info'), $pos = $end, last;
                    # parse elementary stream descriptors
                    for ($j=0; $j<$es_info_length-2; ) {
                        my $descriptor_tag = Get8u(\$buff, $pos + $j);
                        my $descriptor_length = Get8u(\$buff, $pos + $j + 1);
                        $j += 2;
                        last if $j + $descriptor_length > $es_info_length;
                        my $desc = substr($buff, $pos+$j, $descriptor_length);
                        $j += $descriptor_length;
                        if ($verbose > 1) {
                            my $dstr = $desc;
                            $dstr =~ s/([\x00-\x1f\x80-\xff])/sprintf("\\x%.2x",ord $1)/eg;
                            printf $out "    ES Descriptor: Type=0x%.2x \"$dstr\"\n", $descriptor_tag;
                        }
                        # parse type-specific descriptor information (once)
                        unless ($didPID{$pid}) {
                            if ($descriptor_tag == 0x81) {  # AC-3
                                ParseAC3Descriptor($exifTool, \$desc);
                            }
                        }
                    }
                    $pos += $es_info_length;
                }
            }
            $pos = $end + 4; # skip CRC
        } elsif ($pid == 1) {       # conditional access table
        } elsif ($pid == 2) {       # transport stream description table
        } elsif ($pid == 0x1fff) {  # null packet
        } elsif (not $didPID{$pid}) {
            # save data from the start of each elementary stream
            if ($payload_unit_start_indicator) {
                if (defined $data{$pid}) {
                    # we must have a whole section
                    delete $needPID{$pid};
                    $didPID{$pid} = 1;
                    next;
                }
                # check for a PES header
                next if $pos + 6 > $plen;
                my $start_code = Get32u(\$buff, $pos);
                next unless ($start_code & 0xffffff00) == 0x00000100;
                my $stream_id = $start_code & 0xff;
                if ($verbose > 1) {
                    my $pes_packet_length = Get16u(\$buff, $pos + 4);
                    printf $out "  Stream ID:  0x%.2x\n", $stream_id;
                    print  $out "  Packet Len: $pes_packet_length\n";
                }
                $pos += 6;
                unless ($noSyntax{$stream_id}) {
                    next if $pos + 3 > $plen;
                    # validate PES syntax
                    my $syntax = Get8u(\$buff, $pos) & 0xc0;
                    $syntax == 0x80 or $exifTool->Warn('Bad PES syntax'), next;
                    # skip PES header
                    my $pes_header_data_length = Get8u(\$buff, $pos + 2);
                    $pos += 3 + $pes_header_data_length;
                    next if $pos >= $plen;
                }
                $data{$pid} = substr($buff, $pos);
            } else {
                # accumulate first 2kB of data for each elementary stream
                $data{$pid} .= substr($buff, $pos) if defined $data{$pid};
            }
            # save the 256 bytes of most streams, except for unknown or H.264
            # streams where we take the first 1 kB
            my $saveLen = (not $pidType{$pid} or $pidType{$pid} == 0x1b) ? 1024 : 256;
            if (length($data{$pid}) >= $saveLen) {
                delete $needPID{$pid};
                $didPID{$pid} = 1;
            }
            next;
        }
        if ($needPID{$pid}) {
            # we found and parsed a section with this PID, so
            # delete from the lookup of PID's we still need to parse
            delete $needPID{$pid};
            $didPID{$pid} = 1;
        }
    }

    if ($verbose) {
        if (%needPID) {
            my @list = sort map(sprintf("0x%.2x",$_), keys %needPID);
            print $out "End of file.  Missing PID(s): @list\n";
        } else {
            print $out "End scan.  All PID's parsed.\n";
        }
    }

    # parse header from recognized audio/video streams
    my $pid;
    foreach $pid (sort keys %data) {
        my $type = $pidType{$pid} or next;
        my $dataPt = \$data{$pid};
        if ($verbose > 1) {
            printf $out "Parsing stream 0x%.4x (%s)\n", $pid, $pidString{$pid};
            my %parms = ( Out => $out );
            $parms{MaxLen} = 96 if $verbose < 4;
            Image::ExifTool::HexDump(\$data{$pid}, undef, %parms) if $verbose > 2;
        }
        if ($type == 0x01 or $type == 0x02) {
            # MPEG-1/MPEG-2 Video
            require Image::ExifTool::MPEG;
            Image::ExifTool::MPEG::ParseMPEGAudioVideo($exifTool, $dataPt);
        } elsif ($type == 0x03 or $type == 0x04) {
            # MPEG-1/MPEG-2 Audio
            require Image::ExifTool::MPEG;
            Image::ExifTool::MPEG::ParseMPEGAudio($exifTool, $dataPt);
        } elsif ($type == 0x1b) {
            # H.264 Video
            ParseH264Video($exifTool, $dataPt);
        } elsif ($type == 0x81 or $type == 0x87 or $type == 0x91) {
            # AC-3 audio
            ParseAC3Audio($exifTool, $dataPt);
        }
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::M2TS - Read M2TS (AVCHD) meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to extract
information from MPEG-2 transport streams, such as those used by AVCHD
video.

=head1 AUTHOR

Copyright 2003-2009, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://neuron2.net/library/mpeg2/iso13818-1.pdf>

=item L<http://www.blu-raydisc.com/Assets/Downloadablefile/BD-RE_Part3_V2.1_WhitePaper_080406-15271.pdf>

=item L<http://www.videohelp.com/forum/archive/reading-avchd-playlist-files-bdmv-playlist-mpl-t358888.html>

=item L<http://en.wikipedia.org/wiki/MPEG_transport_stream>

=item L<http://www.dunod.com/documents/9782100493463/49346_DVB.pdf>

=item L<http://trac.handbrake.fr/browser/trunk/libhb/stream.c>

=item L<http://ieeexplore.ieee.org/stamp/stamp.jsp?arnumber=04560141>

=item L<http://www.w6rz.net/xport.zip>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/M2TS Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

