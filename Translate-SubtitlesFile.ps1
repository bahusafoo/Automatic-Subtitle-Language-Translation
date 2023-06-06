param ($InputFile,$OutputLanguage,$TimeOffSetInMilliSeconds,$PerformAutoCorrections)
#####################################################################
# Translate-SubtitlesFile.ps1
# Author(s): Sean Huggans, Alexandru Marin
$Script:Version = "23.6.6.3"
#####################################################################
# EXAMPLE USAGE:
# .\Translate-SubtitlesFile.ps1 -InputFile "C:\Temp\Harry Potter 6 - English.srt" -OutputLanguage "Nepali" -TimeOffSetInMilliSeconds "0" -PerformAutoCorrections $true
#######################################################

###################################
# Script Variables
#############################
$LanguageToTranslateTo = "Nepali"

###################################
# Script Functions
#############################
Function Translate-Text ($InputText, $OutputLanguage) {
    # Function logic provided by Alexandru Marin @ alexandrumarin.com
    $TranslateToLanguage = ""
    switch -Wildcard ($OutputLanguage.ToLower()) {
        "*russia*" {
            $TranslateToLanguage = "RU"
        }
        "*dani*" {
            $TranslateToLanguage = "DE"
        }
        "*span*" {
            $TranslateToLanguage = "SP"
        }
        "*spain*" {
            $TranslateToLanguage = "SP"
        }
        "*nep*" {
            $TranslateToLanguage = "NE"
        }
        "*hin*" {
            $TranslateToLanguage = "HI"
        }
        default {
            $TranslateToLanguage = $OutputLanguage
        }
    }
    $Uri = “https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=$($TranslateToLanguage)&dt=t&q=$($InputText)”
    $Response = Invoke-RestMethod -Uri $Uri -Method Get
    $Translation = $Response[0].SyncRoot | foreach { $_[0] }
    return $Translation
}

###################################
# Script Execution Logic
#############################
$CorrectionsMapSource = "$($PSScriptRoot)\CorrectionsMap.txt"

if (($OutputLanguage) -and ($OutputLanguage -ne $null) -and ($OutputLanguage -ne "")) {
    if (Test-Path -Path $InputFile) {
        $CorrectedOutFileDir = $(Get-Item -Path $InputFile).DirectoryName
        $CorrectedOutFileName = ""

        # AutoCorrections based on items mapped in CorrectionsMap (default is enabled)
        if ((Test-Path -Path $CorrectionsMapSource) -and ($PerformAutoCorrections -ne $false)) {
            $CorrectedOutFileName = "$($(Get-Item -Path $InputFile).Name.Replace($(Get-Item -Path $InputFile).Extension,''))-corrected$($(Get-Item -Path $InputFile).Extension)"
            Write-Host "Performing AutoCorrections..."
            $CorrectedOutFileName = "$($(Get-Item -Path $InputFile).Name.Replace($(Get-Item -Path $InputFile).Extension,''))-corrected$($(Get-Item -Path $InputFile).Extension)"
            if (Test-Path -Path "$($CorrectedOutFileDir)\$($CorrectedOutFileName)") {
                Remove-Item -Path "$($CorrectedOutFileDir)\$($CorrectedOutFileName)" -Force -Confirm:$false
            }
            foreach ($InputLine in [array]$(Get-Content -Path $InputFile)) {
                if ($InputLine.Trim() -ne "") {
                    foreach ($Correction in [array]$(Get-Content -Path $CorrectionsMapSource)) {
                        if ($Correction.Trim() -ne "") {
                            $CorrectionPattern = $Correction.Split("|")[0]
                            $CorrectedPattern = $Correction.Split("|")[1]
                            $InputLine = $InputLine.replace($CorrectionPattern, $CorrectedPattern)
                        }
                    }
                }
                $InputLine | Out-File -FilePath "$($CorrectedOutFileDir)\$($CorrectedOutFileName)" -Append -Force
            }
        } else {
            $CorrectedOutFileName = $(Get-Item -Path $InputFile).Name
        }

        Try {
            Write-Host "Performing Translations..."
            #Generate New file name based on the old
            $InputObject = Get-Item -Path "$($CorrectedOutFileDir)\$($CorrectedOutFileName)"
            $OutPutPath = "$($InputObject.FullName.Replace($InputObject.Extension,''))-AUTOTRANSLATED-$($OutputLanguage)$($InputObject.Extension)"
            if (Test-Path -Path $OutPutPath) {
                Remove-Item -Path $OutPutPath -Force -ErrorAction SilentlyContinue
            }
            [array]$RawContentLines = Get-Content -Path $InputFile -ErrorAction Stop
            $CurrCount = 0
            $CurrPercentage = $([math]::Round($($CurrCount / $RawContentLines.Count * 100), 2))
            Write-Progress -Activity "Translating Subtitle File" -Status "Line $($CurrCount)/$($RawContentLines.count) ($($CurrPercentage)%)" -PercentComplete $CurrPercentage
            $PreviousLineType = $null
            $AddScriptCredits = $false
            $FirstST = $True
            foreach ($RawContentLine in $RawContentLines) {
                $CurrCount += 1
                $CurrPercentage = $([math]::Round($($CurrCount / $RawContentLines.Count * 100), 2))
                Write-Progress -Activity "Translating Subtitle File" -Status "Line $($CurrCount)/$($RawContentLines.count) ($($CurrPercentage)%)" -PercentComplete $CurrPercentage
                $OutputLine = ""
                if (($RawContentLine.Trim() -ne "") -and ($RawContentLine.Trim() -ne $null) -and ($RawContentLine.Trim())) {
                    if ($RawContentLine.Trim() -match "^\d+$") {
                        if ($PreviousLineType -ne "Timing") {
                            $LineType = "Numbering"
                            # Leave numbering lines untranslated
                            if ($AddScriptCredits -eq $true) { 
                                [int]$NumberingLineNumber = $RawContentLine
                                $NumberingLineNumber +=1
                                $OutputLine = $NumberingLineNumber
                            } else {
                                $OutputLine = $RawContentLine
                            }
                        } else {
                            $LineType = "SubTitle"
                            $OutputLine = Translate-Text -OutputLanguage $LanguageToTranslateTo -InputText $RawContentLine.Replace("#","%23")
                        }
                    } elseif ($RawContentLine.Trim() -like "*:*:*,* --> *:*:*,*") {
                        # Leave timing lines
                        $LineType = "Timing"
                        $OutputLine = $RawContentLine
                        if ($FirstST -eq $True) {
                            $FirstST = $False
                            if ($RawContentLine.Trim() -notlike "00:00:00*") {
                                # Set flag to know to +1 each numbering line from now on
                                $AddScriptCredits = $true
                                Try {
                                    "00:00:00,000 --> 00:00:05,000" | Out-File -FilePath $OutPutPath -Append -Encoding utf8 -NoClobber -Force -ErrorAction Stop
                                    $SubtitleScriptCreditLine = "Translated to $($OutputLanguage) Automatically by Bahusafoo's Subtitle Translation Script version $($Script:Version)"
                                    $SubtitleScriptCreditLine | Out-File -FilePath $OutPutPath -Append -Encoding utf8 -NoClobber -Force -ErrorAction Stop
                                    "(https://bahusa.net/Translate-SubtitlesFile)" | Out-File -FilePath $OutPutPath -Append -Encoding utf8 -NoClobber -Force -ErrorAction Stop
                                    $(Translate-Text -OutputLanguage $LanguageToTranslateTo -InputText $SubtitleScriptCreditLine.Replace("#","%23")) | Out-File -FilePath $OutPutPath -Append -Encoding utf8 -NoClobber -Force -ErrorAction Stop
                                    "" | Out-File -FilePath $OutPutPath -Append -Encoding utf8 -NoClobber -Force -ErrorAction Stop
                                    "2" | Out-File -FilePath $OutPutPath -Append -Encoding utf8 -NoClobber -Force -ErrorAction Stop
                                } catch {
                                    Write-Host "Error 0"
                                }
                            }
                        }
                        if (($TimeOffSetInMilliSeconds -ne $null) -and ($TimeOffSetInMilliSeconds -ne "")) {
                            Try {
                                $LineSplit = $RawContentLine.Trim().Split(" --> ")
                                $StartTimingRaw = $LineSplit[0]
                                [datetime]$StartTimingTime = $StartTimingRaw.Split(",")[0]
                                $StartTimingMS = $StartTimingRaw.Split(",")[1]
                                $EndTimingRaw = $LineSplit[$LineSplit.Length -1].Trim()
                                [datetime]$EndTimingTime = $EndTimingRaw.Split(",")[0]
                                $EndTimingMS = $EndTimingRaw.Split(",")[1]
                                $StartTimingProcessed = "$(Get-Date -Date $StartTimingTime.AddMilliseconds($TimeOffSetInMilliSeconds) -Format 'HH:mm:ss'),$($StartTimingMS)"
                                $EndingTimingProcessed = "$(Get-Date -Date $EndTimingTime.AddMilliseconds($TimeOffSetInMilliSeconds) -Format 'HH:mm:ss'),$($EndTimingMS)"
                                $TimingLineProcessed = "$($StartTimingProcessed) --> $($EndingTimingProcessed)"
                                $OutputLine = $TimingLineProcessed
                                #Write-Host "Timing Adjusted from $($RawContentLine.Trim()) to $($TimingLineProcessed)"
                            } catch {
                                $OutputLine = $RawContentLine
                                Write-Host "Error With Time Offset, ignoring!"
                            }
                        }
                    } else {
                        $LineType = "SubTitle"
                        switch -Wildcard ($RawContentLine) {
                            # Special Case handlers (Add as needed)
                            "qqqqqqqqwwwedfdc3323423" {
                            }
                            default {
                                # Translate the rest
                                $OutputLine = Translate-Text -OutputLanguage $LanguageToTranslateTo -InputText $RawContentLine.Replace("#","%23")
                                #Write-Host $RawContentLine
                            }
                        }
                    }
                } else {
                    # Leave blank lines in place
                    $LineType = "Blank"
                    $OutputLine = $RawContentLine
                }
                Try {
                    $OutputLine | Out-File -FilePath $OutPutPath -Append -Encoding utf8 -NoClobber -Force -ErrorAction Stop
                } catch {
                    Write-Host "Error 0"
                }
                $PreviousLineType = $LineType
            }
            
        } catch {
            return "Error reading contents of Input File."
        }
    } else {
        return "Input File not Found."
    }
} else {
    return "Output Language was not supplied!"
}
