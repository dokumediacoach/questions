# Questions

An XML based toolset to develop, test and practice multiple choice questions.

## What questions can do

With &lt;questions&gt; you can write lists of questions in XML files.
A questions XML file can be converted to an HTML file.
The HTML file can be opened in your browser to test and practice the questions.

## What questions cannot do

With &lt;questions&gt; you cannot perform a real test with the developed questions.
All generated HTML data is static. The displayed statistics (correctly answered questions) are calculated with javascript at runtime but they are not stored anywhere. If you reload the HTML file, the data is gone.
To be able to process the input data further, it would be necessary to have a webserver, even a localhost for local html files.
And of course that would require further development.

## Dependencies

To author the questions XML files with fun you need a text editor with xml schema support.\
To use the powershell script ps1/questions.ps1 for xml conversion you need Microsoft Windows.

I recommend using VS Code on a Windows machine with the Extensions PowerShell (by Microsoft) and XML (by Red Hat).

To use the questions HTML files, you need a modern browser. I use the current Mozilla Firefox.

## Get started

To get started, clone the repository from GitHub or if you don’t want to fiddle around with git [download the questions-main.zip](https://github.com/dokumediacoach/questions/archive/main.zip) and unzip it.

Open the questions-demo.html in your browser.

## How-to

To use &lt;questions&gt; you …
1. … create and modify questions XML files. Have a look at the [questions-demo.xml](https://github.com/dokumediacoach/questions/blob/main/questions-demo.xml)
in the questions root folder.
2. … execute the PowerShell script [ps1/questions.ps1](https://github.com/dokumediacoach/questions/blob/main/ps1/questions.ps1)
to open a GUI with which you can convert the questions XML files to questions HTML files.

### Multiple languages

You may have multiple languages in questions. The language of a question is identified by …
1. … the xml:lang attribute of the root element questions (defaults to 'en') and
2. … the optional xml:lang attribute of a question element (overwrites value of xml:lang in root element).

If you want to have more than the default language in the HTML output, you need to specify the languages in the optional language attribute of the root element questions. The attribute value of the language attribute is a |-separated list of two digits langcodes. The first langcode is the main language from which each processing of questions is initialized. It will also be the first language in the language menu in the HTML and the language that you see first when you open the HTML file.

To simplify the translation of questions, there is a special mode in the GUI (PowerShell script questions.ps1) where you can prepare translations.\
For example, the questions-demo.xml was first written in English. To prepare German translation of the questions, the language attribute of the root element questions was added with the value "en|de". Then the questions.ps1 was executed in mode 'prepare translation'. The resulting XML file had a copy of each question element with the added xml:lang attribute that got the value "de". These questions were than translated to German.

After the translation the language attribute value of the root element was changed to "de|en", thus making German the main language of the questions-demo.html output, which was also created with the questions.ps1 'xml to html' mode.