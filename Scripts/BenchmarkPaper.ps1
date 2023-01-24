function Test-Algorithm {
	param (
		[ValidateScript({ Get-Item $_ })][string]$WorkingDir=".",
		[ValidateRange(1, 1000000000)][int]$RunCount=1,
		[ValidateRange(-1, 11)][int]$Effort=-1,
		[ValidateRange(0, 11)][int]$EffortMin=1,
		[ValidateRange(0, 11)][int]$EffortMax=1,
		[ValidateRange(-1, 100)][int]$Quality=-1,
		[ValidateRange(0, 100)][int]$QualityMin=10,
		[ValidateRange(0, 100)][int]$QualityMax=100,
		[ValidateRange(1, 100)][int]$QualityStep=5,
		[Parameter(Mandatory)][ValidateScript({ Get-Command "Test_$($_)_c"; Get-Command "Test_$($_)_d" })][string] $Format,
		[string]$RawExtension=".ppm",
		#[Parameter(Mandatory, ValueFromRemainingArguments)][ValidateScript({ Get-Item $_ })][string[]]$SourcePaths
		[ValidateScript({ Get-Item $_ })][string]$SourcePath
	)
	if ($Effort -ne -1) {
		$EffortMin = $Effort
		$EffortMax = $Effort
	}
	if ($Quality -ne -1) {
		$QualityMin = $Quality
		$QualityMax = $Quality
	}
	$RunTimeTotal = Measure-Command {
		#foreach ($SourcePath in $SourcePaths) {
			$SourceFile = Get-Item "$SourcePath"
			$TmpFilePath = "$($WorkingDir)\source$RawExtension"
			if ($SourceFile.Extension -eq $RawExtension) {
				Copy-Item -Force $SourceFile "$TmpFilePath"
			} else {
				ffmpeg -i "$($SourceFile.FullName)" -compression_level 0 "$TmpFilePath" 2>&1 | Out-Null
			}
			$TmpFile = Get-Item "$TmpFilePath"
			$TmpFileCPath = "$($TmpFile.FullName).tmp"
			$TmpFileDPath = "$($TmpFile.FullName)$RawExtension"
			$OriginDir = Get-Location
			Set-Location $WorkingDir
			$DataFileName = "$($SourceFile.Name).$EffortMin-$EffortMax-1.$QualityMin-$QualityMax-$QualityStep.$RunCount"
			$DataFile = New-Item -Force -ItemType File "$DataFileName"
			## Uncomment for header
			#Set-Content $DataFile "Format,Effort [$EffortMin-$EffortMax],Quality [$QualityMin-$QualityMax],Run,Full size (bytes),Compressed size (bytes),Compression time (100ns),Decompression time (100ns)" #,Colour difference (red%), Colour difference (green%), Colour difference (blue%)" 
			$RunTime = Measure-Command {
				for($e = $EffortMin; $e -le $EffortMax; $e++) {
					for($q = $QualityMax; $q -ge $QualityMin; $q -= $QualityStep) {
						for($run = 1; $run -le $RunCount; $run++) {
							$CTime = Measure-Command {
								& "Test_$($Format)_c" -q $q -e $e -if "$($TmpFile.FullName)" -of "$TmpFileCPath"
							}
							$DTime = Measure-Command {
								& "Test_$($Format)_d" -if "$TmpFileCPath" -of "$TmpFileDPath"
							}
							## Uncomment to add colour difference tests
							#$ColourDiff = "$(composite.exe "$($TmpFile.Fullname)" "$TmpFileDPath" -compose difference ppm:- | convert.exe - -resize 1x1 -format "%[fx:r],%[fx:g],%[fx:b]" info:-)"
							Add-Content $DataFile "$Format,$e,$q,$run,$($SourceFile.Name),$((Get-Item "$TmpFileDPath").Length),$((Get-Item "$TmpFileCPath").Length),$($CTime.Ticks),$($DTime.Ticks)"#,$ColourDiff"
							Remove-Item "$TmpFileCPath"
							Remove-Item "$TmpFileDPath"
						}
					}
				}
			}
			Remove-Item $TmpFile
			Set-Location $OriginDir
			Move-Item $DataFile ".\TestData.$Format.$($DataFile.Name).$($RunTime.Ticks).$((Get-Date).Ticks).csv"
		#}
	}
}

function Test-AllAllgorithms
{
	param (
		[ValidateScript({ Get-Item $_ })][string]$WorkingDir=".",
		[ValidateRange(1, 1000000000)][int]$RunCount=1,
		[ValidateRange(-1, 11)][int]$Effort=-1,
		[ValidateRange(0, 11)][int]$EffortMin=1,
		[ValidateRange(0, 11)][int]$EffortMax=1,
		[ValidateRange(-1, 100)][int]$Quality=-1,
		[ValidateRange(0, 100)][int]$QualityMin=10,
		[ValidateRange(0, 100)][int]$QualityMax=100,
		[ValidateRange(1, 100)][int]$QualityStep=5,
		[Parameter(Mandatory)][string]$Formats,
		[Parameter(Mandatory, ValueFromPipeline)][ValidateScript({ Get-Item $_ })][string]$SourcePath
	)
	BEGIN {
		$FormatList = $Formats.Split(" ")
	}
	PROCESS {
		foreach ($Fmt in $FormatList) {
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
	}
}

# Example algorithm
# Define functions; e.g. JXL
function Test_JXL_c ($e,$q,$if,$of)
{
	cjxl -q $q -e $e "$if" "$of"
}
function Test_JXL_d ($if,$of)
{
	djxl "$if" "$of.ppm"
	Rename-Item "$of.ppm" "$of"
}

# Run benchmark example
# Preferably run on a RAM disk.
(Get-ChildItem $SourceDirectory | Where-Object -Property Extension -EQ .ppm).FullName | Test-AllAllgorithms -Formats "PNG WEBP:.bpm AVIF:.png JXL WP2" -Effort 0 -Quality 100 -WorkingDir T: -RunCount 3
