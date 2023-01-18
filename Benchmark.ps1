function Test-Algorithm {

    param (
        
        [ValidateScript({ Get-Item $_ })]
        [string]$WorkingDir=".",
        
        [ValidateRange(1, 1000000000)]
        [int]$RunCount=1,
        
        [ValidateRange(-1, 11)]
        [int]$Effort=-1,
        [ValidateRange(0, 11)]
        [int]$EffortMin=1,
        [ValidateRange(0, 11)]
        [int]$EffortMax=1,

        [ValidateRange(-1, 100)]
        [int]$Quality=-1,
        [ValidateRange(0, 100)]
        [int]$QualityMin=10,
        [ValidateRange(0, 100)]
        [int]$QualityMax=100,
        [ValidateRange(1, 100)]
        [int]$QualityStep=5,

        [Parameter(Mandatory)]
        [ValidateScript({ Get-Command "Test_$($_)_c"; Get-Command "Test_$($_)_d" })]
        [string] $Format,

        [string]$RawExtension=".ppm",
        
        #[Parameter(Mandatory, ValueFromRemainingArguments)]
        #[ValidateScript({ Get-Item $_ })]
        #[string[]]$SourcePaths
        
        [ValidateScript({ Get-Item $_ })]
        [string]$SourcePath

    )

    if ($Effort -ne -1) {
        $EffortMin = $Effort
        $EffortMax = $Effort
    }

    if ($Quality -ne -1) {
        $QualityMin = $Quality
        $QualityMax = $Quality
    }

    #Write-Host "Effort: {$EffortMin..$EffortMax..1}"
    #Write-Host "Quality: {$QualityMin..$QualityMax..$QualityStep}"
    #Write-Host "Runs: $RunCount"

    $RunTimeTotal = Measure-Command {

    #foreach ($SourcePath in $SourcePaths)
    #{
    
        Write-Host "[$Format] File: $SourcePath"

        $SourceFile = Get-Item "$SourcePath"
        $TmpFilePath = "$($WorkingDir)\source$RawExtension"

        if ($SourceFile.Extension -eq $RawExtension)
        {
            Copy-Item -Force $SourceFile "$TmpFilePath"
        }
        else
        {
            Write-Host "[$Format] Wrong format: Converting to $RawExtension"
            ffmpeg -i "$($SourceFile.FullName)" -compression_level 0 "$TmpFilePath" 2>&1 | Out-Null
        }
        
        $TmpFile = Get-Item "$TmpFilePath"
        $TmpFileCPath = "$($TmpFile.FullName).tmp"
        $TmpFileDPath = "$($TmpFile.FullName)$RawExtension"
        
        Write-Host "[$Format] Copied to: $TmpFilePath"
    
        $OriginDir = Get-Location
        Set-Location $WorkingDir
    
        $DataFileName = "$($SourceFile.Name).$EffortMin-$EffortMax-1.$QualityMin-$QualityMax-$QualityStep.$RunCount"

        $DataFile = New-Item -Force -ItemType File "$DataFileName"
        #Set-Content $DataFile "effort [$EffortMin-$EffortMax],quality [$QualityMin-$QualityMax],run,full size (bytes), compressed size (bytes), compression time (100ns), decompression time (100ns)"

        $RunTime = Measure-Command {
        
            Write-Host "[$Format] Beginning test"

            for($e = $EffortMin; $e -le $EffortMax; $e++) {
            
                Write-Host "[$Format] Effort: $e"

                for($q = $QualityMax; $q -ge $QualityMin; $q -= $QualityStep) {
                
                    Write-Host "[TEST] Quality: $q"

                    for($run = 1; $run -le $RunCount; $run++) {
                    
                        Write-Host "[$Format] Run: $run"
                        
                        Write-Host "[$Format] Compressing ..."
                        $CTime = Measure-Command {
                            & "Test_$($Format)_c" -q $q -e $e -if "$($TmpFile.FullName)" -of "$TmpFileCPath"
                        }
                        
                        Write-Host "[$Format] Decompressing ..."
                        $DTime = Measure-Command {
                            & "Test_$($Format)_d" -if "$TmpFileCPath" -of "$TmpFileDPath"
                        }
                        
                        #Write-Host "[$Format] Analising ..."
                        #$ColourDiff = "$(composite.exe "$($TmpFile.Fullname)" "$TmpFileDPath" -compose difference ppm:- | convert.exe - -resize 1x1 -format "%[fx:r],%[fx:g],%[fx:b]" info:-)"

                        Add-Content $DataFile "$Format,$e,$q,$run,$($SourceFile.Name),$((Get-Item "$TmpFileDPath").Length),$((Get-Item "$TmpFileCPath").Length),$($CTime.Ticks),$($DTime.Ticks)"#,$ColourDiff"
                        Remove-Item "$TmpFileCPath"
                        Remove-Item "$TmpFileDPath"
                    }
                }
            }
        }
        
        Write-Host "[$Format] Done."

        Remove-Item $TmpFile
        Set-Location $OriginDir

        Move-Item $DataFile ".\TestData.$Format.$($DataFile.Name).$($RunTime.Ticks).$((Get-Date).Ticks).csv"
        
        Write-Host "[$Format] Saved data to: .\$($DataFile.Name).$($RunTime.Ticks).csv"

    #}

    }

    #Write-Host "Done. Took $($RunTimeTotal.Ticks)"
}

function Test-AllAllgorithms
{
    param (
        
        [ValidateScript({ Get-Item $_ })]
        [string]$WorkingDir=".",
        
        [ValidateRange(1, 1000000000)]
        [int]$RunCount=1,
        
        [ValidateRange(-1, 11)]
        [int]$Effort=-1,
        [ValidateRange(0, 11)]
        [int]$EffortMin=1,
        [ValidateRange(0, 11)]
        [int]$EffortMax=1,
        
        [ValidateRange(-1, 100)]
        [int]$Quality=-1,
        [ValidateRange(0, 100)]
        [int]$QualityMin=10,
        [ValidateRange(0, 100)]
        [int]$QualityMax=100,
        [ValidateRange(1, 100)]
        [int]$QualityStep=5,

        [string]$Formats = "JPEG MOZJPEG JXL AVIF:.png WEBP:.bmp WP2",
        
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateScript({ Get-Item $_ })]
        [string]$SourcePath
    
    )

    BEGIN {
        $FormatList = $Formats.Split(" ")
    }

    PROCESS {
    
    Write-Host "[TEST] File: $SourcePath"

    foreach ($Fmt in $FormatList)
    {
        Write-Host "[TEST] Format: $Fmt"
        $Ext = ".ppm"
        if ($Fmt.Contains(":"))
        {
            $Fmt = $Fmt.split(":")
            $Ext = $Fmt.get(1)
            $Fmt = $Fmt.get(0)
        }
        Test-Algorithm -Format $Fmt -RawExtension $Ext -WorkingDir $WorkingDir -SourcePath $SourcePath `
        -RunCount $RunCount `
        -Effort $Effort -EffortMin $EffortMin -EffortMax $EffortMax `
        -Quality $Quality -QualityMin $QualityMin -QualityMax $QualityMax -QualityStep $QualityStep
        
    }
    
    Write-Host "[TESTALL] Done."

    }

}

# lossy

#ppm
function Test_JXL_c ($e,$q,$if,$of)
{
    cjxl -q $q -e $e "$if" "$of"
}
function Test_JXL_d ($if,$of)
{
    djxl "$if" "$of.ppm"
    Rename-Item "$of.ppm" "$of"
}

#png
function Test_AVIF_c ($e,$if,$of)
{
    Rename-Item "$if" "$if.png"
    avifenc -q $q -s (10 - $e) "$if.png" "$of"
    Rename-Item "$if.png" "$if"
}
function Test_AVIF_d ($if,$of)
{
    avifdec --png-compress 0 "$if" "$of.png"
    Rename-Item "$of.png" "$of"
}

#bmp
function Test_WEBP_c ($e,$q,$if,$of)
{
    cwebp -q $q -m $e "$if" -o "$of"
}
function Test_WEBP_d ($if,$of)
{
    dwebp -ppm "$if" -o "$of"
}

#ppm
function Test_WP2_c ($e,$q,$if,$of)
{
    cwp2 -effort $e -q $q "$if" -o "$of"
}
function Test_WP2_d ($if,$of)
{
    dwp2 -ppm "$if" -o "$of"
}

#ppm
function Test_JPEG_c ($e,$q,$if,$of)
{
    cmd.exe /c "cjpeg -quality $q -optimize `"$if`" > `"$of`"";
}
function Test_JPEG_d ($if,$of)
{
    cmd.exe /c "djpeg `"$if`" > `"$of`"";
}

#ppm
function Test_MOZJPEG_c ($e,$q,$if,$of)
{
    cmd.exe /c "cjpeg-static -quality $q -optimize `"$if`" > `"$of`""
}
function Test_MOZJPEG_d ($if,$of)
{
    cmd.exe /c "djpeg-static `"$if`" > `"$of`""
}

# lossless

#ppm
function Test_PNG_c ($e,$if,$of)
{
    convert "$if" -define png:compression-level=$e "$of.png"
    Rename-Item "$of.png" "$of"
}
function Test_PNG_d ($if,$of)
{
    Rename-Item "$if" "$if.png"
    convert "$if.png" "$of"
    Rename-Item "$if.png" "$if"
}

#ppm
function Test_JXL_c ($e,$if,$of)
{
    cjxl -q 100 -e $e "$if" "$of"
}
function Test_JXL_d ($if,$of)
{
    djxl "$if" "$of.ppm"
    Rename-Item "$of.ppm" "$of"
}

#png
function Test_AVIF_c ($e,$if,$of)
{
    Rename-Item "$if" "$if.png"
    avifenc -l -s (10 - $e) "$if.png" "$of"
    Rename-Item "$if.png" "$if"
}
function Test_AVIF_d ($if,$of)
{
    avifdec --png-compress 0 "$if" "$of.png"
    Rename-Item "$of.png" "$of"
}

#bmp
function Test_WEBP_c ($e,$if,$of)
{
    cwebp -lossless -m $e "$if" -o "$of" 2>&1 | Out-Null
}
function Test_WEBP_d ($if,$of)
{
    dwebp -ppm "$if" -o "$of" 2>&1 | Out-Null
}

#ppm
function Test_WP2_c ($e,$q,$if,$of)
{
    cwp2 -effort $e -q 100 "$if" -o "$of"
}
function Test_WP2_d ($if,$of)
{
    dwp2 -ppm "$if" -o "$of"
}

#ppm
function Test_FLIC_c ($e,$if,$of)
{
    flic c "$of" "$if"
}
function Test_FLIC_d ($if,$of)
{
    flic d "$if" "$of"
}

#ppm
function Test_QLIC_c ($e,$if,$of)
{
    qlic c "$of" "$if"
}
function Test_QLIC_d ($if,$of)
{
    qlic d "$if" "$of"
}

#ppm
function Test_QLIC2_c ($e,$if,$of)
{
    qlic2 c "$of" "$if"
}
function Test_QLIC2_d ($if,$of)
{
    qlic2 d "$if" "$of"
}

#ppm
function Test_QIC_c ($e,$if,$of)
{
    qic c "$of" "$if"
}
function Test_QIC_d ($if,$of)
{
    qic d "$if" "$of"
}

#ppm
function Test_KVICK_c ($e,$if,$of)
{
    kvick c i "$of" "$if"
}
function Test_KVICK_d ($if,$of)
{
    kvick d i "$if" "$of"
}

#ppm
function Test_EMMA_c ($e,$if,$of)
{
    emma_c "$if" "$of"
}
function Test_EMMA_d ($if,$of)
{
    emma_d "$if" "$of"
}

#ppm
function Test_PPMD_c ($e,$if,$of)
{
    7z a -mmt=1 -mx="$e" -m0=PPMD "$of.7z" "$if"
    Rename-Item "$of.7z" "$of"
}
function Test_PPMD_d ($if,$of)
{
    New-Item -ItemType Directory "$of.out"
    7z e "-o$of.out" "$if"
    Move-Item -Path "$of.out\*" -Destination "$of"
    Remove-Item -Recurse -Force "$of.out"
}

#ppm
function Test_BZIP2_c ($e,$if,$of)
{
    7z a -mmt=1 -mx="$e" -m0=BZip2 "$of.7z" "$if"
    Rename-Item "$of.7z" "$of"
}
function Test_BZIP2_d ($if,$of)
{
    New-Item -ItemType Directory "$of.out"
    7z e "-o$of.out" "$if"
    Move-Item -Path "$of.out\*" -Destination "$of"
    Remove-Item -Recurse -Force "$of.out"
}

#ppm
function Test_LZMA2_c ($e,$if,$of)
{
    7z a -mmt=1 -mx="$e" -m0=LZMA2 "$of.7z" "$if"
    Rename-Item "$of.7z" "$of"
}
function Test_LZMA2_d ($if,$of)
{
    New-Item -ItemType Directory "$of.out"
    7z e "-o$of.out" "$if"
    Move-Item -Path "$of.out\*" -Destination "$of"
    Remove-Item -Recurse -Force "$of.out"
}

#ppm
function Test_GZIP_c ($e,$if,$of)
{
    7z a "$of.tgz" "$if"
    Rename-Item "$of.tgz" "$of"
}
function Test_GZIP_d ($if,$of)
{
    Rename-Item "$if" "$if.tgz"
    New-Item -ItemType Directory "$of.out"
    7z e "-o$of.out" "$if.tgz"
    Rename-Item "$if.tgz" "$if"
    Move-Item -Path "$of.out\*" -Destination "$of"
    Remove-Item -Recurse -Force "$of.out"
}

#ppm
function Test_DEFLATE_c ($e,$if,$of)
{
    7z a -mmt=1 -mx="$e" -m0=Deflate "$of.7z" "$if"
    Rename-Item "$of.7z" "$of"
}
function Test_DEFLATE_d ($if,$of)
{
    New-Item -ItemType Directory "$of.out"
    7z e "-o$of.out" "$if"
    Move-Item -Path "$of.out\*" -Destination "$of"
    Remove-Item -Recurse -Force "$of.out"
}


#example

(Get-ChildItem $SourceDirectory | Where-Object -Property Extension -EQ .ppm).FullName | Test-AllAllgorithms -Formats "PNG WEBP:.bpm AVIF:.png JXL WP2" -Effort 0 -Quality 0 -WorkingDir T: -RunCount 3
