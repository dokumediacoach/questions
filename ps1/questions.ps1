<#
    .SYNOPSIS
    This script shows a GUI from which you can process questions xml files.

    .DESCRIPTION
    Within the displayed GUI you can select the modes 'xml to html' or 'prepare translation'
    helping you to develop and to transform your questions xml.
#>
Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase,System.Windows.Forms

Import-Module $PSScriptRoot\psm1\questions-xml.psm1

<# localizing #>

# localized data in msg table defaults to en-US,
# keeping this data inside questions.ps1:
$msgTable = Data {
#culture="en-US"
ConvertFrom-StringData @'
    gettingQuestionsXmlInfo = Getting available questions XML ...
    noQuestionsXmlError = No XML files in questions root folder.
    abortingScriptInfo = Aborting script.
    xmlFilePlaceholder = select questions xml …
    modeText = mode:
    xmlToHtmlText = xml to html
    prepareTranslationText = prepare translation
    renumberQuestionsText = renumber questions
    renumberQuestionsToolTip = don’t sort by @nr, renumber
    randomizeQuestionsOrderText = randomize questions order
    randomizeQuestionsOrderToolTip = randomly sort questions (if randomizable)
    randomizeMultipleChoiceOptionsOrderText = randomize multiple choice options order
    randomizeMultipleChoiceOptionsOrderToolTip = randomly sort multiple choice options (where randomizable)
    outputFileNameText = output file name
    generateButtonText = generate
    generateOverwriteButtonText = generate (overwrite)
'@
}

# try to localize, don’t panic when no localized data can be found (en-US data fallback):
Import-LocalizedData -BindingVariable msgTable -ErrorAction:SilentlyContinue

try {

    <# stored in script variables are two xml variants that can be processed: #>

    # xml for publication is loaded without preserving all whitespace
    $Script:xmlForPublication = $null

    # xml for translation preparation is loaded preserving all whitespace
    $Script:xmlForTranslationPreparation = $null


    <# constant #>

    # xml files in questions root folder (parent of ps1-folder) are processed
    $questionsRoot = Split-Path -Path $PSScriptRoot -Parent

    # getting available xml files
    Write-Host $msgTable.gettingQuestionsXmlInfo
    $questionXmlFiles = Get-ChildItem -Path $questionsRoot -Include *.xml -File -Name

    # exit if there are no xml files
    if ($questionXmlFiles.Length -eq 0) {
        throw $msgTable.noQuestionsXmlError
    }


    <# gui #>

    # load xaml file (gui)
    [xml]$xaml = Get-Content -Path "$PSScriptRoot\questions.xaml"
    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)

    # create for every named element in xaml an eponymous ps variable
    $xaml.SelectNodes("//*[@Name]") | ForEach-Object {
        Set-Variable -Name ($_.Name) -Value $window.FindName($_.Name) -Description GuiVar
    }

    # localize gui
    $iXmlFilePlaceholder.Content = $msgTable.xmlFilePlaceholder
    $modeText.Text = $msgTable.modeText
    $xmlToHtmlText.Text = $msgTable.xmlToHtmlText
    $prepareTranslationText.Text = $msgTable.prepareTranslationText
    $renumberQuestionsText.Text = $msgTable.renumberQuestionsText
    $cbxRenumberQuestions.ToolTip = $msgTable.renumberQuestionsToolTip
    $randomizeQuestionsOrderText.Text = $msgTable.randomizeQuestionsOrderText
    $cbxRandomizeQuestionsOrder.ToolTip = $msgTable.randomizeQuestionsOrderToolTip
    $randomizeMultipleChoiceOptionsOrderText.Text = $msgTable.randomizeMultipleChoiceOptionsOrderText
    $cbxRandomizeMultipleChoiceOptionsOrder.ToolTip = $msgTable.randomizeMultipleChoiceOptionsOrderToolTip
    $outputFileNameText.Text = $msgTable.outputFileNameText
    $btnGenerate.Content = $msgTable.generateButtonText

    # add xml file list to combobox
    foreach ($questionXmlFile in $questionXmlFiles) {
        $cmbXmlFile.Items.Add($questionXmlFile) | Out-Null
    }


    <# helper functions for output file name textbox events #>
    
    function Test-IsFileNameBad {
        <#
            .Description
                Test-IsFileNameBad returns true if given -FileName is bad.
        #>
        param (
            [Parameter(Mandatory)]
            $FileName
        )
        # at first removing all white space characters from beginning and end of $FileName:
        if (-not [String]::IsNullOrEmpty($FileName)) {
            $fileName = $FileName.Trim()
        }
        # file names to avoid according to common sense and infos at microsoft: https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file
        if ($fileName.Length -eq 0 -or $fileName -eq '.' -or $fileName -eq '..' `
        -or $fileName -imatch '^(?:con|prn|aux|nul|com[0-9¹²³]|lpt[0-9¹²³])(?:\.[^<>:`"/\\:?*\s.|]+)*$') {
            $true
        } elseif ($fileName -imatch '^[^<>:`"/\\:?*|]+') {
            $false
        }
    }

    function Set-GenerateButtonByFileNameTextBox {
        <#
            .Description
                Set-GenerateButtonByFileNameTextBox (parameterless) checks text of $tbxOutputFileName and
                accordingly changes text in $btnGenerate and disables or enables it.
        #>

        # getting tbx output file name text:
        $fileName = $tbxOutputFileName.Text
        # at first removing all white space characters from beginning and end of $fileName:
        $fileName = $fileName.Trim()
        # file extension depends on mode: mode xml to html results in .html, else it’s .xml:
        $extension = if ($optXmlToHtml.IsChecked) { '.html' } else { '.xml' }
        # if the file name entered is bad …
        if ($fileName -eq $extension -or (Test-IsFileNameBad -FileName $fileName)) {
            # … the generate button gets text :generate:
            $btnGenerate.Content = $msgTable.generateButtonText
            # … and is disabled:
            $btnGenerate.IsEnabled = $false
            return
        }
        # if file name is without extension, it will be added when keyboard focus is lost (see: tbx output file name on lost keyboard focus ), …
        if ($fileName.Length -lt $extension.Length -or $fileName.Substring($fileName.Length - $extension.Length) -ne $extension) {
            # … so it must be added for this test:
            $fileName = $fileName + $extension
        }
        # if output file already exists …
        if ($null -ne (Get-ChildItem "$questionsRoot\$fileName" -File -ErrorAction SilentlyContinue)) {
            # … the generate button gets text :generate (overwrite):
            $btnGenerate.Content = $msgTable.generateOverwriteButtonText
            # … and is enabled:
            $btnGenerate.IsEnabled = $true
        } else {
            # … otherwise the generate button gets text :generate:
            $btnGenerate.Content = $msgTable.generateButtonText
            # … and is enabled:
            $btnGenerate.IsEnabled = $true
        }
    }


    <# event handlers #>

    # tbx output file name on text changed
    $tbxOutputFileName.Add_TextChanged({
        
        # reserved characters may not be typed in output file name textbox …
        $invalidRegex = "[<>:`"\/\\:|?*]+"
        # … so they are deleted out immediately when typed in
        $replacedText = $this.Text -replace $invalidRegex

        # when nothing was deleted …
        if ($this.Text -eq $replacedText) {
            # … set generate button by file name text box
            Set-GenerateButtonByFileNameTextBox
            # … and leave
            return
        }
        
        # making sure the cursor does not start doing weird things after character removal
        # I had to do weird things (not sure where I found this):
        $oldIndex = $this.CaretIndex
        $x = $_.Changes.GetEnumerator()
        $x.MoveNext()

        # replacing text
        $this.Text = $replacedText

        # moving the cursor in a distinct way
        $this.CaretIndex = $oldIndex - $x.Current.AddedLength

        # finally setting generate button by file name text box
        Set-GenerateButtonByFileNameTextBox
    })

    # tbx output file name on lost keyboard focus
    $tbxOutputFileName.Add_LostKeyboardFocus({

        $fileName = $this.Text
        # at first removing all white space characters from beginning and end of $fileName:
        $fileName = $fileName.Trim()
        # file extension depends on mode: mode xml to html results in .html, else it’s .xml:
        $extension = if ($optXmlToHtml.IsChecked) { '.html' } else { '.xml' }

        # if file name equals extension or file name is bad …
        if ($fileName -eq $extension -or (Test-IsFileNameBad -FileName $fileName)) {
            # … enter trimmed text
            $this.Text = $fileName
            # … and leave
            return
        }
    
        # if file name is entered without extension …
        if ($fileName.Length -lt $extension.Length -or $fileName.Substring($fileName.Length - $extension.Length) -ne $extension) {
            # … it is kindly added
            $fileName = $fileName + $extension
        }

        # finally entering optimized text
        $this.Text = $fileName
    })

    # cmb xml file on preview key down
    $cmbXmlFile.Add_PreviewKeyDown({

        # disable keyboard control for combobox
        $_.Handled = $true
        
        <#
        # possible alternative keeping keyboard control for combobox enabled,
        # only disabling up key before ComboBoxItem with index 0 – placeholder
        # (select questions xml …) – can be selected:
        if ($_.Key -eq 'Up' -and $cmbXmlFile.SelectedIndex -eq 1) {
            $_.Handled = $true
        }
        #>
    })

    # cmb xml file on selection changed
    $cmbXmlFile.Add_SelectionChanged({

        # if xml file was selected before …
        if ($modeText.IsEnabled) {
            # … empty out previous selection
            $optXmlToHtml.IsChecked = $false
            $optPrepareTranslation.IsChecked = $false
            $sepOtions.Visibility = 'Collapsed'
            $stkXmlToHtmlOptions.Visibility = 'Collapsed'
            $stkOutput.Visibility = 'Collapsed'
            $tbxOutputFileName.Clear()
            $Script:xmlForPublication = $null
            $cbxRenumberQuestions.IsChecked = $false
            $cbxRandomizeQuestionsOrder.IsChecked = $false
            $cbxRandomizeMultipleChoiceOptionsOrder.IsChecked = $false
            $Script:xmlForTranslationPreparation = $null
        }

        # enable mode selection
        $modeText.IsEnabled = $true
        $optXmlToHtml.IsEnabled = $true
        $optPrepareTranslation.IsEnabled = $true
    })

    # opt xml to html on checked
    $optXmlToHtml.Add_Checked({

        # get selected questions xml (+ xsd validation)
        $questionsXmlFile = $cmbXmlFile.SelectedValue
        $questionsXmlFilePath = $questionsRoot + '\' + $questionsXmlFile
        $Script:xmlForPublication = Get-QuestionsXml -FilePath $questionsXmlFilePath

        # ensure questions consistency
        Test-QuestionsXml -Xml $Script:xmlForPublication

        # show options
        $sepOtions.Visibility = 'Visible'
        $stkXmlToHtmlOptions.Visibility = 'Visible'
        $stkOutput.Visibility = 'Visible'

        # set state of options according to xml
        $questionsMustBeRenumbered = Get-QuestionsMustBeRenumbered
        $questionsOrderRandomizable = $Script:xmlForPublication.DocumentElement.'questions-order-randomizable' -eq 'true'
        
        if ($questionsMustBeRenumbered) {
            $cbxRenumberQuestions.IsChecked = $true
            $cbxRenumberQuestions.IsEnabled = $false
        } else {
            $renumberQuestionsChangesOutput = Get-RenumberQuestionsChangesOutput
            $cbxRenumberQuestions.IsEnabled = if ($renumberQuestionsChangesOutput -or $questionsOrderRandomizable) { $true } else { $false }
        }

        if ($questionsOrderRandomizable) {
            $cbxRandomizeQuestionsOrder.IsEnabled = $true
        } else {
            $cbxRandomizeQuestionsOrder.IsChecked = $false
            $cbxRandomizeQuestionsOrder.IsEnabled = $false
        }

        $cbxRandomizeMultipleChoiceOptionsOrder.IsEnabled = Get-MultipleChoiceOptionsOrderRandomizable

        # insert default html output file name in textbox
        $newOutputFileNameValue = $questionsXmlFile.TrimEnd('xml') + 'html'
        $tbxOutputFileName.Text = $newOutputFileNameValue
    })

    # opt prepare translation on checked
    $optPrepareTranslation.Add_Checked({

        # get selected questions xml (+ xsd validation), preserving all whitespace
        $questionsXmlFile = $cmbXmlFile.SelectedValue
        $questionsXmlFilePath = $questionsRoot + '\' + $cmbXmlFile.SelectedValue
        $Script:xmlForTranslationPreparation = Get-QuestionsXml -FilePath $questionsXmlFilePath -PreserveAllWhitespace

        # ensure questions language consistency
        Test-QuestionsXml -Xml $Script:xmlForTranslationPreparation -Mode PrepareTranslation

        # show / hide options
        $sepOtions.Visibility = 'Visible'
        $stkXmlToHtmlOptions.Visibility = 'Collapsed'
        $stkOutput.Visibility = 'Visible'

        # insert default translation xml output file name in textbox
        $newOutputFileNameValue = $questionsXmlFile.TrimEnd('.xml') + '-translation.xml'
        $tbxOutputFileName.Text = $newOutputFileNameValue
    })

    # cbx renumber questions on unchecked
    $cbxRenumberQuestions.Add_Unchecked({

        # the option to randomize the questions’ order can only work if the questions are also renumbered
        # so checkbox randomize questions order is kindly unchecked if not already unset
        if(-not $cbxRandomizeQuestionsOrder.IsChecked) {
            return
        }
        $cbxRandomizeQuestionsOrder.IsChecked = $false
    })

    # cbx randomize questions order on checked
    $cbxRandomizeQuestionsOrder.Add_Checked({

        # the option to randomize the questions’ order can only work if the questions are also renumbered
        # so checkbox renumber questions is kindly checked if not already set
        if($cbxRenumberQuestions.IsChecked) {
            return
        }
        $cbxRenumberQuestions.IsChecked = $true
    })

    # btn generate on click
    $btnGenerate.Add_Click({

        # getting tbx output file name text:
        $outputFileName = $tbxOutputFileName.Text
        # combining output path:
        $outputPath = $questionsRoot + '\' + $outputFileName

        # if mode 'xml to html' is selected …
        if ($optXmlToHtml.IsChecked) {
            # … get options
            $renumberQuestions = $cbxRenumberQuestions.IsChecked
            $randomizeQuestionsOrder = $cbxRandomizeQuestionsOrder.IsChecked
            $randomizeMultipleChoiceOptionsOrder = $cbxRandomizeMultipleChoiceOptionsOrder.IsChecked
            # … assemble publication parameters
            $publicationParameters = @{
                Xml                                 = $Script:xmlForPublication
                RandomizeQuestionsOrder             = $randomizeQuestionsOrder
                RandomizeMultipleChoiceOptionsOrder = $randomizeMultipleChoiceOptionsOrder
            }
            # … set questions xml for publication
            Set-QuestionsXmlForPublication @publicationParameters
            # … assemble html conversion parameters
            $htmlConversionParameters = @{
                Xml               = $Script:xmlForPublication
                TargetPath        = $outputPath
                RenumberQuestions = $renumberQuestions
            }
            # … convert questions xml to html
            Convert-QuestionsXmlToHtml @htmlConversionParameters
            # … and exit
            Exit
        }

        # if mode 'prepare translation' is selected …
        if ($optPrepareTranslation.IsChecked) {
            # … set xml accordingly
            Set-QuestionsXmlForTranslationPreparation -Xml $Script:xmlForTranslationPreparation
            # … save it
            Save-QuestionsXml -Xml $Script:xmlForTranslationPreparation -TargetPath $outputPath
            # … and exit
            Exit
        }
    
    })

    # window minimize button on click
    $windowMinimizeButton.Add_Click({
        $window.WindowState = 'Minimized'
    })


    <# show gui #>

    $window.ShowDialog() | Out-Null

}
catch {
    Write-Host "$_`n$($msgTable.abortingScriptInfo)" -ForegroundColor Red
}
finally {
    if ($window.IsVisible) {
        $window.Close()
    }
}