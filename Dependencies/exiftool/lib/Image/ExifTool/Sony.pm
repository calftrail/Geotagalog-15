#------------------------------------------------------------------------------
# File:         Sony.pm
#
# Description:  Sony EXIF Maker Notes tags
#
# Revisions:    04/06/2004  - P. Harvey Created
#
# References:   1) http://www.cybercom.net/~dcoffin/dcraw/
#               2) http://homepage3.nifty.com/kamisaka/makernote/makernote_sony.htm (2006/08/06)
#               3) Thomas Bodenmann private communication
#               4) Philippe Devaux private communication (A700)
#               5) Marcus Holland-Moritz private communication (A700)
#               6) Andrey Tverdokhleb private communication
#               7) Rudiger Lange private communication (A700)
#               8) Igal Milchtaich private communication
#               JD) Jens Duttke private communication
#------------------------------------------------------------------------------

package Image::ExifTool::Sony;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;
use Image::ExifTool::Minolta;

$VERSION = '1.36';

sub ProcessSRF($$$);
sub ProcessSR2($$$);

my %sonyLensTypes;  # filled in based on Minolta LensType's

%Image::ExifTool::Sony::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0102 => { #5/JD
        Name => 'Quality',
        Writable => 'int32u',
        PrintConv => {
            0 => 'RAW',
            1 => 'Super Fine',
            2 => 'Fine',
            3 => 'Standard',
            4 => 'Economy',
            5 => 'Extra Fine',
            6 => 'RAW + JPEG',
            7 => 'Compressed RAW',
            8 => 'Compressed RAW + JPEG',
        },
    },
    0x0104 => { #5/JD
        Name => 'FlashExposureComp',
        Description => 'Flash Exposure Compensation',
        Writable => 'rational64s',
    },
    0x0105 => { #5/JD
        Name => 'Teleconverter',
        Writable => 'int32u',
        PrintHex => 1,
        PrintConv => {
            0 => 'None',
            72 => 'Minolta AF 2x APO (D)',
            80 => 'Minolta AF 2x APO II',
            136 => 'Minolta AF 1.4x APO (D)',
            144 => 'Minolta AF 1.4x APO II',
        },
    },
    0x0112 => { #JD
        Name => 'WhiteBalanceFineTune',
        Format => 'int32s',
        Writable => 'int32u',
    },
    0x0114 => [ #PH
        {
            Name => 'CameraSettings',
            Condition => '$$self{Model} =~ /DSLR-A(200|230|300|350|700|850|900)\b/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Sony::CameraSettings',
                ByteOrder => 'BigEndian',
            },
        },
        {
            Name => 'CameraSettings2',
            Condition => '$$self{Model} =~ /DSLR-A(330|380)\b/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Sony::CameraSettings2',
                ByteOrder => 'BigEndian',
            },
        },
        {
            Name => 'CameraSettingsUnknown',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Sony::CameraSettingsUnknown',
                ByteOrder => 'BigEndian',
            },
        },
    ],
    0x0115 => { #JD
        Name => 'WhiteBalance',
        Writable => 'int32u',
        PrintHex => 1,
        PrintConv => {
            0x00 => 'Auto',
            0x01 => 'Color Temperature/Color Filter',
            0x10 => 'Daylight',
            0x20 => 'Cloudy',
            0x30 => 'Shade',
            0x40 => 'Tungsten',
            0x50 => 'Flash',
            0x60 => 'Fluorescent',
            0x70 => 'Custom',
        },
    },
    0x0e00 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
        },
    },
    0x2001 => { #PH (All DSLR's except the A100)
        Name => 'PreviewImage',
        Writable => 'undef',
        DataTag => 'PreviewImage',
        # Note: the preview data starts with a 32-byte proprietary Sony header
        WriteCheck => 'return $val=~/^(none|.{32}\xff\xd8\xff)/s ? undef : "Not a valid image"',
        RawConv => q{
            return \$val if $val =~ /^Binary/;
            $val = substr($val,0x20) if length($val) > 0x20;
            return \$val if $val =~ s/^.(\xd8\xff\xdb)/\xff$1/s;
            $$self{PreviewError} = 1 unless $val eq 'none';
            return undef;
        },
        # must construct 0x20-byte header which contains length, width and height
        ValueConvInv => q{
            return 'none' unless $val;
            my $e = new Image::ExifTool;
            my $info = $e->ImageInfo(\$val,'ImageWidth','ImageHeight');
            return undef unless $$info{ImageWidth} and $$info{ImageHeight};
            my $size = Set32u($$info{ImageWidth}) . Set32u($$info{ImageHeight});
            return Set32u(length $val) . $size . ("\0" x 8) . $size . ("\0" x 4) . $val;
        },
    },
    0x200a => { #PH (A550)
        Name => 'AutoHDR',
        Writable => 'int32u',
        PrintHex => 1,
        PrintConv => {
            0x0 => 'Off',
            0x10001 => 'On',
        },
    },
    0x3000 => {
        Name => 'ShotInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Sony::ShotInfo',
        },
    },
    # 0x3000: data block that includes DateTimeOriginal string
    0xb000 => { #8
        Name => 'FileFormat',
        Writable => 'int8u',
        Count => 4,
        PrintConv => {
            '0 0 0 2' => 'JPEG',
            '1 0 0 0' => 'SR2',
            '2 0 0 0' => 'ARW 1.0',
            '3 0 0 0' => 'ARW 2.0',
            '3 1 0 0' => 'ARW 2.1',
            # what about cRAW images?
        },
    },
    0xb001 => { # ref http://forums.dpreview.com/forums/read.asp?forum=1037&message=33609644
        # (ARW and SR2 images only)
        Name => 'SonyModelID',
        Writable => 'int16u',
        PrintConvColumns => 2,
        PrintConv => {
            2 => 'DSC-R1',
            256 => 'DSLR-A100',
            257 => 'DSLR-A900',
            258 => 'DSLR-A700',
            259 => 'DSLR-A200',
            260 => 'DSLR-A350',
            261 => 'DSLR-A300',
            263 => 'DSLR-A380',
            264 => 'DSLR-A330',
            265 => 'DSLR-A230',
            269 => 'DSLR-A850',
            273 => 'DSLR-A550',
        },
    },
    0xb020 => { #2
        Name => 'ColorReproduction',
        # observed values: None, Standard, Vivid, Real, AdobeRGB - PH
        Writable => 'string',
    },
    0xb021 => { #2
        Name => 'ColorTemperature',
        Writable => 'int32u',
        PrintConv => '$val ? $val : "Auto"',
        PrintConvInv => '$val=~/Auto/i ? 0 : $val',
    },
    0xb022 => { #7
        Name => 'ColorCompensationFilter',
        Format => 'int32s',
        Writable => 'int32u',
        Notes => 'negative is green, positive is magenta',
    },
    0xb023 => { #PH (A100) - (set by mode dial)
        Name => 'SceneMode',
        Writable => 'int32u',
        PrintConv => \%Image::ExifTool::Minolta::minoltaSceneMode,
    },
    0xb024 => { #PH (A100)
        Name => 'ZoneMatching',
        Writable => 'int32u',
        PrintConv => {
            0 => 'ISO Setting Used',
            1 => 'High Key',
            2 => 'Low Key',
        },
    },
    0xb025 => { #PH (A100)
        Name => 'DynamicRangeOptimizer',
        Writable => 'int32u',
        PrintConv => {
            0 => 'Off',
            1 => 'Standard',
            2 => 'Advanced Auto',
            3 => 'Auto', #PH (A550)
            8 => 'Advanced Lv1', #JD
            9 => 'Advanced Lv2', #JD
            10 => 'Advanced Lv3', #JD
            11 => 'Advanced Lv4', #JD
            12 => 'Advanced Lv5', #JD
        },
    },
    0xb026 => { #PH (A100)
        Name => 'ImageStabilization',
        Writable => 'int32u',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0xb027 => { #2
        Name => 'LensType',
        Writable => 'int32u',
        Notes => q{
            decimal values differentiate lenses which would otherwise have the same
            LensType, and are used by the Composite LensID tag when attempting to
            identify the specific lens model.  "New" or "II" appear in brackets if the
            original version of the lens has the same LensType
        },
        PrintConv => \%sonyLensTypes,
    },
    0xb028 => { #2
        # (used by the DSLR-A100)
        Name => 'MinoltaMakerNote',
        # must check for zero since apparently a value of zero indicates the IFD doesn't exist
        # (dumb Sony -- they shouldn't write this tag if the IFD is missing!)
        Condition => '$$valPt ne "\0\0\0\0"',
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Minolta::Main',
            Start => '$val',
        },
    },
    0xb029 => { #2 (set by creative style menu)
        Name => 'ColorMode',
        Writable => 'int32u',
        PrintConv => \%Image::ExifTool::Minolta::sonyColorMode,
    },
    0xb02b => { #PH (A550 JPEG, A230 and A900 ARW)
        Name => 'FullImageSize',
        Writable => 'int32u',
        Count => 2,
        # values stored height first, so swap to get "width height"
        ValueConv => 'join(" ", reverse split(" ", $val))',
        ValueConvInv => 'join(" ", reverse split(" ", $val))',
        PrintConv => '$val =~ tr/ /x/; $val',
        PrintConvInv => '$val =~ tr/x/ /; $val',
    },
    0xb02c => { #PH (A550 JPEG, A230 and A900 ARW)
        Name => 'PreviewImageSize',
        Writable => 'int32u',
        Count => 2,
        ValueConv => 'join(" ", reverse split(" ", $val))',
        ValueConvInv => 'join(" ", reverse split(" ", $val))',
        PrintConv => '$val =~ tr/ /x/; $val',
        PrintConvInv => '$val =~ tr/x/ /; $val',
    },
    0xb040 => { #2
        Name => 'Macro',
        Writable => 'int16u',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0xb041 => { #2
        Name => 'ExposureMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Auto',
            1 => 'Portrait', #PH (HX1)
            5 => 'Landscape',
            6 => 'Program',
            7 => 'Aperture Priority',
            8 => 'Shutter Priority',
            9 => 'Night Scene',
            15 => 'Manual',
            34 => 'Panorama', #PH (HX1)
            35 => 'Handheld Twilight', #PH (HX1/TX1)
            36 => 'Anti Motion Blur', #PH (TX1)
        },
    },
    # 0xb043 - some sort of mode: values - 0,1,2,3,4,15(face detect?),65535
    0xb047 => { #2
        Name => 'Quality',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Normal',
            1 => 'Fine',
        },
    },
    0xb04b => { #2/PH
        Name => 'Anti-Blur',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'On (Continuous)', #PH (NC)
            2 => 'On (Shooting)', #PH (NC)
            65535 => 'n/a',
        },
    },
    0xb04e => { #2
        Name => 'LongExposureNoiseReduction',
        Writable => 'int16u',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0xb04f => { #PH (TX1)
        Name => 'DynamicRangeOptimizer',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'Standard',
            2 => 'Plus',
        },
    },
    0xb052 => { #PH (TX1)
        Name => 'IntelligentAuto',
        Writable => 'int16u',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0xb054 => { #PH (TX1)
        Name => 'WhiteBalance',
        Writable => 'int16u',
        Priority => 0, # (until more values are filled in)
        PrintConv => {
            0 => 'Auto',
            4 => 'Manual',
            5 => 'Daylight',
            14 => 'Incandescent',
        },
    },
);

# Camera settings (ref PH) (decoded mainly from A200)
%Image::ExifTool::Sony::CameraSettings = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    FORMAT => 'int16u',
    NOTES => q{
        Camera settings for the A200, A230, A300, A350, A700, A850 and A900.  Some
        tags are only valid for certain models.
    },
    0x04 => { #7 (A700, not valid for other models)
        Name => 'DriveMode',
        Condition => '$$self{Model} =~ /DSLR-A700\b/',
        Notes => 'A700 only',
        PrintConv => {
            1 => 'Single Frame',
            2 => 'Continuous High',
            4 => 'Self-timer 10 sec',
            5 => 'Self-timer 2 sec',
            7 => 'Continuous Bracketing',
            12 => 'Continuous Low',
            18 => 'White Balance Bracketing Low',
            19 => 'D-Range Optimizer Bracketing Low',
        },
    },
    0x06 => { #7 (A700, not valid for other models)
        Name => 'WhiteBalanceFineTune',
        Condition => '$$self{Model} =~ /DSLR-A700\b/',
        Format => 'int16s',
        Notes => 'A700 only',
    },
    0x10 => { #7 (A700, not confirmed for other models)
        Name => 'FocusMode',
        PrintConv => {
            0 => 'Manual',
            1 => 'AF-S',
            2 => 'AF-C',
            3 => 'AF-A',
        },
    },
    0x11 => { #JD (A700)
        Name => 'AFAreaMode',
        PrintConv => {
            0 => 'Wide',
            1 => 'Local',
            2 => 'Spot',
        },
    },
    0x12 => { #7 (A700, not confirmed for other models)
        Name => 'LocalAFAreaPoint',
        Format => 'int16u',
        Condition => '$$self{Model} !~ /DSLR-A230/',
        PrintConv => {
            1 => 'Center',
            2 => 'Top',
            3 => 'Top-Right',
            4 => 'Right',
            5 => 'Bottom-Right',
            6 => 'Bottom',
            7 => 'Bottom-Left',
            8 => 'Left',
            9 => 'Top-Left',
            10 => 'Far Right',
            11 => 'Far Left',
            # see value of 128 for A230
        },
    },
    0x15 => { #7
        Name => 'MeteringMode',
        Condition => '$$self{Model} !~ /DSLR-A230/',
        PrintConv => {
            1 => 'Multi-segment',
            2 => 'Center-weighted Average',
            4 => 'Spot',
        },
    },
    0x16 => {
        Name => 'ISOSetting',
        Condition => '$$self{Model} !~ /DSLR-A230/',
        # 0 indicates 'Auto' (I think)
        ValueConv => '$val ? exp(($val/8-6)*log(2))*100 : $val',
        ValueConvInv => '$val ? 8*(log($val/100)/log(2)+6) : $val',
        PrintConv => '$val ? sprintf("%.0f",$val) : "Auto"',
        PrintConvInv => '$val =~ /auto/i ? 0 : $val',
    },
    0x18 => { #7
        Name => 'DynamicRangeOptimizerMode',
        Condition => '$$self{Model} !~ /DSLR-A230/',
        PrintConv => {
            0 => 'Off',
            1 => 'Standard',
            2 => 'Advanced Auto',
            3 => 'Advanced Level',
            4097 => 'Auto', #PH (A550)
        },
    },
    0x19 => { #7
        Name => 'DynamicRangeOptimizerLevel',
        Condition => '$$self{Model} !~ /DSLR-A230/',
    },
    0x1a => { # style actually used (combination of mode dial + creative style menu)
        Name => 'CreativeStyle',
        Condition => '$$self{Model} !~ /DSLR-A230/',
        PrintConv => {
            1 => 'Standard',
            2 => 'Vivid',
            3 => 'Portrait',
            4 => 'Landscape',
            5 => 'Sunset',
            6 => 'Night View/Portrait',
            8 => 'B&W',
            9 => 'Adobe RGB', # A900
            11 => 'Neutral',
            12 => 'Clear', #7
            13 => 'Deep', #7
            14 => 'Light', #7
            15 => 'Autumn', #7
            16 => 'Sepia', #7
        },
    },
    0x1c => {
        Name => 'Sharpness',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x1d => {
        Name => 'Contrast',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x1e => {
        Name => 'Saturation',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x1f => { #7
        Name => 'ZoneMatchingValue',
        Condition => '$$self{Model} !~ /DSLR-A230/',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x22 => { #7
        Name => 'Brightness',
        Condition => '$$self{Model} !~ /DSLR-A230/',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x23 => {
        Name => 'FlashMode',
        PrintConv => {
            0 => 'ADI',
            1 => 'TTL',
        },
    },
    0x28 => { #7
        Name => 'PrioritySetupShutterRelease',
        Condition => '$$self{Model} =~ /DSLR-A700\b/',
        Notes => 'A700 only',
        PrintConv => {
            0 => 'AF',
            1 => 'Release',
        },
    },
    0x29 => { #7
        Name => 'AFIlluminator',
        Condition => '$$self{Model} =~ /DSLR-A700\b/',
        Notes => 'A700 only',
        PrintConv => {
            0 => 'Auto',
            1 => 'Off',
        },
    },
    0x2a => { #7
        Name => 'AFWithShutter',
        Condition => '$$self{Model} =~ /DSLR-A700\b/',
        Notes => 'A700 only',
        PrintConv => { 0 => 'On', 1 => 'Off' },
    },
    0x2b => { #7
        Name => 'LongExposureNoiseReduction',
        Condition => '$$self{Model} =~ /DSLR-A700\b/',
        Notes => 'A700 only',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x2c => { #7
        Name => 'HighISONoiseReduction',
        Condition => '$$self{Model} =~ /DSLR-A700\b/',
        Notes => 'A700 only',
        0 => 'Normal',
        1 => 'Low',
        2 => 'High',
        3 => 'Off',
    },
    0x2d => { #7
        Name => 'ImageStyle',
        Condition => '$$self{Model} =~ /DSLR-A700\b/',
        Notes => 'A700 only',
        PrintConv => {
            1 => 'Standard',
            2 => 'Vivid',
            9 => 'Adobe RGB',
            11 => 'Neutral',
            129 => 'StyleBox1',
            130 => 'StyleBox2',
            131 => 'StyleBox3',
        },
    },
    # 0x2d - A900:1=?,4=?,129=std,130=vivid,131=neutral,132=portrait,133=landscape,134=b&w
    0x3c => {
        Name => 'ExposureProgram',
        Priority => 0,
        PrintConv => {
            0 => 'Auto', # (same as 'Program AE'?)
            1 => 'Manual',
            2 => 'Program AE',
            3 => 'Aperture-priority AE',
            4 => 'Shutter speed priority AE',
            8 => 'Program Shift A', #7
            9 => 'Program Shift S', #7
            16 => 'Portrait',
        },
    },
    0x3d => {
        Name => 'ImageStabilization',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x3f => { # (verified for A330/A380)
        Name => 'Rotation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW', #(NC)
            2 => 'Rotate 270 CW',
        },
    },
    0x54 => {
        Name => 'SonyImageSize',
        PrintConv => {
            1 => 'Large',
            2 => 'Medium',
            3 => 'Small',
        },
    },
    0x55 => { #7
        Name => 'AspectRatio',
        PrintConv => {
            1 => '3:2',
            2 => '16:9',
        },
    },
    0x56 => { #PH/7
        Name => 'Quality',
        PrintConv => {
            0 => 'RAW',
            2 => 'CRAW',
            34 => 'RAW + JPEG',
            35 => 'CRAW + JPEG',
            16 => 'Extra Fine',
            32 => 'Fine',
            48 => 'Standard',
        },
    },
    0x58 => { #7
        Name => 'ExposureLevelIncrements',
        PrintConv => {
            33 => '1/3 EV',
            50 => '1/2 EV',
        },
    },            
);

# Camera settings (ref PH) (A330 and A380)
%Image::ExifTool::Sony::CameraSettings2 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    FORMAT => 'int16u',
    NOTES => 'Camera settings for the A330 and A380.',
    0x10 => { #7 (A700, not confirmed for other models)
        Name => 'FocusMode',
        PrintConv => {
            0 => 'Manual',
            1 => 'AF-S',
            2 => 'AF-C',
            3 => 'AF-A',
        },
    },
    0x11 => { #JD (A700)
        Name => 'AFAreaMode',
        PrintConv => {
            0 => 'Wide',
            1 => 'Local',
            2 => 'Spot',
        },
    },
    0x12 => { #7 (A700, not confirmed for other models)
        Name => 'LocalAFAreaPoint',
        Format => 'int16u',
        PrintConv => {
            1 => 'Center',
            2 => 'Top',
            3 => 'Top-Right',
            4 => 'Right',
            5 => 'Bottom-Right',
            6 => 'Bottom',
            7 => 'Bottom-Left',
            8 => 'Left',
            9 => 'Top-Left',
            10 => 'Far Right',
            11 => 'Far Left',
            # see value of 128 for some models
        },
    },
    0x13 => {
        Name => 'MeteringMode',
        PrintConv => {
            1 => 'Multi-segment',
            2 => 'Center-weighted Average',
            4 => 'Spot',
        },
    },
    0x14 => { # A330/A380
        Name => 'ISOSetting',
        # 0 indicates 'Auto' (?)
        ValueConv => '$val ? exp(($val/8-6)*log(2))*100 : $val',
        ValueConvInv => '$val ? 8*(log($val/100)/log(2)+6) : $val',
        PrintConv => '$val ? sprintf("%.0f",$val) : "Auto"',
        PrintConvInv => '$val =~ /auto/i ? 0 : $val',
    },
    0x16 => {
        Name => 'DynamicRangeOptimizerMode',
        PrintConv => {
            0 => 'Off',
            1 => 'Standard',
            2 => 'Advanced Auto',
            3 => 'Advanced Level',
        },
    },
    0x17 => {
        Name => 'DynamicRangeOptimizerLevel',
    },
    0x18 => { # A380
        Name => 'CreativeStyle',
        PrintConv => {
            1 => 'Standard',
            2 => 'Vivid',
            3 => 'Portrait',
            4 => 'Landscape',
            5 => 'Sunset',
            6 => 'Night View/Portrait',
            8 => 'B&W',
            9 => 'Adobe RGB',
            11 => 'Neutral',
        },
    },
    0x19 => {
        Name => 'Sharpness',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x1a => {
        Name => 'Contrast',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x1b => {
        Name => 'Saturation',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x23 => {
        Name => 'FlashMode',
        PrintConv => {
            0 => 'ADI',
            1 => 'TTL',
        },
    },
    # 0x27 - also related to CreativeStyle:
    #  A380:1=std,2=vivid,3=portrait,4=landscape,5=sunset,7=night view,8=b&w
    0x3c => {
        Name => 'ExposureProgram',
        Priority => 0,
        PrintConv => {
            0 => 'Auto', # (same as 'Program AE'?)
            1 => 'Manual',
            2 => 'Program AE',
            3 => 'Aperture-priority AE',
            4 => 'Shutter speed priority AE',
            16 => 'Portrait',
        },
    },
    0x3f => { # (verified for A330/A380)
        Name => 'Rotation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW', #(NC)
            2 => 'Rotate 270 CW',
        },
    },
    0x54 => {
        Name => 'SonyImageSize',
        PrintConv => {
            1 => 'Large',
            2 => 'Medium',
            3 => 'Small',
        },
    },
    # 0x56 - something to do with JPEG quality?
);

# Camera settings for other models
%Image::ExifTool::Sony::CameraSettingsUnknown = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    FORMAT => 'int16u',
);

# shot information (ref PH)
%Image::ExifTool::Sony::ShotInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    # 0 - byte order 'II'
    6 => {
        Name => 'SonyDateTime',
        Format => 'string[20]',
    },
    #52 => {
    #    # values: 'DC6303320222000' or 'DC5303320222000'
    #    Name => 'UnknownString',
    #    Format => 'string[16]',
    #    Unknown => 1,
    #},
);

# tag table for Sony RAW Format
%Image::ExifTool::Sony::SRF = (
    PROCESS_PROC => \&ProcessSRF,
    GROUPS => { 0 => 'MakerNotes', 1 => 'SRF#', 2 => 'Camera' },
    NOTES => q{
        The maker notes in SRF (Sony Raw Format) images contain 7 IFD's (with family
        1 group names SRF0 through SRF6).  SRF0 through SRF5 use these Sony tags,
        while SRF6 uses standard EXIF tags.  All information other than SRF0 is
        encrypted, but thanks to Dave Coffin the decryption algorithm is known. SRF
        images are written by the Sony DSC-F828 and DSC-V3.
    },
    0 => {
        Name => 'SRF2_Key',
        Notes => 'key to decrypt maker notes from the start of SRF2',
        RawConv => '$self->{SRF2_Key} = $val',
    },
    1 => {
        Name => 'DataKey',
        Notes => 'key to decrypt the rest of the file from the end of the maker notes',
        RawConv => '$self->{SRFDataKey} = $val',
    },
);

# tag table for Sony RAW 2 Format Private IFD (ref 1)
%Image::ExifTool::Sony::SR2Private = (
    PROCESS_PROC => \&ProcessSR2,
    GROUPS => { 0 => 'MakerNotes', 1 => 'SR2', 2 => 'Camera' },
    NOTES => q{
        The SR2 format uses the DNGPrivateData tag to reference a private IFD
        containing these tags.  SR2 images are written by the Sony DSC-R1.
    },
    0x7200 => {
        Name => 'SR2SubIFDOffset',
        # (adjusting offset messes up calculations for AdobeSR2 in DNG images)
        # Flags => 'IsOffset',
        OffsetPair => 0x7201,
        RawConv => '$self->{SR2SubIFDOffset} = $val',
    },
    0x7201 => {
        Name => 'SR2SubIFDLength',
        OffsetPair => 0x7200,
        RawConv => '$self->{SR2SubIFDLength} = $val',
    },
    0x7221 => {
        Name => 'SR2SubIFDKey',
        Format => 'int32u',
        Notes => 'key to decrypt SR2SubIFD',
        RawConv => '$self->{SR2SubIFDKey} = $val',
    },
    0x7250 => { #1
        Name => 'MRWInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::MinoltaRaw::Main',
        },
    },
);

%Image::ExifTool::Sony::SR2SubIFD = (
    GROUPS => { 0 => 'MakerNotes', 1 => 'SR2SubIFD', 2 => 'Camera' },
    SET_GROUP1 => 1, # set group1 name to directory name for all tags in table
    NOTES => 'Tags in the encrypted SR2SubIFD',
    0x7303 => 'WB_GRBGLevels', #1
    0x74c0 => { #PH
        Name => 'SR2DataIFD',
        Groups => { 1 => 'SR2DataIFD' }, # (needed to set SubIFD DirName)
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Sony::SR2DataIFD',
            Start => '$val',
            MaxSubdirs => 20, # an A700 ARW has 14 of these! - PH
        },
    },
    0x7313 => 'WB_RGGBLevels', #6
    0x74a0 => 'MaxApertureAtMaxFocal', #PH
    0x74a1 => 'MaxApertureAtMinFocal', #PH
    0x7820 => 'WB_RGBLevelsDaylight', #6
    0x7821 => 'WB_RGBLevelsCloudy', #6
    0x7822 => 'WB_RGBLevelsTungsten', #6
    0x7825 => 'WB_RGBLevelsShade', #6
    0x7826 => 'WB_RGBLevelsFluorescent', #6
    0x7828 => 'WB_RGBLevelsFlash', #6
);

%Image::ExifTool::Sony::SR2DataIFD = (
    GROUPS => { 0 => 'MakerNotes', 1 => 'SR2DataIFD', 2 => 'Camera' },
    SET_GROUP1 => 1, # set group1 name to directory name for all tags in table
    # 0x7313 => 'WB_RGGBLevels', (duplicated in all SR2DataIFD's)
    0x7770 => { #PH
        Name => 'ColorMode',
        Priority => 0,
    },
);

# fill in Sony LensType lookup based on Minolta values
{
    %sonyLensTypes = %Image::ExifTool::Minolta::minoltaLensTypes;
    my $id;
    foreach $id (sort { $a <=> $b } keys %Image::ExifTool::Minolta::minoltaLensTypes) {
        # higher numbered lenses are missing last digit of ID for some Sony models
        next if $id < 10000;
        my $sid = int($id/10);
        my $i;
        my $lens = $Image::ExifTool::Minolta::minoltaLensTypes{$id};
        if ($sonyLensTypes{$sid}) {
            # put lens name with "or" first in list
            if ($lens =~ / or /) {
                my $tmp = $sonyLensTypes{$sid};
                $sonyLensTypes{$sid} = $lens;
                $lens = $tmp;
            }
            for (;;) {
                $i = ($i || 0) + 1;
                $sid = int($id/10) . ".$i";
                last unless $sonyLensTypes{$sid};
            }
        }
        $sonyLensTypes{$sid} = $lens;
    }
}

#------------------------------------------------------------------------------
# decrypt Sony data (ref 1)
# Inputs: 0) data reference, 1) start offset, 2) data length, 3) decryption key
# Returns: nothing (original data buffer is updated with decrypted data)
sub Decrypt($$$$)
{
    my ($dataPt, $start, $len, $key) = @_;
    my ($i, $j, @pad);
    my $words = $len / 4;

    for ($i=0; $i<4; ++$i) {
        my $lo = ($key & 0xffff) * 0x0edd + 1;
        my $hi = ($key >> 16) * 0x0edd + ($key & 0xffff) * 0x02e9 + ($lo >> 16);
        $pad[$i] = $key = (($hi & 0xffff) << 16) + ($lo & 0xffff);
    }
    $pad[3] = ($pad[3] << 1 | ($pad[0]^$pad[2]) >> 31) & 0xffffffff;
    for ($i=4; $i<0x7f; ++$i) {
        $pad[$i] = (($pad[$i-4]^$pad[$i-2]) << 1 |
                    ($pad[$i-3]^$pad[$i-1]) >> 31) & 0xffffffff;
    }
    my @data = unpack("x$start N$words", $$dataPt);
    for ($i=0x7f,$j=0; $j<$words; ++$i,++$j) {
        $data[$j] ^= $pad[$i & 0x7f] = $pad[($i+1) & 0x7f] ^ $pad[($i+65) & 0x7f];
    }
    substr($$dataPt, $start, $words*4) = pack('N*', @data);
}

#------------------------------------------------------------------------------
# Process SRF maker notes
# Inputs: 0) ExifTool object reference, 1) reference to directory information
#         2) pointer to tag table
# Returns: 1 on success
sub ProcessSRF($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = $$dirInfo{DirLen};
    my $start = $$dirInfo{DirStart};
    my $verbose = $exifTool->Options('Verbose');

    # process IFD chain
    my ($ifd, $success);
    for ($ifd=0; ; ) {
        my $srf = $$dirInfo{DirName} = "SRF$ifd";
        my $srfTable = $tagTablePtr;
        # SRF6 uses standard EXIF tags
        $srfTable = GetTagTable('Image::ExifTool::Exif::Main') if $ifd == 6;
        $exifTool->{SET_GROUP1} = $srf;
        $success = Image::ExifTool::Exif::ProcessExif($exifTool, $dirInfo, $srfTable);
        delete $exifTool->{SET_GROUP1};
        last unless $success;
#
# get pointer to next IFD
#
        my $count = Get16u($dataPt, $$dirInfo{DirStart});
        my $dirEnd = $$dirInfo{DirStart} + 2 + $count * 12;
        last if $dirEnd + 4 > length($$dataPt);
        my $nextIFD = Get32u($dataPt, $dirEnd);
        last unless $nextIFD;
        $nextIFD -= $$dirInfo{DataPos}; # adjust for position of makernotes data
        $$dirInfo{DirStart} = $nextIFD;
#
# decrypt next IFD data if necessary
#
        ++$ifd;
        my ($key, $len);
        if ($ifd == 1) {
            # get the key to decrypt IFD1
            my $cp = $start + 0x8ddc;    # why?
            my $ip = $cp + 4 * unpack("x$cp C", $$dataPt);
            $key = unpack("x$ip N", $$dataPt);
            $len = $cp + $nextIFD;  # decrypt up to $cp
        } elsif ($ifd == 2) {
            # get the key to decrypt IFD2
            $key = $exifTool->{SRF2_Key};
            $len = length($$dataPt) - $nextIFD; # decrypt rest of maker notes
        } else {
            next;   # no decryption needed
        }
        # decrypt data
        Decrypt($dataPt, $nextIFD, $len, $key) if defined $key;
        next unless $verbose > 2;
        # display decrypted data in verbose mode
        $exifTool->VerboseDir("Decrypted SRF$ifd", 0, $nextIFD + $len);
        $exifTool->VerboseDump($dataPt,
            Prefix => "$exifTool->{INDENT}  ",
            Start => $nextIFD,
            DataPos => $$dirInfo{DataPos},
        );
    }
}

#------------------------------------------------------------------------------
# Process SR2 data
# Inputs: 0) ExifTool object reference, 1) reference to directory information
#         2) pointer to tag table
# Returns: 1 on success
sub ProcessSR2($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $raf = $$dirInfo{RAF};
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos};
    my $dataLen = $$dirInfo{DataLen} || length $$dataPt;
    my $base = $$dirInfo{Base} || 0;

    # make sure we have the first 4 bytes available to test directory type
    my $buff;
    if ($dataLen < 4 and $raf) {
        my $pos = $dataPos + ($$dirInfo{DirStart}||0) + $base;
        if ($raf->Seek($pos, 0) and $raf->Read($buff, 4) == 4) {
            $dataPt = \$buff;
            undef $$dirInfo{DataPt};    # must load data from file
            $raf->Seek($pos, 0);
        }
    }
    # this may either be a normal IFD, or a MRW-file-like data block in newer ARW images
    if ($dataPt and $$dataPt =~ /^\0MR[IM]/) {
        require Image::ExifTool::MinoltaRaw;
        return Image::ExifTool::MinoltaRaw::ProcessMRW($exifTool, $dirInfo);
    }
    my $dirLen = $$dirInfo{DirLen};
    my $verbose = $exifTool->Options('Verbose');
    my $result = Image::ExifTool::Exif::ProcessExif($exifTool, $dirInfo, $tagTablePtr);
    return $result unless $result;
    # only take first offset value if more than one!
    my @offsets = split ' ', $exifTool->{SR2SubIFDOffset};
    my $offset = shift @offsets;
    my $length = $exifTool->{SR2SubIFDLength};
    my $key = $exifTool->{SR2SubIFDKey};
    if ($offset and $length and defined $key) {
        my $buff;
        # read encrypted SR2SubIFD from file
        if (($raf and $raf->Seek($offset+$base, 0) and
                $raf->Read($buff, $length) == $length) or
            # or read from data (when processing Adobe DNGPrivateData)
            ($offset - $dataPos >= 0 and $offset - $dataPos + $length < $dataLen and
                ($buff = substr($$dataPt, $offset - $dataPos, $length))))
        {
            Decrypt(\$buff, 0, $length, $key);
            # display decrypted data in verbose mode
            if ($verbose > 2) {
                $exifTool->VerboseDir("Decrypted SR2SubIFD", 0, $length);
                $exifTool->VerboseDump(\$buff, Addr => $offset + $base);
            }
            my $num = '';
            my $dPos = $offset;
            for (;;) {
                my %dirInfo = (
                    Base => $base,
                    DataPt => \$buff,
                    DataLen => length $buff,
                    DirStart => $offset - $dPos,
                    DirName => "SR2SubIFD$num",
                    DataPos => $dPos,
                );
                my $subTable = GetTagTable('Image::ExifTool::Sony::SR2SubIFD');
                $result = $exifTool->ProcessDirectory(\%dirInfo, $subTable);
                last unless @offsets;
                $offset = shift @offsets;
                $num = ($num || 1) + 1;
            }

        } else {
            $exifTool->Warn('Error reading SR2 data');
        }
    }
    delete $exifTool->{SR2SubIFDOffset};
    delete $exifTool->{SR2SubIFDLength};
    delete $exifTool->{SR2SubIFDKey};
    return $result;
}

1; # end

__END__

=head1 NAME

Image::ExifTool::Sony - Sony EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Sony maker notes EXIF meta information.

=head1 NOTES

Also see Minolta.pm since Sony DSLR models use structures originating from
Minolta.

=head1 AUTHOR

Copyright 2003-2009, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=item L<http://homepage3.nifty.com/kamisaka/makernote/makernote_sony.htm>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Thomas Bodenmann, Philippe Devaux, Jens Duttke, Marcus
Holland-Moritz, Andrey Tverdokhleb, Rudiger Lange and Igal Milchtaich for
help decoding some tags.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Sony Tags>,
L<Image::ExifTool::TagNames/Minolta Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
