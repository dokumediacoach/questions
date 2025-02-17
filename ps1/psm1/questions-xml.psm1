<#
    .SYNOPSIS
    This script module contains the necessary funtions to process questions xml files.

    .DESCRIPTION
    With the functions in this script module you can get (load), test, convert and save questions xml.
    The functions throw on error. Information is written to console.
    
    .EXAMPLE
    The module and its functions are consumed by the ps1\questions.ps1 script that shows a gui for user interaction.
    It would also be possible to write scripts like the following (for a simple transformation of questions xml to html e.g.):

    Import-Module $PSScriptRoot\psm1\questions-xml.psm1
    $xml = Get-QuestionsXml -FilePath "$questionsRoot\my-questions.xml"
    Test-QuestionsXml -Xml $xml
    Set-QuestionsXmlForPublication -Xml $xml
    Convert-QuestionsXmlToHtml -Xml $xml -TargetPath "$questionsRoot\my-questions.html"
#>
$questionsRoot = Split-Path -Path $MyInvocation.PSScriptRoot -Parent
$xsdPath = "$questionsRoot\xsd\questions.xsd"
$questionsToHtmlXsltPath = "$questionsRoot\xsl\questions-to-html.xsl"

$Script:questionsMustBeRenumbered = $false
$Script:multipleChoiceOptionsOrderRandomizable = $false
$Script:renumberQuestionsChangesOutput = $false

<# localizing #>

# localized data in msg table defaults to en-US,
# keeping this data inside questions-xml.psm1:
$msgTable = Data {
#culture="en-US"
ConvertFrom-StringData @'
    schemaReadingInfo       = Reading XML schema file ...
    schemaValidationError   = Error reading schema file. Aborting execution.
    xmlReadingInfo          = Reading XML file ...
    checkingLanguagesInfo   = Checking the languages of questions ...
    noMultiLanguageError    = Definition of languages for translation not found. Define them in /questions/@language as |-separated list of two digits langcodes, where the first langcode is the main language from which each processing of questions is initialized.
    languageNotUniqueError  = Language not unique in /questions/@language
    noMainLanguageQuestionsError = No question in main language found. Check your language definition in /questions/@language - the first langcode in the |-separated list is the main language from which each processing of questions is initialized.
    translationMissingError = Translation missing for question number:
    adaptingCodeblocksInfo  = Adapting the texts of codeblocks in questions ...
    loadingXsltInfo = Loading XSLT stylesheet ...
    executingXsltTransformationInfo = Executing XSLT transformation to HTML ...
    htmlCreationSuccessInfo = The HTML file was successfully created:
    xmlCreationSuccessInfo  = The XML file was successfully created:
'@
}

# trying to localize, don’t panic when no localized data can be found (en-US data fallback):
Import-LocalizedData -BindingVariable msgTable -ErrorAction:SilentlyContinue


<# initializing #>

# Reading the xml schema in xml reader during initialization, immidiate exit if something goes wrong here:
try {
    Write-Host $msgTable.schemaReadingInfo
    $schemaReader = [System.Xml.XmlReader]::Create($xsdPath)
    [System.Xml.Schema.ValidationEventHandler]$schemaValidationHandler = { throw $msgTable.schemaValidationError }
    $schema = [System.Xml.Schema.XmlSchema]::Read($schemaReader, $schemaValidationHandler)
    $schemaReader.Close()

    $xmlReaderSettings = [System.Xml.XmlReaderSettings]::new()
    $xmlReaderSettings.ValidationType = [System.Xml.ValidationType]::Schema
    $xmlReaderSettings.ValidationFlags = $xmlReaderSettings.ValidationFlags -bor [System.Xml.Schema.XmlSchemaValidationFlags]::ReportValidationWarnings
    $xmlReaderSettings.Schemas.Add($schema) | Out-Null
}
catch {
    throw $_
}
finally {
    if ($null -ne $schemaReader) {
        $schemaReader.Close()
    }
}


<# local helper functions #>

function Set-MultipleChoiceOptionsOrderRandomizable {
    <#
        .SYNOPSIS
            determine and store if multiple choice options order is randomizable (helper function)

        .DESCRIPTION
            Checks if there are any questions with randomizable multiple choice options in xml.
            Stores the boolean value in $Script:multipleChoiceOptionsOrderRandomizable

        .PARAMETER Xml
            The questions xml.

        .PARAMETER MainLanguage
            The main language of questions xml.
    #>
    param (
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument]$Xml,
        [Parameter()]
        [string]$MainLanguage
    )
    $mainLangMultipleChoiceQuestions = $Xml.SelectNodes("/questions/question[lang('$MainLanguage')][multiple-choice]")
    if ($mainLangMultipleChoiceQuestions.Count -eq 0) {
        $Script:multipleChoiceOptionsOrderRandomizable = $false
        return
    }
    if ($Xml.DocumentElement.'multiple-choice-options-order-randomizable' -eq 'true') {
        $mainLangMultipleChoiceOrderedOptionsQuestions = $Xml.SelectNodes("/questions/question[lang('$MainLanguage')][multiple-choice/@options-order-randomizable='false']")
        if ($mainLangMultipleChoiceOrderedOptionsQuestions.Count -lt $mainLangMultipleChoiceQuestions.Count) {
            $Script:multipleChoiceOptionsOrderRandomizable = $true
        } else {
            $Script:multipleChoiceOptionsOrderRandomizable = $false
        }
    } else {
        $mainLangMultipleChoiceOptionsOrderRandomizableQuestions = $Xml.SelectNodes("/questions/question[lang('$MainLanguage')][multiple-choice/@options-order-randomizable='true']")
        if ($mainLangMultipleChoiceOptionsOrderRandomizableQuestions.Count -gt 0) {
            $Script:multipleChoiceOptionsOrderRandomizable = $true
        } else {
            $Script:multipleChoiceOptionsOrderRandomizable = $false
        }
    }
}

function Set-RenumberQuestionsChangesOutput {
    <#
        .SYNOPSIS
            determine and store if renumbering questions changes output (helper function)

        .DESCRIPTION
            Checks if setting questions-to-html.xsl xsl:param questionsOrder to 'renumber' would have an effect on output.
            Stores the boolean value in $Script:renumberQuestionsChangesOutput

        .PARAMETER Xml
            The questions xml.

        .PARAMETER MainLanguage
            The main language of questions xml.
    #>
    param (
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument]$Xml,
        [Parameter()]
        [string]$MainLanguage
    )
    $guidOnlyMainLangQuestions = $Xml.SelectNodes("/questions/question[lang('$MainLanguage')][@guid][not(@nr)]")
    if ($guidOnlyMainLangQuestions.Count -gt 0) {
        $Script:renumberQuestionsChangesOutput = $true
        return
    }
    $Script:renumberQuestionsChangesOutput = $false
    $mainLangQuestions = $Xml.SelectNodes("/questions/question[lang('$MainLanguage')]")
    $nr = 0
    foreach ($q in $mainLangQuestions) {
        $nr++
        if ($q.nr -ne $nr) {
            $Script:renumberQuestionsChangesOutput = $true
            break
        }
    }
}

<# global functions #>

function Get-QuestionsXml {
    <#
        .SYNOPSIS
            get questions xml

        .DESCRIPTION
            Get questions xml by file path.
            Special mode for preservation of all whitespace can be turned on.

        .PARAMETER FilePath
            The path to the questions xml file to load.

        .PARAMETER PreserveAllWhitespace
            If set, all whitespace in xml is preserved (important for translation preparation).
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$FilePath,
        [switch]$PreserveAllWhitespace
    )
    try {
        Write-Host $msgTable.xmlReadingInfo
        $configReader = [System.Xml.XmlReader]::Create($FilePath, $xmlReaderSettings)
        $xml = [System.Xml.XmlDocument]::new()
        if ($PreserveAllWhitespace) {
            $xml.PreserveWhitespace = $true
        }
        $xml.Load($configReader)
        $configReader.Close()
        $xml
    }
    catch {
        throw $_
    }
    finally {
        if ($null -ne $configReader) {
            $configReader.Close()
        }
    }
}
Export-ModuleMember -Function Get-QuestionsXml


function Test-QuestionsXml {
    <#
        .SYNOPSIS
            test questions xml

        .DESCRIPTION
            Test questions xml for errors that cannot be found by xsd validation alone.
            Throw on errors.
            Questions xml should always be tested with this function prior to further processing.

            During testing in Mode 'Publication' (default) variables
                $Script:questionsMustBeRenumbered
                $Script:multipleChoiceOptionsOrderRandomizable
                $Script:renumberQuestionsChangesOutput
            are correctly set.

            Get them with
                Get-QuestionsMustBeRenumbered
                Get-MultipleChoiceOptionsOrderRandomizable
                Get-RenumberQuestionsChangesOutput

        .PARAMETER Xml
            The questions xml.

        .PARAMETER Language
            Language of questions xml can be overwritten with this parameter.
            Defaults to /questions/@language or /questions/@xml:lang

        .PARAMETER Mode
            Mode of testing is different in Mode 'PrepareTranslation' from that in (default) Mode 'Publication'.
            During translation preparation missing questions languages are created (as copy of default questions languages).
            During publication (xml-to-html) missing questions languages are erroneous.

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument]$Xml,
        [Parameter()]
        [string]$Language,
        [Parameter()]
        [ValidateSet('Publication', 'PrepareTranslation')]
        [string]$Mode = 'Publication'
    )
    try {
        Write-Host $msgTable.checkingLanguagesInfo
        $questionsLanguage = if (-not [String]::IsNullOrEmpty($Language)) {
            $Language
        } elseif ($Mode -eq 'PrepareTranslation') {
            $Xml.DocumentElement.language
        } elseif ($Xml.DocumentElement.language) {
            $Xml.DocumentElement.language
        } else {
            $Xml.DocumentElement.lang
        }
        if ($Mode -eq 'PrepareTranslation' -and ([String]::IsNullOrEmpty($questionsLanguage) -or -not $questionsLanguage.Contains('|'))) {
            throw $msgTable.noMultiLanguageError
        }
        $multiLang = $questionsLanguage.Contains('|')
        if (-not $multiLang) {
            $guidOnlyMainLangQuestions = $Xml.SelectNodes("/questions/question[lang('$questionsLanguage')][@guid][not(@nr)]")
            $Script:questionsMustBeRenumbered = if ($guidOnlyMainLangQuestions.Count -gt 0) { $true } else { $false }
            if ($Script:questionsMustBeRenumbered) {
                $Script:renumberQuestionsChangesOutput = $true
            } else {
                Set-RenumberQuestionsChangesOutput -Xml $Xml -MainLanguage $questionsLanguage
            }
            Set-MultipleChoiceOptionsOrderRandomizable -Xml $Xml -MainLanguage $questionsLanguage
            return
        }
        $questionsLanguageArray = $questionsLanguage.Split('|')
        $seen = @()
        $notUnique = @()
        foreach ($lang in $questionsLanguageArray) {
            if ($seen -contains $lang) {
                $notUnique += $lang
            } else {
                $seen += $lang
            }
        }
        if ($notUnique.Length -gt 0) {
            throw "$($msgTable.languageNotUniqueError) - $($notUnique -join ', ')"
        }
        $mainLangQuestions = $Xml.SelectNodes("/questions/question[lang('$($questionsLanguageArray[0])')]")
        if ($mainLangQuestions.Count -eq 0) {
            throw $msgTable.noMainLanguageQuestionsError
        }
        if ($Mode -eq 'Publication') {
            $Script:questionsMustBeRenumbered = $false
            $missingTranslations = @{}
            foreach ($q in $mainLangQuestions) {
                for ($i = 1; $i -le ($questionsLanguageArray.Length - 1); $i++) {
                    if ($q.HasAttribute('guid')) {
                        $oq = $Xml.SelectSingleNode("/questions/question[@guid='$($q.guid)'][lang('$($questionsLanguageArray[$i])')]")
                        if (-not $q.HasAttribute('nr')) {
                            $Script:questionsMustBeRenumbered = $true
                        }
                    } else {
                        $oq = $Xml.SelectSingleNode("/questions/question[@nr='$($q.nr)'][lang('$($questionsLanguageArray[$i])')]")
                    }
                    if ($null -eq $oq) {
                        if ($null -eq $missingTranslations[$questionsLanguageArray[$i]]) {
                            $missingTranslations[$questionsLanguageArray[$i]] = @()
                        }
                        $missingTranslations[$questionsLanguageArray[$i]] += $q.nr
                    }
                }
            }
            if ($missingTranslations.Count -gt 0) {
                $errorText = $msgTable.translationMissingError + ' '
                $isFirst = $true
                foreach ($lang in $missingTranslations.Keys) {
                    if (-not $isFirst) {
                        $errorText += "; "
                    }
                    $errorText += "$lang - $($missingTranslations[$lang] -join ',')"
                }
                throw $errorText
            }
        }
        Set-MultipleChoiceOptionsOrderRandomizable -Xml $Xml -MainLanguage $questionsLanguageArray[0]
        if ($Script:questionsMustBeRenumbered) {
            $Script:renumberQuestionsChangesOutput = $true
            return
        }
        Set-RenumberQuestionsChangesOutput -Xml $Xml -MainLanguage $questionsLanguageArray[0]
    }
    catch {
        throw $_
    }
}
Export-ModuleMember -Function Test-QuestionsXml


# missing / not yet implemented: function get questions xml categories
#   (will be important when categories are implemented)


function Get-QuestionsMustBeRenumbered {
    <#
        .SYNOPSIS
            must questions be renumbered?

        .DESCRIPTION
            Must Convert-QuestionsXmlToHtml -RenumberQuestions be set?
            Gets boolean $Script:questionsMustBeRenumbered.
            The script variable is set during Test-QuestionsXml.
    #>
    [CmdletBinding()]
    param()
    $Script:questionsMustBeRenumbered    
}
Export-ModuleMember -Function Get-QuestionsMustBeRenumbered

function Get-RenumberQuestionsChangesOutput {
    <#
        .SYNOPSIS
            renumber questions changes output?

        .DESCRIPTION
            Does Convert-QuestionsXmlToHtml -RenumberQuestions
            have an effect on output?
            Gets boolean $Script:renumberQuestionsChangesOutput.
            The script variable is set during Test-QuestionsXml.
    #>
    [CmdletBinding()]
    param ()
    $Script:renumberQuestionsChangesOutput
}
Export-ModuleMember -Function Get-RenumberQuestionsChangesOutput

function Get-MultipleChoiceOptionsOrderRandomizable {
    <#
        .SYNOPSIS
            do multiple choice options exist that are allowed to be in random order?

        .DESCRIPTION
            Does Set-QuestionsXmlForPublication -RandomizeMultipleChoiceOptionsOrder
            have an effect on output?
            Gets boolean $Script:multipleChoiceOptionsOrderRandomizable.
            The script variable is set during Test-QuestionsXml.
    #>
    [CmdletBinding()]
    param ()
    $Script:multipleChoiceOptionsOrderRandomizable
}
Export-ModuleMember -Function Get-MultipleChoiceOptionsOrderRandomizable


function Set-QuestionsXmlForPublication {
    <#
        .SYNOPSIS
            set questions xml for publication

        .DESCRIPTION
            Prepare questions xml for publication (xml-to-html).

        .PARAMETER Xml
            The questions xml.

        .PARAMETER Language
            Language of questions xml can be overwritten with this parameter.
            Defaults to /questions/@language or /questions/@xml:lang

        .PARAMETER RandomizeQuestionsOrder
            If set, the questions are randomly sorted (if allowed).
        
        .PARAMETER RandomizeMultipleChoiceOptionsOrder
            If set, the multiple choice options in questions are randomly sorted (where allowed).

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument]$Xml,
        [Parameter()]
        [string]$Language,
        [switch]$RandomizeQuestionsOrder,
        [switch]$RandomizeMultipleChoiceOptionsOrder
    )
    try {
        if (-not [String]::IsNullOrEmpty($Language)) {
            $Xml.DocumentElement.SetAttribute('language', $Language)
        }
        $questionsLanguage = if ($Xml.DocumentElement.language) {
            $Xml.DocumentElement.language
        } else {
            $Xml.DocumentElement.lang
        }
        if ($RandomizeQuestionsOrder -or $RandomizeMultipleChoiceOptionsOrder) {
            $questionsLanguageArray = $questionsLanguage.Split('|')
        }
        if ($RandomizeQuestionsOrder -and ($Xml.DocumentElement.'questions-order-randomizable' -eq 'true')) {
            $mainLangQuestions = $Xml.SelectNodes("/questions/question[lang('$($questionsLanguageArray[0])')]")
            $newOrder = 0..$($mainLangQuestions.Count - 1) | Sort-Object { Get-Random }
            $previousQuestion = $null
            foreach ($i in $newOrder) {
                $question = $mainLangQuestions[$i]
                if ($null -eq $previousQuestion) {
                    $Xml.DocumentElement.PrependChild($question)
                } else {
                    $Xml.DocumentElement.InsertAfter($question, $previousQuestion)
                }
                $previousQuestion = $question
            }
        }
        if ($RandomizeMultipleChoiceOptionsOrder) {
            $rootMultipleChoiceOptionsOrderRandomizable = ($Xml.DocumentElement.'multiple-choice-options-order-randomizable' -eq 'true')
            $mainLangRandomizableMultipleChoiceQuestions = if ($rootMultipleChoiceOptionsOrderRandomizable) {
                $Xml.SelectNodes("/questions/question[lang('$($questionsLanguageArray[0])')][multiple-choice][not(multiple-choice/options-order-randomizable='false')]")
            } else {
                $Xml.SelectNodes("/questions/question[lang('$($questionsLanguageArray[0])')][multiple-choice][multiple-choice/options-order-randomizable='true']")
            }
            foreach ($question in $mainLangRandomizableMultipleChoiceQuestions) {
                $multipleChoiceOptions = $question.SelectNodes("multiple-choice/option")
                $newOrder = 0..$($multipleChoiceOptions.Count - 1) | Sort-Object { Get-Random }
                $guid = if ($question.HasAttribute('guid')) { $question.guid } else { $null }
                $nr = if ($question.HasAttribute('nr')) { $question.nr } else { $null }
                foreach ($langCode in $questionsLanguageArray) {
                    $multipleChoice = if ($null -ne $guid) {
                        $Xml.SelectSingleNode("/questions/question[lang('$langCode')][@guid='$guid']/multiple-choice")
                    } else {
                        $Xml.SelectSingleNode("/questions/question[lang('$langCode')][@nr='$nr']/multiple-choice")
                    }
                    $options = $multipleChoice.SelectNodes("option")
                    $previousOption = $null
                    foreach ($i in $newOrder) {
                        $option = $options[$i]
                        if ($null -eq $previousOption) {
                            $multipleChoice.PrependChild($option)
                        } else {
                            $multipleChoice.InsertAfter($option, $previousOption)
                        }
                        $previousOption = $option
                    }
                }
            }
        }
        $codeblocks = $xml.SelectNodes('//codeblock')
        if ($codeblocks.Count -gt 0) {
            Write-Host $msgTable.adaptingCodeblocksInfo
        }
        foreach ($codeblock in $codeblocks) {
            if ($codeblock.trim -eq 'true') {
                $codeblock.InnerText = $codeblock.InnerText -replace "(?s)^\s*\n(.*?)\n\s*$", "`${1}"
            }
            if ($codeblock.'strip-indent' -eq 'true') {
                $indentation = 0
                $linesArray = $codeblock.InnerText -split "`n"
                foreach ($line in $linesArray) {
                    $spaces = [regex]::Matches($line, '^\s*').Value
                    if ($line.Length -gt 0 -and $spaces.Length -lt $indentation -or $line -eq $linesArray[0]) {
                        $indentation = $spaces.Length
                    }
                }
                if ($indentation -gt 0) {
                    $newLinesArray = @()
                    foreach ($line in $linesArray) {
                        if ($line.Length -gt 0) {
                            $newLinesArray += $line.Substring($indentation)
                        } else {
                            $newLinesArray += $line
                        }
                    }
                    $newText = [System.String]::Join("`n", $newLinesArray)
                    $codeblock.InnerText = $newText
                }
            }
        }
    }
    catch {
        throw $_
    }
}
Export-ModuleMember -Function Set-QuestionsXmlForPublication


function Set-QuestionsXmlForTranslationPreparation {
    <#
        .SYNOPSIS
            set questions xml for translation prepraration

        .DESCRIPTION
            Prepare questions xml for translation preparation.
            Afterwards it needs to be saved with Save-QuestionsXml.

        .PARAMETER Xml
            The questions xml.

        .PARAMETER Language
            Language of questions xml can be overwritten with this parameter.
            Defaults to /questions/@language
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument]$Xml,
        [Parameter()]
        [string]$Language
    )
    try {
        $questionsLanguage = if (-not [String]::IsNullOrEmpty($Language)) {
            $Language
        } else {
            $Xml.DocumentElement.language
        }
        $questionsLanguageArray = $questionsLanguage.Split('|')
        $mainLangQuestions = $xml.SelectNodes("/questions/question[lang('$($questionsLanguageArray[0])')]")
        foreach ($q in $mainLangQuestions) {
            for ($i = 1; $i -le ($questionsLanguageArray.Length - 1); $i++) {
                if ($i -eq 1) {
                    $insertAfterElement = $q
                }
                if ($q.HasAttribute('guid')) {
                    $oq = $xml.SelectSingleNode("/questions/question[@guid='$($q.guid)'][lang('$($questionsLanguageArray[$i])')]")
                } else {
                    $oq = $xml.SelectSingleNode("/questions/question[@nr='$($q.nr)'][lang('$($questionsLanguageArray[$i])')]")
                }
                if ($null -eq $oq) {
                    $whitespaceBefore = $insertAfterElement.SelectSingleNode('preceding-sibling::text()[1]').Value
                    $indent = $whitespaceBefore.Substring($whitespaceBefore.LastIndexOf("`n") + 1)
                    $oq = $q.Clone()
                    $oq.SetAttribute('xml:lang',$questionsLanguageArray[$i]) | Out-Null
                    $q.ParentNode.InsertAfter($oq, $insertAfterElement) | Out-Null
                    $linebreaks = $xml.CreateTextNode("`n`n$indent")
                    $q.ParentNode.InsertBefore($linebreaks, $oq) | Out-Null
                }
                $insertAfterElement = $oq
            }
        }
    }
    catch {
        throw $_
    }
}
Export-ModuleMember -Function Set-QuestionsXmlForTranslationPreparation


function Convert-QuestionsXmlToHtml {
    <#
        .SYNOPSIS
            convert questions xml to html

        .DESCRIPTION
            Questions xml is converted to html, which is saved in TargetPath.
            
            Use Set-QuestionsXmlForPublication before calling this function.

            XML to HTML conversion is accomplished with questions-to-html.xsl

        .PARAMETER Xml
            The questions xml.

        .PARAMETER TargetPath
            The target path where questions html file will be saved.

        .PARAMETER RenumberQuestions
            If set, questions are processed in document order and will be renumberd.
            If not set, questions output is sorted by @nr.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument]$Xml,
        [Parameter(Mandatory)]
        [string]$TargetPath,
        [switch]$RenumberQuestions
    )
    try {
        Write-Host $msgTable.loadingXsltInfo
        $xslt = [System.Xml.Xsl.XslCompiledTransform]::new()
        $xsltSettings = [System.Xml.Xsl.XsltSettings]::new()
        $xsltSettings.EnableDocumentFunction = 1
        $xmlUrlResolver = [System.Xml.XmlUrlResolver]::new()
        $xslt.Load($questionsToHtmlXsltPath, $xsltSettings, $xmlUrlResolver) | Out-Null

        Write-Host $msgTable.executingXsltTransformationInfo
        $xmlNodeReader = [System.Xml.XmlNodeReader]::new($Xml)
        $xsltArgumentList = if ($RenumberQuestions) { [System.Xml.Xsl.XsltArgumentList]::new() } else { $null }
        if ($RenumberQuestions) {
            $xsltArgumentList.AddParam('questionsOrder','','renumber')
        }
        $outStream = [System.IO.MemoryStream]::new()
        $xslt.Transform($xmlNodeReader, $xsltArgumentList, $outStream) | Out-Null

        $outStream.Position = 0
        $outStreamReader = [System.IO.StreamReader]::new($outStream)
        $outStreamWriter = [System.IO.StreamWriter]::new($TargetPath)
        $outStreamWriter.Write($outStreamReader.ReadToEnd())
        $outStreamReader.Close()
        $outStreamWriter.Close()
        $outStream.Close()

        Write-Host "$($msgTable.htmlCreationSuccessInfo)`n$TargetPath"
    }
    catch {
        throw $_
    }
    finally {
        if ($null -ne $outStreamReader) {
            $outStreamReader.Close()
        }
        if ($null -ne $outStreamWriter) {
            $outStreamWriter.Close()
        }
        if ($null -ne $outStream) {
            $outStream.Close()
        }
    }
}
Export-ModuleMember -Function Convert-QuestionsXmlToHtml


function Save-QuestionsXml {
    <#
        .SYNOPSIS
            save questions xml

        .DESCRIPTION
            Questions xml is saved in TargetPath.
            
            Use Set-QuestionsXmlForTranslationPreparation before calling this function.

        .PARAMETER Xml
            The questions xml.

        .PARAMETER TargetPath
            The target path where questions xml file will be saved.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Xml.XmlDocument]$Xml,
        [Parameter(Mandatory)]
        [string]$TargetPath
    )
    try {
        $Xml.Save($TargetPath)
        Write-Host "$($msgTable.xmlCreationSuccessInfo)`n$targetPath"
    }
    catch {
        throw $_
    }
}
Export-ModuleMember -Function Save-QuestionsXml