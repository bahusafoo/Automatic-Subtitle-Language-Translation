param ($InputFile,$OutputLanguage)
#####################################################################
# Translate-SubtitlesFile.ps1
# Author(s): Sean Huggans, Alexandru Marin
$Script:Version = "23.6.5.1"
#####################################################################

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

if (($OutputLanguage) -and ($OutputLanguage -ne $null) -and ($OutputLanguage -ne "")) {
    if (Test-Path -Path $InputFile) {
        Try {
            #Generate New file name based on the old
            $InputObject = Get-Item -Path $InputFile
            $OutPutPath = "$($InputObject.FullName.Replace($InputObject.Extension,''))-AUTOTRANSLATED-$($OutputLanguage)$($InputObject.Extension)"
            if (Test-Path -Path $OutPutPath) {
                Remove-Item -Path $OutPutPath -Force -ErrorAction SilentlyContinue
            }
            [array]$RawContentLines = Get-Content -Path $InputFile -ErrorAction SilentlyContinue
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
                            $OutputLine = Translate-Text -OutputLanguage $LanguageToTranslateTo -InputText $RawContentLine
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
                                    $(Translate-Text -OutputLanguage $LanguageToTranslateTo -InputText $SubtitleScriptCreditLine) | Out-File -FilePath $OutPutPath -Append -Encoding utf8 -NoClobber -Force -ErrorAction Stop
                                    "" | Out-File -FilePath $OutPutPath -Append -Encoding utf8 -NoClobber -Force -ErrorAction Stop
                                    "2" | Out-File -FilePath $OutPutPath -Append -Encoding utf8 -NoClobber -Force -ErrorAction Stop
                                } catch {
                                    Write-Host "Error 0"
                                }
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
                                $OutputLine = Translate-Text -OutputLanguage $LanguageToTranslateTo -InputText $RawContentLine
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
